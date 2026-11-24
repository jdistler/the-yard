-- Starship: split-hands space rescue (ALL ages). See DESIGN.md. The cabinet has ONE stick and ONE cluster, so "co-op"
-- means two people sharing the one deck, the split-hands shape from CONTROLS.md: the Pilot holds the stick and flies,
-- the Co-Pilot holds LOW (TL and TR do the same) and fires the Star-Bubble Beam. Alone, a player does both, and the
-- stick alone still finishes every world (the ship scoops stars by touch; a rock only bumps it). The beam pops rocks
-- and reaches stars the ship cannot.
--
-- The story: Moon-Mama's Star Lantern keeps six baby star-creatures warm; the wind blew them across three worlds.
-- Each world holds one lost friend (brought home at touchdown) and one shy friend (who comes out for three star-kitties
-- or a TEAM!). Friends ride along in the crew and fill a gallery that is saved between visits.
-- A voyage is three worlds with one score; after world 3 the next voyage starts at world 1 on 0 points.
-- Zero harsh game over; rocket.sav keeps "best N" (best voyage), "voyages N" and the crew (c1..c6) and counters;
-- quit() saves too.
--
-- The duet: the Pilot's catches are bells and the Co-Pilot's pops are plucks, both on the beat, each picked from the
-- chord under the step, from different chord tones. Chain pilot -> co-pilot -> pilot within about two seconds and it
-- is a TEAM! (a bonus, never required).
--
-- Rules for the code: game logic counts frames and never reads music.step() (it is used for drawing and to pick the
-- pitch of a music.cue). Chance in the rules comes from one small seeded generator of this cart (the same on both
-- runtimes); rnd() only throws particles. Nothing in pictures.lua uses the music clock.

local pics = import("pictures")
local songs = import("songs")

local WORLDS, CR = pics.WORLDS, pics.CR
local NW = #WORLDS

local STORY_MIN, STORY_END, STORY_SHORT = 24, 380, 215

local S = {
  phase = "story", world = 1, best = 0, voyages = 0, score = 0, saved = 0,
  px = 192, py = 384, wobble = 0, dist = 0, goal = 1500, wf = 0,
  stars = {}, rocks = {}, beams = {}, bg_stars = {}, boulder = nil,
  cool = 0, fire_t = 0, saw_release = false, goodbye = false, react = "", react_left = 0,
  seed = 1, star_n = 0, rock_n = 0, ev_i = 1,
  -- the duet
  wp = 0, wc = 0, chain = 0, chain_f = -9999, chain_by = "", team_t = 0, team_banner = 0, team_n = 0, deeds = 0,
  prun = 0, plast = -9999, crun = 0, clast = -9999,
  road_id = 0, road_n = 0, kitties = 0, shy = false, shy_in = 0, duet = false,
  -- moods
  idle_t = 0, near_t = 0, cheer_t = 0, danger_t = 0, look_x = 0, look_y = -1, climax = false,
  -- the crew
  c = {0, 0, 0, 0, 0, 0}, distinct = 0, crew_now = {}, crew_by_world = {{}, {}, {}},
  stars_total = 0, pops_total = 0, teams_total = 0, kitties_total = 0, lands = 0, visits = 0,
  -- story and landing
  t = 0, age = 0, land_t = 0, land_ready = 0, land_end = 0, land_starts = {}, land_kinds = {}, land_new = {},
  tally_line = "", score_line = "", lantern_mood = "worry",
}
pics.bind(S)

local EV = {
  {{0.30, "road"}, {0.68, "road"}},
  {{0.28, "boulder"}, {0.62, "road"}},
  {{0.20, "road"}, {0.45, "boulder"}, {0.74, "road"}},
}
local APPROACH = 0.82

-- ------------------------------------------------------------------ small helpers

local function R()
  S.seed = (S.seed * 16807) % 2147483647
  return S.seed / 2147483647
end
local function Rr(lo, hi) return lo + R() * (hi - lo) end
local function clamp_save(k, def, hi) return clamp(save.get(k, def), 0, hi) end
local function react_to(s) S.react, S.react_left = s, 110 end
local function add_score(n)
  S.score = min(S.score + n, 999999)
  if S.score > S.best then S.best = S.score end
