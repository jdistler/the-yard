-- Chomp's music. Six maze worlds, each a real 8-bar arrangement (128 steps, 16 steps to a bar, 4 steps to a beat),
-- plus a "blue" section that the song keeps (music.play{keep = true}) when the ghosts turn blue, a fanfare per
-- world, the star map's music box and the story.
--
-- Tracks (1-based, as in music.track), the same in every world and every section:
--   1 lead (the hook)   2 counter-stabs   3 bass   4 shimmer (arp)   5 drums   6 pad
-- The game brings them in by how many dots are eaten (main.lua): a fresh maze is bass + pad, then the shimmer,
-- the drums, the stabs and at last the lead. Every part is written to be a good song with any subset on.
-- Nothing here is read by the game rules: only sound.
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

local W = {}
M.W = W

-- 1 Night Garden: bouncy C major, the classic hook.
W[1] = {name = "Night Garden", bpm = 144, tonic = 0,
  prog = "C3M A2m F2M G2M C3M A2m F2M G2M/C3M",
  lead = {"E5 . G5 E5 . C5 E5 . G5 . C6 . G5 . . .",
          "E5 . A5 E5 . C5 E5 . A5 . C6 . A5 . . .",
          "F5 . A5 F5 . C5 F5 . A5 . C6 . A5 . . .",
          "D5 . G5 D5 . B4 D5 . G5 . B5 . D6 . . .",
          "E5 . G5 C6 . B5 A5 . G5 . E5 . C5 . . .",
          "C5 . E5 A5 . G5 E5 . C5 . E5 . A4 . . .",
          "A5 . C6 A5 . F5 A5 . C6 . F6 . C6 . . .",
          "D6 . B5 . G5 . B5 . C6 . . . G5 . E5 C5"},
  cpat = {". . 3 . . . 5 .", ". . 5 . . . 3 ."}, cbase = 24,
  bpat = {"1 . 8 . 5 . 8 1", "1 . 8 . 5 . 3 5"},
  spat = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 5 3"}, sbase = 36,
  drums = bars("K . H . S . H . K . H K S . H .", {
    [4] = "K . H . S . H . K S S H C . . .", [8] = "K . S . K S S S K . S . C . . ."})}

-- 2 Firefly Meadow: a gentle G major sway.
W[2] = {name = "Firefly Meadow", bpm = 132, tonic = 7,
  prog = "G2M E2m C3M D3M G2M E2m C3M D3M/G2M",
  lead = {"B4 . D5 . G5 . D5 . B4 . D5 . G5 - - .",
          "B4 . E5 . G5 . E5 . B4 . E5 . G5 - - .",
          "C5 . E5 . G5 . E5 . C5 . E5 . G5 - - .",
          "A4 . D5 . F#5 . D5 . A4 . D5 . F#5 . A5 .",
          "G5 . F#5 G5 . A5 B5 . D6 . B5 . G5 - - .",
          "E5 . D5 E5 . G5 B5 . A5 . G5 . E5 - - .",
          "E5 . G5 C6 . B5 A5 . G5 . E5 . G5 - - .",
          "F#5 . A5 . D6 . C6 . B5 . . . G5 - - ."},
  cpat = {". . . . 3 . . .", ". . . . 5 . . ."}, cbase = 24,
  bpat = {"1 . . . 5 . . .", "1 . . . 5 . 8 ."},
  spat = {"1 . 3 . 5 . 3 .", "1 . 5 . 8 . 5 ."}, sbase = 36,
  drums = bars("K . . . S . H . K . H . S . H .", {
    [4] = "K . . . S . H . K . S . S H S C", [8] = "K . H . S . H . K . S S K S S C"})}

-- 3 Plum Moonlight: a moody A minor, the moon coming up.
W[3] = {name = "Plum Moonlight", bpm = 138, tonic = 9,
  prog = "A2m F2M C3M G2M A2m F2M D3m E2M",
  lead = {"E5 . . A5 . C6 . B5 . A5 . E5 - - . .",
          "C5 . . F5 . A5 . G5 . F5 . C5 - - . .",
          "E5 . . G5 . C6 . B5 . G5 . E5 - - . .",
          "D5 . . G5 . B5 . A5 . G5 . D5 - - . .",
          "A5 . C6 . E6 . D6 . C6 . A5 . E5 . A5 .",
          "A5 . C6 . F6 . E6 . C6 . A5 . F5 - - .",
          "A5 . D6 . F6 . E6 . D6 . A5 . F5 . A5 .",
          "G#5 . B5 . E6 . D6 . B5 . G#5 . B5 - - ."},
  cpat = {". 3 . . . 5 . .", ". 5 . . . 3 . ."}, cbase = 24,
  bpat = {"1 . . 1 . . 5 .", "1 . . 5 . . 8 ."},
  spat = {"1 . 5 . 3 . 8 .", "5 . 8 . 3 . 5 ."}, sbase = 36,
  drums = bars("K . . H S . H . K . H H S . H .", {
    [4] = "K . . H S . H . K . S . S S K C", [8] = "K . S . K . S S K S S . C C C C"})}

