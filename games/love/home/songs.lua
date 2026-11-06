-- Home's music: every piece, written for synth.lua (its header has the notation). All original, except two
-- public-domain American tunes the Freedom Show quotes: "Yankee Doodle" (18th century) and Samuel Ward's
-- "Materna" (1882, sung as "America the Beautiful").
--
--   menu       Neon Home          the menu (A minor synthwave, 112)
--   attract    Insert Coin        the attract tour (C major, 140)
--   tv         Channel Surfing    the TV guide (lounge, swung, 92)
--   dusk quiet chase swarm stars fireflies aurora meteors city ufo digger dream dawn
--              the night show: dusk, the quiet sky between scenes, one for each scene, and dawn
--   fanfare march alert battle victory anthem
--              the Freedom Show's acts (freedom.lua)
-- SFX: short sounds the shows trigger (pew, boom, screech, ...), mixed over the music.
local M = {}

-- ------------------------------------------------------------------ instruments
local function copy(t, over)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end
local LEAD = {wave = "pulse", duty = 0.25, a = 0.005, d = 0.14, s = 0.55, r = 0.09, vol = 0.12, vib = {0.12, 5.5, 0.2}}
local BASS = {wave = "tri", a = 0.003, d = 0.12, s = 0.75, r = 0.04, vol = 0.42}
local ARP = {wave = "pulse", duty = 0.125, a = 0.002, d = 0.06, s = 0.5, r = 0.04, vol = 0.05, arp = 50, oct = 4}
local PAD = {wave = "saw", a = 0.5, d = 0.6, s = 0.7, r = 0.9, vol = 0.07, lp = 900, detune = 9, oct = 3}
local BELL = {wave = "sine", a = 0.002, d = 0.7, s = 0.0, r = 0.4, vol = 0.2, send = 0.5}
local PLUCK = {wave = "tri", a = 0.002, d = 0.35, s = 0.15, r = 0.15, vol = 0.32}

-- A bar of a bass pattern: "f2 c3" -> root, fifth on the beats ("f2*4 c3*4 f2*4 c3*4").
local function oompah(a, b) return string.format("%s*4 %s*4 %s*4 %s*4 ", a, b, a, b) end
local function eights(a, b) return string.rep(a .. "*2 " .. b .. "*2 ", 4) end
local function sixteens(a, b) return string.rep(a .. " " .. a .. " " .. b .. " " .. a .. " ", 4) end

