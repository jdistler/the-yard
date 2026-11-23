-- Dig's music. Five cave worlds, one per garden plot (carrot, turnip, mushroom, pineapple, pumpkin), each a
-- real 8-bar arrangement (128 steps, 16 steps to a bar, 4 steps to a beat), plus a "hunt" section that the song
-- keeps (music.play{keep = true}) when one critter is left, a fanfare, the party, the garden tune and the story.
--
-- Tracks (1-based, as in music.track), the same in every world and every section:
--   1 lead (the hook)   2 counter-stabs   3 bass   4 shimmer (arp)   5 drums   6 pad
-- The game brings them in by what is happening (main.lua): tunnelling alone is bass + pad + shimmer + a soft
-- lead; a critter close turns on drums and stabs; a pop streak lifts the lead. Every part is written to be a
-- good song with any subset on. Nothing here is read by the game rules: only sound.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (floor(m / 12) - 1) end
local PC = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function mid(s)
  local l, a, o = s:match("^([A-G])([#b]?)(%d)$")
  return PC[l] + (a == "#" and 1 or a == "b" and -1 or 0) + (tonumber(o) + 1) * 12
end
-- Move every note in a track string by some semitones (drums and rests are untouched).
local function tr(str, semis)
  if semis == 0 then return str end
  return (str:gsub("([A-G][#b]?)(%d)", function(n, o) return nm(mid(n .. o) + semis) end))
end

