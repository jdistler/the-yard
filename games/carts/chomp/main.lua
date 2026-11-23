-- Chomp!: A rich, kid-friendly Pac-Man homage!
-- 3 neon double-line mazes, butter-smooth auto-cornering, side warp tunnels, right-hand
-- Turbo Dash superpower, 4 classic-personality ghosts (Reddy, Rosie, Zippy, Goofy),
-- frightened-blue mode + 200/400/800/1600 chains, bonus fruits, and full retro chiptunes!
-- chomp.sav keeps "best N" (stages cleared) and "hi N" (high score).

local pics = import("pictures")
local C = pics.C

local COLS, ROWS, TS = 15, 16, 24
local OX, OY = 12, 72
local WARP_ROW = 8

local function cell_x(c) return OX + (c - 0.5) * TS end
local function cell_y(r) return OY + (r - 0.5) * TS end
local function x_cell(x) return clamp(floor((x - OX) / TS) + 1, 1, COLS) end
local function y_cell(y) return clamp(floor((y - OY) / TS) + 1, 1, ROWS) end

-- 3 handcrafted symmetric 15x16 classic arcade mazes (zero dead-ends, side warp on row 8!).
local MAZES = {
  -- Maze 1: Classic Neon Blue
  {
    "###############",
    "#o.....#.....o#",
    "#.##.#.#.#.##.#",
    "#.............#",
    "#.##.#.#.#.##.#",
    "#.............#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.##.#####.##.#",
    "#o.#...P...#.o#",
    "##.#.##.##.#.##",
    "#....#...#....#",
    "#.............#",
    "###############",
  },
  -- Maze 2: Emerald Open-Loop
  {
    "###############",
    "#o...#...#...o#",
    "#.##.#.#.#.##.#",
    "#.............#",
    "#.#.##.#.##.#.#",
    "#.#.........#.#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.#.##.#.##.#.#",
    "#o.....P.....o#",
    "#.##.#.#.#.##.#",
    "#....#...#....#",
    "#.............#",
    "###############",
  },
  -- Maze 3: Starlight Crisscross
  {
    "###############",
    "#o...........o#",
    "#.##.##.##.##.#",
    "#....#...#....#",
    "#.####.#.####.#",
    "#.............#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.####.#.####.#",
    "#o.....P.....o#",
    "#.##.#.#.#.##.#",
    "#....#...#....#",
    "#.............#",
    "###############",
  },
}

-- ------------------------------------------------------------------ Retro Arcade Chiptunes!
-- 1. Classic Arcade Maze Groove (144 BPM, 128-step, 5-track upbeat Pac-inspired homage!)
local maze_bed = {bpm = 144, steps = 4,
  {"C5 . C6 . G5 . E5 . C6 . G5 . E5 . . . " ..
   "D5 . D6 . A5 . F5 . D6 . A5 . F5 . . . " ..
   "E5 . E6 . B5 . G5 . E6 . B5 . G5 . . . " ..
   "F5 . G5 . A5 . B5 . C6 . G5 . C5 . . . " ..
   "A5 . G5 E5 . D5 C5 . D5 . E5 G5 . A5 . . " ..
   "G5 . E5 D5 . C5 A4 . C5 . D5 E5 . G5 . . " ..
   "A5 . B5 C6 . A5 G5 . E5 . G5 A5 . G5 E5 . " ..
   "D5 . E5 F5 . E5 D5 . C5 . G5 . C6 . . . ",
   wave = "square", vol = 0.18, release = 0.04, attack = 0.003, duty = 0.25, pan = -0.2},
  {". . G4 . . . C5 . . . E5 . C5 . . . " ..
   ". . A4 . . . D5 . . . F5 . D5 . . . " ..
   ". . B4 . . . E5 . . . G5 . E5 . . . " ..
   "A4 . B4 . C5 . D5 . E5 . C5 . G4 . . . " ..
   "C5 . . . G4 . . . A4 . . . C5 . . . " ..
   "B4 . . . G4 . . . E4 . . . B4 . . . " ..
   "C5 . D5 E5 . C5 B4 . G4 . B4 C5 . B4 G4 . " ..
   "F4 . G4 A4 . G4 F4 . E4 . C5 . E5 . . . ",
   wave = "square", vol = 0.11, release = 0.035, attack = 0.003, duty = 0.125, pan = 0.25},
  {"C3 . G2 . C3 . G2 . C3 . E3 . G2 . C3 . " ..
   "D3 . A2 . D3 . A2 . D3 . F3 . A2 . D3 . " ..
   "E3 . B2 . E3 . B2 . E3 . G3 . B2 . E3 . " ..
   "F2 . G2 . A2 . B2 . C3 . G2 . C3 . . . " ..
   "F2 . C3 . F2 . A2 . C3 . G2 . E2 . G2 . " ..
   "G2 . D3 . G2 . B2 . C3 . G2 . E2 . C3 . " ..
   "F2 . C3 . F2 . A2 . C3 . G2 . E2 . G2 . " ..
   "D3 . F2 . G2 . B2 . C3 . G2 . C3 . . . ",
   wave = "tri", vol = 0.29, release = 0.045, attack = 0.003},
  {"K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K . H . S . H H " ..
   "K . H . S . H . K . H K S . H . " ..
   "K . H . S . H . K S S H C . . . ",
   wave = "noise", vol = 0.12, release = 0.03, pan = 0.15}}

