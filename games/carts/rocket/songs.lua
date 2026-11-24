-- Starship's music. One song per world (C major dreamy, F major bouncy, D major stately), each 8 bars of 16
-- steps (128), six tracks in the same order in every world and section:
--   1 lead (the hook)   2 counter   3 bass   4 drums   5 pad   6 sparkle
-- Each part is written to sound right alone. The mix follows the flight (main.lua); the "approach" section
-- is music.play{keep = true} near landing. The two players are a duet: the Pilot's catches are round bells
-- (sine + a soft triangle, upper register) and the Co-Pilot's pops are hollow plucks (square at duty 0.125,
-- lower register); both pick their note from the chord under the step they will land on, from different
-- chord tones, so they always harmonise. Nothing here is read by the game rules: sound only.
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
local function join(t) return table.concat(t, " ") end

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

local function bars(n, fills)
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local W = {}
M.W = W

-- 1 Pastel Nebula: C major, a dreamy float.
W[1] = {name = "Pastel Nebula", bpm = 100, tonic = 0,
  roots = "C3M C3M A2m A2m F2M F2M G2M G2M C3M C3M E2m A2m F2M G2M C3M G2M",
  lead = join{
    "G5 . . . E5 . . G5 C6 - - - G5 . E5 .",
    "A5 . . . E5 . . A5 C6 - - - A5 . E5 .",
    "A5 . . . F5 . . A5 C6 - - - A5 . F5 .",
    "B5 . . . G5 . . B5 D6 - - - B5 . G5 .",
    "E6 . . . C6 . . E6 G6 - - - E6 . C6 .",
    "B5 . . . G5 . . B5 C6 - - - A5 . E5 .",
    "A5 . . . C6 . . F6 E6 - - - D6 . B5 .",
    "C6 - - - - - - . G5 . B5 . D6 - - ."},
  bpat = {"1 - - - - - 5 -", "1 - - - 8 - 5 -"},
  cpat = {". . 3 . . . 5 .", ". . 5 . . . 8 ."}, cbase = 12,
  spat = {"8 . 5 . 8 . 3 .", "5 . 8 . 3 . 8 ."}, sbase = 24,
  drums = "K . . . . . H . . . S . . . H .",
  fill = "K . . . H . H . S . . S S . S S",
  cdrums = "K . H . S . H . K . H K S . H H",
  cbpat = {"1 . 8 . 5 . 8 .", "1 . 8 . 5 . 3 5"}, ccpat = {"1 3 5 8 5 3 5 8"}, csp = {"8 5 8 3 8 5 8 3"}}

-- 2 Candy Ring Planet: F major, a bouncy skip.
W[2] = {name = "Candy Ring Planet", bpm = 118, tonic = 5,
  roots = "F2M F2M D2m D2m Bb2M Bb2M C3M C3M F2M F2M A2m D2m Bb2M C3M F2M C3M",
  lead = join{
    "A5 . C6 . A5 . F5 . A5 . C6 . F6 - . .",
    "D6 . A5 . F5 . A5 . D6 . A5 . F5 - . .",
    "D6 . F6 . D6 . Bb5 . D6 . F6 . Bb6 - . .",
    "E6 . G6 . E6 . C6 . G5 . C6 . E6 - . .",
    "C6 . F6 . A6 . F6 . C6 . A5 . C6 - . .",
    "E6 . C6 . A5 . C6 . F6 . D6 . A5 - . .",
    "D6 . F6 . Bb6 . F6 . E6 . G6 . C6 - . .",
    "A6 . F6 . C6 . A5 . G5 . E5 . G5 - . ."},
  bpat = {"1 . . 8 . 5 . .", "1 . . 1 . 5 . 3"},
  cpat = {". 3 . 5 . 3 . 5", ". 5 . 8 . 5 . 3"}, cbase = 12,
  spat = {"8 . . 5 . . 8 .", "5 . . 8 . . 3 ."}, sbase = 24,
  drums = "K . H . . S H . K . H K . S H .",
  fill = "K . H . . S H . K . S . S . S S",
  cdrums = "K H H H S H H K K H K H S H S S",
  cbpat = {"1 . 8 1 . 5 8 ."}, ccpat = {"1 3 5 8 5 3 5 3"}, csp = {"8 5 8 3 8 5 8 5"}}

