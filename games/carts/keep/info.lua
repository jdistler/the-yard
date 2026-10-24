-- The label on the box: what the menu shows for this cart.
return {
  title = "Keep",
  blurb = "catch the falling fruit",
  band = "ALL",            -- who it is for: ALL, 4+, 5+, 8+
  tint = 0xff7a59,         -- the menu's highlight color for this row
  size = "small",          -- 240x320
  save = "keep",           -- keep.sav
  order = 10,              -- place in the menu
  stat = function(s) return (s.best or 0) > 0 and ("best " .. s.best) or nil end,
  icon = function(x, y, lit, t)
    local fy = lit and (t * 30) % 22 or 6
    gfx.circle_o(x + 1, y - 12 + fy * 0.6, 4.5, 0xff5a4a, pal.night, 1.2)
    gfx.rect(x + 1, y - 18 + fy * 0.6, 1, 3, 0x5a3a20)
    gfx.ellipse(x + 4, y - 17 + fy * 0.6, 2.5, 1.4, 0x6fd36f)
    gfx.rrect_o(x - 10, y + 2, 20, 9, 3, 0xc98a4b, pal.night, 1.2)
    gfx.rect(x - 9, y + 5, 18, 1, 0x9a6430)
  end,
}
