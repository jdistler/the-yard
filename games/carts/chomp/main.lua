-- Chomp!: a maze chase with a story. The ghosts tossed the sky's stars into six little maze worlds, and Chompy
-- gobbles the star dust to bring them home: every maze cleared lights one star of a constellation (Chompy's own
-- face) that keeps filling across visits. The four ghosts have faces and habits, the song layers in as the dots
-- are eaten, every dot is a note of it, and it turns when the ghosts go blue. See DESIGN.md.
--
-- Rules for the code: game logic counts game.frame and never reads music.step() (that is for drawing and for the
-- pitch of a music.cue); chance is only the seeded rnd; nothing here draws.
-- chomp.sav keeps "best N" (stages cleared), "hi N" (high score) and, new, the sky and the shelf.

local pics = import("pictures")
local songs = import("songs")
local C = pics.C

local COLS, ROWS, TS = 15, 16, 24
local OX, OY = 12, 72
local WARP_ROW = 8
local NSTARS = pics.NSTARS
local STORY_MIN, STORY_SPLIT, STORY_END = 24, pics.STORY_SPLIT, 400
local MAP_MIN, MAP_AUTO = 70, 240

local function cell_x(c) return OX + (c - 0.5) * TS end
local function cell_y(r) return OY + (r - 0.5) * TS end
local function x_cell(x) return clamp(floor((x - OX) / TS) + 1, 1, COLS) end
local function y_cell(y) return clamp(floor((y - OY) / TS) + 1, 1, ROWS) end

-- Six symmetric 15x16 mazes (zero dead-ends, side warp on row 8). The ghost house, the fruit and Chompy's
-- start are the same in all of them; the rest is each world's own.
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
  -- Maze 4: Candy Lane
  {
    "###############",
    "#o...........o#",
    "#.##.#####.##.#",
    "#.............#",
    "#.#...###...#.#",
    "#.............#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.##.#.#.#.##.#",
    "#o...#.P.#...o#",
    "#.##.#...#.##.#",
    "#.....#.#.....#",
    "#.............#",
    "###############",
  },
  -- Maze 5: Frost Cave
  {
    "###############",
    "#o.....#.....o#",
    "#.###.....###.#",
    "#.............#",
    "#.##.#####.##.#",
    "#.............#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.###.#.#.###.#",
    "#o.....P.....o#",
    "#.###.###.###.#",
    "#.#...###...#.#",
    "#.............#",
    "###############",
  },
  -- Maze 6: Coral Reef
  {
    "###############",
    "#o...........o#",
    "#.#####.#####.#",
    "#.............#",
    "#.##.#.#.#.##.#",
    "#.............#",
    "####.##=##.####",
    " .....GGG..... ",
    "####.#####.####",
    "#......F......#",
    "#.#.##.#.##.#.#",
    "#o.....P.....o#",
    "#.##.#...#.##.#",
    "#....#.#.#....#",
    "#.............#",
    "###############",
  },
}

-- ------------------------------------------------------------------ Game State
local S = {
  COLS = COLS, ROWS = ROWS, TS = TS, OX = OX, OY = OY, WARP_ROW = WARP_ROW,
  phase = "story", stage = 1, maze_id = 1, theme = 1, best = 0, hi = 0, score = 0,
  hurts = 0, hurt_cool = 0, ready_t = 0, clear_t = 0, t = 0, age = 0,
  grid = {}, dots = {}, dots_left = 0, dots_total = 0,
  px = 0, py = 0, fx = 1, fy = 0, want_x = 0, want_y = 0, moving = false, walk_t = 0, wakka = 0,
  power_t = 0, combo = 0, dash_t = 0, dash_cool = 0,
  ghosts = {}, fruit = nil, fruit_spawned = false,
  sx = 0, sy = 0, saw_release = false, react = "", react_left = 0, goodbye = false,
  -- what grows between visits
  stars = 0, visits = 1, grand = 0, look = 0, fr = {0, 0, 0, 0, 0}, gh = {0, 0, 0, 0},
  new_star = false, new_look = false,
  -- what the pictures read (texts are built when they change, never per frame)
  pel = {false, false, false, false}, whew_t = 0, whew_cool = 0, danger_t = 0,
  stage_txt = "STAGE 1", score_txt = "PTS 0", hi_txt = "HI 0", clear_txt = "", clear_score_txt = "",
  fr_txt = {"", "", "", "", ""}, gh_txt = {"", "", "", ""}, grand_txt = "",
  sky_title = "", sky_line = "", map_line = "",
  gal = {},   -- the four ghosts as the shelf and the story draw them
  -- sound only
  run = 0, last_dot = -999, cue_f = -999,
}
pics.S = S

