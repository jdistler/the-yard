-- Safari: Meadow Monsters! A kid-friendly creature-catching & friendly Gym adventure (5+).
-- Walk-up band (CONTROLS.md). Stick explores; LOW/TL/TR tosses an auto-aimed Friend Orb
-- (or unleashes your buddy's elemental move in the friendly Gym!).
-- safari.sav keeps "caught N", "badges N", "best N", and bitmask "dex N".

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, RED = 0xe84855,
  BLUE = 0x5ab8ff, GREEN = 0x62cc6a, PURPLE = 0x8a5cf5, ORANGE = 0xf28c38,
  PIKA = 0xffd838, CYAN = 0x7fe8ff, ROSE = 0xe86b9a, WHITE = 0xfffcf8,
  SKIN = 0xf4c7a1, CAP = 0xe84855,
}

-- Eight original tribute creatures across 3 habitats!
local MONS = {
  {id = 1, name = "Sparky", col = C.PIKA, accent = C.RED, kind = "elec", zone = 1},
  {id = 2, name = "Sprout", col = 0x68d478, accent = 0x3ca050, kind = "leaf", zone = 1},
  {id = 3, name = "Ember", col = C.ORANGE, accent = C.GOLD, kind = "fire", zone = 2},
  {id = 4, name = "Mystic", col = 0xf2c14e, accent = 0x8a5a32, kind = "psy", zone = 2},
  {id = 5, name = "Splash", col = C.BLUE, accent = C.CYAN, kind = "water", zone = 3},
  {id = 6, name = "Snooze", col = 0x48788a, accent = C.CREAM, kind = "bear", zone = 1},
  {id = 7, name = "Giggle", col = C.PURPLE, accent = C.ROSE, kind = "ghost", zone = 2},
  {id = 8, name = "Skywing", col = 0x70b8ff, accent = C.WHITE, kind = "drag", zone = 3},
}

local ZONES = {
  {name = "Sunny Meadow", top = 0x88dc7c, bot = 0x68c462, path = 0xeed8b4},
  {name = "Spark Cave", top = 0x6c5c8a, bot = 0x4e4068, path = 0x9888a8},
  {name = "Crystal Pond", top = 0x68c4e8, bot = 0x4ca4d4, path = 0xd8ecf4},
}

local explore_bed = {bpm = 114, steps = 2,
  {"C5 . E5 . G5 . E5 . A5 . G5 . E5 . D5 . ", wave = "tri", vol = 0.16, release = 0.22, attack = 0.01, pan = -0.2},
  {"C3 - G2 - A2 - E2 - F2 - C3 - G2 - G2 - ", wave = "sine", vol = 0.22, release = 0.3, attack = 0.01}}
local gym_bed = {bpm = 142, steps = 4,
  {"E5 . G5 . A5 . G5 . E5 . D5 . E5 . . . G5 . A5 . C6 . A5 . G5 . E5 . D5 . . . ",
   wave = "square", vol = 0.11, release = 0.05, attack = 0.004, duty = 0.25, pan = -0.2},
  {"A2 . A2 . E3 . E3 . F2 . F2 . G2 . G2 . ", wave = "tri", vol = 0.24, release = 0.06, attack = 0.004},
  {"K . H . S . H . K . H K S . H . ", wave = "noise", vol = 0.09, release = 0.04, pan = 0.2}}

