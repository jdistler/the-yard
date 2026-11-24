-- Safari's music. Three habitat songs (Sunny Meadow, Spark Cave, Crystal Pond), three gym songs (each in three
-- sections that the game swaps with music.play{keep = true} as the leader's strength drops), the victory
-- fanfare, the field-book lullaby and the story. Every song is 8 bars of 16 steps (128 steps), 4 steps a beat.
--
-- Habitat tracks (the same in every habitat):
--   1 lead (the hook)   2 bass   3 pad   4 5 6 the voices of that habitat's three friends
-- A friend's voice is silent until you meet it; it fades in when you walk up to it in the wild (a teaser) and
-- stays once the friend is yours. Every part is written to be a good song with any subset on. Pond has only two
-- friends, so track 6 there is the tide (a soft beat) that comes in with the party.
--
-- Gym tracks: 1 lead  2 bass  3 stabs  4 arp  5 drums  6 pad. Section 1 (the leader is strong) is bass, drums,
-- pad and a thin hook; section 2 brings in the whole hook and the stabs; section 3 (the leader is nearly beaten)
-- is every part, driving.
--
-- Nothing here is read by the game's rules: only sound.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (floor(m / 12) - 1) end
local PC = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function mid(s)
  local l, a, o = s:match("^([A-G])([#b]?)(%d)$")
  return PC[l] + (a == "#" and 1 or a == "b" and -1 or 0) + (tonumber(o) + 1) * 12
end
local function tr(str, semis)
  if semis == 0 then return str end
  return (str:gsub("([A-G][#b]?)(%d)", function(n, o) return nm(mid(n .. o) + semis) end))
end

local SC = {major = {0, 2, 4, 5, 7, 9, 11}, minor = {0, 2, 3, 5, 7, 8, 10}, dorian = {0, 2, 3, 5, 7, 9, 10},
            lydian = {0, 2, 4, 6, 7, 9, 11}}

-- semitones above the tonic of scale degree d (1 up, may pass 7)
local function dst(w, d)
  return SC[w.scale][(d - 1) % 7 + 1] + 12 * idiv(d - 1, 7)
end

-- A melody token in scale degrees: "3", "3h" (an octave up), "6l" (down), "7s" (sharp), "7f" (flat).
local function melody(w, str)
  return (str:gsub("%S+", function(t)
    local d, acc, oct = t:match("^(%d)([sf]?)([hl]?)$")
    if not d then return t end
    local m = w.tonic + w.lb + dst(w, tonumber(d)) + (acc == "s" and 1 or acc == "f" and -1 or 0)
              + (oct == "h" and 12 or oct == "l" and -12 or 0)
    return nm(m)
  end))
end

