-- Starship: split-hands space rescue (ALL ages). The cabinet has ONE stick and ONE cluster, so "co-op"
-- here means two people sharing the one deck, the split-hands shape from CONTROLS.md: the Pilot holds the
-- stick and flies, the Co-Pilot holds LOW (TL and TR do the same) and fires the Star-Bubble Beam. Alone, a
-- player does both, and the stick alone still finishes every world (the ship scoops stars by touch; a
-- rock only bumps it). The beam pops rocks and reaches stars the ship cannot.
-- A voyage is three worlds with one score; after world 3 the next voyage starts at world 1 on 0 points.
-- Zero harsh game over; rocket.sav keeps "best N" (best voyage) and "voyages N"; quit() saves too.

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, ROSE = 0xf47eb2,
  CYAN = 0x7fe8ff, PURPLE = 0x8a5cf5, MINT = 0x78dcc8, WHITE = 0xfffcf8,
  ORANGE = 0xffa84c,
}

local WORLDS = {
  {name = "Pastel Nebula", bg1 = 0x1c1444, bg2 = 0x48266c, planet = C.ROSE},
  {name = "Candy Ring Planet", bg1 = 0x16244c, bg2 = 0x2e4a7c, planet = C.MINT},
  {name = "Starlight Moon", bg1 = 0x141838, bg2 = 0x2a245c, planet = C.GOLD},
}

local space_bed = {bpm = 128, steps = 4,
  {"C5 . E5 . G5 . B5 . C6 . G5 . E5 . . . A5 . G5 . E5 . D5 . E5 . G5 . C5 . . . ",
   wave = "tri", vol = 0.16, release = 0.14, attack = 0.008, pan = -0.2},
  {"C3 . . C3 G2 . . G2 A2 . . A2 F2 . G2 . ", wave = "sine", vol = 0.22, release = 0.18, attack = 0.01},
  {"K . H . S . H . K . H . S . H H ", wave = "noise", vol = 0.08, release = 0.04, pan = 0.2}}
local land_bed = {bpm = 124, steps = 2,
  {"C5 . E5 . G5 . C6 - A5 . G5 . E5 . C6 - ", wave = "tri", vol = 0.20, release = 0.24, attack = 0.008},
  {"C3 - G2 - A2 - E2 - F2 - C3 - G2 - C3 - ", wave = "sine", vol = 0.22, release = 0.24, attack = 0.01}}