local GHOSTS = {
  {id = 1, name = "Reddy", col = C.RED,    c = 8, r = 6, dx = -1, dy = 0, state = "chase", release = 0},
  {id = 2, name = "Rosie", col = C.PINK,   c = 8, r = 8, dx = 0,  dy = -1, state = "house", release = 45},
  {id = 3, name = "Zippy", col = C.CYAN,   c = 7, r = 8, dx = 1,  dy = 0,  state = "house", release = 110},
  {id = 4, name = "Goofy", col = C.ORANGE, c = 9, r = 8, dx = -1, dy = 0,  state = "house", release = 175},
}
for i, d in ipairs(GHOSTS) do
  S.gal[i] = {id = d.id, col = d.col, x = 0, y = 0, dx = 0, dy = 1, state = "chase", taunt = 0, release = 0}
end

local function react_to(s) S.react, S.react_left = s, 110 end
local function leaving() return input.down("1p") and input.down("2p") end

local function theme_of(st) return ((st - 1) + idiv(st - 1, 6)) % 6 + 1 end
local function look_for(stars) return stars >= 15 and 3 or (stars >= 8 and 2 or (stars >= 3 and 1 or 0)) end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.hi then S.hi = S.score; S.hi_txt = "HI " .. S.hi end
  S.score_txt = "PTS " .. S.score
end

local function words()   -- the texts the shelf and the sky show
  for i = 1, 5 do S.fr_txt[i] = "x" .. S.fr[i] end
  for i = 1, 4 do S.gh_txt[i] = "x" .. S.gh[i] end
  S.grand_txt = "x" .. S.grand
  if S.stars >= NSTARS then
    S.sky_title = "THE SKY SHINES!"
    S.sky_line = (S.stars > NSTARS) and (S.stars .. " stars gobbled home! Chomp more!") or "Every star is home! The sky shines!"
  else
    S.sky_title = "STARS HOME " .. S.stars .. "/" .. NSTARS
    S.sky_line = (S.stars == 0) and "Gobble the star dust to light the sky!"
      or (S.stars .. (S.stars == 1 and " star is" or " stars are") .. " home! Let's get more!")
  end
end

local function save_all()
  if S.stage - 1 > S.best then S.best = S.stage - 1 end
  save.set("best", S.best)
  save.set("hi", S.hi)
  save.set("stars", S.stars)
  save.set("visits", S.visits)
  save.set("grand", S.grand)
  for i = 1, 5 do save.set("fr" .. i, S.fr[i]) end
  for i = 1, 4 do save.set("gh" .. i, S.gh[i]) end
  save.write()
end

-- ------------------------------------------------------------------ the music
local LV = {1, 1, 1, 1, 1, 1}   -- the levels asked of the song's tracks, so music.track is called only on a change

local function set_level(i, v)
  if LV[i] ~= v then
    LV[i] = v
    music.track(i, v)
  end
end

local function play_song(song)
  music.play(song)
  if not song.keep then for i = 1, 6 do LV[i] = 1 end end
end

-- Layers follow the dots: a fresh maze is bass and pad; then the shimmer, the drums, the stabs, and at last
-- the lead. A ghost close brings the drums in early; blue ghosts bring everything; a tag lets the lead go.
local function update_mix()
  local f = 1 - S.dots_left / max(1, S.dots_total)
  local blue = S.power_t > 0
  local shim = (f >= 0.05 or blue) and 1 or 0
  local drums = (f >= 0.15 or blue or S.danger_t > 0) and 1 or 0
  local counter = (f >= 0.3 or blue) and 1 or 0
  local lead = 0
  if blue then lead = 1.1 elseif f >= 0.75 then lead = 1.2 elseif f >= 0.45 then lead = 0.85 end
  if S.hurt_cool > 0 then lead = min(lead, 0.3) drums = min(drums, 0.5) end
  set_level(1, lead)
  set_level(2, counter)
  set_level(4, shim)
  set_level(5, drums)
