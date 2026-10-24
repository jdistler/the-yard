-- A menu row that runs the carts on LÖVE, drawn by the GPU (games/love/yard). Packed only by
-- `cart deploy --with-love-probe`. native = "loveyard" runs /data/Games/loveyard, the launcher beside yard.
return {
  title = "GPU yard",
  blurb = "the same games, drawn by the GPU",
  band = "TEST",
  tint = 0x7fe8ff,
  native = "loveyard",
  order = 96,
  stat = function(s) return nil end,
  icon = function(x, y, lit, t)
    gfx.star(x, y, 9, t, pal.night)
    gfx.star(x, y, 7, t, lit and 0x7fe8ff or pal.dim)
  end,
}
