-- Tower: a kid-friendly ladder-and-barrels rescue (5+). Walk-up band (CONTROLS.md). See DESIGN.md.
-- The stick walks, and up/down climbs a ladder you stand at (4-way, magnet-snap). LOW, TL and TR all do
-- the one verb: jump. A Star Swatter on the way smashes barrels for a few seconds, no button needed.
-- Three towers make one run: a run scores from 0, three hearts per tower, a new floor mends a heart,
-- and losing the hearts restarts the same tower. After tower 3 the run ends and the next player starts at
-- tower 1 on a score of 0. tower.sav keeps "best N" (best run) and "rescues N"; quit() saves too.
--
-- The story: Big Grumble is only sleepy; the friends' giggling kept him up, so he locked them in the towers.
-- Each rescue, the friend sings him a lullaby and he falls asleep smiling; the friends fill a gallery, and
-- every few rescues bring him a gift. The climb is a song: each floor brings a layer in, the top is the climax.
--
-- Rules for the code: game logic counts game.frame and never reads music.step() (it is used for drawing and
-- to pick the pitch of a music.cue). Chance is only the seeded rnd (this cart needs none). Nothing in
-- pictures.lua uses the music clock.

local pics = import("pictures")
local songs = import("songs")

local FLOORS, LADDERS, TH = pics.FLOORS, pics.LADDERS, pics.TH
local NTOWERS = #TH
local GIFTS = pics.GIFTS

local STORY_MIN, STORY_END, STORY_SHORT = 24, 372, 250   -- a returning player sees the story from the cages on
local WIN_MIN, WIN_AUTO = 215, 520

local S = {
  phase = "story", level = 1, tw = 1, fi = 1, best = 0, rescues = 0, score = 0, hurts = 0, hurt_cool = 0,
  px = 68, py = FLOORS[1], vy = 0, floor_i = 1, floor_max = 1, on_ground = true, climbing = false,
  face = 1, walk_t = 0, swat_t = 0,
  barrels = {}, swatter = nil, barrel_cool = 90,
  stars = {}, nstars = 0, got = 0,
  g = {0, 0, 0}, pf = {0, 0, 0}, stars_total = 0, visits = 0, hops = 0, soft = 0,
  t = 0, age = 0, win_t = 0, restart_t = 0, saw_release = false, react = "", react_left = 0, goodbye = false,
  idle_t = 0, whew_t = 0, cheer_t = 0, throw_t = 0, laugh_t = 0, danger_t = 0,
  hop_run = 0, last_hop = -9999, jump_n = 0, last_jump = -9999, climax = false,
  gift_new = 0, perfect_now = false, next_level = 1,
}
pics.bind(S)

-- Stars to catch on each tower: a ground star and a hop star on a floor. {floor, x, y above the floor}
local STAR_MAP = {
  {{1, 150, 20}, {1, 232, 60}, {2, 262, 20}, {2, 120, 60}, {3, 160, 20}, {3, 236, 60}, {4, 220, 20}},
  {{1, 120, 20}, {1, 196, 60}, {2, 236, 20}, {2, 140, 60}, {3, 214, 20}, {3, 150, 60}, {4, 200, 20}},
  {{1, 220, 20}, {1, 140, 60}, {2, 270, 20}, {2, 150, 60}, {3, 128, 20}, {3, 210, 60}, {4, 190, 20}, {4, 250, 60}},
}

local function clamp_save(k, def, hi) return clamp(save.get(k, def), 0, hi) end

local function save_all()
  save.set("best", floor(S.best))
  save.set("rescues", floor(S.rescues))
  for i = 1, 3 do
    save.set("g" .. i, floor(S.g[i]))
    save.set("pf" .. i, floor(S.pf[i]))
  end
  save.set("stars", floor(S.stars_total))
  save.set("hops", floor(S.hops))
  save.set("visits", floor(S.visits))
  save.write()
end

local function react_to(s) S.react, S.react_left = s, 110 end
local function add_score(n)
  S.score = min(S.score + n, 999999)
  if S.score > S.best then S.best = S.score end
end
local function soft_for(r) return (r >= 3 and 1 or 0) + (r >= 12 and 1 or 0) end

-- ------------------------------------------------------------------ the music

