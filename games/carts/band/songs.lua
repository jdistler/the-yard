-- Band's four songs. Each is written as chords plus a hand-made melody; the bass, pad, bells and drums
-- are expanded from small per-bar patterns, so they follow the chord under them and any subset of the
-- six tracks sounds right. Track order: 1 pad, 2 Unicorn (melody), 3 Pip (drums), 4 Moth (bass),
-- 5 Pearl (bells), 6 Nib (claps and shaker).
--
-- Verse and chorus have the same chords, the same length and the same tempo, so music.play{keep = true}
-- can swing from one to the other at any step without a bump.
local M = {}

local NN = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function nm(m) return NN[m % 12 + 1] .. (math.floor(m / 12) - 1) end

-- Chord colours: the third, the fifth, the seventh (a triad's "seventh" is its sixth: always sweet).
local QI = {M = {4, 7, 9}, m = {3, 7, 10}, ["7"] = {4, 7, 10}, m7 = {3, 7, 10}, maj7 = {4, 7, 11}}
M.QI = QI

-- Pattern codes: 1 3 5 7 are chord tones, 8 t f s the same an octave up.
local function offsets(q)
  local i = QI[q]
  return {["1"] = 0, ["3"] = i[1], ["5"] = i[2], ["7"] = i[3], ["8"] = 12, t = 12 + i[1], f = 12 + i[2], s = 12 + i[3]}
end

-- Turn per-bar patterns into one track string. tpl.main is the pattern; tpl.fill is used on the fill bars;
-- a literal list (tpl[bar]) is used as written (the melodies).
local function expand(sg, tpl, lift, name)
  local out, n = {}, 0
  for b = 1, sg.nbars do
    local pat = tpl[b] or (sg.fills[b] and tpl.fill) or tpl.main
    local off = offsets(sg.chords[b][2])
    local base = sg.chords[b][1] + lift
    local k = 0
    for tok in pat:gmatch("%S+") do
      k = k + 1
      n = n + 1
      out[n] = off[tok] and nm(base + off[tok]) or tok
    end
    if k ~= sg.bl then error(fmt("band song %s %s bar %d has %d steps, not %d", sg.id, name, b, k, sg.bl)) end
  end
  return table.concat(out, " "), n
end

local function toks(str)
  local t, n = {}, 0
  for tok in str:gmatch("%S+") do n = n + 1 t[n] = tok end
  return t, n
end

-- A note name as a MIDI number, for drawing (which bell, which string). Rests and holds are 0.
local SEMI = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function midi_of(tok)
  local s = SEMI[tok:sub(1, 1)]
  if not s or not tok:find("%d") then return 0 end
  local i = 2
  if tok:sub(2, 2) == "#" then s = s + 1 i = 3 elseif tok:sub(2, 2) == "b" then s = s - 1 i = 3 end
  return 12 * (tonumber(tok:sub(i)) + 1) + s
end

-- ------------------------------------------------------------------ the songs

local SONGS = {}

-- 1. Moon Lullaby: F Dm Bb C, slow and rocking.
SONGS[1] = {
  id = "lullaby", name = "Moon Lullaby", bpm = 76, spb = 4, bl = 16, nbars = 4, fills = {[4] = true},
  chords = {{53, "M"}, {50, "m"}, {46, "M"}, {48, "M"}},
  col = 0xb998f0, sky1 = 0x1c1646, sky2 = 0x4a3a8c,
  tr = {
    pad = {wave = "sine", vol = 0.10, attack = 0.2, release = 0.7, pan = 0},
    uni = {wave = "tri", vol = 0.11, attack = 0.004, release = 0.5, pan = -0.15},
    pip = {wave = "noise", vol = 0.06, release = 0.1, pan = 0.1},
    moth = {wave = "tri", vol = 0.15, attack = 0.01, release = 0.35, pan = 0},
    pearl = {wave = "sine", vol = 0.075, attack = 0.002, release = 0.55, pan = 0.25},
    nib = {wave = "noise", vol = 0.035, release = 0.05, pan = -0.2},
  },
  verse = {
    pad = {main = "3 - - - - - - - 5 - - - - - - -"},
    uni = {
      "A4 - - - C5 - - - F5 - - - E5 - D5 -",
      "E5 - - - D5 - - - C5 - - - A4 - - -",
      "Bb4 - - - D5 - - - F5 - - - D5 - - -",
      "E5 - - - D5 - - - C5 - - - . . . .",
    },
    pip = {main = "K . . . . . . . K . . . . . . .", fill = "K . . . . . . . K . . . K . K ."},
    moth = {main = "1 - - - - - - - 5 - - - - - - -"},
    pearl = {main = "1 . . . 3 . . . 5 . . . t . . ."},
    nib = {main = ". . H . . . H . . . H . . . H ."},
  },
  chorus = {
    pad = {main = "3 - - - - - - - 5 - - - - - - -"},
    uni = {
      "F5 - A5 - C6 - - - A5 - F5 - C6 - - -",
      "D6 - C6 - A5 - - - F5 - A5 - D5 - - -",
      "D6 - C6 - Bb5 - - - F5 - G5 - A5 - - -",
      "G5 - - - E5 - G5 - C6 - - - - - . .",
    },
    pip = {main = "K . . . H . . . K . . . H . H .", fill = "K . . . H . . . K . K . H . H H"},
    moth = {main = "1 - - - - - 5 - 1 - - - - - 5 -"},
    pearl = {main = "1 . 3 . 5 . t . f . t . 5 . 3 ."},
    nib = {main = "H . H . C . H . H . H . C . H ."},
  },
}

-- 2. Parade March: C F G C, bright and bouncy.
SONGS[2] = {
  id = "march", name = "Parade March", bpm = 112, spb = 4, bl = 16, nbars = 4, fills = {[4] = true},
  chords = {{48, "M"}, {53, "M"}, {55, "M"}, {48, "M"}},
  col = 0xffd84a, sky1 = 0x3a1840, sky2 = 0xa04870,
  tr = {
    pad = {wave = "sine", vol = 0.08, attack = 0.05, release = 0.4, pan = 0},
    uni = {wave = "square", vol = 0.05, attack = 0.005, release = 0.12, duty = 0.3, pan = -0.15},
    pip = {wave = "noise", vol = 0.075, release = 0.1, pan = 0.1},
    moth = {wave = "tri", vol = 0.17, attack = 0.005, release = 0.08, pan = 0},
    pearl = {wave = "sine", vol = 0.08, attack = 0.002, release = 0.3, pan = 0.25},
    nib = {wave = "noise", vol = 0.045, release = 0.05, pan = -0.2},
  },
  verse = {
    pad = {main = "5 - - - - - - - 3 - - - - - - -"},
    uni = {
      "G4 . G4 . C5 - - - E5 . E5 . G5 - - -",
      "A5 . A5 . F5 - - - A4 . C5 . F5 - - -",
      "B4 . B4 . D5 - - - G5 . F5 . D5 - - -",
      "E5 . D5 . C5 - - - G4 - - - . . . .",
    },
    pip = {main = "K . . . S . . . K . . . S . S .", fill = "K . . . S . . . K . S . S . S S"},
    moth = {main = "1 . . . 5 . . . 1 . . . 5 . . ."},
    pearl = {main = ". . . . 5 . . . . . . . 5 . . ."},
    nib = {main = ". . H . C . H . . . H . C . H ."},
  },
  chorus = {
    pad = {main = "5 - - - - - - - 3 - - - - - - -"},
    uni = {
      "C5 . E5 . G5 . C6 - C6 . G5 . E5 . G5 .",
      "A5 . F5 . C5 . F5 . A5 . C6 - A5 - F5 -",
      "B5 . D6 . G5 . B5 . D6 - B5 . G5 . D5 .",
      "E6 . D6 . C6 . G5 . C6 - - - . . . .",
    },
    pip = {main = "K . H . S . H . K . H . S . H .", fill = "K . K . S . S . K . S . S S S S"},
    moth = {main = "1 . 5 . 1 . 5 . 1 . 5 . 1 . 5 ."},
    pearl = {main = "1 . 5 . t . 5 . 1 . 5 . t . 5 ."},
    nib = {main = "H . H H C . H H H . H H C . H H"},
  },
}

-- 3. Disco Kitty: Am7 Dm7 G7 Cmaj7, funky, sixteenth-note groove.
SONGS[3] = {
  id = "disco", name = "Disco Kitty", bpm = 116, spb = 4, bl = 16, nbars = 4, fills = {[4] = true},
  chords = {{45, "m7"}, {50, "m7"}, {43, "7"}, {48, "maj7"}},
  col = 0xf47eb2, sky1 = 0x24104a, sky2 = 0x7a2a8a,
  tr = {
    pad = {wave = "sine", vol = 0.09, attack = 0.03, release = 0.4, pan = 0},
    uni = {wave = "saw", vol = 0.04, attack = 0.004, release = 0.15, pan = -0.15},
    pip = {wave = "noise", vol = 0.075, release = 0.1, pan = 0.1},
    moth = {wave = "saw", vol = 0.07, attack = 0.004, release = 0.09, pan = 0},
    pearl = {wave = "sine", vol = 0.08, attack = 0.002, release = 0.2, pan = 0.25},
    nib = {wave = "noise", vol = 0.035, release = 0.05, pan = -0.2},
  },
  verse = {
    pad = {main = "7 - - - - - - - 5 - - - - - - -"},
    uni = {
      ". . A4 . C5 . E5 - . . E5 . D5 . C5 .",
      ". . D5 . F5 . A5 - . . A5 . G5 . F5 .",
      ". . G4 . B4 . D5 - . . F5 . D5 . B4 .",
      "E5 - . . G5 - . . B5 - - - . . . .",
    },
    pip = {main = "K . . . S . . . K . . . S . . .", fill = "K . . . S . . . K . S . S S S S"},
    moth = {main = "1 . 8 . 1 . 8 . 1 . 8 . 1 . 8 ."},
    pearl = {main = "3 . . 5 . . 3 . . 5 . . 3 . 5 ."},
    nib = {main = ". . H . . . H . . . H . . . H ."},
  },
  chorus = {
    pad = {main = "7 - - - - - - - 5 - - - - - - -"},
    uni = {
      "A5 . . A5 C6 . E6 - E6 . D6 . C6 . A5 .",
      "A5 . . A5 D6 . F6 - F6 . E6 . D6 . A5 .",
      "B5 . . B5 D6 . G6 - G6 . F6 . D6 . B5 .",
      "E6 . G6 . E6 . D6 . C6 - - - . . . .",
    },
    pip = {main = "K . . K S . . . K . K . S . . K", fill = "K . . . S . . . K . S . S S S S"},
    moth = {main = "1 . 8 . 1 . 8 . 1 . 8 . 5 . 8 1"},
    pearl = {main = "1 5 t 5 1 5 t 5 1 5 t 5 1 5 t 5"},
    nib = {main = "H . H H C . H H H . H H C . H H"},
  },
}

-- 4. Twirly Waltz: three beats to a bar, eight bars. D Bm G A7, then D G A7 D.
SONGS[4] = {
  id = "waltz", name = "Twirly Waltz", bpm = 132, spb = 4, bl = 12, nbars = 8, fills = {[4] = true, [8] = true},
  chords = {{50, "M"}, {47, "m"}, {43, "M"}, {45, "7"}, {50, "M"}, {43, "M"}, {45, "7"}, {50, "M"}},
  col = 0x78dcc8, sky1 = 0x103a46, sky2 = 0x2a7a84,
  tr = {
    pad = {wave = "sine", vol = 0.09, attack = 0.1, release = 0.5, pan = 0},
    uni = {wave = "tri", vol = 0.10, attack = 0.01, release = 0.3, pan = -0.15},
    pip = {wave = "noise", vol = 0.06, release = 0.1, pan = 0.1},
    moth = {wave = "tri", vol = 0.15, attack = 0.008, release = 0.2, pan = 0},
    pearl = {wave = "sine", vol = 0.08, attack = 0.002, release = 0.4, pan = 0.25},
    nib = {wave = "noise", vol = 0.04, release = 0.05, pan = -0.2},
  },
  verse = {
    pad = {main = "3 - - - - - 5 - - - - -"},
    uni = {
      "A4 - - - D5 - - - F#5 - - -",
      "F#5 - - - D5 - - - B4 - - -",
      "B4 - - - D5 - - - G5 - - -",
      "E5 - - - C#5 - - - A4 - - -",
      "D5 - F#5 - A5 - - - F#5 - - -",
      "G5 - B5 - D6 - - - B5 - - -",
      "C#6 - A5 - E5 - - - G5 - - -",
      "F#5 - - - D5 - - - . . . .",
    },
    pip = {main = "K . . . H . . . H . . .", fill = "K . . . S . S . S S S S"},
    moth = {main = "1 - - - 5 . . . 5 . . ."},
    pearl = {main = ". . . . 3 . . . 5 . . ."},
    nib = {main = ". . . . . . H . . . H ."},
  },
  chorus = {
    pad = {main = "3 - - - - - 5 - - - - -"},
    uni = {
      "D6 - A5 - F#5 - A5 - D6 - - -",
      "B5 - F#5 - D5 - F#5 - B5 - - -",
      "G5 - B5 - D6 - B5 - G5 - - -",
      "A5 - C#6 - E6 - C#6 - A5 - - -",
      "D6 - F#6 - A6 - - - F#6 - D6 -",
      "B5 - D6 - G6 - - - D6 - B5 -",
      "E6 - C#6 - A5 - C#6 - E6 - G6 -",
      "F#6 - - - D6 - - - D6 - . .",
    },
    pip = {main = "K . . . S . H . S . H .", fill = "K . . . S . S . S S S S"},
    moth = {main = "1 - - - 5 . 3 . 5 . . ."},
    pearl = {main = "1 . 3 . 5 . t . f . t ."},
    nib = {main = ". . H . C . H . C . H ."},
  },
}

-- ------------------------------------------------------------------ building the arrangements

local ORDER = {"pad", "uni", "pip", "moth", "pearl", "nib"}
-- How far each track sits above the chord root, so the pad is under the melody and the bells over it.
local LIFT = {pad = 12, uni = 0, pip = 0, moth = 0, pearl = 24, nib = 0}

local function arrange(sg, which)
  local src = sg[which]
  local song = {bpm = sg.bpm, steps = sg.spb}
  local arr = {song = song, toks = {}, mid = {}, on = {}, len = sg.bl * sg.nbars}
  for t, key in ipairs(ORDER) do
    local str = expand(sg, src[key], LIFT[key], which .. " " .. key)
    local p = sg.tr[key]
    song[t] = {str, wave = p.wave, vol = p.vol * (which == "chorus" and 1.12 or 1), attack = p.attack,
      release = p.release, duty = p.duty, pan = p.pan}
    local tk = toks(str)
    local mid, on = {}, {}
    for i = 1, #tk do
      local k = tk[i]
      mid[i] = midi_of(k)
      on[i] = k ~= "." and k ~= "-"
    end
    arr.toks[t], arr.mid[t], arr.on[t] = tk, mid, on
  end
  return arr
end

for _, sg in ipairs(SONGS) do
  sg.total = sg.bl * sg.nbars
  sg.arr = {verse = arrange(sg, "verse"), chorus = arrange(sg, "chorus")}
  -- The same loop length in frames, for the chorus length and the beat in drawing.
  sg.step_frames = 3600 / (sg.bpm * sg.spb)
end

-- The chord under a step: its root and the offsets of its third, fifth and seventh. For solos and lights.
function M.chord(sg, step)
  local bar = math.floor((step % sg.total) / sg.bl) + 1
  local c = sg.chords[bar]
  local i = QI[c[2]]
  return c[1], i[1], i[2], i[3], bar
end

M.songs = SONGS
return M