local S = {
  phase = "fly", world = 1, best = 0, voyages = 0, score = 0, saved = 0,
  px = 192, py = 384, vx = 0, wobble = 0,
  dist = 0, goal = 1500,
  stars = {}, rocks = {}, beams = {}, bg_stars = {},
  cool = 0, land_t = 0, saw_release = false,
  react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 100 end
local function add_score(n)
  S.score = min(S.score + n, 999999)
  if S.score > S.best then S.best = S.score end
end

local function setup_world(w)
  S.phase, S.world, S.dist, S.goal = "fly", w, 0, 1500 + (w - 1) * 300
  S.stars, S.rocks, S.beams = {}, {}, {}
  S.land_t = 0
  S.saw_release = false
  if w == 1 then S.score, S.saved = 0, 0 end
  log("rocket world " .. w)
  music.play(space_bed)
  react_to(WORLDS[w].name .. "! Stick flies, button fires. Team up or fly solo!")
end

local function fire_beam()
  log("rocket beam")
  sfx.slide("sine", 620, 1280, 0.1, 0.2)
  S.beams[#S.beams + 1] = {x = S.px, y = S.py - 24, vy = -7.5, life = 60}
  particles.burst(S.px, S.py - 24, 6, 1.5, 14, 2, C.CYAN, "star")
end

function bot()
  if S.phase == "land" then
    if S.land_t > 80 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  local tx = 192
  for _, st in ipairs(S.stars) do
    if st.y > 40 and st.y < S.py then tx = st.x break end
  end
  if tx < S.px - 10 then input.bot("left") elseif tx > S.px + 10 then input.bot("right") end
  if game.frame % 16 == 0 then input.bot("low") end
end

-- Leaving (1P+2P): keep the best voyage score.
function quit()
  save.set("best", floor(S.best))
  save.set("voyages", floor(S.voyages))
  save.write()
end

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 999999)
  S.voyages = clamp(save.get("voyages", 0), 0, 100000)
  for i = 1, 36 do S.bg_stars[i] = {rnd(8, W - 8), rnd(10, H - 40), rnd(0.8, 2.4)} end
  log("rocket best " .. S.best)
  setup_world(1)
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.cool > 0 then S.cool = S.cool - 1 end
  if S.wobble > 0 then S.wobble = S.wobble - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  for _, bs in ipairs(S.bg_stars) do
    bs[2] = bs[2] + bs[3] * (S.phase == "fly" and 1.2 or 0.2)
    if bs[2] > H - 32 then bs[2], bs[1] = 0, rnd(8, W - 8) end
  end

  if S.phase == "fly" then
    S.px = clamp(S.px + mx * 3.0, 32, W - 32)
    S.py = clamp(S.py + my * 2.4, 240, 434)
    S.dist = S.dist + 2.2

    -- Spawn floating lost stars & space-kitties + goofy purple asteroids!
    if game.frame % 48 == 0 then
      S.stars[#S.stars + 1] = {x = rnd(40, W - 40), y = 58, vy = 1.6, kitty = (game.frame % 144 == 0)}
    end
    if game.frame % 70 == 0 then
      S.rocks[#S.rocks + 1] = {x = rnd(44, W - 44), y = 58, vy = 1.85, r = 16}
    end

    if S.saw_release and ((pressed and S.cool <= 8) or (held and S.cool == 0)) then
      fire_beam()
      S.cool = 18
    end

    for _, b in ipairs(S.beams) do
      b.y, b.life = b.y + b.vy, b.life - 1
      for _, rk in ipairs(S.rocks) do
        if not rk.gone and dist(b.x, b.y, rk.x, rk.y) < rk.r + 14 then
          rk.gone, b.gone = true, true
          add_score(100)
          log("rocket pop")
          sfx.arp("tri", {76, 84}, 0.05, 0.24)
          particles.burst(rk.x, rk.y, 18, 3, 28, 3, C.PURPLE, "star")
          particles.text(rk.x, rk.y - 12, C.GOLD, "POP!")
          react_to("Great shot! Asteroid popped into confetti!")
          break
        end
      end
      if not b.gone then
        for _, st in ipairs(S.stars) do
          if not st.gone and dist(b.x, b.y, st.x, st.y) < 26 then
            st.gone, b.gone = true, true
            S.saved = S.saved + 1
            add_score(st.kitty and 200 or 100)
            sfx.arp("sine", {79, 84, 88}, 0.05, 0.24)
            particles.burst(st.x, st.y, 16, 2.5, 28, 3, st.kitty and C.ROSE or C.GOLD, "heart")
            react_to(st.kitty and "Caught a space-kitty! Yay!" or "Star-Beam caught a star!")
            break
          end
        end
      end
      if b.life <= 0 or b.y < 0 then b.gone = true end
    end
    sweep(S.beams, function(b) return not b.gone end)

    for _, st in ipairs(S.stars) do
      st.y = st.y + st.vy
      if not st.gone and dist(st.x, st.y, S.px, S.py) < 28 then
        st.gone = true
        S.saved = S.saved + 1
        add_score(st.kitty and 200 or 100)
        sfx.arp("sine", {79, 84, 88}, 0.05, 0.24)
        particles.burst(st.x, st.y, 16, 2.5, 28, 3, st.kitty and C.ROSE or C.GOLD, "heart")
        react_to(st.kitty and "Space-kitty aboard!" or "Caught a shooting star!")
      elseif st.y > H - 32 then st.gone = true end
    end
    sweep(S.stars, function(st) return not st.gone end)

    for _, rk in ipairs(S.rocks) do
      rk.y = rk.y + rk.vy
      if not rk.gone and dist(rk.x, rk.y, S.px, S.py) < rk.r + 16 then
        rk.gone = true
        S.wobble = 26
        sfx.slide("sine", 340, 200, 0.16, 0.2)
        particles.burst(rk.x, rk.y, 12, 2.2, 22, 2.5, C.PURPLE, "dot")
        react_to("Boing! Co-Pilot, blast those rocks!")
      elseif rk.y > H - 32 then rk.gone = true end
    end
    sweep(S.rocks, function(rk) return not rk.gone end)

    if S.dist >= S.goal then
      S.phase, S.land_t = "land", 0
      add_score(400)
      if S.world == #WORLDS then S.voyages = S.voyages + 1 end
      save.set("best", floor(S.best))
      save.set("voyages", floor(S.voyages))
      save.write()
      log("rocket land " .. S.world)
      music.play(land_bed)
      sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
      for i = 1, 34 do
        particles.spawn(W / 2 + rnd(-110, 110), 220, rnd(-3, 3), rnd(-4.5, -1), 85, rnd(3, 5),
          i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.CYAN, "star", 0.08, 0.99, 0.1)
      end
      react_to("TOUCHDOWN on " .. WORLDS[S.world].name .. "! Team victory!")
    end
  elseif S.phase == "land" then
    S.land_t = S.land_t + 1
    S.px = approach(S.px, W / 2, 0.08)
    S.py = approach(S.py, 326, 0.08)
    if (pressed and S.saw_release and S.land_t > 70) or S.land_t > 240 then
      snd.ok()
      setup_world(S.world == #WORLDS and 1 or S.world + 1)
    end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  local WD = WORLDS[S.world]
  backdrop("rocket_bg" .. S.world, function() gfx.vgrad(0, 0, W, H - 32, WD.bg1, WD.bg2) end)
  for _, bs in ipairs(S.bg_stars) do
    gfx.circle(bs[1], bs[2], bs[3], alpha(C.WHITE, 180))
  end

  if S.phase == "land" then
    -- Planet surface + Team Flag!
    gfx.circle_o(W / 2, 540, 210, WD.planet, C.INK, 3)
    gfx.line(W / 2 + 56, 348, W / 2 + 56, 286, 4, C.CREAM)
    gfx.rrect_o(W / 2 + 56, 286, 44, 26, 4, C.GOLD, C.INK, 2)
    gfx.star(W / 2 + 78, 299, 8, game.frame * 0.06, C.ROSE)
  end

  for _, st in ipairs(S.stars) do
    if st.kitty then
      gfx.glow(st.x, st.y, 24, alpha(C.ROSE, 150))
      soap(st.x, st.y, 18, C.CYAN)
      gfx.circle_o(st.x, st.y, 10, C.CREAM, C.INK, 1.8)
      gfx.circle(st.x - 3, st.y - 1, 1.6, C.INK)
      gfx.circle(st.x + 3, st.y - 1, 1.6, C.INK)
    else
      gfx.glow(st.x, st.y, 18, alpha(C.GOLD, 140))
      gfx.star(st.x, st.y, 11, game.frame * 0.08, C.GOLD)
    end
  end
  for _, rk in ipairs(S.rocks) do
    gfx.circle_o(rk.x, rk.y, rk.r, C.PURPLE, C.INK, 2.2)
    gfx.circle(rk.x - 4, rk.y - 4, 4, alpha(C.WHITE, 90))
    -- Goofy eyes on the asteroid!
    gfx.circle(rk.x - 4, rk.y + 1, 2, C.WHITE)
    gfx.circle(rk.x + 4, rk.y + 1, 2, C.WHITE)
  end
  for _, b in ipairs(S.beams) do
    gfx.glow(b.x, b.y, 16, alpha(C.CYAN, 170))
    soap(b.x, b.y, 10, C.CYAN)
    gfx.star(b.x, b.y, 6, game.frame * 0.2, C.GOLD)
  end

  -- Rainbow Starship!
  local wx = S.wobble > 0 and sin(S.wobble * 0.8) * 6 or 0
  local x, y = S.px + wx, S.py
  if S.phase == "fly" then
    gfx.glow(x, y + 26, 26, alpha(C.ORANGE, 160))
    gfx.tri(x - 8, y + 18, x + 8, y + 18, x, y + 32 + sin(game.frame * 0.6) * 5, C.GOLD)
  end
  toon(function()
    toon.tri(x - 16, y + 14, x - 28, y + 24, x - 12, y - 4, C.ROSE)
    toon.tri(x + 16, y + 14, x + 28, y + 24, x + 12, y - 4, C.ROSE)
    toon.ellipse(x, y, 17, 24, C.CREAM)
    toon.tri(x - 14, y - 10, x + 14, y - 10, x, y - 34, C.CYAN)
  end, 2.2, C.INK)
  gfx.circle_o(x, y - 2, 8, C.CYAN, C.INK, 1.8)
  gfx.circle(x - 2, y - 4, 2.2, alpha(C.WHITE, 210))

  -- Top HUD.
  gfx.rrect_o(8, 8, 132, 26, 9, C.CREAM, C.INK, 2)
  gfx.text("SAVED: " .. S.saved, 74, 12, 13, C.INK, "center")
  gfx.rrect_o(W - 124, 8, 116, 26, 9, C.CREAM, C.INK, 2)
  gfx.text("PTS " .. S.score, W - 66, 12, 13, C.INK, "center")
  meter(80, 42, W - 160, 10, clamp(S.dist / S.goal, 0, 1), C.GOLD)

  if S.phase == "land" then
    gfx.rrect_o(40, 134, W - 80, 96, 14, C.CREAM, C.INK, 3)
    gfx.text(S.world == #WORLDS and "VOYAGE COMPLETE!" or "MISSION COMPLETE!", W / 2, 148, 24, C.GOLD, "center", C.INK)
    gfx.text("SCORE: " .. S.score .. "   SAVED: " .. S.saved, W / 2, 188, 14, C.PURPLE, "center")
    gfx.text(S.world == #WORLDS and "Next crew starts a new voyage!" or "Press to fly on!", W / 2, 210, 12, C.INK, "center")
  end

  particles.draw()
  local line = S.react_left > 0 and S.react or "Stick flies the ship! Button fires Star-Beam!"
  if input.down("1p") and input.down("2p") then line = "Your best score will stay!" end
  ui.band(line)
end
