-- Keep: catch what falls. Walk-up band (CONTROLS.md).
--
-- The stick moves Pip's basket along the bottom of an orchard at sunset. Fruit shakes on
-- the branch before it drops, and its shadow grows on the grass where it will land.
-- A button dashes the way you lean. A dash is never needed to catch; it only makes the
-- far ones reachable. Catches in a row build a multiplier. Three misses end the round.
-- Bees come later; catching one costs a heart.
--
-- keep.sav is "best N". KEEP_SELFTEST=1 plays until a catch, saves, and quits.

local GROUND, BASKET_W, MAXF = 292, 40, 8
local INK, CREAM, GOLD = 0x2a1630, pal.cream, pal.sun

local fruit = {}             -- {type, x, y, vx, vy, hang, phase}
local lives, combo, mult, score, catches
local spawn_in, dash_cd, dash_t, hurt_t, round_frames
local px, vx, lean, squash, facing = W / 2, 0, 0, 0, 1

local tune = {
  bpm = 118, steps = 4,
  {"E5 . G5 . A5 . G5 E5 . . D5 . C5 . D5 . E5 . G5 . A5 . C6 . A5 . G5 . E5 . . .", wave = "square", vol = 0.07, release = 0.06, attack = 0.005, duty = 0.25, pan = -0.2},
  {"C3 . . C3 G2 . . . A2 . . A2 E2 . . . F2 . . F2 C3 . . . G2 . . G2 D3 . G2 .", wave = "tri", vol = 0.30, release = 0.08, attack = 0.004},
  {"K . H . S . H . K . H K S . H . K . H . S . H . K . H K S . H H", wave = "noise", vol = 0.10, release = 0.05, pan = 0.2},
  {"C5 - - - - - - - A4 - - - - - - - F4 - - - - - - - G4 - - - - - - - ", wave = "sine", vol = 0.05, release = 0.3, attack = 0.2, pan = 0.3},
}

local function level()
  local l = score / 18 + round_frames / 3600
  return game.fast and l * 1.3 + 0.6 or l
end

local TREE_X = {22, 44, 66, 90, 112, 134, 158, 180, 202, 220}

