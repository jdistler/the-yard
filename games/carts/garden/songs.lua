-- Garden's song. Everything is C major pentatonic (C D E G A), so any set of flowers sounds pretty over the
-- chords C, Am, F, G. Four bars of eight steps (two steps to a beat, 92 bpm): 32 steps, about 10 seconds.
--
-- Tracks (1-based, as in music.track):
--   1 pad (always)   2 soft bass (always)   3 arpeggio: the bloomed beds, rebuilt as she grows
--   4 echo of the arpeggio (a few steps late, quiet)   5 evening drums   6 evening bass groove
-- Day is tracks 1-4 and sounds complete with no flower at all. Evening brings in 5 and 6.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (math.floor(m / 12) - 1) end

M.BPM, M.STEPS, M.LEN = 92, 2, 32
M.STEP_FRAMES = 3600 / (92 * 2)

-- Each bed's note: left to right along the row, then the row below. Low to high.
M.BEDNOTE = {72, 74, 76, 79, 81, 84}
-- The next note up the pentatonic scale, for the little rising runs of a growing flower.
local UP = {[0] = 2, [2] = 2, [4] = 3, [7] = 2, [9] = 3}
function M.up(m) return m + UP[m % 12] end

-- Chord roots (the bass octave), thirds and fifths, one chord per bar.
local CH = {{48, 4, 7}, {45, 3, 7}, {41, 4, 7}, {43, 4, 7}}

-- Which bed plays on each step of each bar (0 rests). The same bed always has the same pitch.
local ARP = {
  {1, 3, 2, 4, 3, 0, 2, 1},
  {5, 4, 3, 5, 4, 0, 3, 6},
  {6, 5, 4, 6, 5, 0, 2, 3},
  {4, 6, 5, 4, 3, 2, 0, 1},
}
-- Flat, 1-based by step: ARPBED[pos] is the bed whose note sounds there (drawing uses it, never the rules).
local ARPBED = {}
for b = 1, 4 do for s = 1, 8 do ARPBED[(b - 1) * 8 + s] = ARP[b][s] end end
M.ARPBED = ARPBED

-- Evening drums: kick on the beat, hats between, a soft snare; a little fill at the end.
local DRUMS = {"K . H . S . H .", "K . H . S . H .", "K . H . S . H .", "K . H . S . H H"}
local DRUMTOK = {}
do
  local n = 0
  for b = 1, 4 do for tok in DRUMS[b]:gmatch("%S+") do n = n + 1 DRUMTOK[n] = tok end end
end
M.DRUMTOK = DRUMTOK

local function bars(f)
  local out = {}
  for b = 1, 4 do out[b] = f(b, CH[b]) end
  return table.concat(out, " ")
end

local PAD = {"3 - - - 5 - - -", "3 - - - 5 - - -", "3 - - - 5 - - -", "5 - - - 8 - - -"}
local BASS = {"1 - - - - - 5 -", "1 - - - - - 5 -", "1 - - - - - 5 -", "1 - - - 5 - 8 -"}
local GROOVE = {"1 . 8 . 1 . 5 .", "1 . 8 . 1 . 5 .", "1 . 8 . 1 . 5 .", "1 . 8 . 5 . 8 ."}

local function chordtones(pat, base)
  return bars(function(b, c)
    local off = {["1"] = 0, ["3"] = c[2], ["5"] = c[3], ["8"] = 12}
    local out = {}
    for tok in pat[b]:gmatch("%S+") do out[#out + 1] = off[tok] and nm(c[1] + base + off[tok]) or tok end
    return table.concat(out, " ")
  end)
end

local PADSTR = chordtones(PAD, 12)
local BASSSTR = chordtones(BASS, 0)
local GROOVESTR = chordtones(GROOVE, 0)
local DRUMSTR = table.concat(DRUMS, " ")

-- The arpeggio and its echo for a set of bloomed beds (mask[i] true when bed i has bloomed).
local function arpstrings(mask)
  local a, e = {}, {}
  for p = 1, 32 do a[p], e[p] = ".", "." end
  for p = 1, 32 do
    local b = ARPBED[p]
    if b > 0 and mask[b] then
      a[p] = nm(M.BEDNOTE[b])
      e[(p + 2) % 32 + 1] = nm(M.BEDNOTE[b])
    end
  end
  return table.concat(a, " "), table.concat(e, " ")
end

-- The whole song for the beds that have bloomed: the table music.play takes. keep: swing in without a restart.
function M.song(mask, keep)
  local arp, echo = arpstrings(mask)
  return {bpm = M.BPM, steps = M.STEPS, keep = keep or nil,
    {PADSTR, wave = "sine", vol = 0.10, attack = 0.18, release = 0.75, pan = 0},
    {BASSSTR, wave = "tri", vol = 0.14, attack = 0.01, release = 0.4, pan = 0},
    {arp, wave = "tri", vol = 0.10, attack = 0.003, release = 0.5, pan = -0.15},
    {echo, wave = "sine", vol = 0.045, attack = 0.003, release = 0.6, pan = 0.3},
    {DRUMSTR, wave = "noise", vol = 0.09, release = 0.1, pan = 0.1},
    {GROOVESTR, wave = "tri", vol = 0.13, attack = 0.006, release = 0.16, pan = 0}}
end

return M