-- The 16 half-bar chords: scale degrees, "5M" or "5m" force the third's quality.
local function chords(w)
  w.r, w.t3, w.t5 = {}, {}, {}
  for tok in w.prog:gmatch("%S+") do
    local d, q = tok:match("^(%d)([Mm]?)$")
    d = tonumber(d)
    local root = dst(w, d)
    local third, fifth = dst(w, d + 2) - root, dst(w, d + 4) - root
    if q == "M" then third = 4 elseif q == "m" then third = 3 end
    w.r[#w.r + 1], w.t3[#w.t3 + 1], w.t5[#w.t5 + 1] = root, third, fifth
  end
  assert(#w.r == 16, "prog " .. w.name)
end

-- Patterns of 8 steps per half-bar; 1 3 5 8 are the chord's root, third, fifth, octave.
local function lay(w, pats, base)
  local out = {}
  for h = 1, 16 do
    local pat = pats[(h - 1) % #pats + 1]
    local row = {}
    for tok in pat:gmatch("%S+") do
      local off
      if tok == "1" then off = 0 elseif tok == "3" then off = w.t3[h] elseif tok == "5" then off = w.t5[h]
      elseif tok == "8" then off = 12 end
      row[#row + 1] = off and nm(w.tonic + base + w.r[h] + off) or tok
    end
    out[#out + 1] = table.concat(row, " ")
  end
  return table.concat(out, " ")
end

local function bars(n, fills)   -- drums: a bar pattern, with fills on chosen bars
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local function thin(str, n)     -- keep every nth step of a melody
  local out, i = {}, 0
  for tok in str:gmatch("%S+") do
    out[#out + 1] = (i % n == 0) and tok or "."
    i = i + 1
  end
  return table.concat(out, " ")
end

local function count(str) local n = 0 for _ in str:gmatch("%S+") do n = n + 1 end return n end

local W = {}
M.W = W

-- ---------------------------------------------------------------------------- habitats
-- 1 Sunny Meadow: C major, a bouncy canon-ish walk (C G Am Em F C F G).
W[1] = {name = "Sunny Meadow", tonic = 0, scale = "major", lb = 72, bpm = 116,
  prog = "1 1 5 5 6 6 3 3 4 4 1 1 4 5 1 1",
  hook = "3 . 5 1h . 5 3 . 5 . 3 . 1 . . . " ..
         "5 . 7 2h . 7 5 . 2h . 7 . 5 . . . " ..
         "6 . 1h 3h . 1h 6 . 3h . 1h . 6 . . . " ..
         "3 . 5 7 . 5 3 . 5 . 7 . 3 5 . . " ..
         "4 . 6 1h . 6 4 . 1h . 6 . 4 . . . " ..
         "3 . 5 1h . 3h 1h . 5 . 3 . 5 . . . " ..
         "4 . 6 1h . 6 4 . 5 . 7 2h . 7 5 . " ..
         "1h . . . 5 . 3 . 1 . . . . . . .",
  bpat = {"1 . . 1 . . 5 .", "1 . 8 . 5 . 3 ."}, bbase = 36,
  v = {
    {pats = {"1 . 3 . 5 . 8 .", "5 . 3 . 8 . 5 ."}, base = 72, wave = "square", duty = 0.125, vol = 0.08, rel = 0.06, pan = 0.25},
    {pats = {". . 5 . . 3 . .", ". 3 . . 5 . 3 ."}, base = 60, wave = "tri", vol = 0.13, rel = 0.09, pan = -0.2},
    {drums = bars("K . . . S . . . K . . . S . H .", {
       [4] = "K . . . S . . . K . S . S S S .", [8] = "K . S . K . S . K S K S C . C ."}), vol = 0.12}},
  fan = {"Sparky", "Sprout", "Snooze"}}

-- 2 Spark Cave: A minor, moody and sparkling (Am F C G Am F Dm E).
W[2] = {name = "Spark Cave", tonic = 9, scale = "minor", lb = 60, bpm = 104,
  prog = "1 1 6 6 3 3 7 7 1 1 6 6 4 4 5M 5M",
  hook = "1 . 3 5 . 1h . 5 3 . 1 . . . . . " ..
         "6 . 1h 3h . 1h 6 . 3h . 1h . 6 . . . " ..
         "3 . 5 7 . 5 3 . 7 . 5 . 3 . . . " ..
         "7l . 2 4 . 2 7l . 4 . 2 . 7l . . . " ..
         "1 . 3 5 . 1h . 6 5 . 3 . 1 . . . " ..
         "6 . 1h . 3h . 1h . 6 . 3h . 1h . 6 . " ..
         "4 . 6 1h . 6 4 . 1h . 6 . 4 . . . " ..
         "5 . 7s 2h . 7s 5 . 2h . 7s . 5 . . .",
  bpat = {"1 . . . 5 . 1 .", "1 . 1 . . 5 . 8"}, bbase = 36,
  v = {
    {pats = {". . 3 . . 5 . 3", ". 5 . . 3 . 5 ."}, base = 60, wave = "square", duty = 0.25, vol = 0.10, rel = 0.05, pan = 0.25},
    {pats = {"8 . 5 . 3 . 5 .", "5 . 3 . 8 . 3 ."}, base = 72, wave = "sine", vol = 0.11, rel = 0.28, pan = -0.15},
    {drums = bars("H . H H . H C H H . H H . H C H", {
       [4] = "H . H H . H C H H H C H C C C C", [8] = "H H H H C . C . H H H H C C C C"}), vol = 0.09}},
  fan = {"Ember", "Mystic", "Giggle"}}

-- 3 Crystal Pond: G lydian, floating and watery (G A G D Em A Bm D-G).
W[3] = {name = "Crystal Pond", tonic = 7, scale = "lydian", lb = 60, bpm = 98,
  prog = "1 1 2 2 1 1 5 5 6 6 2 2 3 3 5 1",
  hook = "5 . 3 . 1h . 5 . 3 . 5 . 1h . . . " ..
         "6 . 4 . 2h . 6 . 4 . 6 . 2h . . . " ..
         "3 . 5 . 1h . 3h . 1h . 5 . 3 . . . " ..
         "5 . 7 . 2h . 7 . 5 . 7 . 2h . . . " ..
         "6 . 1h . 3h . 1h . 6 . 1h . 3h . . . " ..
         "2h . 6 . 4 . 6 . 2h . 4h . 6 . . . " ..
         "3 . 5 . 7 . 5 . 3 . 5 . 7 . 5 . " ..
         "5 . 7 . 2h . 7 . 1h . 5 . 3 . 1 .",
  bpat = {"1 . . . 5 . . .", "1 . . 1 . . 8 ."}, bbase = 36,
  v = {
    {pats = {"1 . . 5 . . 8 .", ". 3 . . 5 . 3 ."}, base = 72, wave = "sine", vol = 0.13, rel = 0.16, pan = 0.25},
    {pats = {"8 - - - - - 5 -", "5 - - - 3 - - -"}, base = 72, wave = "tri", vol = 0.10, rel = 0.3, att = 0.08, pan = -0.2},
    {drums = bars("K . . H . . H . . . . H . . H .", {
       [4] = "K . . H . . H . . . H H . H H H", [8] = "K . H H . H H . K . H H H H H H"}), vol = 0.07}},
  fan = {"Splash", "Skywing", "(tide)"}}

for i = 1, 3 do chords(W[i]) assert(count(W[i].hook) == 128, "hook " .. i) end

-- The chord under a step: root note (60..71), third and fifth in semitones above it. Sound only.
local function chord_at(w, step)
  local h = idiv(step % 128, 8) + 1
  local m = w.tonic + 60 + w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.t3[h], w.t5[h]
end

-- Habitats are 1..3 and gyms 4..6 in W; a note from the chord under a step.
function M.chord(id, step) return chord_at(W[id], step) end

local LADDER = {0, 1, 2, 12, 13, 14, 24}   -- 1 and 2 stand for the third and the fifth
function M.ladder(id, step, n)
  local root, t3, t5 = chord_at(W[id], step)
  local k = LADDER[n % 7 + 1]
  if k == 1 then return root + t3 elseif k == 2 then return root + t5
  elseif k == 13 then return root + 12 + t3 elseif k == 14 then return root + 12 + t5 end
  return root + k
end

local function track(str, wave, vol, rel, att, duty, pan)
  return {str, wave = wave, vol = vol, release = rel, attack = att or 0.003, duty = duty, pan = pan}
end

-- Which track a friend sings on, by friend id (see main.lua's MONS).
-- Ids as in MONS: Meadow Sparky 1, Sprout 2, Snooze 6; Cave Ember 3, Mystic 4, Giggle 7; Pond Splash 5, Skywing 8.
M.VOICE = {[1] = 4, [2] = 5, [6] = 6, [3] = 4, [4] = 5, [7] = 6, [5] = 4, [8] = 5}

function M.habitat(z, keep)
  local w = W[z]
  local v = w.v
  local pad = {"3 - - - - - - -", "5 - - - - - - -"}
  local t4, t5 = v[1], v[2]
  local third = v[3]
  local t6 = third.drums and track(third.drums, "noise", third.vol, 0.035, 0.003, nil, 0.15)
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    track(melody(w, w.hook), "square", 0.17, 0.05, 0.003, 0.25, -0.2),
    track(lay(w, w.bpat, w.bbase), "tri", 0.28, 0.06),
    track(lay(w, pad, 48), "sine", 0.09, 0.5, 0.12, nil, 0),
    track(lay(w, t4.pats, t4.base), t4.wave, t4.vol, t4.rel, t4.att, t4.duty, t4.pan),
    track(lay(w, t5.pats, t5.base), t5.wave, t5.vol, t5.rel, t5.att, t5.duty, t5.pan),
    t6}
end

-- ---------------------------------------------------------------------------- gyms
-- 4 Clover (Sunny Meadow): E dorian, a hopping stomp (Em A Em D G A D Bm-Em).
W[4] = {name = "Clover", tonic = 4, scale = "dorian", lb = 60, bpm = 150,
  prog = "1 1 4 4 1 1 7 7 3 3 4 4 7 7 5 1",
  hook = "1 . 3 5 . 1h 5 . 3 . 5 . 1h . . . " ..
         "4 . 6 1h . 6 4 . 1h . 6 . 4 . . . " ..
         "5 . 1h 3h . 1h 5 . 3 . 5 . 1h . . . " ..
         "7 . 2h 4h . 2h 7 . 4h . 2h . 7 . . . " ..
         "3 . 5 7 . 5 3 . 7 . 5 . 3 . . . " ..
         "6 . 1h 4h . 1h 6 . 4h . 1h . 6 . . . " ..
         "4h . 2h 7 . 2h 4h . 7 . 2h . 4h . . . " ..
         "5 . 7 2h . 7 5 . 1h . 5 . 3 . 1 ."}
-- 5 Glint (Spark Cave): D minor, a syncopated chase (Dm Bb F C Dm Bb Gm A).
W[5] = {name = "Glint", tonic = 2, scale = "minor", lb = 60, bpm = 156,
  prog = "1 1 6 6 3 3 7 7 1 1 6 6 4 4 5M 5M",
  hook = "1 . . 1 3 . 5 . 1h . 5 . 3 . 1 . " ..
         "6 . . 6 1h . 3h . 1h . 6 . 3h . 1h . " ..
         "3 . . 3 5 . 7 . 5 . 3 . 7 . 5 . " ..
         "7 . . 7 2h . 4h . 2h . 7 . 4h . 2h . " ..
         "1 . . 1 3 . 5 . 6 . 5 . 3 . 1 . " ..
         "6 . . 6 1h . 3h . 4h . 3h . 1h . 6 . " ..
         "4 . . 4 6 . 1h . 6 . 4 . 1h . 6 . " ..
         "5 . 7s 2h . 7s 5 . 2h . 7s . 5 . . ."}
-- 6 Ripple (Crystal Pond): G minor, a rolling tide (Gm Cm Eb D Gm Cm F D-Gm).
W[6] = {name = "Ripple", tonic = 7, scale = "minor", lb = 60, bpm = 162,
  prog = "1 1 4 4 6 6 5M 5M 1 1 4 4 7 7 5M 1",
  hook = "1 . 3 . 5 . 3 . 1h . 5 . 3 . 1 . " ..
         "4 . 6 . 1h . 6 . 4h . 1h . 6 . 4 . " ..
         "6 . 1h . 3h . 1h . 6 . 1h . 3h . 1h . " ..
         "5 . 7s . 2h . 7s . 5 . 7s . 2h . 7s . " ..
         "1 . 3 . 5 . 1h . 3h . 1h . 5 . 3 . " ..
         "4 . 6 . 1h . 3h . 4h . 3h . 1h . 6 . " ..
         "7 . 2h . 4h . 2h . 7 . 2h . 4h . 2h . " ..
         "5 . 7s . 2h . 7s . 1h . 5 . 3 . 1 ."}
for i = 4, 6 do chords(W[i]) assert(count(W[i].hook) == 128, "hook " .. i) end

local G_BASS = {{"1 . . . 1 . . .", "1 . . . 5 . . ."}, {"1 . 1 . 5 . 1 .", "1 . 1 . 8 . 5 ."},
                {"1 1 8 1 5 5 8 5", "1 1 8 1 5 8 5 3"}}
local G_STAB = {{". . . . . . . ."}, {". . 3 . . 5 3 .", ". . 5 . . 3 5 ."}, {". 3 . 3 . 5 . 3", ". 5 . 5 . 3 . 5"}}
local G_ARP = {{". . . . . . . ."}, {"1 . 3 . 5 . 3 .", "5 . 3 . 1 . 3 ."}, {"1 3 5 8 5 3 5 3", "8 5 3 5 1 3 5 8"}}
local G_DRUM = {
  bars("K . . . S . . . K . . . S . . .", {[4] = "K . . . S . . . K . S . S . S .", [8] = "K . . . S . . . K . S . K S S S"}),
  bars("K . H . S . H . K . H K S . H .", {[4] = "K . H . S . H . K S S H C . . .", [8] = "K . S . K S S S K . S . C . . ."}),
  bars("K H K H S H K H K K S H S . S S", {[2] = "K H K H S H K H K K S S K S S C", [4] = "K S K S S H S S K K S S K S S C",
       [8] = "K S K S K S S S K K S S C C C C"})}
local CACHE = {}

-- Gym song gi (1..3), section sec (1 strong .. 3 nearly beaten). Same length and tempo in every section.
function M.gym(gi, sec, keep)
  local key = gi * 10 + sec
  local s = CACHE[key]
  if not s then
    local w = W[3 + gi]
    local hook = melody(w, w.hook)
    s = {bpm = w.bpm, steps = 4,
      track(sec == 1 and thin(hook, 4) or hook, "square", 0.19, 0.04, 0.003, 0.25, -0.2),
      track(lay(w, G_BASS[sec], 36), "tri", 0.30, 0.04, 0.002),
      track(lay(w, G_STAB[sec], 60), "square", 0.09, 0.05, 0.003, 0.125, 0.25),
      track(lay(w, G_ARP[sec], 72), "square", 0.07, 0.05, 0.003, 0.125, 0.15),
      track(G_DRUM[sec], "noise", 0.14, 0.03, 0.003, nil, 0.15),
      track(lay(w, {"3 - - - - - - -", "5 - - - - - - -"}, 48), "sine", 0.09, 0.4, 0.1, nil, 0)}
    CACHE[key] = s
  end
  s.keep = keep or nil
  return s
end

-- ---------------------------------------------------------------------------- the fanfare (a gym is won)
local FAN = {
  "C5 . E5 . G5 . C6 - - . B5 . C6 . D6 . E6 - - - C6 . G5 . E5 . G5 . C6 - - . ",
  "G4 . C5 . E5 . G5 - - . F5 . E5 . F5 . G5 - - - E5 . C5 . G4 . C5 . E5 - - . ",
  "C3 - G2 - C3 - E3 - F2 - C3 - G2 - D3 - C3 - G2 - A2 - E2 - F2 - G2 - C3 - - . ",
  "K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . "}
function M.fanfare(gi)
  local t = W[3 + gi].tonic
  return {bpm = 144, steps = 4,
    {tr(FAN[1], t), wave = "square", vol = 0.20, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
    {tr(FAN[2], t), wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.13, release = 0.04}}
end

-- ---------------------------------------------------------------------------- the field book
local function hold8(notes)
  local t = {}
  for i, n in ipairs(notes) do t[i] = n .. " - - - - - - -" end
  return table.concat(t, " ")
end
local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end

-- A music box over a slow C bed (C F G C), 4 bars of 16 steps.
function M.book()
  return {bpm = 88, steps = 4,
    {"E5 . G5 . C6 . G5 . E5 . G5 . A5 . . . " ..
     "F5 . A5 . C6 . A5 . F5 . A5 . G5 . . . " ..
     "G5 . B5 . D6 . B5 . G5 . B5 . C6 . . . " ..
     "E5 . G5 . C6 . E6 . D6 . C6 . G5 . . . ",
     wave = "sine", vol = 0.17, release = 0.5, attack = 0.004, pan = -0.1},
    {hold8({"E4", "C4", "F4", "C4", "G4", "D4", "E4", "G4"}),
     wave = "tri", vol = 0.09, release = 0.4, attack = 0.08, pan = 0.1},
    {hold8({"C2", "G2", "F2", "C3", "G2", "D3", "C3", "G2"}),
     wave = "tri", vol = 0.19, release = 0.3, attack = 0.01},
    {rep(". . H . . . H .", 8), wave = "noise", vol = 0.04, release = 0.04, pan = 0.2}}
end

-- ---------------------------------------------------------------------------- the story
-- Night, a falling star (tracks 1 2: Am F C G), the monsters wake (3: a skipping tune), Hoot's theme (4).
function M.story()
  return {bpm = 100, steps = 4,
    {"A5 . E6 . A6 . E6 . C6 . E6 . A5 . E6 . " ..
     "A5 . F6 . C6 . F6 . A5 . C6 . F6 . C6 . " ..
     "G5 . C6 . E6 . C6 . G5 . E6 . G6 . E6 . " ..
     "G5 . D6 . G6 . D6 . B5 . D6 . G5 . D6 . ",
     wave = "sine", vol = 0.13, release = 0.45, attack = 0.004, pan = 0.15},
    {"A2 . . . A2 . E3 . A2 . . . A2 . E3 . " ..
     "F2 . . . F2 . C3 . F2 . . . F2 . C3 . " ..
     "C3 . . . C3 . G3 . C3 . . . C3 . G3 . " ..
     "G2 . . . G2 . D3 . G2 . . . G2 . D3 . ",
     wave = "tri", vol = 0.22, release = 0.1, attack = 0.004},
    {". . . . E5 . . E5 . . G5 . . . . . " ..
     ". . . . C5 . . C5 . . A5 . . . . . " ..
     ". . . . G5 . . G5 . . E5 . . . . . " ..
     ". . . . D5 . . D5 . . B5 . . . . . ",
     wave = "tri", vol = 0.15, release = 0.07, attack = 0.003, pan = -0.2},
    {"A4 . C5 . E5 - - . C5 . E5 . A5 - - . " ..
     "A4 . C5 . F5 - - . C5 . F5 . A5 - - . " ..
     "G4 . C5 . E5 - - . C5 . E5 . G5 - - . " ..
     "G4 . B4 . D5 - - . B4 . D5 . G5 - - . ",
     wave = "square", vol = 0.15, release = 0.12, attack = 0.004, duty = 0.25, pan = 0.1}}
end

return M
