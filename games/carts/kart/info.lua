return {
  title = "Star Kart",
  blurb = "race rivals, grab item boxes",
  band = "5+",
  tint = 0xff5a6e,
  size = "large",
  save = "kart",
  order = 65,
  stat = function(s)
    if (s.cups or 0) > 0 then return plural(s.cups, "cup") end
    return (s.best or 0) > 0 and ("best " .. s.best) or nil
  end,
  icon = function(x, y, lit, t)
    local b = lit and sin(t * 8) * 1.5 or 0
    if lit then gfx.glow(x, y, 18, alpha(0xff6070, 140)) end
    gfx.rrect_o(x - 11, y - 4 + b, 22, 11, 4, 0xe84855, pal.night, 1.3)
    gfx.circle_o(x - 8, y + 6 + b, 3.5, pal.ink, pal.night, 1)
    gfx.circle_o(x + 8, y + 6 + b, 3.5, pal.ink, pal.night, 1)
    gfx.circle_o(x, y - 6 + b, 4.5, 0xfff6ea, pal.night, 1.1)
    gfx.star(x + 11, y - 9, 3.5, t * 2, lit and pal.sun or pal.dim)
  end,
}
