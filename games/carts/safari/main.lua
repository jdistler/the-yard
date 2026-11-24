-- Safari v3: Pocket Meadow Monsters, a journey.
-- Hoot the owl ranger sends you across three habitats (Sunny Meadow, Spark Cave, Crystal Pond) to be friends with
-- the monsters who woke up when three Star Orbs fell, to fill the Field Book, and to win the three gyms (Captain
-- Clover, Miss Glint, Skipper Ripple) and polish their stars. Every friend has a rare sparkly coat.
-- Controls (CONTROLS.md, unchanged): the stick walks and dodges; LOW or TR tosses a Friend Orb (or, in a gym,
-- unleashes your buddy's move); TL swaps your buddy once you have two friends. Press next to Hoot's post to open
-- the Field Book (stick left/right turns the pages, any button closes).
-- safari.sav keeps "caught N", "badges N", "best N", and the bitmask "dex N" (as ever), and, new, all clamped:
-- shiny and seen (bitmasks of the eight friends), star1..star3 (each gym's polish, 0..3), zone, buddy, visits.
--
-- Rules for the code: game logic counts game.frame and its own timers and never reads music.step() (that is for
-- the pitch of a music.cue, sound only). Chance is only the seeded rndi/rnd, never in drawing.

local pics = import("pictures")
local songs = import("songs")
local C = pics.C
local ZONES = pics.ZONES
local HX, HY = pics.HOOT_X, pics.HOOT_Y

local MONS = {
  {id = 1, name = "Sparky",  col = C.PIKA,   accent = C.RED,    kind = "elec",  zone = 1, move = "ZAP BOLT!",
   bio = "Its cheeks fizz when it is happy."},
  {id = 2, name = "Sprout",  col = C.MINT,   accent = C.GREEN,  kind = "leaf",  zone = 1, move = "LEAF SWIRL!",
   bio = "Naps in sunbeams to grow its leaves."},
  {id = 3, name = "Ember",   col = C.ORANGE, accent = C.GOLD,   kind = "fire",  zone = 2, move = "FIRE PUFF!",
   bio = "Its tail is a tiny campfire."},
  {id = 4, name = "Mystic",  col = 0xf2c14e, accent = C.CYAN,   kind = "psy",   zone = 2, move = "MIND BEAM!",
   bio = "Floats two spoons. Never stirs tea."},
  {id = 5, name = "Splash",  col = C.BLUE,   accent = C.CYAN,   kind = "water", zone = 3, move = "SPLASH WAVE!",
   bio = "Blows bubbles in time to music."},
  {id = 6, name = "Snooze",  col = C.NAVY,   accent = C.CREAM,  kind = "bear",  zone = 1, move = "MEGA BOUNCE!",
   bio = "Sleeps through everything. Hugs!"},
  {id = 7, name = "Giggle",  col = C.PURPLE, accent = C.ROSE,   kind = "ghost", zone = 2, move = "SPOOKY BALL!",
   bio = "Hides, then giggles. Boo-hoo-hoo!"},
  {id = 8, name = "Skywing", col = 0xf2a43c, accent = C.TEAL,   kind = "drag",  zone = 3, move = "DRAGON STAR!",
   bio = "Carries sunshine across the sky."},
}
local NMON = #MONS
local ZMON = {{}, {}, {}}
for _, m in ipairs(MONS) do ZMON[m.zone][#ZMON[m.zone] + 1] = m end
local GYM_FOE = {6, 7, 8}     -- each leader's ace: Snooze, Giggle, Skywing
local SHORT = {"Meadow", "Cave", "Pond"}
local VOICE = songs.VOICE

-- Type advantage (2x marks + SUPER popup; every type still wins).
local SUPER = {
  water = {fire = true}, fire = {leaf = true}, leaf = {water = true}, elec = {water = true, drag = true},
  psy = {ghost = true}, ghost = {psy = true}, drag = {drag = true, leaf = true}, bear = {elec = true},
}
-- Each friend's voice when it plays the notes you make: wave and pulse width.
local BUDDY_WAVE = {elec = {"square", 0.125}, leaf = {"tri", 0.5}, fire = {"square", 0.5}, psy = {"sine", 0.5},
                    water = {"sine", 0.5}, bear = {"tri", 0.5}, ghost = {"square", 0.25}, drag = {"tri", 0.5}}

local SHINY_NEW, SHINY_OWN, SHINY_DONE = 12, 14, 60   -- one visit in N brings a sparkly one

local S = {
  MONS = MONS,
  phase = "story", zone = 1, gi = 1, caught = 0, badges = 0, best = 0, score = 0, visits = 0, nshiny = 0, rank = 0,
  dex = {}, shiny = {}, seen = {}, stars = {0, 0, 0}, gym_done = {false, false, false},
  zone_have = {0, 0, 0}, zone_need = {3, 3, 2}, zone_done = {false, false, false},
  buddy = nil, mru = {}, fol = {},
  g_kind = "orb", g_zone = 1, g_mon = nil, g_have = 0, g_need = 0, g_dir = 0, g_text = "", g_prev = "",
  px = 192, py = 360, fx = 0, fy = -1, walk_t = 0, moving = false, bx = 160, by = 385,
  wild = {}, berry = nil, super_orb = false, orb = nil, aim = nil, rustle_cool = 0, near_hoot = false,
  -- the gym
  gym_foe = nil, gym_marks = 0, gym_win = 10, gym_t = 0, gym_atk_t = 0, foe_atk_t = 0, gym_sec = 1,
  gym_beam = nil, foe_shots = {}, foe_cool = 95, foe_rate = 96, foe_vy = 3.2, star_charge = 0, hurt_cool = 0,
  lead_t = 0, lead_mood = nil, run = 0, last_hit = -999,
  win_t = 0, win_first = false, saw_release = false, cool = 0, swap_cool = 0, react = "", react_left = 0,
  goodbye = false, t = 0, cheer_t = 0, idle_t = 0, book_page = 0, flip_cool = 0, page_id = 1, page_new_shiny = false,
  page_stamp = 0, story_tx = -30, walk_cue = -99, walkn = 0, hud_look = 0, hud_mood = nil, dry = 0,
}
pics.S = S

local FX, FY = {0, 0, 0}, {0, 0, 0}          -- followers 2 and 3 (the first is S.bx, S.by)
local FO = {{}, {}, {}}                       -- draw options per follower (reused, never rebuilt)
local CROWD = {{}, {}, {}, {}}
local FOEO = {}
local LV = {1, 1, 1, 1, 1, 1}                 -- the track levels asked of the song

local function react_to(s, n) S.react, S.react_left = s, n or 115 end
local function leaving() return input.down("1p") and input.down("2p") end

local function add_score(pts)
  S.score = min(S.score + pts, 999999)
  if S.score > S.best then S.best = S.score end
end

-- ------------------------------------------------------------------ the book, the goal
local function mask_of(t)
  local m, bit = 0, 1
  for i = 1, NMON do
    if t[i] then m = m + bit end
    bit = bit * 2
  end
  return m
end

local function load_mask(key, t)
  local mask = clamp(save.get(key, 0), 0, 255)
  local bit = 1
  for i = 1, NMON do
    t[i] = idiv(mask, bit) % 2 == 1
    bit = bit * 2
  end
end

local function count_dex()
  local n, ns = 0, 0
  for z = 1, 3 do S.zone_have[z] = 0 end
  for i = 1, NMON do
    if S.dex[i] then
      n = n + 1
      S.zone_have[MONS[i].zone] = S.zone_have[MONS[i].zone] + 1
    end
    if S.shiny[i] then ns = ns + 1 end
  end
  S.caught, S.nshiny = n, ns
  local r = 0
  for z = 1, 3 do
    S.zone_need[z] = #ZMON[z]
    S.zone_done[z] = S.zone_have[z] >= S.zone_need[z]
    S.gym_done[z] = S.stars[z] > 0
    if S.gym_done[z] then r = r + 1 end
  end
  S.rank = r
  return n
end

local function touch(id)   -- most recently used buddy first
  local m = S.mru
  for i = 1, #m do
    if m[i] == id then table.remove(m, i) break end
  end
  table.insert(m, 1, id)
end

local function rebuild_followers()
  local f = {}
  for _, id in ipairs(S.mru) do
    if S.dex[id] and #f < 3 then f[#f + 1] = id end
  end
  S.fol = f
  if f[1] then S.buddy = MONS[f[1]] end
end

local function first_missing(z)
  for _, m in ipairs(ZMON[z]) do if not S.dex[m.id] then return m end end
  return nil
end

local function dir_to(z)
  if z == S.zone then return 0 end
  return (z == S.zone % 3 + 1) and 1 or -1
end

-- Hoot's goal: the first thing in the journey that is not done yet. One picture, one line.
local function refresh_goal()
  count_dex()
  local kind, zone, mon, text = "done", S.zone, nil, "You are a Star Ranger!"
  S.g_have, S.g_need = 0, 0
  if S.caught == 0 then
    kind, zone, mon = "orb", S.zone, ZMON[S.zone][1]
    text = "Toss an orb at a monster!"
  else
    local found = false
    for z = 1, 3 do
      local m = first_missing(z)
      if m and not found then
        found, kind, zone, mon = true, "mons", z, m
        S.g_have, S.g_need = S.zone_have[z], S.zone_need[z]
        text = "Find " .. m.name .. " in the " .. SHORT[z] .. "!"
      elseif not S.gym_done[z] and not found then
        found, kind, zone = true, "gym", z
        text = "Beat " .. pics.leader_name(z) .. "!"
      end
    end
    if not found then
      if S.nshiny == 0 then
        kind, mon = "shiny", S.buddy or MONS[1]
        text = "Look for a sparkly friend!"
      else
        local zl, low = 1, 9
        for z = 1, 3 do
          if S.stars[z] < low then zl, low = z, S.stars[z] end
        end
        if low < 3 then
          kind, zone = "stars", zl
          text = "Win again for a gold star!"
        elseif S.nshiny < NMON then
          for i = 1, NMON do
            if not S.shiny[i] then
              kind, mon, zone = "shiny_mon", MONS[i], MONS[i].zone
              text = "Find a sparkly " .. MONS[i].name .. "!"
              break
            end
          end
        end
      end
    end
  end
  S.g_kind, S.g_zone, S.g_mon, S.g_text = kind, zone, mon, text
  S.g_dir = (kind == "orb" or kind == "shiny") and 0 or dir_to(zone)
  if kind ~= S.g_prev then
    S.g_prev = kind
    log("safari goal " .. kind)
  end
end

local function save_progress()
  if S.score > S.best then S.best = S.score end
  save.set("caught", count_dex())
  save.set("badges", S.badges)
  save.set("best", S.best)
  save.set("dex", mask_of(S.dex))
  save.set("shiny", mask_of(S.shiny))
  save.set("seen", mask_of(S.seen))
  for g = 1, 3 do save.set("star" .. g, S.stars[g]) end
  save.set("zone", S.zone)
  save.set("buddy", S.buddy and S.buddy.id or 0)
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

local function song_id() return S.phase == "gym" and (3 + S.gi) or S.zone end

-- Sound only: a note from the chord under the step it will land on.
local function ladder_note(n, up)
  return songs.ladder(song_id(), music.step() + 1, n) + (up or 0)
end

local function cue_note(n, vol, dur, wave, duty)
  music.cue{wave = wave or "square", duty = duty or 0.25, note = n, dur = dur or 0.2, vol = vol or 0.14, release = 0.18}
end

local function buddy_cue(n, up, vol, dur)
  local bw = BUDDY_WAVE[(S.buddy or MONS[1]).kind]
  cue_note(ladder_note(n, up), vol, dur, bw[1], bw[2])
end

local function cue_chord(vol, up, wave)
  local root, t3, t5 = songs.chord(song_id(), music.step() + 1)
  root = root + (up or 0)
  music.cue{wave = wave or "square", duty = 0.25, note = root, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = wave or "square", duty = 0.25, note = root + t3, dur = 0.42, vol = vol * 0.8, release = 0.38}
  music.cue{wave = "tri", note = root + t5, dur = 0.42, vol = vol, release = 0.38}
  music.cue{wave = "sine", note = root + 12, dur = 0.5, vol = vol * 0.9, release = 0.45}
end

local function sparkle_run(n, up)   -- a rising chord-tone twinkle, a few frames apart (sound only)
  for k = 0, n - 1 do
    after(k * 5, function() cue_note(ladder_note(k, up or 12), 0.1, 0.22, "sine", 0.5) end)
  end
end

-- The layers of a habitat follow who is there: the lead and bass grow with the party; each friend you have met
-- sings its part (fainter when it is wild and near, full when it is yours, louder for your buddy); suspense while an
-- orb wobbles takes the lead away for a moment.
local function update_mix()
  local z, party = S.zone, S.caught
  local lead = party == 0 and 0.6 or (party < 3 and 0.8 or 1.0)
  if S.orb and S.orb.state == "wobble" then lead = 0 end
  set_level(1, lead)
  set_level(2, party == 0 and 0.6 or 0.9)
  set_level(3, 1)
  local v4, v5, v6 = 0, 0, 0
  if z == 3 then v6 = party >= 3 and 0.8 or (party >= 1 and 0.4 or 0) end
  for _, m in ipairs(ZMON[z]) do
    local t = VOICE[m.id]
    local v = 0
    if S.dex[m.id] then v = (S.buddy and S.buddy.id == m.id) and 1.3 or 0.85 end
    for _, w in ipairs(S.wild) do
      if w.mon == m and w.state == "wild" then
        local tv = w.d < 95 and 0.8 or (w.d < 150 and 0.45 or 0)
        if tv > v then v = tv end
      end
    end
    if t == 4 then v4 = v elseif t == 5 then v5 = v else v6 = v end
  end
  set_level(4, v4)
  set_level(5, v5)
  set_level(6, v6)
end

local function story_music(t)
  set_level(1, 1)
  set_level(2, t >= 40 and 1 or 0)
  set_level(3, t >= 130 and 1 or 0)
  set_level(4, t >= 250 and 1 or 0)
end

-- ------------------------------------------------------------------ the habitats
local function pick_wild()
  local best, bd = nil, 155 * 155
  for _, w in ipairs(S.wild) do
    if w.state == "wild" then
      local d = (w.x - S.px) ^ 2 + (w.y - S.py) ^ 2
      if d < bd then best, bd = w, d end
    end
  end
  return best
end

local function in_chain(id)
  for _, f in ipairs(S.fol) do if f == id then return true end end
  return false
end

local function spawn_zone(z)
  S.zone = z
  S.wild = {}
  S.orb = nil
  local spots = {{88, 214}, {294, 214}, {96, 356}, {288, 360}}
  local sparkly = nil
  for idx, m in ipairs(ZMON[z]) do
    local sp = spots[idx] or {192, 260}
    local state, sh = "home", false
    if not S.dex[m.id] then
      state = "wild"
      sh = rndi(1, SHINY_NEW) == 1
    else
      local odds = S.shiny[m.id] and SHINY_DONE or SHINY_OWN
      if S.dry >= 8 and not S.shiny[m.id] then odds = 2 end   -- a long dry spell: a sparkly one comes round
      if rndi(1, odds) == 1 then state, sh = "wild", true end
    end
    if sh then sparkly = m end
    S.wild[#S.wild + 1] = {mon = m, hx = sp[1], hy = sp[2], x = sp[1], y = sp[2], ph = idx * 1.9, state = state,
      shiny = sh, d = 999, greeted = false, o = {shiny = sh, look = 0}}
  end
  if sparkly then S.dry = 0 else S.dry = S.dry + 1 end
  local bspots = {{64, 198}, {318, 198}, {68, 372}, {314, 376}}
  local bp = bspots[((z + S.badges) % #bspots) + 1]
  S.berry = {x = bp[1], y = bp[2], got = false}
  S.hud_look = 0
  refresh_goal()
  log("safari zone " .. z)
  if sparkly then
    log("safari sparkle " .. sparkly.name)
    react_to("A sparkly " .. sparkly.name .. " is here! Toss an orb!")
  elseif S.g_zone == z and S.g_kind ~= "done" and S.g_kind ~= "stars" then
    react_to("Hoot: " .. S.g_text)
  else
    react_to(ZONES[z].name .. "! Toss a Friend Orb!")
  end
end

local function enter_zone(z)
  spawn_zone(z)
  play_song(songs.habitat(z))
  update_mix()
end

local function open_book()
  S.phase, S.book_page, S.t, S.flip_cool = "book", 0, 0, 0
  S.saw_release = false
  log("safari book")
  sfx.arp("tri", {72, 79, 84}, 0.05, 0.26)
  play_song(songs.book())
end

local function close_book()
  S.phase = "explore"
  S.saw_release = false
  S.cool = 18
  snd.ok()
  play_song(songs.habitat(S.zone))
  update_mix()
end

local function begin_play()
  S.phase = "explore"
  S.saw_release = false
  S.cool = 12
  save_progress()
  enter_zone(S.zone)
end

local function cycle_buddy(step)
  if count_dex() < 2 then return false end
  local cur = S.buddy and S.buddy.id or 1
  for _ = 1, NMON do
    cur = ((cur - 1 + step) % NMON) + 1
    if S.dex[cur] then
      touch(cur)
      rebuild_followers()
      sfx.arp("tri", {72, 79, 84}, 0.04, 0.28)
      particles.burst(S.bx, S.by, 16, 2.4, 24, 2.5, S.buddy.col, "star")
      particles.text(S.bx, S.by - 18, S.buddy.col, S.buddy.name .. "!")
      react_to("Go, " .. S.buddy.name .. "! (" .. S.buddy.move .. ")")
      buddy_cue(2, 0, 0.16, 0.3)
      return true
    end
  end
  return false
end

local function throw_orb()
  if S.orb then return end
  local tgt = pick_wild()
  local is_super = S.super_orb
  if tgt and is_super then S.super_orb = false end
  log("safari orb")
  sfx.slide("sine", 540, 1140, 0.14, 0.24)
  buddy_cue(0, 12, 0.1, 0.16)
  if tgt then
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12, tx = tgt.x, ty = tgt.y,
             tgt = tgt, state = "fly", t = 0, wob = 0, super_orb = is_super}
  else
    S.orb = {x = S.px, y = S.py - 12, x0 = S.px, y0 = S.py - 12,
             tx = clamp(S.px + S.fx * 76, 28, W - 28), ty = clamp(S.py + S.fy * 76, 130, 440),
             tgt = nil, state = "fly", t = 0, wob = 0, super_orb = false}
  end
end

local function finish_catch(o)
  local w = o.tgt
  local m = w.mon
  local is_new = not S.dex[m.id]
  local new_shiny = w.shiny and not S.shiny[m.id]
  local had_stamp = S.zone_done[m.zone]
  S.dex[m.id], S.seen[m.id] = true, true
  if w.shiny then S.shiny[m.id] = true end
  touch(m.id)
  rebuild_followers()
  w.state = "gone"
  add_score((o.super_orb and 300 or 200) + (is_new and 100 or 0) + (new_shiny and 400 or 0))
  S.cheer_t = 150
  log("safari catch " .. m.name)
  if w.shiny then log("safari shiny " .. m.name) end
  refresh_goal()
  S.page_stamp = (not had_stamp and S.zone_done[m.zone]) and m.zone or 0
  if S.page_stamp > 0 then log("safari stamp " .. S.page_stamp) end
  save_progress()
  sfx.arp("tri", {72, 76, 79, 84, 88}, 0.055, 0.34)
  particles.burst(o.x, o.y, 28, 3.4, 36, 3.2, C.GOLD, "star")
  if not (is_new or new_shiny) then particles.text(o.x, o.y - 18, C.GOLD, "FRIEND!") end
  -- the catch jingle lands on the beat: a chord, then a climbing twinkle
  cue_chord(0.15, 0, BUDDY_WAVE[m.kind][1])
  after(14, function() cue_chord(0.12, 12, "sine") end)
  sparkle_run(w.shiny and 7 or 4, 12)
  S.orb = nil
  if is_new or new_shiny then
    S.phase, S.t, S.page_id, S.page_new_shiny = "page", 0, m.id, new_shiny
    S.saw_release = false
  else
    react_to("Yay! " .. m.name .. " is happy to see you!")
  end
end

-- ------------------------------------------------------------------ the gyms
local function start_gym()
  local gi = S.zone
  S.phase, S.gi = "gym", gi
  S.gym_foe = MONS[GYM_FOE[gi]]
  local r = S.stars[gi]
  S.gym_marks, S.gym_win, S.gym_t = 0, min(18, 10 + (gi - 1) * 2 + r * 2), 0
  S.foe_rate = max(56, 96 - (gi - 1) * 6 - r * 3)
  S.foe_vy = 3.2 + min((gi - 1) * 0.25 + r * 0.1, 1.2)
  S.gym_atk_t, S.foe_atk_t, S.foe_cool, S.star_charge, S.hurt_cool = 0, 0, 75, 0, 0
  S.lead_t, S.lead_mood, S.run, S.gym_sec = 0, nil, 0, 1
  S.foe_shots, S.gym_beam = {}, nil
  S.px, S.py = 192, 404
  S.bx, S.by = 192, 360
  log("safari gym")
  play_song(songs.gym(gi, 1))
  music.tempo(1)
  music.volume(1)
  sfx.arp("square", {69, 72, 76, 81}, 0.055, 0.30)
  react_to(pics.leader_name(gi) .. " and " .. S.gym_foe.name .. "! Dodge & attack!")
end

local function gym_mix()
  set_level(1, S.hurt_cool > 0 and 0.3 or 1)
  set_level(4, S.star_charge >= 3 and 1.4 or 1)
end

-- ------------------------------------------------------------------ Built-in Bot
function bot()
  if S.phase == "story" then
    if S.t > 20 and game.frame % 10 == 0 then input.bot("low") end
    return
  elseif S.phase == "page" then
    if S.t > 36 and game.frame % 6 == 0 then input.bot("low") end
    return
  elseif S.phase == "book" then
    if S.t > 40 and game.frame % 30 == 0 then input.bot("low") end
    return
  elseif S.phase == "gym" then
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
  if S.orb then return end
  local tgt = nil
  for _, w in ipairs(S.wild) do if w.state == "wild" then tgt = w break end end
  if tgt then
    if dist(S.px, S.py, tgt.x, tgt.y) < 120 then
      if game.frame % 8 == 0 then input.bot("low") end
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
  sfx.limit(8000)
  pics.build_bgs()
  S.badges = clamp(save.get("badges", 0), 0, 100000)
  S.best = clamp(save.get("best", 0), 0, 999999)
  load_mask("dex", S.dex)
  load_mask("shiny", S.shiny)
  load_mask("seen", S.seen)
  local legacy = save.get("star1", -1) == -1
  for g = 1, 3 do S.stars[g] = clamp(save.get("star" .. g, 0), 0, 3) end
  if legacy then   -- a save from before the gyms had stars: its badges are the first gyms won
    for g = 1, min(S.badges, 3) do S.stars[g] = 1 end
  end
  S.visits = clamp(save.get("visits", 0), 0, 100000) + 1
  S.zone = clamp(save.get("zone", 1), 1, 3)
  local bid = clamp(save.get("buddy", 0), 0, NMON)
  for i = 1, NMON do
    if S.dex[i] then
      S.seen[i] = true
      touch(i)
    end
  end
  if bid > 0 and S.dex[bid] then touch(bid) end
  rebuild_followers()
  count_dex()
  for i = 1, 3 do FX[i], FY[i] = S.px, S.py + 30 end
  S.bx, S.by = S.px - 30, S.py + 8
  log("safari caught " .. S.caught)
  refresh_goal()
  S.phase = "story"
  S.t = (S.visits > 1 and S.caught > 0) and 250 or 0
  log("safari story " .. (S.t > 0 and "back" or "new"))
  play_song(songs.story())
  story_music(S.t)
end

function quit()
  save_progress()
end

local function step_explore(mx, my, pressed, swap_l)
  S.moving = false
  if mx ~= 0 or my ~= 0 then
    S.moving = true
    S.walk_t = S.walk_t + 1
    S.fx, S.fy = mx, my
    S.px = clamp(S.px + mx * 2.5, 22, W - 22)
    S.py = clamp(S.py + my * 2.5, 134, 444)
    if S.rustle_cool == 0 and (S.px < 156 or S.px > 228) and (S.py < 252 or S.py > 322) then
      S.rustle_cool = 14
      particles.burst(S.px, S.py + 12, 4, 1.4, 16, 2.2, ZONES[S.zone].accent, "square")
      sfx.noise(0.035, 0.09, 2600)
    end
    -- walking plays a soft tune in the habitat's key, in the voice of your buddy
    if game.frame - S.walk_cue >= 16 then
      S.walk_cue = game.frame
      S.walkn = S.walkn + 1
      buddy_cue(S.walkn % 7, -12 + (idiv(S.walkn, 7) % 2) * 12, 0.07, 0.16)
    end
  end

  -- walk off the left or right edge to visit the other habitats
  if S.px <= 24 and mx < 0 then
    S.px = W - 42
    enter_zone(S.zone == 1 and 3 or S.zone - 1)
    save_progress()
  elseif S.px >= W - 24 and mx > 0 then
    S.px = 42
    enter_zone(S.zone == 3 and 1 or S.zone + 1)
    save_progress()
  end

  -- the buddies trail behind in a little line
  S.bx = approach(S.bx, S.px - S.fx * 30, 0.09)
  S.by = approach(S.by, S.py - S.fy * 26 + 8, 0.09)
  for k = 2, 3 do
    local px_, py_ = (k == 2) and S.bx or FX[2], (k == 2) and S.by or FY[2]
    FX[k] = approach(FX[k], px_ - S.fx * 24 + ((k == 2) and 12 or -12), 0.08)
    FY[k] = approach(FY[k], py_ - S.fy * 20 + 12, 0.08)
  end

  -- Hoot's post
  S.near_hoot = dist(S.px, S.py, HX, HY + 8) < 48
  S.hud_look = S.g_dir

  -- Golden Berry pickup powers up the next Friend Orb
  if S.berry and not S.berry.got and dist(S.px, S.py, S.berry.x, S.berry.y) < 26 then
    S.berry.got = true
    S.super_orb = true
    add_score(100)
    log("safari berry")
    sfx.arp("tri", {76, 81, 84, 88}, 0.045, 0.28)
    particles.burst(S.berry.x, S.berry.y, 20, 2.6, 28, 3, C.GOLD, "star")
    particles.text(S.berry.x, S.berry.y - 16, C.GOLD, "SUPER ORB!")
    cue_chord(0.12, 12, "sine")
    react_to("Golden Berry! Next throw is a SUPER GOLDEN ORB!")
  end

  -- the monsters roam; they notice you, wave, and the near ones start to sing along
  local f = game.frame
  for _, w in ipairs(S.wild) do
    if w.state == "wild" then
      w.x = w.hx + sin(f * 0.025 + w.ph) * 28
      w.y = w.hy + sin(f * 0.037 + w.ph) * 14
      w.d = dist(w.x, w.y, S.px, S.py)
      if (f + w.mon.id * 29) % 140 == 0 then
        particles.burst(w.x, w.y - 6, 4, 1.3, 18, 2.2, w.mon.accent, "star")
      end
      if w.shiny and (f + w.mon.id * 17) % 60 == 0 then
        particles.burst(w.x, w.y - 8, 5, 1.5, 22, 2.6, C.GOLD, "star")
      end
      if w.d < 150 and not S.seen[w.mon.id] then
        S.seen[w.mon.id] = true
        log("safari seen " .. w.mon.name)
      end
    elseif w.state == "home" then
      w.x = w.hx + sin(f * 0.02 + w.ph) * 10
      w.y = w.hy + sin(f * 0.031 + w.ph) * 5
      w.d = dist(w.x, w.y, S.px, S.py)
      if w.d < 64 and not w.greeted and not in_chain(w.mon.id) then
        w.greeted = true
        particles.burst(w.x, w.y - 22, 6, 1.6, 22, 3, C.ROSE, "heart")
        sfx.note("tri", 84, 0.08, 0.2)
        cue_note(ladder_note(3, 0), 0.1, 0.2, "sine", 0.5)
        if S.react_left == 0 then react_to(w.mon.name .. " waves hello!", 80) end
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
          o.tgt.state = "caught"
          sfx.note("sine", 76, 0.14, 0.26)
          cue_chord(0.1, 0, "sine")
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
        cue_note(ladder_note(o.wob * 2, 0), 0.12, 0.2, "tri", 0.5)
      end
      if o.t >= need then
        finish_catch(o)
        if S.phase ~= "explore" then return end
      end
    end
  end

  -- the Gym arch
  if S.buddy and S.py < 148 and abs(S.px - 192) < 46 then
    start_gym()
    return
  end

  -- TL swaps your buddy once you have two; any right-hand button throws an orb (or opens the book at Hoot's post)
  if S.saw_release and S.swap_cool == 0 and count_dex() >= 2 and swap_l then
    cycle_buddy(1)
    S.swap_cool = 16
  elseif pressed and not (swap_l and count_dex() >= 2) and S.saw_release and S.cool == 0 then
    if S.near_hoot then open_book() else throw_orb() end
    S.cool = 18
  end
  update_mix()
end

local function step_gym(mx, pressed, swap_l)
  S.gym_t = S.gym_t + 1
  if S.gym_atk_t > 0 then S.gym_atk_t = S.gym_atk_t - 1 end
  if S.foe_atk_t > 0 then S.foe_atk_t = S.foe_atk_t - 1 end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.lead_t > 0 then S.lead_t = S.lead_t - 1 end

  S.moving = mx ~= 0
  if mx ~= 0 then
    S.walk_t = S.walk_t + 1
    S.fx = mx
    S.px = clamp(S.px + mx * 2.8, 44, W - 44)
  end
  S.bx = approach(S.bx, S.px, 0.16)
  S.by = approach(S.by, S.py - 44, 0.16)

  local swapped = false
  if S.saw_release and S.swap_cool == 0 and count_dex() >= 2 and swap_l then
    cycle_buddy(1)
    S.swap_cool = 16
    swapped = true
  end

  -- the leader telegraphs and throws playful, dodgeable orbs
  S.foe_cool = S.foe_cool - 1
  if S.foe_cool == 20 then
    S.foe_atk_t = 14
    sfx.slide("sine", 420, 680, 0.12, 0.18)
  elseif S.foe_cool <= 0 then
    S.foe_cool = S.foe_rate
    local tx = clamp(S.px + rnd(-26, 26), 54, W - 54)
    local vx = (tx - 192) / 54
    S.foe_shots[#S.foe_shots + 1] = {x = 192, y = 182, vx = vx, vy = S.foe_vy, col = S.gym_foe.col, dodged = false}
  end

  for _, sh in ipairs(S.foe_shots) do
    sh.x, sh.y = sh.x + sh.vx, sh.y + sh.vy
    if S.hurt_cool == 0 and dist(sh.x, sh.y, S.bx, S.by) < 22 then
      sh.gone = true
      S.hurt_cool = 36
      S.lead_t, S.lead_mood = 40, "cheer"
      sfx.slide("sine", 380, 220, 0.14, 0.22)
      gfx.shake(3)
      particles.burst(S.bx, S.by, 10, 2.2, 18, 2.4, sh.col, "star")
      particles.text(S.bx, S.by - 18, C.CREAM, "WHOA!")
      cue_note(ladder_note(0, -12), 0.16, 0.3, "tri", 0.5)
    elseif not sh.dodged and sh.y > S.by + 24 then
      sh.dodged = true
      if abs(sh.x - S.bx) < 30 and S.hurt_cool == 0 then   -- a near miss
        log("safari whew")
        particles.text(S.bx + 16, S.by - 26, C.CYAN, "WHEW!")
      end
      if S.star_charge < 3 then
        S.star_charge = S.star_charge + 1
        add_score(40)
        sfx.note("sine", 80 + S.star_charge * 3, 0.09, 0.22)
        buddy_cue(S.star_charge * 2, 12, 0.1, 0.2)
        if S.star_charge == 3 then
          particles.text(S.bx, S.by - 20, C.GOLD, "STAR READY!")
          react_to("STAR POWER FULL! Press for ULTIMATE MOVE!")
        end
      end
    end
    if sh.y > H - 24 then sh.gone = true end
  end
  sweep(S.foe_shots, function(sh) return not sh.gone end)

  -- your buddy's signature move
  if pressed and not swapped and not (swap_l and count_dex() >= 2) and S.saw_release and S.cool == 0 then
    S.cool = 14
    S.gym_atk_t = 14
    S.cheer_t = 30
    local b = S.buddy or MONS[1]
    local is_ult = S.star_charge >= 3
    local is_super = SUPER[b.kind] and SUPER[b.kind][S.gym_foe.kind]
    local dmg = is_ult and 3 or (is_super and 2 or 1)
    if is_ult then S.star_charge = 0 end
    S.gym_marks = min(S.gym_win, S.gym_marks + dmg)
    add_score(dmg * 60)
    S.lead_t, S.lead_mood = 26, "ouch"
    S.gym_beam = {x0 = S.bx, y0 = S.by - 10, x1 = 192, y1 = 166, t = is_ult and 18 or 13,
                  col = is_ult and C.GOLD or b.col, kind = is_ult and "ult" or b.kind}
    -- each hit is the next note of a rising run in the chord, on the beat
    if game.frame - S.last_hit > 150 then S.run = 0 end
    S.last_hit = game.frame
    buddy_cue(S.run % 7, 12 + idiv(S.run, 7) * 12, 0.16, 0.25)
    S.run = S.run + 1
    if is_ult then
      sfx.arp("square", {72, 79, 84, 91, 96}, 0.035, 0.34)
      gfx.shake(6)
      particles.burst(192, 166, 26, 3.6, 30, 3.2, C.GOLD, "star")
      particles.text(192, 132, C.GOLD, "STAR BLAST!")
      cue_chord(0.16, 12, "square")
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
    -- the song turns up as the leader weakens (the same bars, a harder section)
    local frac = (S.gym_win - S.gym_marks) / max(1, S.gym_win)
    local sec = frac > 0.66 and 1 or (frac > 0.33 and 2 or 3)
    if sec ~= S.gym_sec and S.gym_marks < S.gym_win then
      S.gym_sec = sec
      log("safari gym section " .. sec)
      music.play(songs.gym(S.gi, sec, true))
      music.tempo(1 + 0.07 * (sec - 1))
      cue_chord(0.14, 0, "square")
      particles.text(192, 120, C.CREAM, sec == 2 and "HEATING UP!" or "ALMOST!")
    end
    if S.gym_marks >= S.gym_win then
      S.phase, S.win_t = "gymwin", 0
      S.win_first = S.stars[S.gi] == 0
      S.stars[S.gi] = min(3, S.stars[S.gi] + 1)
      S.badges = S.badges + 1
      S.lead_mood, S.lead_t = "bow", 9999
      add_score(500)
      count_dex()
      refresh_goal()
      save_progress()
      log("safari badge " .. S.badges)
      log("safari star " .. S.gi .. " " .. S.stars[S.gi])
      sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.075, 0.36)
      particles.burst(192, 166, 38, 4.2, 48, 3.6, C.GOLD, "star")
      play_song(songs.fanfare(S.gi))
      music.tempo(1)
      react_to("YOU WON THE " .. pics.badge_name(S.gi) .. " BADGE!", 150)
    end
  end
  if S.phase == "gym" then gym_mix() end
end

local function update_story(pressed)
  S.t = S.t + 1
  story_music(S.t)
  if (pressed and S.saw_release and S.t > 14) or S.t > 440 then
    snd.ok()
    begin_play()
  end
end

local function update_page(pressed)
  S.t = S.t + 1
  if S.t % 12 == 0 and S.t < 200 then
    particles.spawn(rnd(40, W - 40), 30, rnd(-1, 1), rnd(0.6, 1.6), 70, rnd(3, 4.5),
      (S.t % 24 == 0) and C.GOLD or C.ROSE, "star", 0.04, 0.99, 0.1)
  end
  update_mix()
  if (pressed and S.saw_release and S.t > 30) or S.t > 360 then
    S.phase = "explore"
    S.saw_release = false
    S.cool = 18
    snd.ok()
    if S.page_stamp > 0 then
      react_to("HABITAT STAMP! " .. ZONES[S.page_stamp].name .. " is all friends!", 150)
    else
      react_to("Hoot: " .. S.g_text, 150)
    end
  end
end

local function update_book(pressed, mx)
  S.t = S.t + 1
  if S.flip_cool > 0 then S.flip_cool = S.flip_cool - 1 end
  if mx ~= 0 and S.flip_cool == 0 then
    S.flip_cool = 14
    S.book_page = (S.book_page + (mx > 0 and 1 or -1)) % (NMON + 1)
    sfx.note("tri", 76 + S.book_page, 0.06, 0.2)
    cue_note(72 + (S.book_page * 2) % 12, 0.1, 0.25, "sine", 0.5)
  end
  if pressed and S.saw_release and S.t > 12 then close_book() end
end

local function update_gymwin(pressed)
  S.win_t = S.win_t + 1
  if S.win_t % 10 == 0 then
    particles.spawn(rnd(36, W - 36), 66, rnd(-1.5, 1.5), rnd(0.8, 2.2), 75, rnd(3, 4.5),
      S.win_t % 20 == 0 and C.GOLD or C.ROSE, "star", 0.05, 0.99, 0.1)
  end
  if S.win_t == 150 then react_to("Hoot: " .. S.g_text, 200) end
  if (pressed and S.saw_release and S.win_t > 60) or S.win_t > 330 then
    snd.ok()
    S.phase = "explore"
    S.saw_release = false
    S.cool = 18
    S.px, S.py = 192, 344
    S.lead_mood, S.lead_t = nil, 0
    local nz = S.zone
    if S.win_first then nz = S.zone == 3 and 1 or S.zone + 1 end
    enter_zone(nz)
    save_progress()
  end
end

function update()
  local pressed, held = input.action(), input.action_down()
  local swap_l = input.pressed("tl")
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.cool > 0 then S.cool = S.cool - 1 end
  if S.swap_cool > 0 then S.swap_cool = S.swap_cool - 1 end
  if S.rustle_cool > 0 then S.rustle_cool = S.rustle_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.cheer_t > 0 then S.cheer_t = S.cheer_t - 1 end
  S.hud_mood = S.cheer_t > 0 and "cheer" or nil
  if mx ~= 0 or my ~= 0 or pressed then S.idle_t = 0 else S.idle_t = S.idle_t + 1 end

  local ph = S.phase
  if ph == "story" then update_story(pressed)
  elseif ph == "explore" then step_explore(mx, my, pressed, swap_l)
  elseif ph == "gym" then step_gym(mx, pressed, swap_l)
  elseif ph == "gymwin" then update_gymwin(pressed)
  elseif ph == "page" then update_page(pressed)
  elseif ph == "book" then update_book(pressed, mx) end

  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

-- ------------------------------------------------------------------ Signature Move VFX
local function draw_beam(b)
  local k = b.kind
  if k == "elec" or k == "ult" then
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
    for seg = 1, 6 do
      local f = clamp(seg / 6 + (13 - b.t) * 0.04, 0, 1)
      local ox = lerp(b.x0, b.x1, f) + sin(seg * 2.1 + game.frame * 0.4) * 8
      local oy = lerp(b.y0, b.y1, f)
      gfx.circle(ox, oy, 5 + b.t * 0.4, alpha(b.col, 210))
      gfx.circle(ox, oy, 2.5 + b.t * 0.2, C.WHITE)
    end
  elseif k == "psy" then
    for seg = 1, 5 do
      local f = seg / 5
      local ox, oy = lerp(b.x0, b.x1, f), lerp(b.y0, b.y1, f)
      gfx.circle_o(ox, oy, 6 + seg * 3, alpha(C.CYAN, 80), C.ROSE, 2.2)
    end
  else
    gfx.line(b.x0, b.y0, b.x1, b.y1, b.t * 0.7, alpha(b.col, 200))
    for seg = 1, 4 do
      local f = seg / 4
      gfx.star(lerp(b.x0, b.x1, f), lerp(b.y0, b.y1, f), 7, game.frame * 0.3 + seg, C.GOLD)
    end
  end
end

local function band_line()
  if leaving() then return "See you next time, Ranger!" end
  local ph = S.phase
  if ph == "story" then
    if S.t >= 250 and S.visits > 1 and S.caught > 0 and S.t < 330 then
      return "Welcome back, Ranger! " .. S.caught .. "/8 friends"
    end
    return pics.story_line(S.t)
  elseif ph == "page" then
    local m = MONS[S.page_id]
    if S.page_new_shiny then return "A SPARKLY " .. m.name .. "! A rare one!" end
    return "A new page in the Field Book: " .. m.name .. "!"
  elseif ph == "book" then
    return S.book_page == 0 and "Your Field Book! Stick turns pages." or "Stick turns pages. Any button closes."
  end
  if S.react_left > 0 and S.react ~= "" then return S.react end
  if ph == "gym" then
    return "Dodge & press for " .. (S.buddy and S.buddy.move or "STAR BEAM!")
  elseif ph == "gymwin" then
    return "YOU WON THE " .. pics.badge_name(S.gi) .. " BADGE!"
  end
  if S.near_hoot then return "Hoot: press to open the Field Book!" end
  if S.aim then
    return "Press to toss a Friend Orb at " .. (S.aim.shiny and "sparkly " or "") .. S.aim.mon.name .. "!"
  end
  if S.idle_t > 420 then return "Hoot: Hoot hoot! Let's go exploring!" end
  return S.buddy and ("Hoot: " .. S.g_text) or "Walk near a monster and press!"
end

local function draw_wild_and_friends()
  local f = game.frame
  for _, w in ipairs(S.wild) do
    local o = w.o
    local look = clamp((S.px - w.x) / 60, -1, 1)
    if w.state == "wild" then
      local near = w.d < 100
      o.look, o.hop, o.sleep, o.heart = look, near, (w.mon.kind == "bear" and not near), false
      pics.draw_mon(w.mon, w.x, w.y, 1.05, false, 0, o)
    elseif w.state == "home" and not in_chain(w.mon.id) then
      o.shiny = S.shiny[w.mon.id]
      o.look, o.hop, o.sleep, o.heart = look, w.d < 70, false, true
      pics.draw_mon(w.mon, w.x, w.y, 0.95, w.d < 70, 0, o)
    end
  end
end

local function draw_followers(napping)
  for k = #S.fol, 1, -1 do
    local id = S.fol[k]
    local o = FO[k]
    o.shiny = S.shiny[id]
    o.look = S.aim and clamp((S.aim.x - S.bx) / 60, -1, 1) or S.fx
    o.hop = S.cheer_t > 0
    o.sleep = napping
    o.heart = false
    local x, y = (k == 1) and S.bx or FX[k], (k == 1) and S.by or FY[k]
    pics.draw_mon(MONS[id], x, y, 0.88 - (k - 1) * 0.05, S.cheer_t > 0, 0, o)
  end
end

local function draw_explore()
  local f = game.frame
  pics.scene("z" .. S.zone)
  pics.draw_habitat(S.zone)
  -- Hoot on his post: he watches you, and shows the book when you are close
  pics.draw_hoot(HX, HY - 4, 1.0, clamp((S.px - HX) / 60, -1, 1), S.near_hoot and "cheer" or nil, false)
  if S.near_hoot then
    local bob = sin(f * 0.15) * 3
    gfx.rrect_o(HX - 14, HY - 56 + bob, 28, 20, 4, C.PAPER, C.BROWN, 2)
    gfx.star(HX, HY - 46 + bob, 6, f * 0.04, C.GOLD)
  end
  if S.berry and not S.berry.got then
    pics.draw_berry(S.berry.x, S.berry.y + sin(f * 0.12) * 3)
  end
  draw_wild_and_friends()
  if S.aim then
    for k = 0, 3 do
      local a = f * 0.08 + k * 1.571
      gfx.star(S.aim.x + cos(a) * 26, S.aim.y + sin(a) * 26, 5, a, (S.super_orb or S.aim.shiny) and C.GOLD or C.WHITE)
    end
    gfx.rrect_o(S.aim.x - 40, S.aim.y + 22, 80, 18, 6, alpha(C.CREAM, 230), C.INK, 1.4)
    gfx.text((S.aim.shiny and "*" or "") .. S.aim.mon.name, S.aim.x, S.aim.y + 24, 11, C.INK, "center")
  end
  if S.orb then
    local wob = S.orb.state == "wobble" and sin(S.orb.t * 0.45) * 4.5 or 0
    pics.draw_orb(S.orb.x, S.orb.y, 11, S.orb.super_orb, wob)
  end
  draw_followers(S.idle_t > 480)
  pics.draw_trainer(S.px, S.py, S.fx, S.fy, S.walk_t, S.moving, pics.cap_col(S.rank), S.cheer_t > 0)
end

local function draw_gym()
  local foe = S.gym_foe
  local f = game.frame
  pics.scene("g" .. S.gi)
  pics.draw_gym_beams(foe and foe.col)
  -- your friends cheer from the stands, and hop when you hit
  local slots = {36, 68, 316, 348}
  local n = 0
  for _, id in ipairs(S.mru) do
    if S.dex[id] and n < 4 then
      n = n + 1
      local o = CROWD[n]
      o.shiny, o.hop, o.heart = S.shiny[id], S.gym_atk_t > 0 or S.cheer_t > 0, false
      o.look = 0
      pics.draw_mon(MONS[id], slots[n], 100, 0.5, o.hop, 0, o)
    end
  end
  -- the leader and Hoot
  local mood = S.lead_t > 0 and S.lead_mood or nil
  if not mood and S.phase == "gym" and (S.gym_win - S.gym_marks) / max(1, S.gym_win) < 0.34 then mood = "worry" end
  pics.draw_leader(S.gi, 62, 182, 1.0, mood)
  gfx.rrect_o(14, 214, 96, 18, 6, alpha(C.CREAM, 230), C.INK, 1.4)
  gfx.text(pics.leader_name(S.gi), 62, 216, 11, C.INK, "center")
  pics.draw_hoot(326, 190, 0.95, -1, (S.gym_atk_t > 0 or S.phase == "gymwin") and "cheer" or nil, false)
  if foe then
    FOEO.look = clamp((S.px - 192) / 120, -1, 1)
    pics.draw_mon(foe, 192, 166, 1.55, S.phase == "gymwin", S.foe_atk_t, FOEO)
    gfx.rrect_o(102, 72, 180, 38, 10, C.CREAM, C.INK, 2)
    gfx.text(foe.name:upper(), 114, 76, 13, C.INK, "left")
    local rem = max(0, S.gym_win - S.gym_marks)
    local frac = rem / max(1, S.gym_win)
    local hp_col = frac > 0.5 and C.GREEN or (frac > 0.25 and C.GOLD or C.RED)
    gfx.rrect_o(114, 94, 156, 10, 5, 0x4a3a58, C.INK, 1.4)
    if frac > 0 then gfx.rrect(116, 96, max(6, floor(152 * frac)), 6, 3, hp_col) end
  end
  for _, sh in ipairs(S.foe_shots) do
    gfx.glow(sh.x, sh.y, 18, alpha(sh.col, 150))
    gfx.circle_o(sh.x, sh.y, 9, sh.col, C.INK, 2)
    gfx.circle(sh.x - 2, sh.y - 2, 3, C.WHITE)
  end
  if S.gym_beam and S.gym_beam.t > 0 then
    draw_beam(S.gym_beam)
    S.gym_beam.t = S.gym_beam.t - 1
  end
  gfx.rrect_o(14, 344, 64, 48, 10, alpha(C.CREAM, 230), C.INK, 1.8)
  gfx.text("STAR", 46, 348, 11, C.PURPLE, "center")
  for k = 1, 3 do
    gfx.star(24 + (k - 1) * 22, 374, 7.5, 0, k <= S.star_charge and C.GOLD or 0xb8aec4)
  end
  if S.buddy then
    FO[1].shiny, FO[1].look, FO[1].hop, FO[1].sleep, FO[1].heart = S.shiny[S.buddy.id], 0, false, false, false
    pics.draw_mon(S.buddy, S.bx, S.by, 1.15, S.phase == "gymwin", S.gym_atk_t, FO[1])
  end
  pics.draw_trainer(S.px, S.py, S.fx, S.fy, S.walk_t, S.moving, pics.cap_col(S.rank), S.phase == "gymwin" or S.cheer_t > 0)
  if S.phase == "gymwin" then
    gfx.rrect_o(36, 214, W - 72, 150, 16, C.CREAM, C.INK, 3)
    pics.draw_badge(W / 2, 252, S.gi, 1.15, true, S.stars[S.gi])
    gfx.text(pics.badge_name(S.gi) .. " BADGE!", W / 2, 296, 22, C.GOLD, "center", C.INK)
    gfx.text(S.win_first and "A NEW BADGE!" or (S.stars[S.gi] >= 3 and "ALL THREE STARS!" or "A SHINY NEW STAR!"),
      W / 2, 326, 13, C.PURPLE, "center")
    gfx.text("BADGES: " .. S.badges .. "   FRIENDS: " .. S.caught .. "/8", W / 2, 344, 13, C.INK, "center")
  end
end

function draw()
  local ph = S.phase
  if ph == "story" then
    pics.draw_story(S.t)
    particles.draw()
    ui.band(band_line())
    return
  elseif ph == "gym" or ph == "gymwin" then
    draw_gym()
    pics.draw_hud()
  elseif ph == "page" then
    pics.scene("z" .. S.zone)
    pics.draw_friend_page(S.page_id, "new")
    gfx.rrect_o(62, 428, W - 124, 34, 12, C.GOLD, C.INK, 2.5)
    gfx.text(S.page_new_shiny and "SPARKLY FRIEND!" or "NEW FRIEND!", W / 2, 433, 22, C.INK, "center")
    if S.page_stamp > 0 then
      pics.draw_stamp(W - 52, 306, S.page_stamp, 1.1, true)
      gfx.text("STAMP!", W - 52, 332, 11, C.RED, "center")
    end
  elseif ph == "book" then
    pics.scene("z" .. S.zone)
    if S.book_page == 0 then pics.draw_book_cover() else pics.draw_friend_page(S.book_page, "book") end
  else
    draw_explore()
    pics.draw_hud()
  end
  particles.draw()
  ui.band(band_line())
end
