-- Orb is a native OpenGL game (native/orb/orb.c), not a Lua cart: the menu runs the
-- program named here, beside yard. This label is how the menu knows it.
return {
  title = "Orb",
  blurb = "dive down the glowing well",
  band = "8+",
  tint = 0xa98bff,
  save = "orb",
  native = "orb",
  order = 30,
  stat = function(s) return (s.best or 0) > 0 and ("best " .. s.best) or nil end,
  icon = function(x, y, lit, t)
    if lit then gfx.glow(x, y, 20, alpha(0x9a70ff, 170)) end
    gfx.circle_o(x, y, 9, 0x7a54e8, pal.night, 1.2)
    gfx.circle(x - 3, y - 3, 3.5, 0xc8b4ff)
    gfx.ellipse(x, y + 1, 14, 3, alpha(0x7fe0ff, lit and 200 or 110))
    gfx.ellipse(x, y + 1, 11, 1.6, alpha(0x2a1a50, 160))
  end,
}
