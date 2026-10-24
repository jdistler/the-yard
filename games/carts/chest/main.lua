-- Chest: walk to the key, open the chest, take the sword, duel Zam.
-- Walk-up band (CONTROLS.md). The stick walks. Any button shoots.
-- In the fight the sword points at Zam by itself, so every shot flies at him and the
-- stick is for dodging, for stars, and for stepping out of purple rings.
-- Zam learns a new trick as the pile grows: a teleport, a shield, three bubbles at once.
-- A grown-up reads the cream band. chest.sav is "gems N". The spec is DESIGN.md beside this.

local pics = import("pictures")

local SPEED, POP_FRAMES, WRAP_FRAMES, REACT_FRAMES = 2, 60, 120, 120
local WIN_FRAMES, RESTART_FRAMES, SHOT_GAP, HOLD_GAP = 160, 60, 12, 30
local MARKS_WIN, ZX, ZY, FIGHT_TOP, TELE_FRAMES, SHIELD_FRAMES = 9, 192, 118, 300, 40, 90
local SPOTS = {128, 192, 256}
local KEY_SPOTS = {{128, 348}, {300, 356}, {72, 268}, {318, 270}, {84, 420}}
local C = pics.C

local function trunc(v) return v >= 0 and floor(v) or ceil(v) end

-- Everything the game knows. pictures.lua reads it to draw.
local S = {
  phase = "path", gems = 0, marks = 0, pips = 0, level = 0, marks_win = MARKS_WIN,
  nx = 200, ny = 420, face_x = 0, face_y = -1, has_key = false, has_sword = false, key_x = 128, key_y = 348,
  pop_t = 0, bow_t = 0, fight_t = 0, hop = 0, react_left = 0, react = "", shot_cool = 0, saw_release = false,
  telegraph = 0, spray = false, fairy = nil, fairy_x = 0, fairy_y = 0, wrap = 0, wrap_alive = false,
  ring = nil, star = nil, splash = nil, hurt_cool = 0, shot_once = false, spoon_flash = 0, goodbye = false,
  zx = ZX, zy = ZY, spot = 2, tele_t = 0, tele_to = 2, shield_t = 0, flinch_t = 0, dizzy_t = 0, bend_t = 0,
  bubbles = {}, beam = nil, walk_t = 0, pile_hop = 0, moving = false, prize_t = 0, prize_kind = 0, deco = {},
  TELE_FRAMES = TELE_FRAMES, SHIELD_FRAMES = SHIELD_FRAMES, ZX = ZX, ZY = ZY,
}
pics.S = S

local path_bed = {bpm = 96, steps = 2,
  {"C5 . E5 . G5 . E5 . D5 . F5 . A5 . G5 . ", wave = "tri", vol = 0.08, release = 0.2, attack = 0.01, pan = -0.2},
  {"C3 - - - G2 - - - D3 - - - G2 - - - ", wave = "sine", vol = 0.16, release = 0.3, attack = 0.02},
  {"H . . . H . . . H . . . H . H . ", wave = "noise", vol = 0.03, release = 0.04, pan = 0.3}}
local fight_bed = {bpm = 132, steps = 4,
  {"G4 . . G4 A4 . C5 . G4 . . E4 D4 . E4 . G4 . . G4 A4 . C5 . D5 . C5 . A4 . . . ", wave = "square", vol = 0.045, release = 0.06, attack = 0.005, duty = 0.25, pan = -0.2},
  {"C3 . C3 . G2 . G2 . A2 . A2 . F2 . G2 . ", wave = "tri", vol = 0.2, release = 0.06, attack = 0.004},
  {"K . H . S . H . K . H K S . H . ", wave = "noise", vol = 0.06, release = 0.05, pan = 0.2}}

local function tone(hz, dur, vol) sfx.tone("tri", hz, dur, vol) end
local function notes(m, step, vol) sfx.arp("tri", m, step, vol) end

-- ------------------------------------------------------------------ the rules