local LV = {1, 1, 1, 1, 1, 1}   -- the track levels asked of the song, so music.track is only called on a change
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

-- The layers follow the climb: floor 1 is bass and pad, floor 2 brings the drums, floor 3 the counter and the
-- bells, the top floor is the climax section. A barrel close brings the drums in early; the Star Swatter lifts
-- the lead and the bells; a hurt lets the lead drop away, gently.
local function update_mix()
  local f = S.floor_i
  local lead = (f <= 1 and 0.55) or (f == 2 and 0.8) or (f == 3 and 1) or 1.15
  local counter = (f >= 4 and 1) or (f == 3 and 0.9) or 0
  local drums = (f >= 2 and 1) or (S.danger_t > 0 and 0.7) or 0
  local spark = (f >= 4 and 1) or (f == 3 and 0.6) or 0
  if S.swat_t > 0 then lead = lead + 0.3 spark = max(spark, 1.2) end
  if S.hurt_cool > 0 then lead = 0.2 drums = drums * 0.5 end
  set_level(1, lead) set_level(2, counter) set_level(3, 1) set_level(4, drums) set_level(5, 1) set_level(6, spark)
end

-- A note from the chord under the step it will land on (sound only: nothing reads it back).
local function ladder_note(n, up) return songs.ladder(S.tw, music.step() + 1, n) + (up or 0) end
local function cue_chord(vol, up)
  local root, t3 = songs.chord(S.tw, music.step() + 1)
  root = root + (up or 0)
  music.cue{wave = "square", duty = 0.25, note = root, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = "square", duty = 0.25, note = root + t3, dur = 0.42, vol = vol * 0.8, release = 0.38}
  music.cue{wave = "tri", note = root + 7, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = "sine", note = root + 12, dur = 0.5, vol = vol * 0.9, release = 0.45}
end

-- ------------------------------------------------------------------ story and towers

local function begin_story()
  local full = S.rescues == 0 and S.best == 0
  S.phase, S.t, S.age = "story", full and 0 or STORY_SHORT, 0
  S.px, S.py, S.floor_i, S.barrels, S.swatter = 68, FLOORS[1], 1, {}, nil
  S.swat_t, S.hurt_cool, S.hurts, S.climbing, S.on_ground = 0, 0, 0, false, true
  S.react_left = 0
  S.soft = soft_for(S.rescues)
  log("tower story " .. (full and "full" or "short"))
  play_song(songs.story())
  set_level(1, full and 0.7 or 0.4)
  set_level(2, full and 0 or 1) set_level(3, full and 0 or 1)
  set_level(4, 0) set_level(5, 0)
end

local function setup_tower(lvl)
  S.phase, S.level, S.hurts, S.hurt_cool = "play", lvl, 0, 0
  S.tw = (lvl - 1) % NTOWERS + 1
  S.fi = S.tw
  S.px, S.py, S.vy, S.floor_i, S.on_ground, S.climbing, S.face = 68, FLOORS[1], 0, 1, true, false, 1
  S.floor_max, S.climax = 1, false
  S.swat_t, S.barrels, S.barrel_cool = 0, {}, 170
  S.saw_release = false
  S.swatter = {x = 188, y = FLOORS[2] - 26, gone = false}
  S.stars, S.got = {}, 0
  for i, m in ipairs(STAR_MAP[S.tw]) do S.stars[i] = {x = m[2], y = FLOORS[m[1]] - m[3], got = false} end
  S.nstars = #S.stars
  S.win_t, S.restart_t = 0, 0
  S.idle_t, S.whew_t, S.cheer_t, S.throw_t, S.laugh_t, S.danger_t = 0, 0, 0, 0, 0, 0
  S.hop_run, S.jump_n = 0, 0
  S.gift_new, S.perfect_now = 0, false
  S.soft = soft_for(S.rescues)
  log("tower level " .. lvl)
  play_song(songs.song(S.tw, false))
  react_to(TH[S.tw].name .. "! Climb up and free " .. pics.FRIENDS[S.fi].name .. "!")
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
  S.laugh_t = 50
  S.hop_run = 0
  log("tower hurt " .. S.hurts)
  sfx.slide("tri", 320, 120, 0.25, 0.34)
  gfx.shake(4)
  particles.burst(S.px, S.py - 12, 14, 2.5, 26, 3, 0x8a5cf5, "ring")
  if S.hurts >= 3 then
    S.phase, S.restart_t = "restart", 0
    save_all()
    react_to("Whoa! Let's climb this tower again!")
  else
    react_to("Hop over the barrels!")
  end