-- 4 Candy Lane: a hopping F major polka.
W[4] = {name = "Candy Lane", bpm = 152, tonic = 5,
  prog = "F2M Bb2M C3M F2M F2M Bb2M C3M C3M/F2M",
  lead = {"A5 . F5 . A5 . C6 . A5 . F5 . A5 . . .",
          "D6 . Bb5 . D6 . F6 . D6 . Bb5 . D6 . . .",
          "C6 . G5 . C6 . E6 . C6 . G5 . E5 . . .",
          "A5 . C6 . F6 . C6 . A5 . F5 . A5 . . .",
          "C6 . A5 . C6 . F6 . E6 . D6 . C6 . . .",
          "D6 . Bb5 . D6 . F6 . D6 . C6 . Bb5 . . .",
          "E6 . C6 . G5 . C6 . E6 . G6 . E6 . . .",
          "E6 . D6 . C6 . A5 . F5 . A5 . C6 - - ."},
  cpat = {". . 3 . . . 5 .", ". . 5 . . . 3 ."}, cbase = 24,
  bpat = {"1 . . . 5 . . .", "1 . . . 5 . 8 ."},
  spat = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 3 ."}, sbase = 36,
  drums = bars("K . H . S . H . K . H . S . H H", {
    [4] = "K . H . S . H . K S K S K S C C", [8] = "K . S . K S K S K S K S C C C C"})}

-- 5 Frost Cave: slow, glassy D minor.
W[5] = {name = "Frost Cave", bpm = 124, tonic = 2,
  prog = "D3m Bb2M F2M C3M D3m Bb2M G2m A2M",
  lead = {"A5 . . . F5 . A5 . D6 - - - A5 . . .",
          "Bb5 . . . D6 . F6 . D6 - - - Bb5 . . .",
          "A5 . . . C6 . F6 . C6 - - - A5 . . .",
          "G5 . . . C6 . E6 . G6 - - - E6 . . .",
          "F6 . E6 . D6 . A5 . F5 . A5 . D6 - - .",
          "D6 . C6 . Bb5 . F5 . D5 . F5 . Bb5 - - .",
          "D6 . Bb5 . G5 . Bb5 . D6 . G6 . F6 . D6 .",
          "E6 . C#6 . A5 . C#6 . E6 - - - A5 - - ."},
  cpat = {". . . . 5 . . 3", ". . . . 3 . . 5"}, cbase = 24,
  bpat = {"1 - - - 5 - - -", "1 - - - 5 - 8 -"},
  spat = {"1 . . . 5 . . .", "3 . . . 8 . . ."}, sbase = 36,
  drums = bars("K . . . . . H . S . . . . . H .", {
    [4] = "K . . . . . H . S . . H K . S .", [8] = "K . . H S . K . S . S . C . . ."})}

-- 6 Coral Reef: a bubbly B-flat tune.
W[6] = {name = "Coral Reef", bpm = 140, tonic = 10,
  prog = "Bb2M Bb2M Eb3M F2M Bb2M G2m Eb3M F2M/Bb2M",
  lead = {"D5 . F5 D5 . Bb4 D5 . F5 . Bb5 . F5 . . .",
          "D6 . Bb5 F5 . D5 F5 . Bb5 . D6 . Bb5 . . .",
          "Eb5 . G5 Eb5 . Bb4 Eb5 . G5 . Bb5 . G5 . . .",
          "F5 . A5 F5 . C5 F5 . A5 . C6 . A5 . . .",
          "Bb5 . A5 Bb5 . D6 F6 . D6 . Bb5 . F5 . . .",
          "G5 . Bb5 D6 . Bb5 G5 . D5 . G5 . Bb5 . . .",
          "G5 . Bb5 Eb6 . D6 Bb5 . G5 . Bb5 . Eb6 . . .",
          "C6 . A5 . F5 . A5 . Bb5 . D6 . F6 - - ."},
  cpat = {". . 3 . . 3 . .", ". . 5 . . 5 . ."}, cbase = 24,
  bpat = {"1 . 8 . 1 . 5 .", "1 . 8 . 5 . 8 1"},
  spat = {"1 . 3 5 . 3 5 .", "5 . 3 1 . 3 5 ."}, sbase = 36,
  drums = bars("K . H . S . H H K . H . S . H H", {
    [4] = "K . H . S . H H K S K S K S C .", [8] = "K . S . K . S S K S S K C . C C"})}

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
  local w = W[wi]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- The eaten dots are a part of the song: the note walks the chord, alternating its low and high tones, and
