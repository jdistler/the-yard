return {
  title = "Dig",
  blurb = "dig tunnels, pop foes, find gems",
  band = "5+",
  tint = 0xffa84c,
  size = "large",
  save = "dig",
  order = 60,
  stat = function(s) local n = s.best or 0 return n > 0 and ("level " .. n) or nil end,
  icon = function(x, y, lit, t)
    local bob = lit and sin(t * 4) * 2 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xffc060, 140)) end
    -- Warm earth mound + red hard hat with glowing headlamp.
    gfx.rrect_o(x - 12, y + 3, 24, 9, 3, 0xc87a40, pal.night, 1.2)
    gfx.ellipse_o(x, y + 1 + bob, 10, 8, 0xe84855, pal.night, 1.3)
    gfx.rrect_o(x - 12, y + 2 + bob, 24, 4, 2, 0xfff6ea, pal.night, 1.1)
    gfx.circle_o(x, y - 3 + bob, 3, 0xffd84a, pal.night, 1)
    gfx.star(x + 11, y - 7, 3.5, t * 1.5, lit and pal.sun or pal.dim)
  end,
}
