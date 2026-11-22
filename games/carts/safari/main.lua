-- Safari v2: Pocket Meadow Monsters!
-- Rich Pokémon-inspired creature-catching & interactive Gym Stadium adventure (5+).
-- Stick explores (and dodges in Gym!); LOW tosses a Friend Orb (or unleashes your buddy's
-- signature elemental move in the Gym!); TL/TR switches your active Buddy once you have 2+ friends!
-- safari.sav keeps "caught N", "badges N", "best N", and bitmask "dex N".

local pics = import("pictures")
local C = pics.C
local ZONES = pics.ZONES

-- Eight distinct Pokémon-homage monsters across 3 habitats, each with a signature move!
local MONS = {
  {id = 1, name = "Sparky",  col = C.PIKA,   accent = C.RED,    kind = "elec",  zone = 1, move = "THUNDERBOLT!"},
  {id = 2, name = "Sprout",  col = C.MINT,   accent = C.GREEN,  kind = "leaf",  zone = 1, move = "RAZOR LEAF!"},
  {id = 3, name = "Ember",   col = C.ORANGE, accent = C.GOLD,   kind = "fire",  zone = 2, move = "FLAMETHROWER!"},
  {id = 4, name = "Mystic",  col = 0xf2c14e, accent = C.CYAN,   kind = "psy",   zone = 2, move = "PSYBEAM!"},
  {id = 5, name = "Splash",  col = C.BLUE,   accent = C.CYAN,   kind = "water", zone = 3, move = "HYDRO WAVE!"},
  {id = 6, name = "Snooze",  col = C.NAVY,   accent = C.CREAM,  kind = "bear",  zone = 1, move = "MEGA BOUNCE!"},
  {id = 7, name = "Giggle",  col = C.PURPLE, accent = C.ROSE,   kind = "ghost", zone = 2, move = "SHADOW BALL!"},
  {id = 8, name = "Skywing", col = 0xf2a43c, accent = C.TEAL,   kind = "drag",  zone = 3, move = "DRAGON STAR!"},
}

-- Classic elemental type advantage (2x marks + SUPER EFFECTIVE popup; every type still wins!).
local SUPER = {
  water = {fire = true},
  fire  = {leaf = true},
  leaf  = {water = true},
  elec  = {water = true, drag = true},
  psy   = {ghost = true},
  ghost = {psy = true},
  drag  = {drag = true, leaf = true},
  bear  = {elec = true},
}

-- ------------------------------------------------------------------ 3-Song Chiptune Soundtrack!
-- 1. Route Adventure (132 BPM, 128-step, 5-track upbeat Game Boy / NES journey theme in C major!)
local explore_bed = {bpm = 132, steps = 4,
  {"C5 . E5 G5 . E5 C5 . A5 . G5 . E5 . . . " ..
   "F5 . A5 G5 . F5 E5 . D5 . E5 . G5 . . . " ..
   "C5 . E5 G5 . A5 B5 . C6 . A5 G5 . E5 . . " ..
   "F5 . E5 D5 . C5 B4 . C5 . G5 . C5 . . . " ..
   "A5 . G5 F5 . E5 D5 . E5 . G5 . C6 . . . " ..
   "F5 . A5 C6 . B5 A5 . G5 . E5 . D5 . . . " ..
   "E5 . G5 C6 . B5 A5 . F5 . A5 . G5 . E5 . " ..
   "D5 . F5 E5 . D5 B4 . C5 . G5 . C6 . . . ",
   wave = "square", vol = 0.19, release = 0.06, attack = 0.004, duty = 0.25, pan = -0.2},
  {". . . . C5 . . . F5 . . . C5 G4 E4 . " ..
   ". . . . D5 . . . B4 . . . G4 D4 B3 . " ..
   ". . . . E5 . . . A5 . . . E5 . C5 . " ..
   "A4 . C5 B4 . G4 . . E4 . C5 . E4 G4 C5 . " ..
   "F4 . A4 . D5 . A4 . G4 . C5 . E5 . C5 . " ..
   "A4 . C5 . F5 . C5 . E4 . G4 . B4 . G4 . " ..
   "G4 . C5 . E5 . C5 . A4 . C5 . B4 . G4 . " ..
   "F4 . A4 . G4 . D4 . E4 . C5 . E5 . . . ",
   wave = "square", vol = 0.11, release = 0.05, attack = 0.004, duty = 0.125, pan = 0.25},
  {"C3 . G2 . C3 . E3 . F2 . C3 . F2 . A2 . " ..
   "D3 . A2 . G2 . B2 . C3 . G2 . C3 . E3 . " ..
   "C3 . G2 . E3 . C3 . F2 . C3 . A2 . F2 . " ..
   "D3 . F2 . G2 . B2 . C3 . G2 . C3 . . . " ..
   "F2 . C3 . F2 . A2 . C3 . G2 . E2 . G2 . " ..
   "D3 . A2 . F2 . A2 . G2 . D3 . G2 . B2 . " ..
   "C3 . G2 . E3 . C3 . F2 . C3 . G2 . B2 . " ..
   "D3 . F2 . G2 . B2 . C3 . G2 . C3 . . . ",
   wave = "tri", vol = 0.28, release = 0.06, attack = 0.004},
  {". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . G5 E5 C5 . " ..
   "F5 . A5 . C6 . A5 . E5 . G5 . C6 . G5 . " ..
   "F5 . A5 . D6 . A5 . D5 . G5 . B5 . G5 . " ..
   "E5 . G5 . C6 . G5 . F5 . A5 . G5 . B5 . " ..
   "F5 . A5 . G5 . D6 . E6 . C6 . G5 . . . ",
   wave = "sine", vol = 0.09, release = 0.10, attack = 0.006, pan = 0.2},
  {"K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K S S H C . . . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . S . K S S S K . S . C . . . ",
   wave = "noise", vol = 0.11, release = 0.035, pan = 0.15}}

