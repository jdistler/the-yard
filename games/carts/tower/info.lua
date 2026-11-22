return {
  title = "Tower",
  blurb = "climb ladders, hop barrels",
  band = "5+",
  tint = 0xe86b9a,
  size = "large",
  save = "tower",
  order = 74,
  stat = function(s) return (s.best or 0) > 0 and ("best " .. s.best) or nil end,
  icon = function(x, y, lit, t)
    local b = lit and abs(sin(t * 5)) * 3 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xff80b0, 140)) end
    gfx.rect(x - 12, y + 6, 24, 4, 0xe84855)
    gfx.rect(x - 12, y - 4, 24, 4, 0xe84855)
    gfx.line(x + 4, y - 4, x + 4, y + 10, 2, 0x7fe8ff)
    gfx.line(x + 9, y - 4, x + 9, y + 10, 2, 0x7fe8ff)
    gfx.circle_o(x - 5, y - 8 - b, 5, 0xffd84a, pal.night, 1.2)
  end,
}
