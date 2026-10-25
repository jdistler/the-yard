-- The cart sound API (sfx, music; CARTS.md § 4) on love.audio.
--
-- The software synth mixed every voice itself, sample by sample. Here each sound is rendered once into a
-- SoundData (the same waves, envelopes, slides, vibrato, and drums as engine/sfx.c), cached by its settings,
-- and played as an OpenAL source, so the mixing stays in C. The sequencer counts steps by frames.
local A = {}
local RATE = 22050                       -- half the C synth's rate: a quarter of the work, still clean for these waves
local cache, cache_n = {}, 0
local sources = {}
local master, peak = 0.32, 1
local song, step_left, song_step, mus_vol, mus_target, tempo = nil, 0, 0, 1, 1, 1
local nsteps = {}

-- Samples go straight into the SoundData's memory through LuaJIT's FFI when it is there: one call per
-- sample (setSample) was most of the cost of a new sound, and a new note mid-song made the music lag
-- on the cabinet (field test, 2026-10-24).
local ffi_ok, ffi = pcall(require, "ffi")
if not ffi_ok then ffi = nil end

local function midi_hz(m) return 440 * 2 ^ ((m - 69) / 12) end
A.midi_hz = midi_hz
local WAVES = {sine = 0, tri = 1, square = 2, saw = 3, noise = 4}

local function wave_of(w)
  local k = WAVES[w or "tri"]
  if not k then error("no wave named '" .. tostring(w) .. "' (sine tri square saw noise)", 3) end
  return k
end

-- Render one voice, as start_voice + fill did for a single voice.
local function render(wave, hz, hz_end, dur, attack, release, duty, vib_hz, vib_depth, drum)
  local len = math.max(64, math.floor(dur * RATE))
  local att = math.max(16, math.floor(attack * RATE))
  local rel = math.min(len, math.max(32, math.floor(release * RATE)))
  local sd = love.sound.newSoundData(len, RATE, 16, 1)
  local mem = ffi and sd.getFFIPointer and ffi.cast("int16_t *", sd:getFFIPointer())
  local phase, noise, hold, ctr = 0, 0x12345, 0, 0
  local period = (wave == 4 and hz > 0) and math.max(1, math.floor(RATE / hz)) or 1
  local sin, exp, pi2 = math.sin, math.exp, 6.2831853
  local function nz()
    ctr = ctr - 1
    if ctr <= 0 then
      noise = (noise * 1103515245 + 12345) % 2147483648
      hold = (noise % 65536) / 32768 - 1
      ctr = period
    end
    return hold
  end
  for pos = 0, len - 1 do
    local s
    local f = hz
    if hz_end > 0 then f = hz * (hz_end / hz) ^ (pos / len) end
    if vib_depth > 0 then f = f * 2 ^ (vib_depth / 12 * sin(pi2 * vib_hz * pos / RATE)) end
    if drum then
      local t = pos / RATE
      if drum == "K" then
        phase = phase + (50 + 110 * exp(-t * 30)) / RATE
        s = sin(phase * pi2) * 1.2
      elseif drum == "S" then
        phase = phase + 190 / RATE
        s = nz() * 0.7 + 0.4 * sin(phase * pi2)
      elseif drum == "C" then
        s = nz() * ((t % 0.012 < 0.006 or t > 0.03) and 0.8 or 0.2)
      else
        s = nz() * 0.5
      end
    elseif wave == 4 then
      s = nz()
    else
      phase = phase + f / RATE
      phase = phase - math.floor(phase)
      if wave == 0 then s = sin(phase * pi2)
      elseif wave == 1 then s = phase < 0.5 and phase * 4 - 1 or 3 - phase * 4
      elseif wave == 2 then s = phase < duty and 0.6 or -0.6
      else s = (phase * 2 - 1) * 0.6 end
    end
    local env = 1
    if pos < att then env = pos / att end
    if len - pos < rel then local k = (len - pos) / rel env = env * k * k end
    -- The C synth soft-clipped the mix; one voice at these levels stays well under that knee.
    local v = s * env
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    if mem then mem[pos] = math.floor(v * 32767 + 0.5) else sd:setSample(pos, v) end
  end
  return sd
