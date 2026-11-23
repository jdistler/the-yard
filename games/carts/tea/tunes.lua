-- The four tunes Band teaches, as Tea plays them after the cheer: one melody note per press (cued onto the next
-- step of a soft pad-and-bass bed with the same chords and tempo as the Band song). Copied from band/songs.lua
-- (a cart can only import its own files): the verse melody, chords, tempo, and the pad/bass patterns. The newest
-- tune she learned in Band is `tunes` (1..4), so the table index is that number.
local T = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (math.floor(m / 12) - 1) end
local SEMI = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function midi_of(tok)
  local s = SEMI[tok:sub(1, 1)]
  local i = 2
  local c = tok:sub(2, 2)
  if c == "#" then s, i = s + 1, 3 elseif c == "b" then s, i = s - 1, 3 end
  return 12 * (tonumber(tok:sub(i)) + 1) + s
end

-- Chord colours: the third and the fifth (the seventh is left out of a soft bed).
local QI = {M = {4, 7}, m = {3, 7}, ["7"] = {4, 7}, m7 = {3, 7}, maj7 = {4, 7}}

local DEF = {
  { -- Moon Lullaby
    name = "lullaby", bpm = 76, spb = 4, bl = 16,
    chords = {{53, "M"}, {50, "m"}, {46, "M"}, {48, "M"}},
    pad = "3 - - - - - - - 5 - - - - - - -", bass = "1 - - - - - - - 5 - - - - - - -",
    mel = "A4 C5 F5 E5 D5 E5 D5 C5 A4 Bb4 D5 F5 D5 E5 D5 C5",
  },
  { -- Parade March
    name = "march", bpm = 112, spb = 4, bl = 16,
    chords = {{48, "M"}, {53, "M"}, {55, "M"}, {48, "M"}},
    pad = "5 - - - - - - - 3 - - - - - - -", bass = "1 . . . 5 . . . 1 . . . 5 . . .",
    mel = "G4 G4 C5 E5 E5 G5 A5 A5 F5 A4 C5 F5 B4 B4 D5 G5 F5 D5 E5 D5 C5 G4",
  },
  { -- Disco Kitty
    name = "disco", bpm = 116, spb = 4, bl = 16,
    chords = {{45, "m7"}, {50, "m7"}, {43, "7"}, {48, "maj7"}},
    pad = "5 - - - - - - - 3 - - - - - - -", bass = "1 . 8 . 1 . 8 . 1 . 8 . 1 . 8 .",
    mel = "A4 C5 E5 E5 D5 C5 D5 F5 A5 A5 G5 F5 G4 B4 D5 F5 D5 B4 E5 G5 B5",
  },
  { -- Twirly Waltz (bars 5 to 8, which come home to D)
    name = "waltz", bpm = 132, spb = 4, bl = 12,
    chords = {{50, "M"}, {43, "M"}, {45, "7"}, {50, "M"}},
    pad = "3 - - - - - 5 - - - - -", bass = "1 - - - 5 . . . 5 . . .",
    mel = "D5 F#5 A5 F#5 G5 B5 D6 B5 C#6 A5 E5 G5 F#5 D5",
  },
}

-- A pattern for one bar into note names: 1 3 5 are chord tones, 8 the octave. `lift` raises the register.
local function bar_notes(pat, root, q, lift, out)
  local i = QI[q]
  local off = {["1"] = 0, ["3"] = i[1], ["5"] = i[2], ["8"] = 12}
  for tok in pat:gmatch("%S+") do out[#out + 1] = off[tok] and nm(root + lift + off[tok]) or tok end
end

for k, d in ipairs(DEF) do
  local pad, bass = {}, {}
  for b = 1, #d.chords do
    bar_notes(d.pad, d.chords[b][1], d.chords[b][2], 12, pad)
    bar_notes(d.bass, d.chords[b][1], d.chords[b][2], 0, bass)
  end
  local mel = {}
  for tok in d.mel:gmatch("%S+") do mel[#mel + 1] = midi_of(tok) end
  T[k] = {
    name = d.name, mel = mel,
    bed = {bpm = d.bpm, steps = d.spb,
      {table.concat(pad, " "), wave = "sine", vol = 0.07, attack = 0.1, release = 0.6, pan = 0},
      {table.concat(bass, " "), wave = "tri", vol = 0.09, attack = 0.01, release = 0.3, pan = 0.15}},
  }
end

return T
