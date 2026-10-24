-- The label on the box. The menu reads this; the game itself is main.lua.
return {
  title = "{{TITLE}}",
  blurb = "a little story with friends",   -- one short line under the title in the menu
  band = "ALL",                  -- who it is for: ALL, 4+, 5+, 8+ (CONTROLS.md)
  tint = 0x8ec6ff,               -- the menu row's highlight color
  size = "{{SIZE}}",             -- "small" 240x320 or "large" 384x512
  save = "{{ID}}",               -- {{ID}}.sav on the cabinet
  order = 60,                    -- place in the menu, low first
  -- What the menu shows from the save: a short line, or nil for "new".
  stat = function(s) return (s.visits or 0) > 0 and plural(s.visits, "visit") or nil end,
  -- A tiny picture for the menu row, about 24 pixels across, centred on x, y.
  icon = function(x, y, lit, t)
    if lit then gfx.glow(x, y, 18, alpha(0x8ec6ff, 140)) end
    gfx.star(x, y, 9, t, pal.night)
    gfx.star(x, y, 7, t, lit and pal.sun or pal.dim)
  end,
}
