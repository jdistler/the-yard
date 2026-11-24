-- Tower's music. One song per tower, each a rising key (C, G, D) and its own feel: the climb is a song that
-- grows (floor 1 is bass and pad, then drums, then the counter and the bells), and the top floor turns it into
-- the "climax" section (music.play{keep = true}). Plus a fanfare, a lullaby (the payoff: Big Grumble falls
-- asleep) and the story. Nothing here is read by the game rules: sound only.
--
-- Tracks (1-based, as in music.track), the same in every tower and section:
--   1 lead (the hook)   2 counter   3 bass   4 drums   5 pad   6 sparkle (bells)
-- Each part is written to sound right alone. 8 bars of 16 steps (128), 4 steps to a beat.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (floor(m / 12) - 1) end
local PC = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function mid(s)
  local l, a, o = s:match("^([A-G])([#b]?)(%d)$")
  return PC[l] + (a == "#" and 1 or a == "b" and -1 or 0) + (tonumber(o) + 1) * 12
end
local function tr(str, semis)   -- move every note by some semitones (drums and rests stay)
  if semis == 0 then return str end
  return (str:gsub("([A-G][#b]?)(%d)", function(n, o) return nm(mid(n .. o) + semis) end))
end
local function ntok(s) local n = 0 for _ in s:gmatch("%S+") do n = n + 1 end return n end