-- 2. Power Pellet Chase! (164 BPM high-energy ghost-chomping rush!)
local power_bed = {bpm = 164, steps = 4,
  {"C6 . B5 . A5 . G5 . A5 . B5 . C6 . E6 . " ..
   "D6 . C6 . B5 . A5 . B5 . C6 . D6 . F6 . " ..
   "E6 . D6 . C6 . B5 . C6 . D6 . E6 . G6 . " ..
   "F6 . E6 . D6 . C6 . B5 . G5 . C6 . . . ",
   wave = "square", vol = 0.20, release = 0.035, attack = 0.002, duty = 0.25, pan = -0.2},
  {"C3 C4 G2 G3 A2 A3 E2 E3 F2 F3 C3 C4 G2 G3 B2 B3 " ..
   "D3 D4 A2 A3 B2 B3 F2 F3 G2 G3 D3 D4 B2 B3 G2 G3 ",
   wave = "tri", vol = 0.30, release = 0.035, attack = 0.002},
  {"K H K H S H K H K K S H C H S H ",
   wave = "noise", vol = 0.14, release = 0.025, pan = 0.15}}

-- 3. Stage Clear Fanfare!
local clear_bed = {bpm = 148, steps = 4,
  {"C5 . E5 . G5 . C6 - - . B5 . C6 . D6 . E6 - - - C6 . G5 . E5 . G5 . C6 - - . ",
   wave = "square", vol = 0.20, release = 0.14, attack = 0.004, duty = 0.25, pan = -0.2},
  {"G4 . C5 . E5 . G5 - - . F5 . E5 . F5 . G5 - - - E5 . C5 . G4 . C5 . E5 - - . ",
   wave = "tri", vol = 0.22, release = 0.16, attack = 0.006, pan = 0.2},
  {"C3 - G2 - C3 - E3 - F2 - C3 - G2 - D3 - C3 - G2 - A2 - E2 - F2 - G2 - C3 - - . ",
   wave = "sine", vol = 0.25, release = 0.20, attack = 0.01}}

-- ------------------------------------------------------------------ Game State
local S = {
  COLS = COLS, ROWS = ROWS, TS = TS, OX = OX, OY = OY, WARP_ROW = WARP_ROW,
  phase = "ready", stage = 1, maze_id = 1, best = 0, hi = 0, score = 0,
  hurts = 0, hurt_cool = 0, ready_t = 0, clear_t = 0,
  grid = {}, dots = {}, dots_left = 0, dots_total = 0,
  px = 0, py = 0, fx = 1, fy = 0, want_x = 0, want_y = 0, moving = false, walk_t = 0, wakka = 0,
  power_t = 0, combo = 0, dash_t = 0, dash_cool = 0,
  ghosts = {}, fruit = nil, fruit_spawned = false,
  sx = 0, sy = 0, saw_release = false, react = "", react_left = 0, goodbye = false,
}
pics.S = S