end
local function count_distinct()
  local n = 0
  for i = 1, 6 do if S.c[i] > 0 then n = n + 1 end end
  S.distinct = n
end
local function burst(x, y, n, sp, life, size, col, kind)   -- particles, kept under a cap
  if particles.count() > 150 then n = max(2, idiv(n, 3)) end
  particles.burst(x, y, n, sp, life, size, col, kind)
end

local function save_all()
  save.set("best", floor(S.best))
  save.set("voyages", floor(S.voyages))
  for i = 1, 6 do save.set("c" .. i, floor(S.c[i])) end
  save.set("stars", floor(S.stars_total))
  save.set("pops", floor(S.pops_total))
  save.set("teams", floor(S.teams_total))
  save.set("kitties", floor(S.kitties_total))
  save.set("lands", floor(S.lands))
  save.set("visits", floor(S.visits))
  save.write()
end

-- ------------------------------------------------------------------ the music

local LV = {1, 1, 1, 1, 1, 1}   -- the levels asked of the song, so music.track is only called on a change
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

-- The mix follows the flight: bass and pad alone, the lead after the first deed, drums after three (or when a rock
-- is close), the counter at a third of the way, the sparkle at 60 percent, everything in the approach section. A TEAM!
-- lifts the lead and the sparkle; a bump lets the lead drop away, gently.
local function update_mix()
  local p = S.dist / S.goal
  local lead = S.deeds >= 1 and 0.85 or 0.5
  local drums = (S.deeds >= 3 and 0.9) or (S.danger_t > 0 and 0.6) or 0
  local counter = p >= 0.35 and 0.9 or 0
  local spark = p >= 0.6 and 0.8 or 0
  if S.climax then lead, drums, counter, spark = 1.1, 1, 1, 1 end
  if S.team_t > 0 then lead = lead + 0.3 spark = max(spark, 1.2) end
  if S.wobble > 0 then lead = 0.25 drums = drums * 0.5 end
  set_level(1, lead) set_level(2, counter) set_level(3, 1) set_level(4, drums) set_level(5, 1) set_level(6, spark)
end

-- A note from the chord under the step it will land on (sound only: nothing reads it back).
local function cue_chord(vol, up)
  local root, t3 = songs.chord(S.world, music.step() + 1)
  root = root + (up or 0)
  music.cue{wave = "tri", note = root, dur = 0.5, vol = vol, release = 0.4}
  music.cue{wave = "sine", note = root + t3, dur = 0.5, vol = vol * 0.9, release = 0.4}
  music.cue{wave = "sine", note = root + 7, dur = 0.5, vol = vol, release = 0.4}
  music.cue{wave = "square", duty = 0.125, note = root - 12 + 7, dur = 0.4, vol = vol * 0.5, release = 0.3}
  music.cue{wave = "sine", note = root + 12, dur = 0.55, vol = vol * 0.9, release = 0.5}
end

-- the Pilot's bell and the Co-Pilot's pluck: two instruments of one duet
local function play_pilot(road)
  if S.wf - S.plast > 150 then S.prun = 0 end
  S.plast = S.wf
  local note = road and songs.road(S.world, S.road_n) or songs.pilot(S.world, music.step() + 1, S.prun)
  S.prun = S.prun + 1
  sfx.note("sine", 100, 0.03, 0.06)
  music.cue{wave = "sine", note = note, dur = 0.3, vol = 0.21, release = 0.28}
  music.cue{wave = "tri", note = note + 12, dur = 0.2, vol = 0.07, release = 0.18}
end
local function play_copilot(road)
  if S.wf - S.clast > 150 then S.crun = 0 end
  S.clast = S.wf
  local note = road and songs.road(S.world, S.road_n) - 12 or songs.copilot(S.world, music.step() + 1, S.crun)
  S.crun = S.crun + 1
  sfx.noise(0.03, 0.08, 1400)
  music.cue{wave = "square", duty = 0.125, note = note, dur = 0.22, vol = 0.15, release = 0.18}
  music.cue{wave = "sine", note = note + 12, dur = 0.14, vol = 0.05, release = 0.12}