local S = {
  phase = "explore", zone = 1, caught = 0, badges = 0, best = 0, score = 0,
  dex = {}, buddy = nil,
  px = 192, py = 360, fx = 0, fy = -1, walk_t = 0, moving = false,
  bx = 160, by = 385,
  wild = {}, orb = nil, aim = nil,
  -- Friendly Gym Duel state
  gym_foe = nil, gym_marks = 0, gym_win = 8, gym_t = 0, gym_beam = nil,
  win_t = 0, saw_release = false, cool = 0, react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 110 end

local function count_dex()
  local n = 0
  for i = 1, #MONS do if S.dex[i] then n = n + 1 end end
  S.caught = n
  return n
end

local function save_progress()
  if S.score > S.best then S.best = S.score end
  save.set("caught", count_dex())
  save.set("badges", S.badges)
  save.set("best", S.best)
  local mask = 0
  for i = 1, #MONS do if S.dex[i] then mask = mask + 2 ^ (i - 1) end end
  save.set("dex", mask)
  save.write()
end

local function spawn_zone(z)
  S.zone = z
  S.wild = {}
  local spots = {{96, 220}, {288, 220}, {110, 340}, {276, 350}}
  local idx = 1
  for _, m in ipairs(MONS) do
    if m.zone == z then
      local sp = spots[idx] or {192, 260}
      idx = idx + 1
      S.wild[#S.wild + 1] = {mon = m, hx = sp[1], hy = sp[2], x = sp[1], y = sp[2], ph = idx * 1.9, caught = false}
    end
  end
  log("safari zone " .. z)
  react_to(ZONES[z].name .. "! Toss a Friend Orb!")
end

local function pick_wild()
  local best, bd = nil, 150 * 150
  for _, w in ipairs(S.wild) do
    if not w.caught then
      local d = (w.x - S.px) ^ 2 + (w.y - S.py) ^ 2
      if d < bd then best, bd = w, d end
    end
  end
  return best
end

local function throw_orb()
  if S.orb then return end
  local tgt = pick_wild()
  log("safari orb")
  sfx.slide("sine", 540, 1080, 0.14, 0.22)
  if tgt then
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12, tx = tgt.x, ty = tgt.y,
             tgt = tgt, state = "fly", t = 0, wob = 0}
  else
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12,
             tx = clamp(S.px + S.fx * 72, 28, W - 28), ty = clamp(S.py + S.fy * 72, 120, 440),
             tgt = nil, state = "fly", t = 0, wob = 0}
  end
end