end

-- A chord under the beat a cue will land on (sound only).
local function cue_chord(vol, up, root_only)
  local ls = music.step() + 1
  ls = ls + (4 - ls % 4)
  local root, t3 = songs.chord(S.theme, ls)
  root = root + (up or 0)
  music.cue{wave = "square", duty = 0.25, note = root, dur = 0.4, vol = vol, release = 0.35, at = "beat"}
  if not root_only then
    music.cue{wave = "square", duty = 0.25, note = root + t3, dur = 0.4, vol = vol * 0.8, release = 0.35, at = "beat"}
    music.cue{wave = "tri", note = root + 7, dur = 0.4, vol = vol, release = 0.35, at = "beat"}
    music.cue{wave = "sine", note = root + 12, dur = 0.5, vol = vol * 0.9, release = 0.45, at = "beat"}
  end
  S.cue_f = game.frame + 8   -- a stinger rests the dots for a moment
end

-- Every dot is a note of the song: the chord's own tones, alternating, one at most per step.
local function cue_dot()
  local f = game.frame
  if f - S.last_dot > 70 then S.run = 0 end
  S.last_dot = f
  local n = S.run
  S.run = S.run + 1
  if f - S.cue_f < 7 then return end
  S.cue_f = f
  music.cue{wave = "tri", note = songs.dot_note(S.theme, music.step() + 1, n), dur = 0.07, vol = 0.22, release = 0.06}
end

-- ------------------------------------------------------------------ the maze
local function passable(c, r, allow_gate)
  if r == WARP_ROW and (c < 1 or c > COLS) then return true end
  if r < 1 or r > ROWS or c < 1 or c > COLS then return false end
  local ch = S.grid[r][c]
  if ch == "#" then return false end
  if ch == "=" and not allow_gate then return false end
  return true
end

local function spawn_ghosts()
  S.ghosts = {}
  -- Maze 1 has two ghosts, maze 2 three, then all four: a gentle ramp for little hands.
  local count = min(S.stage + 1, 4)
  for _, d in ipairs(GHOSTS) do
    if d.id <= count then S.ghosts[#S.ghosts + 1] = {
      id = d.id, name = d.name, col = d.col,
      x = cell_x(d.c), y = cell_y(d.r), dx = d.dx, dy = d.dy,
      state = d.state, release = d.release, taunt = 0, shy = false,
    } end
  end
end

local function setup_stage(st)
  S.stage = st
  S.theme = theme_of(st)
  S.maze_id = ((st - 1) % #MAZES) + 1
  local raw = MAZES[S.maze_id]
  S.grid, S.dots = {}, {}
  S.dots_left, S.dots_total = 0, 0
  S.fruit, S.fruit_spawned = nil, false
  S.power_t, S.combo, S.dash_t, S.dash_cool, S.hurt_cool = 0, 0, 0, 0, 0
  S.whew_t, S.whew_cool, S.danger_t = 0, 0, 0
  S.hurts = 0
  for i = 1, 4 do S.pel[i] = false end

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
  S.stage_txt = "STAGE " .. st
  spawn_ghosts()
  S.phase, S.ready_t, S.clear_t = "ready", 52, 0
  music.stop()
  log("chomp stage " .. st)
  log("chomp world " .. S.theme)
  sfx.arp("square", {60, 64, 67, 72, 76, 79}, 0.06, 0.30)
  react_to(pics.THEMES[S.theme].name .. "! Gobble the star dust!")
end

-- ------------------------------------------------------------------ Movement & Corner Assist
local function chomp_fruit_hit()
  local fpts = ({100, 300, 500, 700, 1000})[S.fruit.kind] or 300
  add_score(fpts)
  log("chomp fruit " .. fpts)
  local k = S.fruit.kind
  S.fr[k] = min(S.fr[k] + 1, 100000)
  sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.32)
  cue_chord(0.26, 12)
  particles.burst(S.fruit.x, S.fruit.y, 20, 2.8, 28, 3, C.GOLD, "star")
  particles.text(S.fruit.x, S.fruit.y - 16, C.GOLD, "+" .. fpts)
  react_to("Tasty bonus fruit! +" .. fpts .. " points!")
  if S.fr[k] == 1 then   -- a new one for the shelf
    log("chomp newfruit " .. k)
    words()
    save_all()
    react_to("A new fruit for your shelf! +" .. fpts .. " points!")
  end
  S.fruit = nil