end

local function reach_floor(f)
  S.cheer_t = 40
  if f > S.floor_max then
    S.floor_max = f
    log("tower floor " .. f)
    cue_chord(0.16, 0)
    if f == 2 then react_to("Floor 2! The drums join in!")
    elseif f == 3 then react_to(pics.FRIENDS[S.fi].name .. " is cheering! Keep going!")
    elseif f == 4 then react_to("Top floor! Free " .. pics.FRIENDS[S.fi].name .. "!") end
  end
  local top = f >= 4
  if top ~= S.climax then
    S.climax = top
    music.play(songs.song(S.tw, top, true))   -- keep: the same step, the same layers, a new section
  end
end

local function win_tower()
  S.phase, S.win_t = "win", 0
  S.rescues = S.rescues + 1
  S.g[S.fi] = min(S.g[S.fi] + 1, 100000)
  S.soft = soft_for(S.rescues)
  add_score(500)
  S.gift_new = 0
  for k = 1, 3 do if S.rescues == GIFTS[k] then S.gift_new = k end end
  S.perfect_now = S.got >= S.nstars
  if S.perfect_now then
    add_score(300)
    S.pf[S.fi] = 1
    log("tower perfect " .. S.level)
  end
  save_all()
  log("tower rescue " .. S.level)
  if S.gift_new > 0 then log("tower gift " .. S.gift_new) end
  play_song(songs.fanfare(S.tw))
  sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.36)
  for i = 1, 30 do
    particles.spawn(W / 2 + rnd(-110, 110), 160, rnd(-3, 3), rnd(-5, -1), 85, rnd(3, 5),
      i % 3 == 0 and 0xffd84a or i % 3 == 1 and 0xe86b9a or 0x7fe8ff, "heart", 0.1, 0.99, 0.1)
  end
  react_to(S.level >= NTOWERS and "ALL THREE TOWERS! What a hero!" or ("YOU FREED " .. pics.FRIENDS[S.fi].name .. "! Yay!"))
end

local function alive(b) return not b.gone end

function bot()
  if S.phase == "story" then
    if S.age >= STORY_MIN + 6 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if S.phase == "win" then
    if S.win_t > WIN_MIN + 8 and game.frame % 4 == 0 then input.bot("low") end
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
  S.best = clamp_save("best", 0, 999999)
  S.rescues = clamp_save("rescues", 0, 100000)
  for i = 1, 3 do
    S.g[i] = clamp_save("g" .. i, 0, 100000)
    S.pf[i] = clamp_save("pf" .. i, 0, 1)
  end
  S.stars_total = clamp_save("stars", 0, 1000000)
  S.hops = clamp_save("hops", 0, 1000000)
  S.visits = clamp_save("visits", 0, 100000) + 1
  S.soft = soft_for(S.rescues)
  log("tower best " .. S.best)
  S.level, S.tw, S.fi = 1, 1, 1
  begin_story()
end

-- Leaving (1P+2P): keep the best score, the rescues and the gallery.
function quit() save_all() end

