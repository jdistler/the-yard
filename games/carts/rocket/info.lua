return {
  title = "Starship",
  blurb = "co-op space rescue",
  band = "ALL",
  tint = 0x7fe8ff,
  size = "large",
  save = "rocket",
  order = 90,
  stat = function(s) return (s.best or 0) > 0 and ("best " .. s.best) or nil end,
  icon = function(x, y, lit, t)
    local b = lit and sin(t * 7) * 2 or 0
    if lit then gfx.glow(x, y, 18, alpha(0x7fe8ff, 150)) end
    gfx.tri(x, y - 12 + b, x - 8, y + 6 + b, x + 8, y + 6 + b, 0xfff6ea)
    gfx.circle_o(x, y - 1 + b, 3.2, 0x7fe8ff, pal.night, 1)
    gfx.tri(x - 4, y + 6 + b, x + 4, y + 6 + b, x, y + 13 + b, 0xffa84c)
  end,
}
