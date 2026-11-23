return {
  title = "Band",
  blurb = "play music with friends",
  band = "4+",
  tint = 0xb998f0,
  size = "large",
  save = "band",
  order = 86,
  stat = function(s)
    local f, n = s.fans or 0, s.songs or 0
    if f > 0 then return plural(f, "fan") end
    return n > 0 and plural(n, "encore") or nil
  end,
  icon = function(x, y, lit, t)
    local b = lit and sin(t * 6) * 2 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xb998f0, 140)) end
    gfx.circle_o(x - 5, y + 6 + b, 4.5, 0xffd84a, pal.night, 1.2)
    gfx.circle_o(x + 6, y + 3 - b, 4.5, 0xff98c8, pal.night, 1.2)
    gfx.line(x - 1, y + 6 + b, x - 1, y - 9 + b, 2.2, pal.night)
    gfx.line(x + 10, y + 3 - b, x + 10, y - 11 - b, 2.2, pal.night)
    gfx.line(x - 1, y - 9 + b, x + 10, y - 11 - b, 3, 0x7fe8ff)
  end,
}
