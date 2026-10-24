-- Little sounds with a voice. Every one is short and soft: the cabinet is in a home.
snd = {}
local pent = {72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96}

-- A rising note from a five-note scale: call with a running count for catches in a row.
function snd.note(i, vol) sfx.note("tri", pent[(i - 1) % #pent + 1], 0.2, vol or 0.4) end
function snd.pick(i) local m = pent[((i or 1) - 1) % #pent + 1] sfx.note("tri", m, 0.25, 0.35) sfx.note("sine", m + 12, 0.18, 0.12) end
function snd.ok() sfx.arp("tri", {72, 76, 79}, 0.07, 0.3) end
function snd.win() sfx.arp("tri", {72, 76, 79, 84, 88}, 0.09, 0.38) end
function snd.fanfare() sfx.arp("square", {72, 76, 79, 84}, 0.07, 0.25) end
function snd.sad() sfx.arp("tri", {67, 64, 60, 55}, 0.12, 0.4) end
function snd.bump() sfx.slide("square", 220, 70, 0.25, 0.35) sfx.noise(0.15, 0.3, 6000) end
function snd.oops() sfx.slide("tri", 300, 110, 0.25, 0.35) end
function snd.tick(i) sfx.tone("square", 600 + (i or 0) * 90, 0.06, 0.18) end
function snd.whoosh() sfx.slide("noise", 3000, 9000, 0.14, 0.2) end
function snd.sparkle() sfx.slide("sine", 900, 1500, 0.15, 0.12) end
function snd.zap() sfx.slide("square", 1400, 500, 0.12, 0.16) end
function snd.chime() sfx.note("sine", 91, 0.12, 0.15) end
function snd.start() sfx.slide("square", 400, 800, 0.12, 0.2) end
function snd.bye() sfx.arp("tri", {79, 76}, 0.16, 0.3) end
-- A purr: a low wobbling triangle, for anything cozy.
function snd.purr(up)
  sfx.play({wave = "tri", hz = 196 * (up and 1.5 or 1), dur = 0.5, vol = 0.28, attack = 0.05, release = 0.3, vib_hz = 17, vib_depth = 0.4})
end
