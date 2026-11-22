return {
  title = "Chomp",
  blurb = "gobble dots & silly ghosts",
  band = "4+",
  tint = 0xffdc36,
  size = "large",
  save = "chomp",
  order = 62,
  stat = function(s)
    local hi = s.hi or 0
    if hi > 0 then return hi .. " pts" end
    local b = s.best or 0
    return b > 0 and (b .. (b == 1 and " maze" or " mazes")) or nil
  end,
  icon = function(x, y, lit, t)
    local m = lit and (0.2 + abs(sin(t * 10)) * 0.45) or 0.35
    if lit then gfx.glow(x, y, 18, alpha(0xffdc36, 150)) end
    gfx.circle_o(x, y, 10, 0xffdc36, pal.night, 1.5)
    gfx.tri(x, y, x + 11, y - 10 * m, x + 11, y + 10 * m, pal.night)
    gfx.circle(x - 1, y - 4.5, 1.8, pal.night)
    gfx.circle(x + 12, y, 2.2, 0xfff6ea)
  end,
}
