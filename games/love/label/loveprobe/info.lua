-- A menu row for the LÖVE probe, packed only by `cart deploy --with-love-probe` (it is not in carts/).
-- native = "loveprobe" runs /data/Games/loveprobe, the launcher script beside yard.
return {
  title = "LOVE probe",
  blurb = "measures the GPU, then exits",
  band = "TEST",
  tint = 0xe86b9a,
  native = "loveprobe",
  order = 95,
  stat = function(s) return nil end,
  icon = function(x, y, lit, t)
    gfx.heart(x, y, 9, pal.night)
    gfx.heart(x, y, 7, lit and 0xe86b9a or pal.dim)
  end,
}
