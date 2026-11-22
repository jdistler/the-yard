-- Dig v2: a faithful, kid-friendly Dig Dug homage!
-- Walk-gated homage chiptune (plays as you dig, speeds up on the last critter!),
-- escalating Caves 1-5+, classic boulder drops + center bonus veggies, and score + gem tracking.
-- Walk-up band (CONTROLS.md). The stick digs and walks. Any right-hand button puffs the pump.
-- A grown-up reads the cream band. dig.sav keeps "best N", "hi N", and "gems N".

local pics = import("pictures")
local C = pics.C

local COLS, ROWS, TILE, TOP = 12, 12, 32, 96
local SPEED_TUNNEL, SPEED_DIRT = 2.4, 2.0
local PUMP_RANGE, PUMP_GAP, HOLD_GAP = 88, 12, 22
local REACT_FRAMES, CLEAR_MIN, CLEAR_AUTO = 110, 90, 260

local function col_x(c) return (c - 0.5) * TILE end
local function row_y(r) return TOP + (r - 0.5) * TILE end
local function x_col(x) return clamp(floor(x / TILE) + 1, 1, COLS) end
local function y_row(y) return clamp(floor((y - TOP) / TILE) + 1, 1, ROWS) end

local S = {
  COLS = COLS, ROWS = ROWS, TILE = TILE, TOP = TOP,
  phase = "play", level = 1, best = 0, hi = 0, score = 0, gems = 0, hurts = 0, hurt_cool = 0,
  px = col_x(6), py = row_y(5), face_x = 1, face_y = 0, moving = false, still_t = 0, walk_t = 0,
  dug = {}, foes = {}, rocks = {}, gems_list = {}, flames = {}, pebbles = {},
  veggie = nil, rocks_dropped = 0, last_rush = false,
  pump = nil, aim = nil, shot_cool = 0, saw_release = false,
  react = "", react_left = 0, clear_t = 0, restart_t = 0, goodbye = false,
}
pics.S = S

