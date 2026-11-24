-- Star Kart: a kid-friendly kart racer with a cup. A comet dropped the golden Star Cup and four rivals of our
-- own (Ember the fox, Bibi the bee, Moss the frog, Pebble the penguin) want it too. Race three tracks, a map
-- between them, a podium at the end, trophies and kart paint that keep across visits. See DESIGN.md.
-- Walk-up band (CONTROLS.md). The stick steers left/right; LOW/TL/TR uses your item. Nothing else.
--
-- Rules for the code: game logic counts game.frame and never reads music.step() (that is for drawing and for the
-- pitch of a music.cue); chance is only the seeded rnd; nothing here draws.
-- kart.sav keeps "best N" (high score) and "cups N" (cups won), and, new, the shelf (see DESIGN.md).

local pics = import("pictures")
local songs = import("songs")
local C = pics.C
local TRACKS, RIVALS, PAINTS = pics.TRACKS, pics.RIVALS, pics.PAINTS
local NRIV, NTRACK = #RIVALS, #TRACKS
local ST = pics.STORY

local ITEMS = {"comet", "seeker", "bubble", "wobble"}
local ITEM_NAMES = {comet = "Comet Dash!", seeker = "Seeker Spark!", bubble = "Bubble Shield!", wobble = "Wobble Wave!"}
local PTS = {500, 350, 250, 150, 150}
local ORD = {"1st", "2nd", "3rd", "4th", "5th"}
local FINAL_AT = 0.72
local GRID_END = 84

local S = {
  phase = "story", pt = 0, t = 0, saw_release = false, goodbye = false,
  track = 1, next = 1, score = 0, cup_pts = 0, best = 0, cups = 0,
  visits = 1, races = 0, wins = 0, gold = 0, silver = 0, bronze = 0, paint = 1,
  med = {0, 0, 0}, cplace = {0, 0, 0}, beat = {0, 0, 0, 0}, rcup = {0, 0, 0, 0}, rpts = {0, 0, 0, 0},
  order = {0, 1, 2, 3, 4}, rord = {0, 1, 2, 3, 4}, rank = 1, cup_done = false,
  px = 0, py = 384, dist = 0, spd = 0, lean = 0,
  item = nil, item_spin = 0, star_t = 0, boost_t = 0, shield = false, zap_t = 0, spin_t = 0,
  rivals = {}, boxes = {}, pads = {}, shells = {},
  place = 1, mplace = 1, mplace_t = 0, final = false, final_t = 0, go_t = 0,
  run = 0, run_t = 0, pmood = "", pmood_t = 0,
  bub_i = 0, bub_mood = "", bub_word = "", bub_t = 0, bub_cool = 0,
  react = "", react_left = 0, new_paint = 0, new_t = 0, fresh = 0, idle_t = 0,
  mx_prev = 0, pass_n = 0, story_from = 0,
}
pics.S = S

local function react_to(s) S.react, S.react_left = s, 110 end

-- ---------------------------------------------------------------- the shelf (kart.sav)

local function paint_open(k)
  if k == 1 then return true end
  if k == 2 then return S.races >= 1 end
  if k == 3 then return S.races >= 3 end
  if k == 4 then return S.races >= 6 end
  if k == 5 then return S.cups >= 1 end
  if k == 6 then return S.gold >= 1 end
  return S.wins >= 10
end
pics.open = paint_open

local function save_all()
  save.set("best", S.best)
  save.set("cups", S.cups)
  save.set("visits", S.visits)
  save.set("races", S.races)
  save.set("wins", S.wins)
  save.set("gold", S.gold)
  save.set("silver", S.silver)
  save.set("bronze", S.bronze)
  save.set("paint", S.paint)
  for i = 1, NTRACK do save.set("m" .. i, S.med[i]) end
  for i = 1, NRIV do save.set("b" .. i, S.beat[i]) end
  save.write()
end

local function check_unlocks(before)
  for k = 2, #PAINTS do
    if paint_open(k) and not before[k] then
      S.new_paint, S.new_t = k, 0
      log("kart paint " .. k)
      return true
    end
  end
  return false