end

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

  -- Eat dots and the big stars!
  local ec, er = x_cell(S.px), y_cell(S.py)
  local d = S.dots[er] and S.dots[er][ec] or 0
  if d == 1 then
    S.dots[er][ec] = 0
    S.dots_left = S.dots_left - 1
    add_score(10)
    S.wakka = 1 - S.wakka
    cue_dot()
  elseif d == 2 then
    S.dots[er][ec] = 0
    S.dots_left = S.dots_left - 1
    add_score(50)
    S.pel[(er < 8 and 0 or 2) + (ec < 8 and 1 or 2)] = true
    local was_blue = S.power_t > 0
    S.power_t = max(280, 420 - S.stage * 28)
    S.combo = 0
    for _, g in ipairs(S.ghosts) do
      if g.state == "chase" then
        g.state = "fright"
        g.dx, g.dy = -g.dx, -g.dy
      end
    end
    if not was_blue then   -- the song turns: same bar, same layers, a new section
      play_song(songs.song(S.theme, true, true))
      music.tempo(1.12)
    end
    sfx.arp("square", {72, 76, 79, 84}, 0.04, 0.30)
    cue_chord(0.24, 0)
    particles.burst(S.px, S.py, 18, 2.8, 26, 3, C.GOLD, "star")
    particles.text(S.px, S.py - 16, C.GOLD, "BIG STAR!")
    react_to("BIG STAR! Chomp the blue ghosts!")
  end

  -- Bonus fruit halfway through the maze (a different one each time you win a star)
  if not S.fruit_spawned and S.dots_left <= floor(S.dots_total * 0.55) then
    S.fruit_spawned = true
    local fk = ((S.stage - 1 + S.stars) % 5) + 1
    S.fruit = {x = cell_x(8), y = cell_y(10), kind = fk, life = 480}
    sfx.arp("tri", {76, 79, 84}, 0.05, 0.25)
    particles.burst(S.fruit.x, S.fruit.y, 12, 2, 20, 2.5, C.GOLD, "star")
    react_to("Yum! Bonus fruit appeared!")
  end
  if S.fruit then
    S.fruit.life = S.fruit.life - 1
    if dist(S.px, S.py, S.fruit.x, S.fruit.y) < 18 then
      chomp_fruit_hit()
    elseif S.fruit.life <= 0 then
      S.fruit = nil
    end
  end
end

-- ------------------------------------------------------------------ the ghosts (each has a habit)
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

local function ghost_target(g)
  if g.state == "eyes" then return cell_x(8), cell_y(8) end
  if g.state == "fright" then
    -- Run away from Chompy (Zippy zigzags about it)
    local wob = g.id == 3 and sin(game.frame * 0.05) * 90 or 0
    return (S.px < W / 2 and W or 0) + wob, S.py < H / 2 and H or 0
  end
  if g.id == 1 then
    -- Reddy: bold, runs straight at him
    return S.px, S.py
  elseif g.id == 2 then
    -- Rosie: sly, aims 3 tiles ahead of Chompy
    return S.px + S.fx * TS * 3, S.py + S.fy * TS * 3
  elseif g.id == 3 then
    -- Zippy: giddy, circles round him
    return S.px + cos(game.frame * 0.02) * 72, S.py + sin(game.frame * 0.02) * 72
  else
    -- Goofy: shy, runs for the bottom-left corner when he gets close
    if dist(g.x, g.y, S.px, S.py) < 96 then return cell_x(2), cell_y(15) end
    return S.px, S.py
  end
