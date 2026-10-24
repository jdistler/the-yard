return {
  title = "Tea",
  blurb = "tea with the cats",
  band = "4+",
  tint = 0xff9ccf,
  size = "large",          -- 384x512
  save = "tea",
  order = 40,
  stat = function(s) local n = s.visits or 0 return n > 0 and plural(n, "visit") or nil end,
  icon = function(x, y, lit, t)
    if lit then
      for i = 0, 1 do
        local sy = (t * 14 + i * 7) % 14
        gfx.circle(x - 2 + i * 5 + sin(t * 4 + i) * 1.5, y - 6 - sy, 2.2 - sy * 0.12, alpha(pal.cream, 200 - floor(sy * 12)))
      end
    end
    gfx.ellipse_o(x, y + 9, 13, 3, 0xffd0e6, pal.night, 1.2)
    gfx.rrect_o(x - 9, y - 3, 18, 12, 4, pal.cream, pal.night, 1.2)
    gfx.rect(x - 9, y + 1, 18, 3, 0xff7fb0)
    gfx.ring(x + 11, y + 3, 3.5, 2, pal.night)
  end,
}