local function react_to(s) S.react, S.react_left = s, 110 end
local function leaving() return input.down("1p") and input.down("2p") end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.hi then S.hi = S.score end
end

local function save_progress()
  if S.stage - 1 > S.best then S.best = S.stage - 1 end
  save.set("best", S.best)
  save.set("hi", S.hi)
  save.write()
end

local function passable(c, r, allow_gate)
  if r == WARP_ROW and (c < 1 or c > COLS) then return true end
  if r < 1 or r > ROWS or c < 1 or c > COLS then return false end
  local ch = S.grid[r][c]
  if ch == "#" then return false end
  if ch == "=" and not allow_gate then return false end
  return true
end

local function spawn_ghosts()
  local defs = {
    {id = 1, name = "Reddy", col = C.RED,    c = 8, r = 6, dx = -1, dy = 0, state = "chase", release = 0},
    {id = 2, name = "Rosie", col = C.PINK,   c = 8, r = 8, dx = 0,  dy = -1, state = "house", release = 45},
    {id = 3, name = "Zippy", col = C.CYAN,   c = 7, r = 8, dx = 1,  dy = 0,  state = "house", release = 110},
    {id = 4, name = "Goofy", col = C.ORANGE, c = 9, r = 8, dx = -1, dy = 0,  state = "house", release = 175},
  }
  S.ghosts = {}
  -- Maze 1 has two ghosts, maze 2 three, then all four: a gentle ramp for little hands.
  local count = min(S.stage + 1, 4)
  for _, d in ipairs(defs) do
    if d.id <= count then S.ghosts[#S.ghosts + 1] = {
      id = d.id, name = d.name, col = d.col,
      x = cell_x(d.c), y = cell_y(d.r), dx = d.dx, dy = d.dy,
      state = d.state, release = d.release,
    } end
  end
end

