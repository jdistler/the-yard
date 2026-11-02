-- Home's chiptune engine: songs written as text (songs.lua) played by a little synthesizer, a block at a time,
-- so music can stream for hours without a sample in memory (musicthread.lua feeds a QueueableSource with it).
-- Plain LuaJIT + FFI, no LÖVE: tools/songcheck.lua renders every song on the PC to check levels and lengths.
--
-- A song:
--   {bpm = 112, steps = 4 (steps a beat; 4 = sixteenths), swing = 0..0.5, gain = 1, loop = true|false,
--    echo = {time = s, fb = 0..1, mix = 0..1}, lp = Hz (the whole song, one pole),
--    inst = {name = {wave = "pulse"|"tri"|"saw"|"sine"|"noise", duty = 0.125..0.5, pwm = {depth, Hz},
--                    a, d, s, r (seconds; s a level), vol, oct (chords' root octave), arp = Hz | "up"|"down"
--                    (one note a step), vib = {semitones, Hz, delay s}, slide = s (glide between notes),
--                    detune = cents (a second oscillator), lp = Hz, send = 0..1 (to the echo), trem = {depth, Hz}}},
--    parts = {A = {lane = "tokens", ...}, ...}, order = {"A", "A+2", ...}}
-- A lane is named after its instrument ("lead", or "lead_2" for a second lane of the same one); "drums" is the kit.
-- Tokens, one step each: c4 eb5 f#3 (a note), Am F#m7 Bbmaj7 Csus4 (a chord: its notes together, or arpeggiated
-- if the instrument has arp), "-" (hold), "." (rest), "|" (ignored: bars for the eye). "x*4" is x for four steps
-- (a note held, rests, or a drum and three empty steps). A "!" after a note or drum accents it, "?" softens it.
-- Drums: k kick, s snare, h hat, o open hat, c crash, x clap, t low tom, T high tom, r rim; "k+h" together.
-- "A+2" in order plays part A two semitones up. A lane shorter than its part repeats to fill it.
local ffi = require("ffi")
if jit then jit.on() end

local S = {}
local RATE = 22050
local BLOCK = 64
S.RATE, S.BLOCK = RATE, BLOCK
local floor, sin, exp, abs, min, max = math.floor, math.sin, math.exp, math.abs, math.min, math.max
local TAU = 2 * math.pi

-- ------------------------------------------------------------------ parsing
local LETTER = {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11}
local function parse_note(tok)
  local l, acc, oct = tok:match("^([a-g])([#b]?)(%d)$")
  if not l then return nil end
  return (tonumber(oct) + 1) * 12 + LETTER[l] + (acc == "#" and 1 or acc == "b" and -1 or 0)
end
S.parse_note = parse_note

local QUALITY = {
  [""] = {0, 4, 7}, m = {0, 3, 7}, ["7"] = {0, 4, 7, 10}, m7 = {0, 3, 7, 10}, maj7 = {0, 4, 7, 11},
  sus4 = {0, 5, 7}, sus2 = {0, 2, 7}, dim = {0, 3, 6}, dim7 = {0, 3, 6, 9}, aug = {0, 4, 8}, ["6"] = {0, 4, 7, 9},
  m6 = {0, 3, 7, 9}, add9 = {0, 4, 7, 14}, ["9"] = {0, 4, 7, 10, 14}, ["5"] = {0, 7, 12}, m9 = {0, 3, 7, 10, 14},
  maj9 = {0, 4, 7, 11, 14}, madd9 = {0, 3, 7, 14}, ["7sus4"] = {0, 5, 7, 10}, m7b5 = {0, 3, 6, 10},
}
local function parse_chord(tok, oct)
  local l, acc, q = tok:match("^([A-G])([#b]?)(.*)$")
  if not l or not QUALITY[q] then return nil end
  local root = (oct + 1) * 12 + LETTER[l:lower()] + (acc == "#" and 1 or acc == "b" and -1 or 0)
  local t = {}
  for i, iv in ipairs(QUALITY[q]) do t[i] = root + iv end
  return t
