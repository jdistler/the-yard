return {
  title = "Safari",
  blurb = "befriend meadow monsters",
  band = "5+",
  tint = 0x58d68d,
  size = "large",
  save = "safari",
  order = 70,
  stat = function(s)
    local n = s.caught or 0
    return n > 0 and (n .. "/8 friends") or nil
  end,
  icon = function(x, y, lit, t)
    local w = lit and sin(t * 7) * 3 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xff7080, 140)) end
    gfx.circle_o(x + w * 0.3, y, 10, 0xfff6ea, pal.night, 1.4)
    gfx.rrect(x - 10 + w * 0.3, y - 10, 20, 10, 8, 0xe84855)
    gfx.rect(x - 10 + w * 0.3, y - 1, 20, 2.5, pal.night)
    gfx.circle_o(x + w * 0.3, y, 3.2, 0xfff6ea, pal.night, 1.2)
  end,
}