local function setup_stage(st)
  S.stage = st
  S.maze_id = ((st - 1) % #MAZES) + 1
  local raw = MAZES[S.maze_id]
  S.grid, S.dots = {}, {}
  S.dots_left, S.dots_total = 0, 0
  S.fruit, S.fruit_spawned = nil, false
  S.power_t, S.combo, S.dash_t, S.dash_cool, S.hurt_cool = 0, 0, 0, 0, 0
  S.hurts = 0

  for r = 1, ROWS do
    S.grid[r], S.dots[r] = {}, {}
    for c = 1, COLS do
      local ch = raw[r]:sub(c, c)
      S.grid[r][c] = ch
      if ch == "." then
        S.dots[r][c] = 1
        S.dots_left = S.dots_left + 1
      elseif ch == "o" then
        S.dots[r][c] = 2
        S.dots_left = S.dots_left + 1
      else
        S.dots[r][c] = 0
      end
      if ch == "P" then S.px, S.py, S.sx, S.sy = cell_x(c), cell_y(r), cell_x(c), cell_y(r) end
    end
  end
  S.dots_total = S.dots_left
  S.fx, S.fy, S.want_x, S.want_y = 1, 0, 0, 0
  spawn_ghosts()
  S.phase, S.ready_t, S.clear_t = "ready", 52, 0
  log("chomp stage " .. st)
  sfx.arp("square", {60, 64, 67, 72, 76, 79}, 0.06, 0.30)
  react_to("Maze " .. st .. "! Gobble all the dots!")
end

-- ------------------------------------------------------------------ Movement & Corner Assist!
local function step_player(mx, my)
  if mx ~= 0 and my ~= 0 then my = 0 end
  if mx ~= 0 or my ~= 0 then S.want_x, S.want_y = mx, my end

  local spd = S.dash_t > 0 and 3.4 or (S.power_t > 0 and 2.35 or 2.15)
  local c, r = x_cell(S.px), y_cell(S.py)
  local cx, cy = cell_x(c), cell_y(r)

  -- Butter-smooth auto-cornering: generous 10px lane-snap window so kids never snag on corners!
  if (S.want_x ~= 0 or S.want_y ~= 0) and (S.want_x ~= S.fx or S.want_y ~= S.fy) then
    if S.want_x ~= 0 and abs(S.py - cy) <= 10 and passable(c + S.want_x, r, false) then
      S.fx, S.fy = S.want_x, 0
      S.py = approach(S.py, cy, 0.5)
    elseif S.want_y ~= 0 and abs(S.px - cx) <= 10 and passable(c, r + S.want_y, false) then
      S.fx, S.fy = 0, S.want_y
      S.px = approach(S.px, cx, 0.5)
    end
  end

  local nx, ny = S.px + S.fx * spd, S.py + S.fy * spd
  -- Center-align on the orthogonal axis smoothly
  if S.fx ~= 0 then ny = approach(ny, cy, 0.35) elseif S.fy ~= 0 then nx = approach(nx, cx, 0.35) end

  -- Side warp tunnel!
  if r == WARP_ROW then
    if nx < OX - 6 then
      S.px, S.py = OX + COLS * TS + 4, cell_y(WARP_ROW)
      sfx.slide("sine", 620, 1040, 0.1, 0.2)
      particles.burst(S.px - 10, S.py, 10, 2, 18, 2.5, C.CYAN, "star")
      return
    elseif nx > OX + COLS * TS + 6 then
      S.px, S.py = OX - 4, cell_y(WARP_ROW)
      sfx.slide("sine", 620, 1040, 0.1, 0.2)
      particles.burst(S.px + 10, S.py, 10, 2, 18, 2.5, C.CYAN, "star")
      return
    end
  end

  -- Check ahead tile collision
  local ahead_c = x_cell(nx + S.fx * 9)
  local ahead_r = y_cell(ny + S.fy * 9)
  if passable(ahead_c, ahead_r, false) then
    S.px, S.py = nx, ny
    S.moving = true
    S.walk_t = S.walk_t + 1
    if S.dash_t > 0 and game.frame % 3 == 0 then
      particles.burst(S.px, S.py, 2, 1.0, 12, 2.2, C.GOLD, "star")
    end
  else
    S.px, S.py = approach(S.px, cx, 0.5), approach(S.py, cy, 0.5)
    S.moving = false
  end

  -- Eat dots & Power Pellets!
  local ec, er = x_cell(S.px), y_cell(S.py)
  local d = S.dots[er] and S.dots[er][ec] or 0
  if d == 1 then
    S.dots[er][ec] = 0
    S.dots_left = S.dots_left - 1
    add_score(10)
    -- Iconic alternating wakka-wakka 2-tone chomp!
    S.wakka = 1 - S.wakka
    sfx.note("tri", S.wakka == 0 and 62 or 67, 0.055, 0.20)
  elseif d == 2 then
    S.dots[er][ec] = 0
    S.dots_left = S.dots_left - 1
    add_score(50)
    S.power_t = max(280, 420 - S.stage * 28)
    S.combo = 0
    for _, g in ipairs(S.ghosts) do
      if g.state == "chase" then
        g.state = "fright"
        g.dx, g.dy = -g.dx, -g.dy
      end
    end
    music.play(power_bed)
    sfx.arp("square", {72, 76, 79, 84}, 0.04, 0.30)
    particles.burst(S.px, S.py, 18, 2.8, 26, 3, C.GOLD, "star")
    particles.text(S.px, S.py - 16, C.GOLD, "POWER UP!")
    react_to("POWER PELLET! Chomp the blue ghosts!")
  end

  -- Spawn classic Bonus Fruit halfway through the maze!
  if not S.fruit_spawned and S.dots_left <= floor(S.dots_total * 0.55) then
    S.fruit_spawned = true
    local fk = ((S.stage - 1) % 5) + 1
    S.fruit = {x = cell_x(8), y = cell_y(10), kind = fk, life = 480}
    sfx.arp("tri", {76, 79, 84}, 0.05, 0.25)
    particles.burst(S.fruit.x, S.fruit.y, 12, 2, 20, 2.5, C.GOLD, "star")
    react_to("Yum! Bonus fruit appeared!")
  end
  if S.fruit then
    S.fruit.life = S.fruit.life - 1
    if dist(S.px, S.py, S.fruit.x, S.fruit.y) < 18 then
      local fpts = ({100, 300, 500, 700, 1000})[S.fruit.kind] or 300
      add_score(fpts)
      log("chomp fruit " .. fpts)
      sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.32)
      particles.burst(S.fruit.x, S.fruit.y, 20, 2.8, 28, 3, C.GOLD, "star")
      particles.text(S.fruit.x, S.fruit.y - 16, C.GOLD, "+" .. fpts)
      react_to("Tasty bonus fruit! +" .. fpts .. " points!")
      S.fruit = nil
    elseif S.fruit.life <= 0 then
      S.fruit = nil
    end
  end