local function spawn()
  if #fruit >= MAXF then return end
  local r, l = rndi(0, 99), level()
  local f = {vx = 0, vy = 0, phase = rnd() * tau}
  if score >= 10 and r < floor(8 + l * 4) and r < 24 then f.type = "bee"
  elseif r > 94 then f.type = "gold"
  elseif r > 74 then f.type = "pear"
  else f.type = "apple" end
  f.x = TREE_X[rndi(1, 10)]
  f.y = 48 + rnd(0, 10)
  f.hang = f.type == "bee" and 20 or floor(46 - clamp(l * 6, 0, 22))
  if f.type == "bee" then
    f.y = 40
    f.vx = rnd() < 0.5 and -1 or 1
  end
  fruit[#fruit + 1] = f
end

local function new_round()
  fruit = {}
  score, lives, combo, mult, catches = 0, 3, 0, 1, 0
  spawn_in, px, vx = 30, W / 2, 0
  dash_cd, dash_t, hurt_t, round_frames = 0, 0, 0, 0
  music.volume(1)
end

local function end_round()
  sfx.arp("tri", {67, 64, 60, 55}, 0.12, 0.4)
  music.volume(0.35)
  arcade.over()
  log(fmt("keep over %d best %d", score, arcade.best))
end

local PENT = {72, 74, 76, 79, 81, 84, 86, 88, 91, 93}

local function catch(f)
  local pts = f.type == "gold" and 5 or f.type == "pear" and 2 or 1
  local c = f.type == "gold" and GOLD or f.type == "pear" and 0xc8e05a or 0xff5a4a
  combo, catches = combo + 1, catches + 1
  mult = min(5, 1 + idiv(combo, 6))
  score = score + pts * mult
  if arcade.score(score) then
    sfx.arp("square", {72, 76, 79, 84}, 0.07, 0.25)
    particles.text(W / 2, 110, GOLD, "NEW BEST")
  end
  sfx.note("tri", PENT[combo % 10 + 1], 0.18, 0.45)
  if f.type == "gold" then
    sfx.arp("sine", {84, 88, 91, 96}, 0.05, 0.3)
    gfx.flash(alpha(0xfff0b0, 90), 10)
  end
  squash = 1
  particles.text(f.x, GROUND - 46, c, mult > 1 and fmt("+%dx%d", pts, mult) or "+" .. pts)
  particles.burst(f.x, GROUND - 26, 10 + pts * 3, 2.4, 30, 2, c, f.type == "gold" and "star" or "dot")
  if combo % 6 == 0 then
    particles.burst(px, GROUND - 20, 18, 3, 40, 2.5, GOLD, "star")
    sfx.slide("square", 600, 1200, 0.2, 0.18)
  end
  log("keep catch " .. score)
end

local function lose_life(x, bee)
  lives, combo, mult, hurt_t = lives - 1, 0, 1, 40
  gfx.shake(5)
  snd.bump()
  particles.burst(x, bee and GROUND - 24 or GROUND, 16, 2.2, 34, 2.2, bee and 0xffd84a or 0xd23a3a, "dot")
  log("keep miss lives " .. lives)
  if lives <= 0 then end_round() end
end

-- ------------------------------------------------------------------ the built-in player

function bot()
  if arcade.state ~= "play" then
    if (arcade.state == "title" and game.frame % 40 == 5) or (arcade.state == "over" and arcade.t > 60 and arcade.t % 30 == 0) then
      input.bot("low")
    end
    return
  end
  local target, best_t = nil, 1e9
  for _, f in ipairs(fruit) do
    if f.type ~= "bee" then
      local t = f.hang + (f.vy > 0 and (GROUND - 30 - f.y) / (f.vy + 1) or 60)
      if t < best_t then best_t, target = t, f end
    end
  end
  if target then
    local dx = target.x - px
    for _, b in ipairs(fruit) do
      if b.type == "bee" and abs(b.x - target.x) < 26 and b.y > 150 then
        dx = target.x + (b.x < target.x and 30 or -30) - px
      end
    end
    if dx < -4 then input.bot("left") elseif dx > 4 then input.bot("right") end
    if abs(dx) > 80 and best_t < 50 and dash_cd == 0 and game.frame % 2 == 1 then input.bot("low") end
  end
end

-- ------------------------------------------------------------------ the rules

local function play()
  local dir = input.dir()
  local maxv = game.fast and 4.2 or 3.4
  round_frames = round_frames + 1
  if dir ~= 0 then facing = dir end
  if input.action() and dash_cd == 0 then
    vx = facing * (game.fast and 9 or 8)
    dash_t, dash_cd = 9, 22
    snd.whoosh()
    particles.burst(px, GROUND - 2, 8, 1.5, 20, 2, alpha(0xe8f0c0, 200), "dot")
  end
  if dash_t > 0 then
    dash_t = dash_t - 1
  else
    vx = vx + dir * 0.9
    if dir == 0 then vx = vx * 0.72 end
    vx = clamp(vx, -maxv, maxv)
  end
  if dash_cd > 0 then dash_cd = dash_cd - 1 end
  px = px + vx
  if px < BASKET_W / 2 + 2 then px, vx = BASKET_W / 2 + 2, 0 end
  if px > W - BASKET_W / 2 - 2 then px, vx = W - BASKET_W / 2 - 2, 0 end
  lean = approach(lean, clamp(vx / 3, -1, 1), 0.3)
  squash = squash * 0.82
  if hurt_t > 0 then hurt_t = hurt_t - 1 end
  spawn_in = spawn_in - 1
  if spawn_in <= 0 then
    if #fruit < 1 + floor(clamp(level(), 0, 3)) then spawn() end
    spawn_in = floor(clamp(70 - level() * 12, 26, 70)) + rndi(0, 14)
  end
  local g = 0.06 + clamp(level() * 0.012, 0, 0.06)
  local rim = GROUND - 22
  local i = 1
  while i <= #fruit do
    local f, gone = fruit[i], false
    if f.hang > 0 then
      f.hang = f.hang - 1
      if f.hang == 0 then sfx.tone("sine", 900, 0.04, 0.08) end
    else
      if f.type == "bee" then
        f.vy = 1.1 + level() * 0.1
        f.x = f.x + f.vx * 1.2
        if f.x < 12 or f.x > W - 12 then f.vx = -f.vx end
        f.y = f.y + f.vy
      else
        f.vy = clamp(f.vy + g, 0, game.fast and 6 or 5)
        f.y = f.y + f.vy
      end
      if f.y >= rim - 6 and f.y <= rim + 8 and abs(f.x - px) < BASKET_W / 2 + 4 then
        gone = true
        if f.type == "bee" then
          log("keep sting")
          lose_life(f.x, true)
        else
          catch(f)
        end
      elseif f.y > GROUND then
        gone = true
        if f.type ~= "bee" then lose_life(f.x, false) end
      end
    end
    if gone then table.remove(fruit, i) else i = i + 1 end
    if arcade.state ~= "play" then return end
  end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.42)
  music.play(tune)
  arcade.setup({key = "best", start = new_round})
  new_round()
  if game.selftest then game.autoplay = true end