end

local DRUMS = {k = "kick", s = "snare", h = "hat", o = "open", c = "crash", x = "clap", t = "tom", T = "tomhi",
               r = "rim"}

-- A lane's text -> steps: {"on", notes, vel} | "hold" | "rest" | {"drum", {names}, vel} | false (nothing)
local function parse_lane(text, inst, drums, where)
  local steps = {}
  text = text:gsub("|", " ")
  for tok in text:gmatch("%S+") do
    do
      local base, n = tok:match("^(.-)%*(%d+)$")
      if not base then base, n = tok, 1 end
      n = tonumber(n)
      local vel = 1
      if base:sub(-1) == "!" then vel, base = 1.35, base:sub(1, -2)
      elseif base:sub(-1) == "?" then vel, base = 0.6, base:sub(1, -2) end
      if base == "-" then
        for _ = 1, n do steps[#steps + 1] = "hold" end
      elseif base == "." then
        for _ = 1, n do steps[#steps + 1] = drums and false or "rest" end
      elseif drums then
        local names = {}
        for d in base:gmatch("[^+]+") do
          if not DRUMS[d] then error(where .. ": unknown drum '" .. d .. "' in '" .. tok .. "'") end
          names[#names + 1] = DRUMS[d]
        end
        steps[#steps + 1] = {"drum", names, vel}
        for _ = 2, n do steps[#steps + 1] = false end
      else
        local m = parse_note(base)
        local notes = m and {m} or parse_chord(base, inst.oct or 4)
        if not notes then error(where .. ": cannot read '" .. tok .. "'") end
        steps[#steps + 1] = {"on", notes, vel}
        for _ = 2, n do steps[#steps + 1] = "hold" end
      end
    end
  end
  return steps
end

-- A song's text -> per lane, events {step, notes, len (steps), vel} (melodic) or {step, names, vel} (drums).
function S.compile(song, name)
  if song.compiled then return song end
  name = name or "song"
  local lanes = {}                                 -- lane name -> {inst, drums, events}
  local total = 0
  local parsed = {}
  for pname, part in pairs(song.parts) do
    local p = {lanes = {}, len = 0}
    for lane, text in pairs(part) do
      local iname = lane:gsub("_%d+$", "")
      local drums = iname == "drums"
      local inst = drums and {} or song.inst[iname]
      if not inst then error(name .. "." .. pname .. ": no instrument '" .. iname .. "'") end
      local st = parse_lane(text, inst, drums, name .. "." .. pname .. "." .. lane)
      p.lanes[lane] = st
      if #st > p.len then p.len = #st end
    end
    parsed[pname] = p
  end
  for _, entry in ipairs(song.order) do
    local pname, tr = entry:match("^(.-)([%+%-]%d+)$")
    if not pname then pname, tr = entry, 0 end
    tr = tonumber(tr)
    local p = parsed[pname]
    if not p then error(name .. ": no part '" .. pname .. "'") end
    for lane, st in pairs(p.lanes) do
      local iname = lane:gsub("_%d+$", "")
      local L = lanes[lane]
      if not L then
        L = {inst = song.inst[iname] or {}, drums = iname == "drums", events = {}}
        lanes[lane] = L
      end
      local n = #st
      if n > 0 then
        for i = 0, p.len - 1 do
          local s = st[i % n + 1]
          local at = total + i
          if type(s) == "table" then
            if s[1] == "drum" then
              L.events[#L.events + 1] = {at, s[2], s[3]}
            else
              -- held for the "hold" steps after it (across the lane's own repeat, within the part)
              local len = 1
              while i + len < p.len and st[(i + len) % n + 1] == "hold" do len = len + 1 end
              local notes = {}
              for k, m in ipairs(s[2]) do notes[k] = m + (L.drums and 0 or tr) end
              L.events[#L.events + 1] = {at, notes, len, s[3]}
            end
          end
        end
      end
    end
    total = total + p.len
  end
  song.lanes, song.total_steps = lanes, total
  song.step_len = RATE * 60 / (song.bpm * (song.steps or 4))
  song.length = floor(total * song.step_len)
  song.compiled = true
  return song
end

-- ------------------------------------------------------------------ voices
local WAVE = {pulse = 1, tri = 2, saw = 3, sine = 4, noise = 5}
local SINE = ffi.new("float[1024]")
for i = 0, 1023 do SINE[i] = sin(i / 1024 * TAU) end
local function hz(m) return 440 * 2 ^ ((m - 69) / 12) end

local seed = 22222
local function rnd()
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed / 1073741824 - 1
end

-- The envelope at t samples into a note held for len samples (release after).
local function env_at(inst, t, len)
  local a, d, s, r = inst._a, inst._d, inst.s or 0.7, inst._r
  local e
  local tt = t < len and t or len
  if tt < a then e = tt / a
  elseif tt < a + d then e = 1 - (1 - s) * (tt - a) / d
  else e = s end
  if t >= len then
    local k = (t - len) / r
    if k >= 1 then return 0, true end
    e = e * (1 - k)
  end
  return e, false
end

local function prep(inst)
  if inst._ready then return end
  inst._a = max(1, (inst.a or 0.004) * RATE)
  inst._d = max(1, (inst.d or 0.1) * RATE)
  inst._r = max(1, (inst.r or 0.06) * RATE)
  inst._w = WAVE[inst.wave or "pulse"] or 1
  inst._lp = inst.lp and (1 - exp(-TAU * inst.lp / RATE)) or nil
  inst._slide = inst.slide and (1 - exp(-BLOCK / (inst.slide * RATE))) or nil
  inst._det = inst.detune and 2 ^ (inst.detune / 1200) or nil
  inst._ready = true
end

-- A melodic voice: one lane's sounding note (or chord).
local function voice_on(L, ev, step_len, now, old)
  local inst = L.inst
  prep(inst)
  local v = old and old.inst == inst and not inst.retrig and old or {}
  v.inst = inst
  v.notes = ev[2]
  v.t = 0
  v.len = floor(ev[3] * step_len * (inst.gate or 0.92))
  v.vel = ev[4]
  v.step_len = step_len
  v.ph = v.ph or {0, 0, 0, 0, 0}
  v.ph2 = v.ph2 or {0, 0, 0, 0, 0}
  v.y = v.y or 0
  v.hold = v.hold or 0
  v.nz = v.nz or 0
  local f = hz(ev[2][1])
  if inst._slide and old and old.f and not old.done then v.f = old.f else v.f = f end
  v.target = f
  v.done = false
  v.started = now
  return v
end

local function render_voice(v, dry, send, t_song)
  local inst = v.inst
  local e0, gone = env_at(inst, v.t, v.len)
  local e1 = env_at(inst, v.t + BLOCK, v.len)
  if gone then v.done = true return end
  local vol = (inst.vol or 0.1) * v.vel
  if inst.trem then e0 = e0 * (1 - inst.trem[1] * (0.5 + 0.5 * sin(TAU * inst.trem[2] * t_song))) e1 = e1 * (1 - inst.trem[1] * (0.5 + 0.5 * sin(TAU * inst.trem[2] * t_song))) end
  -- pitch: glide, vibrato
  if inst._slide then v.f = v.f + (v.target - v.f) * inst._slide else v.f = v.target end
  local mult = 1
  local vb = inst.vib
  if vb then
    local tv = v.t / RATE - (vb[3] or 0)
    if tv > 0 then mult = 2 ^ (vb[1] * min(1, tv * 4) * sin(TAU * vb[2] * tv) / 12) end
  end
  -- which notes: all (a chord), or one (an arpeggio)
  local notes = v.notes
  local list, nl
  if inst.arp and #notes > 1 then
    local i
    if type(inst.arp) == "number" then i = floor(v.t / RATE * inst.arp)
    else i = floor(v.t / v.step_len) end
    local n = #notes
    i = i % (inst.arp == "updown" and (2 * n - 2) or n)
    if inst.arp == "down" then i = n - 1 - i
    elseif inst.arp == "updown" and i >= n then i = 2 * n - 2 - i end
    list, nl = {notes[i + 1]}, 1
  else
    list, nl = notes, #notes
  end
  local w = inst._w
  local duty = inst.duty or 0.5
  if inst.pwm then duty = duty + inst.pwm[1] * sin(TAU * inst.pwm[2] * t_song) end
  local lp = inst._lp
  local snd = inst.send or 0
  local det = inst._det
  local scale = vol / (nl > 1 and (0.6 + 0.4 * nl) or 1)
  local de = (e1 - e0) / BLOCK
  for k = 1, nl do
    local f = (nl == 1 and k == 1 and #notes == 1) and v.f * mult or hz(list[k]) * mult
    if inst.arp and nl == 1 then f = hz(list[1]) * mult end
    local inc = f / RATE
    local ph = v.ph[k]
    local ph2 = v.ph2[k]
    local inc2 = det and inc * det or 0
    local y, e = v.y, e0
    local hold, nz = v.hold, v.nz
    for i = 0, BLOCK - 1 do
      local s
      if w == 1 then s = ph < duty and 1 or -1
      elseif w == 2 then
        local q = floor((ph < 0.5 and ph * 4 - 1 or 3 - ph * 4) * 7.5 + 0.5) / 7.5
        s = q
      elseif w == 3 then s = 2 * ph - 1
      elseif w == 4 then s = SINE[floor(ph * 1024) % 1024]
      else
        hold = hold + inc
        if hold >= 1 then hold = hold - 1 nz = rnd() end
        s = nz
      end
      if det then
        if w == 1 then s = s + (ph2 < duty and 1 or -1)
        elseif w == 3 then s = s + 2 * ph2 - 1
        else s = s + SINE[floor(ph2 * 1024) % 1024] end
        s = s * 0.6
        ph2 = ph2 + inc2
        if ph2 >= 1 then ph2 = ph2 - 1 end
      end
      if w ~= 5 then
        ph = ph + inc
        if ph >= 1 then ph = ph - 1 end
      end
      if lp then y = y + lp * (s - y) s = y end
      local o = s * e * scale
      dry[i] = dry[i] + o
      send[i] = send[i] + o * snd
      e = e + de
    end
    v.ph[k], v.ph2[k] = ph, ph2
    if k == nl then v.y, v.hold, v.nz = y, hold, nz end
  end
  v.t = v.t + BLOCK
end

-- Drums: one-shot voices.
local KIT = {
  kick = {len = 0.32, vol = 0.55},
  snare = {len = 0.2, vol = 0.32},
  hat = {len = 0.045, vol = 0.12},
  open = {len = 0.28, vol = 0.1},
  crash = {len = 1.6, vol = 0.16},
  clap = {len = 0.22, vol = 0.26},
  tom = {len = 0.3, vol = 0.4},
  tomhi = {len = 0.25, vol = 0.36},
  rim = {len = 0.05, vol = 0.2},
}
local function render_drum(d, dry, send, kit_gain, snd)
  local k = KIT[d.name]
  local n = k.len * RATE
  local vol = k.vol * d.vel * kit_gain
  local name = d.name
  local t = d.t
  local ph, y = d.ph, d.y
  for i = 0, BLOCK - 1 do
    local u = t / n
    if u >= 1 then d.done = true break end
    local s
    if name == "kick" then
      local f = 45 + 110 * exp(-t / (0.03 * RATE))
      ph = ph + f / RATE
      s = SINE[floor(ph * 1024) % 1024] * (1 - u) ^ 2
    elseif name == "tom" or name == "tomhi" then
      local f0 = name == "tom" and 110 or 170
      local f = f0 + f0 * 0.8 * exp(-t / (0.05 * RATE))
      ph = ph + f / RATE
      s = SINE[floor(ph * 1024) % 1024] * (1 - u) ^ 1.5
    elseif name == "snare" then
      ph = ph + 185 / RATE
      s = (rnd() * 0.75 * (1 - u) ^ 2.2 + SINE[floor(ph * 1024) % 1024] * 0.5 * max(0, 1 - u * 3))
    elseif name == "clap" then
      local env = (t < 0.012 * RATE or (t > 0.02 * RATE and t < 0.03 * RATE)) and 1 or (1 - u) ^ 3
      y = y + 0.5 * (rnd() - y)
      s = (rnd() - y) * env
    elseif name == "rim" then
      ph = ph + 1700 / RATE
      s = (ph % 1 < 0.5 and 1 or -1) * (1 - u) ^ 3 * 0.6
    else
      -- hats, crash: bright noise (minus a smoothed copy: a high pass)
      local r = rnd()
      y = y + 0.35 * (r - y)
      s = (r - y) * (1 - u) ^ (name == "crash" and 1.8 or 2.5)
    end
    local o = s * vol
    dry[i] = dry[i] + o
    send[i] = send[i] + o * snd
    t = t + 1
  end
  d.t, d.ph, d.y = t, ph, y
end

-- ------------------------------------------------------------------ a player: one song, playing
local Player = {}
Player.__index = Player

function S.player(song, name)
  S.compile(song, name)
  local p = setmetatable({song = song, name = name, pos = 0, idx = {}, voices = {}, drums = {}, finished = false,
                          gain = 1, target = 1, fade = 0}, Player)
  for lane in pairs(song.lanes) do p.idx[lane] = 1 end
  if song.echo then
    local n = floor((song.echo.time or 0.3) * RATE)
    p.dl = ffi.new("float[?]", n)
    p.dn, p.di = n, 0
  end
  p.lp = song.lp and (1 - exp(-TAU * song.lp / RATE)) or nil
  p.ly = 0
  return p
end

local dry = ffi.new("float[?]", BLOCK)
local send = ffi.new("float[?]", BLOCK)

-- Adds one block of this song into out (from out[o]), at its gain; false when it has ended.
function Player:block(out, o)
  local song = self.song
  for i = 0, BLOCK - 1 do dry[i] = 0 send[i] = 0 end
  local sl = song.step_len
  local now = self.pos
  if not self.finished then
    -- events due in this block (by step; swing delays the off-beat steps)
    for lane, L in pairs(song.lanes) do
      local ev = L.events
      local j = self.idx[lane]
      while ev[j] do
        local st = ev[j][1]
        local at = st * sl
        if song.swing and st % 2 == 1 then at = at + song.swing * sl end
        if at >= now + BLOCK then break end
        if L.drums then
          for _, nm in ipairs(ev[j][2]) do
            self.drums[#self.drums + 1] = {name = nm, vel = ev[j][3], t = 0, ph = 0, y = 0}
          end
        else
          self.voices[lane] = voice_on(L, ev[j], sl, now, self.voices[lane])
        end
        j = j + 1
      end
      self.idx[lane] = j
    end
  end
  local tsong = now / RATE
  for lane, v in pairs(self.voices) do
    if not v.done then render_voice(v, dry, send, tsong) end
  end
  local kg = song.drums_gain or 1
  local ds = song.drums_send or 0
  local nd = #self.drums
  local j = 1
  for i = 1, nd do
    local d = self.drums[i]
    render_drum(d, dry, send, kg, ds)
    if not d.done then self.drums[j] = d j = j + 1 end
  end
  for i = j, nd do self.drums[i] = nil end
  -- echo, the song's tone, its gain (with any fade)
  local e = song.echo
  local dl, dn, di = self.dl, self.dn, self.di
  local fb, mix = e and (e.fb or 0.35) or 0, e and (e.mix or 0.3) or 0
  local g = (song.gain or 1) * self.gain
  local dg = ((song.gain or 1) * self.target - g) / BLOCK * min(1, self.fade > 0 and BLOCK / self.fade or 1)
  local lp, ly = self.lp, self.ly
  for i = 0, BLOCK - 1 do
    local s = dry[i]
    if dl then
      local d = dl[di]
      dl[di] = send[i] + d * fb
      di = di + 1
      if di >= dn then di = 0 end
      s = s + d * mix
    end
    if lp then ly = ly + lp * (s - ly) s = ly end
    out[o + i] = out[o + i] + s * g
    g = g + dg
  end
  self.di, self.ly = di, ly
  self.gain = g / (song.gain or 1)
  if self.fade > 0 then self.fade = max(0, self.fade - BLOCK) end
  self.pos = now + BLOCK
  if self.pos >= song.length and not self.finished then
    if song.loop == false then
      self.finished = true
      self.end_at = self.pos
    else
      self.pos = self.pos - song.length
      for lane in pairs(self.idx) do self.idx[lane] = 1 end
    end
  end
  -- ended: nothing left sounding a moment after the last note
  if self.finished and self.pos - self.end_at > RATE * 2.5 then return false end
  return true
end

-- Fade to a gain over s seconds.
function Player:fade_to(g, s)
  self.target = g
  self.fade = max(1, floor(s * RATE))
  if s <= 0 then self.gain = g end
end

-- ------------------------------------------------------------------ the mixer: songs in and out
local Mixer = {}
Mixer.__index = Mixer

function S.mixer(songs)
  return setmetatable({songs = songs, players = {}, master = 1, mtarget = 1, mstep = 0, current = nil}, Mixer)
end

-- Play a song by name (from the start), fading the others out and it in over fade seconds.
-- "none": silence. A song that ends (loop = false) goes on to song.after, if it names one.
function Mixer:play(name, fade, restart, keep_tail)
  fade = fade or 1.5
  if name == self.current and not restart then return end
  self.current = name
  for _, p in ipairs(self.players) do
    if keep_tail then p.leaving = true else p:fade_to(0, fade) p.leaving = true end
  end
  local song = self.songs[name]
  if song then
    local p = S.player(song, name)
    if fade > 0.05 and #self.players > 0 then p.gain = 0 p:fade_to(1, fade * 0.8) end
    self.players[#self.players + 1] = p
  end
end

function Mixer:volume(v, s)
  self.mtarget = v
  self.mstep = (v - self.master) / max(1, (s or 0.5) * RATE / BLOCK)
end

-- n samples (a multiple of BLOCK) into out (float*), mixed, limited to -1..1.
function Mixer:render(out, n)
  for i = 0, n - 1 do out[i] = 0 end
  for o = 0, n - 1, BLOCK do
    local keep, after = {}, nil
    for _, p in ipairs(self.players) do
      local alive = p:block(out, o)
      if p.leaving and p.target == 0 and p.gain < 0.002 then alive = false end
      if alive then keep[#keep + 1] = p end
      -- a song that ended goes straight on to the one it names (its last notes ring on)
      if p.finished and not p.chained and p.song.after and self.current == p.name then
        p.chained = true
        after = p.song.after
      end
    end
    self.players = keep
    if after then self:play(after, 0, true, true) end
    local m = self.master
    if self.mstep ~= 0 then
      m = m + self.mstep
      if (self.mstep > 0 and m >= self.mtarget) or (self.mstep < 0 and m <= self.mtarget) then m = self.mtarget self.mstep = 0 end
      self.master = m
    end
    for i = o, o + BLOCK - 1 do
      local s = out[i] * m
      -- a soft limit above 0.7
      if s > 0.7 then s = 0.7 + (s - 0.7) / (1 + (s - 0.7) * 3)
      elseif s < -0.7 then s = -0.7 + (s + 0.7) / (1 - (s + 0.7) * 3) end
      out[i] = s
    end
  end
end

-- A whole short song rendered at once (sound effects): float* and its length.
function S.render_all(song, seconds)
  local mx = S.mixer({x = song})
  mx:play("x", 0)
  local n = floor(seconds * RATE / BLOCK) * BLOCK
  local buf = ffi.new("float[?]", n)
  mx:render(buf, n)
  return buf, n
end

return S