end

-- ------------------------------------------------------------------ Classic Ghost AI!
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

local function ghost_target(g)
  if g.state == "eyes" then return cell_x(8), cell_y(8) end
  if g.state == "fright" then
    -- Run away from Chompy!
    return S.px < W / 2 and W or 0, S.py < H / 2 and H or 0
  end
  if g.id == 1 then
    -- Reddy (Blinky): direct gentle chaser
    return S.px, S.py
  elseif g.id == 2 then
    -- Rosie (Pinky): aims 3 tiles ahead of Chompy
    return S.px + S.fx * TS * 3, S.py + S.fy * TS * 3
  elseif g.id == 3 then
    -- Zippy (Inky): patrols near Chompy with playful offset
    return S.px + cos(game.frame * 0.02) * 72, S.py + sin(game.frame * 0.02) * 72
  else
    -- Goofy (Clyde): shy — retreats to bottom-left corner if close!
    if dist(g.x, g.y, S.px, S.py) < 96 then return cell_x(2), cell_y(15) end
    return S.px, S.py
  end
end

local function step_ghosts()
  local base_spd = min(1.85, 1.32 + (S.stage - 1) * 0.12)
  for _, g in ipairs(S.ghosts) do
    if g.state == "house" then
      g.release = g.release - 1
      g.y = cell_y(8) + sin(game.frame * 0.12 + g.id) * 3
      if g.release <= 0 then
        g.x = approach(g.x, cell_x(8), 0.25)
        if abs(g.x - cell_x(8)) < 2 then
          g.state = S.power_t > 0 and "fright" or "chase"
          g.x, g.y = cell_x(8), cell_y(6)
          g.dx, g.dy = (g.id % 2 == 0) and 1 or -1, 0
        end
      end
    else
      local spd = g.state == "eyes" and 3.4 or (g.state == "fright" and base_spd * 0.68 or base_spd)
      local c, r = x_cell(g.x), y_cell(g.y)
      local cx, cy = cell_x(c), cell_y(r)

      -- Choose best turn ONCE per tile center (never 180-reverse unless forced)
      if (c ~= g.last_c or r ~= g.last_r) and abs(g.x - cx) <= spd + 0.5 and abs(g.y - cy) <= spd + 0.5 then
        g.last_c, g.last_r = c, r
        local tx, ty = ghost_target(g)
        local best_d, best_score = nil, 1e12
        for _, d in ipairs(DIRS) do
          local rev = (d[1] == -g.dx and d[2] == -g.dy)
          if not rev and passable(c + d[1], r + d[2], g.state == "eyes") then
            local nx, ny = cell_x(c + d[1]), cell_y(r + d[2])
            local sc = (nx - tx) ^ 2 + (ny - ty) ^ 2
            if sc < best_score then best_score, best_d = sc, d end
          end
        end
        if best_d then
          g.dx, g.dy = best_d[1], best_d[2]
          if g.dx ~= 0 then g.y = cy else g.x = cx end
        else
          g.dx, g.dy = -g.dx, -g.dy
        end
      end

      g.x = g.x + g.dx * spd
      g.y = g.y + g.dy * spd

      -- Warp tunnel for ghosts too!
      if r == WARP_ROW then
        if g.x < OX - 6 then g.x = OX + COLS * TS + 4
        elseif g.x > OX + COLS * TS + 6 then g.x = OX - 4 end
      end

      -- Floating eyes reach Ghost House -> reform!
      if g.state == "eyes" and dist(g.x, g.y, cell_x(8), cell_y(8)) < 12 then
        g.state = "house"
        g.release = 45
        g.x, g.y = cell_x(8), cell_y(8)
        sfx.note("sine", 74, 0.08, 0.16)
      end

      -- Collision with Chompy!
      if g.state ~= "eyes" and dist(g.x, g.y, S.px, S.py) < 17 then
        if g.state == "fright" then
          g.state = "eyes"
          S.combo = min(S.combo + 1, 4)
          local pts = floor(100 * (2 ^ S.combo))
          add_score(pts)
          log("chomp ghost " .. pts)
          sfx.arp("square", {72, 79, 84, 91}, 0.035, 0.34)
          gfx.shake(4)
          particles.burst(g.x, g.y, 20, 3.0, 26, 3, C.CYAN, "star")
          particles.text(g.x, g.y - 16, C.GOLD, tostring(pts))
          react_to("CHOMP! +" .. pts .. " points!")
        elseif S.hurt_cool == 0 and S.dash_t == 0 then
          S.hurts = S.hurts + 1
          S.hurt_cool = 110
          sfx.slide("square", 460, 180, 0.22, 0.26)
          gfx.shake(5)
          particles.burst(S.px, S.py, 14, 2.4, 24, 2.8, C.ROSE, "star")
          if S.hurts >= 3 then
            -- Soft restart: the dots he already ate stay eaten; only the ghosts and Chompy go home.
            save_progress()
            S.hurts, S.hurt_cool, S.power_t, S.dash_t, S.combo = 0, 0, 0, 0, 0
            S.px, S.py, S.fx, S.fy, S.want_x, S.want_y = S.sx, S.sy, 1, 0, 0, 0
            spawn_ghosts()
            S.phase, S.ready_t = "ready", 52
            log("chomp restart " .. game.frame)
            music.play(maze_bed)
            react_to("Nice try! The dots you ate stay eaten!")
            return
          else
            -- Gentle bounce back to safe lane without losing dot progress!
            g.dx, g.dy = -g.dx, -g.dy
            react_to("Oops! " .. g.name .. " tagged you! Keep going!")
          end
        end
      end
    end
  end