end

-- ------------------------------------------------------------------ story and worlds

local function begin_story()
  local full = S.best == 0 and S.distinct == 0
  S.phase, S.t, S.age = "story", full and 0 or STORY_SHORT, 0
  S.crew_now = {}
  S.saw_release = false
  S.react_left = 0
  log("rocket story " .. (full and "full" or "short"))
  play_song(songs.story())
  set_level(1, full and 1 or 0.7)
  set_level(2, 1) set_level(3, full and 0 or 0.0) set_level(4, full and 0 or 1) set_level(5, 1)
end

local function setup_world(w)
  S.phase, S.world, S.dist, S.goal = "fly", w, 0, 1500 + (w - 1) * 300
  S.stars, S.rocks, S.beams, S.boulder = {}, {}, {}, nil
  S.wf, S.star_n, S.rock_n, S.ev_i = 0, 0, 0, 1
  S.seed = (game.frame * 7919 + w * 104729 + S.visits * 31 + S.lands * 17) % 2147483646 + 1
  S.land_t = 0
  S.saw_release = false
  S.wobble, S.cool, S.fire_t = 0, 0, 0
  S.wp, S.wc, S.chain, S.chain_f, S.chain_by, S.deeds = 0, 0, 0, -9999, "", 0
  S.team_t, S.team_banner, S.team_n, S.duet = 0, 0, 0, false
  S.prun, S.plast, S.crun, S.clast = 0, -9999, 0, -9999
  S.road_id, S.road_n, S.kitties, S.shy, S.shy_in = 0, 0, 0, false, 0
  S.idle_t, S.near_t, S.cheer_t, S.danger_t, S.climax = 0, 0, 0, 0, false
  if w == 1 then
    S.score, S.saved = 0, 0
    S.crew_now = {}
    S.crew_by_world = {{}, {}, {}}
    S.px, S.py = 192, 384
  end
  log("rocket world " .. w)
  play_song(songs.song(w, false))
  react_to(WORLDS[w].name .. "! Stick flies, button fires. Team up or fly solo!")
end

