-- Tower: a kid-friendly ladder-and-barrels rescue (5+). Walk-up band (CONTROLS.md).
-- The stick walks, and up/down climbs a ladder you stand at (4-way, magnet-snap). LOW, TL and TR all do
-- the one verb: jump. A Star Swatter on the way smashes barrels for a few seconds, no button needed.
-- Three towers make one run: a run scores from 0, three hearts per tower, a new floor mends a heart,
-- and losing the hearts restarts the same tower. After tower 3 the run ends and the next player starts at
-- tower 1 on a score of 0. tower.sav keeps "best N" (best run) and "rescues N"; quit() saves too.

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, RED = 0xe84855,
  BLUE = 0x4a82cc, CYAN = 0x7fe8ff, BROWN = 0xa86438, WOOD = 0xc8844c,
  PURPLE = 0x8a5cf5, ROSE = 0xe86b9a, SKIN = 0xf4c7a1, WHITE = 0xfffcf8,
  GREEN = 0x62cc6a,
}

-- 4 horizontal floors + top rescue perch!
local FLOORS = {442, 348, 254, 160}
local LADDERS = {
  {x = 304, bot = 1, top = 2},
  {x = 84, bot = 2, top = 3},
  {x = 296, bot = 3, top = 4},
}
local TOWER_THEMES = {
  {name = "Girder Tower", bg1 = 0x241c44, bg2 = 0x3c2860, beam = 0xe84855, lad = 0x7fe8ff},
  {name = "Vine Treehouse", bg1 = 0x2a5444, bg2 = 0x1c3a32, beam = 0xc8844c, lad = 0x78e080},
  {name = "Castle Sky Spire", bg1 = 0x3a2c6e, bg2 = 0x6048a0, beam = 0xf2c14e, lad = 0xfff6ea},
}

local climb_bed = {bpm = 132, steps = 4,
  {"C5 . D5 . E5 . G5 . E5 . D5 . C5 . . . G4 . A4 . B4 . D5 . C5 . B4 . G4 . . . ",
   wave = "square", vol = 0.11, release = 0.05, attack = 0.004, duty = 0.25, pan = -0.2},
  {"C3 . G2 . C3 . G2 . A2 . E2 . A2 . E2 . F2 . C3 . G2 . D3 . C3 . G2 . C3 . . . ",
   wave = "tri", vol = 0.24, release = 0.06, attack = 0.004},
  {"K . H . S . H . K . H . S . H . ", wave = "noise", vol = 0.09, release = 0.04, pan = 0.2}}
local win_bed = {bpm = 132, steps = 2,
  {"C5 . E5 . G5 . C6 - A5 . G5 . E5 . C6 - ", wave = "tri", vol = 0.20, release = 0.22, attack = 0.008},
  {"C3 - G2 - A2 - E2 - F2 - C3 - G2 - C3 - ", wave = "sine", vol = 0.22, release = 0.24, attack = 0.01}}

local NTOWERS = #TOWER_THEMES

local S = {
  phase = "play", level = 1, best = 0, rescues = 0, score = 0, hurts = 0, hurt_cool = 0,
  px = 68, py = FLOORS[1], vy = 0, floor_i = 1, on_ground = true, climbing = false,
  face = 1, walk_t = 0, swat_t = 0,
  barrels = {}, swatter = nil, barrel_cool = 90,
  win_t = 0, restart_t = 0, saw_release = false, react = "", react_left = 0, goodbye = false,
}

local function save_all()
  save.set("best", floor(S.best))
  save.set("rescues", floor(S.rescues))
  save.write()
end

local function react_to(s) S.react, S.react_left = s, 110 end
local function add_score(n)
  S.score = min(S.score + n, 999999)
  if S.score > S.best then S.best = S.score end
end

