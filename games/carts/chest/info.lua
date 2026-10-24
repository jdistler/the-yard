return {
  title = "Chest",
  blurb = "the key, the chest, Zam",
  band = "5+",
  tint = 0x7fd6a0,
  size = "large",
  save = "chest",
  order = 50,
  stat = function(s) local n = s.gems or 0 return n > 0 and plural(n, "gem") or nil end,
  icon = function(x, y, lit, t)
    local lid = lit and abs(sin(t * 2.5)) * 3 or 0
    if lit then gfx.glow(x, y - 2, 18, alpha(0xffd060, 120 + floor(lid * 20))) end
    gfx.rrect_o(x - 11, y - 2, 22, 13, 2, 0xb06a34, pal.night, 1.2)
    gfx.rrect_o(x - 11, y - 9 - lid, 22, 7, 3, 0xc87c3e, pal.night, 1.2)
    gfx.rect(x - 2, y - 4, 4, 9, pal.sun)
    gfx.rect(x - 1, y + 1, 2, 2, pal.night)
  end,
}