end

local function snapshot_open()
  local t = {}
  for k = 1, #PAINTS do t[k] = paint_open(k) end
  return t
end

-- ---------------------------------------------------------------- the music

local LV = {1, 1, 1, 1, 1, 1}
local function play_song(song)
  music.play(song)
  if not song.keep then
    for i = 1, 6 do LV[i] = 1 end
    music.tempo(1)
  end
end
local function lvl(i, v)
  if LV[i] ~= v then LV[i] = v music.track(i, v) end
end
local function cue(note, wave, vol, at, dur)
  music.cue{wave = wave or "square", duty = 0.25, note = note, dur = dur or 0.18, vol = vol or 0.2,
    release = 0.12, at = at or "step"}
end
local function chord_wi() return S.phase == "race" and S.track or 0 end
local function chord_now() return songs.chord(chord_wi(), music.step() + 1) end   -- sound only
local function run_note(n) return songs.ladder(chord_wi(), music.step() + 1, n) end   -- sound only
local function bump_run()
  if S.run_t > 0 then S.run = S.run + 1 else S.run = 1 end
  S.run_t = 170
  return S.run
end
local function stinger(vol, at)   -- the chord under the song, as a bell of three
  local root, t3 = chord_now()
  cue(root + 12, "square", vol, at, 0.3)
  cue(root + 12 + t3, "tri", vol * 0.8, at, 0.3)
  cue(root + 19, "sine", vol * 0.9, at, 0.35)
end

-- The layers follow where you are: leading brings the lead and the shimmer, chasing brings the drums and the
-- stabs, a boost brings everything. Calls music.track only when a level changes.
local function race_levels()
  local p, boost = S.mplace, (S.star_t > 0 or S.boost_t > 0)
  local lead = p == 1 and 1.15 or p == 2 and 1.0 or p == 3 and 0.85 or p == 4 and 0.65 or 0.5
  local stab = (p >= 4) and 1 or (p == 3 and 0.7 or 0)
  local drum = p <= 2 and 0.8 or 1
  local shim = p == 1 and 1 or (p == 2 and 0.7 or 0)
  if boost then lead, stab, drum, shim = max(lead, 1.15), 1, 1.3, 1.2 end
  if S.final then stab, drum = max(stab, 0.8), max(drum, 1) end
  lvl(1, lead) lvl(2, stab) lvl(3, 1) lvl(4, drum) lvl(5, shim) lvl(6, 0.9)
end

-- ---------------------------------------------------------------- the rivals' faces

local function mood(r, m, n)
  r.mood, r.mood_t = m, n
end

local VOICE = {
  function() sfx.slide("tri", 640, 980, 0.12, 0.18) end,                       -- Ember: a sly rising "heh"
  function() sfx.arp("sine", {88, 91, 95}, 0.05, 0.18) end,                    -- Bibi: a buzzy trill
  function() sfx.slide("square", 210, 150, 0.16, 0.14) sfx.slide("square", 230, 170, 0.1, 0.1) end,  -- Moss: ribbit
  function() sfx.slide("saw", 330, 250, 0.16, 0.1) end,                        -- Pebble: a gruff "hmph"
}

local function say(i, m, word)
  if S.bub_cool > 0 and m ~= "cheer" then return end
  S.bub_i, S.bub_mood, S.bub_word, S.bub_t, S.bub_cool = i, m, word, 110, 40
  VOICE[i]()
end

-- ---------------------------------------------------------------- races

local function world_to_screen(wx, wd) return pics.project(wx, wd) end

