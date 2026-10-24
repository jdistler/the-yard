-- {{TITLE}}: a score game built on the arcade shell (title, round, game over, best score,
-- attract demo). Catch the stars in the jar; three misses end the round.
-- CARTS.md "arcade" has the shell; GAMEDEV.md the walk-up rules it follows.

local GROUND = H - 40
local jar = {x = W / 2, vx = 0}
local stars, score, lives, spawn_in = {}, 0, 3, 0

local function new_round()
  stars, score, lives, spawn_in = {}, 0, 3, 30
  jar.x, jar.vx = W / 2, 0
end

function init()
  arcade.setup({key = "best", start = new_round})
  music.play({bpm = 110, steps = 4,
    {"E5 . G5 . A5 . G5 E5 . . D5 . C5 . . . ", wave = "square", vol = 0.05, duty = 0.25},
    {"C3 . . C3 G2 . . . A2 . . A2 E2 . . . ", wave = "tri", vol = 0.25}})
end

local function play()
  local dir = input.dir()
  jar.vx = clamp(jar.vx + dir * 0.9, -3.6, 3.6)
  if dir == 0 then jar.vx = jar.vx * 0.75 end
  jar.x = clamp(jar.x + jar.vx, 24, W - 24)
  spawn_in = spawn_in - 1
  if spawn_in <= 0 then
    stars[#stars + 1] = {x = rnd(20, W - 20), y = -10, vy = 1 + score * 0.02}
    spawn_in = max(24, 60 - score)
  end
  for _, s in ipairs(stars) do
    s.y = s.y + s.vy
    if s.y > GROUND - 24 and s.y < GROUND - 4 and abs(s.x - jar.x) < 26 then
      s.gone = true
      score = score + 1
      if arcade.score(score) then fx.label(W / 2, 90, "NEW BEST") end
      snd.pick(score)
      fx.pop(s.x, s.y)
    elseif s.y > GROUND then
      s.gone = true
      lives = lives - 1
      snd.bump()
      gfx.shake(4)
      if lives <= 0 then arcade.over() end
    end
  end
  sweep(stars, function(s) return not s.gone end)
end

function update()
  if arcade.update() == "play" then play() end
end

-- The built-in player: the tests and the attract demo use it.
function bot()
  if arcade.state ~= "play" then
    if game.frame % 40 == 5 then input.bot("low") end
    return
  end
  local target
  for _, s in ipairs(stars) do if not target or s.y > target.y then target = s end end
  if target then
    if target.x < jar.x - 6 then input.bot("left") elseif target.x > jar.x + 6 then input.bot("right") end
  end
end

local function paint_sky()
  gfx.vgrad(0, 0, W, H, 0x1a1a4a, 0x5a3a7a)
  for i = 1, 60 do gfx.pixel(rndi(0, W), rndi(0, GROUND), alpha(0xffffff, rndi(60, 200))) end
  gfx.vgrad(0, GROUND, W, H - GROUND, 0x3a6a4a, 0x1a3a2a)
end

function draw()
  backdrop("sky", paint_sky)
  for _, s in ipairs(stars) do
    gfx.glow(s.x, s.y, 14, alpha(0xffe080, 140))
    gfx.star(s.x, s.y, 8, game.frame * 0.05, pal.night)
    gfx.star(s.x, s.y, 6.5, game.frame * 0.05, pal.sun)
  end
  shadow(jar.x, GROUND + 2, 20)
  toon(function() toon.rrect(jar.x - 20, GROUND - 26, 40, 26, 8, 0xbfe2ff) end, 2.5, pal.night)
  gfx.rect(jar.x - 16, GROUND - 22, 32, 3, alpha(0xffffff, 150))
  particles.draw()
  if arcade.state ~= "title" then
    hearts(lives, 3, 30, 20, 5)
    gfx.text(tostring(score), W / 2, 8, 26, pal.cream, "center", pal.night)
  end
  if arcade.state == "title" then
    arcade.draw_title("{{TITLE}}", {{"catch the stars in the jar"}, {"three misses end the round", 0xffc0a0}})
  elseif arcade.state == "over" then
    arcade.draw_over("the jar is full", score)
  end
  arcade.draw_demo()
  ui.quit_hint()
end