end

-- ------------------------------------------------------------------ Built-in Bot
function bot()
  if S.phase == "clear" then
    if S.clear_t > 65 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase ~= "play" then return end

  -- Use Turbo Dash when charged for fun speed!
  if S.dash_cool == 0 and game.frame % 25 == 0 then input.bot("low") end

  local pc, pr = x_cell(S.px), y_cell(S.py)
  -- Find nearest blue ghost (when powered) or nearest dot/power pellet!
  local tx, ty, best_d = nil, nil, 1e12
  if S.power_t > 40 then
    for _, g in ipairs(S.ghosts) do
      if g.state == "fright" then
        local d = (g.x - S.px) ^ 2 + (g.y - S.py) ^ 2
        if d < best_d then best_d, tx, ty = d, g.x, g.y end
      end
    end
  end
  if not tx then
    for r = 1, ROWS do
      for c = 1, COLS do
        local v = S.dots[r][c]
        if v > 0 then
          local wx, wy = cell_x(c), cell_y(r)
          local d = (wx - S.px) ^ 2 + (wy - S.py) ^ 2 - (v == 2 and 3500 or 0)
          if d < best_d then best_d, tx, ty = d, wx, wy end
        end
      end
    end
  end
  if not tx then return end

  -- Pick passable neighbor minimizing distance to target while avoiding non-frightened ghosts!
  local pick, pscore = nil, 1e12
  for _, d in ipairs(DIRS) do
    if passable(pc + d[1], pr + d[2], false) then
      local nx, ny = cell_x(pc + d[1]), cell_y(pr + d[2])
      local sc = (nx - tx) ^ 2 + (ny - ty) ^ 2
      if d[1] == S.fx and d[2] == S.fy then sc = sc - 1600 end
      if d[1] == -S.fx and d[2] == -S.fy then sc = sc + 4500 end
      for _, g in ipairs(S.ghosts) do
        if g.state == "chase" and dist(nx, ny, g.x, g.y) < 42 then sc = sc + 25000 end
      end
      if sc < pscore then pscore, pick = sc, d end
    end
  end
  if pick then
    if pick[1] < 0 then input.bot("left") elseif pick[1] > 0 then input.bot("right")
    elseif pick[2] < 0 then input.bot("up") elseif pick[2] > 0 then input.bot("down") end
  end