local function setup_race(tr)
  S.track, S.dist, S.px, S.spd, S.lean = tr, 0, 0, 0, 0
  S.item, S.item_spin, S.star_t, S.boost_t, S.shield, S.zap_t, S.spin_t = nil, 0, 0, 0, false, 0, 0
  S.rivals, S.boxes, S.pads, S.shells = {}, {}, {}, {}
  S.place, S.mplace, S.mplace_t, S.final, S.final_t, S.go_t = 5, 5, 0, false, 0, 0
  S.run, S.run_t, S.pmood, S.pmood_t, S.bub_t, S.bub_cool, S.pass_n = 0, 0, "", 0, 0, 0, 0
  local T = TRACKS[tr]
  local assist = (S.races < 3) and 0.97 or 1
  for i, d in ipairs(RIVALS) do
    S.rivals[i] = {
      def = d, name = d.name, x = -0.65 + (i - 1) * 0.42, d = 60 + i * 55,
      spd = d.spd * assist + (tr - 1) * 0.22, spin = 0, phase = d.phase,
      ahead = true, cool = 0, mood = "", mood_t = 0, look = 0, lookn = 0, sp = 0, cd = 260 + i * 70,
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
  S.phase, S.pt, S.saw_release = "grid", 0, false
  log("kart race " .. tr)
  play_song(songs.song(tr, false))
  lvl(1, 0) lvl(2, 0) lvl(3, 0.7) lvl(4, 0) lvl(5, 0.6) lvl(6, 1)
  react_to(T.name .. "! Get ready!")
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
  S.pmood, S.pmood_t = "happy", 70
  if it == "comet" then
    S.star_t = 220
    S.score = S.score + 150
    sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.32)
    cue(run_note(bump_run()) + 12, "square", 0.22, "beat", 0.4)
    particles.burst(W / 2 + S.px * 145, S.py, 22, 3.2, 30, 3, C.GOLD, "star")
    react_to("COMET DASH! Zoom past everyone!")
  elseif it == "seeker" then
    -- Auto-aim at the nearest rival ahead!
    local tgt, bd = nil, 1e9
    for _, r in ipairs(S.rivals) do
      if r.d > S.dist and r.d - S.dist < bd then tgt, bd = r, r.d - S.dist end
    end
    S.shells[#S.shells + 1] = {x = S.px, d = S.dist + 20, tgt = tgt, life = 130}
    sfx.slide("square", 600, 1200, 0.14, 0.22)
    cue(run_note(bump_run()), "tri", 0.2, "beat")
    react_to("Seeker Spark! Watch out!")
  elseif it == "bubble" then
    S.shield = true
    S.score = S.score + 100
    sfx.arp("sine", {76, 84}, 0.07, 0.26)
    cue(run_note(bump_run()), "sine", 0.22, "beat", 0.3)
    particles.burst(W / 2 + S.px * 145, S.py, 16, 2.5, 24, 3, C.CYAN, "dot")
    react_to("Bubble Shield on!")
  else
    S.zap_t = 180
    S.score = S.score + 150
    sfx.noise(0.18, 0.25, 3400)
    sfx.slide("square", 1200, 260, 0.22, 0.22)
    stinger(0.2, "beat")
    gfx.shake(4)
    for i, r in ipairs(S.rivals) do
      r.spin = 50
      mood(r, "wow", 70)
    end
    say(1 + (S.t % NRIV), "wow", "Wheee!")
    react_to("WOBBLE WAVE! Everyone is wobbly!")
  end
end

-- who is ahead of whom: S.rord holds ids (0 you, 1..4 rivals) from first to last
local function race_order()
  local ids, prog = S.rord, S.rprog
  if not prog then prog = {0, 0, 0, 0, 0} S.rprog = prog end
  ids[1], prog[1] = 0, S.dist
  for i = 1, NRIV do ids[i + 1], prog[i + 1] = i, S.rivals[i].d end
  for i = 2, NRIV + 1 do   -- insertion sort, longest first; you win ties
    local id, pr = ids[i], prog[i]
    local j = i - 1
    while j >= 1 and prog[j] < pr do ids[j + 1], prog[j + 1] = ids[j], prog[j] j = j - 1 end
    ids[j + 1], prog[j + 1] = id, pr
  end
  for i = 1, NRIV + 1 do if ids[i] == 0 then return i end end
  return NRIV + 1
end

-- The cup table: the five racers by cup points, you first on ties
local function standings()
  local ids, pts = S.order, S.rprog or {0, 0, 0, 0, 0}
  S.rprog = pts
  ids[1], pts[1] = 0, S.cup_pts
  for i = 1, NRIV do ids[i + 1], pts[i + 1] = i, S.rcup[i] end
  for i = 2, NRIV + 1 do
    local id, pr = ids[i], pts[i]
    local j = i - 1
    while j >= 1 and pts[j] < pr do ids[j + 1], pts[j + 1] = ids[j], pts[j] j = j - 1 end
    ids[j + 1], pts[j + 1] = id, pr
  end
  for i = 1, NRIV + 1 do if ids[i] == 0 then return i end end
  return NRIV + 1
end

local function finish_race()
  local before = snapshot_open()
  local p = race_order()
  S.place = p
  local pts = PTS[p]
  S.score = S.score + pts
  S.cup_pts = S.cup_pts + pts
  if S.score > S.best then S.best = S.score end
  S.races = S.races + 1
  S.cplace[S.track] = p
  if p == 1 then S.wins = S.wins + 1 end
  if S.med[S.track] == 0 or p < S.med[S.track] then S.med[S.track] = p end
  for rk = 1, NRIV + 1 do
    local id = S.rord[rk]
    if id > 0 then
      S.rpts[id] = PTS[rk]
      S.rcup[id] = S.rcup[id] + PTS[rk]
      local r = S.rivals[id]
      if rk > p then
        S.beat[id] = min(S.beat[id] + 1, 100000)
        local m = r.def.lose
        mood(r, m, 200)
      else
        mood(r, rk == 1 and "cheer" or "taunt", 200)
      end
    end
  end
  S.phase, S.pt, S.saw_release = "finish", 0, false
  S.pmood, S.pmood_t = p <= 3 and "happy" or "ok", 200
  log("kart finish " .. S.track .. " " .. p)
  check_unlocks(before)
  save.set("best", S.best)
  save_all()
  play_song(songs.fanfare(S.track, p))
  sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.3)
  local rr = S.rord[1]
  react_to(p == 1 and "FIRST! You win the race!" or
    ("You finished " .. ORD[p] .. "! " .. (rr > 0 and (S.rivals[rr].name .. " won.") or "")))
  for i = 1, 24 do
    particles.spawn(W / 2 + rnd(-120, 120), 200, rnd(-3, 3), rnd(-5, -1), 80, rnd(3, 5),
      i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.CYAN, "star", 0.12, 0.99, 0.1)
  end