end

local function sound(wave, hz, hz_end, dur, attack, release, duty, vib_hz, vib_depth, drum)
  hz_end, duty, vib_hz, vib_depth = hz_end or 0, duty or 0.5, vib_hz or 0, vib_depth or 0
  local key = table.concat({wave, math.floor(hz * 10), math.floor((hz_end or 0) * 10), math.floor(dur * 1000),
    math.floor(attack * 1000), math.floor(release * 1000), duty, vib_hz, vib_depth, drum or ""}, ":")
  local sd = cache[key]
  if not sd then
    sd = render(wave, hz, hz_end or 0, dur, attack, release, duty or 0.5, vib_hz or 0, vib_depth or 0, drum)
    cache[key] = sd
    cache_n = cache_n + 1
    if cache_n > 400 then cache, cache_n = {}, 0 end -- a cart that never repeats a sound
  end
  return sd
end

local function play_sd(sd, vol, delay)
  if delay and delay > 0 then
    sources[#sources + 1] = {sd = sd, vol = vol, wait = delay}
    return
  end
  local src = love.audio.newSource(sd, "static")
  src:setVolume(math.min(1, vol * master * peak))
  src:play()
  sources[#sources + 1] = {src = src}
end

function A.update(dt)
  -- Delayed starts (arpeggios) and finished sources.
  local j = 1
  for i = 1, #sources do
    local s = sources[i]
    sources[i] = nil
    local keep = true
    if s.wait then
      s.wait = s.wait - dt
      if s.wait <= 0 then
        s.wait = nil
        s.src = love.audio.newSource(s.sd, "static")
        s.src:setVolume(math.min(1, s.vol * master * peak))
        s.src:play()
      end
    elseif s.src and not s.src:isPlaying() then
      keep = false
    end
    if keep then sources[j] = s j = j + 1 end
  end
  -- The sequencer.
  mus_vol = mus_vol + (mus_target - mus_vol) * math.min(1, dt * 2.2)
  if song then
    step_left = step_left - dt * tempo
    while step_left <= 0 do
      step_left = step_left + 60 / (song.bpm * song.steps)
      A.song_tick()
    end
  end
end

local function parse_track(s)
  local out = {}
  local semis = {A = 9, B = 11, C = 0, D = 2, E = 4, F = 5, G = 7}
  local i = 1
  while i <= #s and #out < 128 do
    local ch = s:sub(i, i)
    local nx = s:sub(i + 1, i + 1)
    if ch == "." then out[#out + 1] = -1 i = i + 1
    elseif ch == "-" then out[#out + 1] = -2 i = i + 1
    elseif (ch == "K" or ch == "S" or ch == "H" or ch == "C") and not (ch == "C" and (nx == "#" or nx == "b" or nx:match("%d"))) then
      out[#out + 1] = ch i = i + 1
    elseif semis[ch] then
      local semi, oct = semis[ch], 4
      i = i + 1
      if s:sub(i, i) == "#" then semi = semi + 1 i = i + 1 elseif s:sub(i, i) == "b" then semi = semi - 1 i = i + 1 end
      if s:sub(i, i):match("%d") then oct = tonumber(s:sub(i, i)) i = i + 1 end
      out[#out + 1] = math.max(0, math.min(127, 12 * (oct + 1) + semi))
    else
      i = i + 1
    end
  end
  return out
end

-- The sound for step i of a track (v is a MIDI note or a drum letter); held steps ("-") lengthen it.
local function note_sound(tr, v, i)
  local st, len = tr.steps, #tr.steps
  local release = tr.release > 0 and tr.release or 0.05
  if type(v) == "string" then
    local dur = v == "K" and 0.22 or v == "S" and 0.16 or v == "C" and 0.12 or 0.05
    return sound(4, v == "H" and RATE or v == "S" and RATE / 2 or RATE / 3, 0, dur, tr.attack, dur * 0.95, 0.5, 0, 0, v)
  end
  local hold = 1
  while hold < len and st[(i + hold) % len + 1] == -2 do hold = hold + 1 end
  local step_s = 60 / (song.bpm * song.steps)
  return sound(tr.wave, midi_hz(v + tr.transpose), 0, hold * step_s + release, tr.attack, release, tr.duty, 0, 0)
end

function A.song_tick()
  for t, tr in ipairs(song.tracks) do
    local st = tr.steps
    local len = #st
    if len > 0 then
      local v = st[song_step % len + 1]
      if v ~= -2 then
        if tr.voice and tr.voice:isPlaying() then
          -- The C sequencer released the held note here; a short fade is the nearest a static source does.
          tr.voice:setVolume(tr.voice:getVolume() * 0.5)
        end
        tr.voice = nil
        if v ~= -1 then
          local sd = note_sound(tr, v, song_step % len)
          local src = love.audio.newSource(sd, "static")
          src:setVolume(math.min(1, tr.vol * mus_vol * master * peak))
          src:play()
          tr.voice = src
        end
      end
    end
  end
  song_step = song_step + 1
end

-- ------------------------------------------------------------------ the cart API

local sfx, music = {}, {}
A.sfx, A.music = sfx, music

function sfx.tone(w, hz, dur, vol)
  dur = dur or 0.15
  play_sd(sound(wave_of(w), hz, 0, dur, 0.004, dur * 0.6, 0.5), vol or 0.3)
end
function sfx.note(w, midi, dur, vol) sfx.tone(w, midi_hz(midi), dur or 0.2, vol or 0.3) end
function sfx.slide(w, hz0, hz1, dur, vol)
  dur = dur or 0.2
  play_sd(sound(wave_of(w), hz0, hz1, dur, 0.004, dur * 0.5, 0.5), vol or 0.3)
end
function sfx.noise(dur, vol, hz)
  dur = dur or 0.1
  play_sd(sound(4, hz or 8000, 0, dur, 0.002, dur * 0.9, 0.5), vol or 0.2)
end
function sfx.arp(w, notes, step, vol)
  step = step or 0.08
  local k = wave_of(w)
  for i = 1, math.min(8, #notes) do
    play_sd(sound(k, midi_hz(notes[i]), 0, step * 2.2, 0.004, step * 1.6, 0.5), vol or 0.3, (i - 1) * step)
  end
end
function sfx.play(o)
  local dur = o.dur or 0.2
  play_sd(sound(wave_of(o.wave), o.hz or 440, o.hz_end or 0, dur, o.attack or 0.004, o.release or dur * 0.6,
    o.duty or 0.5, o.vib_hz or 0, o.vib_depth or 0), o.vol or 0.3)
end
function sfx.master(v) master = v end
function sfx.limit(p) peak = math.max(0.05, math.min(1, p / 9000)) end

function music.play(s)
  if s == nil then music.stop() return end
  local tracks = {}
  for i = 1, math.min(6, #s) do
    local t = s[i]
    tracks[i] = {steps = parse_track(t[1]), wave = wave_of(t.wave), vol = t.vol or 0.1, release = t.release or 0.1,
                 attack = t.attack or 0.005, transpose = t.transpose or 0, duty = t.duty or 0.5}
  end
  song = {bpm = s.bpm or 120, steps = s.steps or 4, tracks = tracks}
  song_step, step_left = 0, 0
  -- Render every note of the song now, so none is made while it plays.
  for _, tr in ipairs(tracks) do
    local st, len = tr.steps, #tr.steps
    for i = 0, len - 1 do
      local v = st[i + 1]
      if v ~= -1 and v ~= -2 then note_sound(tr, v, i) end
    end
  end
end
function music.stop()
  if song then for _, t in ipairs(song.tracks) do if t.voice then t.voice:stop() end end end
  song = nil
end
function music.volume(v) mus_target = v end
function music.tempo(k) tempo = k end
function music.step() return song_step end

function A.reset()
  music.stop()
  for _, s in ipairs(sources) do if s.src then s.src:stop() end end
  sources = {}
  master, peak, tempo, mus_vol, mus_target = 0.32, 1, 1, 1, 1
end

return A
