-- Star Kart: a Mario-Kart-inspired arcade racer for 5+!
-- Walk-up band (CONTROLS.md). Stick steers left/right; LOW/TL/TR fires your Item Box power-up!
-- Race Pika-Kart, Zam-Kart, Char-Kart, and Pip-Kart across 3 vibrant tracks to the Grand Podium!
-- kart.sav keeps "best N" (high score) and "cups N" (cups won).

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, ROSE = 0xe86b9a,
  RED = 0xe84855, BLUE = 0x4a90e2, GREEN = 0x58c860, PURPLE = 0x8a5cf5,
  CYAN = 0x7fe8ff, PIKA = 0xffd838, ZAM = 0xf2c14e, CHAR = 0xf28c38, WHITE = 0xfffcf8,
}

local TRACKS = {
  {name = "Meadow Circuit", sky1 = 0x66c2ff, sky2 = 0xbef0ff, grass1 = 0x62c462, grass2 = 0x52b052,
   road = 0x6e7282, kerb1 = 0xe84855, kerb2 = 0xfff6ea, rainbow = false, len = 3600},
  {name = "Beach Boardwalk", sky1 = 0x4ab8ff, sky2 = 0xffe8b0, grass1 = 0xf4d28a, grass2 = 0xe8c070,
   road = 0xb88652, kerb1 = 0x4ac8ff, kerb2 = 0xfff6ea, rainbow = false, len = 4200},
  {name = "Rainbow Skyway", sky1 = 0x1a1438, sky2 = 0x382068, grass1 = 0x241848, grass2 = 0x1c123a,
   road = 0x4a3a7a, kerb1 = 0xffd84a, kerb2 = 0x7fe8ff, rainbow = true, len = 4800},
}

local RIVALS_DEF = {
  {name = "Pika", col = C.PIKA, trim = C.RED, ear = C.INK, base_spd = 4.65},
  {name = "Zam", col = C.ZAM, trim = C.PURPLE, ear = C.ZAM, base_spd = 4.50},
  {name = "Char", col = C.CHAR, trim = C.GOLD, ear = C.CHAR, base_spd = 4.35},
  {name = "Pip", col = 0xf29a3a, trim = C.CREAM, ear = 0xf29a3a, base_spd = 4.20},
}

local ITEMS = {"star", "shell", "shield", "zap"}
local ITEM_NAMES = {star = "Turbo Star!", shell = "Green Shell!", shield = "Bubble Shield!", zap = "Lightning Zap!"}

local race_bed = {bpm = 144, steps = 4,
  {"C5 . E5 . G5 . C6 . B5 . G5 . E5 . . . A5 . G5 . F5 . E5 . D5 . E5 . G5 . . . ",
   wave = "square", vol = 0.12, release = 0.05, attack = 0.004, duty = 0.25, pan = -0.2},
  {"C3 . C3 . G2 . G2 . A2 . A2 . E2 . E2 . F2 . F2 . C3 . C3 . G2 . G2 . G2 . . . ",
   wave = "tri", vol = 0.24, release = 0.06, attack = 0.004},
  {"K . H H S . H . K K H . S . H H ", wave = "noise", vol = 0.10, release = 0.04, pan = 0.2}}
local win_bed = {bpm = 132, steps = 2,
  {"C5 . E5 . G5 . C6 - A5 . G5 . E5 . C6 - ", wave = "tri", vol = 0.20, release = 0.22, attack = 0.008},
  {"C3 - G2 - A2 - E2 - F2 - C3 - G2 - C3 - ", wave = "sine", vol = 0.22, release = 0.24, attack = 0.01}}