local function step_win(pressed)
  S.win_t = S.win_t + 1
  local wt = S.win_t
  if wt == 62 then react_to(pics.FRIENDS[S.fi].name .. " sings Big Grumble a lullaby.") end
  if wt == 100 then play_song(songs.lullaby(S.tw)) end
  if wt >= 100 and wt < 190 and wt % 22 == 0 then
    music.cue{wave = "sine", note = ladder_note(idiv(wt - 100, 22) + 1, 12), dur = 0.3, vol = 0.14, release = 0.3}
  end
  if wt == 150 then react_to("Big Grumble is so sleepy...") end
  if wt == 190 then
    log("tower sleep " .. S.level)
    react_to("Big Grumble is asleep. Sweet dreams!")
    sfx.arp("sine", {84, 88, 91, 96}, 0.12, 0.2)
    for i = 1, 6 do
      particles.spawn(pics.GRUMBLE_X + rnd(-20, 40), FLOORS[4] - 90, rnd(-0.6, 0.6), rnd(-1.6, -0.6), 80, rnd(3, 5), 0xe86b9a, "heart", 0, 0.99, 0.1)
    end
  end
  if wt == 196 and S.gift_new > 0 then
    react_to("Big Grumble got " .. pics.GIFT_NAMES[S.gift_new] .. "!")
    sfx.arp("tri", {72, 79, 84, 91, 96}, 0.07, 0.28)
    particles.burst(pics.GRUMBLE_X, FLOORS[4] - 80, 22, 2.8, 30, 3, 0xffd84a, "star")
  end
  if wt > 100 and wt % 30 == 0 and wt < 480 then
    particles.spawn(rnd(40, W - 40), 100, rnd(-0.5, 0.5), rnd(0.4, 1.2), 90, rnd(3, 4.5),
      wt % 60 == 0 and 0xffd84a or 0xe86b9a, "star", 0.02, 0.99, 0.1)
  end
  if (pressed and S.saw_release and wt >= WIN_MIN) or wt >= WIN_AUTO then
    snd.ok()
    if S.level >= NTOWERS then
      S.score = 0                 -- the run is over: the next player starts fresh at tower 1
      S.level = 1
      begin_story()
    else
      setup_tower(S.level + 1)
    end
  end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.swat_t > 0 then S.swat_t = S.swat_t - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.whew_t > 0 then S.whew_t = S.whew_t - 1 end
  if S.cheer_t > 0 then S.cheer_t = S.cheer_t - 1 end
  if S.throw_t > 0 then S.throw_t = S.throw_t - 1 end
  if S.laugh_t > 0 then S.laugh_t = S.laugh_t - 1 end
  if S.danger_t > 0 then S.danger_t = S.danger_t - 1 end
  S.age = S.age + 1
  if mx == 0 and my == 0 and not held then S.idle_t = S.idle_t + 1 else S.idle_t = 0 end

  if S.phase == "story" then
    S.t = S.t + 1
    local t = S.t
    if t == 95 then set_level(2, 1) set_level(3, 1) sfx.slide("tri", 300, 700, 0.14, 0.2) end
    if t == 172 then gfx.shake(5) sfx.noise(0.2, 0.2, 400) end
    if t == 235 then sfx.noise(0.12, 0.2, 900) sfx.tone("tri", 200, 0.1, 0.2) end
    if t == 262 then set_level(4, 1) set_level(5, 1) sfx.arp("tri", {72, 76, 79}, 0.06, 0.24) end
    local skip = pressed and S.saw_release and S.age >= STORY_MIN
    if skip or t >= STORY_END then
      snd.ok()
      log("tower story done")
      setup_tower(S.level)
    end
  elseif S.phase == "play" then
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
          particles.burst(S.px, S.py - 20, 8, 1.8, 24, 3, 0xe86b9a, "heart")
        end
        reach_floor(S.floor_i)
      elseif S.py >= FLOORS[lad.bot] - 2 and my > 0 then
        S.py, S.floor_i, S.climbing, S.on_ground = FLOORS[lad.bot], lad.bot, false, true
        reach_floor(S.floor_i)
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
          sfx.slide("sine", 360, 740, 0.08, 0.2)
          -- a jump is a note on the beat, rising through a string of jumps
          if game.frame - S.last_jump > 150 then S.jump_n = 0 end
          S.last_jump = game.frame
          music.cue{wave = "sine", note = ladder_note(S.jump_n, 0), dur = 0.2, vol = 0.2, release = 0.16}
          S.jump_n = S.jump_n + 1
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
      log("tower swatter")
      sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.3)
      cue_chord(0.2, 0)
      particles.burst(S.swatter.x, S.swatter.y, 20, 3, 28, 3, 0xffd84a, "star")
      react_to("STAR SWATTER! Smash the barrels!")
    end

    -- little stars: each one the next note of the song's chord ladder
    for i = 1, S.nstars do
      local st = S.stars[i]
      if not st.got and dist(S.px, S.py - 16, st.x, st.y) < 24 then
        st.got = true
        S.got = S.got + 1
        S.stars_total = S.stars_total + 1
        add_score(25)
        log("tower star " .. S.got)
        sfx.tone("sine", 1400, 0.05, 0.1)
        music.cue{wave = "tri", note = ladder_note(S.got - 1, 12), dur = 0.24, vol = 0.22, release = 0.2}
        music.cue{wave = "sine", note = ladder_note(S.got - 1, 24), dur = 0.16, vol = 0.09, release = 0.14}
        particles.burst(st.x, st.y, 8, 2, 22, 2.6, 0xffd84a, "star")
        if S.got == S.nstars then react_to("EVERY STAR! Wow!") end
      end
    end

    -- Spawn rolling barrels from Big Grumble at top-left, after a little wind-up he shows
    S.barrel_cool = S.barrel_cool - 1
    if S.barrel_cool <= 0 then
      S.barrel_cool = max(100, 190 - S.level * 28)
      S.barrels[#S.barrels + 1] = {x = 124, y = FLOORS[4], fl = 4, dir = 1, spd = 1.5 + S.level * 0.25, jumped = false}
      S.throw_t = 16
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
      if b.fl == S.floor_i and abs(b.x - S.px) < 120 then S.danger_t = 60 end
      -- Reward jumping over a barrel!
      if not b.jumped and b.fl == S.floor_i and not S.on_ground and abs(b.x - S.px) < 16 and S.py < b.y - 12 then
        b.jumped = true
        add_score(100)
        if game.frame - S.last_hop > 420 then S.hop_run = 0 end
        S.last_hop = game.frame
        S.hop_run = S.hop_run + 1
        S.hops = S.hops + 1
        S.cheer_t = 36
        log("tower hop " .. S.hop_run)
        sfx.note("sine", 88, 0.1, 0.2)
        music.cue{wave = "square", duty = 0.25, note = ladder_note(S.hop_run + 1, 0), dur = 0.2, vol = 0.18, release = 0.16}
        music.cue{wave = "sine", note = ladder_note(S.hop_run + 1, 12), dur = 0.3, vol = 0.14, release = 0.28}
        particles.text(S.px, S.py - 50, 0xffd84a, S.hop_run >= 3 and ("+100 x" .. S.hop_run) or "+100")
        if S.hop_run == 3 then react_to("Hop streak! The music is dancing!") end
      end
      local d = dist(b.x, b.y - 10, S.px, S.py - 12)
      -- a barrel that rolls close past and misses: whew!
      if not b.whew and d < 34 and d >= (S.swat_t > 0 and 30 or 19) and S.hurt_cool == 0 then
        b.whew = true
        S.whew_t = 40
        log("tower whew")
      end
      -- Hit check (Star Swatter smashes barrels into stars!).
      if d < (S.swat_t > 0 and 30 or 19) then
        if S.swat_t > 0 then
          b.gone = true
          add_score(200)
          log("tower smash")
          sfx.arp("tri", {79, 88}, 0.05, 0.3)
          cue_chord(0.16, 0)
          gfx.shake(3)
          S.cheer_t = 30
          particles.burst(b.x, b.y - 10, 20, 3, 28, 3, 0xffd84a, "star")
          particles.text(b.x, b.y - 24, 0xffd84a, "SMASH!")
        else
          b.gone = true
          hurt_hero()
        end
      end
    end
    sweep(S.barrels, alive)
    update_mix()

    -- Reach the friend at top-left!
    if S.floor_i == 4 and S.px < 146 then win_tower() end
  elseif S.phase == "win" then
    step_win(pressed)
  elseif S.phase == "restart" then
    S.restart_t = S.restart_t + 1
    if S.restart_t >= 65 then setup_tower(S.level) end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function draw()
  if S.phase == "story" then
    pics.story(S.t)
  else
    pics.draw_play()
    if S.phase == "win" then pics.win_panel() end
  end
  particles.draw()
  local line
  if S.phase == "story" then
    line = pics.story_line(S.t)
  else
    line = S.react_left > 0 and S.react or (S.swat_t > 0 and "SMASH the barrels!" or "Climb the ladders and hop the barrels!")
    if S.phase == "win" and S.win_t > 62 then line = S.react end
  end
  if input.down("1p") and input.down("2p") then line = "Your friends will stay!" end
  ui.band(line)
end
