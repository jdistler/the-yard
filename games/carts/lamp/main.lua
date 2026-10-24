-- Lamp: carry a lantern through a dark meadow and wake the fallen stars.
-- Walk-up band (CONTROLS.md), the "stick is the verb" shape: walking into a star wakes it.
--
-- Each night some stars have fallen into the grass. Wake them all and they climb back into
-- the sky and draw a constellation. The lantern burns oil. Fireflies and woken stars fill
-- it. A button lifts the lamp: a wide flare that costs oil and scares the moths. Run dry
-- and the light shrinks to an ember for a moment, then relights. Nothing is lost.
--
-- lamp.sav is "best N": the most nights woken in one walk. LAMP_SELFTEST=1 plays itself
-- through the first night, saves, and quits.

local SKY_H, FY0, FY1 = 90, 92, 306
local FH = FY1 - FY0
local INK, CREAM, GOLD = 0x120e26, pal.cream, pal.sun

local SKIES = {
  {"the Kite", {{.5, .1}, {.75, .45}, {.5, .85}, {.25, .45}}, {72, 76, 79, 84}},
  {"the Teacup", {{.2, .3}, {.8, .3}, {.72, .8}, {.28, .8}, {.92, .5}}, {67, 72, 76, 79, 84}},
  {"the Cat", {{.3, .15}, {.38, .45}, {.62, .45}, {.7, .15}, {.66, .85}, {.34, .85}}, {72, 74, 76, 79, 81, 84}},
  {"the Key", {{.15, .5}, {.3, .25}, {.3, .75}, {.6, .5}, {.85, .5}, {.85, .8}}, {60, 64, 67, 72, 76, 79}},
  {"the Fish", {{.15, .5}, {.35, .2}, {.6, .25}, {.72, .5}, {.6, .75}, {.35, .8}, {.9, .5}}, {69, 72, 74, 76, 79, 81, 84}},
  {"the Crown", {{.15, .8}, {.15, .25}, {.33, .55}, {.5, .15}, {.67, .55}, {.85, .25}, {.85, .8}}, {72, 76, 79, 84, 79, 76, 72}},
  {"the Whale", {{.1, .5}, {.25, .25}, {.55, .2}, {.8, .35}, {.85, .6}, {.6, .8}, {.3, .75}, {.95, .2}}, {60, 62, 64, 67, 69, 72, 74, 76}},
  {"the Teapot", {{.3, .2}, {.7, .2}, {.8, .5}, {.7, .85}, {.3, .85}, {.2, .5}, {.05, .35}, {.95, .3}, {.5, .05}}, {67, 69, 72, 74, 76, 79, 81, 84, 86}},
  {"the Dragon", {{.05, .7}, {.18, .45}, {.32, .6}, {.45, .35}, {.58, .55}, {.7, .3}, {.82, .45}, {.92, .2}, {.95, .55}, {.82, .8}}, {60, 64, 67, 69, 72, 76, 79, 81, 84, 88}},
}

local night, stars, woke = 1, {}, 0
local flies, moths, deco = {}, {}, {}
local px, py, vx, vy = W / 2, 220, 0, 0
local oil, radius, step_anim, facing = 100, 40, 0, 1
local flare_t, flare_cd, ember_t, ouch_t, done_t = 0, 0, 0, 0, 0
local done = false

local tune = {
  bpm = 66, steps = 4,
  {"C4 - - - - - - - A3 - - - - - - - F3 - - - - - - - G3 - - - - - - - ", wave = "sine", vol = 0.16, release = 0.6, attack = 0.3, pan = -0.2},
  {"E4 - - - - - - - C4 - - - - - - - A3 - - - - - - - B3 - - - - - - - ", wave = "sine", vol = 0.12, release = 0.6, attack = 0.3, pan = 0.2},
  {". . . . G5 . . . . . . . E5 . . . . . . . C5 . . . . . . . D5 . . . ", wave = "tri", vol = 0.06, release = 0.4, attack = 0.01},
}