end

-- each ghost laughs in its own voice when it tags him
local function taunt_voice(g)
  if g.id == 1 then sfx.note("square", 52, 0.12, 0.18); sfx.note("square", 47, 0.14, 0.16)
  elseif g.id == 2 then sfx.arp("sine", {88, 93}, 0.06, 0.16)
  elseif g.id == 3 then sfx.arp("tri", {96, 100, 96, 100}, 0.04, 0.16)
  else sfx.slide("sine", 760, 540, 0.14, 0.16) end
end

local function step_ghosts()
  local base_spd = min(1.85, 1.32 + (S.stage - 1) * 0.12)
  if S.danger_t > 0 then S.danger_t = S.danger_t - 1 end
  if S.whew_cool > 0 then S.whew_cool = S.whew_cool - 1 end
  for _, g in ipairs(S.ghosts) do
    if g.taunt > 0 then g.taunt = g.taunt - 1 end
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
      local dp = dist(g.x, g.y, S.px, S.py)
      g.shy = (g.id == 4 and g.state == "chase" and dp < 96)
      if g.state == "chase" and dp < 80 then S.danger_t = 100 end

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

      if r == WARP_ROW then
        if g.x < OX - 6 then g.x = OX + COLS * TS + 4
        elseif g.x > OX + COLS * TS + 6 then g.x = OX - 4 end
      end

      -- Floating eyes reach the ghost house -> reform
      if g.state == "eyes" and dist(g.x, g.y, cell_x(8), cell_y(8)) < 12 then
        g.state = "house"
        g.release = 45
        g.x, g.y = cell_x(8), cell_y(8)
        sfx.note("sine", 74, 0.08, 0.16)
      end

      -- Collision with Chompy
      if g.state ~= "eyes" and dist(g.x, g.y, S.px, S.py) < 17 then
        if g.state == "fright" then
          g.state = "eyes"
          S.combo = min(S.combo + 1, 4)
          local pts = floor(100 * (2 ^ S.combo))
          add_score(pts)
          log("chomp ghost " .. pts)
          sfx.arp("square", {72, 79, 84, 91}, 0.035, 0.34)
          cue_chord(0.2 + S.combo * 0.03, S.combo >= 3 and 12 or 0)
          gfx.shake(4)
          particles.burst(g.x, g.y, 20, 3.0, 26, 3, C.CYAN, "star")
          particles.text(g.x, g.y - 16, C.GOLD, tostring(pts))
          react_to("CHOMP! +" .. pts .. " points!")
          S.gh[g.id] = min(S.gh[g.id] + 1, 100000)
          if S.gh[g.id] == 1 then   -- a new face for the shelf
            log("chomp friend " .. g.id)
            words()
            save_all()
            react_to(g.name .. " is on your shelf! +" .. pts .. " points!")
          end
          if S.combo == 4 then   -- all four in one big star
            S.grand = min(S.grand + 1, 100000)
            log("chomp chain4")
            particles.text(S.px, S.py - 32, C.CYAN, "FOUR IN A ROW!")
            react_to("FOUR IN A ROW! What a chomp!")
            words()
            save_all()
          end
        elseif S.dash_t > 0 then
          -- too fast to catch: a near miss
          if S.whew_cool == 0 then
            S.whew_t, S.whew_cool = 50, 110
            log("chomp whew " .. game.frame)
            sfx.arp("sine", {84, 88, 91}, 0.04, 0.16)
          end
        elseif S.hurt_cool == 0 then
          S.hurts = S.hurts + 1
          S.hurt_cool = 110
          g.taunt = 70
          taunt_voice(g)
          sfx.slide("square", 460, 180, 0.22, 0.26)
          gfx.shake(5)
          particles.burst(S.px, S.py, 14, 2.4, 24, 2.8, C.ROSE, "star")
          if S.hurts >= 3 then
            -- Soft restart: the dots he already ate stay eaten; only the ghosts and Chompy go home.
            save_all()
            local was_blue = S.power_t > 0
            S.hurts, S.hurt_cool, S.power_t, S.dash_t, S.combo = 0, 0, 0, 0, 0
            S.px, S.py, S.fx, S.fy, S.want_x, S.want_y = S.sx, S.sy, 1, 0, 0, 0
            spawn_ghosts()
            S.phase, S.ready_t = "ready", 52
            log("chomp restart " .. game.frame)
            if was_blue then
              play_song(songs.song(S.theme, false, true))
              music.tempo(1)
            end
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
-- A path-follower: breadth-first over the maze cells (the warp row wraps) from where Chompy is, to the nearest
-- star dust (a big star counts a few steps nearer) or, while the ghosts are blue and the time is long enough,
-- the nearest blue ghost. Cells a chasing ghost is within two cells of are walls to it, unless that leaves nothing.
local NCELL = ROWS * COLS
local BD, BF, BQ, BX = {}, {}, {}, {}
for i = 1, NCELL do BD[i], BF[i], BQ[i], BX[i] = -1, 0, 0, false end