-- Revamped 128-step, 5-track arcade chiptunes!
-- Cave 1, 3, 5+: Bouncy G-major Dig-Dug-inspired underground adventure (A + B + turnaround).
local dig_bed = {bpm = 142, steps = 4,
  -- Track 1: Lead (punchy 25% pulse wave)
  {"G4 . B4 D5 . B4 G4 . D5 . B4 . G4 . . . " ..
   "A4 . C5 E5 . C5 A4 . D5 . B4 . G4 . . . " ..
   "G4 . B4 D5 . E5 F#5 . G5 . E5 D5 . B4 . . " ..
   "C5 . B4 A4 . G4 F#4 . G4 . D5 . G4 . . . " ..
   "E5 . G5 E5 . D5 C5 . D5 . F#5 D5 . C5 B4 . " ..
   "C5 . E5 C5 . B4 A4 . B4 . D5 . E5 . . . " ..
   "C5 . D5 E5 . F#5 G5 . A5 . G5 F#5 . E5 D5 . " ..
   "E5 . D5 C5 . B4 A4 . D5 . F#5 . G5 . . . ",
   wave = "square", vol = 0.20, release = 0.045, attack = 0.003, duty = 0.25, pan = -0.2},
  -- Track 2: Counter-harmony & off-beat stabs (crisp 12.5% pulse)
  {". . . . G4 . . . B4 . . . D5 B4 G4 . " ..
   ". . . . A4 . . . F#4 . . . B4 G4 D4 . " ..
   ". . . . B4 . . . E5 . . . B4 . G4 . " ..
   "E4 . G4 F#4 . D4 . . B4 . G4 . D4 B4 G4 . " ..
   "G4 . C5 . G4 . E4 . F#4 . A4 . F#4 . D4 . " ..
   "E4 . G4 . E4 . C4 . G4 . B4 . G4 . E4 . " ..
   "E4 . G4 C5 . A4 B4 . C5 . B4 A4 . G4 F#4 . " ..
   "G4 . F#4 E4 . D4 C4 . F#4 . A4 . B4 . . . ",
   wave = "square", vol = 0.12, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
  -- Track 3: Bouncy octave-walking triangle bass
  {"G2 . G3 . D3 . G2 . G2 . G3 . B2 . D3 . " ..
   "A2 . A3 . E3 . C3 . D3 . A2 . G2 . D3 . " ..
   "G2 . G3 . D3 . B2 . C3 . C4 . G3 . E3 . " ..
   "A2 . E3 . D3 . F#2 . G2 . D3 . G2 . B2 . " ..
   "C3 . C4 . G3 . E3 . B2 . B3 . F#3 . D3 . " ..
   "A2 . A3 . E3 . C3 . E2 . E3 . B2 . G2 . " ..
   "C3 . G2 . C3 . E3 . D3 . A2 . D3 . F#3 . " ..
   "C3 . G2 . A2 . E3 . D3 . F#2 . G2 . D3 . ",
   wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
  -- Track 4: Underground crystal shimmer on B-section
  {". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . D6 B5 G5 . " ..
   "G5 . C6 . E6 . C6 . F#5 . B5 . D6 . B5 . " ..
   "E5 . A5 . C6 . A5 . G5 . B5 . E6 . B5 . " ..
   "G5 . C6 . E6 . C6 . A5 . D6 . F#6 . D6 . " ..
   "G5 . C6 . A5 . E6 . F#5 . A5 . G5 . . . ",
   wave = "sine", vol = 0.10, release = 0.09, attack = 0.005, pan = 0.15},
  -- Track 5: Tight arcade percussion with bar-4 & bar-8 fills
  {"K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K S S H C . . . " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . S . K S S S K . S . C . . . ",
   wave = "noise", vol = 0.14, release = 0.035, pan = 0.15}}

-- Cave 2, 4, 6+: Mysterious & funky Deep Cavern Groove (146 BPM in D Minor / F Major!).
local deep_bed = {bpm = 146, steps = 4,
  {"D5 . F5 A5 . G5 F5 . E5 . G5 F5 . D5 . . " ..
   "C5 . E5 G5 . F5 E5 . D5 . F5 . A4 . . . " ..
   "D5 . F5 A5 . Bb5 A5 . G5 . E5 C5 . E5 . . " ..
   "F5 . G5 A5 . G5 E5 . D5 . A4 . D5 . . . " ..
   "F5 . A5 C6 . Bb5 A5 . G5 . Bb5 A5 . G5 F5 . " ..
   "E5 . G5 Bb5 . A5 G5 . F5 . A5 . D5 . . . " ..
   "Bb4 . D5 F5 . G5 A5 . G5 . E5 C5 . E5 G5 . " ..
   "A5 . G5 F5 . E5 C#5 . D5 . A4 . D5 . . . ",
   wave = "square", vol = 0.20, release = 0.045, attack = 0.003, duty = 0.25, pan = -0.2},
  {". . . . D5 . . . C5 . . . A4 F4 D4 . " ..
   ". . . . C5 . . . A4 . . . F4 D4 A4 . " ..
   ". . . . F5 . . . E5 . . . G4 . C5 . " ..
   "D5 . E5 F5 . E5 C#5 . A4 . F4 . D4 A4 F4 . " ..
   "A4 . C5 . F5 . C5 . Bb4 . D5 . G5 . D5 . " ..
   "G4 . Bb4 . E5 . C5 . A4 . D5 . F5 . A4 . " ..
   "D4 . F4 Bb4 . D5 F5 . E5 . C5 G4 . C5 E5 . " ..
   "F5 . E5 D5 . C#5 A4 . F4 . A4 . D5 . . . ",
   wave = "square", vol = 0.12, release = 0.04, attack = 0.003, duty = 0.125, pan = 0.25},
  {"D2 . D3 . A2 . F2 . C2 . C3 . G2 . E2 . " ..
   "Bb2 . F2 . C3 . G2 . D2 . A2 . D2 . F2 . " ..
   "D2 . D3 . A2 . F2 . C2 . C3 . G2 . E2 . " ..
   "Bb2 . F2 . A2 . E2 . D2 . A2 . D2 . F2 . " ..
   "F2 . F3 . C3 . A2 . G2 . G3 . D3 . Bb2 . " ..
   "C3 . G2 . E2 . C2 . D2 . A2 . D3 . A2 . " ..
   "Bb2 . F2 . Bb2 . D3 . C3 . G2 . C3 . E3 . " ..
   "A2 . E2 . A2 . C#3 . D2 . A2 . D2 . . . ",
   wave = "tri", vol = 0.30, release = 0.055, attack = 0.003},
  {". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . . . . . " ..
   ". . . . . . . . . . . . A5 F5 D5 . " ..
   "A5 . C6 . F6 . C6 . Bb5 . D6 . G6 . D6 . " ..
   "G5 . Bb5 . E6 . C6 . A5 . D6 . F6 . D6 . " ..
   "F5 . Bb5 . D6 . Bb5 . G5 . C6 . E6 . C6 . " ..
   "A5 . E6 . G6 . E6 . F6 . D6 . A5 . . . ",
   wave = "sine", vol = 0.10, release = 0.09, attack = 0.005, pan = 0.15},
  {"K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K S S H C . . . " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . S . K S S S K . S . C . . . ",
   wave = "noise", vol = 0.14, release = 0.035, pan = 0.15}}

-- Harmonized 4-track Cave Clear Victory Fanfare!
local clear_bed = {bpm = 144, steps = 4,
  {"G4 . B4 . D5 . G5 - - . F#5 . G5 . A5 . B5 - - - G5 . D5 . B4 . D5 . G5 - - . ",
   wave = "square", vol = 0.19, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
  {"D4 . G4 . B4 . D5 - - . C5 . B4 . C5 . D5 - - - B4 . G4 . D4 . G4 . B4 - - . ",
   wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
  {"G2 - D3 - G2 - B2 - C3 - G2 - D3 - A2 - G2 - D3 - E2 - B2 - C3 - D3 - G2 - - . ",
   wave = "sine", vol = 0.26, release = 0.20, attack = 0.01},
  {"K . . . S . . . K . K . C . . . K . . . S . . . K . S S C . . . ",
   wave = "noise", vol = 0.12, release = 0.04}}

local function react_to(s) S.react, S.react_left = s, REACT_FRAMES end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.hi then S.hi = S.score end
end

local function stratum_col(r)
  if r <= 3 then return C.L1 elseif r <= 6 then return C.L2 elseif r <= 9 then return C.L3 else return C.L4 end
end

local function is_dug(c, r)
  return r >= 1 and r <= ROWS and c >= 1 and c <= COLS and S.dug[r][c]
end

local function dig_cell(c, r, silent)
  if r < 1 or r > ROWS or c < 1 or c > COLS or S.dug[r][c] then return false end
  S.dug[r][c] = true
  if not silent then
    local x, y = col_x(c), row_y(r)
    particles.burst(x, y, 7, 1.8, 18, 2.5, stratum_col(r), "square")
    sfx.noise(0.05, 0.12, 1800)
  end
  return true
end

local function rock_at_cell(c, r)
  for _, rk in ipairs(S.rocks) do
    if rk.state == "rest" and rk.c == c and rk.r == r then return rk end
  end
  return nil
end

-- Escalating caves 1..5+ with richer critter layouts and boulder placements.
local POCKETS = {
  {c0 = 2, r0 = 3, w = 3, h = 1, kind = "puff"},
  {c0 = 9, r0 = 4, w = 3, h = 1, kind = "char"},
  {c0 = 3, r0 = 9, w = 3, h = 1, kind = "puff"},
  {c0 = 8, r0 = 10, w = 3, h = 1, kind = "char"},
  {c0 = 2, r0 = 6, w = 1, h = 3, kind = "puff"},
  {c0 = 10, r0 = 7, w = 1, h = 3, kind = "char"},
}
local ROCK_SPOTS = {{3, 2}, {10, 2}, {4, 7}, {9, 7}}

local function setup_level(lvl)
  S.phase, S.level, S.hurts, S.hurt_cool = "play", lvl, 0, 0
  S.foes, S.rocks, S.gems_list, S.flames, S.pump, S.aim = {}, {}, {}, {}, nil, nil
  S.veggie, S.rocks_dropped, S.last_rush = nil, 0, false
  S.clear_t, S.restart_t, S.still_t = 0, 0, 0
  S.dug = {}
  for r = 1, ROWS do
    S.dug[r] = {}
    for c = 1, COLS do S.dug[r][c] = false end
  end
  S.pebbles = {}
  for i = 1, 55 do
    S.pebbles[i] = {rnd(10, W - 10), rnd(TOP + 12, TOP + ROWS * TILE - 10), rnd(3, 6), i % 2}
  end
  -- Classic Dig Dug starting T-shaft in the center!
  for r = 1, 5 do dig_cell(6, r, true) end
  dig_cell(5, 5, true)
  dig_cell(7, 5, true)
  S.px, S.py, S.face_x, S.face_y = col_x(6), row_y(5), 1, 0

  -- Cave 1 starts punchier (4 critters: 2 Puff + 2 Char), scaling up to 6 on Cave 3+!
  local nfoes = min(3 + lvl, #POCKETS)
  for i = 1, nfoes do
    local p = POCKETS[i]
    local kind = p.kind
    if lvl >= 3 and i == 3 then kind = "char" end
    for r = p.r0, p.r0 + p.h - 1 do
      for c = p.c0, p.c0 + p.w - 1 do dig_cell(c, r, true) end
    end
    local cx = col_x(p.c0 + idiv(p.w, 2))
    local cy = row_y(p.r0 + idiv(p.h, 2))
    S.foes[#S.foes + 1] = {
      kind = kind, x = cx, y = cy, dx = i % 2 == 0 and -1 or 1, dy = 0,
      puff = 0, deflate = 0, ph = i * 1.7,
      fire_cool = max(70, 120 - lvl * 12) + i * 32, fire_tele = 0,
      ghost = false, ghost_cool = max(140, 260 - lvl * 30) + i * 70,
    }
  end

  local nrocks = min(1 + lvl, #ROCK_SPOTS)
  for i = 1, nrocks do
    local c, r = ROCK_SPOTS[i][1], ROCK_SPOTS[i][2]
    if not is_dug(c, r) then
      S.rocks[#S.rocks + 1] = {c = c, r = r, x = col_x(c), y = row_y(r), state = "rest", t = 0, vy = 0, fell = 0, hits = 0}
    end
  end

  local gspots = {{2, 11}, {11, 7}, {9, 2}, {5, 11}}
  for i, p in ipairs(gspots) do
    S.gems_list[#S.gems_list + 1] = {x = col_x(p[1]), y = row_y(p[2]), kind = (i - 1) % 4 + 1, ph = i * 1.3}
  end

  log("dig level " .. lvl)
  music.play(lvl % 2 == 1 and dig_bed or deep_bed)
  music.tempo(1)
  music.volume(1)
  react_to("Cave " .. lvl .. "! Dig and puff the critters!")
end

local function pick_aim()
  local best, bscore = nil, 1e9
  for _, e in ipairs(S.foes) do
    local d = dist(S.px, S.py, e.x, e.y)
    if d <= PUMP_RANGE then
      local sc = d - e.puff * 30
      if sc < bscore then best, bscore = e, sc end
    end
  end
  return best
end

local function spawn_drop_gem(x, y, bonus)
  S.gems_list[#S.gems_list + 1] = {x = x, y = y, kind = rndi(1, 4), ph = rnd(0, 6), bonus = bonus, drop = true, age = 0}
end

local function pop_foe(e, by_rock, rock_hits)
  e.gone = true
  if by_rock then
    local pts = (rock_hits and rock_hits >= 2) and 500 or 400
    add_score(pts)
    log("dig bonk " .. game.frame)
    sfx.arp("tri", {72, 79, 84, 91}, 0.05, 0.35)
    gfx.shake(5)
    particles.burst(e.x, e.y, 28, 3.8, 36, 3.5, C.GOLD, "star")
    particles.text(e.x, e.y - 16, C.GOLD, (rock_hits and rock_hits >= 2) and "MEGA BONK!" or "BONK!")
    spawn_drop_gem(e.x, e.y, true)
    react_to((rock_hits and rock_hits >= 2) and "MEGA BONK! Double boulder smash!" or "BONK! The boulder got one!")
  else
    add_score(200)
    log("dig pop " .. game.frame)
    sfx.arp("tri", {76, 81, 88}, 0.05, 0.32)
    gfx.shake(3)
    particles.burst(e.x, e.y, 22, 3.2, 32, 3, e.kind == "char" and C.FLAME or C.PUFF, "star")
    particles.text(e.x, e.y - 14, C.GOLD, "POP!")
    spawn_drop_gem(e.x, e.y, false)
    react_to(e.kind == "char" and "POP! Char popped into stars!" or "POP! Puff popped into stars!")
  end
end

local function do_pump()
  log("dig pump")
  for _, f in ipairs(S.flames) do
    if not f.gone and dist(S.px, S.py, f.x, f.y) <= PUMP_RANGE then
      f.gone = true
      S.pump = {x0 = S.px, y0 = S.py, x1 = f.x, y1 = f.y, t = 12}
      sfx.tone("sine", 980, 0.08, 0.22)
      particles.burst(f.x, f.y, 10, 2, 18, 2.5, C.AQUA, "dot")
      react_to("Puffed out the flame!")
      return
    end
  end
  local tgt = pick_aim()
  if tgt then
    S.pump = {x0 = S.px, y0 = S.py, x1 = tgt.x, y1 = tgt.y, t = 12}
    tgt.puff = tgt.puff + 1
    tgt.deflate = max(85, 125 - S.level * 8)
    tgt.fire_tele = 0
    tgt.ghost = false
    local notes_midi = {72, 76, 81}
    sfx.note("sine", notes_midi[min(tgt.puff, 3)], 0.14, 0.28)
    particles.burst(tgt.x, tgt.y, 8, 1.8, 18, 2.5, C.AQUA, "dot")
    if tgt.puff >= 3 then
      pop_foe(tgt, false)
    elseif tgt.puff == 2 then
      react_to("One more puff to POP!")
    else
      react_to("Puff! Keep pumping!")
    end
  else
    local tx = clamp(S.px + S.face_x * 46, 12, W - 12)
    local ty = clamp(S.py + S.face_y * 46, TOP + 10, TOP + ROWS * TILE - 10)
    S.pump = {x0 = S.px, y0 = S.py, x1 = tx, y1 = ty, t = 12}
    sfx.slide("sine", 540, 820, 0.09, 0.18)
    particles.burst(tx, ty, 6, 1.5, 16, 2, C.AQUA, "dot")
  end
end

local function hurt_player()
  if S.hurt_cool > 0 or S.phase ~= "play" then return end
  S.hurts = S.hurts + 1
  S.hurt_cool = 85
  log(fmt("dig hurt %d %d", S.hurts, game.frame))
  sfx.slide("tri", 320, 120, 0.26, 0.35)
  gfx.shake(4)
  particles.burst(S.px, S.py, 14, 2.5, 28, 3, C.PURPLE, "ring")
  if S.hurts >= 3 then
    S.phase, S.restart_t = "restart", 0
    log("dig restart " .. game.frame)
    sfx.arp("tri", {76, 72}, 0.14, 0.3)
    react_to("Whoa! Let's try this cave again!")
  else
    react_to("Oops! Pump to puff them back!")
  end
end

local function check_clear()
  if S.phase == "play" and #S.foes == 0 then
    S.phase, S.clear_t = "clear", 0
    add_score(500)
    if S.level > S.best then S.best = S.level end
    save.set("best", S.best)
    save.set("hi", S.hi)
    save.set("gems", S.gems)
    save.write()
    log("dig clear " .. S.level)
    music.tempo(1)
    music.volume(1)
    music.play(clear_bed)
    sfx.arp("tri", {72, 76, 79, 84, 88}, 0.08, 0.34)
    for i = 1, 36 do
      local col = i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.AQUA
      particles.spawn(W / 2 + rnd(-120, 120), 220 + rnd(-50, 50), rnd(-3, 3), rnd(-5, -1), 85, rnd(3, 5), col,
        i % 2 == 0 and "star" or "square", 0.12, 0.99, 0.1)
    end
    react_to("Cave " .. S.level .. " clear! Great digging!")
  end
end

local function step_player(mx, my)
  S.moving = false
  if mx == 0 and my == 0 then
    S.still_t = S.still_t + 1
    return
  end
  S.still_t = 0
  if mx ~= 0 and my ~= 0 then my = 0 end
  S.face_x, S.face_y = mx, my
  S.moving = true
  S.walk_t = S.walk_t + 1
  local c, r = x_col(S.px), y_row(S.py)
  local in_tunnel = is_dug(c, r)
  local spd = in_tunnel and SPEED_TUNNEL or SPEED_DIRT
  local nx, ny = S.px + mx * spd, S.py + my * spd
  if mx ~= 0 then ny = approach(ny, row_y(r), 0.3) else nx = approach(nx, col_x(c), 0.3) end
  nx = clamp(nx, TILE * 0.5, W - TILE * 0.5)
  ny = clamp(ny, TOP + TILE * 0.5, TOP + ROWS * TILE - TILE * 0.5)
  local nc, nr = x_col(nx), y_row(ny)
  if rock_at_cell(nc, nr) then return end
  S.px, S.py = nx, ny
  dig_cell(nc, nr, false)
end

local function step_rocks()
  for _, rk in ipairs(S.rocks) do
    if rk.state == "rest" then
      if rk.r < ROWS and is_dug(rk.c, rk.r + 1) then
        rk.state, rk.t = "wiggle", 56
        sfx.slide("sine", 240, 320, 0.25, 0.16)
        react_to("Watch out! Rock rolling!")
      end
    elseif rk.state == "wiggle" then
      rk.t = rk.t - 1
      if rk.t % 14 == 0 then particles.burst(rk.x, rk.y + 10, 4, 1.2, 16, 2, C.ROCK, "dot") end
      if rk.t <= 0 then
        rk.state, rk.vy = "fall", 3.8
        dig_cell(rk.c, rk.r, true)
      end
    elseif rk.state == "fall" then
      rk.y = rk.y + rk.vy
      rk.fell = rk.fell + rk.vy
      local nr = y_row(rk.y)
      dig_cell(rk.c, nr, true)
      for _, e in ipairs(S.foes) do
        if not e.gone and dist(rk.x, rk.y, e.x, e.y) < 25 then
          rk.hits = rk.hits + 1
          pop_foe(e, true, rk.hits)
        end
      end
      if dist(rk.x, rk.y, S.px, S.py) < 22 then
        S.px = clamp(S.px + (S.px < W / 2 and 28 or -28), TILE * 0.5, W - TILE * 0.5)
        dig_cell(x_col(S.px), y_row(S.py), true)
        sfx.slide("sine", 500, 900, 0.1, 0.16)
      end
      local next_r = y_row(rk.y + 14)
      local hit_floor = rk.y >= TOP + ROWS * TILE - TILE * 0.5
      local hit_dirt = rk.fell > TILE * 1.4 and next_r <= ROWS and not is_dug(rk.c, next_r)
      if hit_floor or hit_dirt then
        rk.gone = true
        S.rocks_dropped = S.rocks_dropped + 1
        sfx.noise(0.14, 0.22, 900)
        gfx.shake(3)
        particles.burst(rk.x, rk.y, 16, 2.6, 26, 3, C.ROCK, "square")
        -- Classic Dig Dug bonus veggie spawns in the center after 2 boulders drop!
        if S.rocks_dropped == 2 and not S.veggie then
          S.veggie = {x = col_x(6), y = row_y(5), kind = (S.level - 1) % 5 + 1, life = 480}
          sfx.arp("tri", {72, 76, 79, 84}, 0.06, 0.28)
          particles.burst(S.veggie.x, S.veggie.y, 18, 2.5, 30, 3, C.GOLD, "star")
          react_to("Bonus treasure in the middle!")
        end
      end
    end
  end
  sweep(S.rocks, function(rk) return not rk.gone end)
end

local function step_foes()
  -- Last-critter rush! Speed up the tune like classic Dig Dug!
  if #S.foes == 1 and not S.last_rush then
    S.last_rush = true
    music.tempo(1.24)
    react_to("Last critter! Catch it!")
  end
  local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
  local base_spd = min(1.08 + (S.level - 1) * 0.12, 1.55)
  for _, e in ipairs(S.foes) do
    if not e.gone then
      if e.puff > 0 then
        e.deflate = e.deflate - 1
        if e.deflate <= 0 then
          e.puff = e.puff - 1
          if e.puff > 0 then e.deflate = 80 end
        end
      elseif e.fire_tele > 0 then
        e.fire_tele = e.fire_tele - 1
        if e.fire_tele == 0 then
          local dir = e.dx < 0 and -1 or 1
          S.flames[#S.flames + 1] = {x = e.x + dir * 14, y = e.y, vx = dir * 2.5, life = 54}
          sfx.noise(0.14, 0.18, 2400)
        end
      else
        local spd = base_spd * (e.ghost and 0.78 or 1) * (S.last_rush and 1.12 or 1)
        if e.ghost then
          local a = atan2(S.py - e.y, S.px - e.x)
          e.x = clamp(e.x + cos(a) * spd, TILE * 0.5, W - TILE * 0.5)
          e.y = clamp(e.y + sin(a) * spd, TOP + TILE * 0.5, TOP + ROWS * TILE - TILE * 0.5)
          e.dx = cos(a) >= 0 and 1 or -1
          if is_dug(x_col(e.x), y_row(e.y)) and dist(e.x, e.y, S.px, S.py) > 40 then
            e.ghost = false
            e.ghost_cool = max(180, 320 - S.level * 25)
          end
        else
          local c, r = x_col(e.x), y_row(e.y)
          local cx, cy = col_x(c), row_y(r)
          if abs(e.x - cx) < 2 and abs(e.y - cy) < 2 then
            local tx, ty = S.px, S.py
            local best_d, best_sc = nil, 1e9
            for _, d in ipairs(dirs) do
              local nc, nr = c + d[1], r + d[2]
              if is_dug(nc, nr) and not rock_at_cell(nc, nr) then
                local sc = dist(col_x(nc), row_y(nr), tx, ty)
                if d[1] == -e.dx and d[2] == -e.dy then sc = sc + 120 end
                if sc < best_sc then best_d, best_sc = d, sc end
              end
            end
            if best_d then e.dx, e.dy = best_d[1], best_d[2] else e.dx, e.dy = -e.dx, -e.dy end
          end
          local nx, ny = e.x + e.dx * spd, e.y + e.dy * spd
          if is_dug(x_col(nx), y_row(ny)) then e.x, e.y = nx, ny else e.dx, e.dy = -e.dx, -e.dy end
          if S.level >= 2 or S.last_rush then
            e.ghost_cool = e.ghost_cool - 1
            if e.ghost_cool <= 0 and dist(e.x, e.y, S.px, S.py) > 96 then
              e.ghost = true
              react_to("A critter is floating through the dirt!")
            end
          end
        end
        if e.kind == "char" and not e.ghost then
          e.fire_cool = e.fire_cool - 1
          if e.fire_cool <= 0 and abs(e.y - S.py) < 22 and abs(e.x - S.px) < 145 then
            e.dx = S.px >= e.x and 1 or -1
            e.fire_tele = 32
            e.fire_cool = max(110, 175 - S.level * 12)
            sfx.slide("sine", 320, 620, 0.25, 0.14)
            react_to("Char is puffing fire!")
          end
        end
        if dist(e.x, e.y, S.px, S.py) < 20 then
          hurt_player()
          e.dx, e.dy = -e.dx, -e.dy
          e.x = clamp(e.x + e.dx * 16, TILE * 0.5, W - TILE * 0.5)
        end
      end
    end
  end
  sweep(S.foes, function(e) return not e.gone end)
end

local function step_flames()
  for _, f in ipairs(S.flames) do
    f.x, f.life = f.x + f.vx, f.life - 1
    if dist(f.x, f.y, S.px, S.py) < 18 then
      f.gone = true
      hurt_player()
    elseif f.life <= 0 or f.x < 8 or f.x > W - 8 then
      f.gone = true
    end
  end
  sweep(S.flames, function(f) return not f.gone end)
end

local function step_gems()
  if S.veggie then
    local v = S.veggie
    v.life = v.life - 1
    if dist(v.x, v.y, S.px, S.py) < 26 then
      S.gems = min(S.gems + 3, 100000)
      add_score(300)
      log("dig bonus " .. S.gems)
      sfx.arp("tri", {76, 79, 84, 88, 96}, 0.05, 0.3)
      particles.burst(v.x, v.y, 24, 3, 32, 3.5, C.GOLD, "star")
      particles.text(v.x, v.y - 16, C.GOLD, "+300!")
      react_to("Yum! Bonus treasure!")
      S.veggie = nil
    elseif v.life <= 0 then
      S.veggie = nil
    end
  end
  for _, g in ipairs(S.gems_list) do
    if g.drop then
      g.age = g.age + 1
      if g.age > 22 and dist(g.x, g.y, S.px, S.py) < 120 then
        g.x = approach(g.x, S.px, 0.16)
        g.y = approach(g.y, S.py, 0.16)
      end
    end
    if dist(g.x, g.y, S.px, S.py) < 26 then
      g.gone = true
      S.gems = min(S.gems + (g.bonus and 2 or 1), 100000)
      add_score(g.bonus and 150 or 100)
      log("dig gem " .. S.gems)
      sfx.arp("sine", {84, 88, 96}, 0.05, 0.24)
      particles.burst(g.x, g.y, 12, 2.2, 24, 2.5, C.GOLD, "star")
      particles.text(g.x, g.y - 12, C.GOLD, g.bonus and "+2" or "+1")
      react_to("Ooh! A sparkling gem!")
    end
  end
  sweep(S.gems_list, function(g) return not g.gone end)
end

local function leaving() return input.down("1p") and input.down("2p") end

local function rest_line()
  if leaving() then return "Your gems and score will stay!" end
  if S.phase == "clear" then
    return S.clear_t >= CLEAR_MIN and "Press any button for the next cave!" or ("Cave " .. S.level .. " clear! Great digging!")
  end
  if S.phase == "restart" then return "Whoa! Let's try this cave again!" end
  if S.aim then return "Press to puff the critter!" end
  return "Dig tunnels and find the critters!"
end

-- ------------------------------------------------------------------ built-in player

function bot()
  if S.phase == "clear" then
    if S.clear_t >= CLEAR_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase ~= "play" then return end
  if S.aim then
    if game.frame % 3 == 0 then input.bot("low") end
    if dist(S.px, S.py, S.aim.x, S.aim.y) < 42 then
      if S.px < S.aim.x then input.bot("left") else input.bot("right") end
    end
    return
  end
  local tgt = S.foes[1]
  local bd = 1e9
  for _, e in ipairs(S.foes) do
    local d = dist(S.px, S.py, e.x, e.y)
    if d < bd then tgt, bd = e, d end
  end
  if not tgt then return end
  local dx, dy = tgt.x - S.px, tgt.y - S.py
  if abs(dx) > abs(dy) then input.bot(dx < 0 and "left" or "right")
  else input.bot(dy < 0 and "up" or "down") end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.42)
  sfx.limit(12000)
  S.best = clamp(save.get("best", 0), 0, 100000)
  S.hi = clamp(save.get("hi", 0), 0, 999999)
  S.gems = clamp(save.get("gems", 0), 0, 100000)
  log("dig best " .. S.best)
  setup_level(1)
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.shot_cool > 0 then S.shot_cool = S.shot_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "play" then
    step_player(mx, my)
    step_rocks()
    step_foes()
    step_flames()
    step_gems()
    S.aim = pick_aim()
    if S.saw_release and ((pressed and S.shot_cool <= HOLD_GAP - PUMP_GAP) or (held and not pressed and S.shot_cool == 0)) then
      do_pump()
      S.shot_cool = HOLD_GAP
    end
    check_clear()
  elseif S.phase == "clear" then
    S.clear_t = S.clear_t + 1
    if S.clear_t % 12 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.5, 2), 80, rnd(3, 4.5),
        S.clear_t % 24 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.clear_t >= CLEAR_MIN) or S.clear_t >= CLEAR_AUTO then
      snd.ok()
      setup_level(S.level + 1)
    end
  elseif S.phase == "restart" then
    S.restart_t = S.restart_t + 1
    if S.restart_t >= 70 then setup_level(S.level) end
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