local function react_to(s) S.react, S.react_left = s, REACT_FRAMES end
local function near_chest() return S.ny < 268 and S.nx > 156 and S.nx < 236 end
local function near_key() return (S.nx - S.key_x) ^ 2 + (S.ny - S.key_y) ^ 2 < 36 * 36 end
-- Zam can be hit when he is all there: not mid-teleport.
local function zam_solid() return S.tele_t == 0 or S.tele_t > TELE_FRAMES - 4 end

local function clear_fight()
  S.marks, S.pips, S.fight_t, S.telegraph, S.spray = 0, 0, 0, 0, false
  S.bubbles, S.fairy, S.wrap, S.wrap_alive, S.ring, S.star = {}, nil, 0, false, nil, nil
  S.shot_once, S.hurt_cool, S.tele_t, S.shield_t, S.spot, S.zx = false, 0, 0, 0, 2, ZX
  -- He learns a trick for each of the first three gems, and takes three more zaps each time.
  S.level = min(S.gems, 3)
  S.marks_win = MARKS_WIN + 3 * S.level
end

local function take_key()
  S.has_key = true
  log("chest key " .. game.frame)
  sfx.note("tri", 84, 0.3, 0.35)
  sfx.note("sine", 96, 0.2, 0.15)
  particles.burst(S.key_x, S.key_y - 20, 18, 2.5, 34, 2.5, C.GOLD, "star")
  react_to("The key is his.")
end

local function begin_pop()
  if S.phase ~= "path" or not S.has_key then return end
  S.phase, S.pop_t = "pop", 0
  log("chest pop " .. game.frame)
  notes({72, 76, 79, 84}, 0.08, 0.35)
  gfx.shake(4)
  particles.burst(ZX, 170, 30, 3.5, 40, 3, C.GOLD, "star")
  music.play(fight_bed)
  react_to("Pop! He threw the sword.")
  S.react_left = 80
end

local function begin_win()
  S.phase, S.bow_t = "winbow", 0
  S.prize_kind, S.prize_t = S.gems % 8, 1
  if S.gems < 100000 then S.gems = S.gems + 1 end
  save.set("gems", S.gems)
  save.write()
  log("chest win " .. game.frame)
  log("chest gems " .. S.gems)
  notes({72, 76, 79, 84, 88}, 0.1, 0.38)
  for i = 1, 30 do
    particles.spawn(S.zx + rnd(-40, 40), S.zy, rnd(-3, 3), rnd(-5, -1), 70, rnd(3, 5), i % 3 ~= 0 and C.ROSE or C.GOLD,
      i % 2 == 0 and "star" or "square", 0.15, 0.99, 0.1)
  end
  S.bubbles, S.tele_t, S.shield_t, S.ring, S.star, S.fairy = {}, 0, 0, nil, nil, nil
  music.play(path_bed)
  react_to("Treasure for the pile.")
end

local function add_marks(n, big)
  S.marks = S.marks + n
  S.spoon_flash, S.flinch_t = 16, 14
  if big then
    log("chest big")
    notes({79, 84}, 0.07, 0.4)
    gfx.shake(5)
    S.dizzy_t = 70
    particles.burst(S.zx, S.zy, 34, 4, 40, 3, C.GOLD, "star")
    particles.text(S.zx, S.zy - 80, C.GOLD, "+3")
    react_to("The big bubble popped.")
  else
    log("chest mark " .. S.marks)
    sfx.slide("square", 900, 600, 0.08, 0.18)
    particles.burst(S.zx, S.zy - 10, 10, 2, 24, 2, C.CREAM, "star")
    react_to("The sword zapped him.")
  end
  if S.marks >= S.marks_win and S.phase == "fight" then begin_win() end
end

local function hurt()
  if S.phase ~= "fight" or S.hurt_cool > 0 then return end
  S.pips, S.hurt_cool = S.pips + 1, 40
  S.ny = min(S.ny + 16, 450)
  log(fmt("chest hurt %d %d", S.pips, game.frame))
  sfx.slide("tri", 300, 110, 0.25, 0.35)
  gfx.shake(4)
  particles.burst(S.nx, S.ny - 10, 14, 2.5, 30, 3, C.PURPLE, "ring")
  if S.pips >= 3 then
    S.phase, S.bow_t = "restart", 0
    log("chest restart " .. game.frame)
    notes({79, 76}, 0.14, 0.3)
    react_to("Pop. The sword stayed.")
  else
    react_to("That bubble got him.")
  end