-- 3 Starlight Moon: D major, a stately glow.
W[3] = {name = "Starlight Moon", bpm = 92, tonic = 2,
  roots = "D3M D3M B2m B2m G2M G2M A2M A2M D3M D3M F#2m B2m G2M A2M D3M A2M",
  lead = join{
    "F#5 . . . A5 . . . D6 - - - A5 . F#5 .",
    "D6 . . . F#6 . . . B5 - - - D6 . . .",
    "B5 . . . D6 . . . G6 - - - D6 . B5 .",
    "C#6 . . . E6 . . . A6 - - - E6 . C#6 .",
    "A5 . . . D6 . . . F#6 - - - A6 . F#6 .",
    "C#6 . . . F#6 . . . D6 . . . B5 . F#5 .",
    "B5 . D6 . G6 - - . E6 . C#6 . A5 - - .",
    "D6 - - - - - - . E6 . C#6 . A5 - - ."},
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
function M.chord(wd, step)
  local w = W[wd]
  local h = idiv(step % 128, 8) + 1
  local m = w.r[h]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, w.q[h]
end

-- The Pilot's bells: a rising chord-tone ladder, upper register. n = 0, 1, 2 ... climbs then starts over.
function M.pilot(wd, step, n)
  local root, t3 = M.chord(wd, step)
  local k = n % 7
  local off = (k == 0 and 0) or (k == 1 and t3) or (k == 2 and 7) or (k == 3 and 12) or (k == 4 and 12 + t3)
    or (k == 5 and 19) or 24
  return root + off
end

-- The Co-Pilot's plucks: a lower ladder on different chord tones (fifth, octave, tenth, ...), so each pop
-- sits a harmony away from the bell that was just played.
function M.copilot(wd, step, n)
  local root, t3 = M.chord(wd, step)
  local k = n % 6
  local off = (k == 0 and 7) or (k == 1 and 12) or (k == 2 and 12 + t3) or (k == 3 and 19) or (k == 4 and 12 + t3) or 12
  return root - 12 + off
end

-- Star-road melody: seven notes of the world's pentatonic scale, rising. n = 1..7. Sound only.
local ROAD = {0, 2, 4, 7, 9, 12, 16}
function M.road(wd, n) return 72 + W[wd].tonic + ROAD[clamp(n, 1, 7)] end

-- The flight song of a world. climax: the approach section (the song keeps its place, every layer opens).
function M.song(wd, climax, keep)
  local w = W[wd]
  local pad = {"5 - - - - - - -", "3 - - - - - - -"}
  local bass = lay(w, climax and w.cbpat or w.bpat, 0)
  local counter = lay(w, climax and w.ccpat or w.cpat, w.cbase)
  local spark = lay(w, climax and w.csp or w.spat, w.sbase)
  local drums = climax and bars(w.cdrums, {}) or bars(w.drums, {[4] = w.fill, [8] = w.fill})
  return {bpm = w.bpm, steps = 4, keep = keep or nil,
    {w.lead, wave = "tri", vol = climax and 0.21 or 0.18, release = 0.12, attack = 0.006, pan = -0.2},
    {counter, wave = "square", vol = 0.075, release = 0.05, attack = 0.003, duty = 0.125, pan = 0.25},
    {bass, wave = "sine", vol = 0.30, release = 0.09, attack = 0.006},
    {drums, wave = "noise", vol = climax and 0.14 or 0.11, release = 0.035, pan = 0.15},
    {lay(w, pad, 12), wave = "sine", vol = 0.09, release = 0.5, attack = 0.12, pan = 0},
    {spark, wave = "sine", vol = 0.09, release = 0.1, attack = 0.005, pan = 0.15}}
end

-- Touchdown: a fanfare in the world's key (2 bars).
local FAN = {
  "C5 . E5 . G5 . C6 - - . . . G5 . C6 . D6 - - . E6 - - . G6 - - - - - - .",
  "E4 . G4 . C5 . E5 - - . . . C5 . E5 . F5 - - . G5 - - . C6 - - - - - - .",
  "C3 - - - G2 - - - C3 - - - G2 - - - F3 - - - G3 - - - C3 - - - - - - .",
  "K . . . S . . . K . K . S . C . K . S . K . S S C . . . . . . ."}
function M.fanfare(wd)
  local t = W[wd].tonic
  return {bpm = 132, steps = 4,
    {tr(FAN[1], t), wave = "tri", vol = 0.20, release = 0.14, attack = 0.004, pan = -0.2},
    {tr(FAN[2], t), wave = "sine", vol = 0.18, release = 0.16, attack = 0.006, pan = 0.2},
    {tr(FAN[3], t), wave = "sine", vol = 0.28, release = 0.20, attack = 0.01},
    {FAN[4], wave = "noise", vol = 0.12, release = 0.04}}
end

-- Home: the warm tune while the star-creature runs to the ship and the voyage map unfolds. It reuses the
-- world's own hook (its first four bars) as a music box, over a slow bed. 4 bars of 16 steps (64). With
-- finale = true (the last world) it is fuller: this is the Star Lantern being lit again.
local function take(str, from, n)   -- tokens from..from+n-1 of a string
  local t, i = {}, 0
  for tok in str:gmatch("%S+") do
    i = i + 1
    if i >= from and i < from + n then t[#t + 1] = tok end
  end
  return table.concat(t, " ")
end
function M.home(wd, finale)
  local w = W[wd]
  local lead = take(w.lead, 1, 64)
  local bass = take(lay(w, {"1 - - - - - - -", "1 - - - 5 - - -"}, 0), 1, 64)
  local pad = take(lay(w, {"5 - - - - - - -", "3 - - - - - - -"}, 12), 1, 64)
  local bells = take(lay(w, {". . . . 8 . . . ", ". . 5 . . . 3 ."}, 24), 1, 64)
  local sp = bells
  local song = {bpm = w.bpm - 14, steps = 4,
    {lead, wave = "sine", vol = 0.20, release = 0.4, attack = 0.004, pan = -0.1},
    {bass, wave = "tri", vol = 0.24, release = 0.2, attack = 0.01},
    {pad, wave = "sine", vol = 0.09, release = 0.6, attack = 0.14},
    {sp, wave = "sine", vol = 0.08, release = 0.3, attack = 0.004, pan = 0.2}}
  if finale then
    song[5] = {take(lay(w, {"1 . 8 . 5 . 8 .", "1 . 8 . 5 . 3 5"}, 12), 1, 64), wave = "square", duty = 0.125,
      vol = 0.07, release = 0.06, attack = 0.003, pan = 0.25}
    song[6] = {take(bars("K . . . S . . . K . . H S . . H", {}), 1, 64), wave = "noise", vol = 0.10, release = 0.04}
  end
  return song
end

-- A creature's own little tune (cues, sound only): four notes of the world's pentatonic scale. kind 1..6.
local SIG = {{0, 4, 7, 12}, {2, 7, 9, 14}, {4, 9, 12, 16}, {0, 7, 12, 7}, {7, 12, 14, 19}, {4, 7, 12, 19}}
function M.sig(kind, i) return 72 + (SIG[kind][i] or 0) end

-- The story: a music box lullaby (the sleeping babies), the wind (a low swell), the ship's theme.
-- 4 bars of 16 steps, 96 bpm. Tracks: 1 music box, 2 bass, 3 wind (noise), 4 ship theme, 5 pad.
function M.story()
  return {bpm = 96, steps = 4,
    {"E5 . . . G5 . . . C6 . . . G5 . . . " ..
     "E5 . . . A5 . . . C6 . . . A5 . . . " ..
     "F5 . . . A5 . . . C6 . . . A5 . F5 . " ..
     "D5 . . . G5 . . . B5 . . . G5 - - .",
     wave = "sine", vol = 0.18, release = 0.5, attack = 0.004, pan = -0.1},
    {"C3 - - - - - - - G2 - - - - - - - " ..
     "A2 - - - - - - - E2 - - - - - - - " ..
     "F2 - - - - - - - C3 - - - - - - - " ..
     "G2 - - - - - - - G2 . . . D3 . G2 .",
     wave = "sine", vol = 0.24, release = 0.2, attack = 0.02},
    {". . . . . . . . . . . . . . H . " ..
     "H . H . H . H . H . H . H H H H " ..
     "H . H H H H H H H H H H H H H H " ..
     "K . . . S . . . K . . . S . S S",
     wave = "noise", vol = 0.09, release = 0.05, pan = 0.2},
    {"C5 . E5 . G5 . C6 - E6 . C6 . G5 - - . " ..
     "A5 . C6 . E6 . C6 - A5 . C6 . E6 - - . " ..
     "F5 . A5 . C6 . A5 . F6 . C6 . A5 - - . " ..
     "G5 . B5 . D6 . B5 . G6 - - - - - - .",
     wave = "tri", vol = 0.18, release = 0.1, attack = 0.004, pan = 0.15},
    {"G4 - - - - - - - E4 - - - - - - - " ..
     "A4 - - - - - - - C4 - - - - - - - " ..
     "A4 - - - - - - - F4 - - - - - - - " ..
     "B4 - - - - - - - D4 - - - - - - -",
     wave = "sine", vol = 0.08, release = 0.6, attack = 0.15}}
end

return M
