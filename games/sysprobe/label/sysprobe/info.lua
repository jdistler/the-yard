-- A menu row for the system probe, packed only by `cart deploy --with-sysprobe` (it is not in carts/).
-- native = "sysprobe" runs /data/Games/sysprobe, a read-only shell script beside yard (FIELD_TASKS.md).
return {
  title = "System probe",
  blurb = "2 minutes dark: plug things in",
  band = "TEST",
  tint = 0x6bb3e8,
  native = "sysprobe",
  order = 97,
  stat = function(s) return nil end,
  icon = function(x, y, lit, t)
    gfx.circle(x, y, 9, pal.night)
    gfx.circle(x, y, 7, lit and 0x6bb3e8 or pal.dim)
  end,
}