local function setup_tower(lvl)
  S.phase, S.level, S.hurts, S.hurt_cool = "play", lvl, 0, 0
  S.px, S.py, S.vy, S.floor_i, S.on_ground, S.climbing, S.face = 68, FLOORS[1], 0, 1, true, false, 1
  S.swat_t, S.barrels, S.barrel_cool = 0, {}, 170
  S.saw_release = false
  S.swatter = {x = 188, y = FLOORS[2] - 26, gone = false}
  S.win_t, S.restart_t = 0, 0
  log("tower level " .. lvl)
  music.play(climb_bed)
  local th = TOWER_THEMES[(lvl - 1) % #TOWER_THEMES + 1]
  react_to(th.name .. "! Climb up and rescue your friend!")
end

local function near_ladder()
  for _, l in ipairs(LADDERS) do
    if abs(S.px - l.x) < 22 and S.py <= FLOORS[l.bot] + 6 and S.py >= FLOORS[l.top] - 6 then
      return l
    end
  end
  return nil
end

local function hurt_hero()
  if S.hurt_cool > 0 or S.phase ~= "play" then return end
  S.hurts = S.hurts + 1
  S.hurt_cool = 90
  log("tower hurt " .. S.hurts)
  sfx.slide("tri", 320, 120, 0.25, 0.34)
  gfx.shake(4)
  particles.burst(S.px, S.py - 12, 14, 2.5, 26, 3, C.PURPLE, "ring")
  if S.hurts >= 3 then
    S.phase, S.restart_t = "restart", 0
    save_all()
    react_to("Whoa! Let's climb this tower again!")
  else
    react_to("Hop over the barrels!")
  end
end

function bot()
  if S.phase == "win" then
    if S.win_t > 80 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase ~= "play" then return end
  -- Jump if a barrel is close on our floor!
  for _, b in ipairs(S.barrels) do
    if b.fl == S.floor_i and abs(b.x - S.px) < 42 and S.on_ground and not S.climbing then
      input.bot("low")
    end
  end
  if S.floor_i < 4 then
    local l = LADDERS[S.floor_i]
    if abs(S.px - l.x) < 10 then
      input.bot("up")
    else
      input.bot(l.x < S.px and "left" or "right")
    end
  else
    -- Walk to the rescued friend at top left!
    if S.px > 120 then input.bot("left") end
  end
end

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 999999)
  S.rescues = clamp(save.get("rescues", 0), 0, 100000)
  log("tower best " .. S.best)
  setup_tower(1)
end