-- 2. Gym Leader Battle! (154 BPM, 128-step, 5-track high-energy A-minor / C-major battle theme!)
local gym_bed = {bpm = 154, steps = 4,
  {"A4 B4 C5 D5 E5 . E5 . A5 . G5 E5 . D5 C5 . " ..
   "D5 . F5 E5 . D5 C5 . B4 . E5 . G#5 . E5 . " ..
   "A5 . E5 C5 . E5 A5 . G5 . D5 B4 . D5 G5 . " ..
   "F5 . E5 D5 . C5 B4 . A4 . E5 . A5 . . . " ..
   "C6 . B5 A5 . G5 E5 . F5 . A5 G5 . F5 E5 . " ..
   "D5 . F5 A5 . G5 F5 . E5 . G#5 B5 . E6 . . " ..
   "A5 . G5 F5 . E5 D5 . C5 . E5 A5 . G5 E5 . " ..
   "F5 . D5 E5 . G#5 B5 . A5 . E5 . A5 . . . ",
   wave = "square", vol = 0.21, release = 0.04, attack = 0.003, duty = 0.25, pan = -0.2},
  {"E4 . A4 . C5 . A4 . E4 . A4 . C5 . A4 . " ..
   "F4 . A4 . D5 . A4 . E4 . G#4 . B4 . G#4 . " ..
   "E4 . A4 . C5 . A4 . D4 . G4 . B4 . G4 . " ..
   "D4 . F4 . E4 . G#4 . C4 . E4 . A4 . E4 . " ..
   "G4 . C5 . E5 . C5 . A4 . C5 . F5 . C5 . " ..
   "F4 . A4 . D5 . A4 . G#4 . B4 . E5 . B4 . " ..
   "E4 . A4 . C5 . A4 . G4 . B4 . E5 . B4 . " ..
   "A4 . F4 . G#4 . B4 . C5 . A4 . E4 . . . ",
   wave = "square", vol = 0.13, release = 0.035, attack = 0.003, duty = 0.125, pan = 0.25},
  {"A2 A3 A2 A3 A2 A3 G2 G3 F2 F3 F2 F3 E2 E3 E2 E3 " ..
   "D2 D3 D2 D3 D2 D3 F2 F3 E2 E3 E2 E3 G#2 G#3 E2 E3 " ..
   "A2 A3 A2 A3 C3 C4 A2 A3 G2 G3 G2 G3 B2 B3 G2 G3 " ..
   "F2 F3 F2 F3 E2 E3 G#2 G#3 A2 A3 E2 E3 A2 . . . " ..
   "C3 C4 C3 C4 G2 G3 E2 E3 F2 F3 F2 F3 C3 C4 A2 A3 " ..
   "D2 D3 D2 D3 A2 A3 F2 F3 E2 E3 E2 E3 G#2 G#3 B2 B3 " ..
   "A2 A3 A2 A3 G2 G3 E2 E3 F2 F3 F2 F3 E2 E3 C2 C3 " ..
   "D2 D3 F2 F3 E2 E3 G#2 G#3 A2 A3 E2 E3 A2 . . . ",
   wave = "tri", vol = 0.30, release = 0.04, attack = 0.002},
  {"K H K H S H K H K H K K S H H H " ..
   "K H K H S H K H K K S S C . H . " ..
   "K H K H S H K H K H K K S H H H " ..
   "K H S H K S S S K . S . C . . . ",
   wave = "noise", vol = 0.14, release = 0.03, pan = 0.15}}