local function start_gym()
  S.phase = "gym"
  S.gym_foe = MONS[rndi(1, #MONS)]
  S.gym_marks, S.gym_win, S.gym_t = 0, 8 + min(S.badges * 2, 8), 0
  S.px, S.py = 192, 390
  log("safari gym")
  music.play(gym_bed)
  sfx.arp("tri", {72, 76, 79, 84}, 0.06, 0.3)
  react_to("Friendly Gym Duel vs " .. S.gym_foe.name .. "! Press to cheer!")
end

local function draw_mon(m, x, y, s, happy)
  local bob = sin(game.frame * 0.12 + m.id) * 3 * s
  y = y + bob
  gfx.ellipse(x, y + 18 * s, 16 * s, 5 * s, alpha(0x1a1428, 80))
  toon(function()
    if m.kind == "elec" or m.kind == "psy" then
      toon.tri(x - 10 * s, y - 8 * s, x - 18 * s, y - 28 * s, x - 2 * s, y - 14 * s, m.col)
      toon.tri(x + 10 * s, y - 8 * s, x + 18 * s, y - 28 * s, x + 2 * s, y - 14 * s, m.col)
    elseif m.kind == "drag" then
      toon.tri(x - 12 * s, y, x - 26 * s, y - 14 * s, x - 8 * s, y - 10 * s, m.accent)
      toon.tri(x + 12 * s, y, x + 26 * s, y - 14 * s, x + 8 * s, y - 10 * s, m.accent)
    elseif m.kind == "leaf" then
      toon.ellipse(x, y - 15 * s, 11 * s, 8 * s, m.accent)
    end
    toon.circle(x, y, 15 * s, m.col)
  end, 2 * s, C.INK)
  if m.kind == "fire" then
    gfx.glow(x + 16 * s, y + 2 * s, 14 * s, alpha(C.GOLD, 160))
    gfx.circle(x + 16 * s, y + 2 * s, 5 * s, C.RED)
    gfx.circle(x + 16 * s, y + 1 * s, 2.8 * s, C.GOLD)
  end
  if happy then
    gfx.line(x - 8 * s, y - 2 * s, x - 5 * s, y - 6 * s, 2 * s, C.INK)
    gfx.line(x - 5 * s, y - 6 * s, x - 2 * s, y - 2 * s, 2 * s, C.INK)
    gfx.line(x + 2 * s, y - 2 * s, x + 5 * s, y - 6 * s, 2 * s, C.INK)
    gfx.line(x + 5 * s, y - 6 * s, x + 8 * s, y - 2 * s, 2 * s, C.INK)
  else
    gfx.circle(x - 5 * s, y - 3 * s, 2.5 * s, C.INK)
    gfx.circle(x + 5 * s, y - 3 * s, 2.5 * s, C.INK)
    gfx.circle(x - 6 * s, y - 4 * s, 1 * s, C.WHITE)
    gfx.circle(x + 4 * s, y - 4 * s, 1 * s, C.WHITE)
  end
  gfx.circle(x - 9 * s, y + 3 * s, 3 * s, alpha(m.accent, 180))
  gfx.circle(x + 9 * s, y + 3 * s, 3 * s, alpha(m.accent, 180))
  gfx.line(x - 3 * s, y + 4 * s, x + 3 * s, y + 4 * s, 1.5 * s, C.INK)
end

function bot()
  if S.phase == "gym" then
    if game.frame % 14 == 0 then input.bot("low") end
    return
  elseif S.phase == "gymwin" then
    if S.win_t > 70 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  local tgt = nil
  for _, w in ipairs(S.wild) do if not w.caught then tgt = w break end end
  if tgt then
    if dist(S.px, S.py, tgt.x, tgt.y) < 120 then
      if not S.orb and game.frame % 8 == 0 then input.bot("low") end
    else
      if tgt.x < S.px - 6 then input.bot("left") elseif tgt.x > S.px + 6 then input.bot("right") end
      if tgt.y < S.py - 6 then input.bot("up") elseif tgt.y > S.py + 6 then input.bot("down") end
    end
  elseif S.buddy then
    -- Walk up to the Starlight Gym!
    if S.px < 186 then input.bot("right") elseif S.px > 198 then input.bot("left") end
    if S.py > 140 then input.bot("up") end
  end
end

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.badges = clamp(save.get("badges", 0), 0, 100000)
  S.best = clamp(save.get("best", 0), 0, 999999)
  local mask = clamp(save.get("dex", 0), 0, 255)
  for i = 1, #MONS do
    if idiv(mask, 2 ^ (i - 1)) % 2 == 1 then
      S.dex[i] = true
      if not S.buddy then S.buddy = MONS[i] end
    end
  end
  count_dex()
  log("safari caught " .. S.caught)
  spawn_zone(1)
  music.play(explore_bed)
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.cool > 0 then S.cool = S.cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "explore" then
    S.moving = false
    if mx ~= 0 or my ~= 0 then
      S.moving = true
      S.walk_t = S.walk_t + 1
      S.fx, S.fy = mx, my
      S.px = clamp(S.px + mx * 2.4, 24, W - 24)
      S.py = clamp(S.py + my * 2.4, 126, 446)
    end
    -- Walk off left/right edges to visit other habitats!
    if S.px <= 26 and mx < 0 then
      S.px = W - 44
      spawn_zone(S.zone == 1 and 3 or S.zone - 1)
    elseif S.px >= W - 26 and mx > 0 then
      S.px = 44
      spawn_zone(S.zone == 3 and 1 or S.zone + 1)
    end
    -- Buddy follows happily!
    S.bx = approach(S.bx, S.px - S.fx * 28, 0.08)
    S.by = approach(S.by, S.py - S.fy * 28 + 10, 0.08)

    for _, w in ipairs(S.wild) do
      if not w.caught then
        w.x = w.hx + sin(game.frame * 0.025 + w.ph) * 26
        w.y = w.hy + sin(game.frame * 0.037 + w.ph) * 14
      end
    end
    S.aim = pick_wild()

    -- Friend Orb arc -> 3 wobbles -> CLICK!
    if S.orb then
      local o = S.orb
      o.t = o.t + 1
      if o.state == "fly" then
        local k = clamp(o.t / 22, 0, 1)
        o.x = lerp(o.x0, o.tx, k)
        o.y = lerp(o.y0, o.ty, k) - sin(k * math.pi) * 48
        if k >= 1 then
          if o.tgt then
            o.state, o.t, o.wob = "wobble", 0, 0
            o.tgt.caught = true
            sfx.note("sine", 76, 0.14, 0.24)
            particles.burst(o.x, o.y, 12, 2.2, 22, 2.5, C.WHITE, "star")
          else
            S.orb = nil
            particles.burst(o.x, o.y, 8, 1.8, 16, 2, C.GOLD, "dot")
          end
        end
      elseif o.state == "wobble" then
        if o.t % 20 == 0 then
          o.wob = o.wob + 1
          sfx.note("tri", 72 + o.wob * 4, 0.1, 0.22)
        end
        if o.t >= 62 then
          local m = o.tgt.mon
          S.dex[m.id] = true
          S.buddy = m
          S.score = S.score + 200
          save_progress()
          log("safari catch " .. m.name)
          sfx.arp("tri", {72, 76, 79, 84, 88}, 0.06, 0.32)
          particles.burst(o.x, o.y, 26, 3.2, 34, 3, C.GOLD, "star")
          particles.text(o.x, o.y - 18, C.GOLD, "FRIEND!")
          react_to("Yay! " .. m.name .. " is your new friend!")
          S.orb = nil
        end
      end
    end

    -- Walk up to the Starlight Gym arch once you have a buddy!
    if S.buddy and S.py < 146 and abs(S.px - 192) < 42 then
      start_gym()
    end

    if pressed and S.saw_release and S.cool == 0 then
      throw_orb()
      S.cool = 20
    end
  elseif S.phase == "gym" then
    S.gym_t = S.gym_t + 1
    if mx ~= 0 then S.px = clamp(S.px + mx * 2.4, 48, W - 48) end
    S.bx = approach(S.bx, S.px, 0.15)
    S.by = approach(S.by, S.py - 36, 0.15)
    if pressed and S.saw_release and S.cool == 0 then
      S.cool = 14
      S.gym_marks = S.gym_marks + 1
      S.score = S.score + 50
      local col = S.buddy and S.buddy.col or C.GOLD
      S.gym_beam = {x0 = S.bx, y0 = S.by, x1 = 192, y1 = 166, t = 12, col = col}
      sfx.slide("square", 860, 520, 0.09, 0.2)
      particles.burst(192, 166, 12, 2.5, 22, 2.5, col, "star")
      if S.gym_marks >= S.gym_win then
        S.phase, S.win_t = "gymwin", 0
        S.badges = S.badges + 1
        S.score = S.score + 500
        save_progress()
        log("safari badge " .. S.badges)
        sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
        particles.burst(192, 166, 36, 4, 46, 3.5, C.GOLD, "star")
        music.play(explore_bed)
        react_to("YOU WON A GYM BADGE! Amazing teamwork!")
      end
    end
  elseif S.phase == "gymwin" then
    S.win_t = S.win_t + 1
    if (pressed and S.saw_release and S.win_t > 60) or S.win_t > 200 then
      snd.ok()
      S.phase = "explore"
      S.px, S.py = 192, 340
      spawn_zone(S.zone == 3 and 1 or S.zone + 1)
    end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  local Z = ZONES[S.zone]
  gfx.vgrad(0, 0, W, H - 32, Z.top, Z.bot)
  if S.phase == "explore" then
    -- Starlight Gym Arch at top center.
    gfx.rrect_o(136, 94, 112, 46, 12, C.CREAM, C.INK, 2.5)
    gfx.text("GYM", 192, 106, 20, C.GOLD, "center", C.INK)
    -- Zone signposts left/right.
    gfx.text("<", 14, 270, 22, C.CREAM, "left", C.INK)
    gfx.text(">", W - 14, 270, 22, C.CREAM, "right", C.INK)
    -- Wild creatures!
    for _, w in ipairs(S.wild) do
      if not w.caught then draw_mon(w.mon, w.x, w.y, 1.05, false) end
    end
    if S.aim then
      for k = 0, 3 do
        local a = game.frame * 0.08 + k * 1.571
        gfx.star(S.aim.x + cos(a) * 24, S.aim.y + sin(a) * 24, 5, a, C.GOLD)
      end
    end
    if S.orb then
      local wob = S.orb.state == "wobble" and sin(S.orb.t * 0.45) * 4 or 0
      gfx.circle_o(S.orb.x + wob, S.orb.y, 11, C.WHITE, C.INK, 2)
      gfx.rrect(S.orb.x - 10 + wob, S.orb.y - 10, 20, 10, 8, C.RED)
      gfx.rect(S.orb.x - 10 + wob, S.orb.y - 1, 20, 2.5, C.INK)
      gfx.circle_o(S.orb.x + wob, S.orb.y, 3.2, C.WHITE, C.INK, 1.4)
    end
  else
    -- Friendly Gym Arena!
    gfx.ellipse_o(192, 180, 90, 26, alpha(C.CREAM, 180), C.INK, 2)
    gfx.ellipse_o(192, 360, 100, 28, alpha(C.CREAM, 180), C.INK, 2)
    if S.gym_foe then draw_mon(S.gym_foe, 192, 160, 1.65, S.phase == "gymwin") end
    for i = 0, S.gym_win - 1 do
      local x = 192 - (S.gym_win - 1) * 7 + i * 14
      gfx.circle(x, 218, 4.5, C.INK)
      gfx.circle(x, 218, 3, i < S.gym_marks and C.GOLD or 0x5a4a6a)
    end
    if S.gym_beam and S.gym_beam.t > 0 then
      local b = S.gym_beam
      gfx.line(b.x0, b.y0, b.x1, b.y1, b.t, alpha(b.col, 200))
      gfx.line(b.x0, b.y0, b.x1, b.y1, b.t * 0.4, C.WHITE)
      b.t = b.t - 1
    end
  end

  -- Buddy + Trainer!
  if S.buddy then draw_mon(S.buddy, S.bx, S.by, 0.85, S.phase == "gymwin") end
  toon(function()
    toon.rrect(S.px - 9, S.py, 18, 16, 6, C.BLUE)
    toon.circle(S.px, S.py - 8, 11, C.SKIN)
    toon.ellipse(S.px, S.py - 15, 13, 7, C.CAP)
  end, 2.2, C.INK)
  gfx.circle(S.px - 3.5, S.py - 8, 1.8, C.INK)
  gfx.circle(S.px + 3.5, S.py - 8, 1.8, C.INK)

  -- Top HUD: Field Book 8-dot tracker + Badges + Score!
  gfx.rrect_o(8, 8, W - 16, 46, 12, C.CREAM, C.INK, 2)
  for i = 1, #MONS do
    local cx = 26 + (i - 1) * 24
    gfx.circle_o(cx, 31, 8, S.dex[i] and MONS[i].col or 0xc8c0d0, C.INK, 1.5)
  end
  gfx.text("BADGES " .. S.badges, W - 18, 13, 13, C.PURPLE, "right")
  gfx.text("PTS " .. S.score, W - 18, 31, 13, C.INK, "right")

  if S.phase == "gymwin" then
    gfx.rrect_o(44, 224, W - 88, 92, 14, C.CREAM, C.INK, 3)
    gfx.text("GYM BADGE WON!", W / 2, 238, 26, C.GOLD, "center", C.INK)
    gfx.text("BADGES: " .. S.badges .. "   FRIENDS: " .. S.caught .. "/8", W / 2, 278, 14, C.PURPLE, "center")
  end

  particles.draw()
  local line = S.react_left > 0 and S.react or (S.aim and ("Press to toss a Friend Orb at " .. S.aim.mon.name .. "!") or (S.buddy and "Walk to the GYM or explore left/right!" or "Walk near a monster and press!"))
  if input.down("1p") and input.down("2p") then line = "Your friends and badges will stay!" end
  ui.band(line)
end
