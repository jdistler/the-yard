-- Dig v3: a Dig Dug homage with a reason. The critters carried the veggie garden down into the caves. Each cave
-- cleared brings one veggie home (carrot, turnip, mushroom, pineapple, pumpkin): it is planted on a garden map,
-- and every fifth cave is a harvest party. Five cave worlds (one per veggie), each with its own song.
-- Walk-up band (CONTROLS.md). The stick digs and walks. Any right-hand button puffs the pump.
-- A grown-up reads the cream band. dig.sav keeps "best N", "hi N", "gems N" (as ever) and, new: harvests, rowq
-- (this row's plots), v1..v5 (veggies saved), gold (golden veggies), gk1..gk4 (gems by colour), visits.
--
-- Rules for the code: game logic counts game.frame and never reads music.step() (it is used for drawing and to
-- pick the pitch of a music.cue). Chance is only the seeded rnd. Nothing here draws or reads the music clock.

local pics = import("pictures")
local songs = import("songs")
local C = pics.C

local COLS, ROWS, TILE, TOP = 12, 12, 32, 96
local SPEED_TUNNEL, SPEED_DIRT = 2.4, 2.0
local PUMP_RANGE, PUMP_GAP, HOLD_GAP = 88, 12, 22
local REACT_FRAMES, CLEAR_MIN, CLEAR_AUTO = 110, 90, 260
local STORY_END, STORY_MIN, GARDEN_MIN, GARDEN_AUTO, HARVEST_MIN, HARVEST_AUTO = 392, 14, 70, 250, 200, 560
local DANGER_D, DANGER_HOLD, STREAK_WINDOW, RUN_WINDOW = 130, 120, 420, 150
local VEGNAME = pics.VEG

local function col_x(c) return (c - 0.5) * TILE end
local function row_y(r) return TOP + (r - 0.5) * TILE end
local function x_col(x) return clamp(floor(x / TILE) + 1, 1, COLS) end
local function y_row(y) return clamp(floor((y - TOP) / TILE) + 1, 1, ROWS) end

local S = {
  COLS = COLS, ROWS = ROWS, TILE = TILE, TOP = TOP,
  phase = "story", level = 1, diff = 1, clears = 0, best = 0, hi = 0, score = 0, gems = 0, hurts = 0, hurt_cool = 0,
  px = col_x(6), py = row_y(5), face_x = 1, face_y = 0, moving = false, still_t = 0, walk_t = 0,
  dug = {}, dug_ver = 0, foes = {}, rocks = {}, gems_list = {}, flames = {}, pebbles = {},
  veggie = nil, rocks_dropped = 0, last_rush = false, bonus_grade = 0,
  pump = nil, aim = nil, shot_cool = 0, saw_release = false,
  react = "", react_left = 0, clear_t = 0, restart_t = 0, goodbye = false,
  -- the garden
  world = 1, slot = 1, planted = false, rowq = {0, 0, 0, 0, 0}, veg = {0, 0, 0, 0, 0}, goldveg = 0,
  harvests = 0, gk = {0, 0, 0, 0}, visits = 0, look = 1, bq = {}, bq_key = "-",
  t = 0, age = 0,
  -- how the world is answering
  whew_t = 0, pump_t = 0, near = 999, run = 0, last_pump = -999, streak = 0, last_pop = -999,
  danger_t = 0, dig_cue = -99, dign = 0,
}
pics.S = S

local LV = {1, 1, 1, 1, 1, 1}   -- the track levels asked of the song, so music.track is only called on a change

-- ------------------------------------------------------------------ small helpers

local function react_to(s) S.react, S.react_left = s, REACT_FRAMES end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.hi then S.hi = S.score end
end

local function row_code()
  local n, m = 0, 1
  for i = 1, 5 do n = n + clamp(S.rowq[i], 0, 2) * m m = m * 4 end
  return n
end

local function save_all()
  save.set("best", S.best)
  save.set("hi", S.hi)
  save.set("gems", S.gems)
  save.set("harvests", S.harvests)
  save.set("rowq", row_code())
  for i = 1, 5 do save.set("v" .. i, S.veg[i]) end
  save.set("gold", S.goldveg)
  for i = 1, 4 do save.set("gk" .. i, S.gk[i]) end
  save.set("visits", S.visits)
  save.write()
end

-- ------------------------------------------------------------------ the music

local function set_level(i, v)
  if LV[i] ~= v then
    LV[i] = v
    music.track(i, v)
  end
end

local function play_song(song)
  music.play(song)
  for i = 1, 6 do LV[i] = 1 end
end

-- The layers follow what is happening: calm tunnelling is bass, pad, shimmer and a soft lead; a critter close
-- brings the drums and the stabs; a run of pops lifts the lead; being hurt lets the lead drop away, gently.
local function update_mix()
  local danger = S.last_rush or S.danger_t > 0
  local lead = 0.55
  if S.streak >= 2 then lead = 1.25 elseif danger then lead = 0.9 end
  if S.hurt_cool > 0 then lead = 0.3 end
  set_level(1, lead)
  set_level(2, danger and 1 or 0)
  set_level(5, danger and (S.last_rush and 1.1 or 1) or 0)
end

local function cave_song(hunt, keep)
  return songs.song(S.world, hunt, keep)
end

-- A note from the chord under the step it will land on (sound only: nothing reads it back).
local function ladder_note(n, up)
  return songs.ladder(S.world, music.step() + 1, n) + (up or 0)
end

local function cue_chord(vol, wave, up)
  local root, t3 = songs.chord(S.world, music.step() + 1)
  root = root + (up or 0)
  music.cue{wave = wave or "square", duty = 0.25, note = root, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = wave or "square", duty = 0.25, note = root + t3, dur = 0.42, vol = vol * 0.8, release = 0.38}
  music.cue{wave = "tri", note = root + 7, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = "sine", note = root + 12, dur = 0.5, vol = vol * 0.9, release = 0.45}
end

-- ------------------------------------------------------------------ the earth

local function stratum_col(r)
  local w = pics.WORLDS[S.world].l
  if r <= 3 then return w[1] elseif r <= 6 then return w[2] elseif r <= 9 then return w[3] else return w[4] end
end

local function is_dug(c, r)
  return r >= 1 and r <= ROWS and c >= 1 and c <= COLS and S.dug[r][c]
end

local function dig_cell(c, r, silent)
  if r < 1 or r > ROWS or c < 1 or c > COLS or S.dug[r][c] then return false end
  S.dug[r][c] = true
  S.dug_ver = S.dug_ver + 1
  if not silent then
    local x, y = col_x(c), row_y(r)
    particles.burst(x, y, 7, 1.8, 18, 2.5, stratum_col(r), "square")
    sfx.noise(0.05, 0.12, 1800)
    -- tunnelling plays a soft marimba: each fresh cell the next note of the chord, on the grid
    if game.frame - S.dig_cue >= 10 then
      S.dig_cue = game.frame
      S.dign = S.dign + 1
      music.cue{wave = "tri", note = ladder_note(S.dign % 7, -12), dur = 0.2, vol = 0.12, release = 0.18}
    end
  end
  return true
end

local function rock_at_cell(c, r)
  for _, rk in ipairs(S.rocks) do
    if rk.state == "rest" and rk.c == c and rk.r == r then return rk end
  end
  return nil
end

-- Escalating caves with richer critter layouts and boulder placements. difficulty is S.diff: it starts at 1
-- every visit and climbs with each cave cleared, so a returning player's first cave is always a gentle one.
local POCKETS = {
  {c0 = 2, r0 = 3, w = 3, h = 1, kind = "puff"},
  {c0 = 9, r0 = 4, w = 3, h = 1, kind = "char"},
  {c0 = 3, r0 = 9, w = 3, h = 1, kind = "puff"},
  {c0 = 8, r0 = 10, w = 3, h = 1, kind = "char"},
  {c0 = 2, r0 = 6, w = 1, h = 3, kind = "puff"},
  {c0 = 10, r0 = 7, w = 1, h = 3, kind = "char"},
}
-- (none sits straight above a critter pocket, so no rock falls on its own at the start)
local ROCK_SPOTS = {{5, 2}, {10, 2}, {4, 7}, {9, 7}}

local function setup_level(lvl)
  S.phase, S.level, S.hurts, S.hurt_cool = "play", lvl, 0, 0
  S.diff = min(lvl, 1 + S.clears)
  S.slot = (lvl - 1) % 5 + 1
  S.world = S.slot
  S.planted, S.bonus_grade = false, 0
  if S.slot == 1 then for i = 1, 5 do S.rowq[i] = 0 end end
  S.foes, S.rocks, S.gems_list, S.flames, S.pump, S.aim = {}, {}, {}, {}, nil, nil
  S.veggie, S.rocks_dropped, S.last_rush = nil, 0, false
  S.clear_t, S.restart_t, S.still_t, S.t, S.age = 0, 0, 0, 0, 0
  S.whew_t, S.pump_t, S.near, S.run, S.streak, S.danger_t = 0, 0, 999, 0, 0, 0
  S.dug = {}
  S.dug_ver = S.dug_ver + 1
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

  local d = S.diff
  -- Cave 1 is gentle for a five-year-old (3 critters: Puff, Char, Puff), scaling up to 6 by Cave 4.
  local nfoes = min(2 + d, #POCKETS)
  for i = 1, nfoes do
    local p = POCKETS[i]
    local kind = p.kind
    if d >= 3 and i == 3 then kind = "char" end
    for r = p.r0, p.r0 + p.h - 1 do
      for c = p.c0, p.c0 + p.w - 1 do dig_cell(c, r, true) end
    end
    local cx = col_x(p.c0 + idiv(p.w, 2))
    local cy = row_y(p.r0 + idiv(p.h, 2))
    S.foes[#S.foes + 1] = {
      kind = kind, x = cx, y = cy, dx = i % 2 == 0 and -1 or 1, dy = 0, id = i, cheer = 0,
      puff = 0, deflate = 0, ph = i * 1.7,
      fire_cool = max(70, 120 - d * 12) + i * 32 + (d == 1 and 100 or 0), fire_tele = 0,
      ghost = false, ghost_cool = max(140, 260 - d * 30) + i * 70,
    }
  end

  local nrocks = min(1 + d, #ROCK_SPOTS)
  for i = 1, nrocks do
    local c, r = ROCK_SPOTS[i][1], ROCK_SPOTS[i][2]
    if not is_dug(c, r) then
      S.rocks[#S.rocks + 1] = {c = c, r = r, x = col_x(c), y = row_y(r), state = "rest", t = 0, vy = 0, fell = 0, hits = 0, near = false}
    end
  end

  local gspots = {{2, 11}, {11, 7}, {9, 2}, {5, 11}}
  for i, p in ipairs(gspots) do
    S.gems_list[#S.gems_list + 1] = {x = col_x(p[1]), y = row_y(p[2]), kind = (i - 1) % 4 + 1, ph = i * 1.3}
  end

  log("dig level " .. lvl)
  play_song(cave_song(false))
  music.tempo(1)
  music.volume(1)
  update_mix()
  if lvl == 1 and S.best == 0 then
    react_to("Cave 1! Dig and puff the critters!")
  else
    react_to("Cave " .. lvl .. "! Dig out the " .. VEGNAME[S.slot] .. "!")
  end
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

-- gems into the pouch: the shelf keeps each colour, and enough gems earn a new hat
local function gain_gems(n, kind)
  S.gems = min(S.gems + n, 100000)
  if kind then S.gk[kind] = min(S.gk[kind] + 1, 100000) end
  local look = pics.look_for(S.gems)
  if look > S.look then
    S.look = look
    log("dig hat " .. look)
    sfx.arp("tri", {72, 76, 79, 84, 88, 91, 96}, 0.06, 0.3)
    particles.burst(S.px, S.py - 16, 26, 3, 36, 3.5, C.GOLD, "star")
    particles.text(S.px, S.py - 40, C.GOLD, "NEW HAT!")
    react_to("A new hat for Diggy!")
  end
end

-- a pop (or a bonk) in a run: the streak is the lead coming in, the chord is the stinger
local function note_pop()
  if game.frame - S.last_pop <= STREAK_WINDOW then S.streak = S.streak + 1 else S.streak = 1 end
  S.last_pop = game.frame
end

local function pop_foe(e, by_rock, rock_hits)
  e.gone = true
  note_pop()
  local extra = S.streak >= 2 and 50 * (S.streak - 1) or 0
  if by_rock then
    local pts = (rock_hits and rock_hits >= 2) and 500 or 400
    add_score(pts + extra)
    log("dig bonk " .. game.frame)
    cue_chord(0.2, "square", 0)
    sfx.arp("tri", {72, 79, 84, 91}, 0.05, 0.3)
    gfx.shake(5)
    particles.burst(e.x, e.y, 28, 3.8, 36, 3.5, C.GOLD, "star")
    particles.text(e.x, e.y - 16, C.GOLD, (rock_hits and rock_hits >= 2) and "MEGA BONK!" or "BONK!")
    spawn_drop_gem(e.x, e.y, true)
    react_to((rock_hits and rock_hits >= 2) and "MEGA BONK! Double boulder smash!" or "BONK! The boulder got one!")
  else
    add_score(200 + extra)
    log("dig pop " .. game.frame)
    cue_chord(0.17, "square", S.streak >= 3 and 12 or 0)
    gfx.shake(3)
    particles.burst(e.x, e.y, 22, 3.2, 32, 3, e.kind == "char" and C.FLAME or C.PUFF, "star")
    particles.text(e.x, e.y - 14, C.GOLD, "POP!")
    spawn_drop_gem(e.x, e.y, false)
    if S.streak >= 3 then
      react_to("Triple pop! You are on a roll!")
    elseif S.streak == 2 then
      react_to("Double pop! Keep going!")
    else
      react_to(e.kind == "char" and "POP! Char popped into stars!" or "POP! Puff popped into stars!")
    end
  end
end

local function do_pump()
  log("dig pump")
  S.pump_t = 14
  if game.frame - S.last_pump > RUN_WINDOW then S.run = 0 end
  S.last_pump = game.frame
  S.run = S.run + 1
  local rn = S.run - 1
  for _, f in ipairs(S.flames) do
    if not f.gone and dist(S.px, S.py, f.x, f.y) <= PUMP_RANGE then
      f.gone = true
      S.pump = {x0 = S.px, y0 = S.py, x1 = f.x, y1 = f.y, t = 12}
      music.cue{wave = "sine", note = ladder_note(rn, 12), dur = 0.2, vol = 0.22, release = 0.18}
      particles.burst(f.x, f.y, 10, 2, 18, 2.5, C.AQUA, "dot")
      react_to("Puffed out the flame!")
      return
    end
  end
  local tgt = pick_aim()
  if tgt then
    S.pump = {x0 = S.px, y0 = S.py, x1 = tgt.x, y1 = tgt.y, t = 12}
    tgt.puff = tgt.puff + 1
    tgt.deflate = max(85, 125 - S.diff * 8)
    tgt.fire_tele = 0
    tgt.ghost = false
    -- the pump is an instrument: each puff the next note up the chord, on the beat
    music.cue{wave = "tri", note = ladder_note(rn, 0), dur = 0.22, vol = 0.3, release = 0.2}
    music.cue{wave = "sine", note = ladder_note(rn, 12), dur = 0.14, vol = 0.1, release = 0.12}
    particles.burst(tgt.x, tgt.y, 8, 1.8, 18, 2.5, hsv(clamp(S.run, 1, 8) / 9, 0.5, 1), "dot")
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

local function whew()
  if S.whew_t > 0 then return end
  S.whew_t = 40
  log("dig whew " .. game.frame)
  sfx.slide("sine", 880, 520, 0.18, 0.14)
end

local function hurt_player()
  if S.hurt_cool > 0 or S.phase ~= "play" then return end
  S.hurts = S.hurts + 1
  S.hurt_cool = 85
  S.streak, S.run = 0, 0
  for _, e in ipairs(S.foes) do   -- the nearest critter cheers
    if not e.gone and dist(e.x, e.y, S.px, S.py) < 70 then e.cheer = 70 end
  end
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

-- ------------------------------------------------------------------ clear, garden, harvest

local function check_clear()
  if S.phase == "play" and #S.foes == 0 then
    S.phase, S.clear_t = "clear", 0
    add_score(500)
    if S.level > S.best then S.best = S.level end
    S.clears = S.clears + 1
    -- the veggie is saved: it goes on the shelf and into this row of the garden
    local grade = S.bonus_grade
    S.rowq[S.slot] = grade
    S.veg[S.slot] = min(S.veg[S.slot] + 1, 100000)
    if grade == 2 then S.goldveg = min(S.goldveg + 1, 100000) end
    S.planted = true
    if S.slot == 5 then S.harvests = min(S.harvests + 1, 100000) end
    save_all()
    log("dig clear " .. S.level)
    log(fmt("dig veg %d %d", S.slot, grade))
    music.tempo(1)
    music.volume(1)
    play_song(songs.fanfare(S.world))
    sfx.arp("tri", {72, 76, 79, 84, 88}, 0.08, 0.34)
    for i = 1, 36 do
      local col = i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.AQUA
      particles.spawn(W / 2 + rnd(-120, 120), 220 + rnd(-50, 50), rnd(-3, 3), rnd(-5, -1), 85, rnd(3, 5), col,
        i % 2 == 0 and "star" or "square", 0.12, 0.99, 0.1)
    end
    react_to("Cave " .. S.level .. " clear! The " .. VEGNAME[S.slot] .. " is saved!")
  end
end

local function begin_garden()
  S.phase, S.t, S.age = "garden", 0, 0
  log("dig garden " .. S.slot)
  play_song(songs.garden())
  music.tempo(1)
  react_to("Plant the " .. VEGNAME[S.slot] .. "!")
end

local function begin_harvest()
  S.phase, S.t, S.age = "harvest", 0, 0
  log("dig harvest " .. S.harvests)
  play_song(songs.song(6, false))
  music.tempo(1)
  music.volume(1)
  sfx.arp("tri", {72, 76, 79, 84, 88, 91, 96}, 0.07, 0.3)
  react_to("Harvest party! The critters brought everything back!")
end

local function next_cave() snd.ok() setup_level(S.level + 1) end

-- ------------------------------------------------------------------ the cave's characters

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
        music.cue{wave = "tri", note = ladder_note(0, -12), dur = 0.3, vol = 0.16, release = 0.25}
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
      local pd = dist(rk.x, rk.y, S.px, S.py)
      if pd < 22 then
        S.px = clamp(S.px + (S.px < W / 2 and 28 or -28), TILE * 0.5, W - TILE * 0.5)
        dig_cell(x_col(S.px), y_row(S.py), true)
        sfx.slide("sine", 500, 900, 0.1, 0.16)
        rk.near = true
        whew()
      elseif pd < 46 and not rk.near then   -- it went right past him
        rk.near = true
        whew()
      end
      local next_r = y_row(rk.y + 14)
      local hit_floor = rk.y >= TOP + ROWS * TILE - TILE * 0.5
      local hit_dirt = rk.fell > TILE * 1.4 and next_r <= ROWS and not is_dug(rk.c, next_r)
      if hit_floor or hit_dirt then
        rk.gone = true
        S.rocks_dropped = S.rocks_dropped + 1
        sfx.noise(0.14, 0.22, 900)
        music.cue{wave = "sine", hz = 130, hz_end = 44, dur = 0.22, vol = 0.3, release = 0.2}
        gfx.shake(3)
        particles.burst(rk.x, rk.y, 16, 2.6, 26, 3, C.ROCK, "square")
        -- Classic Dig Dug bonus veggie spawns in the center after 2 boulders drop! Now and then it is golden.
        if S.rocks_dropped == 2 and not S.veggie then
          local gold = rnd() < 0.2
          S.veggie = {x = col_x(6), y = row_y(5), kind = S.slot, life = gold and 720 or 480, gold = gold}
          sfx.arp("tri", {72, 76, 79, 84}, 0.06, 0.28)
          particles.burst(S.veggie.x, S.veggie.y, 18, 2.5, 30, 3, C.GOLD, "star")
          log(gold and "dig goldveg" or "dig bonusveg")
          react_to(gold and "A GOLDEN " .. VEGNAME[S.slot] .. "! Grab it!" or "Bonus treasure in the middle!")
        end
      end
    end
  end
  sweep(S.rocks, function(rk) return not rk.gone end)
end

local function step_foes()
  -- Last-critter rush! The song turns into its hunt section and speeds up, like classic Dig Dug.
  if #S.foes == 1 and not S.last_rush then
    S.last_rush = true
    music.play(cave_song(true, true))   -- keep: the same step, the same layers, a new section
    music.tempo(1.2)
    log("dig last " .. game.frame)
    react_to("Last critter! Catch it!")
  end
  local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
  local base_spd = min(1.08 + (S.diff - 1) * 0.12, 1.55)
  local near = 999
  for _, e in ipairs(S.foes) do
    if not e.gone then
      if e.cheer > 0 then e.cheer = e.cheer - 1 end
      local dd = dist(e.x, e.y, S.px, S.py)
      if dd < near then near = dd end
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
          S.flames[#S.flames + 1] = {x = e.x + dir * 14, y = e.y, vx = dir * 2.5, life = 54, near = false}
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
            e.ghost_cool = max(180, 320 - S.diff * 25)
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
          if S.diff >= 2 or S.last_rush then
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
            e.fire_cool = max(110, 175 - S.diff * 12)
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
  S.near = near
  if near < DANGER_D then S.danger_t = DANGER_HOLD end
  sweep(S.foes, function(e) return not e.gone end)
end

local function step_flames()
  for _, f in ipairs(S.flames) do
    f.x, f.life = f.x + f.vx, f.life - 1
    local fd = dist(f.x, f.y, S.px, S.py)
    if fd < 18 then
      f.gone = true
      hurt_player()
    elseif fd < 34 and not f.near and S.hurt_cool == 0 then   -- a flame that just missed
      f.near = true
      whew()
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
      local g = v.gold and 6 or 3
      gain_gems(g, nil)
      add_score(v.gold and 600 or 300)
      S.bonus_grade = v.gold and 2 or max(S.bonus_grade, 1)
      log((v.gold and "dig golden " or "dig bonus ") .. S.gems)
      if v.gold then
        sfx.arp("tri", {76, 79, 84, 88, 91, 96, 100, 103}, 0.05, 0.3)
        particles.burst(v.x, v.y, 40, 3.4, 44, 4, C.GOLD, "star")
        particles.text(v.x, v.y - 16, C.GOLD, "+600!")
        react_to("A GOLDEN " .. VEGNAME[S.slot] .. "! So shiny!")
      else
        sfx.arp("tri", {76, 79, 84, 88, 96}, 0.05, 0.3)
        particles.burst(v.x, v.y, 24, 3, 32, 3.5, C.GOLD, "star")
        particles.text(v.x, v.y - 16, C.GOLD, "+300!")
        react_to("Yum! Bonus treasure!")
      end
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
      gain_gems(g.bonus and 2 or 1, g.kind)
      add_score(g.bonus and 150 or 100)
      log("dig gem " .. S.gems)
      music.cue{wave = "sine", note = ladder_note(g.kind + 2, 12), dur = 0.2, vol = 0.14, release = 0.18}
      sfx.arp("sine", {84, 88, 96}, 0.05, 0.14)
      particles.burst(g.x, g.y, 12, 2.2, 24, 2.5, pics.GEM_COLS[g.kind] or C.GOLD, "star")
      particles.text(g.x, g.y - 12, C.GOLD, g.bonus and "+2" or "+1")
      react_to("Ooh! A sparkling gem!")
    end
  end
  sweep(S.gems_list, function(g) return not g.gone end)
end

local function leaving() return input.down("1p") and input.down("2p") end

local function rest_line()
  if leaving() then return "Your gems, veggies and garden will stay!" end
  if S.phase == "story" then return pics.story_line(S.t) end
  if S.phase == "clear" then
    return S.clear_t >= CLEAR_MIN and "Press any button to plant the veggie!" or ("Cave " .. S.level .. " clear! Great digging!")
  end
  if S.phase == "garden" then
    if S.t < 62 then return "Plant the " .. VEGNAME[S.slot] .. "!" end
    if S.slot == 5 then return "That is the whole row! Harvest time!" end
    local left = 5 - S.slot
    return "The " .. VEGNAME[S.slot] .. " is home! " .. left .. " more to find!"
  end
  if S.phase == "harvest" then
    return S.t >= HARVEST_MIN and "Press any button for the next caves!" or "Harvest party! The critters brought everything back!"
  end
  if S.phase == "restart" then return "Whoa! Let's try this cave again!" end
  if S.aim then return "Press to puff the critter!" end
  if S.veggie then return S.veggie.gold and "Grab the golden veggie!" or "Grab the bonus treasure!" end
  return "Dig tunnels and find the critters!"
end

-- ------------------------------------------------------------------ built-in player

function bot()
  if S.phase == "story" then
    if S.age >= STORY_MIN + 6 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase == "clear" then
    if S.clear_t >= CLEAR_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase == "garden" then
    if S.t >= GARDEN_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase == "harvest" then
    if S.t >= HARVEST_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
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

local FLOWERS = {rose = 1, gold = 1, sky = 1, lilac = 1, mint = 1, coral = 1}

function init()
  sfx.master(0.42)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 100000)
  S.hi = clamp(save.get("hi", 0), 0, 999999)
  S.gems = clamp(save.get("gems", 0), 0, 100000)
  S.harvests = clamp(save.get("harvests", 0), 0, 100000)
  S.goldveg = clamp(save.get("gold", 0), 0, 100000)
  S.visits = clamp(save.get("visits", 0), 0, 100000) + 1
  for i = 1, 5 do S.veg[i] = clamp(save.get("v" .. i, 0), 0, 100000) end
  for i = 1, 4 do S.gk[i] = clamp(save.get("gk" .. i, 0), 0, 100000) end
  -- this row of the garden: what the last visit planted (only the plots the saved cave number has reached)
  local code = clamp(save.get("rowq", 0), 0, 1023)
  local done = S.best % 5
  for i = 1, 5 do
    local q = idiv(code, 4 ^ (i - 1)) % 4
    S.rowq[i] = (i <= done) and min(q, 2) or 0
  end
  S.look = pics.look_for(S.gems)
  -- Garden's bouquet grows on Dig's grass, if she has grown one
  local w = save.peek("garden", "bouquet", "")
  if type(w) == "string" and #w <= 32 then
    local n = 0
    for tok in w:gmatch("[a-z]+") do
      if FLOWERS[tok] and n < 4 then n = n + 1 S.bq[n] = tok end
    end
    if n > 0 then S.bq_key = table.concat(S.bq, "-") end
  end
  log("dig best " .. S.best)
  -- the next cave is the one after the best; the garden carries on where it was
  S.level = S.best + 1
  S.slot = (S.level - 1) % 5 + 1
  S.world = S.slot
  S.phase, S.t, S.age = "story", (S.visits > 1 and S.best > 0) and 170 or 0, 0
  log("dig story " .. S.level)
  play_song(songs.story())
  if S.t < 250 then set_level(3, 0) set_level(4, 0) end
  -- (the story song's own tracks: 1 2 are the thieves' tiptoe, 3 4 the hero who comes in later)
end

-- Leaving (1P+2P): keep the gems, veggies and the best score found so far.
function quit()
  save_all()
end

local function story_music()
  -- Diggy's theme comes in when he arrives
  if S.t == 250 then set_level(3, 1) set_level(4, 1) end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.shot_cool > 0 then S.shot_cool = S.shot_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.whew_t > 0 then S.whew_t = S.whew_t - 1 end
  if S.pump_t > 0 then S.pump_t = S.pump_t - 1 end
  if S.danger_t > 0 then S.danger_t = S.danger_t - 1 end
  S.age = S.age + 1

  if S.phase == "story" then
    S.t = S.t + 1
    story_music()
    if S.t % 20 == 0 and S.t > 70 and S.t < 150 then
      particles.burst(W / 2, 330, 4, 1.4, 20, 2.5, C.CREAM, "dot")
    end
    local skip = pressed and S.saw_release and S.age >= STORY_MIN
    if skip or S.t >= STORY_END then
      snd.ok()
      setup_level(S.level)
      -- the press that skipped the story is not wasted: the first puff of the first cave
      if skip then do_pump() S.shot_cool = HOLD_GAP end
    end
  elseif S.phase == "play" then
    step_player(mx, my)
    step_rocks()
    step_foes()
    step_flames()
    step_gems()
    S.aim = pick_aim()
    if S.streak > 0 and game.frame - S.last_pop > STREAK_WINDOW then S.streak = 0 end
    if S.run > 0 and game.frame - S.last_pump > RUN_WINDOW then S.run = 0 end
    update_mix()
    if S.saw_release and ((pressed and S.shot_cool <= HOLD_GAP - PUMP_GAP) or (held and not pressed and S.shot_cool == 0)) then
      do_pump()
      S.shot_cool = HOLD_GAP
    end
    check_clear()
  elseif S.phase == "clear" then
    S.clear_t = S.clear_t + 1
    S.near = 999
    if S.clear_t % 12 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.5, 2), 80, rnd(3, 4.5),
        S.clear_t % 24 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.clear_t >= CLEAR_MIN) or S.clear_t >= CLEAR_AUTO then
      snd.ok()
      begin_garden()
    end
  elseif S.phase == "garden" then
    S.t = S.t + 1
    if S.t == 62 then   -- the veggie lands in its plot
      local x, y = pics.PX[S.slot], pics.PY - 2
      sfx.arp("sine", {72, 76, 79, 84}, 0.07, 0.3)
      particles.burst(x, y, 22, 2.6, 34, 3.2, S.rowq[S.slot] == 2 and C.GOLD or C.GRASS, "star")
      particles.burst(x, y + 10, 10, 1.6, 22, 3, C.SOIL, "square")
      log(fmt("dig plant %d %d", S.slot, S.rowq[S.slot]))
    end
    if S.t > 62 and S.t % 30 == 0 then particles.burst(pics.PX[S.slot], pics.PY - 20, 4, 1.2, 24, 2.5, C.CREAM, "heart") end
    if S.slot == 5 then
      if S.t >= 150 then begin_harvest() end
    elseif (pressed and S.saw_release and S.t >= GARDEN_MIN) or S.t >= GARDEN_AUTO then
      next_cave()
    end
  elseif S.phase == "harvest" then
    S.t = S.t + 1
    if S.t % 34 == 0 then   -- fireworks
      local fx, fy = rnd(60, W - 60), rnd(110, 220)
      local col = ({C.GOLD, C.ROSE, C.AQUA, 0x9fe08a})[idiv(S.t, 34) % 4 + 1]
      particles.burst(fx, fy, 26, 3.6, 40, 3.4, col, "star")
      sfx.noise(0.12, 0.12, 3000)
      music.cue{wave = "sine", note = 84 + idiv(S.t, 34) % 5 * 2, dur = 0.3, vol = 0.12, release = 0.28}
    end
    if (pressed and S.saw_release and S.t >= HARVEST_MIN) or S.t >= HARVEST_AUTO then
      next_cave()
    end
  elseif S.phase == "restart" then
    S.restart_t = S.restart_t + 1
    S.near = 999
    if S.restart_t >= 70 then setup_level(S.level) end
  end

  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  if S.phase == "story" then pics.story(S.t)
  elseif S.phase == "garden" then pics.garden(S.t)
  elseif S.phase == "harvest" then pics.harvest(S.t)
  else
    pics.draw_cave()
    if S.phase == "clear" then pics.draw_clear_banner() end
  end
  particles.draw()
  local line = S.react_left > 0 and S.react or rest_line()
  if leaving() then line = rest_line() end
  if S.phase == "story" then line = leaving() and rest_line() or pics.story_line(S.t) end
  ui.band(line)
end
