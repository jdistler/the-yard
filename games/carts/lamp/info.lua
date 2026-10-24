return {
  title = "Lamp",
  blurb = "wake the sleeping stars",
  band = "ALL",
  tint = 0xffc94a,
  size = "small",
  save = "lamp",
  order = 20,
  stat = function(s) local n = s.best or 0 return n > 0 and plural(n, "night") or nil end,
  icon = function(x, y, lit, t)
    local sw = lit and sin(t * 3) * 2 or 0
    if lit then gfx.glow(x + sw, y + 2, 22, alpha(0xffb040, 150)) end
    gfx.line(x, y - 13, x + sw, y - 8, 1.2, 0x8a6a40)
    gfx.rrect_o(x - 6 + sw, y - 8, 12, 17, 3, 0xffe08a, pal.night, 1.2)
    gfx.rect(x - 4 + sw, y - 4, 8, 9, lit and 0xfff4c0 or 0xd9b060)
    gfx.star(x + 11, y - 9, 3.5, t, lit and pal.sun or pal.dim)
  end,
}