local S = {
  phase = "race", track = 1, best = 0, cups = 0, score = 0, cup_pts = 0,
  px = 0, py = 384, dist = 0, spd = 0, lean = 0,
  item = nil, item_spin = 0, star_t = 0, boost_t = 0, shield = false, zap_t = 0, spin_t = 0,
  rivals = {}, boxes = {}, pads = {}, shells = {},
  saw_release = false, t = 0, finish_t = 0, place = 1,
  react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 100 end

local function road_curve(d)
  return sin(d * 0.0045) * 44 + sin(d * 0.0019 + S.track) * 24
end

local function world_to_screen(wx, wd)
  local rel = wd - S.dist
  if rel < -60 or rel > 460 then return nil end
  local k = clamp(1 - rel / 460, 0, 1)
  local sy = lerp(128, 396, k ^ 1.35)
  local halfw = lerp(42, 152, k ^ 1.25)
  local cx = W / 2 + (road_curve(wd) - road_curve(S.dist)) * (1 - k)
  local sx = cx + wx * halfw
  return sx, sy, lerp(0.32, 1.05, k ^ 1.2)
end

local function setup_race(tr)
  S.phase, S.track, S.dist, S.px, S.spd, S.lean = "race", tr, 0, 0, 2.5, 0
  S.item, S.item_spin, S.star_t, S.boost_t, S.shield, S.zap_t, S.spin_t = nil, 0, 0, 0, false, 0, 0
  S.rivals, S.boxes, S.pads, S.shells = {}, {}, {}, {}
  S.finish_t, S.place = 0, 1
  local T = TRACKS[tr]
  for i, r in ipairs(RIVALS_DEF) do
    S.rivals[i] = {
      name = r.name, col = r.col, trim = r.trim, ear = r.ear,
      x = -0.65 + (i - 1) * 0.42, d = 110 + i * 75, spd = r.base_spd + (tr - 1) * 0.22,
      spin = 0, phase = i * 1.4,
    }
  end
  for d = 300, T.len - 260, 400 do
    for b = -1, 1 do
      S.boxes[#S.boxes + 1] = {x = b * 0.55, d = d, gone = false}
    end
  end
  for d = 220, T.len - 220, 450 do
    S.pads[#S.pads + 1] = {x = ((floor(d / 450)) % 2 == 0 and -0.42 or 0.42), d = d}
  end
  log("kart race " .. tr)
  music.play(race_bed)
  react_to(T.name .. "! Go! Go! Go!")
end

local function calc_place()
  local p = 1
  for _, r in ipairs(S.rivals) do
    if r.d > S.dist then p = p + 1 end
  end
  S.place = p
  return p
end

local function use_item()
  if not S.item or S.item_spin > 0 then return end
  local it = S.item
  S.item = nil
  log("kart item " .. it)
  if it == "star" then
    S.star_t = 220
    S.score = S.score + 150
    sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.32)
    particles.burst(W / 2 + S.px * 145, S.py, 22, 3.2, 30, 3, C.GOLD, "star")
    react_to("TURBO STAR! Zoom past everyone!")
  elseif it == "shell" then
    -- Auto-aim at the nearest rival ahead!
    local tgt, bd = nil, 1e9
    for _, r in ipairs(S.rivals) do
      if r.d > S.dist and r.d - S.dist < bd then tgt, bd = r, r.d - S.dist end
    end
    S.shells[#S.shells + 1] = {x = S.px, d = S.dist + 20, tgt = tgt, life = 130}
    sfx.slide("square", 600, 1200, 0.14, 0.22)
    react_to("Green Shell! Watch out!")
  elseif it == "shield" then
    S.shield = true
    S.score = S.score + 100
    sfx.arp("sine", {76, 84}, 0.07, 0.26)
    particles.burst(W / 2 + S.px * 145, S.py, 16, 2.5, 24, 3, C.CYAN, "dot")
    react_to("Bubble Shield on!")
  elseif it == "zap" then
    S.zap_t = 180
    S.score = S.score + 150
    sfx.noise(0.18, 0.25, 3400)
    sfx.slide("square", 1200, 260, 0.22, 0.22)
    gfx.shake(4)
    for _, r in ipairs(S.rivals) do r.spin = 50 end
    react_to("LIGHTNING ZAP! Everyone shrunk!")
  end
end

local function finish_race()
  local p = calc_place()
  local pts = p == 1 and 500 or p == 2 and 350 or p == 3 and 250 or 150
  S.score = S.score + pts
  S.cup_pts = S.cup_pts + pts
  if S.score > S.best then S.best = S.score end
  if S.track == #TRACKS then
    S.phase, S.finish_t = "podium", 0
    if p <= 3 then S.cups = S.cups + 1 end
    save.set("best", S.best)
    save.set("cups", S.cups)
    save.write()
    log("kart podium " .. p)
    log("kart best " .. S.best)
    music.play(win_bed)
    sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
    react_to("You finished " .. (p == 1 and "1st!" or p == 2 and "2nd!" or p == 3 and "3rd!" or p .. "th!") .. " Trophy time!")
  else
    S.phase, S.finish_t = "clear", 0
    save.set("best", S.best)
    save.write()
    log("kart finish " .. S.track .. " " .. p)
    sfx.arp("tri", {72, 76, 79, 84}, 0.08, 0.34)
    react_to("Race " .. S.track .. " done! " .. (p == 1 and "1st place!" or p .. " place!"))
  end
  for i = 1, 32 do
    particles.spawn(W / 2 + rnd(-120, 120), 200, rnd(-3, 3), rnd(-5, -1), 80, rnd(3, 5),
      i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.CYAN, "star", 0.12, 0.99, 0.1)
  end
end

function bot()
  if S.phase == "clear" or S.phase == "podium" then
    if S.finish_t > 80 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  -- Steer toward boost pads or item boxes ahead, else center!
  local tx = 0
  if not S.item then
    for _, b in ipairs(S.boxes) do
      if not b.gone and b.d > S.dist + 10 and b.d < S.dist + 200 then tx = b.x break end
    end
  else
    for _, p in ipairs(S.pads) do
      if p.d > S.dist + 10 and p.d < S.dist + 180 then tx = p.x break end
    end
  end
  if tx < S.px - 0.12 then input.bot("left")
  elseif tx > S.px + 0.12 then input.bot("right") end
  if S.item and S.item_spin == 0 and game.frame % 10 == 0 then input.bot("low") end
end

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 999999)
  S.cups = clamp(save.get("cups", 0), 0, 100000)
  log("kart best " .. S.best)
  setup_race(1)
end

function quit()
  save.set("best", S.best)
  save.set("cups", S.cups)
  save.write()
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  S.t = S.t + 1
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "race" then
    local T = TRACKS[S.track]
    if S.star_t > 0 then S.star_t = S.star_t - 1 end
    if S.boost_t > 0 then S.boost_t = S.boost_t - 1 end
    if S.zap_t > 0 then S.zap_t = S.zap_t - 1 end
    if S.spin_t > 0 then S.spin_t = S.spin_t - 1 end
    if S.item_spin > 0 then
      S.item_spin = S.item_spin - 1
      if S.item_spin % 5 == 0 then sfx.tone("sine", 600 + (30 - S.item_spin) * 18, 0.04, 0.14) end
      if S.item_spin == 0 and S.item then
        sfx.arp("tri", {79, 84}, 0.05, 0.24)
        react_to("Got " .. ITEM_NAMES[S.item])
      end
    end

    -- Smooth Mario-Kart steering with gentle road-edge rails (never get stuck!).
    local steer = mx * 0.036
    S.px = clamp(S.px + steer, -0.92, 0.92)
    S.lean = approach(S.lean, mx, 0.2)
    local target_spd = 4.75 + (my < 0 and 0.35 or 0)
    if S.star_t > 0 then target_spd = 6.9
    elseif S.boost_t > 0 then target_spd = 6.5
    elseif S.spin_t > 0 then target_spd = 2.6 end
    S.spd = approach(S.spd, target_spd, 0.08)
    S.dist = S.dist + S.spd

    -- Boost pads.
    for _, p in ipairs(S.pads) do
      if abs(p.d - S.dist) < 22 and abs(p.x - S.px) < 0.32 and S.boost_t < 40 then
        S.boost_t = 70
        S.score = S.score + 75
        sfx.slide("sine", 520, 1280, 0.18, 0.24)
        particles.burst(W / 2 + S.px * 145, S.py + 12, 14, 2.8, 22, 3, C.CYAN, "star")
        react_to("WHOOSH! Rainbow Boost!")
      end
    end

    -- Item boxes.
    for _, b in ipairs(S.boxes) do
      -- (a box is left for later while his hands are full)
      if not b.gone and not S.item and abs(b.d - S.dist) < 24 and abs(b.x - S.px) < 0.28 then
        b.gone = true
        S.score = S.score + 50
        particles.burst(W / 2 + S.px * 145, S.py, 14, 2.4, 22, 3, C.GOLD, "star")
        S.item = ITEMS[rndi(1, #ITEMS)]
        S.item_spin = 26
      end
    end

    -- Shells auto-steer toward the rival ahead!
    for _, sh in ipairs(S.shells) do
      sh.d = sh.d + 9.5
      sh.life = sh.life - 1
      if sh.tgt then sh.x = approach(sh.x, sh.tgt.x, 0.18) end
      for _, r in ipairs(S.rivals) do
        if abs(r.d - sh.d) < 30 and abs(r.x - sh.x) < 0.32 then
          r.spin = 70
          sh.gone = true
          S.score = S.score + 150
          sfx.arp("tri", {79, 88}, 0.05, 0.3)
          local sx, sy = world_to_screen(r.x, r.d)
          if sx then particles.burst(sx, sy, 18, 3, 26, 3, C.GREEN, "star") end
          react_to("BONK! Hit " .. r.name .. "-Kart!")
          break
        end
      end
      if sh.life <= 0 then sh.gone = true end
    end
    sweep(S.shells, function(sh) return not sh.gone end)

    -- Rivals race with gentle rubber-banding so every race stays exciting!
    for _, r in ipairs(S.rivals) do
      if r.spin > 0 then
        r.spin = r.spin - 1
        r.d = r.d + 1.5
      else
        local rubber = clamp((S.dist - r.d) * 0.0025, -0.45, 0.55)
        local z = S.zap_t > 0 and 0.65 or 1
        r.d = r.d + (r.spd + rubber) * z
      end
      r.x = clamp(sin(S.t * 0.018 + r.phase) * 0.65, -0.78, 0.78)
      -- Bumping a rival: harmless bounce!
      if abs(r.d - S.dist) < 22 and abs(r.x - S.px) < 0.25 then
        if S.star_t > 0 then
          r.spin = 65
          S.score = S.score + 100
          sfx.note("tri", 88, 0.12, 0.26)
        elseif S.shield then
          S.shield = false
          r.spin = 45
          sfx.tone("sine", 780, 0.12, 0.24)
        else
          S.px = clamp(S.px + (S.px < r.x and -0.15 or 0.15), -0.9, 0.9)
          sfx.tone("sine", 320, 0.08, 0.16)
        end
      end
    end

    if pressed and S.saw_release then
      if S.item and S.item_spin == 0 then
        use_item()
      else
        -- Mini turbo hop on button press even without an item!
        sfx.slide("sine", 480, 720, 0.08, 0.14)
        particles.burst(W / 2 + S.px * 145, S.py + 16, 6, 1.6, 14, 2, C.GOLD, "dot")
      end
    end
    calc_place()
    if S.dist >= T.len then finish_race() end
  elseif S.phase == "clear" then
    S.finish_t = S.finish_t + 1
    if (pressed and S.saw_release and S.finish_t > 55) or S.finish_t > 180 then
      snd.ok()
      setup_race(S.track + 1)
    end
  elseif S.phase == "podium" then
    S.finish_t = S.finish_t + 1
    if S.finish_t % 14 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.5, 2), 80, rnd(3, 5),
        S.finish_t % 28 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.finish_t > 80) or S.finish_t > 280 then
      snd.ok()
      S.cup_pts, S.score = 0, 0
      setup_race(1)
    end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

local function draw_kart(x, y, s, col, trim, lean, spin, star)
  local body = star and hsv((game.frame * 0.06) % 1, 0.7, 1) or col
  local jx = spin and spin > 0 and sin(game.frame * 0.8) * 6 * s or 0
  x = x + jx
  gfx.ellipse(x, y + 16 * s, 22 * s, 6 * s, alpha(0x1a1428, 100))
  toon(function()
    toon.rrect(x - 20 * s, y + 2 * s, 8 * s, 14 * s, 3, C.INK)
    toon.rrect(x + 12 * s, y + 2 * s, 8 * s, 14 * s, 3, C.INK)
    toon.rrect(x - 16 * s, y - 8 * s, 32 * s, 20 * s, 7, body)
    toon.circle(x + lean * 3 * s, y - 14 * s, 11 * s, trim)
  end, 2 * s, C.INK)
  gfx.rrect(x - 10 * s, y - 2 * s, 20 * s, 5 * s, 2, trim)
  gfx.circle(x - 3 * s + lean * 3 * s, y - 16 * s, 1.8 * s, C.WHITE)
  gfx.circle(x + 3 * s + lean * 3 * s, y - 16 * s, 1.8 * s, C.WHITE)
end

function draw()
  local T = TRACKS[S.track]
  local HY = 128
  -- Sky + ground.
  gfx.blit(bake("sky" .. S.track, W, HY, function() gfx.vgrad(0, 0, W, HY, T.sky1, T.sky2) end), 0, 0)
  gfx.rect(0, HY, W, H - 32 - HY, T.grass1)
  if T.rainbow then
    for i = 1, 20 do
      local sx = (i * 53 + S.t * 0.2) % W
      local sy = (i * 29) % (HY - 16)
      gfx.circle(sx, sy, (i % 2) + 1, alpha(C.WHITE, 180))
    end
  end

  -- Scrolling perspective road strips (fast & super smooth!).
  local strips = 24
  for i = 0, strips - 1 do
    local k0, k1 = i / strips, (i + 1) / strips
    local y0, y1 = lerp(HY, H - 32, k0 ^ 1.35), lerp(HY, H - 32, k1 ^ 1.35)
    local d0 = S.dist + (1 - k0) * 460
    local cx = W / 2 + (road_curve(d0) - road_curve(S.dist)) * (1 - k0)
    local hw = lerp(42, 152, k0 ^ 1.25)
    local band = floor(d0 / 48) % 2 == 0
    if band then gfx.rect(0, y0, W, y1 - y0 + 1, T.grass2) end
    local rcol = T.rainbow and hsv(((d0 * 0.002) % 1), 0.55, 0.88) or T.road
    gfx.rect(cx - hw - 10 * k0 - 2, y0, (hw + 10 * k0 + 2) * 2, y1 - y0 + 1, band and T.kerb1 or T.kerb2)
    gfx.rect(cx - hw, y0, hw * 2, y1 - y0 + 1, rcol)
    if band then gfx.rect(cx - 2 - k0 * 2, y0, 4 + k0 * 4, y1 - y0 + 1, alpha(C.CREAM, 170)) end
  end

  -- Finish line checkerboard if visible!
  local fx, fy, fs = world_to_screen(0, T.len)
  if fx then
    local hw = 148 * fs
    for i = 0, 7 do
      gfx.rect(fx - hw + i * (hw / 4), fy - 5 * fs, hw / 4, 10 * fs, i % 2 == 0 and C.WHITE or C.INK)
    end
  end

  -- Boost pads.
  for _, p in ipairs(S.pads) do
    local sx, sy, sc = world_to_screen(p.x, p.d)
    if sx then
      gfx.rrect_o(sx - 22 * sc, sy - 6 * sc, 44 * sc, 12 * sc, 4, hsv((game.frame * 0.04) % 1, 0.8, 1), C.INK, 1.5)
    end
  end

  -- Item boxes.
  for _, b in ipairs(S.boxes) do
    if not b.gone then
      local sx, sy, sc = world_to_screen(b.x, b.d)
      if sx then
        local bob = sin(game.frame * 0.14 + b.d) * 3 * sc
        gfx.rrect_o(sx - 12 * sc, sy - 12 * sc + bob, 24 * sc, 24 * sc, 5, C.GOLD, C.INK, 2 * sc)
        gfx.text("?", sx, sy - 10 * sc + bob, max(10, floor(18 * sc)), C.INK, "center")
      end
    end
  end

  -- Rivals (drawn back-to-front by distance).
  for _, r in ipairs(S.rivals) do
    local sx, sy, sc = world_to_screen(r.x, r.d)
    if sx then draw_kart(sx, sy, sc * (S.zap_t > 0 and 0.65 or 1), r.col, r.trim, 0, r.spin, false) end
  end

  -- Shells.
  for _, sh in ipairs(S.shells) do
    local sx, sy, sc = world_to_screen(sh.x, sh.d)
    if sx then gfx.circle_o(sx, sy, 10 * sc, C.GREEN, C.INK, 2 * sc) end
  end

  -- Player kart!
  local px_scr = W / 2 + S.px * 145
  if S.boost_t > 0 or S.star_t > 0 then
    gfx.glow(px_scr, S.py + 12, 34, alpha(C.CYAN, 150))
  end
  draw_kart(px_scr, S.py, 1.15, C.RED, C.BLUE, S.lean, S.spin_t, S.star_t > 0)
  if S.shield then soap(px_scr, S.py - 2, 34, C.CYAN) end

  -- HUD: Place, Item Box slot, Score & Progress bar!
  gfx.rrect_o(10, 10, 82, 34, 10, C.CREAM, C.INK, 2)
  local pl = S.place == 1 and "1ST" or S.place == 2 and "2ND" or S.place == 3 and "3RD" or (S.place .. "TH")
  gfx.text(pl, 51, 14, 20, S.place == 1 and C.GOLD or C.PURPLE, "center", C.INK)
  -- Item box slot in center.
  gfx.rrect_o(W / 2 - 30, 8, 60, 44, 10, C.CREAM, C.INK, 2.5)
  if S.item then
    local shown = S.item_spin > 0 and ITEMS[(floor(S.item_spin / 3) % #ITEMS) + 1] or S.item
    if shown == "star" then gfx.star(W / 2, 30, 14, game.frame * 0.1, C.GOLD)
    elseif shown == "shell" then gfx.circle_o(W / 2, 30, 12, C.GREEN, C.INK, 2)
    elseif shown == "shield" then soap(W / 2, 30, 13, C.CYAN)
    else gfx.text("!", W / 2, 16, 26, C.PIKA, "center", C.INK) end
  end
  gfx.rrect_o(W - 116, 10, 106, 34, 10, C.CREAM, C.INK, 2)
  gfx.text(tostring(S.score), W - 63, 16, 17, C.INK, "center")
  -- Track progress bar.
  meter(72, 60, W - 144, 10, clamp(S.dist / T.len, 0, 1), C.GOLD)

  -- Race Clear / Grand Podium Banner!
  if S.phase == "clear" or S.phase == "podium" then
    local bw, bh = 316, 118
    local bx, by = (W - bw) / 2, 186
    gfx.rrect_o(bx, by, bw, bh, 14, C.CREAM, C.INK, 3)
    gfx.text(S.phase == "podium" and "GRAND PODIUM!" or ("FINISH! " .. pl), W / 2, by + 12, 28, C.GOLD, "center", C.INK)
    gfx.text("SCORE: " .. S.score .. "   CUPS: " .. S.cups, W / 2, by + 56, 15, C.PURPLE, "center")
    if S.finish_t > 60 and blink(40, 26) then
      gfx.text("PRESS TO RACE AGAIN!", W / 2, by + 84, 15, C.INK, "center")
    end
  end

  particles.draw()
  local line = S.react_left > 0 and S.react or (S.item and ("Press to use " .. ITEM_NAMES[S.item]) or (T.name .. "! Grab a ? box!"))
  if input.down("1p") and input.down("2p") then line = "Your cups and best score will stay!" end
  ui.band(line)
end