-- Leaving (1P+2P): keep the best score and the rescues.
function quit() save_all() end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.swat_t > 0 then S.swat_t = S.swat_t - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "play" then
    local lad = near_ladder()
    if lad and my ~= 0 and (S.on_ground or S.climbing) then
      S.climbing = true
      S.on_ground = false
      S.vy = 0
      S.px = approach(S.px, lad.x, 0.35)
      S.py = clamp(S.py + my * 2.5, FLOORS[lad.top], FLOORS[lad.bot])
      S.walk_t = S.walk_t + 1
      if S.py <= FLOORS[lad.top] + 2 and my < 0 then
        S.py, S.floor_i, S.climbing, S.on_ground = FLOORS[lad.top], lad.top, false, true
        add_score(50)
        if S.hurts > 0 then
          S.hurts = S.hurts - 1
          particles.burst(S.px, S.py - 20, 8, 1.8, 24, 3, C.ROSE, "heart")
        end
      elseif S.py >= FLOORS[lad.bot] - 2 and my > 0 then
        S.py, S.floor_i, S.climbing, S.on_ground = FLOORS[lad.bot], lad.bot, false, true
      end
    else
      if S.climbing and mx ~= 0 and (abs(S.py - FLOORS[S.floor_i]) < 12) then
        S.climbing, S.on_ground, S.py = false, true, FLOORS[S.floor_i]
      end
      if not S.climbing then
        if mx ~= 0 then
          S.face = mx
          S.px = clamp(S.px + mx * 2.5, 24, W - 24)
          S.walk_t = S.walk_t + 1
        end
        if pressed and S.saw_release and S.on_ground then
          S.vy = -7.2
          S.on_ground = false
          log("tower jump")
          sfx.slide("sine", 360, 740, 0.14, 0.22)
        end
        if not S.on_ground then
          S.vy = S.vy + 0.34
          S.py = S.py + S.vy
          if S.py >= FLOORS[S.floor_i] then
            S.py, S.vy, S.on_ground = FLOORS[S.floor_i], 0, true
          end
        end
      end
    end

    -- Star Swatter pickup!
    if S.swatter and not S.swatter.gone and dist(S.px, S.py - 16, S.swatter.x, S.swatter.y) < 28 then
      S.swatter.gone = true
      S.swat_t = 360
      add_score(150)
      sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.3)
      particles.burst(S.swatter.x, S.swatter.y, 20, 3, 28, 3, C.GOLD, "star")
      react_to("STAR SWATTER! Smash the barrels!")
    end

    -- Spawn rolling barrels from the goofy giant ape at top-left!
    S.barrel_cool = S.barrel_cool - 1
    if S.barrel_cool <= 0 then
      S.barrel_cool = max(100, 190 - S.level * 28)
      S.barrels[#S.barrels + 1] = {x = 124, y = FLOORS[4], fl = 4, dir = 1, spd = 1.5 + S.level * 0.25, jumped = false}
      sfx.tone("tri", 240, 0.09, 0.16)
    end

    for _, b in ipairs(S.barrels) do
      b.x = b.x + b.dir * b.spd
      -- Drop down at the edges of each floor.
      if b.dir > 0 and b.x > W - 26 then
        if b.fl > 1 then b.fl, b.y, b.dir = b.fl - 1, FLOORS[b.fl - 1], -1 else b.gone = true end
      elseif b.dir < 0 and b.x < 26 then
        if b.fl > 1 then b.fl, b.y, b.dir = b.fl - 1, FLOORS[b.fl - 1], 1 else b.gone = true end
      end
      -- Reward jumping over a barrel!
      if not b.jumped and b.fl == S.floor_i and not S.on_ground and abs(b.x - S.px) < 16 and S.py < b.y - 12 then
        b.jumped = true
        add_score(100)
        sfx.note("sine", 88, 0.1, 0.2)
        particles.text(S.px, S.py - 32, C.GOLD, "+100")
      end
      -- Hit check (Star Swatter smashes barrels into stars!).
      if dist(b.x, b.y - 10, S.px, S.py - 12) < (S.swat_t > 0 and 30 or 19) then
        if S.swat_t > 0 then
          b.gone = true
          add_score(200)
          sfx.arp("tri", {79, 88}, 0.05, 0.3)
          gfx.shake(3)
          particles.burst(b.x, b.y - 10, 20, 3, 28, 3, C.GOLD, "star")
          particles.text(b.x, b.y - 24, C.GOLD, "SMASH!")
        else
          b.gone = true
          hurt_hero()
        end
      end
    end
    sweep(S.barrels, function(b) return not b.gone end)

    -- Reach the friend at top-left!
    if S.floor_i == 4 and S.px < 146 then
      S.phase, S.win_t = "win", 0
      S.rescues = S.rescues + 1
      add_score(500)
      save_all()
      log("tower rescue " .. S.level)
      music.play(win_bed)
      sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
      for i = 1, 34 do
        particles.spawn(W / 2 + rnd(-110, 110), 160, rnd(-3, 3), rnd(-5, -1), 85, rnd(3, 5),
          i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.CYAN, "heart", 0.1, 0.99, 0.1)
      end
      react_to(S.level >= NTOWERS and "ALL THREE TOWERS! What a hero!" or "YOU RESCUED YOUR FRIEND! Yay!")
    end
  elseif S.phase == "win" then
    S.win_t = S.win_t + 1
    if (pressed and S.saw_release and S.win_t > 70) or S.win_t > 240 then
      snd.ok()
      if S.level >= NTOWERS then
        S.score = 0                 -- the run is over: the next player starts fresh at tower 1
        setup_tower(1)
      else
        setup_tower(S.level + 1)
      end
    end
  elseif S.phase == "restart" then
    S.restart_t = S.restart_t + 1
    if S.restart_t >= 65 then setup_tower(S.level) end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

local function paint_tower(th)
  gfx.vgrad(0, 0, W, H - 32, th.bg1, th.bg2)
  -- Girders / platforms.
  for _, y in ipairs(FLOORS) do
    gfx.rrect_o(12, y, W - 24, 14, 4, th.beam, C.INK, 2)
    for x = 24, W - 36, 28 do gfx.line(x, y + 2, x + 14, y + 12, 1.5, alpha(C.INK, 120)) end
  end
  -- Ladders.
  for _, l in ipairs(LADDERS) do
    local y1, y2 = FLOORS[l.top], FLOORS[l.bot]
    gfx.line(l.x - 10, y1, l.x - 10, y2, 3.5, th.lad)
    gfx.line(l.x + 10, y1, l.x + 10, y2, 3.5, th.lad)
    for y = y1 + 10, y2 - 6, 14 do gfx.line(l.x - 10, y, l.x + 10, y, 2.5, th.lad) end
  end
end

function draw()
  local th = TOWER_THEMES[(S.level - 1) % #TOWER_THEMES + 1]
  backdrop("tower_bg" .. ((S.level - 1) % NTOWERS + 1), function() paint_tower(th) end)

  -- Big Grumble at top-left (waves when rescued!) + trapped fairy friend!
  local ay = FLOORS[4] - 26 + sin(game.frame * 0.1) * 3
  toon(function()
    toon.ellipse(76, ay, 24, 22, C.BROWN)
    toon.circle(76, ay - 18, 16, C.BROWN)
    toon.ellipse(76, ay - 15, 11, 8, C.SKIN)
  end, 2.2, C.INK)
  gfx.circle(71, ay - 18, 2.2, C.INK)
  gfx.circle(81, ay - 18, 2.2, C.INK)
  -- Friend to rescue!
  local fy = FLOORS[4] - 22 - abs(sin(game.frame * 0.14)) * (S.phase == "win" and 10 or 3)
  gfx.glow(128, fy, 22, alpha(C.GOLD, 130))
  toon(function() toon.circle(128, fy, 11, C.GOLD) end, 2, C.INK)
  gfx.circle(125, fy - 2, 1.8, C.INK)
  gfx.circle(131, fy - 2, 1.8, C.INK)

  -- Star Swatter pickup.
  if S.swatter and not S.swatter.gone then
    local hy = S.swatter.y + sin(game.frame * 0.12) * 3
    gfx.glow(S.swatter.x, hy, 22, alpha(C.GOLD, 140))
    gfx.line(S.swatter.x, hy + 10, S.swatter.x, hy - 6, 4, C.WOOD)
    gfx.rrect_o(S.swatter.x - 11, hy - 14, 22, 12, 4, C.GOLD, C.INK, 2)
  end

  -- Rolling barrels.
  for _, b in ipairs(S.barrels) do
    gfx.circle_o(b.x, b.y - 11, 11, C.WOOD, C.INK, 2)
    gfx.circle(b.x + cos(game.frame * 0.25 * b.dir) * 4, b.y - 11 + sin(game.frame * 0.25 * b.dir) * 4, 2.5, C.GOLD)
  end

  -- Hero!
  if not (S.hurt_cool > 0 and idiv(S.hurt_cool, 4) % 2 == 1) then
    local x, y = S.px, S.py - 16
    toon(function()
      toon.rrect(x - 9, y, 18, 16, 6, C.BLUE)
      toon.circle(x, y - 8, 10, C.SKIN)
      toon.ellipse(x, y - 14, 12, 6, C.RED)
    end, 2.2, C.INK)
    gfx.circle(x - 3 + S.face * 2, y - 8, 1.8, C.INK)
    gfx.circle(x + 3 + S.face * 2, y - 8, 1.8, C.INK)
    if S.swat_t > 0 then
      local sw = sin(game.frame * 0.5) * 12
      gfx.rrect_o(x + S.face * 16 - 9, y - 12 + sw, 18, 10, 3, C.GOLD, C.INK, 2)
    end
  end

  -- HUD.
  gfx.rrect_o(8, 8, 106, 26, 9, C.CREAM, C.INK, 2)
  gfx.text("TOWER " .. S.level, 61, 12, 14, C.INK, "center")
  for i = 1, 3 do
    local hx = W / 2 - 26 + (i - 1) * 26
    gfx.heart(hx, 22, 10, C.INK)
    gfx.heart(hx, 22, 8, i <= (3 - S.hurts) and C.ROSE or 0x9aa4b8)
  end
  gfx.rrect_o(W - 110, 8, 102, 26, 9, C.CREAM, C.INK, 2)
  gfx.text(tostring(S.score), W - 59, 12, 14, C.INK, "center")

  if S.phase == "win" then
    gfx.rrect_o(44, 204, W - 88, 96, 14, C.CREAM, C.INK, 3)
    gfx.text(S.level >= NTOWERS and "ALL CLEAR!" or "TOWER CLEAR!", W / 2, 218, 28, C.GOLD, "center", C.INK)
    gfx.text("SCORE: " .. S.score .. "   BEST: " .. S.best, W / 2, 258, 14, C.PURPLE, "center")
    if S.level >= NTOWERS then gfx.text("Next hero starts a new run!", W / 2, 278, 12, C.INK, "center") end
  end

  particles.draw()
  local line = S.react_left > 0 and S.react or (S.swat_t > 0 and "SMASH the barrels!" or "Climb the ladders and hop the barrels!")
  if input.down("1p") and input.down("2p") then line = "Your best score will stay!" end
  ui.band(line)
end
