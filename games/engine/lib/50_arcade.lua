-- The arcade shell for score games: a title screen, a round, a "game over" card, the best
-- score in the save, and an attract demo when nobody has touched the stick for ten seconds.
--
--   arcade.setup{key = "best", start = new_round}      in init()
--   arcade.update()                                      first thing in update(); returns the state
--   arcade.score(n)                                      as points come in
--   arcade.over()                                        when the round ends
--   arcade.state                                         "title", "play", or "over"
--   arcade.demo                                          true while the attract demo plays
--
-- The demo plays through the cart's own bot(): write bot() to press the deck the way a
-- player would (input.bot("left") and so on), including pressing to start on the title.
-- A demo never writes a record. A real press ends it.

arcade = {state = "title", demo = false, best = 0, t = 0, idle = 0, new_best = false, points = 0}
local opts = {}

function arcade.setup(o)
  opts = o or {}
  opts.key = opts.key or "best"
  opts.idle = opts.idle or 600
  arcade.best = clamp(save.get(opts.key, 0), 0, 1000000)
  arcade.saved = arcade.best
  arcade.state = "title"
  on_quit(function() arcade.save() end)
end

function arcade.save()
  if arcade.best > arcade.saved and not arcade.demo then
    save.set(opts.key, arcade.best)
    if save.write() then arcade.saved = arcade.best else log(game.id .. ": score save failed") end
  end
end

function arcade.start()
  arcade.state = "play"
  arcade.t = 0
  arcade.points = 0
  arcade.new_best = false
  particles.clear()
  if opts.start then opts.start() end
end

-- Record points. Returns true the first time this round passes the old best.
function arcade.score(n)
  arcade.points = n
  if n > arcade.best and not arcade.demo then
    local first = not arcade.new_best and arcade.best > 0
    arcade.best = n
    arcade.new_best = true
    return first
  end
  return false
end

function arcade.over()
  arcade.state = "over"
  arcade.t = 0
  arcade.save()
end

function arcade.to_title()
  arcade.state = "title"
  arcade.t = 0
  arcade.idle = 0
  particles.clear()
  if opts.title then opts.title() end
end

local function demo_off(quiet)
  arcade.demo = false
  game.demo = false
  input.bot_clear()
  if not quiet then log(game.id .. " demo off") end
end

function arcade.update()
  local any = input.any()
  arcade.t = arcade.t + 1
  if arcade.demo and any then
    demo_off()
    arcade.to_title()
  end
  if arcade.state == "title" then
    arcade.idle = any and 0 or arcade.idle + 1
    if input.action() then
      arcade.start()
    elseif arcade.idle > opts.idle and not arcade.demo and not game.autoplay then
      arcade.demo = true
      game.demo = true
      arcade.idle = 0
      log(game.id .. " demo")
      if opts.demo_starts then arcade.start() end
    end
  elseif arcade.state == "over" then
    if arcade.t > 50 and input.action() then
      arcade.start()
    elseif arcade.demo and arcade.t > 240 then
      demo_off(true)
      arcade.to_title()
    end
  end
  return arcade.state
end

-- The usual cards. Games can draw their own instead.
function arcade.draw_title(title, lines, y)
  y = y or 96
  local bob = sin(game.frame * 0.05) * 3
  local h = 40 + #lines * 16 + 40
  ui.panel(26, y + bob, W - 52, h)
  gfx.text(title, W / 2, y + 2 + bob, 46, pal.sun, "center", pal.night)
  for i, l in ipairs(lines) do
    gfx.text(l[1], W / 2, y + 44 + (i - 1) * 15 + bob, 12, l[2] or pal.cream, "center")
  end
  if blink(60, 30) then gfx.text("press to start", W / 2, y + h - 30 + bob, 18, pal.cream, "center", pal.night) end
  if arcade.best > 0 then gfx.text((opts.best_label or "best %d"):format(arcade.best), W / 2, y + h + 8, 13, pal.sun, "center", pal.night) end
end

function arcade.draw_over(headline, score)
  local k = ease.out_back(clamp(arcade.t / 30, 0, 1))
  local y = 110 - (1 - k) * 60
  ui.panel(30, y, W - 60, 96, alpha(0x2a1630, 220))
  gfx.text(headline, W / 2, y + 6, 17, 0xffb0a0, "center", pal.night)
  gfx.text(tostring(score), W / 2, y + 24, 38, pal.cream, "center", pal.night)
  if arcade.new_best and score > 0 then
    gfx.text("a new best!", W / 2, y + 66, 13, pal.sun, "center")
  else
    gfx.text((opts.best_label or "best %d"):format(arcade.best), W / 2, y + 66, 13, pal.sun, "center")
  end
  if arcade.t > 50 and blink(60, 30) then gfx.text("press to play again", W / 2, y + 100, 13, pal.cream, "center", pal.night) end
end

function arcade.draw_demo(y)
  if arcade.demo then gfx.text("demo - press to play", W / 2, y or 104, 13, alpha(pal.cream, 200 + floor(sin(game.frame * 0.1) * 50)), "center", pal.night) end
end