end

-- Before the sword: a short spark the way he faces, which can also tap the key and the lock.
local function spark()
  local x, y, dx, dy = S.nx, S.ny - 8, S.face_x, S.face_y
  if dx == 0 and dy == 0 then dy = -1 end
  log("chest bolt")
  sfx.tone("sine", 1300, 0.07, 0.2)
  local x0, y0 = x, y
  for _ = 1, 52 do
    x, y = x + dx, y + dy
    if not S.has_key and (x - S.key_x) ^ 2 + (y - S.key_y) ^ 2 < 30 * 30 then take_key() end
    if S.has_key and S.phase == "path" and y < 268 and x > 156 and x < 236 then begin_pop() end
  end
  S.beam = {x0 = x0, y0 = y0, x1 = x, y1 = y, t = 7, blocked = false}
end

-- With the sword: a laser that flies at Zam. A shield stops it, an empty spot lets it pass.
local function laser()
  local sx, sy = S.nx, S.ny - 12
  log("chest bolt")
  snd.zap()
  S.beam = {x0 = sx, y0 = sy, x1 = S.zx, y1 = S.zy, t = 10, blocked = false}
  S.shot_once = true
  if S.phase ~= "fight" then return end
  if not zam_solid() then
    -- He is not there: the laser flies on to the top of the meadow.
    S.beam.x1, S.beam.y1 = trunc(sx + (S.zx - sx) * 1.6), 8
    S.splash = {S.beam.x1, S.beam.y1}
    return
  end
  if S.shield_t > 0 and S.wrap == 0 then
    local k = (sy - (S.zy + 62)) / (sy - S.zy)
    S.beam.x1, S.beam.y1, S.beam.blocked = trunc(sx + (S.zx - sx) * k), S.zy + 62, true
    S.splash = {S.beam.x1, S.beam.y1}
    sfx.note("sine", 100, 0.15, 0.2)
    react_to("His shield is up. Wait.")
    log("chest blocked")
    return
  end
  if S.wrap > 0 then
    S.wrap, S.wrap_alive = 0, false
    add_marks(3, true)
  else
    add_marks(1, false)
  end
end

local function fire()
  if S.has_sword and S.phase ~= "path" then laser() else spark() end
  if S.splash then particles.burst(S.splash[1], S.splash[2], 8, 2, 18, 2, S.beam.blocked and C.CYAN or C.CREAM, "dot") end
end