-- ------------------------------------------------------------------ Home
M.menu = {
  bpm = 112, gain = 1, echo = {time = 0.4, fb = 0.3, mix = 0.22},
  inst = {lead = copy(LEAD, {send = 0.4}), bass = BASS, arp = ARP,
          pad = copy(PAD, {vol = 0.045})},
  parts = {
    I = {arp = "Am*16 F*16 C*16 G*16",
         bass = eights("a2", "a3") .. eights("f2", "f3") .. eights("c3", "c4") .. eights("g2", "g3"),
         drums = "k*4 h*4 k*4 h*4"},
    A = {lead = "e5*4 a5*2 g5*2 e5*4 d5*2 c5*2 | c5*2 d5*2 e5*4 a4*8 | g4*2 c5*2 e5*2 g5*2 f5*4 e5*4 | d5*6 b4*2 g4*8 |" ..
                "e5*4 a5*2 b5*2 c6*4 b5*2 a5*2 | g5*2 a5*2 f5*4 c5*8 | e5*2 g5*2 c6*2 b5*2 a5*2 g5*2 e5*4 | d5*4 e5*2 d5*2 b4*8",
         arp = "Am*16 F*16 C*16 G*16",
         pad = "Am*16 F*16 C*16 G*16",
         bass = eights("a2", "a3") .. eights("f2", "f3") .. eights("c3", "c4") .. eights("g2", "g3"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead = "f5*4 e5*4 d5*4 c5*4 | a4*8 c5*8 | b4*4 d5*4 g5*8 | g#5*8 e5*4 .*4",
         arp = "Dm*16 F*16 G*16 E*16",
         pad = "Dm*16 F*16 G*16 E*16",
         bass = eights("d2", "d3") .. eights("f2", "f3") .. eights("g2", "g3") .. eights("e2", "e3"),
         drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 x*2"},
  },
  order = {"I", "A", "A", "B", "A"},
}

M.attract = {
  bpm = 140, gain = 1,
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.11}), bass = copy(BASS, {gate = 0.7}), arp = copy(ARP, {oct = 4})},
  parts = {
    A = {lead = "c5*2 e5*2 g5*2 c6*2 b5*2 g5*2 e5*2 g5*2 | a5*2 e5*2 c5*2 e5*2 a5*4 g5*4 |" ..
                "f5*2 a5*2 c6*2 a5*2 g5*2 f5*2 e5*2 d5*2 | d5*2 g5*2 b5*2 d6*2 c6*4 b5*4",
         arp = "C*16 Am*16 F*16 G*16",
         bass = eights("c3", "g3") .. eights("a2", "e3") .. eights("f2", "c3") .. eights("g2", "d3"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead = "a5*4 c6*4 a5*4 f5*4 | g5*4 b5*4 d6*8 | e6*4 d6*4 b5*4 g5*4 | a5*12 .*4",
         arp = "F*16 G*16 Em*16 Am*16",
         bass = eights("f2", "c3") .. eights("g2", "d3") .. eights("e2", "b2") .. eights("a2", "e3"),
         drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 s?*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.tv = {
  bpm = 92, steps = 2, swing = 0.32, gain = 0.95, echo = {time = 0.33, fb = 0.25, mix = 0.2},
  inst = {vib = {wave = "sine", a = 0.002, d = 1.1, s = 0.0, r = 0.3, vol = 0.2, trem = {0.35, 5.5}, send = 0.4},
          keys = {wave = "sine", a = 0.004, d = 0.7, s = 0.25, r = 0.3, vol = 0.12, oct = 4, trem = {0.2, 4}},
          bass = copy(BASS, {vol = 0.38, gate = 0.8})},
  parts = {
    A = {vib = "e5*3 g5 b5*2 a5*2 | g5*3 e5 c5*4 | f5*3 a5 c6*2 b5*2 | a5*2 g5*2 f5*2 d5*2 |" ..
               "e5*2 g5*2 c6*2 b5*2 | c#6*4 a5*4 | d6*2 c6*2 a5*2 f5*2 | g5*4 d5*2 b4*2",
         keys = "Cmaj7*3 Cmaj7*5 | Am7*3 Am7*5 | Dm7*3 Dm7*5 | G7*3 G7*5 | Cmaj7*3 Cmaj7*5 | A7*3 A7*5 | Dm7*3 Dm7*5 | G7*3 G7*5",
         bass = "c3*2 e3*2 g3*2 a3*2 | a2*2 c3*2 e3*2 g3*2 | d3*2 f3*2 a3*2 c4*2 | g2*2 b2*2 d3*2 f3*2 |" ..
                "c3*2 e3*2 g3*2 a3*2 | a2*2 c#3*2 e3*2 g3*2 | d3*2 f3*2 a3*2 c4*2 | g2*2 b2*2 d3*2 f3*2",
         drums = "k h r? h k h r? h"},
    B = {vib = "a5*4 g5*2 f5*2 | e5*4 g5*4 | f5*2 e5*2 d5*2 c5*2 | d5*8",
         keys = "Fmaj7*3 Fmaj7*5 | Em7*3 Em7*5 | Dm7*3 Dm7*5 | G7*3 G7*5",
         bass = "f2*2 a2*2 c3*2 e3*2 | e2*2 g2*2 b2*2 d3*2 | d3*2 f3*2 a3*2 c4*2 | g2*2 b2*2 d3*2 f3*2",
         drums = "k h r? h k h r? h"},
  },
  order = {"A", "B", "A"},
}

-- ------------------------------------------------------------------ the night (soft: the cabinet sleeps)
M.dusk = {
  bpm = 72, gain = 0.8, echo = {time = 0.42, fb = 0.4, mix = 0.3},
  inst = {pad = PAD, arp = copy(BELL, {arp = "up", vol = 0.09, oct = 4, d = 0.4}),
          lead = {wave = "tri", a = 0.04, d = 0.3, s = 0.8, r = 0.4, vol = 0.2, vib = {0.1, 4.5, 0.4}, send = 0.3},
          bass = copy(BASS, {vol = 0.32, a = 0.05, r = 0.3})},
  parts = {
    A = {pad = "Fmaj7*16 Dm7*16 Bbmaj7*16 C*16", arp = "Fmaj7*16 Dm7*16 Bbmaj7*16 C*16",
         lead = "a5*8 g5*4 f5*4 | e5*8 d5*8 | f5*8 d5*4 c5*4 | e5*12 .*4",
         bass = "f2*16 d2*16 bb2*16 c3*16"},
    B = {pad = "Gm7*16 C7*16 Fmaj7*16 Dm7*16", arp = "Gm7*16 C7*16 Fmaj7*16 Dm7*16",
         lead = "d5*8 bb4*4 c5*4 | e5*8 g5*8 | a5*12 c6*4 | a5*16",
         bass = "g2*16 c3*16 f2*16 d2*16"},
  },
  order = {"A", "B", "A", "B"},
}

M.quiet = {
  bpm = 60, gain = 1.3, echo = {time = 0.5, fb = 0.5, mix = 0.4},
  inst = {pad = copy(PAD, {vol = 0.05, a = 1.5, r = 1.5}), bell = BELL},
  parts = {
    A = {pad = "Am7*16 Fmaj7*16 Cmaj7*16 Em7*16", bell = "e5*8 .*8 | g5*4 a5*4 .*8 | c6*8 .*4 b5*4 | a5*16"},
    B = {pad = "Fmaj7*16 G*16 Am7*16 Em7*16", bell = ".*8 d5*8 | e5*16 | g5*4 e5*4 d5*8 | e5*16"},
  },
  order = {"A", "B"},
}

M.chase = {
  bpm = 150, gain = 0.62,
  inst = {lead = copy(LEAD, {gate = 0.75}), bass = copy(BASS, {gate = 0.55, vol = 0.36})},
  parts = {
    A = {lead = "b4*2 e5*2 g5*2 b5*2 a5*2 g5*2 e5*4 | c5*2 e5*2 g5*2 c6*2 b5*2 a5*2 g5*4 |" ..
                "f#5*2 a5*2 d6*2 a5*2 f#5*2 d5*2 e5*2 f#5*2 | d#5*4 f#5*4 b5*8",
         bass = "e2*2 e3*2 e2*2 e3*2 e2*2 e3*2 g2*2 a2*2 | c3*2 c4*2 c3*2 c4*2 c3*2 c4*2 b2*2 a2*2 |" ..
                "d3*2 d4*2 d3*2 d4*2 d3*2 d4*2 c3*2 d3*2 | b2*2 b3*2 b2*2 b3*2 f#2*2 f#3*2 a2*2 b2*2",
         drums = "k*2 h?*2 s?*2 h?*2"},
    B = {lead = "a5*4 c6*2 b5*2 a5*4 e5*4 | g5*4 b5*2 a5*2 g5*4 e5*4 | c6*2 b5*2 a5*2 g5*2 e5*4 g5*4 | f#5*2 g5*2 a5*2 b5*2 d#6*8",
         bass = eights("a2", "a3") .. eights("e2", "e3") .. eights("c3", "c4") .. eights("b2", "b3"),
         drums = "k*2 h?*2 s?*2 h?*2 k*2 k*2 s?*2 h?*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.swarm = {
  bpm = 120, gain = 0.85, echo = {time = 0.375, fb = 0.35, mix = 0.25},
  inst = {beat = {wave = "pulse", duty = 0.5, a = 0.002, d = 0.25, s = 0.2, r = 0.05, vol = 0.12, lp = 700},
          lead = {wave = "saw", a = 0.03, d = 0.3, s = 0.7, r = 0.3, vol = 0.07, lp = 1800, vib = {0.2, 5, 0.3}, send = 0.4},
          stab = copy(ARP, {arp = 30, vol = 0.04, oct = 5})},
  parts = {
    A = {beat = "f#2*4 e2*4 d2*4 c#2*4", drums = "k?*4 h?*4 k?*4 h?*4"},
    B = {beat = "f#2*4 e2*4 d2*4 c#2*4",
         lead = "f#5*8 a5*4 g#5*4 | f#5*4 e5*4 c#5*8 | d5*8 e5*4 f#5*4 | c#5*16",
         stab = "F#m*2 .*14 | .*16 | D*2 .*14 | C#*2 .*14", drums = "k*4 h*4 k*4 h*4"},
    C = {beat = "f#2*2 f#2*2 e2*2 e2*2 d2*2 d2*2 c#2*2 c#2*2",
         lead = "a5*2 c#6*2 a5*2 f#5*2 e5*4 c#5*4 | d5*2 f#5*2 d5*2 b4*2 c#5*8 | a5*2 c#6*2 e6*4 d6*4 c#6*4 | b5*8 c#6*8",
         drums = "k*2 h*2 s?*2 h*2"},
  },
  order = {"A", "B", "C", "B"},
}

M.stars = {
  bpm = 90, gain = 1.15, echo = {time = 0.5, fb = 0.45, mix = 0.35},
  inst = {arp = copy(BELL, {arp = "up", oct = 5, vol = 0.07, d = 0.25, send = 0.6}), pad = copy(PAD, {vol = 0.05}),
          lead = {wave = "sine", a = 0.05, d = 0.4, s = 0.7, r = 0.5, vol = 0.16, vib = {0.15, 5, 0.3}, slide = 0.08, send = 0.4}},
  parts = {
    A = {arp = "Emaj7*16 Amaj7*16 C#m7*16 Bsus4*16", pad = "Emaj7*16 Amaj7*16 C#m7*16 B*16",
         lead = "g#5*8 b5*4 d#6*4 | c#6*12 b5*4 | e5*8 g#5*8 | f#5*16"},
    B = {arp = "Amaj7*16 G#m7*16 F#m7*16 Bsus4*16", pad = "Amaj7*16 G#m7*16 F#m7*16 B*16",
         lead = "a5*8 g#5*4 e5*4 | d#5*12 b4*4 | c#5*4 e5*4 f#5*4 a5*4 | g#5*8 f#5*8"},
    C = {arp = "Emaj7*16 B*16 Amaj7*16 B*16", pad = "Emaj7*16 B*16 Amaj7*16 B*16",
         lead = "b5*4 c#6*4 e6*8 | d#6*8 b5*8 | a5*4 g#5*4 f#5*4 e5*4 | f#5*16"},
  },
  order = {"A", "B", "C", "A"},
}

M.fireflies = {
  bpm = 104, gain = 1.2, echo = {time = 0.29, fb = 0.3, mix = 0.25},
  inst = {box = copy(BELL, {vol = 0.18, d = 0.5, send = 0.35}), chord = copy(BELL, {vol = 0.055, d = 0.25, oct = 4}),
          bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {box = "d5*4 g5*4 b5*4 | a5*8 f#5*4 | e5*4 g5*4 c6*4 | b5*12 | a5*4 c6*4 e6*4 | d6*8 b5*4 | a5*4 f#5*4 d5*4 | g5*12",
         chord = ".*4 G*4 G*4 | .*4 D7*4 D7*4 | .*4 C*4 C*4 | .*4 G*4 G*4 | .*4 Am*4 Am*4 | .*4 G*4 G*4 | .*4 D7*4 D7*4 | .*4 G*4 G*4",
         bass = "g2*12 | d2*12 | c3*12 | g2*12 | a2*12 | d2*12 | d2*12 | g2*12"},
    B = {box = "b5*4 c6*4 d6*4 | e6*8 c6*4 | a5*4 b5*4 c6*4 | d6*8 b5*4 | g5*4 a5*4 b5*4 | c6*8 a5*4 | f#5*4 g5*4 a5*4 | g5*12",
         chord = ".*4 Em*4 Em*4 | .*4 Am*4 Am*4 | .*4 D*4 D*4 | .*4 G*4 G*4 | .*4 Em*4 Em*4 | .*4 Am*4 Am*4 | .*4 D7*4 D7*4 | .*4 G*4 G*4",
         bass = "e2*12 | a2*12 | d2*12 | g2*12 | e2*12 | a2*12 | d2*12 | g2*12"},
  },
  order = {"A", "B", "A"},
}

M.aurora = {
  bpm = 60, gain = 0.7, echo = {time = 0.6, fb = 0.5, mix = 0.4},
  inst = {pad = copy(PAD, {a = 1.6, r = 2, vol = 0.06, lp = 700}),
          lead = {wave = "sine", a = 0.3, d = 0.5, s = 0.8, r = 1.2, vol = 0.15, slide = 0.25, vib = {0.25, 5.5, 0.6}, send = 0.5},
          bass = {wave = "sine", a = 0.5, d = 0.5, s = 0.8, r = 1, vol = 0.25}},
  parts = {
    A = {pad = "Dmaj7*16 E*16 Bm7*16 Gmaj7*16", lead = "a5*12 g#5*4 | b5*16 | f#5*8 d5*8 | e5*16",
         bass = "d3*16 e3*16 b2*16 g2*16"},
    B = {pad = "Dmaj7*16 E*16 Gmaj7*16 A*16", lead = "c#6*8 b5*8 | g#5*12 e5*4 | g5*8 b5*8 | a5*16",
         bass = "d3*16 e3*16 g2*16 a2*16"},
  },
  order = {"A", "B"},
}

M.meteors = {
  bpm = 126, gain = 0.7, echo = {time = 0.36, fb = 0.4, mix = 0.3},
  inst = {arp = copy(ARP, {arp = "down", oct = 5, vol = 0.045, d = 0.08}), bass = copy(BASS, {vol = 0.34, gate = 0.6}),
          lead = copy(LEAD, {duty = 0.5, vol = 0.09, send = 0.4})},
  parts = {
    A = {arp = "Cm*16 Ab*16 Eb*16 Bb*16", bass = eights("c3", "c2") .. eights("ab2", "ab1") .. eights("eb2", "eb3") .. eights("bb2", "bb1"),
         lead = "g5*2 f5*2 eb5*2 d5*2 c5*8 | ab5*2 g5*2 f5*2 eb5*2 c5*8 | bb5*2 ab5*2 g5*2 f5*2 eb5*4 g5*4 | f5*2 eb5*2 d5*2 bb4*2 d5*8",
         drums = "k*4 h?*4 s?*4 h?*4"},
    B = {arp = "Fm*16 Ab*16 Bb*16 Cm*16", bass = eights("f2", "f3") .. eights("ab2", "ab1") .. eights("bb2", "bb1") .. eights("c3", "c2"),
         lead = "c6*4 bb5*4 ab5*4 f5*4 | eb5*4 f5*4 ab5*8 | bb5*4 ab5*4 g5*4 f5*4 | g5*16",
         drums = "k*4 h?*4 s?*4 h?*4"},
    C = {arp = "Ab*16 Eb*16 Fm*16 G*16", bass = eights("ab2", "ab1") .. eights("eb2", "eb3") .. eights("f2", "f3") .. eights("g2", "g1"),
         lead = "c6*4 eb6*4 c6*4 ab5*4 | g5*4 bb5*4 eb6*8 | f5*4 ab5*4 c6*4 f6*4 | d6*8 b5*8",
         drums = "k*4 h?*4 s?*4 h?*4"},
  },
  order = {"A", "B", "A", "C"},
}

M.city = {
  bpm = 118, gain = 0.85, echo = {time = 0.38, fb = 0.35, mix = 0.28}, drums_send = 0.35,
  inst = {lead = {wave = "pulse", duty = 0.4, pwm = {0.12, 0.3}, a = 0.01, d = 0.2, s = 0.65, r = 0.15, vol = 0.09,
                  detune = 7, vib = {0.12, 5, 0.25}, send = 0.4},
          bass = {wave = "saw", a = 0.003, d = 0.12, s = 0.5, r = 0.05, vol = 0.14, lp = 600, gate = 0.7},
          pad = copy(PAD, {vol = 0.05})},
  parts = {
    A = {lead = "c#5*4 e5*4 f#5*6 a5*2 | f#5*4 e5*4 d5*8 | e5*4 c#5*4 a4*8 | b4*4 c#5*4 e5*4 g#5*4",
         bass = string.rep("f#2*2 ", 8) .. string.rep("d2*2 ", 8) .. string.rep("a2*2 ", 8) .. string.rep("e2*2 ", 8),
         pad = "F#m*16 D*16 A*16 E*16", drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 h*2"},
    B = {lead = "a5*6 g#5*2 f#5*4 e5*4 | f#5*6 e5*2 d5*8 | c#5*4 e5*4 a5*4 c#6*4 | b5*16",
         bass = string.rep("d2*2 ", 8) .. string.rep("b1*2 ", 8) .. string.rep("a2*2 ", 8) .. string.rep("e2*2 ", 8),
         pad = "D*16 Bm*16 A*16 E*16", drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 x*2"},
  },
  order = {"A", "B", "A", "B"},
}

M.ufo = {
  bpm = 72, gain = 0.85, echo = {time = 0.45, fb = 0.45, mix = 0.35},
  inst = {lead = {wave = "sine", a = 0.15, d = 0.3, s = 0.9, r = 0.6, vol = 0.2, slide = 0.35, vib = {0.35, 6, 0.1}, send = 0.5},
          pad = copy(PAD, {lp = 600, vol = 0.06}),
          blip = copy(ARP, {arp = "updown", oct = 6, vol = 0.025, wave = "pulse"})},
  parts = {
    A = {lead = "c5*8 eb5*4 d5*4 | ab5*12 g5*4 | f#5*8 d5*8 | c5*16", pad = "Cm*16 Abmaj7*16 D7*16 Cm*16",
         blip = "Cdim7*16 | .*16 | Cdim7*16 | .*16"},
    B = {lead = "g5*8 c6*8 | b5*12 g5*4 | ab5*8 f5*8 | g5*16", pad = "Cm*16 G7*16 Fm*16 G*16",
         blip = ".*16 | Cdim7*16 | .*16 | Cdim7*16"},
  },
  order = {"A", "B"},
}

M.digger = {
  bpm = 132, gain = 0.75,
  inst = {lead = copy(LEAD, {gate = 0.6, vol = 0.1}), bass = copy(BASS, {gate = 0.5, vol = 0.34})},
  parts = {
    A = {lead = "g4*2 .*2 b4*2 .*2 d5*2 .*2 b4*2 .*2 | c5*2 .*2 e5*2 .*2 d5*8 | b4*2 .*2 g4*2 .*2 a4*2 .*2 f#4*2 .*2 | g4*8 .*8",
         bass = oompah("g2", "d3") .. "c3*4 g3*4 d3*4 a3*4 | g2*4 d3*4 d3*4 a3*4 | " .. oompah("g2", "d3"),
         drums = "k*4 s?*4"},
    B = {lead = "e5*2 .*2 e5*2 f#5*2 g5*4 e5*4 | d5*2 .*2 d5*2 e5*2 f#5*4 d5*4 | c5*2 b4*2 a4*2 g4*2 a4*4 b4*2 c5*2 | d5*8 .*8",
         bass = oompah("e2", "b2") .. oompah("d3", "a3") .. "c3*4 g3*4 d3*4 a3*4 | " .. oompah("d3", "f#3"),
         drums = "k*4 s?*4 k*4 s?*2 s?*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.dream = {
  bpm = 66, steps = 2, gain = 1.3, echo = {time = 0.45, fb = 0.45, mix = 0.35},
  inst = {box = copy(BELL, {vol = 0.2, d = 0.6}), chord = copy(PAD, {vol = 0.04, a = 0.8, oct = 4, lp = 1200}),
          bass = copy(PLUCK, {vol = 0.22})},
  parts = {
    A = {box = "e5*2 g5 c6*2 b5 | a5*3 f5*3 | g5*2 e5 c5*3 | d5*6 | e5*2 g5 c6*2 d6 | e6*3 c6*3 | b5*2 g5 a5*2 b5 | c6*6",
         chord = "C*6 | F*6 | C*6 | G*6 | C*6 | Am*6 | G*6 | C*6",
         bass = "c3*6 | f2*6 | c3*6 | g2*6 | c3*6 | a2*6 | g2*6 | c3*6"},
  },
  order = {"A", "A"},
}

M.dawn = {
  bpm = 84, gain = 0.75, echo = {time = 0.36, fb = 0.35, mix = 0.28},
  inst = {arp = copy(BELL, {arp = "up", oct = 4, vol = 0.08, d = 0.3}),
          lead = {wave = "tri", a = 0.03, d = 0.3, s = 0.8, r = 0.3, vol = 0.2, vib = {0.1, 5, 0.3}, send = 0.3},
          bass = copy(BASS, {vol = 0.3, a = 0.05, r = 0.2}),
          bird = {wave = "sine", a = 0.002, d = 0.08, s = 0.3, r = 0.03, vol = 0.07, slide = 0.02, vib = {0.8, 22, 0}}},
  parts = {
    A = {lead = "d5*4 g5*4 a5*4 b5*4 | a5*8 f#5*8 | g5*4 b5*4 e6*8 | d6*12 .*4", arp = "G*16 D*16 Em*16 C*16",
         bass = "g2*16 f#2*16 e2*16 c3*16", bird = ".*10 g7 a7 .*4 | .*16 | .*6 e7 g7 e7 .*7 | .*16"},
    B = {lead = "e6*4 d6*4 b5*4 g5*4 | a5*8 d6*8 | c6*4 b5*4 a5*4 g5*4 | g5*16", arp = "Cmaj7*16 D*16 Am7*16 G*16",
         bass = "c3*16 d3*16 a2*16 g2*16", bird = ".*16 | .*4 b7 g7 .*10 | .*16 | .*12 d7 e7 d7 ."},
    C = {lead = "b5*4 d6*4 g6*8 | f#6*8 d6*8 | e6*4 c6*4 a5*4 f#5*4 | g5*16", arp = "G*16 D*16 C*16 G*16",
         bass = "g2*16 d3*16 c3*16 g2*16", bird = ".*12 a7 b7 .*2 | .*16 | .*16 | .*8 g7 a7 g7 .*5"},
  },
  order = {"A", "B", "C", "A"},
}

-- ------------------------------------------------------------------ the Freedom Show
local BUGLE = {wave = "pulse", duty = 0.5, a = 0.02, d = 0.15, s = 0.7, r = 0.1, vol = 0.12, vib = {0.1, 5, 0.25}, detune = 5}
local PICCOLO = {wave = "pulse", duty = 0.125, a = 0.003, d = 0.1, s = 0.6, r = 0.05, vol = 0.05}
local BRASS_PAD = copy(PAD, {a = 0.08, vol = 0.07, lp = 1500, oct = 3})

M.fanfare = {
  bpm = 108, gain = 1, loop = false, after = "march",
  inst = {lead = BUGLE, lead_2 = BUGLE, bass = BASS},
  parts = {
    A = {lead = "f4*2 bb4*2 d5*2 f5*6 d5*2 f5*2 | bb5*12 .*4",
         lead_2 = "d4*2 f4*2 bb4*2 d5*6 bb4*2 d5*2 | f5*12 .*4",
         bass = "bb2*4 .*12 | bb2*12 .*4",
         drums = "s? s? s? s? s? s? s? s? s s s s s! s! s! s! | c+k!*12 .*4"},
  },
  order = {"A"},
}

-- America the Beautiful (Materna), in C: transposed by the order. Pickup bar first.
local MATERNA = ".*12 g4*4 | g4*6 e4*2 e4*4 g4*4 | g4*6 d4*2 d4*4 e4*4 | f4*4 g4*4 a4*4 b4*4 | g4*12 g4*4 |" ..
                "g4*6 e4*2 e4*4 g4*4 | g4*6 d4*2 d4*4 d5*4 | c#5*4 d5*4 e5*4 a4*4 | d5*12 d5*4 |" ..
                "e5*6 d5*2 d5*4 c5*4 | c5*6 b4*2 b4*4 c5*4 | d5*4 b4*4 a4*4 g4*4 | c5*12 c5*4 |" ..
                "c5*6 a4*2 a4*4 c5*4 | c5*6 g4*2 g4*4 g4*4 | a4*4 c5*4 g4*4 d5*4 | c5*16"
local MATERNA_PAD = "G*16 | C*16 | G7*16 | F*8 G7*8 | C*16 | C*16 | G*16 | A7*16 | D7*16 |" ..
                    "C*16 | G7*16 | G7*16 | C*16 | F*16 | C*16 | F*8 G7*8 | C*16"
local MATERNA_BASS = "g2*16 | c3*8 g2*8 | g2*8 d3*8 | f2*8 g2*8 | c3*8 g2*8 | c3*8 g2*8 | g2*8 d3*8 | a2*8 e2*8 | d3*8 a2*8 |" ..
                     "c3*8 g2*8 | g2*8 d3*8 | g2*8 d3*8 | c3*8 g2*8 | f2*8 c3*8 | c3*8 g2*8 | f2*8 g2*8 | c3*8 g2*8"
-- Yankee Doodle, in Bb (eighth notes), and its piccolo obbligato.
local DOODLE = "bb4*2 bb4*2 c5*2 d5*2 bb4*2 d5*2 c5*2 f4*2 | bb4*2 bb4*2 c5*2 d5*2 bb4*4 a4*4 |" ..
               "bb4*2 bb4*2 c5*2 d5*2 eb5*2 d5*2 c5*2 bb4*2 | a4*2 f4*2 g4*2 a4*2 bb4*4 bb4*4"
local function octave_up(text)
  return (text:gsub("(%l[b#]?)(%d)", function(n, o) return n .. (tonumber(o) + 1) end))
end
local DOODLE_HI = octave_up(DOODLE)
local DOODLE_BASS = "bb2*4 f2*4 f2*4 c3*4 | bb2*4 f2*4 f2*4 c3*4 | bb2*4 f2*4 eb2*4 bb2*4 | f2*4 c3*4 bb2*4 f2*4"
local OBBLIGATO = "f6 g6 f6 g6 f6 g6 f6 g6 f6*4 d6*4 | c6 d6 c6 d6 c6 d6 c6 d6 c6*4 a5*4 |" ..
                  "d6 eb6 d6 eb6 d6 eb6 d6 eb6 g6*4 eb6*4 | c6*4 a5*4 bb5*8"
local MARCH_DRUMS = "k*2 s?*2 s*2 s?*2 k*2 s?*2 s!*2 s?*2"

M.march = {
  bpm = 120, gain = 1,
  inst = {lead = copy(BUGLE, {detune = 6}), lead_2 = copy(BUGLE, {vol = 0.06, detune = 0}), pic = PICCOLO,
          bass = copy(BASS, {gate = 0.5, vol = 0.45}), pad = BRASS_PAD},
  parts = {
    I = {drums = "s! s? s s s! s? s s s! s? s s s! . s . | s! s s s! s s s! . c+k!*8",
         bass = "bb2*2 .*2 f2*2 .*2 bb2*2 .*2 f2*2 .*2 | bb2*2 .*2 f2*2 .*2 bb2*8"},
    A = {lead = "f5*4 d5*2 bb4*2 f4*4 bb4*4 | d5*2 c5*2 d5*2 eb5*2 f5*8 | g5*4 eb5*2 c5*2 g4*4 c5*4 | eb5*2 d5*2 c5*2 bb4*2 a4*4 c5*4 |" ..
                "f5*4 d5*2 bb4*2 f4*4 bb4*4 | d5*2 c5*2 d5*2 g5*2 bb5*8 | a5*4 g5*2 f5*2 eb5*4 c5*4 | d5*4 f5*4 bb5*4 .*4",
         lead_2 = "d5*16 | bb4*16 | eb5*16 | c5*16 | d5*16 | bb4*16 | c5*8 eb5*8 | f5*12 .*4",
         bass = oompah("bb2", "f2") .. oompah("bb2", "f2") .. oompah("c3", "g2") .. oompah("f2", "c3") ..
                oompah("bb2", "f2") .. oompah("g2", "d3") .. "eb2*4 bb2*4 f2*4 c3*4 | " .. oompah("bb2", "f2"),
         drums = MARCH_DRUMS},
    B = {lead = DOODLE .. " | " .. DOODLE_HI, pic = OBBLIGATO, bass = DOODLE_BASS .. " | " .. DOODLE_BASS,
         drums = MARCH_DRUMS .. " | " .. MARCH_DRUMS:gsub("k%*2 s%?%*2", "c+k*2 s?*2", 1) .. " | " .. MARCH_DRUMS .. " | " .. MARCH_DRUMS},
    C = {lead = MATERNA, pad = MATERNA_PAD, bass = MATERNA_BASS, drums = "k*4 s?*4 k*4 s?*4"},
    D = {lead = MATERNA, lead_2 = octave_up(MATERNA), pad = MATERNA_PAD,
         bass = MATERNA_BASS, pic = ".*16 " .. string.rep(OBBLIGATO .. " ", 4), drums = "c+k!*4 s*4 k*4 s*2 s*2"},
  },
  -- (the last time round, a semitone up: the key change)
  order = {"I", "A", "A", "B", "C+3", "D+4"},
}

M.alert = {
  bpm = 132, gain = 0.95,
  inst = {siren = {wave = "pulse", duty = 0.5, a = 0.01, d = 0.1, s = 0.9, r = 0.1, vol = 0.06, slide = 0.22},
          bass = copy(BASS, {gate = 0.6}), lead = copy(LEAD, {wave = "saw", lp = 2500, vol = 0.09}),
          stab = copy(BRASS_PAD, {a = 0.01, d = 0.15, s = 0.3, r = 0.1, vol = 0.09})},
  parts = {
    A = {siren = "a5*8 d6*8", bass = eights("d2", "d3") .. eights("d2", "d3") .. eights("bb1", "bb2") .. eights("a1", "a2"),
         stab = "Dm*2 .*6 Dm*2 .*2 Dm*2 .*2 | Dm*2 .*6 Dm*2 .*2 Dm*2 .*2 | Bb*2 .*6 Bb*2 .*2 Bb*2 .*2 | A*2 .*6 A*2 .*2 A*2 .*2",
         drums = "k*2 h*2 x*2 h*2"},
    B = {siren = "a5*8 d6*8", lead = "d5*4 f5*4 a5*4 d6*4 | c#6*8 a5*8 | bb5*4 a5*4 g5*4 f5*4 | e5*8 c#5*8",
         bass = eights("d2", "d3") .. eights("a1", "a2") .. eights("g2", "g3") .. eights("a1", "a2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
  },
  order = {"A", "B", "A", "B"},
}

M.battle = {
  bpm = 156, gain = 1,
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.1}), bass = copy(BASS, {gate = 0.7, vol = 0.38}),
          beat = {wave = "pulse", duty = 0.5, a = 0.002, d = 0.2, s = 0.3, r = 0.05, vol = 0.07, lp = 900},
          brass = BRASS_PAD},
  parts = {
    A = {lead = "e5*2 .*2 e5*2 g5*2 b5*4 a5*2 g5*2 | e5*2 .*2 e5*2 g5*2 c6*4 b5*2 a5*2 | a5*2 c6*2 b5*2 a5*2 e5*4 c5*4 | b4*2 d#5*2 f#5*2 a5*2 b5*8",
         bass = sixteens("e2", "e3") .. sixteens("c2", "c3") .. sixteens("a1", "a2") .. sixteens("b1", "b2"),
         beat = "e3*4 d3*4 c3*4 b2*4", drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead = "d5*4 g5*4 b5*4 d6*4 | a5*4 f#5*4 d6*8 | b5*4 g5*4 e5*4 g5*4 | c6*4 e6*4 g5*4 c6*4 |" ..
                "e6*8 d6*4 c6*4 | d6*4 a5*4 f#5*4 a5*4 | g5*16 | .*8 d6*2 d6*2 d6*4",
         brass = "G*16 D*16 Em*16 C*16 C*16 D*16 G*16 D7*16",
         bass = eights("g2", "g3") .. eights("d2", "d3") .. eights("e2", "e3") .. eights("c2", "c3") ..
                eights("c2", "c3") .. eights("d2", "d3") .. eights("g2", "g3") .. eights("d2", "d3"),
         drums = "c+k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2 | k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.victory = {
  bpm = 132, gain = 1,
  inst = {lead = copy(BUGLE, {vol = 0.12}), lead_2 = copy(BUGLE, {vol = 0.06, detune = 0}), pic = PICCOLO,
          bass = copy(BASS, {gate = 0.6, vol = 0.42}), brass = BRASS_PAD},
  parts = {
    A = {lead = "bb4*2 d5*2 f5*2 bb5*6 f5*2 bb5*2 | d6*12 c6*2 bb5*2 | c6*4 a5*4 f5*4 c6*4 | bb5*12 .*4",
         lead_2 = "f4*2 bb4*2 d5*2 f5*6 d5*2 f5*2 | bb5*12 a5*2 g5*2 | a5*4 f5*4 c5*4 a5*4 | d5*12 .*4",
         brass = "Bb*16 Bb*8 Gm*8 F*16 Bb*16",
         bass = "bb2*4 f2*4 bb2*4 d3*4 | bb2*4 f2*4 g2*4 d3*4 | f2*4 c3*4 f2*4 a2*4 | bb2*4 f2*4 bb2*8",
         drums = "c+k!*2 s*2 k*2 s*2 k*2 s*2 k*2 s!*2 | k*2 s*2 k*2 s*2 k*2 s*2 s s s! s!"},
    B = {lead = DOODLE_HI, lead_2 = DOODLE, pic = OBBLIGATO, bass = DOODLE_BASS,
         drums = "c+k*2 s*2 k*2 s*2 k*2 s*2 k*2 s*2 | k*2 s*2 k*2 s*2 k*2 s*2 k*2 s*2"},
  },
  order = {"A", "B", "A", "B"},
}

M.anthem = {
  bpm = 76, gain = 0.9, echo = {time = 0.4, fb = 0.35, mix = 0.3},
  inst = {lead = {wave = "tri", a = 0.05, d = 0.3, s = 0.85, r = 0.4, vol = 0.24, vib = {0.12, 5, 0.3}, send = 0.3},
          lead_2 = copy(BELL, {vol = 0.1}), pad = copy(PAD, {vol = 0.06}), bass = copy(BASS, {vol = 0.3, a = 0.04, r = 0.3})},
  parts = {
    C = {lead = MATERNA, pad = MATERNA_PAD, bass = MATERNA_BASS},
    D = {lead = MATERNA, lead_2 = octave_up(MATERNA), pad = MATERNA_PAD,
         bass = MATERNA_BASS},
  },
  order = {"C+3", "D+4"},
}

-- ------------------------------------------------------------------ Texas (texas.lua): all original
local HARMONICA = {wave = "pulse", duty = 0.45, a = 0.04, d = 0.2, s = 0.75, r = 0.15, vol = 0.1, vib = {0.18, 5.5, 0.15},
                   lp = 2600, send = 0.3}
local FIDDLE = {wave = "saw", a = 0.03, d = 0.2, s = 0.75, r = 0.12, vol = 0.09, vib = {0.2, 6, 0.12}, lp = 2400, send = 0.25}
local STEEL = {wave = "sine", a = 0.05, d = 0.4, s = 0.7, r = 0.4, vol = 0.14, slide = 0.14, vib = {0.15, 5, 0.3}, send = 0.4}
local GUITAR = {wave = "pulse", duty = 0.25, a = 0.002, d = 0.3, s = 0.2, r = 0.15, vol = 0.07, lp = 2200}
local CHOP = {wave = "pulse", duty = 0.3, a = 0.002, d = 0.08, s = 0.0, r = 0.05, vol = 0.05, oct = 4, lp = 2000}
local ACCORDION = {wave = "pulse", duty = 0.5, a = 0.02, d = 0.1, s = 0.85, r = 0.08, vol = 0.08, detune = 12, vib = {0.08, 6, 0.1}, lp = 2600}
local TRUMPET = {wave = "pulse", duty = 0.45, a = 0.05, d = 0.2, s = 0.8, r = 0.25, vol = 0.11, detune = 4, vib = {0.14, 5, 0.3}, lp = 2200, send = 0.35}

M.tx_sunrise = {
  bpm = 72, gain = 0.9, echo = {time = 0.42, fb = 0.35, mix = 0.3},
  inst = {lead = HARMONICA, arp = copy(GUITAR, {arp = "up", oct = 3, d = 0.35}), pad = copy(PAD, {vol = 0.045}),
          bass = copy(BASS, {vol = 0.3, a = 0.04, r = 0.3})},
  parts = {
    A = {lead = "d5*8 b4*4 d5*4 | e5*12 d5*4 | b4*8 g4*4 a4*4 | b4*16", arp = "G*16 D*16 Em*16 C*16",
         pad = "G*16 D*16 Em*16 Cmaj7*16", bass = "g2*16 d2*16 e2*16 c3*16"},
    B = {lead = "c5*8 e5*4 d5*4 | b4*8 g4*8 | a4*8 b4*4 c5*4 | d5*16", arp = "C*16 G*16 D*16 G*16",
         pad = "C*16 G*16 D*16 G*16", bass = "c3*16 g2*16 d2*16 g2*16"},
  },
  order = {"A", "B", "A", "B"},
}

M.tx_waltz = {
  bpm = 104, gain = 1.6, echo = {time = 0.29, fb = 0.25, mix = 0.2},
  inst = {lead = FIDDLE, chord = copy(GUITAR, {oct = 4, d = 0.2, vol = 0.05}), bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = "a4*4 d5*4 f#5*4 | a5*8 f#5*4 | e5*4 g5*4 e5*4 | c#5*12 | e5*4 a5*4 g5*4 | e5*8 c#5*4 | d5*4 f#5*4 e5*4 | d5*12",
         chord = ".*4 D*4 D*4 | .*4 D*4 D*4 | .*4 A7*4 A7*4 | .*4 A7*4 A7*4 | .*4 A7*4 A7*4 | .*4 A7*4 A7*4 | .*4 D*4 D*4 | .*4 D*4 D*4",
         bass = "d3*12 | a2*12 | a2*12 | e2*12 | a2*12 | e2*12 | d3*12 | a2*12"},
    B = {lead = "b5*4 a5*4 g5*4 | d5*8 b4*4 | a4*4 d5*4 f#5*4 | a5*12 | g5*4 f#5*4 e5*4 | c#5*8 a4*4 | d5*4 e5*4 f#5*4 | d5*12",
         chord = ".*4 G*4 G*4 | .*4 G*4 G*4 | .*4 D*4 D*4 | .*4 D*4 D*4 | .*4 A7*4 A7*4 | .*4 A7*4 A7*4 | .*4 D*4 D*4 | .*4 D*4 D*4",
         bass = "g2*12 | d3*12 | d3*12 | a2*12 | a2*12 | e2*12 | d3*12 | d3*12"},
  },
  order = {"A", "B", "A", "B"},
}

local function boogie(r, three, five, six, sev)
  return string.format("%s %s %s %s %s %s %s %s ", r, three, five, six, sev, six, five, three)
end
local AUSTIN_TAIL = string.rep(boogie("a2", "c#3", "e3", "f#3", "g3"), 2) ..
  string.rep(boogie("e2", "g#2", "b2", "c#3", "d3"), 2) .. boogie("b2", "d#3", "f#3", "g#3", "a3") ..
  boogie("a2", "c#3", "e3", "f#3", "g3") .. boogie("e2", "g#2", "b2", "c#3", "d3") .. boogie("b2", "d#3", "f#3", "g#3", "a3")
M.tx_austin = {
  bpm = 112, steps = 2, swing = 0.33, gain = 0.95,
  inst = {lead = copy(GUITAR, {d = 0.25, s = 0.5, vol = 0.1, slide = 0.03, vib = {0.2, 6, 0.2}, duty = 0.3}),
          bass = copy(BASS, {gate = 0.8, vol = 0.38}), keys = copy(GUITAR, {oct = 4, vol = 0.04, d = 0.15})},
  parts = {
    A = {lead = "e5*2 g5*2 e5 d5 b4*2 | e5*4 .*4 | g5*2 a5*2 b5*2 g5*2 | e5*8 | a5*2 c#6*2 a5*2 g5*2 | e5*2 c#5*2 a4*4 |" ..
                "b4*2 e5*2 g5*2 g#5*2 | e5*8 | f#5*2 a5*2 b5*2 d#6*2 | c#6*2 a5*2 g5*2 e5*2 | e5*2 g5 g#5 b5*4 | a5*2 f#5*2 d#5*2 b4*2",
         bass = string.rep(boogie("e2", "g#2", "b2", "c#3", "d3"), 4) .. string.rep(boogie("a2", "c#3", "e3", "f#3", "g3"), 2) ..
                string.rep(boogie("e2", "g#2", "b2", "c#3", "d3"), 2) .. boogie("b2", "d#3", "f#3", "g#3", "a3") ..
                boogie("a2", "c#3", "e3", "f#3", "g3") .. boogie("e2", "g#2", "b2", "c#3", "d3") .. boogie("b2", "d#3", "f#3", "g#3", "a3"),
         keys = ".*1 E7 .*1 E7 .*1 E7 .*1 E7",
         drums = "k h s h k h s h"},
    -- the stop-time chorus: the band hits and holds, the guitar answers
    B = {lead = "b5*2 . . b5 a5 g5 e5 | g5*2 . . e5*4 | b5*2 . . b5 a5 g5 e5 | g5*8 | e6*2 d6 b5 a5*2 g5 e5 | e5*8 |" ..
                "b5*2 . . b5 a5 g5 e5 | g5*2 e5*6 | f#5 a5 b5 d6 b5*4 | a5 c#6 e6 c#6 a5*4 | g5 g#5 b5*2 e5*4 | b4*2 d#5*2 f#5*2 b5*2",
         bass = "e2*2 .*6 | e2*2 .*6 | e2*2 .*6 | e2*2 .*6 | " .. AUSTIN_TAIL,
         keys = ".*1 E7 .*1 E7 .*1 E7 .*1 E7",
         drums = "c+k*2 .*6 | k*2 .*6 | k*2 .*6 | k*2 .*6 | k h s h k h s h | k h s h k h s h | k h s h k h s h | k h s h k h s h |" ..
                 "k h s h k h s h | k h s h k h s h | k h s h k h s h | k h s! h k h s! s!"},
  },
  order = {"A", "B", "A"},
}

M.tx_swing = {
  bpm = 132, steps = 2, swing = 0.3, gain = 0.95, echo = {time = 0.23, fb = 0.2, mix = 0.15},
  inst = {lead = FIDDLE, steel = STEEL, chop = CHOP, bass = copy(BASS, {gate = 0.8, vol = 0.36})},
  parts = {
    A = {lead = "g4 b4 d5 g5 b5*2 a5*2 | g5*4 e5*2 d5*2 | e5 g5 c6 e6 d6*2 c6*2 | a5*8 | f#5 a5 c6 a5 f#5*2 d5*2 | e5 f#5 g5 a5 b5*4 |" ..
                "d6*2 b5*2 g5*2 d5*2 | g5*8",
         steel = "b4*8 | g4*8 | c5*8 | e5*8 | d5*8 | c5*8 | b4*8 | g4*8",
         chop = ".*1 G .*1 G .*1 G .*1 G | .*1 G .*1 G .*1 G .*1 G | .*1 C .*1 C .*1 C .*1 C | .*1 C6 .*1 C6 .*1 C6 .*1 C6 |" ..
                ".*1 D7 .*1 D7 .*1 D7 .*1 D7 | .*1 D7 .*1 D7 .*1 D7 .*1 D7 | .*1 G .*1 G .*1 G .*1 G | .*1 G .*1 G .*1 G .*1 G",
         bass = "g2*2 d3*2 g2*2 d3*2 | g2*2 b2*2 d3*2 b2*2 | c3*2 g2*2 c3*2 g2*2 | c3*2 e3*2 g3*2 e3*2 | d3*2 a2*2 d3*2 a2*2 |" ..
                "d3*2 f#3*2 a3*2 f#3*2 | g2*2 d3*2 g2*2 d3*2 | g2*2 b2*2 d3*2 g3*2",
         drums = "k*2 s?*2 k*2 s?*2"},
    B = {lead = "e5*2 g5*2 c6*2 g5*2 | a5*4 g5*4 | f5*2 a5*2 c6*2 a5*2 | g5*8 | e5 f5 g5 a5 b5*2 a5*2 | g5*4 f#5*2 e5*2 |" ..
                "d5*2 f#5*2 a5*2 c6*2 | b5*4 a5*4",
         steel = "e5*8 | c5*8 | a4*8 | c5*8 | g4*8 | b4*8 | a4*8 | f#4*8",
         chop = ".*1 C .*1 C .*1 C .*1 C | .*1 C .*1 C .*1 C .*1 C | .*1 F .*1 F .*1 F .*1 F | .*1 C .*1 C .*1 C .*1 C |" ..
                ".*1 G .*1 G .*1 G .*1 G | .*1 E7 .*1 E7 .*1 E7 .*1 E7 | .*1 A7 .*1 A7 .*1 A7 .*1 A7 | .*1 D7 .*1 D7 .*1 D7 .*1 D7",
         bass = "c3*2 g2*2 c3*2 g2*2 | c3*2 e3*2 g3*2 e3*2 | f2*2 c3*2 f2*2 c3*2 | c3*2 g2*2 c3*2 g2*2 | g2*2 d3*2 g2*2 d3*2 |" ..
                "e2*2 b2*2 e2*2 g#2*2 | a2*2 e3*2 a2*2 c#3*2 | d3*2 a2*2 d3*2 f#3*2",
         drums = "k*2 s?*2 k*2 s?*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.tx_alamo = {
  bpm = 64, gain = 0.85, echo = {time = 0.47, fb = 0.4, mix = 0.35},
  inst = {lead = TRUMPET, pad = copy(PAD, {vol = 0.06, lp = 800}), bass = copy(BASS, {vol = 0.3, a = 0.1, r = 0.5})},
  parts = {
    A = {lead = "a4*8 d5*4 e5*4 | f5*12 e5*4 | c5*8 a4*4 c5*4 | e5*16 | d5*8 f5*4 a5*4 | g5*8 bb4*8 | a4*8 c#5*4 e5*4 | d5*16",
         pad = "Dm*16 Bb*16 F*16 A*16 Dm*16 Gm*16 A*16 Dm*16", bass = "d2*16 bb1*16 f2*16 a1*16 d2*16 g1*16 a1*16 d2*16",
         drums = "k?*16"},
    B = {lead = "f5*8 e5*4 d5*4 | c5*12 a4*4 | bb4*8 c5*4 d5*4 | a4*16 | d5*8 e5*4 f5*4 | g5*12 f5*4 | e5*8 d5*4 c#5*4 | d5*16",
         pad = "F*16 C*16 Bb*16 A*16 Dm*16 Gm*16 A*16 Dm*16", bass = "f2*16 c2*16 bb1*16 a1*16 d2*16 g1*16 a1*16 d2*16",
         drums = "k?*16"},
  },
  order = {"A", "B", "A"},
}

M.tx_conjunto = {
  bpm = 116, gain = 0.9,
  inst = {lead = ACCORDION, chord = copy(CHOP, {vol = 0.06}), bass = copy(BASS, {gate = 0.6, vol = 0.38})},
  parts = {
    A = {lead = "e5*2 g5*2 e5*2 c5*2 | d5*2 f5*2 b4*4 | d5*2 f5*2 d5*2 b4*2 | c5*4 g4*4 | e5*2 g5*2 c6*2 b5*2 | a5*2 f5*2 d5*4 |" ..
                "g5*2 f5*2 e5*2 d5*2 | c5*4 .*4",
         chord = ".*2 C*2 .*2 C*2 | .*2 G7*2 .*2 G7*2 | .*2 G7*2 .*2 G7*2 | .*2 C*2 .*2 C*2 | .*2 C*2 .*2 C*2 | .*2 F*2 .*2 F*2 |" ..
                 ".*2 G7*2 .*2 G7*2 | .*2 C*2 .*2 C*2",
         bass = "c3*2 .*2 g2*2 .*2 | g2*2 .*2 d3*2 .*2 | g2*2 .*2 d3*2 .*2 | c3*2 .*2 g2*2 .*2 | c3*2 .*2 g2*2 .*2 | f2*2 .*2 c3*2 .*2 |" ..
                "g2*2 .*2 d3*2 .*2 | c3*2 .*2 g2*2 .*2",
         drums = "k*2 s?*2 k*2 s?*2"},
    B = {lead = "a5*2 c6*2 a5*2 f5*2 | e5*2 g5*2 c5*4 | d5*2 g5*2 b5*2 g5*2 | e5*2 c5*2 e5*4 | f5*2 a5*2 c6*2 a5*2 | g5*2 e5*2 c5*4 |" ..
                "b4*2 d5*2 f5*2 d5*2 | c5*8",
         chord = ".*2 F*2 .*2 F*2 | .*2 C*2 .*2 C*2 | .*2 G7*2 .*2 G7*2 | .*2 C*2 .*2 C*2 | .*2 F*2 .*2 F*2 | .*2 C*2 .*2 C*2 |" ..
                 ".*2 G7*2 .*2 G7*2 | .*2 C*2 .*2 C*2",
         bass = "f2*2 .*2 c3*2 .*2 | c3*2 .*2 g2*2 .*2 | g2*2 .*2 d3*2 .*2 | c3*2 .*2 g2*2 .*2 | f2*2 .*2 c3*2 .*2 | c3*2 .*2 g2*2 .*2 |" ..
                "g2*2 .*2 d3*2 .*2 | c3*2 .*2 c3*2 .*2",
         drums = "k*2 s?*2 k*2 s?*2"},
  },
  order = {"A", "B", "A", "B"},
}

-- The River Walk at dusk: a mariachi son in 3/4, two trumpets in thirds, then the violins (original)
local function bars(list, f) local t = {} for _, x in ipairs(list) do t[#t + 1] = f(x) end return table.concat(t, " | ") end
local function vihuela(c) return ".*2 " .. c .. "*2 " .. c .. "*2" end
local function guitarron(n) return n .. "*2 .*4" end
M.tx_mariachi = {
  bpm = 160, steps = 2, gain = 0.95, echo = {time = 0.28, fb = 0.2, mix = 0.18},
  inst = {lead = copy(TRUMPET, {vol = 0.1}), fiddle = copy(FIDDLE, {vol = 0.1}), chop = copy(CHOP, {vol = 0.06}),
          bass = copy(PLUCK, {vol = 0.34})},
  parts = {
    A = {lead = "a4*2 d5*2 f#5*2 | a5*4 f#5*2 | g5*2 f#5*2 e5*2 | e5*6 | g4*2 c#5*2 e5*2 | g5*4 e5*2 | f#5*2 e5*2 d5*2 | d5*6 |" ..
                "a4*2 d5*2 f#5*2 | b5*4 a5*2 | g5*2 b5*2 g5*2 | e5*6 | c#5*2 e5*2 a5*2 | g5*2 f#5*2 e5*2 | d5*2 f#5*2 e5*2 | d5*6",
         lead_2 = "f#4*2 a4*2 d5*2 | f#5*4 d5*2 | e5*2 d5*2 c#5*2 | c#5*6 | e4*2 a4*2 c#5*2 | e5*4 c#5*2 | d5*2 c#5*2 a4*2 | a4*6 |" ..
                  "f#4*2 a4*2 d5*2 | g5*4 f#5*2 | e5*2 g5*2 e5*2 | c#5*6 | a4*2 c#5*2 e5*2 | e5*2 d5*2 c#5*2 | b4*2 d5*2 c#5*2 | a4*6",
         chop = bars({"D", "D", "A7", "A7", "A7", "A7", "D", "D", "D", "G", "G", "A7", "A", "A7", "A7", "D"}, vihuela),
         bass = bars({"d3", "a2", "a2", "e2", "a2", "e2", "d3", "a2", "d3", "g2", "g2", "a2", "a2", "e2", "a2", "d3"}, guitarron),
         drums = "k*2 r?*2 r?*2"},
    B = {fiddle = "b5*2 a5*2 g5*2 | d5*6 | e5*2 f#5*2 g5*2 | a5*6 | c6*2 b5*2 a5*2 | f#5*6 | g5*2 a5*2 b5*2 | g5*6 |" ..
                  "b5*2 a5*2 g5*2 | d6*6 | c6*2 b5*2 a5*2 | e5*6 | f#5*2 g5*2 a5*2 | d6*4 c#6*2 | e5*2 g5*2 c#6*2 | d6*6",
         chop = bars({"G", "G", "C", "D7", "D7", "D7", "G", "G", "G", "G", "Am", "Am", "D", "D", "A7", "D"}, vihuela),
         bass = bars({"g2", "d3", "c3", "d3", "a2", "d3", "g2", "d3", "g2", "b2", "a2", "e2", "d3", "a2", "a2", "d3"}, guitarron),
         drums = "k*2 r?*2 r?*2"},
  },
  order = {"A", "A", "B", "A"},
}

-- Dinosaur Valley: plucky exploring (A), then the dinosaurs walk, low brass and toms (B) (original)
M.tx_dino = {
  bpm = 104, gain = 1.1, echo = {time = 0.3, fb = 0.25, mix = 0.2},
  inst = {lead = copy(PLUCK, {vol = 0.3, oct = 4}), brass = copy(TRUMPET, {vol = 0.12, lp = 1400}), pad = copy(BRASS_PAD, {vol = 0.07}),
          bass = copy(BASS, {gate = 0.6, vol = 0.42})},
  parts = {
    A = {lead = "d5*2 .*2 f5*2 .*2 a5*2 .*2 d6*2 a5*2 | g5*2 .*2 bb5*2 .*2 d6*4 c6*2 bb5*2 | a5*2 .*2 f5*2 .*2 e5*2 .*2 c#5*4 |" ..
                "d5*4 e5*4 f5*4 a4*4 | d5*2 .*2 f5*2 .*2 a5*2 .*2 d6*2 a5*2 | bb5*2 .*2 a5*2 .*2 g5*2 .*2 f5*2 e5*2 |" ..
                "f5*2 e5*2 d5*2 c#5*2 e5*4 a4*4 | d5*12 .*4",
         bass = "d2*2 .*2 a2*2 .*2 d2*2 .*2 a2*2 .*2 | g2*2 .*2 d3*2 .*2 g2*2 .*2 d3*2 .*2 | a2*2 .*2 e2*2 .*2 a2*2 .*2 c#3*2 .*2 |" ..
                "d2*2 .*2 a2*2 .*2 d2*2 .*2 a2*2 .*2 | d2*2 .*2 a2*2 .*2 d2*2 .*2 a2*2 .*2 | g2*2 .*2 d3*2 .*2 g2*2 .*2 d3*2 .*2 |" ..
                "a2*2 .*2 e2*2 .*2 a2*2 .*2 c#3*2 .*2 | d2*2 .*2 a2*2 .*2 d2*4 .*4",
         drums = "k*4 h?*4 s?*4 h?*4"},
    B = {brass = "d4*8 f4*8 | f4*8 d4*8 | g4*8 bb4*8 | a4*16 | d5*8 c5*8 | bb4*8 d5*8 | bb4*8 c#5*8 | d5*16",
         pad = "Dm*16 Bb*16 Gm*16 A*16 Dm*16 Bb*16 Gm*8 A7*8 Dm*16",
         bass = "d2*16 | bb1*16 | g1*16 | a1*16 | d2*16 | bb1*16 | g1*8 a1*8 | d2*16",
         drums = "c+t!*4 .*4 t*4 .*4 | T*4 .*4 t*4 t*4"},
  },
  order = {"A", "B", "B", "A"},
}

M.tx_redriver = {
  bpm = 84, gain = 0.9, echo = {time = 0.36, fb = 0.3, mix = 0.25},
  inst = {lead = HARMONICA, arp = copy(GUITAR, {arp = "up", oct = 3}), pad = copy(PAD, {vol = 0.045}), steel = copy(STEEL, {vol = 0.07}),
          bass = copy(BASS, {vol = 0.3})},
  parts = {
    A = {lead = "g4*4 c5*4 e5*8 | f5*4 e5*4 d5*8 | c5*4 e5*4 g5*8 | f5*12 d5*4 | e5*4 g5*4 c6*8 | a5*4 g5*4 f5*8 |" ..
                "d5*4 e5*4 f5*4 b4*4 | c5*16",
         arp = "C*16 F*16 C*16 G7*16 C*16 F*16 G7*16 C*16", pad = "C*16 F*16 C*16 G*16 C*16 F*16 G*16 C*16",
         bass = "c3*8 g2*8 | f2*8 c3*8 | c3*8 g2*8 | g2*8 d3*8 | c3*8 g2*8 | f2*8 c3*8 | g2*8 b2*8 | c3*16"},
    B = {lead = "a4*4 c5*4 e5*8 | f5*4 a5*4 c6*8 | g5*8 e5*4 c5*4 | d5*12 b4*4 | a4*4 c5*4 e5*8 | a5*4 g5*4 f5*8 |" ..
                "e5*4 d5*4 b4*4 g4*4 | c5*16",
         arp = "Am*16 F*16 C*16 G*16 Am*16 F*16 G7*16 C*16", steel = "e5*16 | c5*16 | g4*16 | b4*16 | c5*16 | a4*16 | b4*16 | c5*16",
         pad = "Am*16 F*16 C*16 G*16 Am*16 F*16 G*16 C*16",
         bass = "a2*8 e2*8 | f2*8 c3*8 | c3*8 g2*8 | g2*8 d3*8 | a2*8 e2*8 | f2*8 c3*8 | g2*8 d3*8 | c3*16"},
  },
  order = {"A", "B", "A"},
}

M.tx_bats = {
  bpm = 100, gain = 1.5, echo = {time = 0.3, fb = 0.4, mix = 0.3},
  inst = {arp = copy(ARP, {arp = "updown", oct = 5, vol = 0.04}), lead = copy(BELL, {vol = 0.16, d = 0.5}),
          bass = copy(PLUCK, {vol = 0.28})},
  parts = {
    A = {arp = "Am*16 F*16 C*16 E*16", lead = "e5*4 .*4 c5*4 .*4 | a4*8 .*8 | g4*4 c5*4 e5*4 g5*4 | g#5*16",
         bass = "a2*4 .*4 a2*4 .*4 | f2*4 .*4 f2*4 .*4 | c3*4 .*4 c3*4 .*4 | e2*4 .*4 e2*4 .*4", drums = "h?*2 h?*2 h?*2 o?*2"},
    B = {arp = "Dm*16 Am*16 E*16 Am*16", lead = "f5*4 .*4 d5*4 .*4 | e5*8 c5*8 | b4*4 g#4*4 e4*4 b4*4 | a4*16",
         bass = "d3*4 .*4 d3*4 .*4 | a2*4 .*4 a2*4 .*4 | e2*4 .*4 e2*4 .*4 | a2*4 .*4 a2*4 .*4", drums = "h?*2 h?*2 h?*2 o?*2"},
    C = {arp = "F*16 G*16 Em*16 Am*16", lead = "a5*4 g5*4 f5*4 e5*4 | d5*8 e5*8 | c5*4 b4*4 c5*4 e5*4 | a4*16",
         bass = "f2*2 f2*2 c3*2 f2*2 | g2*2 g2*2 d3*2 g2*2 | e2*2 e2*2 b2*2 e2*2 | a2*2 a2*2 e3*2 a2*2", drums = "k*2 h?*2 s?*2 h?*2"},
    D = {arp = "Dm*16 E*16 Am*16 E*16", lead = "d5*4 f5*4 a5*4 f5*4 | g#5*8 e5*8 | a5*4 e5*4 c5*4 a4*4 | b4*16",
         bass = "d3*2 d3*2 a2*2 d3*2 | e2*2 e2*2 b2*2 e2*2 | a2*2 a2*2 e3*2 a2*2 | e2*2 e2*2 b2*2 g#2*2", drums = "k*2 h?*2 s?*2 o?*2"},
  },
  order = {"A", "B", "C", "D", "A", "B"},
}

M.tx_desert = {
  bpm = 60, gain = 1.7, echo = {time = 0.55, fb = 0.5, mix = 0.4},
  inst = {lead = copy(GUITAR, {d = 0.8, s = 0.3, r = 0.5, vol = 0.11, slide = 0.08, vib = {0.25, 5, 0.3}, send = 0.6}),
          pad = copy(PAD, {vol = 0.05, lp = 600, a = 1.2, r = 1.5})},
  parts = {
    A = {lead = "e4*8 g4*4 b4*4 | c5*12 b4*4 | a4*8 g4*4 f#4*4 | e4*16", pad = "Em*16 C*16 Am*16 Em*16"},
    B = {lead = "b4*8 d5*4 e5*4 | g5*12 f#5*4 | e5*8 d5*4 b4*4 | e5*16", pad = "Em*16 G*16 D*16 Em*16"},
    C = {lead = "g4*8 a4*4 b4*4 | c5*8 e5*4 d5*4 | b4*8 a4*4 g4*4 | f#4*16", pad = "C*16 Am*16 Em*16 B*16"},
  },
  order = {"A", "B", "C", "A"},
}

M.tx_lonestar = {
  bpm = 76, gain = 1, echo = {time = 0.4, fb = 0.3, mix = 0.25},
  inst = {lead = copy(TRUMPET, {vol = 0.12}), lead_2 = copy(BELL, {vol = 0.08}), pad = copy(BRASS_PAD, {vol = 0.06}),
          bass = copy(BASS, {vol = 0.34})},
  parts = {
    A = {lead = "a4*8 d5*4 f#5*4 | a5*12 g5*4 | f#5*8 e5*4 d5*4 | e5*16 | f#5*8 a5*4 d6*4 | c#6*12 b5*4 | a5*8 g5*4 e5*4 | d5*16",
         lead_2 = "a5*8 d6*4 f#6*4 | a6*12 g6*4 | f#6*8 e6*4 d6*4 | e6*16 | f#6*8 a6*4 d6*4 | c#6*12 b5*4 | a5*8 g5*4 e5*4 | d6*16",
         pad = "D*16 A7*16 Bm*16 A*16 D*16 A*16 G*8 A*8 D*16",
         bass = "d2*16 | a1*16 | b1*16 | a1*16 | d2*16 | a1*16 | g1*8 a1*8 | d2*16",
         drums = "c+k*4 s?*4 k*4 s?*4 | k*4 s?*4 k*4 s?*4"},
  },
  order = {"A", "A"},
}

-- ------------------------------------------------------------------ Longhorns (longhorns.lua): all original
local CARILLON = {wave = "sine", a = 0.002, d = 1.2, s = 0.0, r = 0.6, vol = 0.2, send = 0.5, detune = 1200}
local CALLIOPE = {wave = "pulse", duty = 0.5, a = 0.01, d = 0.1, s = 0.8, r = 0.06, vol = 0.08, vib = {0.3, 7, 0}, lp = 3000}

M.lh_gameday = {
  bpm = 92, gain = 0.9, echo = {time = 0.5, fb = 0.4, mix = 0.35},
  inst = {bell = CARILLON, pad = copy(BRASS_PAD, {vol = 0.05, a = 0.6}), bass = copy(BASS, {vol = 0.3, a = 0.05, r = 0.4}),
          lead = copy(TRUMPET, {vol = 0.08})},
  parts = {
    A = {bell = "c5*8 a4*4 f4*4 | g4*8 c5*8 | d5*8 f5*4 d5*4 | bb4*16 | a4*8 c5*4 f5*4 | e5*8 g5*8 | f5*4 d5*4 e5*4 c5*4 | f5*16",
         pad = "F*16 C*16 Dm*16 Bb*16 F*16 C*16 Bb*8 C*8 F*16", bass = "f2*16 c2*16 d2*16 bb1*16 f2*16 c2*16 bb1*8 c2*8 f2*16"},
    B = {bell = "c5*8 a4*4 f4*4 | g4*8 c5*8 | d5*8 f5*4 d5*4 | bb4*16 | a4*8 c5*4 f5*4 | e5*8 g5*8 | f5*4 d5*4 e5*4 c5*4 | f5*16",
         lead = "f4*16 | e4*16 | f4*16 | d4*16 | f4*16 | g4*16 | f4*8 g4*8 | a4*16",
         pad = "F*16 C*16 Dm*16 Bb*16 F*16 C*16 Bb*8 C*8 F*16", bass = "f2*16 c2*16 d2*16 bb1*16 f2*16 c2*16 bb1*8 c2*8 f2*16",
         drums = "k*8 s?*8"},
  },
  order = {"A", "B"},
}

M.lh_march = {
  bpm = 132, gain = 1,
  inst = {lead = copy(TRUMPET, {vol = 0.12}), pad = copy(BRASS_PAD, {vol = 0.06, a = 0.02}), pic = PICCOLO,
          bass = copy(BASS, {gate = 0.5, vol = 0.42})},
  parts = {
    A = {lead = "f4*4 bb4*4 d5*4 f5*4 | d5*8 bb4*8 | c5*4 eb5*4 a5*4 c6*4 | a5*8 f5*8 | eb5*4 f5*4 g5*4 a5*4 | c6*8 a5*8 |" ..
                "bb5*4 f5*4 d5*4 bb4*4 | bb4*8 .*8",
         pad = "Bb*16 Bb*16 F7*16 F7*16 F7*16 F7*16 Bb*16 Bb*16",
         bass = oompah("bb2", "f2") .. oompah("bb2", "f2") .. oompah("f2", "c3") .. oompah("f2", "c3") .. oompah("f2", "c3") ..
                oompah("f2", "c3") .. oompah("bb2", "f2") .. oompah("bb2", "f2"),
         drums = MARCH_DRUMS},
    B = {lead = "g5*4 bb5*4 g5*4 eb5*4 | f5*8 d5*8 | e5*4 g5*4 bb5*4 g5*4 | f5*8 c5*8 | g5*4 bb5*4 eb6*4 g5*4 | f5*8 d5*8 |" ..
                "c5*4 eb5*4 a5*4 c6*4 | bb5*16",
         pic = "bb6 c7 bb6 c7 bb6 c7 bb6 c7 bb6*8 | .*16 | g6 a6 g6 a6 g6 a6 g6 a6 g6*8 | .*16 | bb6 c7 bb6 c7 bb6 c7 bb6 c7 g6*8 | .*16 |" ..
               "a6 bb6 a6 bb6 a6 bb6 a6 bb6 f6*8 | d7*16",
         pad = "Eb*16 Bb*16 C7*16 F7*16 Eb*16 Bb*16 F7*16 Bb*16",
         bass = oompah("eb2", "bb2") .. oompah("bb2", "f2") .. oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("eb2", "bb2") ..
                oompah("bb2", "f2") .. oompah("f2", "c3") .. oompah("bb2", "f2"),
         drums = MARCH_DRUMS .. " | " .. MARCH_DRUMS:gsub("k%*2 s%?%*2", "c+k*2 s?*2", 1)},
  },
  order = {"A", "B", "A", "B"},
}

M.lh_drumline = {
  bpm = 120, gain = 1, drums_gain = 1.2,
  inst = {bass = {wave = "sine", a = 0.002, d = 0.4, s = 0.0, r = 0.1, vol = 0.5}},
  parts = {
    A = {drums = "k . s? s? s! s? s? s? k . s? s? s! s? s . | k . s? s? s! s? s? s? k k s! s? s! s! s! .",
         drums_2 = "t . . . T . T . t . . . T T T . | t . . . T . T . t t . . T . T .",
         bass = "a1*4 .*12 | a1*4 .*4 a1*4 .*4"},
    B = {drums = "s? s? s? s? s s s s s! s! s! s! s! s! c+k! . | k . k . s! . k . k k s! . c+k! . . .",
         drums_2 = "t*16 | t . t . T . t . t t T . T . . .",
         bass = "a1*16 | a1*4 a1*4 .*8"},
    C = {drums = "k k s? s? s! . s s k k s? s? s! . s s | c+k . s s s! . s s k . s! s! s! s! s! .",
         drums_2 = "t t . . T T . . t t . . T T T T | t . . . T . . . t t t t T T T T",
         bass = "a1*2 a1*2 .*12 | a1*4 .*4 a1*4 .*4"},
    -- call and answer: the snares ask, the toms answer
    D = {drums = "s! s s s! . . . . s! s s s! . . . . | s s! s s s! s s s! k . . . c+k! . . .",
         drums_2 = ". . . . t t T T . . . . t t T T | . . . . . . . . t t T T t T t T",
         bass = ".*8 a1*4 .*4 | .*8 a1*2 a1*2 a1*4"},
    -- the roll up to the big hit
    E = {drums = "s? s? s? s? s s s s s s s s s! s! s! s! | s! s! s! s! s! s! s! s! s! s! s! s! c+k! . . .",
         drums_2 = "t*16 | t . t . T . T . t t t t T T T T",
         bass = "a1*16 | a1*12 a1*4"},
  },
  order = {"A", "A", "C", "A", "B", "D", "D", "E", "A", "C", "B", "D", "E", "A", "B"},
}

M.lh_hookem = {
  bpm = 100, gain = 1, drums_gain = 1.1,
  inst = {lead = copy(TRUMPET, {vol = 0.12}), brass = copy(BRASS_PAD, {a = 0.01, d = 0.2, s = 0.4, r = 0.15, vol = 0.09}),
          bass = copy(BASS, {gate = 0.6, vol = 0.4})},
  parts = {
    A = {drums = "k*2 .*2 k*2 x*2 .*2 k*2 x*4 | k*2 .*2 k*2 x*2 k*2 k*2 x*4",
         brass = "Bb*4 .*4 Bb*2 F*6 | Eb*4 .*4 F*8",
         lead = "f5*2 .*2 f5*2 bb5*6 .*4 | eb5*2 .*2 eb5*2 f5*10",
         bass = "bb1*4 .*4 bb1*2 f1*6 | eb2*4 .*4 f2*8"},
    B = {drums = "k*2 .*2 k*2 x*2 .*2 k*2 x*4 | k*2 k*2 k*2 x*2 k*2 k*2 x!*4",
         brass = "Eb*4 .*4 Eb*2 Bb*6 | F*4 .*4 Bb*8",
         lead = "g5*2 .*2 g5*2 bb5*6 .*4 | a5*2 .*2 a5*2 bb5*10",
         bass = "eb2*4 .*4 eb2*2 bb1*6 | f2*4 .*4 bb1*8"},
    C = {drums = "k*2 .*2 k*2 x*2 .*2 k*2 x*4 | k*2 .*2 k*2 x*2 k*2 k*2 x*4",
         brass = "Gm*4 .*4 Gm*2 Eb*6 | F*4 .*4 F7*8",
         lead = "d6*2 .*2 d6*2 bb5*6 .*4 | c6*2 .*2 c6*2 a5*10",
         bass = "g1*4 .*4 g1*2 eb2*6 | f2*4 .*4 f1*8"},
    D = {drums = "k*2 x*2 k*2 x*2 k k x*2 k*2 x!*2 | x x x x x! x x x x! x x x x! x! x! x!",
         bass = "bb1*2 .*2 bb1*2 .*2 bb1 bb1 .*2 bb1*2 .*2 | f1*4 .*4 f1*4 bb1*4"},
  },
  order = {"A", "A", "B", "A", "B", "B", "C", "C", "D", "A", "B", "B"},
}

M.lh_drive = {
  bpm = 150, gain = 1,
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.1}), bass = copy(BASS, {gate = 0.7, vol = 0.38}), brass = BRASS_PAD},
  parts = {
    A = {lead = "a4*2 d5*2 f5*2 a5*2 g5*4 f5*2 e5*2 | d5*4 a4*4 f5*8 | bb4*2 d5*2 f5*2 bb5*2 a5*4 g5*2 f5*2 | e5*4 c#5*4 a4*8",
         bass = sixteens("d2", "d3") .. sixteens("d2", "d3") .. sixteens("bb1", "bb2") .. sixteens("a1", "a2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead = "d5*4 f#5*4 a5*4 d6*4 | c#6*4 a5*4 e5*8 | b5*4 g5*4 d5*4 g5*4 | a5*16",
         brass = "D*16 A*16 G*16 A*16",
         bass = eights("d2", "d3") .. eights("a1", "a2") .. eights("g1", "g2") .. eights("a1", "a2"),
         drums = "c+k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2 | k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    -- third down: the bridge, tense
    C = {lead = "f5*4 e5*4 d5*4 c5*4 | bb4*4 d5*4 f5*8 | e5*4 d5*4 c5*4 bb4*4 | a4*8 c#5*8",
         bass = sixteens("bb1", "bb2") .. sixteens("bb1", "bb2") .. sixteens("g1", "g2") .. sixteens("a1", "a2"),
         drums = "k*2 h*2 s?*2 h*2 k*2 h*2 s?*2 h*2"},
    -- into the end zone: the brass on top
    D = {lead = "d6*4 a5*4 f#5*4 a5*4 | b5*4 g5*4 e5*8 | c#6*4 a5*4 e5*4 a5*4 | d6*16",
         brass = "D*16 G*16 A*16 D*16",
         bass = eights("d2", "d3") .. eights("g1", "g2") .. eights("a1", "a2") .. eights("d2", "d3"),
         drums = "c+k*2 h*2 s*2 h*2 k*2 k*2 s*2 s*2 | k*2 h*2 s*2 h*2 k*2 k*2 s!*2 s!*2"},
  },
  order = {"A", "A", "B", "A", "B", "C", "C", "D", "A", "B", "D"},
}

M.lh_fair = {
  bpm = 132, gain = 0.95,
  inst = {lead = CALLIOPE, chord = copy(CHOP, {vol = 0.06, oct = 4}), bass = copy(PLUCK, {vol = 0.32})},
  parts = {
    A = {lead = "e5*4 g5*4 c6*4 | e6*8 c6*4 | d6*4 b5*4 g5*4 | f5*12 | d5*4 f5*4 b5*4 | d6*8 b5*4 | c6*4 g5*4 e5*4 | c5*12",
         chord = ".*4 C*4 C*4 | .*4 C*4 C*4 | .*4 G7*4 G7*4 | .*4 G7*4 G7*4 | .*4 G7*4 G7*4 | .*4 G7*4 G7*4 | .*4 C*4 C*4 | .*4 C*4 C*4",
         bass = "c3*12 | g2*12 | g2*12 | d3*12 | g2*12 | d3*12 | c3*12 | g2*12", drums = "k*4 h*4 h*4"},
    B = {lead = "a5*4 c6*4 f6*4 | e6*8 c6*4 | g5*4 c6*4 e6*4 | d6*12 | c6*4 a5*4 f#5*4 | g5*8 b5*4 | c6*4 e5*4 g5*4 | c6*12",
         chord = ".*4 F*4 F*4 | .*4 F*4 F*4 | .*4 C*4 C*4 | .*4 C*4 C*4 | .*4 D7*4 D7*4 | .*4 G7*4 G7*4 | .*4 C*4 C*4 | .*4 C*4 C*4",
         bass = "f2*12 | c3*12 | c3*12 | g2*12 | d3*12 | g2*12 | c3*12 | c3*12", drums = "k*4 h*4 h*4"},
    -- the midway strain (then again, a step up: the lift)
    C = {lead = "c6*4 a5*4 f5*4 | c6*8 a5*4 | bb5*4 g5*4 e5*4 | c5*12 | d5*4 f5*4 bb5*4 | a5*8 f5*4 | g5*4 e5*4 c5*4 | f5*12",
         chord = ".*4 F*4 F*4 | .*4 F*4 F*4 | .*4 C7*4 C7*4 | .*4 C7*4 C7*4 | .*4 Bb*4 Bb*4 | .*4 F*4 F*4 | .*4 C7*4 C7*4 | .*4 F*4 F*4",
         bass = "f2*12 | c3*12 | c3*12 | g2*12 | bb2*12 | f2*12 | c3*12 | f2*12", drums = "k*4 h*4 h*4"},
  },
  order = {"A", "B", "A", "B", "C", "C+2", "A", "B"},
}

M.lh_tower = {
  bpm = 72, gain = 0.95, echo = {time = 0.42, fb = 0.35, mix = 0.3},
  inst = {lead = copy(TRUMPET, {vol = 0.11}), bell = copy(CARILLON, {vol = 0.12}), pad = copy(PAD, {vol = 0.06}),
          bass = copy(BASS, {vol = 0.32, a = 0.05, r = 0.3})},
  parts = {
    A = {lead = "f4*8 bb4*4 d5*4 | f5*12 eb5*4 | d5*8 c5*4 bb4*4 | c5*16 | d5*8 f5*4 bb5*4 | a5*12 g5*4 | f5*8 eb5*4 c5*4 | bb4*16",
         bell = "bb5*16 | .*16 | g5*16 | .*16 | bb5*16 | .*16 | f5*16 | d6*16",
         pad = "Bb*16 Bb7*16 Gm*16 F*16 Bb*16 F*16 Cm*8 F*8 Bb*16",
         bass = "bb1*16 | bb1*16 | g1*16 | f1*16 | bb1*16 | f1*16 | c2*8 f1*8 | bb1*16", drums = "c+k*4 .*12 | k*4 .*12"},
    -- the second strain: up a step, the bells answering, building to the 1
    B = {lead = "g4*8 c5*4 eb5*4 | g5*12 f5*4 | eb5*8 d5*4 c5*4 | d5*16 | eb5*8 g5*4 c6*4 | bb5*12 a5*4 | g5*8 f5*4 d5*4 | c5*16",
         bell = ".*8 c6*8 | .*16 | .*8 g5*8 | .*16 | .*8 c6*8 | .*16 | .*8 a5*8 | eb6*16",
         pad = "Cm*16 Cm7*16 Ab*16 G*16 Cm*16 F*16 Bb*8 G*8 C*16",
         bass = "c2*16 | c2*16 | ab1*16 | g1*16 | c2*16 | f1*16 | bb1*8 g1*8 | c2*16", drums = "c+k*4 .*4 k*4 .*4 | k*4 .*4 k*4 s?*4"},
  },
  order = {"A", "B", "A"},
}

-- ------------------------------------------------------------------ Thanksgiving (thanksgiving.lua): all original
local XYLO = {wave = "tri", a = 0.001, d = 0.18, s = 0.0, r = 0.05, vol = 0.3}
local TUBA = copy(BASS, {gate = 0.45, vol = 0.45})

M.tg_harvest = {
  bpm = 84, gain = 1.6, echo = {time = 0.36, fb = 0.3, mix = 0.25},
  inst = {lead = HARMONICA, arp = copy(GUITAR, {arp = "up", oct = 3}), bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = "d5*8 b4*4 | c5*8 e5*4 | d5*4 c5*4 a4*4 | b4*12 | g4*4 b4*4 e5*4 | e5*8 c5*4 | a4*4 b4*4 c5*4 | b4*12",
         arp = "G*12 C*12 D*12 G*12 Em*12 C*12 D*12 G*12",
         bass = "g2*12 | c3*12 | d3*12 | g2*12 | e2*12 | c3*12 | d3*12 | g2*12"},
  },
  order = {"A", "A"},
}

M.tg_parade = {
  bpm = 120, gain = 1,
  inst = {lead = copy(BUGLE, {vol = 0.12}), lead_2 = copy(BUGLE, {vol = 0.05, detune = 0}), pic = PICCOLO,
          bass = copy(BASS, {gate = 0.5, vol = 0.42})},
  parts = {
    A = {lead = "c5*4 e5*4 g5*4 e5*4 | d5*4 f5*4 b5*8 | g5*4 f5*4 d5*4 b4*4 | c5*8 g4*8 | a4*4 c5*4 f5*4 a5*4 | g5*4 e5*4 c5*8 |" ..
                "d5*4 g5*4 f5*4 d5*4 | c5*16",
         lead_2 = "g4*16 | b4*16 | b4*16 | e4*16 | f4*16 | e4*16 | b4*16 | e4*16",
         bass = oompah("c3", "g2") .. oompah("g2", "d3") .. oompah("g2", "d3") .. oompah("c3", "g2") .. oompah("f2", "c3") ..
                oompah("c3", "g2") .. oompah("g2", "d3") .. oompah("c3", "g2"),
         drums = MARCH_DRUMS},
    B = {lead = "e5*4 g5*4 c6*4 g5*4 | f5*4 a5*4 d6*8 | b5*4 g5*4 d6*4 b5*4 | c6*16",
         pic = "c7 d7 c7 d7 c7 d7 c7 d7 c7*8 | a6 b6 a6 b6 a6 b6 a6 b6 a6*8 | g6 a6 g6 a6 g6 a6 g6 a6 b6*8 | c7*16",
         bass = oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("g2", "d3") .. oompah("c3", "g2"),
         drums = MARCH_DRUMS},
  },
  order = {"A", "B", "A", "B"},
}

M.tg_trot = {
  bpm = 160, gain = 1,
  inst = {lead = XYLO, bass = TUBA},
  parts = {
    A = {lead = "c5 . a4 . c5 . f5 . e5 . d5 . c5*4 | bb4 . g4 . bb4 . e5 . d5 . c5 . bb4*4 | a4 . c5 . f5 . a5 . g5 . f5 . e5 . d5 . |" ..
                "c5*2 e5*2 g5*2 c6*2 .*8",
         bass = oompah("f2", "c3") .. oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("c3", "g2"),
         drums = "k*4 s?*4 k*4 s?*4"},
  },
  order = {"A", "A", "A+2", "A"},
}

M.tg_grateful = {
  bpm = 76, gain = 1.6, echo = {time = 0.4, fb = 0.3, mix = 0.25},
  inst = {lead = HARMONICA, arp = copy(GUITAR, {arp = "up", oct = 3}), pad = copy(PAD, {vol = 0.04}), bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = "f#4*8 a4*4 d5*4 | e5*12 d5*4 | b4*8 a4*4 g4*4 | a4*16 | f#4*8 a4*4 d5*4 | g5*12 f#5*4 | e5*8 d5*4 c#5*4 | d5*16",
         arp = "D*16 A*16 G*16 A*16 D*16 G*16 A*16 D*16", pad = "D*16 A*16 G*16 A*16 D*16 G*16 A*16 D*16",
         bass = "d3*16 | a2*16 | g2*16 | a2*16 | d3*16 | g2*16 | a2*16 | d3*16"},
  },
  order = {"A", "A"},
}

M.tg_football = {
  bpm = 120, gain = 1,
  inst = {lead = copy(TRUMPET, {vol = 0.12}), brass = BRASS_PAD, bass = copy(BASS, {gate = 0.7, vol = 0.4})},
  parts = {
    A = {lead = "bb4*4 d5*4 f5*8 | eb5*4 g5*4 bb5*8 | a5*4 f5*4 c5*4 a4*4 | bb4*16", brass = "Bb*16 Eb*16 F*16 Bb*16",
         bass = eights("bb1", "bb2") .. eights("eb2", "eb3") .. eights("f1", "f2") .. eights("bb1", "bb2"),
         drums = "c+k*2 h*2 s*2 h*2 k*2 k*2 s*2 t*2 | k*2 h*2 s*2 h*2 k*2 k*2 s*2 T*2"},
    B = {lead = "f5*4 a5*4 c6*8 | bb5*4 g5*4 eb5*8 | d5*4 f5*4 bb5*4 d6*4 | c6*16", brass = "F*16 Eb*16 Bb*16 F*16",
         bass = eights("f1", "f2") .. eights("eb2", "eb3") .. eights("bb1", "bb2") .. eights("f1", "f2"),
         drums = "c+k*2 h*2 s*2 h*2 k*2 k*2 s*2 t*2 | k*2 h*2 s*2 h*2 k*2 k*2 s*2 T*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.tg_pie = {
  bpm = 128, gain = 0.95,
  inst = {lead = ACCORDION, chord = copy(CHOP, {vol = 0.06}), bass = copy(BASS, {gate = 0.6, vol = 0.38})},
  parts = {
    A = {lead = "g5*2 b5*2 g5*2 d5*2 | e5*2 c5*2 a4*4 | d5*2 f#5*2 a5*2 f#5*2 | g5*4 .*4",
         chord = ".*2 G*2 .*2 G*2 | .*2 Am*2 .*2 Am*2 | .*2 D7*2 .*2 D7*2 | .*2 G*2 .*2 G*2",
         bass = "g2*2 .*2 d3*2 .*2 | a2*2 .*2 e3*2 .*2 | d3*2 .*2 a2*2 .*2 | g2*2 .*2 d3*2 .*2",
         drums = "k*2 s?*2 k*2 s?*2"},
    B = {lead = "b5*2 a5*2 g5*2 f#5*2 | e5*2 g5*2 c6*4 | a5*2 g5*2 f#5*2 e5*2 | d5*4 .*4",
         chord = ".*2 G*2 .*2 G*2 | .*2 C*2 .*2 C*2 | .*2 D7*2 .*2 D7*2 | .*2 G*2 .*2 G*2",
         bass = "g2*2 .*2 d3*2 .*2 | c3*2 .*2 g2*2 .*2 | d3*2 .*2 a2*2 .*2 | g2*2 .*2 d3*2 .*2", drums = "k*2 s?*2 k*2 s?*2"},
  },
  order = {"A", "A", "B", "A", "A+5", "B+5", "A"},
}

-- ------------------------------------------------------------------ Christmas (christmas.lua): public-domain
-- carols (Jingle Bells, Deck the Halls, We Wish You a Merry Christmas, Silent Night, the Carol of the Bells'
-- ostinato) and one of ours (the Gingerbread Rag)
local SLEIGH = "h h h h h h h h"
local CHOIR = {wave = "sine", a = 0.3, d = 0.4, s = 0.8, r = 0.6, vol = 0.07, oct = 4, vib = {0.12, 5, 0.3}, detune = 6}

local JINGLE = "e5*4 e5*4 e5*8 | e5*4 e5*4 e5*8 | e5*4 g5*4 c5*6 d5*2 | e5*16 | f5*4 f5*4 f5*6 f5*2 | f5*4 e5*4 e5*4 e5*2 e5*2 |" ..
               "e5*4 d5*4 d5*4 e5*4 | d5*8 g5*8 | e5*4 e5*4 e5*8 | e5*4 e5*4 e5*8 | e5*4 g5*4 c5*6 d5*2 | e5*16 |" ..
               "f5*4 f5*4 f5*6 f5*2 | f5*4 e5*4 e5*4 e5*2 e5*2 | g5*4 g5*4 f5*4 d5*4 | c5*16"
local JINGLE_CHORDS = "C*16 C*16 C*16 C*16 F*16 C*16 D7*16 G7*16 C*16 C*16 C*16 C*16 F*16 C*16 G7*16 C*16"
local JINGLE_BASS = oompah("c3", "g2") .. oompah("c3", "g2") .. oompah("c3", "g2") .. oompah("c3", "g2") .. oompah("f2", "c3") ..
                    oompah("c3", "g2") .. oompah("d3", "a2") .. oompah("g2", "d3") .. oompah("c3", "g2") .. oompah("c3", "g2") ..
                    oompah("c3", "g2") .. oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("c3", "g2") .. oompah("g2", "d3") ..
                    oompah("c3", "g2")

M.xm_bells = {
  bpm = 140, gain = 1, echo = {time = 0.43, fb = 0.4, mix = 0.3},
  inst = {bell = copy(BELL, {vol = 0.18, d = 0.5}), bell_2 = copy(BELL, {vol = 0.1, d = 0.4}),
          lead = copy(TRUMPET, {vol = 0.08, wave = "sine", detune = 0}), pad = copy(PAD, {vol = 0.05}),
          bass = copy(BASS, {vol = 0.32, a = 0.03, r = 0.3})},
  parts = {
    A = {bell = "bb4*4 a4*2 bb4*2 g4*4"},
    B = {bell = "bb4*4 a4*2 bb4*2 g4*4", bell_2 = "bb5*4 a5*2 bb5*2 g5*4", bass = "g2*12"},
    C = {bell = "bb4*4 a4*2 bb4*2 g4*4", lead = "d6*12 | c6*12 | bb5*12 | a5*12 | g5*12 | f5*12 | eb5*12 | d5*12",
         pad = "Gm*12 F*12 Eb*12 D*12 Cm*12 Bb*12 Cm*12 D*12",
         bass = "g2*12 | f2*12 | eb2*12 | d2*12 | c2*12 | bb1*12 | c2*12 | d2*12"},
  },
  -- (A and B are one bar; repeated)
  order = {"A", "A", "A", "A", "B", "B", "B", "B", "B", "B", "B", "B", "C", "C", "B", "B", "B", "B"},
}

M.xm_jingle = {
  bpm = 132, gain = 1,
  inst = {lead = copy(BELL, {vol = 0.2, d = 0.35, s = 0.2}), lead_2 = copy(LEAD, {vol = 0.06, duty = 0.5}),
          pad = copy(CHOP, {vol = 0.05, d = 0.2}), bass = copy(BASS, {gate = 0.55, vol = 0.4})},
  parts = {
    A = {lead = JINGLE, lead_2 = JINGLE, pad = JINGLE_CHORDS, bass = JINGLE_BASS, drums = SLEIGH .. " " .. SLEIGH},
  },
  order = {"A", "A"},
}

M.xm_deck = {
  bpm = 116, steps = 2, swing = 0.3, gain = 1, echo = {time = 0.26, fb = 0.2, mix = 0.15},
  inst = {lead = FIDDLE, steel = STEEL, chop = copy(CHOP, {oct = 4}), bass = copy(BASS, {gate = 0.8, vol = 0.36})},
  parts = {
    A = {lead = "g5*3 f5 e5*2 d5*2 | c5*2 d5*2 e5*2 c5*2 | d5 e5 f5 d5 e5*3 d5 | c5*2 b4*2 c5*4",
         steel = "e5*8 | g4*8 | b4*4 g4*4 | e4*8",
         chop = ".*1 C .*1 C .*1 C .*1 C | .*1 C .*1 C .*1 C .*1 C | .*1 G7 .*1 G7 .*1 C .*1 C | .*1 C .*1 G7 .*1 C .*1 C",
         bass = "c3*2 g2*2 c3*2 g2*2 | c3*2 e3*2 g3*2 e3*2 | g2*2 b2*2 c3*2 g2*2 | c3*2 g2*2 c3*4", drums = "k*2 s?*2"},
    B = {lead = "d5*3 e5 f5*2 d5*2 | e5*3 f5 g5*2 d5*2 | e5 f#5 g5*2 a5 b5 c6*2 | b5*2 a5*2 g5*4",
         steel = "b4*8 | c5*4 b4*4 | a4*8 | g4*8",
         chop = ".*1 G .*1 G .*1 G .*1 G | .*1 C .*1 C .*1 G .*1 G | .*1 D .*1 D .*1 D7 .*1 D7 | .*1 G .*1 G .*1 G .*1 G",
         bass = "g2*2 d3*2 g2*2 d3*2 | c3*2 g2*2 g2*2 d3*2 | d3*2 a2*2 d3*2 c3*2 | g2*2 d3*2 g2*4", drums = "k*2 s?*2"},
  },
  order = {"A", "A", "B", "A", "A", "A", "B", "A"},
}

M.xm_wish = {
  bpm = 120, gain = 1, echo = {time = 0.3, fb = 0.3, mix = 0.25},
  inst = {lead = copy(BELL, {vol = 0.2, d = 0.4, s = 0.25}), pad = CHOIR, bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = ".*8 g4*4 | c5*4 c5*2 d5*2 c5*2 b4*2 | a4*4 a4*4 a4*4 | d5*4 d5*2 e5*2 d5*2 c5*2 | b4*4 g4*4 g4*4 |" ..
                "e5*4 e5*2 f5*2 e5*2 d5*2 | c5*4 a4*4 g4*2 g4*2 | a4*4 d5*4 b4*4 | c5*12",
         pad = "G*12 C*12 F*12 D7*12 G*12 E7*12 Am*12 G7*12 C*12",
         bass = "g2*12 | c3*12 | f2*12 | d3*12 | g2*12 | e2*12 | a2*12 | g2*12 | c3*12"},
  },
  order = {"A", "A"},
}

M.xm_rag = {
  bpm = 116, gain = 1,
  inst = {lead = copy(GUITAR, {vol = 0.1, d = 0.3, s = 0.3}), chord = copy(CHOP, {vol = 0.06, oct = 4}),
          bass = copy(BASS, {gate = 0.5, vol = 0.4})},
  parts = {
    A = {lead = "c5*2 e5*2 g5*2 a5*2 g5*4 e5*4 | f5*2 a5*2 c6*2 a5*2 g5*8 | e5*2 g5*2 c6*2 b5*2 a5*2 g5*2 f5*2 e5*2 | d5*4 g5*4 c5*8",
         chord = ".*4 C*4 .*4 C*4 | .*4 F*4 .*4 F*4 | .*4 C*4 .*4 C*4 | .*4 G7*4 .*4 C*4",
         bass = "c2*4 .*4 g2*4 .*4 | f2*4 .*4 c3*4 .*4 | c2*4 .*4 g2*4 .*4 | g2*4 .*4 c2*4 .*4", drums = "k*4 s?*4"},
  },
  order = {"A", "A", "A+5", "A"},
}

M.xm_silent = {
  bpm = 72, gain = 1.6, echo = {time = 0.5, fb = 0.45, mix = 0.35},
  inst = {box = copy(BELL, {vol = 0.2, d = 0.9}), pad = copy(CHOIR, {vol = 0.05}), bass = copy(PLUCK, {vol = 0.22, d = 0.6})},
  parts = {
    A = {box = "g4*6 a4*2 g4*4 | e4*12 | g4*6 a4*2 g4*4 | e4*12 | d5*8 d5*4 | b4*12 | c5*8 c5*4 | g4*12 | a4*8 a4*4 |" ..
               "c5*6 b4*2 a4*4 | g4*6 a4*2 g4*4 | e4*12 | a4*8 a4*4 | c5*6 b4*2 a4*4 | g4*6 a4*2 g4*4 | e4*12 | d5*8 d5*4 |" ..
               "f5*6 d5*2 b4*4 | c5*12 | e5*12 | c5*6 g4*2 e4*4 | g4*6 f4*2 d4*4 | c4*12 | .*12",
         pad = "C*12 C*12 C*12 C*12 G7*12 G7*12 C*12 C*12 F*12 F*12 C*12 C*12 F*12 F*12 C*12 C*12 G7*12 G7*12 C*12 C*12 C*12 G7*12 C*12 C*12",
         bass = "c3*12 | c3*12 | c3*12 | c3*12 | g2*12 | g2*12 | c3*12 | c3*12 | f2*12 | f2*12 | c3*12 | c3*12 | f2*12 | f2*12 |" ..
                "c3*12 | c3*12 | g2*12 | g2*12 | c3*12 | c3*12 | c3*12 | g2*12 | c3*12 | c3*12"},
  },
  order = {"A"},
}

M.xm_finale = {
  bpm = 152, gain = 1,
  inst = M.xm_jingle.inst,
  parts = {A = M.xm_jingle.parts.A},
  order = {"A+2", "A+2"},
}

-- ------------------------------------------------------------------ Halloween (halloween.lua): Bach's Toccata in
-- D minor (its opening) and Grieg's In the Hall of the Mountain King (public domain), and ours
local ORGAN = {wave = "saw", a = 0.01, d = 0.2, s = 0.9, r = 0.5, vol = 0.1, detune = 8, lp = 2600, send = 0.5, oct = 3}
local THEREMIN = {wave = "sine", a = 0.15, d = 0.3, s = 0.9, r = 0.5, vol = 0.18, slide = 0.3, vib = {0.35, 6, 0.1}, send = 0.5}

M.hw_toccata = {
  bpm = 54, gain = 2.0, echo = {time = 0.55, fb = 0.5, mix = 0.4},
  inst = {organ = ORGAN, pad = copy(ORGAN, {vol = 0.07}), bass = copy(ORGAN, {vol = 0.12, lp = 600})},
  parts = {
    A = {organ = "a5 g5 a5*10 .*4 | g5*2 f5*2 e5*2 d5*2 c#5*6 d5*2 | d5*12 .*4 | a4 g4 a4*10 .*4 | e4*3 f4*3 c#4*4 d4*6 |" ..
                 "d4*12 .*4 | a3 g3 a3*10 .*4 | g3*2 f3*2 e3*2 d3*2 c#3*6 d3*2 | d3*12 .*4"},
    B = {pad = "C#dim7*16 | Dm*16 | Gm*8 A7*8 | Dm*16", bass = "a1*16 | d2*16 | g1*8 a1*8 | d2*16", drums = "k?*16 | .*16 | .*16 | k*16"},
  },
  order = {"A", "B"},
}

M.hw_pumpkin = {
  bpm = 132, gain = 1,
  inst = {lead = XYLO, bass = TUBA},
  parts = {
    A = {lead = "e5 . g5 . b5 . e5 . d#5*4 b4*4 | e5 . g5 . c6 . b5 . a5*4 f#5*4 | g5 . e5 . c5 . e5 . b4*4 d#5*4 | e5*8 .*8",
         bass = "e2*4 b2*4 b1*4 b2*4 | c3*4 g2*4 b1*4 d#2*4 | c3*4 e2*4 b1*4 f#2*4 | e2*4 b2*4 e2*8", drums = "k*4 s?*4"},
  },
  order = {"A", "A", "A+5", "A"},
}

local MOUNTAIN = "b3*2 c#4*2 d4*2 e4*2 f#4*2 d4*2 f#4*4 | f4*2 c#4*2 f4*4 e4*2 c4*2 e4*4 |" ..
                 "b3*2 c#4*2 d4*2 e4*2 f#4*2 d4*2 f#4*2 b4*2 | a4*2 f#4*2 d4*2 f#4*2 a4*8"
local function mountain(bpm, n, after, drums, loud)
  return {
    bpm = bpm, gain = 1, loop = after == nil, after = after,
    inst = {lead = loud and copy(LEAD, {vol = 0.11, duty = 0.5}) or copy(PLUCK, {vol = 0.3}),
            lead_2 = copy(PLUCK, {vol = loud and 0.22 or 0}), bass = copy(BASS, {gate = 0.4, vol = 0.4})},
    parts = {A = {lead = MOUNTAIN, lead_2 = octave_up(MOUNTAIN), bass = string.rep("b1*4 f#2*4 b1*4 f#2*4 ", 4), drums = drums}},
    order = n == 1 and {"A", "A+7"} or {"A", "A+7", "A", "A+7"},
  }
end
M.hw_mountain1 = mountain(92, 1, "hw_mountain2", ".*16")
M.hw_mountain2 = mountain(112, 1, "hw_mountain3", "k*4 .*12")
M.hw_mountain3 = mountain(136, 1, "hw_mountain4", "k*4 s?*4 k*4 s?*4", true)
M.hw_mountain4 = mountain(168, 2, nil, "k*2 s*2 k*2 s*2 k*2 s*2 k*2 s!*2 | c+k*2 s*2 k*2 s*2 k*2 s*2 s s s! s!", true)

M.hw_skeleton = {
  bpm = 150, steps = 2, swing = 0.33, gain = 1,
  inst = {lead = XYLO, bass = copy(BASS, {gate = 0.8, vol = 0.38})},
  parts = {
    A = {lead = "a4 c5 e5 a5 g5*2 e5*2 | f5 a5 c6 a5 g5*4 | e5 g#5 b5 e6 d6*2 b5*2 | a5*8",
         bass = "a2*2 c3*2 e3*2 g3*2 | f2*2 a2*2 c3*2 e3*2 | e2*2 g#2*2 b2*2 d3*2 | a2*2 e2*2 a2*4", drums = "k h s h"},
  },
  order = {"A", "A", "A+5", "A", "A", "A+5"},
}

M.hw_witch = {
  bpm = 96, gain = 1, echo = {time = 0.47, fb = 0.4, mix = 0.35},
  inst = {lead = THEREMIN, chord = copy(CHOP, {vol = 0.05, oct = 4}), bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = "d5*8 f5*4 | a5*12 | g5*4 f5*4 e5*4 | f5*12 | e5*8 g5*4 | bb5*12 | a5*4 g5*4 f5*4 | e5*12",
         chord = ".*4 Dm*4 Dm*4 | .*4 Dm*4 Dm*4 | .*4 C*4 C*4 | .*4 F*4 F*4 | .*4 C*4 C*4 | .*4 Gm*4 Gm*4 | .*4 Dm*4 Dm*4 | .*4 A*4 A*4",
         bass = "d2*12 | a1*12 | c2*12 | f2*12 | c2*12 | g1*12 | d2*12 | a1*12"},
  },
  order = {"A", "A"},
}

M.hw_dark = {
  bpm = 60, gain = 1.5,
  inst = {pad = copy(PAD, {vol = 0.06, lp = 500, trem = {0.5, 3}}), ping = copy(BELL, {vol = 0.08})},
  parts = {
    A = {pad = "Dm*32 | C#dim7*32", drums = "k*2 .*2 k?*2 .*10", ping = ".*24 g#6*4 .*36 | .*8 f6*4 .*20 d6*4 .*28"},
  },
  order = {"A"},
}

M.hw_finale = {
  bpm = 128, gain = 1,
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.11}), lead_2 = copy(XYLO, {vol = 0.16}), bass = copy(BASS, {gate = 0.6, vol = 0.38})},
  parts = {
    A = {lead = "e5*4 g5*4 b5*4 e6*4 | d6*4 b5*4 g5*8 | c6*4 a5*4 f#5*4 d#5*4 | e5*16",
         bass = eights("e2", "e3") .. eights("g2", "g3") .. eights("b1", "b2") .. eights("e2", "e3"), drums = "k*2 h*2 s*2 h*2"},
    B = {lead = "g5*4 b5*4 d6*4 g6*4 | f#6*4 d6*4 a5*8 | b5*4 g5*4 e5*4 c6*4 | b5*16",
         lead_2 = "g6 . b6 . d7 . b6 . g6*8 | f#6 . a6 . d7 . a6 . f#6*8 | e6 . g6 . b6 . g6 . e6*8 | b6*16",
         bass = eights("g2", "g3") .. eights("d2", "d3") .. eights("c3", "c4") .. eights("e2", "e3"), drums = "c+k*2 h*2 s*2 h*2 k*2 h*2 s*2 h*2"},
  },
  order = {"A", "B", "A", "B"},
}

-- ------------------------------------------------------------------ New Year's Eve (newyear.lua): Auld Lang Syne
-- (public domain) and ours
M.ny_disco = {
  bpm = 120, gain = 1, echo = {time = 0.375, fb = 0.3, mix = 0.2}, drums_send = 0.2,
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.1, send = 0.3}), bass = {wave = "saw", a = 0.003, d = 0.12, s = 0.5, r = 0.05, vol = 0.14, lp = 700},
          stab = copy(BRASS_PAD, {a = 0.005, d = 0.15, s = 0.3, r = 0.1, vol = 0.08})},
  parts = {
    A = {lead = "e5*2 .*2 e5*2 g5*2 a5*4 g5*2 e5*2 | d5*2 .*2 d5*2 e5*2 g5*4 e5*4 | c5*2 .*2 c5*2 d5*2 e5*4 d5*2 c5*2 | b4*2 c5*2 d5*2 e5*2 g#5*8",
         bass = string.rep("a2*2 a3*2 ", 4) .. string.rep("g2*2 g3*2 ", 4) .. string.rep("f2*2 f3*2 ", 4) .. string.rep("e2*2 e3*2 ", 4),
         stab = ".*2 Am*2 .*4 .*2 Am*2 .*4 | .*2 G*2 .*4 .*2 G*2 .*4 | .*2 F*2 .*4 .*2 F*2 .*4 | .*2 E*2 .*4 .*2 E*2 .*4",
         drums = "k*2 o*2 k+x*2 o*2"},
  },
  order = {"A", "A", "A", "A"},
}

M.ny_rag = {
  bpm = 120, gain = 1,
  inst = {lead = copy(GUITAR, {vol = 0.1, d = 0.3, s = 0.3}), chord = copy(CHOP, {vol = 0.06, oct = 4}),
          bass = copy(BASS, {gate = 0.5, vol = 0.4})},
  parts = {
    A = {lead = "e5*2 c5*2 g4*2 c5*2 e5*4 g5*4 | f5*2 d5*2 a4*2 d5*2 f5*8 | e5*2 g5*2 c6*2 g5*2 a5*2 f5*2 d5*2 b4*2 | c5*4 g4*4 c5*8",
         chord = ".*4 C*4 .*4 C*4 | .*4 Dm*4 .*4 Dm*4 | .*4 C*4 .*4 G7*4 | .*4 G7*4 .*4 C*4",
         bass = "c2*4 .*4 g2*4 .*4 | d2*4 .*4 a2*4 .*4 | c2*4 .*4 g2*4 .*4 | g2*4 .*4 c2*4 .*4", drums = "k*4 s?*4"},
  },
  order = {"A", "A", "A+5", "A"},
}

M.ny_countdown = {
  bpm = 100, gain = 1,
  inst = {arp = copy(ARP, {arp = "up", oct = 4, vol = 0.05}), bass = copy(BASS, {vol = 0.4, gate = 0.5}),
          pad = copy(BRASS_PAD, {vol = 0.05, a = 1})},
  parts = {
    A = {arp = "Am*16 | F*16 | C*16 | E*16", pad = "Am*16 F*16 C*16 E*16", bass = string.rep("a1*2 ", 8) .. string.rep("f1*2 ", 8) .. string.rep("c2*2 ", 8) .. string.rep("e1*2 ", 8),
         drums = "k*4 s?*4 k*4 s?*4 | k*4 s?*4 k*4 s?*2 s?*2 | k*4 s*4 k*4 s*2 s*2 | s? s? s s s s s! s! s! s! s! s! s! s! s! s!"},
  },
  order = {"A"},
}

M.ny_midnight = {
  bpm = 132, gain = 1,
  inst = {lead = copy(TRUMPET, {vol = 0.12}), lead_2 = copy(BELL, {vol = 0.1}), brass = BRASS_PAD, bass = copy(BASS, {gate = 0.6, vol = 0.4})},
  parts = {
    A = {lead = "c5*4 e5*4 g5*4 c6*4 | b5*4 g5*4 d6*8 | c6*4 a5*4 f5*4 a5*4 | g5*16", brass = "C*16 G*16 F*16 G*16",
         bass = eights("c2", "c3") .. eights("g1", "g2") .. eights("f1", "f2") .. eights("g1", "g2"),
         drums = "c+k*2 s*2 k*2 s*2 k*2 s*2 k*2 s*2 | k*2 s*2 k*2 s*2 k*2 s*2 s s s! s!"},
    B = {lead = "e6*4 d6*4 c6*4 g5*4 | a5*4 b5*4 c6*8 | f5*4 a5*4 c6*4 e6*4 | d6*4 b5*4 c6*8", lead_2 = "c7*16 | e7*16 | f7*16 | g7*8 c7*8",
         brass = "C*16 Am*16 F*16 G*8 C*8",
         bass = eights("c2", "c3") .. eights("a1", "a2") .. eights("f1", "f2") .. "g1*2 g2*2 g1*2 g2*2 c2*2 c3*2 c2*4 ",
         drums = "c+k*2 s*2 k*2 s*2 k*2 s*2 k*2 s*2"},
  },
  order = {"A", "B", "A", "B"},
}

M.ny_auld = {
  bpm = 72, gain = 1.2, echo = {time = 0.42, fb = 0.4, mix = 0.3},
  inst = {lead = copy(BELL, {vol = 0.2, d = 0.9, s = 0.2}), pad = CHOIR, bass = copy(PLUCK, {vol = 0.26, d = 0.6})},
  parts = {
    A = {lead = ".*12 c4*4 | f4*6 f4*2 f4*4 a4*4 | g4*6 f4*2 g4*4 a4*4 | f4*6 f4*2 a4*4 c5*4 | d5*12 d5*4 |" ..
                "c5*6 a4*2 a4*4 f4*4 | g4*6 f4*2 g4*4 a4*4 | f4*6 d4*2 d4*4 c4*4 | f4*12 .*4",
         pad = "C*16 F*16 C7*16 F*16 Bb*16 F*16 C7*16 Bb*8 C7*8 F*16",
         bass = "c3*16 | f2*16 | c3*16 | f2*16 | bb2*16 | f2*16 | c3*16 | bb2*8 c3*8 | f2*16"},
  },
  order = {"A", "A+2"},
}

-- ------------------------------------------------------------------ Mission Control (space.lua): Richard Strauss's
-- Also sprach Zarathustra (its sunrise, 1896) and Johann Strauss II's The Blue Danube (1866), public domain; ours
local TIMP = "t*2 T*2 t*2 T*2 t*2 T*2 t*2 T*2"
M.mc_hum = {
  bpm = 96, gain = 1, echo = {time = 0.47, fb = 0.4, mix = 0.3},
  inst = {arp = copy(ARP, {arp = "up", oct = 4, vol = 0.045}), pad = copy(PAD, {vol = 0.05}), bass = copy(BASS, {vol = 0.3, gate = 0.5}),
          lead = copy(BELL, {vol = 0.12})},
  parts = {
    A = {arp = "Am*16 F*16 C*16 G*16", pad = "Am*16 F*16 C*16 G*16", bass = string.rep("a1*4 ", 4) .. string.rep("f1*4 ", 4) .. string.rep("c2*4 ", 4) .. string.rep("g1*4 ", 4),
         drums = "k?*4 .*4 k?*4 .*4"},
    B = {arp = "Am*16 F*16 C*16 E*16", pad = "Am*16 F*16 C*16 E*16", lead = "e5*8 c5*8 | a4*16 | g4*8 c5*8 | b4*16",
         bass = string.rep("a1*4 ", 4) .. string.rep("f1*4 ", 4) .. string.rep("c2*4 ", 4) .. string.rep("e1*4 ", 4), drums = "k?*4 h?*4 k?*4 h?*4"},
  },
  order = {"A", "B", "A", "B"},
}

M.mc_sunrise = {
  bpm = 60, gain = 1, loop = false, after = "mc_tranquil", echo = {time = 0.6, fb = 0.45, mix = 0.35}, drums_gain = 1.4,
  inst = {lead = copy(TRUMPET, {vol = 0.14, vib = {0.05, 5, 0.5}}), pad = copy(BRASS_PAD, {vol = 0.1, a = 0.05, r = 1.5}),
          bass = copy(ORGAN, {vol = 0.12, lp = 500, oct = 2})},
  parts = {
    A = {lead = ".*16 | c4*16 | g4*16 | c5*16 | e5*4 eb5*12 | .*16 | c4*16 | g4*16 | c5*16 | eb5*4 e5*12 | .*16 |" ..
                "c4*16 | g4*16 | c5*16 | a5*8 b5*8 | c6*32",
         pad = ".*64 | C*4 Cm*12 | .*64 | Cm*4 C*12 | .*64 | F*8 G*8 | C*32",
         bass = "c2*272",
         drums = ".*80 | " .. TIMP .. " | .*64 | " .. TIMP .. " | .*64 | c+k!*16 | " .. TIMP},
  },
  order = {"A"},
}

M.mc_danube = {
  bpm = 150, gain = 1.4, echo = {time = 0.4, fb = 0.3, mix = 0.25},
  inst = {lead = copy(BELL, {vol = 0.2, d = 0.7, s = 0.3}), pad = copy(PAD, {vol = 0.05, a = 0.2}), chord = copy(CHOP, {vol = 0.05, oct = 4}),
          bass = copy(PLUCK, {vol = 0.3})},
  parts = {
    A = {lead = "d4*4 d4*4 f#4*4 | a4*12 | .*4 a5*4 a5*4 | .*4 f#5*4 f#5*4 | d4*4 d4*4 f#4*4 | a4*12 | .*4 b5*4 b5*4 | .*4 g5*4 g5*4 |" ..
                "c#4*4 c#4*4 e4*4 | b4*12 | .*4 b5*4 b5*4 | .*4 g5*4 g5*4 | c#4*4 c#4*4 e4*4 | b4*12 | .*4 a5*4 a5*4 | .*4 f#5*4 f#5*4",
         pad = "D*72 G*24 A7*72 D*24",
         chord = string.rep(".*4 D*4 D*4 ", 6) .. string.rep(".*4 G*4 G*4 ", 2) .. string.rep(".*4 A7*4 A7*4 ", 6) .. string.rep(".*4 D*4 D*4 ", 2),
         bass = string.rep("d2*12 ", 6) .. string.rep("g2*12 ", 2) .. string.rep("a2*12 ", 6) .. string.rep("d2*12 ", 2)},
    -- the trio: the station turning, the tune up high
    B = {lead = "a5*8 f#5*4 | d5*12 | b5*8 g5*4 | e5*12 | c#6*8 a5*4 | e5*12 | d6*8 b5*4 | a5*12 | a5*4 b5*4 c#6*4 | d6*12 |" ..
                "b5*4 a5*4 g5*4 | f#5*12 | e5*4 f#5*4 g5*4 | a5*8 c#5*4 | d5*12 | .*12",
         pad = "D*24 G*24 A*24 D*24 D*24 G*24 A*24 D*24",
         chord = string.rep(".*4 D*4 D*4 ", 2) .. string.rep(".*4 G*4 G*4 ", 2) .. string.rep(".*4 A*4 A*4 ", 2) .. string.rep(".*4 D*4 D*4 ", 4) ..
                 string.rep(".*4 G*4 G*4 ", 2) .. string.rep(".*4 A*4 A*4 ", 2) .. string.rep(".*4 D*4 D*4 ", 2),
         bass = "d2*12 d2*12 g2*12 g2*12 a2*12 a2*12 d2*12 d2*12 d2*12 d2*12 g2*12 g2*12 a2*12 a2*12 d2*12 d2*12"},
  },
  order = {"A", "A", "B", "A", "B"},
}

M.mc_tranquil = {
  bpm = 60, gain = 2.0, echo = {time = 0.6, fb = 0.5, mix = 0.45},
  inst = {pad = copy(PAD, {vol = 0.05, a = 1.5, r = 2}), lead = copy(BELL, {vol = 0.15, d = 1.2})},
  parts = {
    A = {pad = "Em*16 Cmaj7*16 G*16 D*16", lead = "e5*8 .*8 | b4*8 d5*8 | e5*16 | .*16"},
    B = {pad = "Am7*16 Em*16 C*16 D*16", lead = ".*8 a4*8 | b4*16 | g4*8 e5*8 | d5*16"},
    C = {pad = "Cmaj7*16 G*16 Am7*16 Bm*16", lead = "g5*8 e5*8 | d5*16 | c5*8 e5*8 | f#5*16"},
    D = {pad = "Em*16 C*16 D*16 Em*16", lead = "b4*8 .*8 | e5*8 g5*8 | f#5*8 d5*8 | e5*16"},
  },
  order = {"A", "B", "C", "D", "A", "B"},
}

M.mc_home = {
  bpm = 110, gain = 1,
  inst = {lead = copy(TRUMPET, {vol = 0.12}), brass = BRASS_PAD, bass = copy(BASS, {gate = 0.6, vol = 0.4})},
  parts = {
    A = {lead = "d5*4 a4*4 d5*4 f#5*4 | e5*8 a5*8 | g5*4 f#5*4 e5*4 d5*4 | e5*16 | d5*4 a4*4 d5*4 f#5*4 | b5*8 a5*8 |" ..
                "g5*4 e5*4 c#5*4 e5*4 | d5*16",
         brass = "D*16 A*16 G*16 A*16 D*16 G*16 A*16 D*16",
         bass = eights("d2", "d3") .. eights("a1", "a2") .. eights("g1", "g2") .. eights("a1", "a2") .. eights("d2", "d3") ..
                eights("g1", "g2") .. eights("a1", "a2") .. eights("d2", "d3"),
         drums = "k*4 s*4 k*4 s*4 | k*4 s*4 k*2 k*2 s*4"},
    B = {lead = "f#5*4 g5*4 a5*8 | b5*4 a5*4 g5*8 | e5*4 f#5*4 g5*8 | a5*16 | f#5*4 g5*4 a5*8 | d6*4 c#6*4 b5*8 |" ..
                "a5*4 g5*4 e5*4 c#5*4 | d5*16",
         brass = "D*16 G*16 Em*16 A*16 D*16 G*16 A7*16 D*16",
         bass = eights("d2", "d3") .. eights("g1", "g2") .. eights("e2", "e3") .. eights("a1", "a2") .. eights("d2", "d3") ..
                eights("g1", "g2") .. eights("a1", "a2") .. eights("d2", "d3"),
         drums = "k*4 s*4 k*4 s*4 | k*4 s*4 k*2 k*2 s*4"},
  },
  order = {"A", "A", "B", "A", "B", "A+2"},
}

-- ------------------------------------------------------------------ Summer (summer.lua): all ours
local FLUTE = {wave = "sine", a = 0.04, d = 0.2, s = 0.8, r = 0.2, vol = 0.16, vib = {0.12, 5, 0.25}, send = 0.4}
M.su_lake = {
  bpm = 116, gain = 1, echo = {time = 0.39, fb = 0.25, mix = 0.18},
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.1, send = 0.3}), chord = copy(CHOP, {vol = 0.05}), bass = copy(BASS, {gate = 0.6})},
  parts = {
    A = {lead = "a5*2 c6*2 a5*2 f5*2 g5*4 a5*4 | f5*2 d5*2 f5*2 a5*2 c6*8 | bb5*2 a5*2 g5*2 f5*2 d5*4 f5*4 | g5*2 a5*2 g5*2 e5*2 c5*8",
         chord = string.rep(".*2 F*2 ", 4) .. string.rep(".*2 Dm*2 ", 4) .. string.rep(".*2 Bb*2 ", 4) .. string.rep(".*2 C*2 ", 4),
         bass = eights("f2", "c3") .. eights("d2", "a2") .. eights("bb1", "f2") .. eights("c2", "g2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead = "c6*4 bb5*4 a5*4 f5*4 | d6*4 c6*4 a5*8 | bb5*4 d6*4 c6*4 a5*4 | g5*12 .*4",
         chord = string.rep(".*2 Bb*2 ", 4) .. string.rep(".*2 F*2 ", 4) .. string.rep(".*2 Gm*2 ", 4) .. string.rep(".*2 C*2 ", 4),
         bass = eights("bb1", "f2") .. eights("f2", "c3") .. eights("g2", "d3") .. eights("c2", "g2"),
         drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 o*2"},
    -- the speedboat: the tune skipping along, then the big one
    C = {lead = "f5*2 g5*2 a5*2 c6*2 d6*4 c6*4 | a5*2 g5*2 f5*2 d5*2 f5*8 | e5*2 f5*2 g5*2 bb5*2 a5*4 g5*4 | f5*2 e5*2 d5*2 e5*2 c5*8",
         chord = string.rep(".*2 F*2 ", 4) .. string.rep(".*2 Dm*2 ", 4) .. string.rep(".*2 C*2 ", 4) .. string.rep(".*2 Bb*2 ", 2) .. string.rep(".*2 C*2 ", 2),
         bass = eights("f2", "c3") .. eights("d2", "a2") .. eights("c2", "g2") .. eights("bb1", "c2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 s*2"},
  },
  order = {"A", "A", "B", "A", "C", "C", "B", "A+2"},
}

M.su_bossa = {
  bpm = 128, gain = 1, echo = {time = 0.47, fb = 0.3, mix = 0.22},
  inst = {lead = FLUTE, keys = {wave = "sine", a = 0.004, d = 0.5, s = 0.3, r = 0.2, vol = 0.09, oct = 4, trem = {0.15, 4}},
          bass = copy(BASS, {vol = 0.36, gate = 0.8})},
  parts = {
    A = {lead = "a5*6 g5*2 f5*4 e5*4 | d5*6 e5*2 f5*4 b5*4 | c6*6 b5*2 a5*4 g5*4 | e5*12 .*4",
         keys = "Dm7*3 Dm7*3 Dm7*2 .*2 Dm7*3 Dm7*3 | G7*3 G7*3 G7*2 .*2 G7*3 G7*3 | Cmaj7*3 Cmaj7*3 Cmaj7*2 .*2 Cmaj7*3 Cmaj7*3 | A7*3 A7*3 A7*2 .*2 A7*3 A7*3",
         bass = "d2*6 a2*2 a2*6 d2*2 | g2*6 d2*2 d2*6 g2*2 | c2*6 g2*2 g2*6 c2*2 | a1*6 e2*2 e2*6 a1*2",
         drums = "k+h h r h k+h h r h k+h h h r k+h r h h"},
    B = {lead = "c6*4 a5*4 f5*8 | b5*4 g#5*4 e5*8 | a5*4 c6*4 e6*4 c6*4 | b5*8 d6*8",
         keys = "Fmaj7*3 Fmaj7*3 Fmaj7*2 .*2 Fmaj7*3 Fmaj7*3 | E7*3 E7*3 E7*2 .*2 E7*3 E7*3 | Am7*3 Am7*3 Am7*2 .*2 Am7*3 Am7*3 | G7*3 G7*3 G7*2 .*2 G7*3 G7*3",
         bass = "f2*6 c3*2 c3*6 f2*2 | e2*6 b2*2 b2*6 e2*2 | a1*6 e2*2 e2*6 a1*2 | g1*6 d2*2 d2*6 g1*2",
         drums = "k+h h r h k+h h r h k+h h h r k+h r h h"},
    C = {lead = "e6*4 d6*4 c6*4 a5*4 | f5*6 g5*2 a5*8 | d6*4 c6*4 b5*4 g5*4 | e5*6 f5*2 g5*8",
         keys = "Am7*3 Am7*3 Am7*2 .*2 Am7*3 Am7*3 | Dm7*3 Dm7*3 Dm7*2 .*2 Dm7*3 Dm7*3 | G7*3 G7*3 G7*2 .*2 G7*3 G7*3 | Cmaj7*3 Cmaj7*3 Cmaj7*2 .*2 Cmaj7*3 Cmaj7*3",
         bass = "a1*6 e2*2 e2*6 a1*2 | d2*6 a2*2 a2*6 d2*2 | g1*6 d2*2 d2*6 g1*2 | c2*6 g2*2 g2*6 c2*2",
         drums = "k+h h r h k+h h r h k+h h h r k+h r h h"},
  },
  order = {"A", "A", "B", "A", "C", "C", "B", "A"},
}

M.su_shuffle = {
  bpm = 136, swing = 0.3, gain = 1,
  inst = {lead = copy(CALLIOPE, {vol = 0.07}), lead_2 = XYLO, chord = copy(CHOP, {vol = 0.05}), bass = TUBA},
  parts = {
    A = {lead = "g5*2 e5*2 c5*2 e5*2 g5*4 c6*4 | a5*2 f5*2 c5*2 f5*2 a5*8 | g5*2 e5*2 c5*2 e5*2 d5*2 f5*2 b5*2 d6*2 | c6*4 g5*4 c6*8",
         chord = ".*4 C*4 .*4 C*4 | .*4 F*4 .*4 F*4 | .*4 C*4 .*4 G7*4 | .*4 G7*4 .*4 C*4",
         bass = oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("c3", "g2") .. "g2*4 d3*4 c3*4 g2*4 ",
         drums = "k*4 s*4 k*4 s*4"},
    B = {lead_2 = "e6*2 d6*2 c6*2 a5*2 g5*4 e5*4 | f5*2 a5*2 c6*2 d6*2 c6*8 | d6*2 c6*2 b5*2 a5*2 g5*4 f5*4 | e5*4 d5*4 c5*8",
         chord = ".*4 C*4 .*4 Am*4 | .*4 F*4 .*4 F*4 | .*4 G7*4 .*4 G7*4 | .*4 C*4 .*4 C*4",
         bass = oompah("c3", "g2") .. oompah("f2", "c3") .. oompah("g2", "d3") .. oompah("c3", "g2"),
         drums = "k*4 s*4 k*4 s*2 s?*2"},
  },
  order = {"A", "B", "A+5", "B+5", "A"},
}

M.su_lazy = {
  bpm = 84, gain = 1, echo = {time = 0.5, fb = 0.3, mix = 0.2},
  inst = {lead = STEEL, pick = copy(GUITAR, {arp = "up", oct = 4, vol = 0.06}), harp = HARMONICA, bass = copy(BASS, {vol = 0.36, gate = 0.7})},
  parts = {
    A = {lead = "e5*8 g5*4 e5*4 | d5*12 c5*4 | a4*8 c5*4 d5*4 | e5*16", pick = "C*16 G*16 F*16 C*16",
         bass = "c2*8 g2*8 | g1*8 d2*8 | f1*8 c2*8 | c2*8 g1*8", drums = "k?*8 r?*8"},
    B = {lead = "g5*8 a5*4 g5*4 | e5*12 d5*4 | c5*8 d5*4 e5*4 | c5*16", pick = "C*16 Am*16 F*16 C*16",
         bass = "c2*8 g2*8 | a1*8 e2*8 | f1*8 c2*8 | c2*8 g1*8", drums = "k?*8 r?*8"},
    C = {harp = "g4*8 e4*8 | d4*8 b3*8 | c4*8 a3*8 | g3*16", pick = "C*16 G*16 F*16 C*16",
         bass = "c2*8 g2*8 | g1*8 d2*8 | f1*8 c2*8 | c2*8 g1*8", drums = "k?*8 r?*8"},
  },
  order = {"A", "B", "C", "A", "B"},
}

M.su_storm = {
  bpm = 100, gain = 1, echo = {time = 0.6, fb = 0.35, mix = 0.25},
  inst = {lead = copy(LEAD, {vol = 0.1, send = 0.4}), pad = copy(PAD, {vol = 0.06}), bass = copy(BASS, {gate = 0.5, vol = 0.38})},
  parts = {
    A = {lead = "e5*4 .*4 e5*2 f5*2 e5*4 | c5*8 a4*8 | d5*4 f5*4 a5*4 f5*4 | g#5*12 .*4", pad = "Am*16 F*16 Dm*16 E*16",
         bass = sixteens("a1", "a2") .. sixteens("f1", "f2") .. sixteens("d2", "d3") .. sixteens("e1", "e2"),
         drums = "k*2 t*2 T*2 t*2 k*2 t*2 s*2 t*2 | k*2 t*2 T*2 t*2 k*2 t*2 s*2 t*2 | k*2 t*2 T*2 t*2 k*2 t*2 s*2 t*2 | k*2 t*2 T*2 t*2 s s s! s! c*4"},
    B = {lead = "a5*4 g5*4 e5*8 | f5*4 e5*4 c5*8 | e5*4 g5*4 c6*8 | b5*12 .*4", pad = "Am*16 F*16 C*16 G*16",
         bass = sixteens("a1", "a2") .. sixteens("f1", "f2") .. sixteens("c2", "c3") .. sixteens("g1", "g2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.su_fireflies = {
  bpm = 72, gain = 1.1, echo = {time = 0.5, fb = 0.45, mix = 0.3},
  inst = {lead = copy(FLUTE, {vol = 0.12}), box = copy(BELL, {arp = "up", oct = 4, vol = 0.09}), pad = copy(PAD, {vol = 0.04}),
          bass = copy(PLUCK, {vol = 0.24, d = 0.6})},
  parts = {
    A = {box = "Cmaj7*16 Am7*16 Fmaj7*16 G*16", pad = "Cmaj7*16 Am7*16 Fmaj7*16 G*16",
         bass = "c3*8 g2*8 | a2*8 e2*8 | f2*8 c3*8 | g2*8 d2*8", drums = "h?*2 h?*2 .*4 h?*2 h?*2 .*4"},
    B = {lead = "g5*8 e5*4 c5*4 | a5*8 g5*4 e5*4 | f5*8 a5*4 c6*4 | b5*12 .*4", box = "Cmaj7*16 Am7*16 Fmaj7*16 G*16",
         pad = "Cmaj7*16 Am7*16 Fmaj7*16 G*16", bass = "c3*8 g2*8 | a2*8 e2*8 | f2*8 c3*8 | g2*8 d2*8", drums = "h?*2 h?*2 .*4 h?*2 h?*2 .*4"},
    C = {lead = "e6*8 d6*4 c6*4 | c6*8 b5*4 a5*4 | a5*8 g5*4 f5*4 | g5*16", box = "Cmaj7*16 Am7*16 Fmaj7*16 G*16",
         pad = "Cmaj7*16 Am7*16 Fmaj7*16 G*16", bass = "c3*8 g2*8 | a2*8 e2*8 | f2*8 c3*8 | g2*8 d2*8", drums = "h?*2 h?*2 .*4 h?*2 h?*2 .*4"},
  },
  order = {"A", "B", "C", "B"},
}

-- ------------------------------------------------------------------ Sweethearts (valentine.lua): all ours
local TRIPLET = function(ch) return string.rep(ch .. " ", 12) end
M.ve_open = {
  bpm = 124, gain = 1, echo = {time = 0.36, fb = 0.25, mix = 0.18},
  inst = {lead = copy(LEAD, {duty = 0.5, vol = 0.1, send = 0.3}), lead_2 = copy(BELL, {vol = 0.12}),
          chord = copy(CHOP, {vol = 0.05}), bass = copy(BASS, {gate = 0.6})},
  parts = {
    A = {lead = "e5*2 g5*2 c6*4 b5*2 a5*2 g5*4 | a5*2 c6*2 e6*4 d6*2 c6*2 a5*4 | f5*2 a5*2 c6*4 b5*2 a5*2 f5*4 | g5*4 b5*4 d6*8",
         chord = string.rep(".*2 C*2 ", 4) .. string.rep(".*2 Am*2 ", 4) .. string.rep(".*2 F*2 ", 4) .. string.rep(".*2 G*2 ", 4),
         bass = eights("c2", "c3") .. eights("a1", "a2") .. eights("f1", "f2") .. eights("g1", "g2"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
    B = {lead_2 = "c6*8 b5*4 a5*4 | e6*8 d6*4 c6*4 | a5*4 c6*4 f6*4 e6*4 | d6*12 .*4",
         chord = string.rep(".*2 C*2 ", 4) .. string.rep(".*2 Am*2 ", 4) .. string.rep(".*2 F*2 ", 4) .. string.rep(".*2 G*2 ", 4),
         bass = eights("c2", "c3") .. eights("a1", "a2") .. eights("f1", "f2") .. eights("g1", "g2"),
         drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 o*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.ve_chase = {
  bpm = 150, gain = 1,
  inst = {lead = copy(LEAD, {vol = 0.1}), arp = ARP, bass = copy(BASS, {gate = 0.6})},
  parts = {
    A = {lead = "a5 . a5 . c6 . a5 . e6*2 d6*2 c6*2 b5*2 | g5 . g5 . b5 . g5 . d6*2 c6*2 b5*2 a5*2 |" ..
                "f5 . f5 . a5 . f5 . c6*2 b5*2 a5*2 g5*2 | e5 . e5 . g#5 . e5 . b5*4 g#5*4",
         arp = "Am*16 G*16 F*16 E*16",
         bass = eights("a2", "a3") .. eights("g2", "g3") .. eights("f2", "f3") .. eights("e2", "e3"),
         drums = "k*2 h*2 s*2 h*2 k*2 h*2 s*2 h*2"},
  },
  order = {"A", "A", "A+3", "A"},
}

M.ve_bubble = {
  bpm = 128, gain = 1,
  inst = {lead = XYLO, chord = copy(CHOP, {vol = 0.05}), bass = copy(BASS, {gate = 0.6}), lead_2 = copy(BELL, {vol = 0.1})},
  parts = {
    A = {lead = "c6 . a5 . f5 . a5 . c6*2 d6*2 c6*4 | d6 . a5 . f5 . a5 . d6*2 e6*2 d6*4 |" ..
                "bb5 . g5 . d5 . g5 . bb5*2 c6*2 d6*4 | c6*2 bb5*2 a5*2 g5*2 e5*4 c5*4",
         chord = string.rep(".*2 F*2 ", 4) .. string.rep(".*2 Dm*2 ", 4) .. string.rep(".*2 Gm*2 ", 4) .. string.rep(".*2 C*2 ", 4),
         bass = eights("f2", "c3") .. eights("d2", "a2") .. eights("g2", "d3") .. eights("c2", "g2"),
         drums = "k*4 x*4 k*2 k*2 x*4"},
    B = {lead_2 = "f6*8 e6*4 c6*4 | d6*8 a5*8 | bb5*4 d6*4 g6*4 f6*4 | e6*12 .*4",
         chord = string.rep(".*2 F*2 ", 4) .. string.rep(".*2 Dm*2 ", 4) .. string.rep(".*2 Gm*2 ", 4) .. string.rep(".*2 C*2 ", 4),
         bass = eights("f2", "c3") .. eights("d2", "a2") .. eights("g2", "d3") .. eights("c2", "g2"),
         drums = "k*4 x*4 k*2 k*2 x*4"},
  },
  order = {"A", "B", "A+2", "B+2", "A"},
}

M.ve_serenade = {
  bpm = 63, steps = 3, gain = 1, echo = {time = 0.48, fb = 0.35, mix = 0.25},
  inst = {lead = copy(THEREMIN, {vol = 0.15}), keys = {wave = "sine", a = 0.004, d = 0.4, s = 0.2, r = 0.2, vol = 0.06, oct = 4},
          bass = copy(PLUCK, {vol = 0.28, d = 0.5})},
  parts = {
    A = {lead = "e5*6 d5*3 c5*3 | e5*6 g5*6 | a5*6 g5*3 f5*3 | d5*12",
         keys = TRIPLET("C") .. TRIPLET("Am") .. TRIPLET("F") .. TRIPLET("G"),
         bass = "c2*6 g2*6 | a1*6 e2*6 | f1*6 c2*6 | g1*6 d2*6", drums = "k?*3 h?*3 s?*3 h?*3"},
    B = {lead = "g5*6 a5*3 g5*3 | e5*6 c5*6 | f5*3 e5*3 d5*3 f5*3 | c5*12",
         keys = TRIPLET("C") .. TRIPLET("Am") .. TRIPLET("G7") .. TRIPLET("C"),
         bass = "c2*6 g2*6 | a1*6 e2*6 | g1*6 d2*6 | c2*6 g1*6", drums = "k?*3 h?*3 s?*3 h?*3"},
  },
  order = {"A", "B", "A", "B"},
}

M.ve_doowop = {
  bpm = 76, steps = 3, gain = 1, echo = {time = 0.4, fb = 0.3, mix = 0.2},
  inst = {lead = copy(TRUMPET, {vol = 0.1}), keys = {wave = "sine", a = 0.004, d = 0.35, s = 0.25, r = 0.2, vol = 0.06, oct = 4},
          choir = copy(CHOIR, {vol = 0.06}), bass = copy(BASS, {vol = 0.38, gate = 0.7})},
  parts = {
    A = {lead = "g5*6 e5*6 | a5*6 c6*6 | a5*3 g5*3 f5*3 a5*3 | g5*12",
         keys = TRIPLET("C") .. TRIPLET("Am") .. TRIPLET("F") .. TRIPLET("G"), choir = "C*12 Am*12 F*12 G*12",
         bass = "c2*3 e2*3 g2*3 a2*3 | a1*3 c2*3 e2*3 g2*3 | f1*3 a1*3 c2*3 d2*3 | g1*3 b1*3 d2*3 f2*3",
         drums = "k*3 h h h s*3 h h h"},
    B = {lead = "c6*6 b5*3 a5*3 | c6*6 e5*6 | f5*3 a5*3 c6*3 a5*3 | b5*6 d6*6",
         keys = TRIPLET("C") .. TRIPLET("Am") .. TRIPLET("F") .. TRIPLET("G"), choir = "C*12 Am*12 F*12 G*12",
         bass = "c2*3 e2*3 g2*3 a2*3 | a1*3 c2*3 e2*3 g2*3 | f1*3 a1*3 c2*3 d2*3 | g1*3 b1*3 d2*3 f2*3",
         drums = "k*3 h h h s*3 h h h"},
  },
  order = {"A", "B", "A", "B"},
}

M.ve_heart = {
  bpm = 132, gain = 1, echo = {time = 0.45, fb = 0.3, mix = 0.22},
  inst = {lead = copy(BELL, {vol = 0.18}), lead_2 = copy(FLUTE, {vol = 0.1}), chord = copy(CHOP, {vol = 0.05}),
          bass = copy(BASS, {gate = 0.5, vol = 0.38})},
  parts = {
    A = {lead = "e5*8 g5*4 | c6*8 b5*4 | a5*8 g5*4 | e5*12 | f5*8 a5*4 | d6*8 c6*4 | b5*8 a5*4 | g5*12",
         chord = ".*4 C*4 C*4 | .*4 C*4 C*4 | .*4 Am*4 Am*4 | .*4 C*4 C*4 | .*4 F*4 F*4 | .*4 F*4 F*4 | .*4 G*4 G*4 | .*4 G7*4 G7*4",
         bass = "c2*4 .*8 | e2*4 .*8 | a1*4 .*8 | c2*4 .*8 | f1*4 .*8 | a1*4 .*8 | g1*4 .*8 | b1*4 .*8",
         drums = "k*4 h?*4 h?*4"},
    B = {lead = "e6*8 d6*4 | c6*8 a5*4 | g5*8 b5*4 | c6*12", lead_2 = "c6*8 b5*4 | a5*8 f5*4 | d5*8 f5*4 | e5*12",
         chord = ".*4 C*4 C*4 | .*4 Am*4 Am*4 | .*4 G7*4 G7*4 | .*4 C*4 C*4",
         bass = "c2*4 .*8 | a1*4 .*8 | g1*4 .*8 | c2*4 .*8", drums = "k*4 h?*4 h?*4"},
  },
  order = {"A", "A", "B"},
}

-- ------------------------------------------------------------------ Easter Egg Hunt (easter.lua): all ours
M.eg_hunt = {
  bpm = 112, gain = 1, echo = {time = 0.4, fb = 0.3, mix = 0.2},
  inst = {lead = FLUTE, pick = copy(PLUCK, {arp = "up", oct = 4, vol = 0.14}), bass = copy(BASS, {gate = 0.6, vol = 0.38})},
  parts = {
    A = {lead = "d5*2 g5*2 b5*4 a5*2 g5*2 e5*4 | d5*2 g5*2 b5*2 d6*2 c6*8 | c6*2 b5*2 a5*2 g5*2 e5*4 c6*4 | b5*4 a5*4 g5*8",
         pick = "G*16 C*16 Am*16 D*8 G*8",
         bass = "g2*4 d3*4 g2*4 d3*4 | c3*4 g2*4 c3*4 g2*4 | a2*4 e3*4 a2*4 e3*4 | d3*4 a2*4 g2*8", drums = "k*4 h*4 s*4 h*4"},
  },
  order = {"A", "A", "A+5", "A"},
}

M.eg_dye = {
  bpm = 120, swing = 0.25, gain = 1,
  inst = {lead = XYLO, chord = copy(CHOP, {vol = 0.05}), bass = TUBA},
  parts = {
    A = {lead = "f5*2 a5*2 c6*2 a5*2 bb5*4 g5*4 | e5*2 g5*2 bb5*2 g5*2 a5*4 f5*4 | d5*2 f5*2 a5*2 f5*2 g5*4 e5*4 | c5*4 e5*4 f5*8",
         chord = ".*4 F*4 .*4 F*4 | .*4 C7*4 .*4 F*4 | .*4 Dm*4 .*4 C7*4 | .*4 C7*4 .*4 F*4",
         bass = oompah("f2", "c3") .. oompah("c3", "g2") .. oompah("d3", "a2") .. "c3*4 g2*4 f2*8 ", drums = "k*4 s*4 k*4 s*4"},
  },
  order = {"A", "A+2", "A"},
}

M.eg_hop = {
  bpm = 140, gain = 1,
  inst = {lead = ACCORDION, chord = copy(CHOP, {vol = 0.05}), bass = TUBA},
  parts = {
    A = {lead = "a5*4 f#5*4 a5*4 f#5*4 | a5*2 b5*2 a5*2 g5*2 f#5*4 e5*4 | g5*4 e5*4 g5*4 e5*4 | g5*2 a5*2 g5*2 f#5*2 e5*4 d5*4",
         chord = ".*4 D*4 .*4 D*4 | .*4 D*4 .*4 A7*4 | .*4 A7*4 .*4 A7*4 | .*4 A7*4 .*4 D*4",
         bass = oompah("d3", "a2") .. oompah("d3", "a2") .. oompah("a2", "e2") .. oompah("a2", "d3"), drums = "k*4 s*4 k*4 s*4"},
  },
  order = {"A", "A", "A+2", "A"},
}

M.eg_cascarones = {
  bpm = 100, gain = 1,
  inst = {lead = ACCORDION, chord = copy(CHOP, {vol = 0.05}), bass = copy(BASS, {gate = 0.7, vol = 0.4})},
  parts = {
    A = {lead = "e5*2 g5*2 e5*2 c5*2 d5*4 e5*4 | f5*2 a5*2 f5*2 d5*2 e5*4 f5*4 | g5*2 f5*2 e5*2 d5*2 c5*2 d5*2 e5*2 f5*2 | g5*12 .*4",
         chord = string.rep(".*2 C*2 ", 4) .. string.rep(".*2 Dm*2 ", 4) .. string.rep(".*2 G7*2 ", 4) .. string.rep(".*2 C*2 ", 4),
         bass = "c2*6 g2*2 c2*4 g1*4 | d2*6 a2*2 d2*4 a1*4 | g1*6 d2*2 g1*4 d2*4 | c2*6 g2*2 c2*4 g1*4",
         drums = "k h x h k h x h k h x h k h x h"},
  },
  order = {"A", "A", "A+2", "A"},
}

M.eg_secret = {
  bpm = 120, gain = 1, echo = {time = 0.375, fb = 0.4, mix = 0.25},
  inst = {lead = copy(LEAD, {vol = 0.1, send = 0.4}), arp = ARP, bass = copy(BASS, {gate = 0.6})},
  parts = {
    A = {lead = "e5*8 .*8 | f5*8 .*8 | e5*4 c5*4 a4*8 | g#4*16", arp = "Am*16 Bb*16 Am*16 E*16", bass = "a1*16 | bb1*16 | a1*16 | e1*16"},
    B = {lead = "c5*2 e5*2 g5*2 c6*2 e6*8 | d6*2 b5*2 g5*2 d5*2 b5*8 | c6*2 a5*2 f5*2 a5*2 c6*4 f6*4 | e6*16",
         arp = "C*16 G*16 F*16 C*16", bass = eights("c2", "c3") .. eights("g1", "g2") .. eights("f1", "f2") .. eights("c2", "c3"),
         drums = "k*2 h*2 s*2 h*2 k*2 k*2 s*2 h*2"},
  },
  order = {"A", "A", "B", "B"},
}

-- ------------------------------------------------------------------ Longhorns, more (longhorns.lua): all ours
M.lh_board = {
  bpm = 118, gain = 1, echo = {time = 0.38, fb = 0.25, mix = 0.18},
  inst = {lead = TRUMPET, brass = BRASS_PAD, bass = TUBA},
  parts = {
    A = {lead = "f5*2 bb5*2 d6*4 c6*2 bb5*2 g5*4 | f5*2 a5*2 c6*4 bb5*2 a5*2 f5*4 | eb5*2 g5*2 bb5*4 a5*2 g5*2 eb5*4 | f5*4 a5*4 bb5*8",
         brass = "Bb*16 F*16 Eb*16 F*8 Bb*8",
         bass = oompah("bb2", "f2") .. oompah("f2", "c3") .. oompah("eb2", "bb2") .. "f2*4 c3*4 bb2*8 ", drums = MARCH_DRUMS},
    B = {lead = "d6*4 c6*4 bb5*4 d6*4 | c6*4 a5*4 f5*8 | g5*4 bb5*4 eb6*4 d6*4 | c6*12 .*4",
         brass = "Bb*16 F*16 Eb*16 F*16",
         bass = oompah("bb2", "f2") .. oompah("f2", "c3") .. oompah("eb2", "bb2") .. oompah("f2", "c3"),
         drums = "k*2 s?*2 s*2 s?*2 k*2 s?*2 s!*2 s?*2 | k*2 s?*2 s*2 s?*2 k*2 s?*2 s!*2 s?*2 | k*2 s?*2 s*2 s?*2 k*2 s?*2 s!*2 s?*2 | k*2 s s s! s! s s s! s! c*4 .*2"},
  },
  order = {"A", "A", "B", "A"},
}

M.lh_legends = {
  bpm = 120, gain = 1, echo = {time = 0.5, fb = 0.35, mix = 0.22},
  inst = {arp = ARP, pad = copy(PAD, {vol = 0.05}), bass = copy(BASS, {gate = 0.5}), lead = TRUMPET, brass = BRASS_PAD},
  parts = {
    A = {arp = "Dm*16 Bb*16 C*16 A*16", pad = "Dm*16 Bb*16 C*16 A*16",
         bass = sixteens("d2", "d3") .. sixteens("bb1", "bb2") .. sixteens("c2", "c3") .. sixteens("a1", "a2"),
         drums = "k*4 h*4 k*4 h*4 | k*4 h*4 k*4 h*4 | k*4 h*4 k*4 h*4 | k*4 h*4 k*4 s s s! s!"},
    B = {lead = "d5*4 f#5*4 a5*8 | g5*4 b5*4 d6*8 | e6*4 d6*4 c#6*4 b5*4 | a5*16", brass = "D*16 G*16 A*16 D*16",
         bass = eights("d2", "d3") .. eights("g1", "g2") .. eights("a1", "a2") .. eights("d2", "d3"),
         drums = "c+k*2 s*2 k*2 s*2 k*2 s*2 k*2 s*2"},
  },
  -- (the replay's touchdown is about 48 s into the scene: the fanfare starts there)
  order = {"A", "A", "A", "A", "A", "A", "B", "B", "B", "B"},
}

M.lh_hex = {
  bpm = 66, steps = 3, gain = 1.1, echo = {time = 0.45, fb = 0.45, mix = 0.3},
  inst = {lead = copy(BELL, {vol = 0.18}), pad = copy(ORGAN, {vol = 0.06}), bass = copy(BASS, {vol = 0.36, gate = 0.8})},
  parts = {
    A = {lead = "a4*6 c5*3 e5*3 | d5*6 c5*3 b4*3 | c5*6 a4*3 e4*3 | g#4*12", pad = "Am*12 Dm*12 Am*12 E*12",
         bass = "a1*12 | d2*12 | a1*12 | e1*12", drums = "t*6 t?*6"},
    B = {lead = "c#5*6 e5*3 a5*3 | b5*6 a5*3 g#5*3 | a5*6 e5*3 c#5*3 | e5*12", pad = "A*12 E*12 A*12 E*12",
         bass = "a1*12 | e2*12 | a1*12 | e1*12", drums = "t*6 t?*3 t?*3"},
  },
  order = {"A", "A", "B", "A", "B"},
}

-- ------------------------------------------------------------------ sound effects (loop = false; steps of 1/32 s)
local function fx(inst, lane, beats, gain)
  return {bpm = 120, steps = 16, loop = false, gain = gain or 1, inst = {x = inst}, parts = {A = {x = lane}}, order = {"A"}}
end
M.SFX = {
  -- Starlight's sound logo: a twinkle up a major arpeggio to a ringing star (the intro, as the name is written)
  sting = fx({wave = "sine", a = 0.002, d = 0.9, s = 0.15, r = 0.6, vol = 0.22, vib = {0.08, 6, 0.3}, detune = 7},
             "g5*3 c6*3 e6*3 g6*3 c7*36 . . . e7*6 g7*20"),
  -- a laser: down from high, fast
  pew = fx({wave = "pulse", duty = 0.25, a = 0.001, d = 0.18, s = 0, r = 0.02, vol = 0.16, slide = 0.05}, "e7 c4*6"),
  -- the invaders' laser: lower, buzzier
  zap = fx({wave = "saw", a = 0.001, d = 0.2, s = 0, r = 0.02, vol = 0.12, slide = 0.06, lp = 3000}, "c6 c3*7"),
  -- an explosion: rumbling noise
  boom = fx({wave = "noise", a = 0.001, d = 0.7, s = 0, r = 0.1, vol = 0.45, lp = 900}, "c3*24"),
  pop = fx({wave = "noise", a = 0.001, d = 0.12, s = 0, r = 0.05, vol = 0.3, lp = 2500}, "c5*4"),
  -- a firework: thump up, then crackle
  crackle = fx({wave = "noise", a = 0.001, d = 0.05, s = 0, r = 0.02, vol = 0.18}, "c7 . c7 c7 . . c7 . c7 . . c7 c7 . . . c7"),
  -- the eagle: a screech down
  screech = fx({wave = "saw", a = 0.01, d = 0.6, s = 0, r = 0.1, vol = 0.28, slide = 0.12, vib = {1.2, 28, 0}, lp = 4000}, "a7 e7*16"),
  -- jets going over: a swell of noise
  jet = fx({wave = "noise", a = 1.2, d = 1, s = 0.6, r = 1.5, vol = 0.22, lp = 600}, "c2*80"),
  -- the crowd
  cheer = fx({wave = "noise", a = 0.5, d = 1, s = 0.7, r = 1.5, vol = 0.18, lp = 1800, trem = {0.35, 7}}, "c6*96"),
  -- duct tape
  tape = fx({wave = "noise", a = 0.001, d = 0.3, s = 0.6, r = 0.05, vol = 0.12, lp = 5000, trem = {0.6, 40}}, "c6*10"),
  -- the alarm's klaxon
  klaxon = fx({wave = "pulse", duty = 0.5, a = 0.01, d = 0.1, s = 0.9, r = 0.05, vol = 0.2, slide = 0.08},
              "d5*8 a5*8 d5*8 a5*8"),
  -- the power pellet
  power = fx({wave = "pulse", duty = 0.25, a = 0.002, d = 0.08, s = 0.4, r = 0.03, vol = 0.2}, "c5 e5 g5 c6 e6 g6 c7*4"),
  -- the saucer's warble
  saucer = fx({wave = "sine", a = 0.05, d = 0.5, s = 0.9, r = 0.3, vol = 0.12, vib = {2, 9, 0}}, "e6*60"),
  -- thunder: a long low rumble
  thunder = fx({wave = "noise", a = 0.05, d = 2.5, s = 0, r = 0.5, vol = 0.5, lp = 300}, "c2*90"),
  -- BOO!: a ghostly swoop down
  boo = fx({wave = "saw", a = 0.02, d = 0.8, s = 0.3, r = 0.3, vol = 0.2, slide = 0.2, vib = {0.8, 7, 0}, lp = 2000}, "c5 g3*30"),
  -- (the blueprint's kit, every show) a big switch thrown: the lights come on
  clunk = fx({wave = "noise", a = 0.001, d = 0.09, s = 0, r = 0.03, vol = 0.35, lp = 700}, "c3*3"),
  -- a ding: a lamp goes green, a job done
  ding = fx({wave = "sine", a = 0.001, d = 0.6, s = 0.1, r = 0.4, vol = 0.18}, "e6 e7*20"),
  -- a boing: a hop, a bonk on the head
  boing = fx({wave = "tri", a = 0.001, d = 0.3, s = 0.2, r = 0.1, vol = 0.22, slide = 0.15, vib = {0.3, 18, 0}}, "c4 c6*8"),
  -- a splash: water thrown up
  splash = fx({wave = "noise", a = 0.002, d = 0.6, s = 0, r = 0.2, vol = 0.32, lp = 2400}, "c5*20"),
  -- a whoosh: something fast going by
  whoosh = fx({wave = "noise", a = 0.15, d = 0.35, s = 0, r = 0.1, vol = 0.2, lp = 1500, slide = 0.1}, "c4*14"),
  -- a chime: sparkle, fixed, found
  chime = fx({wave = "sine", a = 0.001, d = 0.5, s = 0.1, r = 0.4, vol = 0.14}, "c6 e6 g6 c7*12"),
  -- a dinosaur's roar: low, growling, falling
  roar = fx({wave = "saw", a = 0.05, d = 0.9, s = 0.5, r = 0.5, vol = 0.32, slide = 0.25, vib = {1.6, 13, 0}, lp = 900},
            "e3*6 c2*34"),
  -- a tick: a clock, a knife on the block, a camera's timer
  tick = fx({wave = "noise", a = 0.001, d = 0.03, s = 0, r = 0.01, vol = 0.3, lp = 5000}, "c6"),
  -- (the Texas rebuild, 2026-11-06) a duck: two nasal quacks
  quack = fx({wave = "pulse", duty = 0.125, a = 0.002, d = 0.09, s = 0.4, r = 0.04, vol = 0.16, slide = 0.04, lp = 1800},
             "f5*3 c5*2 . . f5*3 c5*3"),
  -- a cow: a long low moo
  moo = fx({wave = "saw", a = 0.12, d = 0.4, s = 0.8, r = 0.3, vol = 0.18, slide = 0.25, lp = 700, vib = {0.2, 5, 0.2}},
           "a2*6 e3*10 c3*18"),
  -- a horn: two toots
  honk = fx({wave = "pulse", duty = 0.5, a = 0.005, d = 0.05, s = 0.8, r = 0.03, vol = 0.14, detune = 30, lp = 2200},
            "g4*4 . . g4*8"),
  -- a train whistle: two notes together, long
  whistle = fx({wave = "sine", a = 0.08, d = 0.3, s = 0.85, r = 0.4, vol = 0.14, detune = 380, vib = {0.1, 5, 0.1}},
               "b5*10 . b5*24"),
  -- a sizzle: meat on the fire
  sizzle = fx({wave = "noise", a = 0.05, d = 0.6, s = 0.5, r = 0.4, vol = 0.12, lp = 6000, trem = {0.5, 23}}, "c7*40"),
  -- "U! S! A!": three claps and the crowd
  usa = {bpm = 120, steps = 4, loop = false, gain = 1, inst = {},
         parts = {A = {drums = "x+k!*4 x+k!*4 x+k!*8"}}, order = {"A"}},
}

-- Loudness evened out (tools/song_levels.py): each song's gain times its level
if os.getenv("HOME_SONG_LEVELS") ~= "0" then
  local ok, levels = pcall(require, "song_levels")
  if ok and type(levels) == "table" then
    for name, g in pairs(levels) do
      if type(M[name]) == "table" then M[name].gain = (M[name].gain or 1) * g end
    end
  end
end

return M