end

local function start_podium()
  local before = snapshot_open()
  local rank = standings()
  S.rank, S.phase, S.pt, S.saw_release = rank, "podium", 0, false
  if rank <= 3 then
    S.cups = S.cups + 1
    if rank == 1 then S.gold = S.gold + 1 elseif rank == 2 then S.silver = S.silver + 1 else S.bronze = S.bronze + 1 end
    S.fresh = rank
  else
    S.fresh = 0
  end
  log("kart podium " .. rank)
  log("kart best " .. S.best)
  check_unlocks(before)
  save_all()
  play_song(songs.podium())
  lvl(1, 0) lvl(2, 0) lvl(3, 0) lvl(4, 0) lvl(5, 0) lvl(6, 1)
  react_to(rank == 1 and "You won the Star Cup!" or rank <= 3 and ("You are " .. ORD[rank] .. " in the cup!") or "Good racing! Try again?")
end

local function enter_garage()
  S.phase, S.pt, S.saw_release = "garage", 0, false
  S.cup_pts, S.score, S.rcup, S.cplace = 0, 0, {0, 0, 0, 0}, {0, 0, 0}
  S.next = 1
  particles.clear()
  play_song(songs.story())
  log("kart garage")
end

local function enter_map()
  S.phase, S.pt, S.saw_release = "map", 0, false
  play_song(songs.map())
  lvl(5, 0.35 + 0.25 * (S.next - 1))
  standings()
  react_to(S.next == 1 and "Three races to the Star Cup!" or ("Next: " .. TRACKS[S.next].name))
end