-- Half-bar chords (16 per song): bass note + quality (M major, m minor). 8 steps each.
local OFF = {["1"] = 0, ["5"] = 7, ["8"] = 12}
local function parse_roots(s)
  local r, q = {}, {}
  for tok in s:gmatch("%S+") do
    local n, k = tok:match("^([A-G][#b]?%d)([Mm])$")
    r[#r + 1], q[#q + 1] = mid(n), (k == "M") and 4 or 3
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

local function bars(n, fills)   -- drums: normal bars with a fill on bars 4 and 8
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local W = {}
M.W = W

-- 1 Meadow Mine (carrot): bouncy G major, the original Dig tune.
W[1] = {name = "Meadow Mine", bpm = 142, tonic = 0,
  roots = "G2M G2M A2m D2M G2M C3M D2M G2M C3M B2m A2m E2m C3M D3M C3M G2M",
  lead = "G4 . B4 D5 . B4 G4 . D5 . B4 . G4 . . . " ..
   "A4 . C5 E5 . C5 A4 . D5 . B4 . G4 . . . " ..
   "G4 . B4 D5 . E5 F#5 . G5 . E5 D5 . B4 . . " ..
   "C5 . B4 A4 . G4 F#4 . G4 . D5 . G4 . . . " ..
   "E5 . G5 E5 . D5 C5 . D5 . F#5 D5 . C5 B4 . " ..
   "C5 . E5 C5 . B4 A4 . B4 . D5 . E5 . . . " ..
   "C5 . D5 E5 . F#5 G5 . A5 . G5 F#5 . E5 D5 . " ..
   "E5 . D5 C5 . B4 A4 . D5 . F#5 . G5 . . . ",
  counter = ". . . . G4 . . . B4 . . . D5 B4 G4 . " ..
   ". . . . A4 . . . F#4 . . . B4 G4 D4 . " ..
   ". . . . B4 . . . E5 . . . B4 . G4 . " ..
   "E4 . G4 F#4 . D4 . . B4 . G4 . D4 B4 G4 . " ..
   "G4 . C5 . G4 . E4 . F#4 . A4 . F#4 . D4 . " ..
   "E4 . G4 . E4 . C4 . G4 . B4 . G4 . E4 . " ..
   "E4 . G4 C5 . A4 B4 . C5 . B4 A4 . G4 F#4 . " ..
   "G4 . F#4 E4 . D4 C4 . F#4 . A4 . B4 . . . ",
  bass = "G2 . G3 . D3 . G2 . G2 . G3 . B2 . D3 . " ..
   "A2 . A3 . E3 . C3 . D3 . A2 . G2 . D3 . " ..
   "G2 . G3 . D3 . B2 . C3 . C4 . G3 . E3 . " ..
   "A2 . E3 . D3 . F#2 . G2 . D3 . G2 . B2 . " ..
   "C3 . C4 . G3 . E3 . B2 . B3 . F#3 . D3 . " ..
   "A2 . A3 . E3 . C3 . E2 . E3 . B2 . G2 . " ..
   "C3 . G2 . C3 . E3 . D3 . A2 . D3 . F#3 . " ..
   "C3 . G2 . A2 . E3 . D3 . F#2 . G2 . D3 . ",
  shim = ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . D6 B5 G5 . " ..
   "G5 . C6 . E6 . C6 . F#5 . B5 . D6 . B5 . " ..
   "E5 . A5 . C6 . A5 . G5 . B5 . E6 . B5 . " ..
   "G5 . C6 . E6 . C6 . A5 . D6 . F#6 . D6 . " ..
   "G5 . C6 . A5 . E6 . F#5 . A5 . G5 . . . ",
  drums = bars("K . H . S . H . K . H K S . H .", {
    [2] = "K . H . S . H . K . H . S . H H", [4] = "K . H . S . H . K S S H C . . .",
    [6] = "K . H . S . H . K . H . S . H H", [8] = "K . S . K S S S K . S . C . . ."}),
  hdrums = bars("K H H H S H H K K H H H S H K H", {
    [4] = "K H H H S H H H K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  hbass = {"1 . 8 1 . 5 8 1"}, hshim = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."}, shimbase = 60 + 12}

-- 2 Crystal Deep (turnip): mysterious D minor / F major groove.
W[2] = {name = "Crystal Deep", bpm = 146, tonic = -5,
  roots = "D2m C2M Bb2M D2m D2m C2M Bb2M D2m F2M G2m C3M D2m Bb2M C3M A2M D2m",
  lead = "D5 . F5 A5 . G5 F5 . E5 . G5 F5 . D5 . . " ..
   "C5 . E5 G5 . F5 E5 . D5 . F5 . A4 . . . " ..
   "D5 . F5 A5 . Bb5 A5 . G5 . E5 C5 . E5 . . " ..
   "F5 . G5 A5 . G5 E5 . D5 . A4 . D5 . . . " ..
   "F5 . A5 C6 . Bb5 A5 . G5 . Bb5 A5 . G5 F5 . " ..
   "E5 . G5 Bb5 . A5 G5 . F5 . A5 . D5 . . . " ..
   "Bb4 . D5 F5 . G5 A5 . G5 . E5 C5 . E5 G5 . " ..
   "A5 . G5 F5 . E5 C#5 . D5 . A4 . D5 . . . ",
  counter = ". . . . D5 . . . C5 . . . A4 F4 D4 . " ..
   ". . . . C5 . . . A4 . . . F4 D4 A4 . " ..
   ". . . . F5 . . . E5 . . . G4 . C5 . " ..
   "D5 . E5 F5 . E5 C#5 . A4 . F4 . D4 A4 F4 . " ..
   "A4 . C5 . F5 . C5 . Bb4 . D5 . G5 . D5 . " ..
   "G4 . Bb4 . E5 . C5 . A4 . D5 . F5 . A4 . " ..
   "D4 . F4 Bb4 . D5 F5 . E5 . C5 G4 . C5 E5 . " ..
   "F5 . E5 D5 . C#5 A4 . F4 . A4 . D5 . . . ",
  bass = "D2 . D3 . A2 . F2 . C2 . C3 . G2 . E2 . " ..
   "Bb2 . F2 . C3 . G2 . D2 . A2 . D2 . F2 . " ..
   "D2 . D3 . A2 . F2 . C2 . C3 . G2 . E2 . " ..
   "Bb2 . F2 . A2 . E2 . D2 . A2 . D2 . F2 . " ..
   "F2 . F3 . C3 . A2 . G2 . G3 . D3 . Bb2 . " ..
   "C3 . G2 . E2 . C2 . D2 . A2 . D3 . A2 . " ..
   "Bb2 . F2 . Bb2 . D3 . C3 . G2 . C3 . E3 . " ..
   "A2 . E2 . A2 . C#3 . D2 . A2 . D2 . . . ",
  shim = ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . A5 F5 D5 . " ..
   "A5 . C6 . F6 . C6 . Bb5 . D6 . G6 . D6 . " ..
   "G5 . Bb5 . E6 . C6 . A5 . D6 . F6 . D6 . " ..
   "F5 . Bb5 . D6 . Bb5 . G5 . C6 . E6 . C6 . " ..
   "A5 . E6 . G6 . E6 . F6 . D6 . A5 . . . ",
  drums = bars("K . H . S . H . K . H K S . H .", {
    [2] = "K . H . S . H . K . H . S . H H", [4] = "K . H . S . H . K S S H C . . .",
    [6] = "K . H . S . H . K . H . S . H H", [8] = "K . S . K S S S K . S . C . . ."}),
  hdrums = bars("K H H H S H H K K H H H S H K H", {
    [4] = "K H H H S H H H K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  hbass = {"1 . 8 1 . 5 8 1"}, hshim = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."}, shimbase = 60 + 12}

-- 3 Mushroom Grove (mushroom): bouncy C major, a little skip in the step.
W[3] = {name = "Mushroom Grove", bpm = 128, tonic = 5,
  roots = "C3M C3M A2m A2m F2M F2M G2M G2M C3M C3M E2m E2m F2M F2M G2M G2M",
  lead = "E5 . G5 . E5 . C5 . D5 . E5 . G5 . . . " ..
   "A5 . G5 . E5 . C5 . E5 . D5 . C5 . . . " ..
   "A5 . C6 . A5 . F5 . G5 . A5 . C6 . . . " ..
   "B5 . A5 . G5 . D5 . G5 . A5 . B5 . . . " ..
   "C6 . B5 . G5 . E5 . G5 . E5 . C5 . . . " ..
   "G5 . E5 . B4 . E5 . G5 . B5 . G5 . . . " ..
   "F5 . A5 . C6 . A5 . C6 . D6 . C6 . A5 . " ..
   "B5 . D6 . B5 . G5 . A5 . B5 . C6 . D6 . ",
  cpat = {". . 5 . . 3 . .", ". 3 . . 5 . 3 ."}, cbase = 24,
  bpat = {"1 . . . 5 . 8 .", "1 . 8 . 5 . 3 ."},
  spat = {". . . . . . . .", ". . . . . . . ."},
  drums = bars("K . H . . . S . . K H . S . H .", {
    [4] = "K . H . . . S . . K H . S S S .", [8] = "K . H . S . S . K . S . S S S S"}),
  hdrums = bars("K . H H . H S . K . H H S . H H", {
    [4] = "K . H H . H S . K K S S S S C .", [8] = "K S K S K S S S K K S S C C C C"}),
  hbass = {"1 . 1 . 5 . 8 5"}, hshim = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 3 5"}, shimbase = 60 + 24,
  shim5 = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 5 ."}}

-- 4 Ember Deep (pineapple): driving A minor funk with a hot turnaround on E.
W[4] = {name = "Ember Deep", bpm = 150, tonic = 2,
  roots = "A2m A2m A2m A2m F2M F2M G2M G2M A2m A2m A2m A2m F2M F2M E2M E2M",
  lead = "A4 . . A4 C5 . E5 . A5 . . G5 E5 . C5 . " ..
   "A4 . . A4 C5 . E5 . D5 . C5 . B4 . A4 . " ..
   "F4 . . F4 A4 . C5 . F5 . . E5 C5 . A4 . " ..
   "G4 . . G4 B4 . D5 . G5 . . F5 D5 . B4 . " ..
   "E5 . . E5 A5 . C6 . B5 . A5 . E5 . C5 . " ..
   "A5 . G5 . E5 . C5 . E5 . G5 . A5 . . . " ..
   "A5 . . C6 A5 . F5 . G5 . A5 . C6 . . . " ..
   "B5 . G#5 . E5 . B4 . G#4 . B4 . E5 . . . ",
  cpat = {". . . 5 . . 3 .", ". 3 . 5 . . 8 ."}, cbase = 24,
  bpat = {"1 . . 1 . . 8 .", "1 . 1 . . 5 . 8"},
  spat = {". . . . . . . .", ". . . . . . . ."},
  drums = bars("K . H K . H S . . K H K . H S H", {
    [4] = "K . H K . H S . . K H K S S S S", [8] = "K . S . K S S S K . S . C . . ."}),
  hdrums = bars("K H H K H H S H K K H K H H S H", {
    [4] = "K H H K S H S S K K S S S S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  hbass = {"1 1 . 1 . 8 1 5"}, hshim = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."}, shimbase = 60 + 24,
  shim5 = {"1 . 5 . 8 . 5 ."}}

-- 5 Crown Cave (pumpkin, the last cave of a row): a bright marching D major.
W[5] = {name = "Crown Cave", bpm = 120, tonic = -5,
  roots = "D3M D3M B2m B2m G2M G2M A2M A2M D3M D3M B2m B2m G2M G2M A2M A2M",
  lead = "D5 . F#5 . A5 . F#5 . D6 . . . A5 . . . " ..
   "B5 . A5 . F#5 . D5 . F#5 . . . B4 . . . " ..
   "G5 . B5 . D6 . B5 . G5 . . . D5 . . . " ..
   "A5 . C#6 . E6 . C#6 . A5 . . . E5 . . . " ..
   "F#6 . . E6 D6 . . A5 F#5 . . A5 D6 . . . " ..
   "D6 . . B5 F#5 . . B5 D6 . F#6 . D6 . B5 . " ..
   "G5 . A5 . B5 . D6 . G6 . . F#6 E6 . D6 . " ..
   "E6 . . D6 C#6 . . B5 A5 . C#6 . E6 . . . ",
  cpat = {"3 . . . 5 . . .", "3 . 5 . 3 . 5 ."}, cbase = 24,
  bpat = {"1 . 5 . 1 . 5 .", "1 . 5 . 8 . 5 ."},
  spat = {". . . . . . . .", ". . . . . . . ."},
  drums = bars("K . H . S . H . K . H . S . H .", {
    [4] = "K . H . S . H . K . S . S S S S", [8] = "K . S . K . S . K S K S K S C C"}),
  hdrums = bars("K H H H S H H H K H K H S H S H", {
    [4] = "K H H H S H S S K K S S S S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  hbass = {"1 . 5 1 . 5 8 5"}, hshim = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."}, shimbase = 60 + 24,
  shim5 = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 5 ."}}

-- 6 The Harvest Party (every five caves): an F major polka, oom-pah.
W[6] = {name = "Harvest Party", bpm = 132, tonic = 0,
  roots = "F2M F2M C3M C3M F2M F2M Bb2M Bb2M F2M F2M C3M C3M D3m D3m C3M F2M",
  lead = "A5 . F5 . A5 . C6 . A5 . F5 . A5 . . . " ..
   "G5 . E5 . G5 . C6 . G5 . E5 . G5 . . . " ..
   "A5 . C6 . F6 . C6 . A5 . F5 . A5 . . . " ..
   "D6 . Bb5 . D6 . F6 . D6 . Bb5 . D6 . . . " ..
   "C6 . A5 . C6 . F6 . E6 . D6 . C6 . . . " ..
   "E6 . G5 . E6 . C6 . G5 . C6 . E6 . . . " ..
   "D6 . F6 . A5 . D6 . F6 . D6 . A5 . . . " ..
   "G5 . C6 . E6 . G6 . F6 . . . A5 . . . ",
  cpat = {". . 3 . . . 5 .", ". . 5 . . . 3 ."}, cbase = 24,
  bpat = {"1 . . . 5 . . .", "1 . . . 5 . 8 ."},
  spat = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 3 ."},
  drums = bars("K . H . S . H . K . H . S . H H", {
    [4] = "K . H . S . H . K S K S K S C C", [8] = "K . S . K S K S K S K S C C C C"}),
  hdrums = bars("K H K H S H K H K H K H S H S H", {}),
  hbass = {"1 . 5 . 1 . 5 ."}, hshim = {"1 . 5 . 8 . 5 3"}, shimbase = 60 + 24,
  shim5 = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 5 ."}}

for i, w in ipairs(W) do
  w.r, w.q = parse_roots(w.roots)
  assert(#w.r == 16, "roots " .. i)
end

-- The chord under a step: its root as a note (60 to 71) and its third (3 or 4). Sound only.
function M.chord(wi, step)
  local w = W[wi]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- Rising chord-tone ladder for a run: n = 0, 1, 2 ... climbs and then starts over an octave lower.
local LADDER = {0, 99, 7, 12, 99, 19, 24}
function M.ladder(wi, step, n)
  local root, t3 = M.chord(wi, step)
  local k = n % 7
  local off = LADDER[k + 1]
  if off == 99 then off = (k == 1) and t3 or 12 + t3 end
  return root + off
end


-- The cave song for a world. hunt: the section for the last critter (busier, nothing silent). keep: swing in.
function M.song(wi, hunt, keep)
  local w = W[wi]
  local pad = {"5 - - - - - - -", "3 - - - - - - -"}
  local lead, counter, bass, shim, drums
  lead = w.lead
  counter = w.counter or lay(w, w.cpat, w.cbase)
  if hunt then
    bass = lay(w, w.hbass, 0)
    shim = lay(w, w.hshim, w.shimbase)
    drums = w.hdrums
  else
    bass = w.bass or lay(w, w.bpat, 0)
    if w.shim then
      shim = w.shim
    else   -- silent for the first half, then the shimmer joins
      local half = {}
      for h = 1, 16 do half[h] = h <= 8 and ". . . . . . . ." or w.shim5[(h - 1) % #w.shim5 + 1] end
      shim = lay(w, half, w.shimbase)
    end
    drums = w.drums
  end
  local padstr = lay(w, pad, 24)
  local vol = w.name == "Harvest Party" and 1.15 or 1
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {lead, wave = "square", vol = 0.20 * vol, release = 0.045, attack = 0.003, duty = 0.25, pan = -0.2},
    {counter, wave = "square", vol = 0.12, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
    {bass, wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
    {shim, wave = "sine", vol = 0.10, release = 0.09, attack = 0.005, pan = 0.15},
    {drums, wave = "noise", vol = 0.14, release = 0.035, pan = 0.15},
    {padstr, wave = "sine", vol = 0.09, release = 0.5, attack = 0.12, pan = 0}}
end

-- Cave clear: the victory fanfare in the world's own key.
local FAN = {
  "G4 . B4 . D5 . G5 - - . F#5 . G5 . A5 . B5 - - - G5 . D5 . B4 . D5 . G5 - - . ",
  "D4 . G4 . B4 . D5 - - . C5 . B4 . C5 . D5 - - - B4 . G4 . D4 . G4 . B4 - - . ",
  "G2 - D3 - G2 - B2 - C3 - G2 - D3 - A2 - G2 - D3 - E2 - B2 - C3 - D3 - G2 - - . ",
  "K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . "}
function M.fanfare(wi)
  local t = W[wi].tonic
  return {bpm = 144, steps = 4,
    {tr(FAN[1], t), wave = "square", vol = 0.19, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
    {tr(FAN[2], t), wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.12, release = 0.04}}
end

-- The garden map between caves: a music box over a slow C major bed, 4 bars of 16 steps (64).
local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end
local function hold8(notes)   -- each note held for 8 steps
  local t = {}
  for i, n in ipairs(notes) do t[i] = n .. " - - - - - - -" end
  return table.concat(t, " ")
end
function M.garden()
  return {bpm = 96, steps = 4,
    {"E5 . G5 . C6 . G5 . E5 . G5 . A5 . . . " ..
     "F5 . A5 . C6 . A5 . F5 . A5 . G5 . . . " ..
     "E5 . G5 . C6 . E6 . D6 . C6 . A5 . G5 . " ..
     "D5 . G5 . B5 . D6 . C6 - - - . . . . ",
     wave = "sine", vol = 0.17, release = 0.5, attack = 0.004, pan = -0.1},
    {hold8({"E4", "C4", "C4", "E4", "A3", "C4", "B3", "E4"}),
     wave = "tri", vol = 0.10, release = 0.4, attack = 0.08, pan = 0.1},
    {hold8({"C2", "G2", "A2", "E2", "F2", "C3", "G2", "D3"}),
     wave = "tri", vol = 0.20, release = 0.3, attack = 0.01},
    {rep(". . H . . . H .", 8), wave = "noise", vol = 0.05, release = 0.04, pan = 0.2}}
end

-- The story: critters tiptoeing off with the veggies (tracks 1 2), then Diggy's hero theme (tracks 3 4)
-- comes in when he arrives. Am F C E, 4 bars of 16 steps, 104 bpm.
function M.story()
  return {bpm = 104, steps = 4,
    {". . A4 . . . C5 . . . E5 . . . C5 . " ..
     ". . F4 . . . A4 . . . C5 . . . A4 . " ..
     ". . E4 . . . G4 . . . C5 . . . G4 . " ..
     ". . E4 . . . G#4 . . . B4 . . . G#4 . ",
     wave = "tri", vol = 0.20, release = 0.07, attack = 0.003, pan = -0.15},
    {"A2 . . . . . A2 . E3 . . . A2 . . . " ..
     "F2 . . . . . F2 . C3 . . . F2 . . . " ..
     "C3 . . . . . C3 . G2 . . . C3 . . . " ..
     "E2 . . . . . E2 . B2 . . . E2 . . . ",
     wave = "tri", vol = 0.24, release = 0.1, attack = 0.004},
    {"C5 . E5 . G5 - - . E5 . G5 . C6 - - - " ..
     "A5 . C6 . A5 - - . F5 . A5 . C6 - - . " ..
     "G5 . E5 . C5 . E5 . G5 - - . E5 . C5 . " ..
     "B5 . G#5 . E5 . B5 . E6 - - - - - - - ",
     wave = "square", vol = 0.17, release = 0.12, attack = 0.004, duty = 0.25, pan = 0.1},
    {rep("K . . . S . . .", 7) .. " K . . . S . S S",
     wave = "noise", vol = 0.10, release = 0.04}}
end

return M