local function spawn_bubbles()
  local n = S.spray and 3 or 1
  for k = 0, n - 1 do
    local bx, by = S.zx + (k - (n - 1) / 2) * 30, S.zy - 30
    local a = math.atan(S.ny - by, S.nx - bx) + (k - (n - 1) / 2) * 0.38
    S.bubbles[#S.bubbles + 1] = {x = bx, y = by, vx = cos(a) * 2.3, vy = sin(a) * 2.3}
  end
  sfx.slide("sine", 500, 300, 0.2, 0.2)
end

local function begin_teleport()
  local to
  repeat to = rndi(1, 3) until to ~= S.spot
  S.tele_t, S.tele_to = TELE_FRAMES, to
  sfx.slide("sine", 400, 1600, 0.25, 0.2)
  react_to("Zam jumped! Find him.")
  log("chest teleport " .. (to - 1))
end

local function wrap_him(x, y, kind, line)
  S.wrap, S.wrap_alive = WRAP_FRAMES, true
  S.bubbles, S.telegraph, S.shield_t = {}, 0, 0
  log("chest wrap " .. game.frame)
  sfx.note("sine", 88, 0.4, 0.3)
  particles.burst(x, y, 16, 2.5, 30, 2.5, C.GOLD, kind)
  react_to(line)
end

local function step_to_int(v, d, max_step) return v + (d > max_step and max_step or d < -max_step and -max_step or d) end

local function fight_step()
  S.fight_t = S.fight_t + 1
  if S.wrap > 0 then
    S.wrap = S.wrap - 1
    if S.wrap == 0 and S.wrap_alive then
      S.wrap_alive = false
      add_marks(1, false)
    end
  end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.spoon_flash > 0 then S.spoon_flash = S.spoon_flash - 1 end
  if S.phase ~= "fight" then return end
  -- His rhythm, from the second fight on, every five seconds: the spoons glow and the
  -- bubbles come (he is open), then his shield goes up (zaps bounce off), then he
  -- teleports. On the first fight there is only a bubble every two and a half seconds.
  local len = S.level == 0 and 150 or 300
  local c = S.fight_t % len
  if S.tele_t > 0 then
    S.tele_t = S.tele_t - 1
    if S.tele_t == TELE_FRAMES // 2 then
      S.spot = S.tele_to
      S.zx = SPOTS[S.spot]
      particles.burst(S.zx, S.zy, 16, 2, 26, 2.5, 0xc8a8ff, "star")
    end
  elseif S.level >= 1 and c == (S.level >= 2 and 250 or 180) and S.wrap == 0 then
    begin_teleport()
  end
  if S.shield_t > 0 then
    S.shield_t = S.shield_t - 1
    if S.wrap > 0 then S.shield_t = 0 end
  elseif S.level >= 2 and c == 150 and S.wrap == 0 and S.tele_t == 0 then
    S.shield_t = SHIELD_FRAMES
    sfx.note("sine", 88, 0.3, 0.25)
    sfx.note("sine", 95, 0.3, 0.12)
    react_to("His shield is up. Wait.")
    log("chest shield")
  end
  if S.telegraph > 0 then
    S.telegraph = S.telegraph - 1
    if S.telegraph == 0 then spawn_bubbles() end
  elseif S.wrap == 0 and not S.fairy and S.tele_t == 0 and c == 40 then
    S.telegraph = 30
    S.spray = S.level >= 3 and (S.fight_t // len) % 2 == 1
    tone(S.spray and 587 or 659, 0.12, 0.2)
    if S.spray then react_to("Three bubbles! Step away.") end
  end
  for _, b in ipairs(S.bubbles) do
    b.x, b.y = b.x + b.vx, b.y + b.vy
    if (b.x - S.nx) ^ 2 + (b.y - S.ny) ^ 2 < 28 * 28 then
      b.gone = true
      hurt()
    elseif b.y > H - 40 or b.x < 0 or b.x > W then
      b.gone = true
    end
  end
  sweep(S.bubbles, function(b) return not b.gone end)
  if not S.fairy and S.wrap == 0 and not S.ring and not S.star then
    local t = S.fight_t
    if t == 70 or t == 460 then S.fairy, S.fairy_x, S.fairy_y = "gold", 40, 180
    elseif t == 250 then S.fairy, S.fairy_x, S.fairy_y = "blue", 340, 240
    elseif (S.shot_once and t == 190) or t == 520 then S.fairy, S.fairy_x, S.fairy_y = "purple", 48, 300 end
    if S.fairy then sfx.note("sine", S.fairy == "purple" and 67 or 88, 0.2, 0.18) end
  end
  if S.fairy == "gold" then
    local dx, dy = trunc(S.zx) - S.fairy_x, trunc(S.zy) + 12 - S.fairy_y
    S.fairy_x, S.fairy_y = step_to_int(S.fairy_x, dx, 4), step_to_int(S.fairy_y, dy, 4)
    if abs(dx) < 12 and abs(dy) < 12 and zam_solid() then
      S.fairy = nil
      wrap_him(S.zx, S.zy, "glow", "Gold fairy has him.")
    end
  elseif S.fairy then
    local dx, dy = S.nx - S.fairy_x, S.ny - S.fairy_y
    S.fairy_x, S.fairy_y = step_to_int(S.fairy_x, dx, 3), step_to_int(S.fairy_y, dy, 3)
    if abs(dx) < 14 and abs(dy) < 14 then
      S.ring = {x = S.nx, y = S.ny, r = 8, safe = S.fairy == "blue"}
      S.fairy = nil
    end
  end
  local ring = S.ring
  if ring then
    local inside = (S.nx - ring.x) ^ 2 + (S.ny - ring.y) ^ 2 < (ring.r + 6) ^ 2
    if not ring.safe and not inside then
      S.ring = nil
      tone(880, 0.08, 0.25)
      particles.burst(ring.x, ring.y, 12, 2, 20, 2, C.PURPLE, "dot")
    elseif ring.safe and ring.r > 22 then
      S.ring = nil
      S.star = {x = S.nx < 60 and S.nx + 28 or S.nx - 28, y = S.ny, life = 180}
      log("chest star " .. game.frame)
      notes({76, 79}, 0.1, 0.3)
      particles.burst(S.nx, S.ny, 14, 2.5, 24, 2, C.BLUE, "dot")
      react_to("Walk over the star.")
    elseif not ring.safe and ring.r > 26 and inside then
      S.ring = nil
      hurt()
    else
      ring.r = ring.r + 1
      if not ring.safe and ring.r % 4 == 0 then sfx.tone("sine", 300 + ring.r * 12, 0.06, 0.08) end
    end
  end
  local star = S.star
  if star then
    if (S.nx - star.x) ^ 2 + (S.ny - star.y) ^ 2 < 22 * 22 then
      S.star, S.tele_t = nil, 0
      wrap_him(star.x, star.y, "star", "The star wrapped him.")
    else
      star.life = star.life - 1
      if star.life <= 0 then S.star = nil end
    end
  end
end

local function leaving() return input.down("1p") and input.down("2p") end

local function rest_line()
  if leaving() then return "The gems will stay." end
  local p = S.phase
  if p == "pop" then return "Pop! He threw the sword." end
  if p == "winbow" then return "Treasure for the pile." end
  if p == "restart" then return "Pop. The sword stayed." end
  if p == "fight" then
    if S.tele_t > 0 then return "Zam jumped! Find him." end
    if S.telegraph > 0 then return S.spray and "Three bubbles! Step away." or "A bubble is coming." end
    if S.wrap > 0 then return "Gold fairy has him." end
    if S.shield_t > 0 then return "His shield is up. Wait." end
    if S.ring and S.ring.safe then return "A blue bubble. Catch it." end
    if S.star then return "Walk over the star." end
    if S.ring then return "Purple. Step out of it." end
    if not S.shot_once then return "The sword can zap him." end
    return "Gold one. He's the boss."
  end
  if not S.has_key then
    if S.hop > 0 then return "The lock wants the key." end
    local dx, dy = input.dir()
    if dx ~= 0 or dy ~= 0 then return "He walks to the key." end
    return "The key is glowing."
  end
  return "Now walk to the chest."
end

-- ------------------------------------------------------------------ the built-in player (tests, the reel)

function bot()
  local tx, ty = S.nx, S.ny
  if S.phase == "path" then
    tx, ty = S.has_key and ZX or S.key_x, S.has_key and 240 or S.key_y
  elseif S.phase == "fight" then
    tx, ty = trunc(S.zx) + (sin(game.frame * 0.012) > 0 and -40 or 40), 400
    if S.star then tx, ty = S.star.x, S.star.y end
    if S.ring and not S.ring.safe then tx, ty = S.ring.x + (S.ring.x < ZX and 80 or -80), S.ring.y end
    for _, b in ipairs(S.bubbles) do
      if abs(b.x - S.nx) < 50 and b.y < S.ny then tx = S.nx + (b.x < S.nx and 70 or -70) end
    end
  else
    return
  end
  if not (abs(tx - S.nx) < 6 and abs(ty - S.ny) < 6) then
    if tx < S.nx - 2 then input.bot("left") end
    if tx > S.nx + 2 then input.bot("right") end
    if ty < S.ny - 2 then input.bot("up") end
    if ty > S.ny + 2 then input.bot("down") end
  end
  -- With the sword, shoot whenever the shield is down.
  if S.phase == "fight" and S.shield_t == 0 and game.frame % 2 == 1 then input.bot("low") end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.17)
  sfx.limit(3000)
  S.gems = clamp(save.get("gems", 0), 0, 100000)
  log("chest gems " .. S.gems)
  for i = 1, 40 do
    local x
    repeat x = rnd(16, W - 16) until not (x > 128 and x < 256)
    S.deco[i] = {x, rnd(80, H - 32 - 8), rndi(0, 4)}
  end
  music.play(path_bed)
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  S.splash = nil
  if not held then S.saw_release = true end
  S.moving = false
  if S.phase == "pop" then
    -- He hops back to the fighting line while Zam unfolds.
    S.nx = S.nx + trunc((ZX - S.nx) * 0.08)
    if S.ny < 400 then S.ny = S.ny + 3 end
  elseif S.phase ~= "winbow" and S.phase ~= "restart" then
    local top = S.phase == "fight" and FIGHT_TOP or 230
    S.nx = clamp(S.nx + mx * SPEED, 24, W - 24)
    S.ny = clamp(S.ny + my * SPEED, top, 450)
    if mx ~= 0 or my ~= 0 then
      S.moving = true
      S.walk_t = S.walk_t + 1
      S.face_x, S.face_y = mx, my
      if mx ~= 0 and my ~= 0 then S.face_x = 0 end
      if S.walk_t % 16 == 0 then particles.spawn(S.nx, S.ny + 32, rnd(-0.5, 0.5), -0.3, 18, 2.5, alpha(0xe8f0d0, 160), "dot") end
    end
  end
  if not S.has_key and near_key() then take_key() end
  if S.phase == "path" and near_chest() then
    if S.has_key then
      begin_pop()
    elseif S.hop == 0 then
      S.hop = 10
      tone(330, 0.1, 0.25)
      react_to("The lock wants the key.")
    end
  end
  if S.shot_cool > 0 then S.shot_cool = S.shot_cool - 1 end
  -- A press fires at once (no faster than five a second); a held button repeats twice a second.
  if S.saw_release and S.phase ~= "winbow" and S.phase ~= "restart"
      and ((pressed and S.shot_cool <= HOLD_GAP - SHOT_GAP) or (held and not pressed and S.shot_cool == 0)) then
    fire()
    S.shot_cool = HOLD_GAP
  end
  if S.phase == "pop" then
    S.pop_t = S.pop_t + 1
    if S.pop_t >= POP_FRAMES then
      S.phase, S.has_sword = "fight", true
      clear_fight()
      log("chest sword " .. game.frame)
      log("chest level " .. S.level)
    end
  elseif S.phase == "fight" then
    fight_step()
  elseif S.phase == "winbow" then
    S.bow_t = S.bow_t + 1
    if S.bow_t > 20 and S.bend_t < 40 then S.bend_t = S.bend_t + 1 end
    if S.prize_t > 0 then
      S.prize_t = S.prize_t + 1
      if S.prize_t > 60 then
        S.prize_t, S.pile_hop = 0, 30
        sfx.note("sine", 91, 0.2, 0.2)
      end
    end
    if S.bow_t >= WIN_FRAMES then
      S.phase, S.has_key, S.has_sword, S.bend_t = "path", false, false, 0
      clear_fight()
      local k = KEY_SPOTS[rndi(2, 5)]
      S.key_x, S.key_y = k[1], k[2]
      S.react, S.react_left = "The key is back. Go on.", REACT_FRAMES
    end
  elseif S.phase == "restart" then
    S.bow_t = S.bow_t + 1
    if S.bow_t >= RESTART_FRAMES then
      S.phase, S.has_sword = "fight", true
      clear_fight()
    end
  end
  for _, k in ipairs({"hop", "pile_hop", "react_left", "flinch_t", "dizzy_t"}) do
    if S[k] > 0 then S[k] = S[k] - 1 end
  end
  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  pics.draw()
  particles.draw()
  local line = S.react_left > 0 and S.react or rest_line()
  if leaving() then line = rest_line() end
  ui.band(line)
end
