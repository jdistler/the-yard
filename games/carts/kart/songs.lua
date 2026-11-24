-- Star Kart's music. Three track songs (one per track of the cup), each an 8-bar arrangement of 128 steps
-- (16 steps to a bar), in two sections the game switches between without a restart (music.play{keep = true}):
-- "verse" for the race and "final" for the last stretch. Plus a fanfare per track, a podium march, the map's
-- travelling tune, the garage/story themes.
--
-- Tracks (1-based, as in music.track), the same in every track and section:
--   1 lead (the hook)   2 counter-stabs   3 bass   4 drums   5 shimmer (arp)   6 pad
-- main.lua brings them in and out by race position and boost. Every part is written to sound right alone.
-- Nothing here is read by the game rules: only sound (game logic never reads music.step()).
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (floor(m / 12) - 1) end
local PC = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function mid(s)
  local l, a, o = s:match("^([A-G])([#b]?)(%d)$")
  return PC[l] + (a == "#" and 1 or a == "b" and -1 or 0) + (tonumber(o) + 1) * 12
end
local function tr(str, semis)   -- move every note by some semitones (drums and rests are untouched)
  if semis == 0 then return str end
  return (str:gsub("([A-G][#b]?)(%d)", function(n, o) return nm(mid(n .. o) + semis) end))
end