local function fire_beam()
  log("rocket beam")
  sfx.slide("sine", 620, 1280, 0.1, 0.2)
  S.beams[#S.beams + 1] = {x = S.px, y = S.py - 38, vy = -7.5, life = 60}
  S.fire_t = 10
  burst(S.px, S.py - 38, 5, 1.5, 14, 2, pics.C.CYAN, "star")
end

-- ------------------------------------------------------------------ the duet

local function team_moment()
  S.team_n = S.team_n + 1
  S.teams_total = S.teams_total + 1
  S.chain = 0
  S.team_t, S.team_banner = 420, 90
  S.cheer_t = 80
  add_score(300)
  log("rocket team " .. S.team_n)
  cue_chord(0.2, 0)
  music.cue{wave = "sine", note = songs.pilot(S.world, music.step() + 1, 5), dur = 0.4, vol = 0.18, release = 0.4, at = "beat"}
  sfx.arp("tri", {76, 79, 84, 88, 91, 96}, 0.05, 0.3)
  gfx.shake(3)
  burst(S.px, S.py, 20, 3.4, 30, 3, pics.C.GOLD, "star")
  burst(S.px, S.py, 8, 2, 34, 4, pics.C.ROSE, "ring")
  if not S.shy then
    S.shy, S.shy_in = true, 1
    log("rocket shy")
  end
  react_to("TEAM! Pilot and Co-Pilot in sync! A friend peeks out!")
end

-- Every score is a deed by one instrument. Three alternating deeds, each within ~2 s of the last, make a TEAM!
local function deed(by, pts)
  if by == "pilot" then S.wp = S.wp + pts else S.wc = S.wc + pts end
  S.deeds = S.deeds + 1
  if S.team_t > 0 then
    S.chain = 0
  elseif S.chain > 0 and S.wf - S.chain_f <= 130 then
    if by ~= S.chain_by then S.chain = S.chain + 1 end
  else
    S.chain = 1
  end
  S.chain_f, S.chain_by = S.wf, by
  if S.chain >= 3 then team_moment() end
end

local function catch_star(st, by)
  st.gone = true
  S.saved = S.saved + 1
  S.stars_total = min(S.stars_total + 1, 1000000)
  local pts = st.kitty and 200 or 100
  add_score(pts)
  local road = false
  if st.road and st.road == S.road_id then
    S.road_n = S.road_n + 1
    road = true
  end
  S.cheer_t = 36
  if by == "pilot" then play_pilot(road) else play_copilot(road) end
  if st.kitty then
    S.kitties = S.kitties + 1
    S.kitties_total = min(S.kitties_total + 1, 1000000)
    log("rocket kitty " .. S.kitties)
    music.cue{wave = "sine", note = songs.pilot(S.world, music.step() + 1, 2) + 12, dur = 0.3, vol = 0.1, release = 0.3}
    if S.kitties >= 3 and not S.shy then
      S.shy, S.shy_in = true, 1
      log("rocket shy")
      react_to("Three star-kitties! A shy friend peeks out!")
    end
  end
  burst(st.x, st.y, 14, 2.5, 26, 3, st.kitty and pics.C.ROSE or pics.C.GOLD, "heart")
  particles.text(st.x, st.y - 14, pics.C.GOLD, "+" .. pts)
  deed(by, pts)
  if road and S.road_n == 7 then
    add_score(300)
    log("rocket road")
    sfx.arp("tri", {84, 88, 91, 96}, 0.06, 0.28)
    cue_chord(0.16, 12)
    particles.text(st.x, st.y - 34, pics.C.GOLD, "STAR ROAD! +300")
    react_to("The whole Star Road! Lovely!")
  elseif S.team_t <= 0 and S.react_left <= 70 then
    if by == "pilot" then react_to(st.kitty and "Space-kitty aboard!" or "Caught a shooting star!")
    else react_to(st.kitty and "Star-Beam caught a kitty! Yay!" or "Star-Beam caught a star!") end
  end
end

local function pop_rock(rk)
  rk.gone = true
  add_score(100)
  S.pops_total = min(S.pops_total + 1, 1000000)
  log("rocket pop")
  play_copilot(false)
  S.cheer_t = 30
  burst(rk.x, rk.y, 16, 3, 28, 3, WORLDS[S.world].rock, "star")
  burst(rk.x, rk.y, 5, 1.6, 20, 3, pics.C.GOLD, "dot")
  particles.text(rk.x, rk.y - 12, pics.C.GOLD, "POP!")
  deed("copilot", 100)
  if S.team_t <= 0 and S.react_left <= 70 then react_to("Great shot! Asteroid popped into confetti!") end
end

local function spawn_star(x, y, vx, road)
  S.star_n = S.star_n + 1
  S.stars[#S.stars + 1] = {x = x, y = y, vy = 1.6, vx = vx or 0, kitty = (not road) and S.star_n % 3 == 0,
    road = road, near = false, lx = 0, ly = 0}
end

local function spawn_road()
  S.road_id = S.road_id + 1
  S.road_n = 0
  local cx = Rr(130, 254)
  local amp = S.world == 3 and 96 or 78
  local dir = R() < 0.5 and 1 or -1
  for i = 1, 7 do
    S.star_n = S.star_n + 1
    S.stars[#S.stars + 1] = {x = clamp(cx + sin((i - 1) * 0.95) * amp * dir, 44, W - 44), y = 58 - (i - 1) * 34,
      vy = 1.6, vx = 0, kitty = false, road = S.road_id, near = false, lx = 0, ly = 0}
  end
  log("rocket road start")
  react_to("A Star Road! Catch them all for a tune!")
end

local function spawn_boulder()
  local need = S.world == 2 and 3 or 4
  S.boulder = {x = Rr(110, 274), y = 40, r = S.world == 2 and 34 or 36, vy = 0.9, vx = 0, need = need, hp = need,
    awake = 0, hit_t = 0, gone = false}
  log("rocket boulder")
  react_to("A sleepy boulder! Co-Pilot, wake it gently!")
end

-- the star shower a boulder drops when it pops
local function boulder_shower(b)
  for i = 1, 7 do
    S.star_n = S.star_n + 1
    S.stars[#S.stars + 1] = {x = b.x + (i - 4) * 12, y = b.y, vy = 1.0 + (i % 3) * 0.2, vx = (i - 4) * 0.55,
      kitty = false, road = nil, near = false, lx = 0, ly = 0}
  end
end

-- ------------------------------------------------------------------ landing

local function touchdown()
  S.phase, S.land_t = "land", 0
  add_score(400)
  S.lands = S.lands + 1
  if S.world == NW then S.voyages = S.voyages + 1 end
  S.duet = false
  local hi, lo = max(S.wp, S.wc), min(S.wp, S.wc)
  if lo >= 200 and lo * 2 >= hi then
    S.duet = true
    add_score(300)
    log("rocket duet")
  end
  S.tally_line = "PILOT " .. S.wp .. "   CO-PILOT " .. S.wc .. (S.team_n > 0 and ("   TEAM x" .. S.team_n) or "")
    .. (S.duet and "   DUET!" or "")
  S.score_line = "SCORE: " .. S.score .. "   SAVED: " .. S.saved
  local w = WORLDS[S.world]
  S.land_kinds = {w.lost}
  S.land_starts = {40}
  S.land_new = {false, false}
  if S.shy then S.land_kinds[2], S.land_starts[2] = w.shy, 140 end
  local last = S.land_starts[#S.land_starts]
  S.land_ready = last + 90 + (S.world == NW and 50 or 0)
  S.land_end = S.land_ready + 280
  S.lantern_mood = "worry"
  save_all()
  log("rocket land " .. S.world)
  play_song(songs.fanfare(S.world))
  sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
  for i = 1, 30 do
    particles.spawn(W / 2 + rnd(-110, 110), 220, rnd(-3, 3), rnd(-4.5, -1), 85, rnd(3, 5),
      i % 3 == 0 and pics.C.GOLD or i % 3 == 1 and pics.C.ROSE or pics.C.CYAN, "star", 0.08, 0.99, 0.1)
  end
  react_to("TOUCHDOWN on " .. w.name .. "!" .. (S.duet and " A perfect duet!" or " Team victory!"))
end

local function step_land(pressed)
  local t = S.land_t
  if t == 200 then play_song(songs.home(S.world, S.world == NW)) end
  for j = 1, 2 do
    local t0 = S.land_starts[j]
    if t0 then
      local k = S.land_kinds[j]
      if t == t0 then
        S.c[k] = min(S.c[k] + 1, 100000)
        S.land_new[j] = S.c[k] == 1
        log("rocket crew " .. CR[k].name)
        react_to(CR[k].name .. " the " .. CR[k].what .. (S.land_new[j] and " is a NEW friend!" or " is home!"))
        sfx.slide("sine", 500, 1200, 0.2, 0.2)
        save_all()
      elseif t == t0 + 24 then
        for i = 1, 4 do
          music.cue{wave = "sine", note = songs.sig(k, i) , dur = 0.3, vol = 0.18, release = 0.3}
        end
        sfx.arp("sine", {84, 88, 91, 96}, 0.08, 0.2)
        particles.burst(W / 2 - 100, 330, 12, 2.4, 30, 3, CR[k].col, "heart")
      elseif t == t0 + 82 then
        S.crew_now[#S.crew_now + 1] = k
        S.crew_by_world[S.world][#S.crew_by_world[S.world] + 1] = k
        count_distinct()
        S.cheer_t = 60
        particles.burst(S.px, S.py, 14, 2.6, 30, 3, CR[k].col, "star")
        if S.world == NW and j == #S.land_kinds then
          S.lantern_mood = "happy"
          log("rocket lantern")
        end
      end
    end
  end
  if S.world == NW and t > 0 and t % 36 == 0 and t < S.land_ready then
    particles.spawn(rnd(60, W - 60), 70, rnd(-1, 1), rnd(0.5, 1.6), 80, rnd(3, 5),
      t % 72 == 0 and pics.C.GOLD or pics.C.ROSE, "star", 0.02, 0.99, 0.1)
  end
  if (pressed and S.saw_release and t >= S.land_ready) or t >= S.land_end then
    snd.ok()
    if S.world == NW then
      begin_story()
    else
      setup_world(S.world + 1)
    end
  end
end

-- ------------------------------------------------------------------ the loop

local function alive(o) return not o.gone end

function bot()
  if S.phase == "story" then
    if S.age >= STORY_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase == "land" then
    if S.land_t > S.land_ready + 6 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  local tx = 192
  for _, st in ipairs(S.stars) do
    if st.y > 40 and st.y < S.py then tx = st.x break end
  end
  if tx < S.px - 10 then input.bot("left") elseif tx > S.px + 10 then input.bot("right") end
  if game.frame % 16 == 0 then input.bot("low") end
end

-- Leaving (1P+2P): keep the best voyage score and the crew.
function quit() save_all() end

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.best = clamp_save("best", 0, 999999)
  S.voyages = clamp_save("voyages", 0, 100000)
  for i = 1, 6 do S.c[i] = clamp_save("c" .. i, 0, 100000) end
  S.stars_total = clamp_save("stars", 0, 1000000)
  S.pops_total = clamp_save("pops", 0, 1000000)
  S.teams_total = clamp_save("teams", 0, 1000000)
  S.kitties_total = clamp_save("kitties", 0, 1000000)
  S.lands = clamp_save("lands", 0, 1000000)
  S.visits = clamp_save("visits", 0, 100000) + 1
  count_distinct()
  for i = 1, 36 do
    local h = sin(i * 12.9898) * 43758.5453
    h = h - floor(h)
    local h2 = sin(i * 78.233) * 43758.5453
    h2 = h2 - floor(h2)
    S.bg_stars[i] = {8 + h * (W - 16), 10 + h2 * (H - 50), 0.8 + ((i * 7) % 16) / 10}
  end
  log("rocket best " .. S.best)
  begin_story()
end

local function step_fly(pressed, held, mx, my)
  S.wf = S.wf + 1
  S.px = clamp(S.px + mx * 3.0, 32, W - 32)
  S.py = clamp(S.py + my * 2.4, 240, 434)
  S.dist = S.dist + 2.2
  if S.near_t > 0 then S.near_t = S.near_t - 1 end
  if S.danger_t > 0 then S.danger_t = S.danger_t - 1 end
  if S.team_t > 0 then S.team_t = S.team_t - 1 end
  if S.team_banner > 0 then S.team_banner = S.team_banner - 1 end
  if S.fire_t > 0 then S.fire_t = S.fire_t - 1 end
  if S.shy_in > 0 and S.shy_in < 60 then S.shy_in = S.shy_in + 1 end
  if S.chain > 0 and S.wf - S.chain_f > 130 then S.chain = 0 end
  if mx == 0 and my == 0 and not held then
    S.idle_t = S.idle_t + 1
    if S.idle_t == 600 then react_to("Zzz... the stick flies the ship!") end
  else
    S.idle_t = 0
  end

  -- Spawn floating lost stars (a kitty every third) and goofy asteroids. The first star waits right above the ship,
  -- and a fresh voyage's first seconds have no rocks.
  if S.world == 1 and S.star_n == 0 and S.wf == 30 then spawn_star(S.px, 58, 0, nil) end
  if S.wf % 48 == 0 then spawn_star(Rr(40, W - 40), 58, 0, nil) end
  if S.wf % 70 == 0 and (S.world > 1 or S.wf >= 150) then
    S.rock_n = S.rock_n + 1
    S.rocks[#S.rocks + 1] = {x = Rr(44, W - 44), y = 58, vy = 1.85, vx = 0, r = 15 + floor(R() * 4), spin = R() * 6.28,
      hit = 0, scared = false, bumped = false, whew = false}
  end
  local ev = EV[S.world][S.ev_i]
  if ev and S.dist / S.goal >= ev[1] then
    S.ev_i = S.ev_i + 1
    if ev[2] == "road" then spawn_road() else spawn_boulder() end
  end

  if S.saw_release and ((pressed and S.cool <= 8) or (held and S.cool == 0)) then
    fire_beam()
    S.cool = 18
  end

  -- the beams (the Co-Pilot)
  for _, b in ipairs(S.beams) do
    b.y, b.life = b.y + b.vy, b.life - 1
    for _, rk in ipairs(S.rocks) do
      if not rk.gone and not rk.bumped and dist(b.x, b.y, rk.x, rk.y) < rk.r + 14 then
        b.gone = true
        pop_rock(rk)
        break
      end
    end
    local bd = S.boulder
    if not b.gone and bd and not bd.gone and dist(b.x, b.y, bd.x, bd.y) < bd.r + 8 then
      b.gone = true
      bd.hp, bd.hit_t, bd.awake = bd.hp - 1, 24, 90
      add_score(50)
      S.cheer_t = 20
      if bd.hp <= 0 then
        bd.gone = true
        add_score(300)
        log("rocket boulder pop")
        boulder_shower(bd)
        play_copilot(false)
        cue_chord(0.15, 0)
        gfx.shake(3)
        burst(bd.x, bd.y, 24, 3.4, 32, 3.5, WORLDS[S.world].rock2, "star")
        particles.text(bd.x, bd.y - 20, pics.C.GOLD, "WOW! +300")
        deed("copilot", 300)
        react_to("The boulder popped into stars! Pilot, scoop them up!")
      else
        play_copilot(false)
        sfx.slide("sine", 220, 160, 0.14, 0.18)
        burst(bd.x, bd.y, 8, 2, 20, 3, WORLDS[S.world].rock2, "dot")
        react_to("Ooh, it is waking up!")
      end
    end
    if not b.gone then
      for _, st in ipairs(S.stars) do
        if not st.gone and dist(b.x, b.y, st.x, st.y) < 26 then
          b.gone = true
          catch_star(st, "copilot")
          break
        end
      end
    end
    if b.life <= 0 or b.y < 0 then b.gone = true end
  end
  sweep(S.beams, alive)

  -- stars (the Pilot scoops by touch)
  local reach = S.team_t > 0 and 40 or 28
  local near_d, nx, ny = 9999, 0, 0
  for _, st in ipairs(S.stars) do
    st.y = st.y + st.vy
    st.x = st.x + st.vx
    st.vx = st.vx * 0.985
    if not st.gone then
      local d = dist(st.x, st.y, S.px, S.py)
      st.near = d < 90
      st.lx = clamp((S.px - st.x) / 50, -1, 1) * 1.2
      st.ly = clamp((S.py - st.y) / 60, -1, 1)
      if st.y < S.py and d < near_d then near_d, nx, ny = d, st.x, st.y end
      if d < reach then
        catch_star(st, "pilot")
      elseif st.y > H - 32 then st.gone = true end
    end
  end
  sweep(S.stars, alive)
  if near_d < 9999 then
    S.look_x = clamp((nx - S.px) / 40, -1, 1) * 1.4
    S.look_y = clamp((ny - S.py) / 120, -1, 0)
  else
    S.look_x, S.look_y = 0, -0.6
  end

  -- the boulder: a sleepy giant that drifts down and bumps, never hurts
  local bd = S.boulder
  if bd then
    if bd.hit_t > 0 then bd.hit_t = bd.hit_t - 1 end
    if bd.awake > 0 then bd.awake = bd.awake - 1 end
    local dd = dist(bd.x, bd.y, S.px, S.py)
    if dd < 150 then bd.awake = max(bd.awake, 30) end
    bd.y = bd.y + bd.vy
    bd.x = clamp(bd.x + bd.vx, 40, W - 40)
    bd.vx = bd.vx * 0.94
    if not bd.gone and dd < bd.r + 18 then
      bd.vx = (bd.x >= S.px and 2.4 or -2.4)
      if S.wobble == 0 then
        S.wobble = 26
        sfx.slide("sine", 300, 180, 0.16, 0.2)
        react_to("Boing! The boulder is just sleepy. Co-Pilot, pop it!")
      end
    end
    if bd.gone or bd.y > H - 20 then
      if not bd.gone then react_to("The sleepy boulder rolled on by.") end
      S.boulder = nil
    end
  end

  -- the rocks
  for _, rk in ipairs(S.rocks) do
    rk.y = rk.y + rk.vy
    rk.x = rk.x + rk.vx
    rk.spin = rk.spin + 0.04
    if rk.hit > 0 then rk.hit = rk.hit - 1 end
    if not rk.gone then
      local d = dist(rk.x, rk.y, S.px, S.py)
      if d < 120 then S.danger_t = 40 end
      if not rk.bumped then
        local sc = false
        for _, b in ipairs(S.beams) do
          if not b.gone and abs(b.x - rk.x) < rk.r + 18 and b.y > rk.y and b.y - rk.y < 150 then sc = true break end
        end
        rk.scared = sc
        if d < rk.r + 16 then
          rk.bumped, rk.hit = true, 40
          rk.vx = rk.x >= S.px and 3 or -3
          S.wobble = 26
          sfx.slide("sine", 340, 200, 0.16, 0.2)
          burst(rk.x, rk.y, 10, 2.2, 22, 2.5, WORLDS[S.world].rock, "dot")
          react_to("Boing! Co-Pilot, blast those rocks!")
        elseif d < rk.r + 38 and not rk.whew and S.wobble == 0 then
          rk.whew = true
          S.near_t = 40
          log("rocket whew")
        end
      end
      if rk.y > H - 32 or rk.x < -30 or rk.x > W + 30 then rk.gone = true end
    end
  end
  sweep(S.rocks, alive)
  if S.wobble > 0 then S.wobble = S.wobble - 1 end

  -- the approach section: the song turns, all its layers open
  if not S.climax and S.dist / S.goal >= APPROACH then
    S.climax = true
    music.play(songs.song(S.world, true, true))
    log("rocket approach")
    react_to("Almost there! The song is swelling!")
  end
  update_mix()

  if S.dist >= S.goal then touchdown() end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.cool > 0 then S.cool = S.cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.cheer_t > 0 then S.cheer_t = S.cheer_t - 1 end
  S.age = S.age + 1

  for _, bs in ipairs(S.bg_stars) do
    bs[2] = bs[2] + bs[3] * (S.phase == "fly" and 1.2 or 0.2)
    if bs[2] > H - 32 then bs[2], bs[1] = 0, 8 + (bs[1] * 7 + 13) % (W - 16) end
  end

  if S.phase == "story" then
    S.t = S.t + 1
    local t = S.t
    if t == 105 then set_level(3, 1) sfx.slide("tri", 300, 700, 0.14, 0.2) end
    if t == 122 then gfx.shake(5) sfx.noise(0.25, 0.2, 500) end
    if t == 205 then set_level(3, 0.5) end
    if t == 232 then set_level(4, 1) set_level(1, 0.8) sfx.arp("tri", {72, 76, 79}, 0.06, 0.24) end
    if t == 262 then sfx.arp("tri", {84, 88, 91, 96}, 0.05, 0.22) end
    if (pressed and S.saw_release and S.age >= STORY_MIN) or t >= STORY_END then
      snd.ok()
      setup_world(1)
    end
  elseif S.phase == "fly" then
    step_fly(pressed, held, mx, my)
  elseif S.phase == "land" then
    S.land_t = S.land_t + 1
    S.px = approach(S.px, W / 2, 0.08)
    S.py = approach(S.py, 326, 0.08)
    if S.wobble > 0 then S.wobble = 0 end
    step_land(pressed)
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  if S.phase == "story" then
    pics.story(S.t)
  elseif S.phase == "fly" then
    pics.fly()
  else
    pics.land()
  end
  particles.draw()
  if S.phase ~= "story" then
    pics.hud()
    pics.banner()
  end
  local line
  if S.phase == "story" then
    line = pics.story_line(S.t)
  else
    line = S.react_left > 0 and S.react or "Stick flies the ship! Button fires Star-Beam!"
  end
  if input.down("1p") and input.down("2p") then line = "Your best score and crew will stay!" end
  ui.band(line)
end
