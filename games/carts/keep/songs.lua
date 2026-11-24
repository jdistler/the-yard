-- Keep's music. One real arrangement per season (blossom, summer, harvest, snow), each 8 bars of 16 steps
-- (128 steps, 4 steps to a beat), a chorus section the song turns into (music.play{keep = true}) when the run is
-- going well, the pantry's music-box tune, the Tea party polka, and the little tunes a catch run plays.
--
-- Tracks (1-based, as in music.track), the same in every season and section:
--   1 pad (always)   2 bass (always)   3 arp   4 drums   5 counter-stabs   6 lead hook
-- main.lua brings them in as the run goes well (layer 0..5) and drops one gently on a miss. Every part is
-- written to be a song with any subset on. Nothing here is read by the game rules: only sound.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (floor(m / 12) - 1) end
local PC = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function mid(s)
  local l, a, o = s:match("^([A-G])([#b]?)(%d)$")
  return PC[l] + (a == "#" and 1 or a == "b" and -1 or 0) + (tonumber(o) + 1) * 12
end

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

local function bars(n, fills)   -- drums: the same bar, with a fill on bars 4 and 8
  local out = {}
  for b = 1, 8 do out[b] = fills[b] or n end
  return table.concat(out, " ")
end

local function count(str)
  local n = 0
  for _ in str:gmatch("%S+") do n = n + 1 end
  return n
end

local W = {}
M.W = W