local function bfs(avoid, want_ghost)
  for i = 1, NCELL do BD[i], BX[i] = -1, false end
  local pc, pr = x_cell(S.px), y_cell(S.py)
  if avoid then
    for _, g in ipairs(S.ghosts) do
      if g.state == "chase" then
        local gc, gr = x_cell(g.x), y_cell(g.y)
        for dr = -2, 2 do
          for dc = -2, 2 do
            if abs(dr) + abs(dc) <= 2 then
              local rr, cc = gr + dr, gc + dc
              if rr >= 1 and rr <= ROWS and cc >= 1 and cc <= COLS and not (rr == pr and cc == pc) then
                BX[(rr - 1) * COLS + cc] = true
              end
            end
          end
        end
      end
    end
  end
  local head, tail = 1, 1
  local s0 = (pr - 1) * COLS + pc
  BQ[1], BD[s0], BF[s0] = s0, 0, 0
  -- heading first, so a tie goes straight on
  local order = 0
  for k = 1, 4 do if DIRS[k][1] == S.fx and DIRS[k][2] == S.fy then order = k - 1 end end
  while head <= tail do
    local cur = BQ[head]
    head = head + 1
    local r, c = idiv(cur - 1, COLS) + 1, (cur - 1) % COLS + 1
    for k = 0, 3 do
      local d = DIRS[(k + order) % 4 + 1]
      local nr, nc = r + d[2], c + d[1]
      if nr == WARP_ROW then
        if nc < 1 then nc = COLS elseif nc > COLS then nc = 1 end
      end
      if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS and passable(nc, nr, false) then
        local ni = (nr - 1) * COLS + nc
        if BD[ni] < 0 and not BX[ni] then
          BD[ni] = BD[cur] + 1
          BF[ni] = (cur == s0) and (k + order) % 4 + 1 or BF[cur]
          tail = tail + 1
          BQ[tail] = ni
        end
      end
    end
  end
  -- the best target among what was reached
  local best, bs = nil, 1e9
  if want_ghost then
    for _, g in ipairs(S.ghosts) do
      if g.state == "fright" then
        local i = (y_cell(g.y) - 1) * COLS + x_cell(g.x)
        if BD[i] >= 0 and BD[i] < bs then bs, best = BD[i], i end
      end
    end
  end
  if not best then
    for r = 1, ROWS do
      for c = 1, COLS do
        local v = S.dots[r][c]
        if v > 0 then
          local i = (r - 1) * COLS + c
          local d = BD[i]
          if d > 0 then
            d = d - (v == 2 and 6 or 0)
            if d < bs then bs, best = d, i end
          end
        end
      end
    end
  end
  if S.fruit then   -- the bonus fruit is worth a detour
    local i = (y_cell(S.fruit.y) - 1) * COLS + x_cell(S.fruit.x)
    if BD[i] > 0 and BD[i] - 12 < bs then best = i end
  end
  return (best and BF[best] > 0) and BF[best] or nil
end

