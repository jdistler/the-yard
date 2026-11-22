return {
  title = "Garden",
  blurb = "grow magic flowers",
  band = "4+",
  tint = 0xffa0d4,
  size = "large",
  save = "garden",
  order = 78,
  stat = function(s) local n = s.blooms or 0 return n > 0 and plural(n, "bloom") or nil end,
  icon = function(x, y, lit, t)
    local sc = lit and (1 + sin(t * 4) * 0.1) or 1
    if lit then gfx.glow(x, y, 18, alpha(0xffa0d4, 140)) end
    for i = 0, 4 do
      local a = i * 1.257 + (lit and t * 0.6 or 0)
      gfx.circle_o(x + cos(a) * 6 * sc, y + sin(a) * 6 * sc, 4.5 * sc, 0xff8ec8, pal.night, 1.1)
    end
    gfx.circle_o(x, y, 4.2 * sc, 0xffd84a, pal.night, 1.1)
  end,
}
