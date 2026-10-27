-- A menu row to try Partycade Home before it opens at power-on (games/love/home). native = "homepreview" runs
-- /data/Games/homepreview, which runs /data/home/homeloop in preview mode: its last card comes back here.
return {
  title = "Home preview",
  blurb = "the new front end: try it",
  band = "TEST",
  tint = 0xff4fd8,
  native = "homepreview",
  memory = "all",
  order = 94,
  stat = function(s) return nil end,
  icon = function(x, y, lit, t)
    gfx.rrect(x - 10, y - 7, 20, 14, 3, lit and 0xff4fd8 or pal.dim)
    gfx.rect(x - 7, y + 2, 14, 2, pal.night)
  end,
}