-- chords, one per half bar (16 per song): bass note + quality (M major, m minor)
local function parse_roots(s)
  local r, q = {}, {}
  for tok in s:gmatch("%S+") do
    local n, k = tok:match("^([A-G][#b]?%d)([Mm])$")
    r[#r + 1], q[#q + 1] = mid(n), (k == "M") and 4 or 3
  end
  return r, q
end

local OFF = {["1"] = 0, ["5"] = 7, ["8"] = 12}
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

local function bars(n, fills)   -- drums: the groove each bar, a fill on the bars named
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end
local function join(t) return table.concat(t, " ") end

local W = {}
M.W = W

-- 1 Girder Tower: C major, a bouncy march.
W[1] = {name = "Girder Tower", bpm = 132, tonic = 0,
  roots = "C3M C3M G2M G2M A2m A2m F2M F2M C3M C3M G2M G2M F2M F2M G2M G2M",
  lead = join{
    "E5 . G5 . C6 . G5 . E5 . G5 . E5 . D5 .",
    "D5 . G5 . B5 . G5 . D5 . B4 . D5 . . .",
    "C5 . E5 . A5 . E5 . C5 . E5 . A5 . G5 .",
    "A5 . F5 . C6 . A5 . F5 . A5 . G5 . F5 .",
    "G5 . E5 . C6 . E5 . G5 . C6 . E6 . D6 .",
    "B5 . D6 . G5 . B5 . D6 . B5 . G5 . . .",
    "A5 . C6 . F5 . A5 . C6 . A5 . F5 . G5 .",
    "B5 . A5 . G5 . F5 . D5 . G5 . B5 - - ."},
  bpat = {"1 . 8 . 5 . 8 .", "1 . 8 . 5 . 3 5"},
  cpat = {". . 3 . . . 5 .", ". . 5 . . . 8 ."}, cbase = 12,
  spat = {"8 . 5 . 8 . 3 .", "5 . 8 . 3 . 8 ."}, sbase = 24,
  drums = "K . H . S . H . K . H . S . H H",
  fill = "K . H . S . H . K . S . S S S S",
  cdrums = "K H H H S H H H K H K H S H S S",
  cbpat = {"1 8 1 8 5 8 5 8"}, ccpat = {"1 3 5 8 5 3 5 8"}, csp = {"8 5 8 3 8 5 8 3"}}

-- 2 Vine Treehouse: G major, a skipping groove with a marimba counter.
W[2] = {name = "Vine Treehouse", bpm = 124, tonic = 7,
  roots = "G2M G2M E2m E2m C3M C3M D3M D3M G2M G2M E2m E2m A2m A2m D3M D3M",
  lead = join{
    "G4 . B4 D5 . B4 . D5 G5 . D5 . B4 . . .",
    "E5 . G5 B5 . G5 . E5 B4 . E5 . G5 . . .",
    "E5 . G5 C6 . G5 . E5 C5 . E5 . G5 . . .",
    "F#5 . A5 D6 . A5 . F#5 D5 . F#5 . A5 . . .",
    "G5 . B5 D6 . B5 . G5 D5 . G5 . B5 . . .",
    "G5 . B5 E6 . B5 . G5 E5 . G5 . B5 . . .",
    "A5 . C6 . E5 . A5 . F#5 . A5 . D6 . C6 .",
    "B5 . G5 . D5 . B4 . G4 . B4 . D5 - - -"},
  bpat = {"1 . . 8 . 5 . .", "1 . . 1 . 5 . 3"},
  cpat = {". 3 . 5 . 3 . 5", ". 5 . 8 . 5 . 3"}, cbase = 12,
  spat = {"8 . . 5 . . 8 .", "5 . . 8 . . 3 ."}, sbase = 24,
  drums = "K . H . . S H . K . H K . S H .",
  fill = "K . H . . S H . K . S . S . S S",
  cdrums = "K H H H S H H K K H K H S H S S",
  cbpat = {"1 . 8 1 . 5 8 ."}, ccpat = {"1 3 5 8 5 3 5 3"}, csp = {"8 5 8 3 8 5 8 5"}}

-- 3 Castle Sky Spire: D major, a stately anthem. The top of the song.
W[3] = {name = "Castle Sky Spire", bpm = 116, tonic = 2,
  roots = "D3M D3M A2M A2M B2m B2m G2M G2M D3M D3M G2M G2M E2m E2m A2M A2M",
  lead = join{
    "F#5 . . . A5 . . . D6 . . . A5 . F#5 .",
    "E5 . . . A5 . . . C#6 . . . A5 . E5 .",
    "D5 . F#5 . B5 . . . A5 . F#5 . D5 . . .",
    "B5 . . . D6 . . . B5 . G5 . B5 . . .",
    "A5 . F#5 . D6 . . . F#6 . . . D6 . A5 .",
    "B5 . D6 . G6 . . . D6 . B5 . G5 . . .",
    "G5 . B5 . E6 . . . E6 . C#6 . A5 . . .",
    "C#6 . E6 . A5 . . . E5 . A5 . C#6 - - -"},
  bpat = {"1 - - - 5 - - -", "1 - - 8 5 - - 3"},
  cpat = {"1 . 3 . 5 . 3 .", "5 . 8 . 5 . 3 ."}, cbase = 12,
  spat = {"8 . . 5 . . 8 .", "3 . . 8 . . 5 ."}, sbase = 24,
  drums = "K . . . S . . . K . . . S . . S",
  fill = "K . . . S . . . K . S . S . S S",
  cdrums = "K . H . S . H H K . H K S . H S",
  cbpat = {"1 . 8 . 5 . 8 ."}, ccpat = {"1 3 5 8 5 3 5 8"}, csp = {"8 5 3 5 8 5 3 5"}}

for i, w in ipairs(W) do
  w.r, w.q = parse_roots(w.roots)
  assert(#w.r == 16, "roots " .. i)
  assert(ntok(w.lead) == 128, "lead " .. i .. " has " .. ntok(w.lead))
end

-- The chord under a step: its root as a note (60 to 71) and its third (3 or 4). Sound only.
function M.chord(tw, step)
  local w = W[tw]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- Rising chord-tone ladder for a run: n = 0, 1, 2 ... climbs, then starts over lower.
local LADDER = {0, 99, 7, 12, 99, 19, 24}
function M.ladder(tw, step, n)
  local root, t3 = M.chord(tw, step)
  local off = LADDER[n % 7 + 1]
  if off == 99 then off = (n % 7 == 1) and t3 or 12 + t3 end
  return root + off
end

-- The climb song of a tower. climax: the top-floor section (the song keeps its place, the layers all open).
function M.song(tw, climax, keep)
  local w = W[tw]
  local pad = {"5 - - - - - - -", "3 - - - - - - -"}
  local bass = lay(w, climax and w.cbpat or w.bpat, 0)
  local counter = lay(w, climax and w.ccpat or w.cpat, w.cbase)
  local spark = lay(w, climax and w.csp or w.spat, w.sbase)
  local drums = climax and bars(w.cdrums, {}) or bars(w.drums, {[4] = w.fill, [8] = w.fill})
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {w.lead, wave = "square", vol = climax and 0.21 or 0.19, release = 0.045, attack = 0.003,
      duty = climax and 0.5 or 0.25, pan = -0.2},
    {counter, wave = "square", vol = 0.10, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
    {bass, wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
    {drums, wave = "noise", vol = climax and 0.15 or 0.13, release = 0.035, pan = 0.15},
    {lay(w, pad, 12), wave = "sine", vol = 0.09, release = 0.5, attack = 0.12, pan = 0},
    {spark, wave = "sine", vol = 0.09, release = 0.09, attack = 0.005, pan = 0.15}}
end

-- Win: a short fanfare in the tower's key (2 bars), then the lullaby.
local FAN = {
  "C5 . E5 . G5 . C6 - - . . . G5 . C6 . D6 - - . E6 - - . G6 - - - - - - .",
  "E4 . G4 . C5 . E5 - - . . . C5 . E5 . F5 - - . G5 - - . C6 - - - - - - .",
  "C3 - - - G2 - - - C3 - - - G2 - - - F3 - - - G3 - - - C3 - - - - - - .",
  "K . . . S . . . K . K . S . C . K . S . K . S S C . . . . . . ."}
function M.fanfare(tw)
  local t = W[tw].tonic
  return {bpm = 132, steps = 4,
    {tr(FAN[1], t), wave = "square", vol = 0.19, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
    {tr(FAN[2], t), wave = "tri", vol = 0.20, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "tri", vol = 0.26, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.12, release = 0.04}}
end

-- The lullaby that puts Big Grumble to sleep: a music box over a slow bed, 4 bars of 16 steps (64).
local function hold8(notes)   -- each note held for 8 steps
  local t = {}
  for i, n in ipairs(notes) do t[i] = n .. " - - - - - - -" end
  return table.concat(t, " ")
end
function M.lullaby(tw)
  local t = W[tw].tonic
  return {bpm = 84, steps = 4,
    {tr("E5 . . . G5 . . . E5 . . . C5 . . . " ..
        "C5 . . . E5 . . . A5 . . . E5 . . . " ..
        "A5 . . . F5 . . . C5 . . . F5 . . . " ..
        "D5 . . . B4 . . . G4 . . . C5 - - -", t),
     wave = "sine", vol = 0.20, release = 0.5, attack = 0.004, pan = -0.1},
    {tr(hold8({"E4", "C4", "C4", "E4", "A3", "C4", "B3", "E4"}), t),
     wave = "tri", vol = 0.10, release = 0.4, attack = 0.08, pan = 0.1},
    {tr(hold8({"C3", "G2", "A2", "E2", "F2", "C3", "G2", "C3"}), t),
     wave = "tri", vol = 0.20, release = 0.3, attack = 0.01},
    {tr(". . . . . . . . . . G6 . . . . . " ..
        ". . . . . . . . . . C6 . . . . . " ..
        ". . . . . . . . . . A6 . . . . . " ..
        ". . . . . . . . . . G6 . . . . .", t),
     wave = "sine", vol = 0.08, release = 0.4, attack = 0.004, pan = 0.2}}
end

-- The story: the sprites' giggle (track 1), Big Grumble's grumble (2 3), and the hero's theme (4 5) which
-- comes in when she arrives. 4 bars of 16 steps, 100 bpm.
local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end
function M.story()
  return {bpm = 100, steps = 4,
    {"G5 . E6 . C6 . . . G6 . E6 . . . . . " ..
     "A5 . F6 . C6 . . . A6 . F6 . . . . . " ..
     "G5 . E6 . C6 . E6 . G6 . . . E6 . C6 . " ..
     "B5 . D6 . G5 . . . B5 . D6 . G6 - - .",
     wave = "sine", vol = 0.11, release = 0.12, attack = 0.004, pan = 0.25},
    {"C3 . . . . . C3 . Eb3 . . . C3 . . . " ..
     "Ab2 . . . . . Ab2 . C3 . . . Ab2 . . . " ..
     "F2 . . . . . F2 . Ab2 . . . F2 . . . " ..
     "G2 . . . . . G2 . B2 . . . D3 . G2 .",
     wave = "tri", vol = 0.26, release = 0.1, attack = 0.004},
    {"G3 . . . Eb3 . . . G3 . . . C4 . . . " ..
     "Eb4 . . . C4 . . . Ab3 . . . C4 . . . " ..
     "C4 . . . Ab3 . . . F3 . . . Ab3 . . . " ..
     "D4 . . . B3 . . . D4 . . . G3 . . .",
     wave = "square", vol = 0.10, release = 0.12, attack = 0.01, duty = 0.5, pan = -0.2},
    {"C5 . E5 . G5 - - . E5 . G5 . C6 - - - " ..
     "A5 . C6 . A5 - - . F5 . A5 . C6 - - . " ..
     "G5 . E5 . C5 . E5 . G5 - - . E5 . C5 . " ..
     "D5 . F5 . G5 . B5 . D6 - - - - - - -",
     wave = "square", vol = 0.17, release = 0.12, attack = 0.004, duty = 0.25, pan = 0.1},
    {rep("K . . . S . . .", 7) .. " K . . . S . S S",
     wave = "noise", vol = 0.10, release = 0.04}}
end

return M
