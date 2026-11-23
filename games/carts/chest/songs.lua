-- Chest's music. Four real arrangements of 8 bars (128 steps, 16 to a bar, 4 to a beat): the path (C major, a
-- walking quest tune whose band grows with each gold fairy that follows him), Zam's duel (A minor), Pika's duel
-- (G major, bouncy and electric), and the win. Zam and Pika each have three sections that the game swaps in
-- with music.play{keep = true} (1 verse, 2 surge at half marks, 3 climax for the last few marks).
--
-- Tracks (1-based, as music.track):
--   path:  1 lead  2 bass  3 hat    4 fairy 1 (bells)  5 fairy 2 (counter line)  6 fairy 3 (sparkles)
--   duels: 1 lead  2 bass  3 drums  4 counter          5 pad                     6 choir (gold fairies)
--   win:   1 lead  2 harmony  3 bass  4 claps          5 fairy bells             6 fairy sparkles
-- Every part is written to be a good song with any subset on. Only sound lives here: nothing in the rules
-- reads the music clock (main.lua picks a pitch for a music.cue from M.chord / M.ladder, and that is all).
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

-- Half-bar chords (16 a song, 8 steps each): the root (a note) and whether the third is major (4) or minor (3).
local OFF = {["1"] = 0, ["5"] = 7, ["8"] = 12}
local function parse_roots(s)
  local r, q = {}, {}
  for tok in s:gmatch("%S+") do
    local n, k = tok:match("^([A-G][#b]?%d)([Mm])$")
    r[#r + 1], q[#q + 1] = mid(n), (k == "M") and 4 or 3
  end
  assert(#r == 16, "chest songs: 16 half-bars")
  return r, q
end

-- Lay a half-bar pattern (tokens 1 3 5 8 follow that half-bar's chord) over all 16 half-bars.
local function lay(w, pats, base)
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

local function bars(n, fills)
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local function join(t) return table.concat(t, " ") end

local W = {}

-- ---------------------------------------------------------------- the path: C, a walking quest tune
W.path = {bpm = 100,
  roots = "C3M C3M A2m A2m F2M F2M G2M G2M C3M C3M E3m E3m F2M F2M G2M G2M",
  lead = join{
    "G5 . . E5 . . C5 . E5 . G5 . . . . .",
    "A5 . . E5 . . C5 . E5 . A5 . . . . .",
    "A5 . . F5 . . C5 . F5 . A5 . G5 . F5 .",
    "G5 . . D5 . . B4 . D5 . G5 . . . . .",
    "C6 . . G5 . . E5 . G5 . C6 . . . . .",
    "B5 . . G5 . . E5 . G5 . B5 . . . . .",
    "A5 . G5 . F5 . A5 . C6 . A5 . F5 . . .",
    "G5 . F5 . E5 . D5 . G5 . . . . . . ."}}

-- ---------------------------------------------------------------- Zam: A minor, a wizard's march
W.zam = {bpm = 132,
  roots = "A2m A2m F2M F2M C3M C3M G2M G2M A2m A2m F2M F2M D3m D3m E3M E3M",
  lead = join{
    "A4 . . A4 C5 . E5 . A5 . . G5 E5 . C5 .",
    "F4 . . F4 A4 . C5 . F5 . . E5 C5 . A4 .",
    "E4 . . G4 C5 . E5 . G5 . . E5 C5 . G4 .",
    "D4 . . G4 B4 . D5 . G5 . . F5 D5 . B4 .",
    "A4 . . A4 C5 . E5 . A5 . . B5 C6 . A5 .",
    "F4 . . F4 A4 . C5 . F5 . A5 . C6 . A5 .",
    "D5 . . F5 A5 . F5 . D5 . F5 . A5 . D6 .",
    "E5 . G#5 . B5 . G#5 . E5 . . . B4 . G#4 ."},
  riff = join{
    "A4 . A4 . C5 . E5 . A5 . E5 . C5 . E5 .",
    "F4 . F4 . A4 . C5 . F5 . C5 . A4 . C5 .",
    "E4 . E4 . G4 . C5 . E5 . C5 . G4 . C5 .",
    "D5 . D5 . B4 . G4 . D5 . G5 . B5 . G5 .",
    "A4 . C5 . E5 . A5 . C6 . A5 . E5 . C5 .",
    "A4 . C5 . F5 . A5 . C6 . A5 . F5 . C5 .",
    "D5 . F5 . A5 . D6 . A5 . F5 . D5 . F5 .",
    "E5 . G#5 . B5 . E6 . B5 . G#5 . E5 . B4 ."}}

-- ---------------------------------------------------------------- Pika: G major, bouncy and electric
W.pika = {bpm = 148,
  roots = "G2M G2M E3m E3m C3M C3M D3M D3M G2M G2M E3m E3m C3M C3M D3M D3M",
  lead = join{
    "D5 . G5 . B5 . D6 . B5 . G5 . D5 . . .",
    "E5 . G5 . B5 . E6 . B5 . G5 . E5 . . .",
    "E5 . G5 . C6 . E6 . C6 . G5 . E5 . . .",
    "F#5 . A5 . D6 . F#6 . D6 . A5 . F#5 . . .",
    "G5 . B5 . D6 . G6 . D6 . B5 . G5 . D5 .",
    "E5 . G5 . B5 . G5 . E5 . B4 . E5 . G5 .",
    "C6 . G5 . E5 . G5 . C6 . E6 . G6 . E6 .",
    "A5 . F#5 . D5 . F#5 . A5 . C6 . D6 . . ."},
  riff = join{
    "G5 D6 G5 D6 B5 G6 B5 G6 D6 B5 D6 B5 G5 . . .",
    "E5 B5 E5 B5 G5 E6 G5 E6 B5 G5 B5 G5 E5 . . .",
    "E5 C6 E5 C6 G5 E6 G5 E6 C6 G5 C6 G5 E5 . . .",
    "F#5 D6 F#5 D6 A5 F#6 A5 F#6 D6 A5 D6 A5 F#5 . . .",
    "D5 G5 D5 G5 B5 D6 B5 D6 G6 D6 B5 D6 G5 . . .",
    "E5 G5 E5 G5 B5 E6 B5 E6 G6 E6 B5 E6 G5 . . .",
    "E5 G5 C6 G5 E6 G5 C6 E6 G6 E6 C6 G5 E5 . . .",
    "F#5 A5 D6 A5 F#6 A5 D6 F#6 A6 F#6 D6 A5 D6 . . ."}}

-- ---------------------------------------------------------------- the win: a C major fanfare party
W.win = {bpm = 128,
  roots = "C3M C3M G2M G2M A2m A2m F2M F2M C3M C3M G2M G2M F2M F2M G2M C3M",
  lead = join{
    "C5 . E5 . G5 . C6 - - . G5 . E5 . G5 .",
    "B4 . D5 . G5 . B5 - - . G5 . D5 . G5 .",
    "A4 . C5 . E5 . A5 - - . E5 . C5 . E5 .",
    "A4 . C5 . F5 . A5 - - . C6 . A5 . F5 .",
    "E5 . G5 . C6 . E6 - - . C6 . G5 . E5 .",
    "D5 . G5 . B5 . D6 - - . B5 . G5 . D5 .",
    "F5 . A5 . C6 . F6 - E6 . D6 . C6 . A5 .",
    "G5 . B5 . D6 . G6 - - - - - - - - -"}}

for _, w in pairs(W) do w.r, w.q = parse_roots(w.roots) end

-- The chord under a step: its root as a note (60 to 71) and its third (3 or 4). Sound only.
function M.chord(name, step)
  local w = W[name]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- A rising chord-tone ladder for a run: n = 0, 1, 2 ... climbs through two octaves, then starts over.
local LADDER = {0, 99, 7, 12, 99, 19, 24}
function M.ladder(name, step, n)
  local root, t3 = M.chord(name, step)
  local k = n % 7
  local off = LADDER[k + 1]
  if off == 99 then off = (k == 1) and t3 or 12 + t3 end
  return root + off
end

-- ---------------------------------------------------------------- the path

function M.path(keep)
  local w = W.path
  local bass = lay(w, {"1 . . 1 . . 5 .", "1 . . . 8 . 5 ."}, 0)
  local hat = bars("H . . . H . . . H . . . H . H .", {[4] = "H . . . H . . . H . H . H . H H", [8] = "H . H . H . H . H H H . H H H H"})
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {w.lead, wave = "tri", vol = 0.16, release = 0.2, attack = 0.01, pan = -0.2},
    {bass, wave = "sine", vol = 0.26, release = 0.18, attack = 0.015},
    {hat, wave = "noise", vol = 0.06, release = 0.04, pan = 0.3},
    {lay(w, {". . 5 . . . 8 ."}, 24), wave = "sine", vol = 0.12, release = 0.4, attack = 0.004, pan = 0.35},
    {lay(w, {"3 . 5 . 8 . 5 ."}, 12), wave = "tri", vol = 0.09, release = 0.12, attack = 0.01, pan = -0.35},
    {lay(w, {". 8 . 5 . 8 . 3", "5 . 8 . . 5 . ."}, 36), wave = "sine", vol = 0.07, release = 0.25, attack = 0.004, pan = 0.1}}
end

-- ---------------------------------------------------------------- the duels

-- sect: 1 verse, 2 surge, 3 climax.
local DRUMS = {
  zam = {{"K . H . S . H . K . H K S . H .", {[4] = "K . H . S . H . K S S H C . . .", [8] = "K . S . K . S . K S K S C C C C"}},
         {"K . H H S . H . K . H K S . H S", {[4] = "K . H H S . H . K S K S K S C C", [8] = "K . S . K S K S K S K S C C C C"}},
         {"K H H K S H K H K H H K S H S S", {[4] = "K H H K S H K H K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}}},
  pika = {{"K . H H S . H . K K H . S . H H", {[4] = "K . H H S . H . K K S S K S C C", [8] = "K . S . K . S . K K S S K S C C"}},
          {"K H H K S . H H K K H K S . H H", {[4] = "K H H K S H H K K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}},
          {"K H K H S H K K K H K H S H S S", {[4] = "K H K H S H K K K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}}}}

function M.duel(name, sect, keep)
  local w = W[name]
  local zam = name == "zam"
  local d = DRUMS[name][sect]
  local drums = bars(d[1], d[2])
  local bass
  if sect == 1 then bass = lay(w, {zam and "1 . 1 . 5 . 1 ." or "1 . . 1 . . 5 1"}, 0)
  elseif sect == 2 then bass = lay(w, {zam and "1 . 1 1 . 5 1 ." or "1 . 1 . 8 . 5 ."}, 0)
  else bass = lay(w, {zam and "1 1 8 1 5 5 8 5" or "1 8 1 8 5 8 1 5"}, 0) end
  local lead = sect == 1 and w.lead or w.riff
  local counter
  if sect == 1 then counter = lay(w, {". . 3 . . . 5 ."}, 24)
  elseif sect == 2 then counter = lay(w, {"1 . 3 . 5 . 8 ."}, 24)
  else counter = tr(w.lead, -12) end
  local pad = lay(w, {"3 - - - - - - -", "5 - - - - - - -"}, 24)
  local choir = lay(w, {". . 8 . 5 . 3 .", "5 . 8 . 3 . 8 ."}, 36)
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {lead, wave = "square", vol = zam and 0.11 or 0.10, release = 0.06, attack = 0.005, duty = zam and 0.25 or 0.3, pan = -0.2},
    {bass, wave = "tri", vol = 0.26, release = 0.06, attack = 0.004},
    {drums, wave = "noise", vol = 0.10, release = 0.05, pan = 0.2},
    {counter, wave = sect == 3 and "tri" or "square", vol = sect == 3 and 0.12 or 0.06, release = 0.07, attack = 0.005, duty = 0.125, pan = 0.25},
    {pad, wave = "sine", vol = 0.08, release = 0.5, attack = 0.1},
    {choir, wave = "sine", vol = 0.08, release = 0.3, attack = 0.004, pan = 0.1}}
end

-- ---------------------------------------------------------------- the win

function M.win()
  local w = W.win
  return {bpm = w.bpm, steps = 4,
    {w.lead, wave = "tri", vol = 0.20, release = 0.22, attack = 0.008, pan = -0.2},
    {lay(w, {"3 . 5 . 8 . 5 ."}, 12), wave = "sine", vol = 0.13, release = 0.2, attack = 0.01, pan = 0.2},
    {lay(w, {"1 - - - 5 - - -"}, 0), wave = "sine", vol = 0.22, release = 0.25, attack = 0.01},
    {bars("K . H . C . H . K . H K C . H H", {[4] = "K . H . C . H . K C K C K C C C", [8] = "K . C . K C K C K C K C C C C C"}),
     wave = "noise", vol = 0.10, release = 0.05, pan = 0.2},
    {lay(w, {". . 5 . . . 8 ."}, 24), wave = "sine", vol = 0.12, release = 0.4, attack = 0.004, pan = 0.35},
    {lay(w, {". 8 . 5 . 8 . 3", "5 . 8 . . 5 . ."}, 36), wave = "sine", vol = 0.07, release = 0.25, attack = 0.004, pan = 0.1}}
end

return M
