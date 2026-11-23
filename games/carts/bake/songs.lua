-- Bake's kitchen song. C major over C, Am, F, G: four bars of eight steps (two steps to a beat, 104 bpm), 32 steps,
-- about 9 seconds. The verse is what she builds; the chorus is the same chords and length, so it can swing in at any step.
--
-- Tracks (1-based, as in music.track):
--   1 hum (always, a soft pad)  2 shaker (the mixing)  3 bass (the oven)  4 melody (the frosting)
--   5 bells (the sprinkles)  6 drums (only in the chorus, when the customer is served)
-- Every track is written to sound right with any other, or alone.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (math.floor(m / 12) - 1) end

M.BPM, M.STEPS, M.LEN = 104, 2, 32
M.STEP_FRAMES = 3600 / (104 * 2)

-- Chord tones for the notes she plays (music.cue), six to a bar, low to high. Sound only.
local CT = {
  {72, 76, 79, 84, 88, 91},
  {69, 72, 76, 81, 84, 88},
  {65, 69, 72, 77, 81, 84},
  {67, 71, 74, 79, 83, 86},
}
-- The pitch for a cue: a chord tone of the bar that the cue will land in (the next step), k = 0, 1, 2, ...
function M.cue_note(step, k, oct)
  local bar = math.floor(((step + 1) % M.LEN) / 8) + 1
  return CT[bar][k % 6 + 1] + (oct or 0)
end

local ROOT = {48, 45, 41, 43}
local FIFTH = {55, 52, 48, 50}

local HUM = {"E4 - - - G4 - - -", "E4 - - - A4 - - -", "F4 - - - A4 - - -", "D4 - - - G4 - - -"}
local SHAKE = {"H . H H . H H .", "H . H H . H H .", "H . H H . H H .", "H . H H H H H H"}
local MELV = {"E5 . G5 E5 . D5 C5 .", "C5 . E5 C5 . A4 C5 .", "F5 . A5 F5 . E5 C5 .", "D5 . G5 F5 . D5 B4 ."}
local MELC = {"G5 . E5 G5 C6 . B5 G5", "A5 . E5 A5 C6 . A5 E5", "A5 . C6 A5 F5 . A5 C6", "B5 . D6 B5 G5 . B5 D6"}
local BELV = {". C6 . E6 . G6 . E6", ". A5 . C6 . E6 . C6", ". F5 . A5 . C6 . A5", ". G5 . B5 . D6 . B5"}
local BELC = {"C6 E6 G6 E6 C6 E6 G6 E6", "A5 C6 E6 C6 A5 C6 E6 C6", "F5 A5 C6 A5 F5 A5 C6 A5", "G5 B5 D6 B5 G5 B5 D6 G6"}
local DRUM = {"K . H . S . H .", "K . H . S . H .", "K . H K S . H .", "K . H . S . S S"}

local function join(t) return table.concat(t, " ") end

local function bass(chorus)
  local out = {}
  for b = 1, 4 do
    local r, f = nm(ROOT[b]), nm(FIFTH[b])
    local o = nm(ROOT[b] + 12)
    out[b] = chorus and fmt("%s . %s %s %s . %s %s", r, o, r, f, o, r) or fmt("%s . %s . %s . %s .", r, r, f, r)
  end
  return join(out)
end

-- chorus: false for the verse (what she builds), true for the chorus. keep: swing in without a restart.
function M.song(chorus, keep)
  return {bpm = M.BPM, steps = M.STEPS, keep = keep or nil,
    {join(HUM), wave = "sine", vol = 0.09, attack = 0.15, release = 0.7, pan = 0},
    {join(SHAKE), wave = "noise", vol = chorus and 0.05 or 0.04, release = 0.05, pan = 0.25},
    {bass(chorus), wave = "tri", vol = 0.13, attack = 0.008, release = chorus and 0.16 or 0.3, pan = 0},
    {join(chorus and MELC or MELV), wave = "tri", vol = chorus and 0.11 or 0.10, attack = 0.004, release = 0.28, pan = -0.15},
    {join(chorus and BELC or BELV), wave = "sine", vol = chorus and 0.06 or 0.07, attack = 0.002, release = 0.5, pan = 0.3},
    {join(DRUM), wave = "noise", vol = 0.08, release = 0.1, pan = 0.1}}
end

return M