function bot()
  if S.phase == "story" then
    if S.age > 30 and game.frame % 4 == 0 then input.bot("low") end
    return
  elseif S.phase == "map" then
    if S.t > MAP_MIN - 5 and game.frame % 4 == 0 then input.bot("low") end
    return
  elseif S.phase == "clear" then
    if S.clear_t > 65 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase ~= "play" then return end

  -- Use Turbo Dash when charged for fun speed!
  if S.dash_cool == 0 and game.frame % 25 == 0 then input.bot("low") end

  local want_ghost = S.power_t > 40
  local di = bfs(true, want_ghost)
  if not di then di = bfs(false, want_ghost) end
  if di then
    local d = DIRS[di]
    if d[1] < 0 then input.bot("left") elseif d[1] > 0 then input.bot("right")
    elseif d[2] < 0 then input.bot("up") elseif d[2] > 0 then input.bot("down") end
  end
end

-- ------------------------------------------------------------------ Lifecycle
function init()
  sfx.master(0.42)
  sfx.limit(8000)
  S.best = clamp(save.get("best", 0), 0, 100000)
  S.hi = clamp(save.get("hi", 0), 0, 999999)
  S.stars = clamp(save.get("stars", 0), 0, 100000)
  S.visits = clamp(save.get("visits", 0), 0, 100000) + 1
  S.grand = clamp(save.get("grand", 0), 0, 100000)
  for i = 1, 5 do S.fr[i] = clamp(save.get("fr" .. i, 0), 0, 100000) end
  for i = 1, 4 do S.gh[i] = clamp(save.get("gh" .. i, 0), 0, 100000) end
  -- a save from before the sky: the mazes already cleared are stars already home
  if S.stars < S.best then S.stars = S.best end
  S.look = look_for(S.stars)
  S.hi_txt = "HI " .. S.hi
  words()
  log("chomp hi " .. S.hi)
  log("chomp sky " .. S.stars)
  -- the story: the ghosts toss the stars away and Chompy rolls up; a returning player sees only the last part
  S.phase, S.t, S.age = "story", (S.visits > 1 and S.stars > 0) and STORY_SPLIT or 0, 0
  log("chomp story")
  play_song(songs.story())
  if S.t < 150 then set_level(3, 0) set_level(4, 0) end
end

function quit()
  save_all()
end