local OFF = {["1"] = 0, ["5"] = 7, ["8"] = 12}
-- A bar's chord, "C3M" or "C3M/G2M" (the second half different): two half-bars of 8 steps each.
local function parse_prog(prog)
  local r, q = {}, {}
  for tok in prog:gmatch("%S+") do
    local a, b = tok:match("^([^/]+)/(.+)$")
    a = a or tok
    b = b or a
    for _, t in ipairs({a, b}) do
      local n, k = t:match("^([A-G][#b]?%d)([Mm])$")
      r[#r + 1], q[#q + 1] = mid(n), (k == "M") and 4 or 3
    end
  end
  return r, q
end

local function lay(w, pats, base)   -- tokens 1 3 5 8 follow the half-bar's chord
  local out = {}
  for h = 1, 16 do
    local pat = pats[(h - 1) % #pats + 1]
    local row = {}
    for tok in pat:gmatch("%S+") do
      local o = OFF[tok]
      if tok == "3" then o = w.q[h] end
      row[#row + 1] = o and nm(w.r[h] + base + o) or tok
    end
    out[#out + 1] = table.concat(row, " ")
  end
  return table.concat(out, " ")
end

local function bars(n, fills)   -- drums: normal bars with fills on some
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local function count(s) local n = 0 for _ in s:gmatch("%S+") do n = n + 1 end return n end
local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end
local function hold8(notes)   -- each note held for 8 steps
  local t = {}
  for i, n in ipairs(notes) do t[i] = n .. " - - - - - - -" end
  return table.concat(t, " ")
end

local W = {}
M.W = W

-- 1 Meadow Circuit: sunny C major, a bouncy hook over C F G.
W[1] = {name = "Meadow Circuit", bpm = 148, tonic = 0,
  prog = "C3M F2M G2M C3M A2m F2M G2M G2M/C3M",
  lead = {"G5 . . E5 . G5 . C6 - - . B5 . G5 . .",
          "A5 . . F5 . A5 . C6 - - . A5 . F5 . .",
          "B5 . . G5 . B5 . D6 - - . C6 . B5 . .",
          "C6 . E6 . D6 . C6 . G5 . E5 . G5 - - .",
          "E5 . A5 . C6 . E6 - - . D6 . C6 . A5 .",
          "F5 . A5 . C6 . F6 - - . E6 . D6 . C6 .",
          "D6 . D6 B5 . G5 . B5 . D6 . G6 - - . .",
          "G6 . E6 . C6 . G5 . E5 . G5 . C6 - - ."},
  cpat = {". . 3 . . 5 . .", ". . 5 . . 3 . ."}, cbase = 24,
  bpat = {"1 . 1 . 5 . 8 .", "1 . 1 . 5 . 3 5"},
  spat = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 5 3"}, sbase = 36,
  drums = bars("K . H . S . H . K . H K S . H .", {
    [4] = "K . H . S . H . K S S H C . . .", [8] = "K . S . K S S S K . S . C . . ."})}

-- 2 Beach Boardwalk: a syncopated calypso G major (the 3-3-2 swing).
W[2] = {name = "Beach Boardwalk", bpm = 136, tonic = 7,
  prog = "G2M C3M D3M G2M E2m C3M D3M D3M/G2M",
  lead = {"B5 . . D6 . . B5 . G5 . B5 . D6 - - .",
          "C6 . . E6 . . C6 . G5 . C6 . E6 - - .",
          "D6 . . F#6 . . D6 . A5 . D6 . F#6 - - .",
          "G6 . . D6 . . B5 . D6 . G6 . B5 - - .",
          "B5 . . E6 . . B5 . G5 . B5 . E6 - - .",
          "G5 . . C6 . . E6 . C6 . G5 . E5 - - .",
          "A5 . . D6 . . F#6 . A6 . F#6 . D6 - - .",
          "D6 . C6 . B5 . A5 . G5 . A5 . B5 - - ."},
  cpat = {". . . 3 . . 5 .", ". . . 5 . . 3 ."}, cbase = 24,
  bpat = {"1 . . 1 . . 5 .", "1 . . 5 . . 8 ."},
  spat = {"1 . . 5 . . 8 .", "3 . . 5 . . 8 ."}, sbase = 36,
  drums = bars("K . . H . S . H K . H . . S . H", {
    [4] = "K . . H . S . H K . S . S S K C", [8] = "K . S . K . S S K S S . C C C C"})}

-- 3 Rainbow Skyway: a driving A minor, the night sky streaming past.
W[3] = {name = "Rainbow Skyway", bpm = 152, tonic = 9,
  prog = "A2m F2M C3M G2M A2m F2M D3m E2M",
  lead = {"E6 . . E6 A5 . C6 . E6 . . D6 C6 . A5 .",
          "F6 . . F6 A5 . C6 . F6 . . E6 C6 . A5 .",
          "G6 . . G6 C6 . E6 . G6 . . F6 E6 . C6 .",
          "D6 . . D6 G5 . B5 . D6 . . C6 B5 . G5 .",
          "A5 . C6 . E6 . A6 - - . G6 . E6 . C6 .",
          "A5 . C6 . F6 . A6 - - . G6 . F6 . C6 .",
          "A5 . D6 . F6 . A6 - - . G6 . F6 . D6 .",
          "G#5 . B5 . E6 . G#6 . B6 - - - E6 . . ."},
  cpat = {". 3 . . 5 . . .", ". 5 . . 3 . . ."}, cbase = 24,
  bpat = {"1 1 . 1 1 . 8 .", "1 1 . 1 5 . 8 ."},
  spat = {"1 . 5 . 8 . 5 .", "5 . 8 . 3 . 5 ."}, sbase = 36,
  drums = bars("K . H H K . H . K . H H S . H H", {
    [4] = "K . H H K . H . K S K S K S C C", [8] = "K S K S K S S S K S K S C C C C"})}

for i, w in ipairs(W) do
  w.r, w.q = parse_prog(w.prog)
  assert(#w.r == 16, "prog " .. i)
  assert(#w.lead == 8, "lead bars " .. i)
  for b = 1, 8 do assert(count(w.lead[b]) == 16, "lead " .. i .. " bar " .. b) end
  w.leadstr = table.concat(w.lead, " ")
end
M.COUNT = #W

-- The chord under a step: its root as a note (60 to 71) and its third (3 or 4). Sound only.
function M.chord(wi, step)
  if wi == 0 then return 60, 4 end   -- off the race: C major (the map, the podium and the story are all in C)
  local w = W[wi]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- A rising ladder over the chord under a step (root, third, fifth, octave, ...): a run of pickups is a melody.
-- n counts the run (1-based); it wraps after 7 notes. Sound only.
function M.ladder(wi, step, n)
  local root, t3 = M.chord(wi, step)
  local k = (max(n, 1) - 1) % 7
  local off = k == 0 and 0 or k == 1 and t3 or k == 2 and 7 or k == 3 and 12 or k == 4 and 12 + t3 or k == 5 and 19 or 24
  return root + 12 + off
end

local PAD = {"5 - - - - - - -", "3 - - - - - - -"}
-- The race song of a track. verse: the written parts. final: the section the song turns into for the last
-- stretch (same tune, busier everything, an arpeggio where the pad was).
function M.song(wi, final, keep)
  local w = W[wi]
  local pad = lay(w, PAD, 24)
  local lead, counter, bass, shim, drums, padw
  if final then
    lead = w.leadstr
    counter = lay(w, {"5 . 5 . 5 . 8 ."}, 24)
    bass = lay(w, {"1 . 8 . 1 . 8 5", "1 . 8 . 5 . 8 1"}, 0)
    shim = lay(w, {"8 5 8 5 8 5 8 3"}, 36)
    drums = bars("K H H K S H K H K H H K S H S S", {[4] = "K H H K S H S S K K S S K S C C", [8] = "K S K S K S S S K K S S C C C C"})
    padw = lay(w, {"1 3 5 8 5 3 5 8"}, 24)
  else
    lead = w.leadstr
    counter = lay(w, w.cpat, w.cbase)
    bass = lay(w, w.bpat, 0)
    shim = lay(w, w.spat, w.sbase)
    drums = w.drums
    padw = pad
  end
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {lead, wave = "square", vol = final and 0.19 or 0.17, release = 0.05, attack = 0.003, duty = 0.25, pan = -0.2},
    {counter, wave = "square", vol = 0.10, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
    {bass, wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
    {drums, wave = "noise", vol = 0.13, release = 0.035, pan = 0.15},
    {shim, wave = "sine", vol = 0.10, release = 0.09, attack = 0.005, pan = 0.15},
    {padw, wave = "sine", vol = final and 0.07 or 0.08, release = final and 0.12 or 0.5, attack = final and 0.004 or 0.12, pan = 0}}
end

-- The grid: the same song with the lead and drums waiting (the game raises them at GO).
-- A race finish fanfare in the track's key (written in C, moved by the tonic). Triumphant for the top three,
-- a warm "good race" when it was not.
local FAN = {
  "C5 . E5 . G5 . C6 - - . B5 . C6 . E6 - - - C6 . G5 . E5 . G5 . C6 - - . ",
  "G4 . C5 . E5 . G5 - - . F5 . E5 . G5 . G5 - - - E5 . C5 . G4 . C5 . E5 - - . ",
  "C3 - G2 - C3 - E3 - F2 - C3 - G2 - D3 - C3 - G2 - A2 - E2 - F2 - G2 - C3 - - . ",
  "K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . "}
local GOOD = {
  "E5 . . . G5 . . . A5 . . . G5 - - - F5 . . . E5 . . . D5 . . . C5 - - - ",
  "C4 . . . E4 . . . F4 . . . E4 - - - D4 . . . C4 . . . B3 . . . C4 - - - ",
  "C3 - - - C3 - - - F2 - - - C3 - - - G2 - - - A2 - - - G2 - - - C3 - - - ",
  "K . . . . . . . K . . . S . . . K . . . . . . . K . . . S . . . "}
function M.fanfare(wi, place)
  local t = W[wi].tonic
  if place and place > 3 then
    return {bpm = 112, steps = 4,
      {tr(GOOD[1], t), wave = "tri", vol = 0.20, release = 0.2, attack = 0.01, pan = -0.1},
      {tr(GOOD[2], t), wave = "sine", vol = 0.18, release = 0.3, attack = 0.02, pan = 0.2},
      {tr(GOOD[3], t), wave = "tri", vol = 0.24, release = 0.25, attack = 0.01},
      {GOOD[4], wave = "noise", vol = 0.08, release = 0.04}}
  end
  return {bpm = 150, steps = 4,
    {tr(FAN[1], t), wave = "square", vol = 0.19, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
    {tr(FAN[2], t), wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.12, release = 0.04}}
end

-- The map between races: a travelling tune in C (8 bars). Track 5 is the twinkle: the game raises it with the
-- stages done.
local MAP = {name = "map", bpm = 116, tonic = 0,
  lead = {"E5 . G5 . C6 . G5 . E5 . G5 . E5 . . .",
          "D5 . G5 . B5 . G5 . D5 . G5 . D5 . . .",
          "C5 . E5 . A5 . E5 . C5 . E5 . C5 . . .",
          "A4 . C5 . F5 . C5 . A4 . C5 . F5 - - .",
          "G5 . E5 . C6 . E6 - D6 . C6 . G5 . E5 .",
          "B5 . D6 . G6 - - . D6 . B5 . G5 . . .",
          "A5 . C6 . F6 - - . E6 . C6 . A5 . . .",
          "D6 . B5 . G5 . B5 . D6 - - . . . . ."}}
MAP.prog = "C3M C3M G2M G2M A2m A2m F2M F2M C3M C3M G2M G2M F2M F2M G2M G2M"
MAP.r, MAP.q = parse_prog(MAP.prog)
function M.map()
  local w = MAP
  assert(#w.lead == 8)
  for b = 1, 8 do assert(count(w.lead[b]) == 16, "map lead " .. b) end
  return {bpm = w.bpm, steps = 4,
    {table.concat(w.lead, " "), wave = "tri", vol = 0.22, release = 0.12, attack = 0.006, pan = -0.1},
    {lay(w, {". . 3 . . . 5 .", ". . 5 . . . 3 ."}, 24), wave = "square", vol = 0.08, release = 0.05, duty = 0.125, pan = 0.2},
    {lay(w, {"1 . . . 5 . . .", "1 . . . 5 . 8 ."}, 0), wave = "tri", vol = 0.26, release = 0.1, attack = 0.005},
    {bars("H . . H H . . H H . . H H . H H", {}), wave = "noise", vol = 0.06, release = 0.03, pan = 0.15},
    {lay(w, {"8 . . . 5 . . . 3 . . . 5 . . ."}, 36), wave = "sine", vol = 0.09, release = 0.4, attack = 0.003, pan = 0.25}}
end

-- The podium: a march in C (8 bars). Tracks come in as the racers reach their steps (the game).
local POD = {prog = "C3M F2M C3M G2M A2m F2M G2M C3M",
  lead = {"C5 . . C5 E5 . G5 - C6 - - . G5 . E5 .",
          "F5 . . F5 A5 . C6 - F6 - - . C6 . A5 .",
          "E6 . . D6 C6 . G5 - E5 . G5 . C6 - - .",
          "D6 . . D6 B5 . G5 - D6 - - . G6 - - .",
          "A5 . . C6 E6 . A6 - G6 - - . E6 . C6 .",
          "F6 . . E6 D6 . C6 - A5 . C6 . F6 - - .",
          "G6 . . F6 E6 . D6 . C6 . D6 . B5 - - .",
          "C6 - - - E6 - - - G6 - - - C7 - - -"}}
POD.r, POD.q = parse_prog(POD.prog)
function M.podium()
  local w = POD
  assert(#w.lead == 8)
  for b = 1, 8 do assert(count(w.lead[b]) == 16, "podium lead " .. b) end
  return {bpm = 118, steps = 4,
    {table.concat(w.lead, " "), wave = "square", vol = 0.17, release = 0.08, attack = 0.004, duty = 0.25, pan = -0.15},
    {lay(w, {"5 . 5 . 3 . 5 .", "5 . 8 . 5 . 3 ."}, 24), wave = "tri", vol = 0.15, release = 0.1, attack = 0.005, pan = 0.2},
    {lay(w, {"1 . 8 . 5 . 8 .", "1 . 1 . 5 . 8 5"}, 0), wave = "tri", vol = 0.28, release = 0.08, attack = 0.004},
    {bars("K . . H S . . H K . K H S . H C", {[4] = "K . S . K S K S K S K S C C C C", [8] = "K . S . K S K S K S K S C C C C"}),
     wave = "noise", vol = 0.12, release = 0.04, pan = 0.1},
    {lay(w, {"8 . 5 . 8 . 5 . 8 . 3 . 5 . 8 ."}, 36), wave = "sine", vol = 0.09, release = 0.35, attack = 0.003, pan = 0.25},
    {lay(w, PAD, 24), wave = "sine", vol = 0.08, release = 0.5, attack = 0.1}}
end

-- The garage and the story: a comet falls (tracks 1 and 2, high bells over a hush: Am F C E), then the
-- racers' theme (3 and 4) comes in when they line up. 4 bars of 16 steps, 104 bpm. The garage plays the same
-- with everything in.
function M.story()
  return {bpm = 104, steps = 4,
    {"E6 . . . D6 . . . C6 . A5 . E5 . . . " ..
     "C6 . . . A5 . . . F5 . A5 . C6 . . . " ..
     "G5 . . . E5 . . . C5 . E5 . G5 . . . " ..
     "B5 . . . G#5 . . . E5 . G#5 . B5 . . . ",
     wave = "sine", vol = 0.17, release = 0.4, attack = 0.004, pan = -0.15},
    {"A2 . . . . . A2 . E3 . . . A2 . . . " ..
     "F2 . . . . . F2 . C3 . . . F2 . . . " ..
     "C3 . . . . . C3 . G2 . . . C3 . . . " ..
     "E2 . . . . . E2 . B2 . . . E2 . . . ",
     wave = "tri", vol = 0.22, release = 0.1, attack = 0.004},
    {"C5 . E5 . G5 - - . E5 . G5 . C6 - - - " ..
     "A5 . C6 . A5 - - . F5 . A5 . C6 - - . " ..
     "G5 . E5 . C5 . E5 . G5 - - . E5 . C5 . " ..
     "B5 . G5 . D6 - - . G6 - - - - - - - ",
     wave = "square", vol = 0.15, release = 0.12, attack = 0.004, duty = 0.25, pan = 0.1},
    {rep("K . . . S . . .", 7) .. " K . . . S . S S",
     wave = "noise", vol = 0.10, release = 0.04}}
end

return M