-- every eighth dot starts the walk over. n counts dots in a run.
function M.dot_note(wi, step, n)
  local root, t3 = M.chord(wi, step)
  local k = n % 8
  local off = (k == 0 and 0) or (k == 2 and t3) or (k == 4 and 12) or (k == 6 and t3) or 7
  return root + off + 12
end

-- The maze song for a world. Normal: the written parts. Blue: the section the song turns into when the
-- ghosts turn blue (a driving arpeggio, a pumping bass, busy drums, the shimmer all through).
local PAD = {"5 - - - - - - -", "3 - - - - - - -"}
function M.song(wi, blue, keep)
  local w = W[wi]
  local pad = lay(w, PAD, 24)
  local lead, counter, bass, shim, drums
  if blue then
    lead = lay(w, {"1 3 5 8 5 3 5 8", "8 5 3 5 8 5 3 1"}, 36)
    counter = lay(w, {"5 . 5 . 5 . 8 ."}, 24)
    bass = lay(w, {"1 . 8 . 1 . 8 5", "1 . 8 . 5 . 8 1"}, 0)
    shim = lay(w, {"8 5 8 5 8 5 8 3"}, 36)
    drums = bars("K H H K S H K H K H H K S H S S", {[4] = "K H H K S H S S K K S S K S C C", [8] = "K S K S K S S S K K S S C C C C"})
  else
    lead = w.leadstr
    counter = lay(w, w.cpat, w.cbase)
    bass = lay(w, w.bpat, 0)
    shim = lay(w, w.spat, w.sbase)
    drums = w.drums
  end
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {lead, wave = "square", vol = blue and 0.17 or 0.20, release = 0.045, attack = 0.003, duty = 0.25, pan = -0.2},
    {counter, wave = "square", vol = 0.11, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
    {bass, wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
    {shim, wave = "sine", vol = 0.10, release = 0.09, attack = 0.005, pan = 0.15},
    {drums, wave = "noise", vol = 0.13, release = 0.035, pan = 0.15},
    {pad, wave = "sine", vol = 0.09, release = 0.5, attack = 0.12, pan = 0}}
end

-- Maze clear: a fanfare in the world's own key (written in C, moved by the world's tonic).
local FAN = {
  "C5 . E5 . G5 . C6 - - . B5 . C6 . D6 . E6 - - - C6 . G5 . E5 . G5 . C6 - - . ",
  "G4 . C5 . E5 . G5 - - . F5 . E5 . F5 . G5 - - - E5 . C5 . G4 . C5 . E5 - - . ",
  "C3 - G2 - C3 - E3 - F2 - C3 - G2 - D3 - C3 - G2 - A2 - E2 - F2 - G2 - C3 - - . ",
  "K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . "}
function M.fanfare(wi)
  local t = W[wi].tonic
  return {bpm = 148, steps = 4,
    {tr(FAN[1], t), wave = "square", vol = 0.19, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
    {tr(FAN[2], t), wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.12, release = 0.04}}
end

local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end
local function hold8(notes)   -- each note held for 8 steps
  local t = {}
  for i, n in ipairs(notes) do t[i] = n .. " - - - - - - -" end
  return table.concat(t, " ")
end

-- The star map: a music box over a slow bed, 4 bars of 16 steps. Track 4 is the twinkle: the game brings it in
-- with the stars that are lit.
function M.map()
  return {bpm = 92, steps = 4,
    {"E5 . G5 . C6 . G5 . E5 . G5 . A5 . . . " ..
     "F5 . A5 . C6 . A5 . F5 . A5 . G5 . . . " ..
     "E5 . G5 . C6 . E6 . D6 . C6 . A5 . G5 . " ..
     "D5 . G5 . B5 . D6 . C6 - - - . . . . ",
     wave = "sine", vol = 0.17, release = 0.5, attack = 0.004, pan = -0.1},
    {hold8({"E4", "C4", "C4", "E4", "A3", "C4", "B3", "E4"}),
     wave = "tri", vol = 0.10, release = 0.4, attack = 0.08, pan = 0.1},
    {hold8({"C2", "G2", "A2", "E2", "F2", "C3", "G2", "D3"}),
     wave = "tri", vol = 0.20, release = 0.3, attack = 0.01},
    {"G6 . . . . . E6 . . . . . C6 . . . . . D6 . . . . . G6 . . . . . . . " ..
     ". . A6 . . . . . F6 . . . . . C6 . . . E6 . . . . . G6 . . . D6 . . .",
     wave = "sine", vol = 0.07, release = 0.35, attack = 0.003, pan = 0.25}}
end

-- The story: the ghosts tiptoe off with the stars (tracks 1 2, Am F C E), then Chompy's theme (tracks 3 4)
-- comes in when he rolls up. 4 bars of 16 steps, 104 bpm.
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