end

function update()
  if arcade.update() == "play" then play() end
  if game.selftest then
    if catches >= 1 and game.frame > 8 then
      save.set("best", arcade.best)
      assert(save.write() and save.get("best") == arcade.best, "keep self-test: the save did not stick")
      arcade.saved = arcade.best
      game.quit()
    elseif game.frame > 900 then
      error("keep self-test: no catch in 900 frames")
    end
  end
end

-- ------------------------------------------------------------------ pictures

local function draw_fruit(f, x, y, wob)
  local r = 6
  if f.type == "bee" then
    local wing = sin(game.frame * 1.2) * 2.5
    gfx.ellipse(x - 3, y - 5 - wing, 4, 2.5, alpha(0xe0f4ff, 200))
    gfx.ellipse(x + 3, y - 5 + wing, 4, 2.5, alpha(0xe0f4ff, 200))
    gfx.ellipse_o(x, y, 7, 5, 0xffd02a, INK, 1.2)
    gfx.rect(x - 2, y - 5, 2, 10, INK)
    gfx.rect(x + 2, y - 5, 2, 10, INK)
    gfx.circle(x + (f.vx > 0 and 5 or -5), y - 1, 1.2, INK)
  elseif f.type == "pear" then
    gfx.circle_o(x, y + 2, r, 0xc8e05a, INK, 1.2)
    gfx.circle_o(x, y - 4, r - 2.5, 0xc8e05a, INK, 1.2)
    gfx.circle(x, y + 2, r - 0.2, 0xc8e05a)
    gfx.circle(x - 2, y, 1.8, alpha(0xffffff, 150))
    gfx.line(x, y - 8, x + 1 + wob, y - 11, 1.2, 0x5a3a20)
  elseif f.type == "gold" then
    gfx.glow(x, y, 16, alpha(0xffd060, 160))
    gfx.star(x, y, 8, game.frame * 0.08, INK)
    gfx.star(x, y, 6.5, game.frame * 0.08, GOLD)
    gfx.circle(x - 1.5, y - 1.5, 1.5, CREAM)
  else
    gfx.circle_o(x, y, r, 0xff5a4a, INK, 1.2)
    gfx.circle(x - 2, y - 2, 2, alpha(0xffffff, 140))
    gfx.line(x, y - 5, x + wob, y - 9, 1.2, 0x5a3a20)
    gfx.ellipse(x + 3 + wob, y - 8, 2.6, 1.4, 0x6fd36f)
  end
end

local function paint_world()
  gfx.vgrad(0, 0, W, 200, 0x3b2a6e, 0xff9a6a)
  gfx.vgrad(0, 200, W, GROUND - 200, 0xff9a6a, 0xffc98a)
  gfx.glow(120, 196, 70, alpha(0xffe0a0, 120))
  gfx.circle(120, 200, 22, 0xfff0c4)
  gfx.poly({-20, 236, 50, 214, 100, 230, 150, 210, 200, 226, 260, 212, 260, 300, -20, 300}, 0xb06a8a)
  gfx.poly({-20, 262, 60, 244, 130, 258, 190, 240, 260, 254, 260, 300, -20, 300}, 0x7a4a7a)
  gfx.vgrad(0, GROUND - 14, W, H - GROUND + 14, 0x5cae58, 0x2f6e3a)
  for i = 0, 23 do
    local gx = (i * 37) % W
    gfx.tri(gx, GROUND - 13, gx + 3, GROUND - 19, gx + 6, GROUND - 13, 0x6cc066)
  end
  -- The orchard canopy across the top.
  gfx.rect(8, 0, 10, 60, 0x5a3a28)
  gfx.rect(222, 0, 10, 60, 0x5a3a28)
  for i = 0, 12 do
    local cx, cy = i * 20, 26 + (i % 3) * 7
    gfx.circle(cx, cy + 4, 20, 0x24603a)
    gfx.circle(cx + 4, cy - 2, 16, 0x2f7a44)
    gfx.circle(cx + 6, cy - 6, 8, 0x3f9452)
  end
