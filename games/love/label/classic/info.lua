-- A menu row shown only in GPU yard (the menu cart hides it on the C runtime): it leaves GPU yard for the
-- classic Yard, the same games drawn by the CPU. native = "classic" is not a program: the GPU runtime quits
-- with the request, loveprobe.sh exits 10, and The Yard's supervisor shows the C runtime's menu.
return {
  title = "Classic yard",
  blurb = "the same games, drawn by the CPU",
  band = "TEST",
  tint = 0xffd27f,
  native = "classic",
  order = 96,
  stat = function(s) return nil end,
  icon = function(x, y, lit, t)
    gfx.rrect(x - 9, y - 7, 18, 14, 3, lit and 0xffd27f or pal.dim)
    gfx.rect(x - 6, y - 4, 12, 8, pal.night)
  end,
}