local function sky() return SKIES[(night - 1) % #SKIES + 1] end
local function sky_x(i) return 30 + sky()[2][i][1] * (W - 60) end
local function sky_y(i) return 14 + sky()[2][i][2] * (SKY_H - 26) end

local function place_stars()
  stars, woke = {}, 0
  for i = 1, #sky()[2] do
    local x, y, ok
    local tries = 0
    repeat
      x, y = rnd(18, W - 18), rnd(FY0 + 18, FY1 - 18)
      ok = dist(x, y, px, py) > 40
      for j = 1, i - 1 do if ok and dist(x, y, stars[j].x, stars[j].y) < 34 then ok = false end end
      tries = tries + 1
    until ok or tries >= 200
    stars[i] = {x = x, y = y, awake = 0, t = 0}   -- awake: 0 in the grass, 1 climbing, 2 home
  end
end

local function new_fly() return {x = rnd(16, W - 16), y = rnd(FY0 + 16, FY1 - 16), t = rnd() * tau} end

local function make_deco()
  deco = {}
  for i = 1, 48 do deco[i] = {rnd(0, W), rnd(FY0 + 4, FY1 - 2), rndi(0, 5)} end
  unbake("field")
end

local function begin_night(n)
  night, done, oil = n, false, 100
  flare_t, flare_cd, ember_t = 0, 0, 0
  place_stars()
  flies = {new_fly(), new_fly(), new_fly()}
  moths = {}
  for i = 1, max(0, night - 2) do
    if i > 4 then break end
    moths[i] = {x = rnd() < 0.5 and -10 or W + 10, y = rnd(FY0 + 20, FY1 - 20), vx = 0, vy = 0, cool = 60 + (i - 1) * 60}
  end
  make_deco()
  sfx.slide("sine", 300, 600, 0.4, 0.2)
  log(fmt("lamp night %d (%s, %d stars)", night, sky()[1], #stars))
end

local function wake(s)
  s.awake, s.t = 1, 0
  woke = woke + 1
  oil = clamp(oil + 18, 0, 100)
  sfx.note("tri", sky()[3][woke], 0.6, 0.45)
  sfx.note("sine", sky()[3][woke] + 12, 0.4, 0.15)
  particles.burst(s.x, s.y, 22, 2.2, 40, 2, GOLD, "star")
  gfx.shake(1.5)
  log(fmt("lamp star %d/%d", woke, #stars))
end

-- ------------------------------------------------------------------ the built-in walker

function bot()
  if arcade.state == "title" then
    if game.frame % 40 == 5 then input.bot("low") end
    return
  end
  if done then return end
  local tx, ty, bd = px, py, 1e9
  for _, s in ipairs(stars) do
    if s.awake == 0 then
      local d = (s.x - px) ^ 2 + (s.y - py) ^ 2
      if d < bd then bd, tx, ty = d, s.x, s.y end
    end
  end
  if oil < 35 then
    for _, f in pairs(flies) do
      local d = (f.x - px) ^ 2 + (f.y - py) ^ 2
      if d < bd * 1.5 then bd, tx, ty = d, f.x, f.y end
    end
  end
  if tx < px - 2 then input.bot("left") end
  if tx > px + 2 then input.bot("right") end
  if ty < py - 2 then input.bot("up") end
  if ty > py + 2 then input.bot("down") end
  for _, m in ipairs(moths) do
    if abs(m.x - px) < 30 and abs(m.y - py) < 30 and flare_cd == 0 and oil > 30 then input.bot("low") end
  end
end

-- ------------------------------------------------------------------ the rules

local function walk()
  local dx, dy = input.dir()
  local maxv = (game.fast and 2.4 or 1.8) * (ember_t > 0 and 0.6 or 1)
  vx, vy = approach(vx, dx * maxv, 0.25), approach(vy, dy * maxv, 0.25)
  px, py = clamp(px + vx, 8, W - 8), clamp(py + vy, FY0 + 10, FY1 - 8)
  if dx ~= 0 then facing = dx end
  if dx ~= 0 or dy ~= 0 then step_anim = step_anim + 0.3 end
  -- Oil and the light it gives.
  oil = oil - (game.fast and 0.07 or 0.05)
  if input.action() and flare_cd == 0 and oil > 8 and ember_t == 0 then
    flare_t, flare_cd, oil = 40, 70, oil - 12
    sfx.slide("sine", 400, 900, 0.35, 0.3)
    sfx.noise(0.2, 0.08, 12000)
    particles.burst(px, py - 8, 16, 2.5, 30, 2, alpha(0xffc060, 220), "glow")
    for _, m in ipairs(moths) do
      local ax, ay = m.x - px, m.y - py
      local d = sqrt(ax * ax + ay * ay) + 1
      m.vx, m.vy, m.cool = ax / d * 4, ay / d * 4, 120
    end
  end
  if flare_t > 0 then flare_t = flare_t - 1 end
  if flare_cd > 0 then flare_cd = flare_cd - 1 end
  if oil <= 0 and ember_t == 0 then
    oil, ember_t = 0, 150
    sfx.slide("tri", 400, 100, 0.6, 0.3)
    log("lamp out")
  end
  if ember_t > 0 then
    ember_t = ember_t - 1
    if ember_t == 0 then
      oil = 60
      sfx.slide("tri", 200, 600, 0.3, 0.25)
    end
  end
  local target = ember_t > 0 and 14 or 28 + oil * 0.5 + (flare_t > 0 and 50 * flare_t / 40 or 0)
  radius = approach(radius, target, 0.15)
  -- Stars.
  for i, s in ipairs(stars) do
    if s.awake == 0 then
      if dist(s.x, s.y, px, py - 2) < 13 then wake(s) end
    elseif s.awake == 1 then
      s.t = s.t + 0.025
      if s.t >= 1 then
        s.awake = 2
        sfx.tone("sine", 1800, 0.08, 0.12)
        particles.burst(sky_x(i), sky_y(i), 10, 1.5, 24, 1.5, CREAM, "star")
      end
    end
  end
  local home = 0
  for _, s in ipairs(stars) do if s.awake == 2 then home = home + 1 end end
  if home == #stars then
    done, done_t = true, 0
    sfx.arp("tri", {60, 64, 67, 72, 76, 79}, 0.09, 0.4)
    arcade.score(night)
    arcade.save()
    log(fmt("lamp night %d done", night))
  end
  -- Fireflies wander; touching one fills the lamp.
  for i = 1, 4 do
    local f = flies[i]
    if not f then
      if rndi(0, 300) == 0 then flies[i] = new_fly() end
    else
      f.t = f.t + 0.03
      f.x = clamp(f.x + cos(f.t * 1.3 + i - 1) * 0.6, 8, W - 8)
      f.y = clamp(f.y + sin(f.t * 0.9 + (i - 1) * 2) * 0.5, FY0 + 8, FY1 - 8)
      if dist(f.x, f.y, px, py) < 12 then
        flies[i] = nil
        oil = clamp(oil + 30, 0, 100)
        sfx.note("sine", 88, 0.12, 0.25)
        sfx.note("sine", 93, 0.12, 0.15)
        particles.burst(f.x, f.y, 10, 1.6, 24, 1.5, 0xe8ff90, "glow")
      end
    end
  end
  -- Moths drift toward the light and nibble the oil.
  for i, m in ipairs(moths) do
    if m.cool > 0 then
      m.cool = m.cool - 1
      m.x, m.y = m.x + m.vx, m.y + m.vy
      m.vx, m.vy = m.vx * 0.97, m.vy * 0.97
    else
      local ax, ay = px - m.x, py - 10 - m.y
      local d = sqrt(ax * ax + ay * ay) + 1
      m.vx = approach(m.vx, ax / d * 0.9 + sin(game.frame * 0.1 + i - 1) * 0.6, 0.05)
      m.vy = approach(m.vy, ay / d * 0.9 + cos(game.frame * 0.13 + i - 1) * 0.6, 0.05)
      m.x, m.y = m.x + m.vx, m.y + m.vy
      if d < 10 then
        oil = clamp(oil - 20, 0, 100)
        m.cool, m.vx, m.vy = 150, -ax / d * 3, -ay / d * 3
        ouch_t = 50
        sfx.noise(0.2, 0.2, 3000)
        gfx.shake(2)
      end
    end
    m.x, m.y = clamp(m.x, -12, W + 12), clamp(m.y, FY0, FY1)
  end
  if ouch_t > 0 then ouch_t = ouch_t - 1 end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.36)
  music.play(tune)
  make_deco()
  arcade.setup({key = "best", best_label = "best %d nights", demo_starts = true,
    start = function() px, py = W / 2, 220 begin_night(1) end})
  if game.selftest then game.autoplay = true end
end

function update()
  if arcade.update() ~= "play" then return end
  if not done then
    walk()
  else
    done_t = done_t + 1
    if game.selftest then
      assert(save.get("best") == arcade.best, "lamp self-test: the save did not stick")
      game.quit()
    end
    if done_t > 170 then
      if arcade.demo and night >= 2 then
        arcade.demo, game.demo = false, false
        input.bot_clear()
        arcade.to_title()
      else
        begin_night(night + 1)
      end
    end
  end
  if game.selftest and game.frame > 4000 then error("lamp self-test: no night woken in 4000 frames") end
end

-- ------------------------------------------------------------------ pictures

local function draw_sky()
  local glow = done and clamp(done_t / 40, 0, 1) or 0
  gfx.vgrad(0, 0, W, SKY_H, mix(0x05061a, 0x1a2058, glow), mix(0x18163c, 0x4a3a7a, glow))
  for i = 0, 39 do
    gfx.pixel((i * 53 + 11) % W, (i * 29 + 7) % (SKY_H - 4), alpha(0xc0c8ff, 60 + floor(40 * sin(game.frame * 0.04 + i))))
  end
  if arcade.state == "title" then return end
  for i = 2, #stars do
    local both = stars[i].awake == 2 and stars[i - 1].awake == 2
    if both or not done then
      gfx.line(sky_x(i - 1), sky_y(i - 1), sky_x(i), sky_y(i), both and 1.4 or 1, both and alpha(0xffe8a0, 200) or alpha(0x6a6aa0, 50))
    end
  end
  for i, s in ipairs(stars) do
    local x, y = sky_x(i), sky_y(i)
    if s.awake == 2 then
      gfx.glow(x, y, 10 + glow * 6, alpha(0xffd060, 160))
      gfx.star(x, y, 4.5, game.frame * 0.02 + i, CREAM)
    else
      gfx.ring(x, y, 3.5, 1, alpha(0x8a8ac8, 120))
    end
  end
  if done then
    local k = ease.out_back(clamp(done_t / 30, 0, 1))
    gfx.text(sky()[1] .. " is awake", W / 2, SKY_H - 18 * k, 14, GOLD, "center", INK)
  end
end

local function paint_field()
  gfx.vgrad(0, FY0, W, FH, 0x3a6a4a, 0x2a5a3c)
  for i, d in ipairs(deco) do
    local x, y, k = d[1], d[2], d[3]
    if k <= 1 then
      gfx.tri(x - 3, y, x, y - 7, x + 1, y, 0x5a9a5a)
      gfx.tri(x, y, x + 3, y - 6, x + 4, y, 0x4a8a4a)
    elseif k == 2 then
      gfx.circle(x, y, 2, i % 2 == 0 and 0xff9ac8 or 0xfff09a)
      gfx.pixel(x, y, 0xffffff)
    elseif k == 3 then
      gfx.ellipse(x, y, 7, 4, 0x6a7a7a)
      gfx.ellipse(x - 1, y - 1, 5, 2.5, 0x8a9a9a)
    else
      gfx.circle(x, y - 6, 9, 0x24503a)
      gfx.rect(x - 1, y - 2, 3, 6, 0x4a3a2a)
    end
  end
end

local function draw_wren()
  local x, y = px, py
  local bob = sin(step_anim) * 1.2
  local lx, ly = x + facing * 7, y - 8 + bob * 0.5
  gfx.ellipse(x, y + 7, 7, 2.5, alpha(0, 90))
  gfx.tri(x - 7, y + 7, x, y - 7 + bob, x + 7, y + 7, 0x2a3a8a)
  gfx.tri(x - 5, y + 7, x, y - 3 + bob, x + 5, y + 7, 0x3a4aa8)
  gfx.circle_o(x, y - 7 + bob, 5, 0xf2d2b0, INK, 1)
  gfx.ellipse(x, y - 10 + bob, 6, 3.5, 0x2a3a8a)
  gfx.circle(x + facing * 2, y - 6 + bob, 0.9, INK)
  gfx.line(x + facing * 3, y - 2, lx, ly - 4, 1, 0x8a7050)
  gfx.rrect_o(lx - 3, ly - 4, 6, 8, 1.5, 0xffd27a, INK, 1)
  gfx.rect(lx - 1, ly - 2, 3, 4, ember_t > 0 and 0xa04020 or 0xfff6c8)
end

function draw()
  local playing = arcade.state ~= "title"
  draw_sky()
  gfx.rect(0, SKY_H, W, FY0 - SKY_H, 0x0a0818)
  gfx.clip(0, FY0, W, FH)
  gfx.blit(bake("field", W, H, paint_field), 0, 0)
  if playing then
    for _, s in ipairs(stars) do
      if s.awake == 0 then
        gfx.star(s.x, s.y, 6, 0.3, 0x9aa0c0)
        gfx.star(s.x, s.y, 4, 0.3, 0xd8dcf0)
      end
    end
  end
  gfx.clip()
  if playing then
    for _, f in pairs(flies) do gfx.circle(f.x, f.y, 1.5, 0xe8ff90) end
    for i, m in ipairs(moths) do
      local wing = abs(sin(game.frame * 0.6 + i - 1)) * 4
      gfx.ellipse(m.x - 3, m.y, 3, 1 + wing, 0xb8a890)
      gfx.ellipse(m.x + 3, m.y, 3, 1 + wing, 0xb8a890)
      gfx.ellipse(m.x, m.y, 1.5, 3, 0x6a5a4a)
    end
    draw_wren()
  end
  -- The dark: everything in the meadow is lit only by the lamp and what glows.
  light.begin(0, FY0, W, FH, 0.07)
  if not playing then
    light.add(W / 2 + sin(game.frame * 0.02) * 40, 220 + cos(game.frame * 0.03) * 30, 90, 1.1)
  else
    light.add(px + facing * 7, py - 8, radius, 1.15)
    for i, f in pairs(flies) do light.add(f.x, f.y, 14, 0.5 + 0.3 * sin(game.frame * 0.2 + i - 1)) end
    for _, s in ipairs(stars) do
      if s.awake == 1 then light.add(s.x, s.y + (FY0 - s.y) * s.t, 40 * (1 - s.t) + 10, 0.9) end
    end
    if done then light.fill(clamp(done_t / 60, 0, 0.6)) end
  end
  light.apply(0x00000e)
  if playing then
    -- Sleeping stars breathe through the dark, so they can be found.
    for i, s in ipairs(stars) do
      if s.awake == 0 then
        local b = 0.5 + 0.5 * sin(game.frame * 0.05 + (i - 1) * 1.3)
        gfx.glow(s.x, s.y, 9 + b * 4, alpha(0x9aa8ff, floor(40 + b * 60)))
      elseif s.awake == 1 then
        local k = ease.in_out(s.t)
        local x, y = lerp(s.x, sky_x(i), k), lerp(s.y, sky_y(i), k)
        gfx.glow(x, y, 16, alpha(0xffd060, 220))
        gfx.star(x, y, 5, game.frame * 0.2, CREAM)
        if game.frame % 2 == 0 then particles.spawn(x, y, rnd(-0.3, 0.3), 0.4, 24, 1.5, alpha(0xffe090, 200), "glow") end
      end
    end
    for i, f in pairs(flies) do gfx.glow(f.x, f.y, 6, alpha(0xd8ff70, 120 + floor(80 * sin(game.frame * 0.2 + i - 1)))) end
    gfx.glow(px + facing * 7, py - 8, ember_t > 0 and 8 or 16, ember_t > 0 and alpha(0xff5020, 150) or alpha(0xffb040, 140))
  end
  particles.draw()
  -- Under the meadow: the night, the oil, the stars.
  gfx.rect(0, FY1, W, H - FY1, 0x0a0818)
  if playing then
    gfx.text("night " .. night, 4, FY1 + 1, 12, CREAM, "left", INK)
    meter(58, FY1 + 4, 80, 6, oil / 100, oil < 25 and 0xff7040 or 0xffc040)
    gfx.star(148, FY1 + 7, 4, 0, GOLD)
    gfx.text(woke .. "/" .. #stars, 155, FY1 + 1, 12, GOLD, "left", INK)
    gfx.text("best " .. arcade.best, W - 4, FY1 + 1, 12, 0xa0a0d0, "right", INK)
  else
    ui.title("Lamp", 8, 46, GOLD, INK)
    gfx.text("wake the stars that fell", W / 2, 62, 13, 0xc0c8ff, "center")
    ui.panel(24, 140, W - 48, 78, alpha(0x0a0818, 200))
    gfx.text("walk into a star to wake it", W / 2, 146, 12, CREAM, "center")
    gfx.text("fireflies fill the lamp", W / 2, 160, 12, 0xd8ff90, "center")
    gfx.text("button: lift the lamp", W / 2, 174, 12, 0xffc080, "center")
    ui.prompt("press to start", 192, 18)
    if arcade.best > 0 then gfx.text("best " .. plural(arcade.best, "night"), W / 2, 228, 13, GOLD, "center", INK) end
    gfx.text("hold 1P+2P to leave", W / 2, H - 13, 11, alpha(0x8080b0, 200), "center")
  end
  if ouch_t > 0 then gfx.text("a moth!", px, py - 30, 12, 0xffa080, "center", INK) end
  if ember_t > 0 then gfx.text("the lamp is out... it will relight", W / 2, FY0 + 6, 12, 0xffb080, "center", INK) end
  arcade.draw_demo(FY0 + 20)
end