end

local function draw_pip()
  local x, y = px, GROUND - 4
  local sq = squash * 0.25
  local bw, bh = BASKET_W * (1 + sq), 18 * (1 - sq * 0.8)
  local look = facing * 1.5
  if hurt_t > 0 and idiv(hurt_t, 4) % 2 == 1 then return end
  if dash_t > 0 then
    for k = 1, 3 do gfx.rrect(x - bw / 2 - vx * k * 2, y - bh, bw, bh, 5, alpha(0xffffff, 60 - k * 15)) end
  end
  gfx.ellipse(x, GROUND + 2, bw * 0.55, 4, alpha(0x1a3a20, 120))
  -- Pip the hedgehog peeks over the basket.
  local hx, hy = x + lean * 3, y - bh - 10 + sq * 6
  for k = -3, 3 do
    gfx.tri(hx + k * 5 - 4, hy - 4, hx + k * 5, hy - 17 + abs(k) * 2, hx + k * 5 + 4, hy - 4, 0x6a4a3a)
  end
  gfx.ellipse_o(hx, hy, 15, 12, 0x8a6450, INK, 1.5)
  gfx.ellipse(hx + look, hy + 3, 10, 8, 0xf2d2b0)
  if game.frame % 180 < 6 then
    gfx.rect(hx - 6 + look, hy, 4, 1, INK)
    gfx.rect(hx + 3 + look, hy, 4, 1, INK)
  else
    gfx.circle(hx - 4 + look, hy + 0.5, 1.8, INK)
    gfx.circle(hx + 5 + look, hy + 0.5, 1.8, INK)
    gfx.pixel(hx - 4 + look, hy - 1, CREAM)
    gfx.pixel(hx + 5 + look, hy - 1, CREAM)
  end
  gfx.circle(hx + look * 2, hy + 5, 1.8, INK)
  if hurt_t > 20 then gfx.text("ouch", hx, hy - 30, 12, 0xff6060, "center", INK) end
  gfx.rrect_o(x - bw / 2, y - bh, bw, bh, 5, 0xc98a4b, INK, 1.5)
  for k = 1, 3 do gfx.rect(x - bw / 2 + 2, y - bh + k * bh / 4, bw - 4, 1, 0x9a6430) end
  gfx.rrect(x - bw / 2 - 2, y - bh - 2, bw + 4, 5, 2, 0xdba060)
  if mult > 1 then
    gfx.rrect(x + bw / 2 - 2, y - bh - 15, 20, 13, 5, GOLD)
    gfx.text("x" .. mult, x + bw / 2 + 8, y - bh - 15, 11, INK, "center")
  end
end

local function draw_hud()
  hearts(lives, 3, 29, 82, 4.3)
  gfx.text(tostring(score), W / 2, 66, 28, CREAM, "center", INK)
  gfx.text("best " .. arcade.best, W - 5, 76, 12, GOLD, "right", INK)
end

function draw()
  backdrop("orchard", paint_world)
  for _, f in ipairs(fruit) do
    if f.type ~= "bee" then
      -- Where it will land: a shadow that sharpens as it falls.
      local k = clamp((f.y - 40) / (GROUND - 60), 0, 1)
      gfx.ellipse(f.x, GROUND + 1, 4 + k * 5, 2 + k, alpha(0x1a3a20, 60 + floor(k * 100)))
    end
  end
  draw_pip()
  for _, f in ipairs(fruit) do
    local wob = 0
    if f.hang > 0 then wob = sin(game.frame * 0.9 + f.phase) * (f.hang < 20 and 2 or 1) end
    draw_fruit(f, f.x + (f.hang > 0 and wob or 0), f.y, wob)
  end
  particles.draw()
  if arcade.state ~= "title" then draw_hud() end
  if arcade.state == "title" then
    arcade.draw_title("Keep", {{"catch the fruit in Pip's basket"}, {"button dashes   three misses end", 0xffc0a0}})
  elseif arcade.state == "over" then
    arcade.draw_over("the basket's full", score)
  end
  arcade.draw_demo(100)
  ui.quit_hint()
end