-- 1 Blossom: a bright, bouncy C major walk under the pink trees.
W[1] = {name = "Blossom", bpm = 104,
  roots = "C3M C3M A2m A2m F2M F2M G2M G2M C3M C3M E2m E2m F2M F2M G2M G2M",
  hook = {"E5 . G5 . E5 . D5 .", "C5 . E5 . G5 . . .", "A5 . C6 . A5 . G5 .", "E5 . A5 . G5 . . .",
          "F5 . A5 . C6 . A5 .", "G5 . F5 . A5 . . .", "G5 . B5 . D6 . B5 .", "A5 . G5 . D5 . . .",
          "E5 . G5 . C6 . D6 .", "E6 . D6 . C6 . . .", "B5 . G5 . E5 . G5 .", "B5 . E6 . D6 . . .",
          "C6 . A5 . F5 . A5 .", "C6 . F6 . E6 . . .", "D6 . B5 . G5 . B5 .", "D6 . B5 . G5 - - -"},
  bpat = {"1 . . . 5 . 8 .", "1 . . . 5 . 3 ."}, apat = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."},
  cpat = {". . 3 . . 5 . .", ". 3 . . 5 . 3 ."},
  hbpat = {"1 . 1 . 5 . 8 5"}, hapat = {"1 5 8 5 1 5 8 5"}, hcpat = {". 3 . 5 . 3 . 5"},
  drums = bars("K . H . S . H . K . H . S . H .", {[4] = "K . H . S . H . K . S . S . S .", [8] = "K . H . S . S . K S K S S . C ."}),
  hdrums = bars("K . H K S . H . K . H K S . H H", {[4] = "K . H K S . H . K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  tune = "C5 E5 G5 A5 G5 E5 D5 E5 G5 A5 C6 A5 G5 E5 D5 C5", wave = "tri", vol = 0.26}

-- 2 Summer: a warm, lazy-bright G major, off-beat stabs like a porch band.
W[2] = {name = "Summer", bpm = 118,
  roots = "G2M G2M C3M C3M G2M G2M D3M D3M G2M G2M E2m E2m C3M C3M D3M D3M",
  hook = {"B4 . D5 . G5 . . D5", "B5 . A5 . G5 . . .", "C5 . E5 . G5 . . E5", "C6 . B5 . G5 . . .",
          "D5 . G5 . B5 . . G5", "D6 . B5 . A5 . G5 .", "A5 . D6 . F#5 . . A5", "D6 . C6 . A5 . . .",
          "G5 . B5 . D6 . . B5", "G6 . D6 . B5 . . .", "E5 . G5 . B5 . . G5", "E6 . D6 . B5 . . .",
          "E5 . G5 . C6 . . G5", "E6 . D6 . C6 . B5 .", "A5 . F#5 . D5 . . F#5", "A5 . C6 . B5 - - ."},
  bpat = {"1 . . 1 . . 5 .", "1 . 8 . 5 . . 1"}, apat = {"1 . 5 . 8 . 5 .", "3 . 8 . 5 . 3 ."},
  cpat = {". . 3 . . 3 . .", ". 5 . . 3 . 5 ."},
  hbpat = {"1 . 8 1 . 5 8 1"}, hapat = {"1 5 8 5 3 5 8 5"}, hcpat = {". 5 . 3 . 5 . 3"},
  drums = bars("K . H . S . H H K . H . S . H .", {[4] = "K . H . S . H . K S S H C . . .", [8] = "K . S . K S K S K . S . C . C ."}),
  hdrums = bars("K H H K S H H H K H H K S H K H", {[4] = "K H H H S H H H K K S S K S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  tune = "G4 B4 D5 E5 D5 B4 A4 B4 D5 E5 G5 E5 D5 B4 A4 G4", wave = "square", vol = 0.12}

-- 3 Harvest: a rolling A minor jig that turns up bright on C and rests on E.
W[3] = {name = "Harvest", bpm = 124,
  roots = "A2m A2m G2M G2M F2M F2M E2M E2M A2m A2m C3M C3M G2M G2M E2M E2M",
  hook = {"E5 . A5 . C6 . B5 A5", "E5 . . . A4 . C5 .", "D5 . G5 . B5 . A5 G5", "D5 . . . G4 . B4 .",
          "C5 . F5 . A5 . G5 F5", "C5 . . . F4 . A4 .", "B4 . E5 . G#5 . B5 .", "G#5 . E5 . B4 . . .",
          "A4 . C5 . E5 . A5 .", "C6 . B5 . A5 . . .", "G5 . E5 . C5 . E5 .", "G5 . C6 . E6 . . .",
          "D6 . B5 . G5 . B5 .", "D6 . B5 . A5 . G5 .", "E5 . G#5 . B5 . . G#5", "E6 . B5 . G#5 - - ."},
  bpat = {"1 . . 1 . . 5 .", "1 . 5 . 1 . 8 ."}, apat = {"1 . 5 . 8 . 5 3", "8 . 5 . 3 . 5 ."},
  cpat = {". . 5 . . 3 . .", ". 3 . . 5 . 3 ."},
  hbpat = {"1 . 5 1 . 5 8 5"}, hapat = {"1 5 8 5 1 5 8 5"}, hcpat = {". 3 . 5 . 3 . 5"},
  drums = bars("K . H H S . H H K . H H S . H K", {[4] = "K . H H S . H H K K S S S S S C", [8] = "K . S . K S K S K S K S C C C C"}),
  hdrums = bars("K H H K S H H K K H H K S H K H", {[4] = "K H H K S H S S K K S S S S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  tune = "A4 C5 E5 G5 E5 C5 D5 E5 G5 A5 G5 E5 D5 C5 B4 A4", wave = "tri", vol = 0.27}

-- 4 Snow: a music-box E minor lullaby, slow, with bells and room between the notes.
W[4] = {name = "Snow", bpm = 92,
  roots = "E2m E2m C3M C3M G2M G2M D3M D3M E2m E2m A2m A2m C3M C3M B2M B2M",
  hook = {"B5 . . . E6 . G6 .", "F#6 . E6 . B5 . . .", "G5 . . . C6 . E6 .", "D6 . C6 . G5 . . .",
          "B5 . . . D6 . G6 .", "F#6 . D6 . B5 . . .", "A5 . . . D6 . F#6 .", "E6 . D6 . A5 . . .",
          "G5 . B5 . E6 . . .", "D6 . B5 . G5 . . .", "A5 . . . C6 . E6 .", "D6 . C6 . A5 . . .",
          "G5 . . . C6 . E6 .", "G6 . E6 . C6 . . .", "B5 . D#6 . F#6 . . .", "F#6 . D#6 . B5 - - -"},
  bpat = {"1 . . . . . 5 .", "1 . . . 5 . . ."}, apat = {"1 . 5 . 8 . 5 .", "3 . 5 . 8 . 3 ."},
  cpat = {". . . . 5 . . .", ". . 3 . . . 5 ."},
  hbpat = {"1 . 1 . 5 . 8 ."}, hapat = {"1 5 8 5 3 5 8 5"}, hcpat = {". . 3 . 5 . 3 ."},
  drums = bars("H . . . K . . . H . . H S . H .", {[4] = "H . . . K . . . H . K . S . S .", [8] = "H . . H K . . H K . K . S S C ."}),
  hdrums = bars("K . H . S . H H K . H K S . H .", {[4] = "K . H . S . H . K K S S S S S C", [8] = "K S K S K S S S K K S S C C C C"}),
  tune = "E5 G5 B5 A5 G5 E5 D5 E5 G5 B5 D6 B5 A5 G5 E5 D5", wave = "sine", vol = 0.30}

for i, w in ipairs(W) do
  w.r, w.q = parse_roots(w.roots)
  assert(#w.r == 16, "roots " .. i)
  assert(#w.hook == 16, "hook " .. i)
  for h = 1, 16 do assert(count(w.hook[h]) == 8, "hook " .. i .. " half " .. h) end
  w.hookstr = table.concat(w.hook, " ")
  local t = {}
  for n in w.tune:gmatch("%S+") do t[#t + 1] = mid(n) end
  assert(#t == 16, "tune " .. i)
  w.notes = t
end

-- The tune a catch run plays: note n of the run (1, 2, 3 ...), then round again. MIDI numbers.
function M.tune_note(si, n) return W[si].notes[(n - 1) % 16 + 1] end
function M.tune_wave(si) return W[si].wave, W[si].vol end
-- The chord's root under a half-bar, to pick a chord for a stinger (sound only).
function M.root(si, step)
  local m = W[si].r[idiv(step % 128, 8) + 1]
  while m < 60 do m = m + 12 end
  while m >= 72 do m = m - 12 end
  return m, W[si].q[idiv(step % 128, 8) + 1]
end

local cache = {}
local PAD = {"5 - - - - - - -", "3 - - - - - - -"}

-- A season's song: chorus is the busier section the run turns into. Built once, kept.
function M.song(si, chorus, keep)
  local key = si * 2 + (chorus and 1 or 0)
  local s = cache[key]
  if not s then
    local w = W[si]
    local bass = lay(w, chorus and w.hbpat or w.bpat, 0)
    local arp = lay(w, chorus and w.hapat or w.apat, 24)
    local ctr = lay(w, chorus and w.hcpat or w.cpat, 12)
    local drums = chorus and w.hdrums or w.drums
    local pad = lay(w, PAD, 12)
    local lv = chorus and 1.12 or 1
    s = {bpm = w.bpm, steps = 4,
      {pad, wave = "sine", vol = 0.10, release = 0.5, attack = 0.12, pan = 0},
      {bass, wave = "tri", vol = 0.30, release = 0.06, attack = 0.004},
      {arp, wave = "sine", vol = 0.10, release = 0.12, attack = 0.005, pan = 0.2},
      {drums, wave = "noise", vol = 0.12, release = 0.035, pan = 0.15},
      {ctr, wave = "square", vol = 0.075, release = 0.05, attack = 0.003, duty = 0.125, pan = 0.25},
      {w.hookstr, wave = "square", vol = 0.15 * lv, release = 0.05, attack = 0.004, duty = 0.25, pan = -0.2}}
    for i = 1, 6 do assert(count(s[i][1]) == 128, "track " .. i .. " of season " .. si .. " has " .. count(s[i][1])) end
    cache[key] = s
  end
  if not keep then return s end
  return {bpm = s.bpm, steps = 4, keep = true, s[1], s[2], s[3], s[4], s[5], s[6]}
end

-- The pantry and the story: a music box in C over a soft bass, 4 bars of 16 steps (64), 100 bpm.
-- 1 music-box tune, 2 pad, 3 bass, 4 tick.
local function rep(str, n) local t = {} for i = 1, n do t[i] = str end return table.concat(t, " ") end
local title_song
function M.title()
  if title_song then return title_song end
  title_song = {bpm = 100, steps = 4,
    {"E5 . G5 . C6 . G5 . E5 . G5 . A5 . . . " ..
     "C6 . A5 . E5 . A5 . C6 . E5 . A5 . . . " ..
     "F5 . A5 . C6 . A5 . F5 . A5 . G5 . . . " ..
     "D5 . G5 . B5 . D6 . C6 - - - . . . .",
     wave = "sine", vol = 0.17, release = 0.45, attack = 0.004, pan = -0.1},
    {"E4 - - - - - - - C4 - - - - - - - " ..
     "C4 - - - - - - - E4 - - - - - - - " ..
     "A3 - - - - - - - C4 - - - - - - - " ..
     "B3 - - - - - - - D4 - - - - - - -",
     wave = "tri", vol = 0.09, release = 0.4, attack = 0.1, pan = 0.1},
    {"C2 . . . G2 . . . E2 . . . G2 . . . A2 . . . E2 . . . C3 . . . E2 . . . " ..
     "F2 . . . C3 . . . A2 . . . C3 . . . G2 . . . D3 . . . B2 . . . D3 . . .",
     wave = "tri", vol = 0.20, release = 0.25, attack = 0.01},
    {rep(". . H . . . H .", 8), wave = "noise", vol = 0.04, release = 0.04, pan = 0.2}}
  for i = 1, 4 do assert(count(title_song[i][1]) == 64, "title track " .. i) end
  return title_song
end

-- The Tea party at the end of a year: an F major polka, oom-pah, 4 bars of 16 steps, 132 bpm.
local party_song
function M.party()
  if party_song then return party_song end
  party_song = {bpm = 132, steps = 4,
    {"A5 . F5 . A5 . C6 . A5 . F5 . A5 . . . " ..
     "G5 . E5 . G5 . C6 . G5 . E5 . G5 . . . " ..
     "A5 . C6 . F6 . C6 . D6 . Bb5 . D6 . . . " ..
     "C6 . A5 . G5 . E5 . F5 . A5 . C6 - - -",
     wave = "square", vol = 0.19, release = 0.05, attack = 0.003, duty = 0.25, pan = -0.2},
    {"F2 . F3 . C3 . C3 . F2 . F3 . C3 . C3 . " ..
     "C3 . C4 . G3 . G3 . C3 . C4 . G3 . G3 . " ..
     "F2 . F3 . C3 . C3 . Bb2 . Bb3 . F3 . F3 . " ..
     "C3 . C4 . G3 . G3 . F2 . C3 . F2 - - -",
     wave = "tri", vol = 0.30, release = 0.06, attack = 0.004},
    {". . A4 . . . A4 . . . A4 . . . A4 . " ..
     ". . G4 . . . G4 . . . G4 . . . G4 . " ..
     ". . A4 . . . A4 . . . Bb4 . . . Bb4 . " ..
     ". . G4 . . . G4 . . . A4 . . . . .",
     wave = "square", vol = 0.07, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
    {rep("K . H . S . H . K . H . S . H H", 3) .. " K . H . S . S . K S K S C . C .",
     wave = "noise", vol = 0.12, release = 0.04, pan = 0.15}}
  for i = 1, 4 do assert(count(party_song[i][1]) == 64, "party track " .. i) end
  return party_song
end

return M