-- 3. Gym Badge Victory Fanfare! (144 BPM, 4-track harmonized fanfare!)
local win_bed = {bpm = 144, steps = 4,
  {"C5 . E5 . G5 . C6 - - . B5 . C6 . D6 . E6 - - - C6 . G5 . E5 . G5 . C6 - - . ",
   wave = "square", vol = 0.20, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
  {"G4 . C5 . E5 . G5 - - . F5 . E5 . F5 . G5 - - - E5 . C5 . G4 . C5 . E5 - - . ",
   wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
  {"C3 - G2 - C3 - E3 - F2 - C3 - G2 - D3 - C3 - G2 - A2 - E2 - F2 - G2 - C3 - - . ",
   wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
  {"K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . ",
   wave = "noise", vol = 0.13, release = 0.04}}

-- ------------------------------------------------------------------ Game State
local S = {
  phase = "explore", zone = 1, caught = 0, badges = 0, best = 0, score = 0,
  dex = {}, buddy = nil,
  px = 192, py = 360, fx = 0, fy = -1, walk_t = 0, moving = false,
  bx = 160, by = 385,
  wild = {}, berry = nil, super_orb = false, orb = nil, aim = nil, rustle_cool = 0,
  -- Interactive Gym Stadium state
  gym_foe = nil, gym_marks = 0, gym_win = 10, gym_t = 0, gym_atk_t = 0, foe_atk_t = 0,
  gym_beam = nil, foe_shots = {}, foe_cool = 95, star_charge = 0, hurt_cool = 0,
  win_t = 0, saw_release = false, cool = 0, swap_cool = 0, react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 115 end
local function leaving() return input.down("1p") and input.down("2p") end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.best then S.best = S.score end
end

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

local function cycle_buddy(step)
  if count_dex() < 2 then return false end
  local cur = S.buddy and S.buddy.id or 1
  for _ = 1, #MONS do
    cur = ((cur - 1 + step) % #MONS) + 1
    if S.dex[cur] then
      S.buddy = MONS[cur]
      sfx.arp("tri", {72, 79, 84}, 0.04, 0.28)
      particles.burst(S.bx, S.by, 16, 2.4, 24, 2.5, S.buddy.col, "star")
      particles.text(S.bx, S.by - 18, S.buddy.col, S.buddy.name .. "!")
      react_to("Go, " .. S.buddy.name .. "! (" .. S.buddy.move .. ")")
      return true
    end
  end
  return false
end

local function spawn_zone(z)
  S.zone = z
  S.wild = {}
  local spots = {{88, 214}, {294, 214}, {96, 356}, {288, 360}}
  local idx = 1
  for _, m in ipairs(MONS) do
    if m.zone == z then
      local sp = spots[idx] or {192, 260}
      idx = idx + 1
      S.wild[#S.wild + 1] = {mon = m, hx = sp[1], hy = sp[2], x = sp[1], y = sp[2], ph = idx * 1.9, caught = false}
    end
  end
  -- Spawn a shiny Golden Berry in a habitat corner!
  local bspots = {{64, 198}, {318, 198}, {68, 372}, {314, 376}}
  local bp = bspots[((z + S.badges) % #bspots) + 1]
  S.berry = {x = bp[1], y = bp[2], got = false}
  log("safari zone " .. z)
  react_to(ZONES[z].name .. "! Toss a Friend Orb!")
end

local function pick_wild()
  local best, bd = nil, 155 * 155
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
  local is_super = S.super_orb
  if tgt and is_super then S.super_orb = false end
  log("safari orb")
  sfx.slide("sine", 540, 1140, 0.14, 0.24)
  if tgt then
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12, tx = tgt.x, ty = tgt.y,
             tgt = tgt, state = "fly", t = 0, wob = 0, super_orb = is_super}
  else
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12,
             tx = clamp(S.px + S.fx * 76, 28, W - 28), ty = clamp(S.py + S.fy * 76, 130, 440),
             tgt = nil, state = "fly", t = 0, wob = 0, super_orb = false}
  end
end

local function start_gym()
  S.phase = "gym"
  S.gym_foe = MONS[(S.badges % #MONS) + 1]
  S.gym_marks, S.gym_win, S.gym_t = 0, 10 + min(S.badges * 2, 6), 0
  S.gym_atk_t, S.foe_atk_t, S.foe_cool, S.star_charge, S.hurt_cool = 0, 0, 75, 0, 0
  S.foe_shots, S.gym_beam = {}, nil
  S.px, S.py = 192, 404
  S.bx, S.by = 192, 360
  log("safari gym")
  music.play(gym_bed)
  music.tempo(1)
  music.volume(1)
  sfx.arp("square", {69, 72, 76, 81}, 0.055, 0.30)
  local _, bname = pics.badge_info(S.badges + 1)
  react_to(bname .. " GYM vs " .. S.gym_foe.name .. "! Dodge & attack!")
end

-- ------------------------------------------------------------------ Built-in Bot
function bot()
  if S.phase == "gym" then
    -- Dodge incoming foe shots cleanly, and fire elemental moves!
    local dodge = 0
    for _, sh in ipairs(S.foe_shots) do
      if sh.y > 260 and abs(sh.x - S.px) < 40 then
        dodge = S.px < W / 2 and 1 or -1
        break
      end
    end
    if dodge < 0 then input.bot("left") elseif dodge > 0 then input.bot("right") end
    if game.frame % 13 == 0 then input.bot("low") end
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
    if S.px < 186 then input.bot("right") elseif S.px > 198 then input.bot("left") end
    if S.py > 140 then input.bot("up") end
  end
end

-- ------------------------------------------------------------------ Lifecycle
function init()
  sfx.master(0.42)
  sfx.limit(12000)
  pics.build_bgs()
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
  music.volume(1)
end

local function step_explore(mx, my, pressed, swap_l, swap_r)
  S.moving = false
  if mx ~= 0 or my ~= 0 then
    S.moving = true
    S.walk_t = S.walk_t + 1
    S.fx, S.fy = mx, my
    S.px = clamp(S.px + mx * 2.5, 22, W - 22)
    S.py = clamp(S.py + my * 2.5, 134, 444)
    -- Tall-grass / crystal / lily-pad rustle particles when walking off the center road!
    if S.rustle_cool == 0 and (S.px < 156 or S.px > 228) and (S.py < 252 or S.py > 322) then
      S.rustle_cool = 14
      particles.burst(S.px, S.py + 12, 4, 1.4, 16, 2.2, ZONES[S.zone].accent, "square")
      sfx.noise(0.035, 0.09, 2600)
    end
  end

  -- Seamless walk off left/right edges to visit other habitats!
  if S.px <= 24 and mx < 0 then
    S.px = W - 42
    spawn_zone(S.zone == 1 and 3 or S.zone - 1)
  elseif S.px >= W - 24 and mx > 0 then
    S.px = 42
    spawn_zone(S.zone == 3 and 1 or S.zone + 1)
  end

  -- Buddy follows trainer happily!
  S.bx = approach(S.bx, S.px - S.fx * 30, 0.09)
  S.by = approach(S.by, S.py - S.fy * 26 + 8, 0.09)

  -- Golden Berry pickup -> powers up next Friend Orb into a SUPER GOLDEN ORB!
  if S.berry and not S.berry.got and dist(S.px, S.py, S.berry.x, S.berry.y) < 26 then
    S.berry.got = true
    S.super_orb = true
    add_score(100)
    sfx.arp("tri", {76, 81, 84, 88}, 0.045, 0.28)
    particles.burst(S.berry.x, S.berry.y, 20, 2.6, 28, 3, C.GOLD, "star")
    particles.text(S.berry.x, S.berry.y - 16, C.GOLD, "SUPER ORB!")
    react_to("Golden Berry! Next throw is a SUPER GOLDEN ORB!")
  end

  -- Wild creatures roam + occasional elemental sparkle!
  for _, w in ipairs(S.wild) do
    if not w.caught then
      w.x = w.hx + sin(game.frame * 0.025 + w.ph) * 28
      w.y = w.hy + sin(game.frame * 0.037 + w.ph) * 14
      if (game.frame + w.mon.id * 29) % 140 == 0 then
        particles.burst(w.x, w.y - 6, 4, 1.3, 18, 2.2, w.mon.accent, "star")
      end
    end
  end
  S.aim = pick_wild()

  -- Friend Orb arc -> wobble -> CLICK!
  if S.orb then
    local o = S.orb
    o.t = o.t + 1
    if o.state == "fly" then
      local k = clamp(o.t / 20, 0, 1)
      o.x = lerp(o.x0, o.tx, k)
      o.y = lerp(o.y0, o.ty, k) - sin(k * math.pi) * 52
      if k >= 1 then
        if o.tgt then
          o.state, o.t, o.wob = "wobble", 0, 0
          o.tgt.caught = true
          sfx.note("sine", 76, 0.14, 0.26)
          particles.burst(o.x, o.y, 16, 2.4, 24, 2.8, o.super_orb and C.GOLD or C.WHITE, "star")
        else
          S.orb = nil
          particles.burst(o.x, o.y, 8, 1.8, 16, 2, C.GOLD, "dot")
        end
      end
    elseif o.state == "wobble" then
      local need = o.super_orb and 22 or 58
      if o.t % 18 == 0 and o.t < need then
        o.wob = o.wob + 1
        sfx.note("tri", 72 + o.wob * 4, 0.1, 0.24)
      end
      if o.t >= need then
        local m = o.tgt.mon
        local is_new = not S.dex[m.id]
        S.dex[m.id] = true
        S.buddy = m
        add_score((o.super_orb and 300 or 200) + (is_new and 100 or 0))
        save_progress()
        log("safari catch " .. m.name)
        sfx.arp("tri", {72, 76, 79, 84, 88}, 0.055, 0.34)
        particles.burst(o.x, o.y, 28, 3.4, 36, 3.2, C.GOLD, "star")
        particles.text(o.x, o.y - 18, C.GOLD, is_new and "NEW FRIEND!" or "FRIEND!")
        react_to("Yay! " .. m.name .. " joined your team!")
        S.orb = nil
      end
    end
  end

  -- Enter the Starlight Gym Arch once you have a buddy!
  if S.buddy and S.py < 148 and abs(S.px - 192) < 46 then
    start_gym()
    return
  end

  -- Switch Buddy with TL/TR when you have 2+ friends; otherwise any right-hand button throws!
  if S.saw_release and S.swap_cool == 0 and count_dex() >= 2 and (swap_l or swap_r) then
    cycle_buddy(swap_r and 1 or -1)
    S.swap_cool = 16
  elseif pressed and S.saw_release and S.cool == 0 then
    throw_orb()
    S.cool = 18
  end
end

local function step_gym(mx, pressed, swap_l, swap_r)
  S.gym_t = S.gym_t + 1
  if S.gym_atk_t > 0 then S.gym_atk_t = S.gym_atk_t - 1 end
  if S.foe_atk_t > 0 then S.foe_atk_t = S.foe_atk_t - 1 end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end

  -- Move left/right to dodge rival elemental orbs!
  S.moving = mx ~= 0
  if mx ~= 0 then
    S.walk_t = S.walk_t + 1
    S.fx = mx
    S.px = clamp(S.px + mx * 2.8, 44, W - 44)
  end
  S.bx = approach(S.bx, S.px, 0.16)
  S.by = approach(S.by, S.py - 44, 0.16)

  -- Switch buddy mid-battle with TL/TR for type matchups!
  if S.saw_release and S.swap_cool == 0 and count_dex() >= 2 and (swap_l or swap_r) then
    cycle_buddy(swap_r and 1 or -1)
    S.swap_cool = 16
  end

  -- Gym Champion telegraphs & launches playful dodgeable orbs!
  S.foe_cool = S.foe_cool - 1
  if S.foe_cool == 20 then
    S.foe_atk_t = 14
    sfx.slide("sine", 420, 680, 0.12, 0.18)
  elseif S.foe_cool <= 0 then
    S.foe_cool = max(56, 96 - S.badges * 6)
    local tx = clamp(S.px + rnd(-26, 26), 54, W - 54)
    local vx = (tx - 192) / 54
    S.foe_shots[#S.foe_shots + 1] = {x = 192, y = 182, vx = vx, vy = 3.2 + min(S.badges * 0.25, 1.2), col = S.gym_foe.col, dodged = false}
  end

  for _, sh in ipairs(S.foe_shots) do
    sh.x, sh.y = sh.x + sh.vx, sh.y + sh.vy
    if S.hurt_cool == 0 and dist(sh.x, sh.y, S.bx, S.by) < 22 then
      sh.gone = true
      S.hurt_cool = 36
      sfx.slide("sine", 380, 220, 0.14, 0.22)
      gfx.shake(3)
      particles.burst(S.bx, S.by, 10, 2.2, 18, 2.4, sh.col, "star")
      particles.text(S.bx, S.by - 18, C.CREAM, "WHOA!")
    elseif not sh.dodged and sh.y > S.by + 24 then
      sh.dodged = true
      if S.star_charge < 3 then
        S.star_charge = S.star_charge + 1
        add_score(40)
        sfx.note("sine", 80 + S.star_charge * 3, 0.09, 0.22)
        if S.star_charge == 3 then
          particles.text(S.bx, S.by - 20, C.GOLD, "STAR READY!")
          react_to("STAR POWER FULL! Press for ULTIMATE MOVE!")
        end
      end
    end
    if sh.y > H - 24 then sh.gone = true end
  end
  sweep(S.foe_shots, function(sh) return not sh.gone end)

  -- Unleash Buddy's signature elemental move!
  if pressed and S.saw_release and S.cool == 0 then
    S.cool = 14
    S.gym_atk_t = 14
    local b = S.buddy or MONS[1]
    local is_ult = S.star_charge >= 3
    local is_super = SUPER[b.kind] and SUPER[b.kind][S.gym_foe.kind]
    local dmg = is_ult and 3 or (is_super and 2 or 1)
    if is_ult then S.star_charge = 0 end
    S.gym_marks = min(S.gym_win, S.gym_marks + dmg)
    add_score(dmg * 60)
    S.gym_beam = {x0 = S.bx, y0 = S.by - 10, x1 = 192, y1 = 166, t = is_ult and 18 or 13,
                  col = is_ult and C.GOLD or b.col, kind = is_ult and "ult" or b.kind}
    if is_ult then
      sfx.arp("square", {72, 79, 84, 91, 96}, 0.035, 0.34)
      gfx.shake(6)
      particles.burst(192, 166, 26, 3.6, 30, 3.2, C.GOLD, "star")
      particles.text(192, 132, C.GOLD, "STAR BLAST!")
      react_to(b.name .. " used ULTIMATE STAR BLAST!")
    elseif is_super then
      sfx.slide("square", 980, 560, 0.11, 0.26)
      gfx.shake(3)
      particles.burst(192, 166, 18, 3.0, 26, 2.8, b.col, "star")
      particles.text(192, 134, C.GOLD, "SUPER! 2X")
      react_to(b.name .. " used " .. b.move .. " SUPER EFFECTIVE!")
    else
      sfx.slide("square", 840, 480, 0.09, 0.22)
      particles.burst(192, 166, 12, 2.4, 22, 2.4, b.col, "star")
      react_to(b.name .. " used " .. b.move)
    end
    if S.gym_marks >= S.gym_win then
      S.phase, S.win_t = "gymwin", 0
      S.badges = S.badges + 1
      add_score(500)
      save_progress()
      log("safari badge " .. S.badges)
      sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.075, 0.36)
      particles.burst(192, 166, 38, 4.2, 48, 3.6, C.GOLD, "star")
      music.play(win_bed)
      local _, bname = pics.badge_info(S.badges)
      react_to("YOU WON THE " .. bname .. " BADGE!")
    end
  end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local swap_l, swap_r = input.pressed("tl"), input.pressed("tr")
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.cool > 0 then S.cool = S.cool - 1 end
  if S.swap_cool > 0 then S.swap_cool = S.swap_cool - 1 end
  if S.rustle_cool > 0 then S.rustle_cool = S.rustle_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "explore" then
    step_explore(mx, my, pressed, swap_l, swap_r)
  elseif S.phase == "gym" then
    step_gym(mx, pressed, swap_l, swap_r)
  elseif S.phase == "gymwin" then
    S.win_t = S.win_t + 1
    if S.win_t % 10 == 0 then
      particles.spawn(rnd(36, W - 36), 66, rnd(-1.5, 1.5), rnd(0.8, 2.2), 75, rnd(3, 4.5),
        S.win_t % 20 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.win_t > 60) or S.win_t > 210 then
      snd.ok()
      S.phase = "explore"
      S.px, S.py = 192, 344
      music.play(explore_bed)
      spawn_zone(S.zone == 3 and 1 or S.zone + 1)
    end
  end

  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

-- ------------------------------------------------------------------ Signature Move VFX
local function draw_beam(b)
  local k = b.kind
  if k == "elec" or k == "ult" then
    -- Jagged golden lightning bolt!
    local px, py = b.x0, b.y0
    for seg = 1, 5 do
      local f = seg / 5
      local nx = lerp(b.x0, b.x1, f) + (seg < 5 and ((seg % 2 == 0 and 1 or -1) * 14) or 0)
      local ny = lerp(b.y0, b.y1, f)
      gfx.line(px, py, nx, ny, b.t * 0.75, alpha(b.col, 220))
      gfx.line(px, py, nx, ny, b.t * 0.3, C.WHITE)
      px, py = nx, ny
    end
  elseif k == "fire" or k == "water" or k == "ghost" then
    -- Roaring elemental orbs surging up the beam!
    for seg = 1, 6 do
      local f = clamp(seg / 6 + (13 - b.t) * 0.04, 0, 1)
      local ox = lerp(b.x0, b.x1, f) + sin(seg * 2.1 + game.frame * 0.4) * 8
      local oy = lerp(b.y0, b.y1, f)
      gfx.circle(ox, oy, 5 + b.t * 0.4, alpha(b.col, 210))
      gfx.circle(ox, oy, 2.5 + b.t * 0.2, C.WHITE)
    end
  elseif k == "psy" then
    -- Hypnotic expanding psychic rings!
    for seg = 1, 5 do
      local f = seg / 5
      local ox, oy = lerp(b.x0, b.x1, f), lerp(b.y0, b.y1, f)
      gfx.circle_o(ox, oy, 6 + seg * 3, alpha(C.CYAN, 80), C.ROSE, 2.2)
    end
  else
    -- Whirling Razor Leaf / Dragon Star / Mega Bounce beam!
    gfx.line(b.x0, b.y0, b.x1, b.y1, b.t * 0.7, alpha(b.col, 200))
    for seg = 1, 4 do
      local f = seg / 4
      gfx.star(lerp(b.x0, b.x1, f), lerp(b.y0, b.y1, f), 7, game.frame * 0.3 + seg, C.GOLD)
    end
  end
end

function draw()
  if S.phase == "explore" then
    pics.draw_explore_bg(S.zone)
    -- Golden Berry!
    if S.berry and not S.berry.got then
      local by = S.berry.y + sin(game.frame * 0.12) * 3
      gfx.glow(S.berry.x, by, 18, alpha(C.GOLD, 140))
      gfx.circle_o(S.berry.x, by, 8, C.GOLD, C.INK, 1.8)
      gfx.tri(S.berry.x - 4, by - 7, S.berry.x, by - 13, S.berry.x + 4, by - 7, C.GREEN)
      gfx.circle(S.berry.x - 2.5, by - 2.5, 2, C.WHITE)
    end
    -- Wild monsters + target lock & name tag!
    for _, w in ipairs(S.wild) do
      if not w.caught then
        pics.draw_mon(w.mon, w.x, w.y, 1.05, false, 0)
      end
    end
    if S.aim then
      for k = 0, 3 do
        local a = game.frame * 0.08 + k * 1.571
        gfx.star(S.aim.x + cos(a) * 26, S.aim.y + sin(a) * 26, 5, a, S.super_orb and C.GOLD or C.WHITE)
      end
      gfx.rrect_o(S.aim.x - 36, S.aim.y + 22, 72, 18, 6, alpha(C.CREAM, 230), C.INK, 1.4)
      gfx.text(S.aim.mon.name, S.aim.x, S.aim.y + 24, 11, C.INK, "center")
    end
    if S.orb then
      local wob = S.orb.state == "wobble" and sin(S.orb.t * 0.45) * 4.5 or 0
      pics.draw_orb(S.orb.x, S.orb.y, 11, S.orb.super_orb, wob)
    end
  else
    -- Interactive Gym Stadium!
    pics.draw_gym_bg(S.zone, S.gym_foe and S.gym_foe.col)
    if S.gym_foe then
      pics.draw_mon(S.gym_foe, 192, 166, 1.55, S.phase == "gymwin", S.foe_atk_t)
      -- Champion Nameplate + HP Bar!
      gfx.rrect_o(102, 72, 180, 38, 10, C.CREAM, C.INK, 2)
      gfx.text(S.gym_foe.name:upper(), 114, 76, 13, C.INK, "left")
      local rem = max(0, S.gym_win - S.gym_marks)
      local frac = rem / max(1, S.gym_win)
      local hp_col = frac > 0.5 and C.GREEN or (frac > 0.25 and C.GOLD or C.RED)
      gfx.rrect_o(114, 94, 156, 10, 5, 0x4a3a58, C.INK, 1.4)
      if frac > 0 then gfx.rrect(116, 96, max(6, floor(152 * frac)), 6, 3, hp_col) end
    end
    -- Incoming dodgeable foe orbs!
    for _, sh in ipairs(S.foe_shots) do
      gfx.glow(sh.x, sh.y, 18, alpha(sh.col, 150))
      gfx.circle_o(sh.x, sh.y, 9, sh.col, C.INK, 2)
      gfx.circle(sh.x - 2, sh.y - 2, 3, C.WHITE)
    end
    if S.gym_beam and S.gym_beam.t > 0 then
      draw_beam(S.gym_beam)
      S.gym_beam.t = S.gym_beam.t - 1
    end
    -- Buddy Star Power Meter (3 stars!)
    gfx.rrect_o(14, 344, 64, 48, 10, alpha(C.CREAM, 230), C.INK, 1.8)
    gfx.text("STAR", 46, 348, 11, C.PURPLE, "center")
    for k = 1, 3 do
      gfx.star(24 + (k - 1) * 22, 374, 7.5, 0, k <= S.star_charge and C.GOLD or 0xb8aec4)
    end
  end

  -- Buddy + Trainer!
  if S.buddy then
    local bs = S.phase == "explore" and 0.88 or 1.15
    pics.draw_mon(S.buddy, S.bx, S.by, bs, S.phase == "gymwin", S.gym_atk_t)
  end
  pics.draw_trainer(S.px, S.py, S.fx, S.fy, S.walk_t, S.moving)

  -- Top HUD: Field Book 8-slot tracker + Badges + Score!
  gfx.rrect_o(8, 8, W - 16, 48, 12, C.CREAM, C.INK, 2)
  for i = 1, #MONS do
    local cx = 25 + (i - 1) * 24
    local active = S.buddy and S.buddy.id == i
    if active then gfx.circle(cx, 32, 11, alpha(C.GOLD, 180)) end
    gfx.circle_o(cx, 32, 8.5, S.dex[i] and MONS[i].col or 0xc8c0d0, C.INK, active and 2.2 or 1.4)
  end
  gfx.text("BADGES " .. S.badges, W - 16, 13, 13, C.PURPLE, "right")
  gfx.text("PTS " .. S.score, W - 16, 32, 13, C.INK, "right")

  -- Badge Victory Ceremony Card!
  if S.phase == "gymwin" then
    local _, bname = pics.badge_info(S.badges)
    gfx.rrect_o(36, 206, W - 72, 126, 16, C.CREAM, C.INK, 3)
    pics.draw_badge(W / 2, 240, S.badges, 1.0)
    gfx.text(bname .. " BADGE!", W / 2, 268, 22, C.GOLD, "center", C.INK)
    gfx.text("BADGES: " .. S.badges .. "   FRIENDS: " .. S.caught .. "/8", W / 2, 302, 13, C.PURPLE, "center")
  end

  particles.draw()
  local line = S.react_left > 0 and S.react or (
    S.phase == "gym" and ("Dodge & press for " .. (S.buddy and S.buddy.move or "STAR BEAM!")) or
    (S.aim and ("Press to toss a Friend Orb at " .. S.aim.mon.name .. "!") or
    (S.buddy and "Walk to the GYM, explore left/right, or TL/TR swap buddy!" or "Walk near a monster and press!")))
  if leaving() then line = "See you next time, Trainer!" end
  ui.band(line)
end