end

-- ------------------------------------------------------------------ Lifecycle
function init()
  sfx.master(0.42)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 100000)
  S.hi = clamp(save.get("hi", 0), 0, 999999)
  log("chomp hi " .. S.hi)
  setup_stage(1)
end

function quit()
  save_progress()
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.dash_t > 0 then S.dash_t = S.dash_t - 1 end
  if S.dash_cool > 0 then S.dash_cool = S.dash_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if S.phase == "ready" then
    S.ready_t = S.ready_t - 1
    if S.ready_t <= 0 then
      S.phase = "play"
      music.play(maze_bed)
      music.tempo(1)
      music.volume(1)
    end
  elseif S.phase == "play" then
    if pressed and S.saw_release and S.dash_cool == 0 then
      S.dash_t = 48
      S.dash_cool = 180
      sfx.slide("square", 520, 1040, 0.12, 0.24)
      particles.burst(S.px, S.py, 14, 2.6, 20, 2.5, C.GOLD, "star")
      particles.text(S.px, S.py - 16, C.GOLD, "TURBO!")
    end

    if S.power_t > 0 then
      S.power_t = S.power_t - 1
      if S.power_t == 0 then
        for _, g in ipairs(S.ghosts) do
          if g.state == "fright" then g.state = "chase" end
        end
        music.play(maze_bed)
      end
    end

    step_player(mx, my)
    if S.phase == "play" then step_ghosts() end

    -- Stage Clear!
    if S.dots_left <= 0 then
      S.phase, S.clear_t = "clear", 0
      add_score(500)
      if S.stage > S.best then S.best = S.stage end
      save.set("best", S.best)
      save.set("hi", S.hi)
      save.write()
      log("chomp clear " .. S.stage)
      music.play(clear_bed)
      sfx.arp("tri", {72, 76, 79, 84, 88}, 0.06, 0.34)
      particles.burst(W / 2, 220, 32, 3.6, 42, 3.4, C.GOLD, "star")
      react_to("Maze " .. S.stage .. " CLEAR! Awesome chomping!")
    end
  elseif S.phase == "clear" then
    S.clear_t = S.clear_t + 1
    if S.clear_t % 12 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.6, 2.0), 75, rnd(3, 4.5),
        S.clear_t % 24 == 0 and C.GOLD or C.CYAN, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.clear_t >= 60) or S.clear_t >= 180 then
      snd.ok()
      setup_stage(S.stage + 1)
    end
  end

  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  pics.draw()
  particles.draw()
  local line = S.react_left > 0 and S.react or (
    S.power_t > 0 and "POWER UP! Chomp the blue ghosts!" or
    (S.dash_cool == 0 and "Stick steers! Press any button for TURBO DASH!" or "Gobble every dot and grab the Power Pellets!"))
  if leaving() then line = "Great chomping! See you soon!" end
  ui.band(line)
end
