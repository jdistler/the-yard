return {
  title = "Bake",
  blurb = "bake treats for the cats",
  band = "4+",
  tint = 0xffb878,
  size = "large",
  save = "bake",
  order = 82,
  stat = function(s) local n = s.treats or 0 return n > 0 and plural(n, "treat") or nil end,
  icon = function(x, y, lit, t)
    local b = lit and sin(t * 5) * 1.5 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xffb878, 140)) end
    gfx.rrect_o(x - 8, y + 2 + b, 16, 10, 3, 0xf2b070, pal.night, 1.2)
    gfx.ellipse_o(x, y + b, 11, 7, 0xff98c8, pal.night, 1.2)
    gfx.circle_o(x, y - 7 + b, 3.2, 0xe84855, pal.night, 1)
  end,
}