function bot()
  local ph = S.phase
  if ph == "story" or ph == "garage" or ph == "map" or ph == "finish" or ph == "podium" then
    if S.pt > 30 and game.frame % 4 == 0 then input.bot("low") end
    return
  end
  if ph == "grid" then return end
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
  S.visits = clamp(save.get("visits", 0), 0, 100000) + 1
  S.races = clamp(save.get("races", 0), 0, 100000)
  S.wins = clamp(save.get("wins", 0), 0, 100000)
  S.gold = clamp(save.get("gold", 0), 0, 100000)
  S.silver = clamp(save.get("silver", 0), 0, 100000)
  S.bronze = clamp(save.get("bronze", 0), 0, 100000)
  S.paint = clamp(save.get("paint", 1), 1, #PAINTS)
  for i = 1, NTRACK do S.med[i] = clamp(save.get("m" .. i, 0), 0, 5) end
  for i = 1, NRIV do S.beat[i] = clamp(save.get("b" .. i, 0), 0, 100000) end
  if not paint_open(S.paint) then S.paint = 1 end
  log("kart best " .. S.best)
  log("kart visit " .. S.visits)
  S.story_from = (S.visits > 1 and S.races > 0) and ST.kart - 10 or 0
  S.phase, S.pt = "story", S.story_from
  log("kart story")
  play_song(songs.story())
  lvl(3, 0) lvl(4, 0)
  react_to(S.story_from > 0 and "Welcome back! Race for the Star Cup!" or "A comet dropped the golden Star Cup!")
end

function quit()
  save_all()
end

-- The rivals drive (a little rubber band keeps every race close). Used while racing and after the line.
local function move_rivals(racing)
  for i, r in ipairs(S.rivals) do
    local d = r.def
    -- now and then one that is just behind you sprints (a dash of speed that never lasts), so rivals really do
    -- come past, and the race is a chase
    local burst = 0
    if r.sp > 0 then
      r.sp = r.sp - 1
      burst = 0.85
    elseif racing then
      r.cd = r.cd - 1
      local back = S.dist - r.d
      if r.cd <= 0 and back > 30 and back < 260 then r.sp, r.cd = 55, 420 end
    end
    if r.spin > 0 then
      r.spin = r.spin - 1
      r.d = r.d + 1.5
    else
      local rubber = clamp((S.dist - r.d) * 0.0025, -0.45, 0.55)
      local z = S.zap_t > 0 and 0.65 or 1
      r.d = r.d + (r.spd + rubber + burst) * z
    end
    r.x = approach(r.x, clamp(sin(S.t * d.lane + r.phase) * d.amp, -0.78, 0.78), 0.1)
    if r.mood_t > 0 then r.mood_t = r.mood_t - 1 if r.mood_t == 0 then r.mood = "" end end
    if r.cool > 0 then r.cool = r.cool - 1 end
    local gap = r.d - S.dist
    r.look = (gap > 8 and gap < 110 and abs(r.x - S.px) < 0.5) and 1 or 0
    if racing then
      -- one that stays just ahead glances back, and has something to say about it
      if r.look == 1 then r.lookn = r.lookn + 1 else r.lookn = 0 end
      if r.lookn == 45 and r.cool == 0 and S.bub_cool == 0 then
        r.cool = 220
        mood(r, "taunt", 80)
        say(i, "taunt", d.words.taunt)
        log("kart taunt " .. r.name)
      end
      -- Overtaking (and being overtaken) is a moment: the rival taunts or sulks, in its own way.
      local ahead = r.d > S.dist
      if ahead ~= r.ahead then
        r.ahead = ahead
        if r.cool == 0 and S.spin_t == 0 then
          r.cool = 150
          if ahead then
            mood(r, "taunt", 90)
            say(i, "taunt", d.words.taunt)
            log("kart taunt " .. r.name)
          else
            S.pass_n = S.pass_n + 1
            mood(r, d.lose, 90)
            say(i, d.lose, d.words.lose)
            sfx.note("tri", 84, 0.06, 0.18)
            cue(run_note(bump_run()), "tri", 0.18, "step", 0.15)
            log("kart pass " .. r.name)
          end
        end
      end
      -- Bumping a rival: harmless bounce!
      if abs(r.d - S.dist) < 22 and abs(r.x - S.px) < 0.25 then
        if S.star_t > 0 then
          r.spin = 65
          S.score = S.score + 100
          sfx.note("tri", 88, 0.12, 0.26)
          mood(r, "wow", 80)
          cue(run_note(bump_run()) + 7, "square", 0.2, "beat")
        elseif S.shield then
          S.shield = false
          r.spin = 45
          sfx.tone("sine", 780, 0.12, 0.24)
          mood(r, "wow", 70)
        else
          S.px = clamp(S.px + (S.px < r.x and -0.15 or 0.15), -0.9, 0.9)
          sfx.tone("sine", 320, 0.08, 0.16)
          S.pmood, S.pmood_t = "ouch", 40
          if r.cool == 0 then
            r.cool = 90
            mood(r, "bump", 60)
            say(i, "bump", d.words.bump)
          end
        end
      end
    end
  end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  local tap = pressed and S.saw_release
  S.t = S.t + 1
  S.pt = S.pt + 1
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.bub_t > 0 then S.bub_t = S.bub_t - 1 end
  if S.bub_cool > 0 then S.bub_cool = S.bub_cool - 1 end
  if S.pmood_t > 0 then S.pmood_t = S.pmood_t - 1 if S.pmood_t == 0 then S.pmood = "" end end
  local ph = S.phase

  if ph == "story" then
    -- the comet falls; the rivals roll in one by one; you roll in last
    if S.pt == ST.comet then sfx.slide("sine", 1800, 300, 0.5, 0.2) end
    if S.pt == ST.hit then
      gfx.flash(0xfff6c0, 8)
      stinger(0.2, "step")
      react_to("A comet dropped the golden Star Cup!")
    end
    for i = 1, NRIV do
      if S.pt == ST.riv + (i - 1) * ST.gap + 30 then
        VOICE[i]()
        cue(songs.ladder(0, 1, i * 2 - 1), "tri", 0.18, "step")
        if i == 1 then react_to("Ember, Bibi, Moss and Pebble want it too!") end
      end
    end
    if S.pt == ST.kart + 40 then
      sfx.arp("tri", {72, 76, 79, 84}, 0.06, 0.26)
      react_to("Race three tracks to win the Star Cup!")
    end
    if S.pt >= ST.kart then lvl(3, 1) lvl(4, 1) end
    if (tap and S.pt > S.story_from + 12) or S.pt > ST["end"] then
      S.phase, S.pt, S.saw_release = "garage", 0, false
      snd.ok()
      lvl(3, 1) lvl(4, 1)
      log("kart garage")
      react_to("Pick your paint! Press to race.")
    end

  elseif ph == "garage" then
    S.new_t = S.new_t + 1
    if mx ~= 0 and S.mx_prev == 0 then
      local k = S.paint
      for _ = 1, #PAINTS do
        k = (k - 1 + mx) % #PAINTS + 1
        if paint_open(k) then break end
      end
      if k ~= S.paint then
        S.paint = k
        sfx.note("tri", 76 + k, 0.08, 0.2)
        cue(songs.ladder(0, 1, k), "sine", 0.16, "step")
        log("kart pick " .. k)
        react_to("Looking good! " .. PAINTS[k].name .. "!")
      end
    end
    S.mx_prev = mx
    if tap and S.pt > 14 then
      snd.ok()
      save_all()
      enter_map()
    end

  elseif ph == "map" then
    if S.pt == pics.MAPMOVE then
      sfx.slide("sine", 400, 900, 0.3, 0.18)
      cue(songs.ladder(0, 1, S.next * 2), "tri", 0.2, "beat")
    end
    if (tap and S.pt > 30) or S.pt > 230 then
      snd.ok()
      setup_race(S.next)
    end

  elseif ph == "grid" then
    -- three lights and GO; the engines rev
    local g = S.pt
    if g == 12 or g == 34 or g == 56 then
      sfx.tone("square", 330, 0.12, 0.2)
      sfx.noise(0.08, 0.1, 900)
    end
    if g == 12 then react_to("Three...") elseif g == 34 then react_to("Two...") elseif g == 56 then react_to("One...") end
    if g == 76 then
      sfx.tone("square", 660, 0.4, 0.24)
      stinger(0.22, "step")
      S.phase = "race"
      S.go_t = 0
      S.spd = 2.5
      S.saw_release = false
      react_to("GO! " .. TRACKS[S.track].name .. "!")
      race_levels()
      local r1 = S.rivals[1 + (S.track - 1) % NRIV]
      mood(r1, "taunt", 70)
      say(r1.def.id, "taunt", r1.def.words.taunt)
    end
    for _, r in ipairs(S.rivals) do r.x = approach(r.x, -0.65 + (r.def.id - 1) * 0.42, 0.1) end

  elseif ph == "race" then
    local T = TRACKS[S.track]
    S.go_t = S.go_t + 1
    if S.star_t > 0 then S.star_t = S.star_t - 1 end
    if S.boost_t > 0 then S.boost_t = S.boost_t - 1 end
    if S.zap_t > 0 then S.zap_t = S.zap_t - 1 end
    if S.spin_t > 0 then S.spin_t = S.spin_t - 1 end
    if S.run_t > 0 then S.run_t = S.run_t - 1 end
    if S.final_t > 0 then S.final_t = S.final_t - 1 end
    if S.item_spin > 0 then
      S.item_spin = S.item_spin - 1
      if S.item_spin % 5 == 0 then sfx.tone("sine", 600 + (30 - S.item_spin) * 18, 0.04, 0.14) end
      if S.item_spin == 0 and S.item then
        sfx.arp("tri", {79, 84}, 0.05, 0.24)
        react_to("Got " .. ITEM_NAMES[S.item])
      end
    end

    -- Smooth steering with gentle road-edge rails (never get stuck!).
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
        cue(run_note(bump_run()) + 12, "square", 0.2, "beat", 0.3)
        S.pmood, S.pmood_t = "wow", 50
        particles.burst(W / 2 + S.px * 145, S.py + 12, 14, 2.8, 22, 3, C.CYAN, "star")
        react_to("WHOOSH! Rainbow Boost!")
      end
    end

    -- Item boxes (a box is left for later while your hands are full).
    for _, b in ipairs(S.boxes) do
      if not b.gone and not S.item and abs(b.d - S.dist) < 24 and abs(b.x - S.px) < 0.28 then
        b.gone = true
        S.score = S.score + 50
        particles.burst(W / 2 + S.px * 145, S.py, 14, 2.4, 22, 3, C.GOLD, "star")
        cue(run_note(bump_run()), "square", 0.2, "step", 0.14)
        S.item = ITEMS[rndi(1, #ITEMS)]
        S.item_spin = 26
        S.pmood, S.pmood_t = "happy", 40
      end
    end

    -- Seekers aim themselves at the rival ahead!
    for _, sh in ipairs(S.shells) do
      sh.d = sh.d + 9.5
      sh.life = sh.life - 1
      if sh.tgt then sh.x = approach(sh.x, sh.tgt.x, 0.18) end
      for i, r in ipairs(S.rivals) do
        if abs(r.d - sh.d) < 30 and abs(r.x - sh.x) < 0.32 then
          r.spin = 70
          sh.gone = true
          S.score = S.score + 150
          sfx.arp("tri", {79, 88}, 0.05, 0.3)
          stinger(0.2, "beat")
          local sx, sy = world_to_screen(r.x, r.d)
          if sx then particles.burst(sx, sy, 14, 3, 26, 3, C.GOLD, "star") end
          mood(r, r.def.lose == "cheer" and "sulk" or r.def.lose, 100)
          say(i, "sulk", r.def.words.sulk)
          log("kart bonk " .. r.name)
          gfx.shake(3)
          react_to("BONK! Hit " .. r.name .. "!")
          break
        end
      end
      if sh.life <= 0 then sh.gone = true end
    end
    sweep(S.shells, function(sh) return not sh.gone end)

    move_rivals(true)

    if tap then
      if S.item and S.item_spin == 0 then
        use_item()
      else
        -- A little hop on button press even without an item!
        sfx.slide("sine", 480, 720, 0.08, 0.14)
        particles.burst(W / 2 + S.px * 145, S.py + 16, 6, 1.6, 14, 2, C.GOLD, "dot")
      end
    end
    calc_place()
    if S.place == S.mplace then S.mplace_t = 0
    else
      S.mplace_t = S.mplace_t + 1
      if S.mplace_t >= 30 then S.mplace, S.mplace_t = S.place, 0 end
    end
    -- the last stretch: the song turns without a restart
    if not S.final and S.dist >= T.len * FINAL_AT then
      S.final, S.final_t = true, 130
      play_song(songs.song(S.track, true, true))
      music.tempo(1.05)
      stinger(0.22, "beat")
      sfx.arp("square", {79, 84, 88, 91}, 0.05, 0.18)
      log("kart final " .. S.track)
      local rf = S.rivals[1 + (S.track + 1) % NRIV]
      mood(rf, "wow", 70)
      say(rf.def.id, "wow", rf.def.words.cheer)
      react_to("LAST STRETCH! Go go go!")
    end
    race_levels()
    if S.dist >= T.len then finish_race() end

  elseif ph == "finish" then
    -- everyone coasts over the line; the table of this race appears
    S.spd = approach(S.spd, 3.2, 0.05)
    S.dist = S.dist + S.spd
    S.zap_t = 0
    move_rivals(false)
    if S.pt % 9 == 0 and S.pt < 80 then
      particles.spawn(rnd(40, W - 40), 60, rnd(-1.5, 1.5), rnd(0.5, 2), 70, rnd(3, 5),
        S.pt % 18 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    if S.new_paint > 0 and S.pt == 40 then
      sfx.arp("sine", {84, 88, 91, 96}, 0.07, 0.24)
      react_to("New kart paint: " .. PAINTS[S.new_paint].name .. "!")
    end
    if (tap and S.pt > 70) or S.pt > 230 then
      snd.ok()
      S.new_paint = 0
      if S.track == NTRACK then
        start_podium()
      else
        S.next = S.track + 1
        enter_map()
      end
    end

  elseif ph == "podium" then
    if S.pt % 14 == 0 then
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.5, 2), 80, rnd(3, 5),
        S.pt % 28 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
    end
    -- the table fills in from the bottom: each step arrives on a note of the march
    for k = 5, 1, -1 do
      if S.pt == 24 + (5 - k) * 22 then
        local id = S.order[k]
        if id > 0 then VOICE[id]() end
        cue(songs.ladder(0, 1, 6 - k), k == 1 and "square" or "tri", 0.22, "step", 0.3)
        if k == 4 then lvl(3, 1) elseif k == 3 then lvl(4, 1)
        elseif k == 2 then lvl(2, 1) lvl(5, 1)
        elseif k == 1 then lvl(1, 1) gfx.flash(0xfff6c0, 6) end
      end
    end
    if S.new_paint > 0 and S.pt == 170 then
      sfx.arp("sine", {84, 88, 91, 96}, 0.07, 0.24)
      react_to("New kart paint: " .. PAINTS[S.new_paint].name .. "!")
    end
    if (tap and S.pt > 150) or S.pt > 420 then
      snd.ok()
      S.new_paint = 0
      enter_garage()
    end
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
    save_all()
  end
end

function draw()
  local ph = S.phase
  local line
  if ph == "story" then pics.story(S) line = S.react_left > 0 and S.react or "Race for the Star Cup!"
  elseif ph == "garage" then pics.garage(S) line = S.react_left > 0 and S.react or "Pick your paint. Press to race!"
  elseif ph == "map" then pics.map(S) line = S.react_left > 0 and S.react or "Press to go!"
  elseif ph == "podium" then pics.podium(S) line = S.react
  else
    pics.race(S)
    local T = TRACKS[S.track]
    if ph == "race" and S.react_left == 0 then
      line = S.item and ("Press to use " .. ITEM_NAMES[S.item]) or (T.name .. "! Grab a ? box!")
    else
      line = S.react
    end
  end
  particles.draw()
  if input.down("1p") and input.down("2p") then line = "Your cups and best score will stay!" end
  ui.band(line)
end