local function begin_map()
  S.phase, S.t = "map", 0
  play_song(songs.map())
  set_level(4, clamp(S.stars / NSTARS * 1.2, 0.2, 1.2))
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.dash_t > 0 then S.dash_t = S.dash_t - 1 end
  if S.dash_cool > 0 then S.dash_cool = S.dash_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.whew_t > 0 then S.whew_t = S.whew_t - 1 end
  S.age = S.age + 1

  if S.phase == "story" then
    S.t = S.t + 1
    if S.t == 150 then set_level(3, 1) set_level(4, 1) end   -- Chompy's theme comes in with him
    if S.t > 70 and S.t < 190 and S.t % 16 == 0 then
      particles.burst(W / 2, 330, 3, 1.4, 20, 2.5, C.GOLD, "star")
    end
    if (pressed and S.saw_release and S.age >= STORY_MIN) or S.t >= STORY_END then
      snd.ok()
      setup_stage(1)
    end
  elseif S.phase == "ready" then
    S.ready_t = S.ready_t - 1
    if S.ready_t <= 0 then
      S.phase = "play"
      play_song(songs.song(S.theme, false))
      music.tempo(1)
      music.volume(1)
      update_mix()
    end
  elseif S.phase == "play" then
    if pressed and S.saw_release and S.dash_cool == 0 then
      S.dash_t = 48
      S.dash_cool = 180
      sfx.slide("square", 520, 1040, 0.12, 0.24)
      music.cue{wave = "square", duty = 0.25, note = songs.dot_note(S.theme, music.step() + 1, 4) + 12,
                dur = 0.12, vol = 0.14, release = 0.1}
      particles.burst(S.px, S.py, 14, 2.6, 20, 2.5, C.GOLD, "star")
      particles.text(S.px, S.py - 16, C.GOLD, "TURBO!")
    end

    if S.power_t > 0 then
      S.power_t = S.power_t - 1
      if S.power_t == 0 then
        for _, g in ipairs(S.ghosts) do
          if g.state == "fright" then g.state = "chase" end
        end
        play_song(songs.song(S.theme, false, true))   -- back to the verse, same bar
        music.tempo(1)
      end
    end

    step_player(mx, my)
    if S.phase == "play" then step_ghosts() end
    if S.phase == "play" then update_mix() end

    -- Maze clear: a star goes home
    if S.phase == "play" and S.dots_left <= 0 then
      S.phase, S.clear_t = "clear", 0
      add_score(500)
      S.stars = min(S.stars + 1, 100000)
      S.new_star = S.stars <= NSTARS
      local lk = look_for(S.stars)
      S.new_look = lk > S.look
      S.look = lk
      if S.stage > S.best then S.best = S.stage end
      words()
      S.clear_txt = "MAZE " .. S.stage .. " CLEAR!"
      S.clear_score_txt = "SCORE: " .. S.score
      save_all()
      log("chomp clear " .. S.stage)
      log("chomp star " .. S.stars)
      if S.new_look then log("chomp look " .. lk) end
      play_song(songs.fanfare(S.theme))
      sfx.arp("tri", {72, 76, 79, 84, 88}, 0.06, 0.34)
      particles.burst(W / 2, 220, 32, 3.6, 42, 3.4, C.GOLD, "star")
      react_to("Maze " .. S.stage .. " CLEAR! A star goes home!")
    end
  elseif S.phase == "clear" then
    S.clear_t = S.clear_t + 1
    if S.clear_t % 12 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.6, 2.0), 75, rnd(3, 4.5),
        S.clear_t % 24 == 0 and C.GOLD or C.CYAN, "star", 0.05, 0.99, 0.1)
    end
    if (pressed and S.saw_release and S.clear_t >= 60) or S.clear_t >= 180 then
      snd.ok()
      begin_map()
      S.map_line = S.new_star and "A star flies home to the sky!" or "One more star for the sky!"
    end
  elseif S.phase == "map" then
    S.t = S.t + 1
    if S.t == 60 then   -- the star lands
      music.cue{wave = "sine", note = 84, dur = 0.5, vol = 0.2, release = 0.4, at = "beat"}
      music.cue{wave = "sine", note = 88, dur = 0.5, vol = 0.16, release = 0.4, at = "beat"}
      music.cue{wave = "sine", note = 91, dur = 0.5, vol = 0.16, release = 0.4, at = "beat"}
      sfx.arp("sine", {79, 84, 88, 91, 96}, 0.06, 0.3)
      if S.new_star then
        local k = S.stars
        particles.burst(pics.SX[k], pics.SY[k], 22, 2.6, 34, 3.2, C.GOLD, "star")
        log("chomp lands " .. k)
      end
      if S.new_look then S.map_line = "Chompy has a new look!" end
      if S.stars == NSTARS and S.new_star then
        log("chomp lantern")
        S.map_line = "Every star is home! The sky shines!"
      end
    end
    if S.t > 60 and S.stars >= NSTARS and S.t % 30 == 0 then
      particles.burst(rnd(60, W - 60), rnd(100, 260), 18, 3.2, 34, 3.2,
        S.t % 60 == 0 and C.GOLD or C.CYAN, "star")
    end
    if (pressed and S.saw_release and S.t >= MAP_MIN) or S.t >= MAP_AUTO then
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
  if S.phase == "story" then pics.story(S.t)
  elseif S.phase == "map" then pics.map(S.t)
  else pics.draw() end
  if S.phase == "clear" and S.clear_t < 48 and S.clear_t % 16 == 0 then gfx.flash(alpha(C.WHITE, 70), 4) end
  particles.draw()
  local line
  if S.phase == "story" then line = pics.story_line(S.t)
  elseif S.phase == "map" then line = S.map_line
  else
    line = S.react_left > 0 and S.react or (
      S.power_t > 0 and "BIG STAR! Chomp the blue ghosts!" or
      (S.dash_cool == 0 and "Stick steers! Press any button for TURBO DASH!" or "Gobble every dot and grab the big stars!"))
  end
  if leaving() then line = "Great chomping! See you soon!" end
  ui.band(line)
end
