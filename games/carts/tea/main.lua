-- Tea: a unicorn flies to a castle and takes care of the cats.
-- Little band (CONTROLS.md): any stick direction does a useful thing, every right-hand
-- button does the care, and a turn cannot be lost. The spec is DESIGN.md beside this file.
--
-- The flight: treats float toward her along the rainbow in three lanes. Left and right
-- change lane, up and down swoop to the next treat, a button sparkles (and the sparkle
-- reaches the side lanes too). What she catches decorates the party.
-- The party: the stick visits the next cat, a button gives the picture over its head.
-- Each of a cat's three hearts asks for something different: its own wish, a cupcake,
-- a hug. When every heart glows the table cheers, a photo goes on the castle wall, and
-- the buttons play a song.
-- tea.sav remembers visits, gifts, and photos. Hearts start fresh each visit.

local pics = import("pictures")

local BAND = 32
local SKY_STEP, HURRY_STEP = 480, 900
local FLY_DONE = SKY_STEP * 900
local DOOR_FRAMES, REACT_FRAMES, CHEER_FRAMES, CARE_GAP = 100, 120, 200, 30
local LANE_X, BASKET_MAX = 108, 14

local PIP, MOTH, PEARL, NIB = 1, 2, 3, 4
local NAMES = {"Pip", "Moth", "Pearl", "Nib"}
local GIFT_WORD = {"none", "teacup", "ribbon", "flower"}
local GIFT_FOR = {[PIP] = "teacup", [MOTH] = "ribbon", [PEARL] = "flower"}
local C = pics.C

-- What the whole game knows. pictures.lua reads it to draw.
local st = {
  phase = "sky", fly = 0, door_t = 0, focus = PIP, ncats = 3, visits = 0, photos = 0,
  hearts = {0, 0, 0, 0}, gift = {"none", "none", "none", "none"}, last_friend = PIP,
  react_left = 0, react_line = "", cheer_left = 0, cheered = false, care_wait = 0, care_from_party = false,
  song_i = 0, song_mode = false, hurry = false, lane = 0, swoop_t = 0, bump_cool = 0, goodbye = false,
  stick_hold = 0, delight = {0, 0, 0, 0}, heart_pop = {0, 0, 0, 0}, care_kind = {}, toss_t = 0, toss_who = 1,
  toss_kind = "cup", idle_who = 0, idle_t = 0, photo_t = 0, sparkle_t = 0,
  wing = 0, uni_x = W / 2, uni_lx = 0, cat_lean = {0, 0, 0, 0}, tilt = 0,
  got = {balloon = 0, cake = 0, flower = 0, star = 0}, basket = {}, clouds = {}, treats = {}, next_treat = 40,
}
pics.st = st

-- ------------------------------------------------------------------ sound

local sky_bed = {bpm = 96, steps = 2,
  {"C5 . E5 . G5 . E5 . A5 . G5 . E5 . D5 . ", wave = "sine", vol = 0.09, release = 0.35, attack = 0.02, pan = -0.2},
  {"C3 - - - - - - - F3 - - - G3 - - - ", wave = "sine", vol = 0.08, release = 0.5, attack = 0.05, pan = 0.2}}
local party_bed = {bpm = 90, steps = 2,
  {"C5 . E5 . G5 . E5 . F5 . A5 . G5 . E5 . ", wave = "tri", vol = 0.05, release = 0.3, attack = 0.01, pan = -0.2},
  {"C3 - - - - - - - F3 - - - G3 - - - ", wave = "sine", vol = 0.09, release = 0.4, attack = 0.05, pan = 0.2}}
-- The party song, one note per press after the cheer. Major, pentatonic, ours.
local SONG = {72, 76, 79, 76, 81, 79, 76, 72, 74, 76, 79, 84, 81, 79, 76, 79}

local function notes(m, step, vol) sfx.arp("tri", m, step, vol) end

local function wish_of(cat)
  if cat == NIB then
    return st.last_friend == MOTH and "yarn" or st.last_friend == PEARL and "flower" or "cup"
  end
  return cat == MOTH and "yarn" or cat == PEARL and "flower" or "cup"
end

local function purr(up, dur, vol, release, vib)
  sfx.play({wave = "tri", hz = 196 * (up > 0 and 1.5 or 1), dur = dur, vol = vol, attack = 0.05, release = release, duty = 0.5, vib_hz = vib, vib_depth = 0.4})
end

local function tune_for(cat, kind)
  local up = cat == NIB and 7 or 0
  if kind == "cake" then sfx.arp("sine", {79 + up, 76 + up, 84 + up}, 0.08, 0.26) return end
  if kind == "hug" then
    purr(up, 0.6, 0.3, 0.35, 16)
    sfx.arp("sine", {72 + up, 79 + up, 84 + up}, 0.12, 0.22)
    return
  end
  if kind == "cup" then
    purr(up, 0.45, 0.25, 0.3, 18)
    sfx.note("sine", 76 + up, 0.4, 0.3)
  elseif kind == "yarn" then
    notes({79 + up, 84 + up}, 0.09, 0.3)
  else
    local m = cat == NIB and {84 + up, 88 + up} or {84 + up, 88 + up, 91 + up}
    sfx.arp("sine", m, 0.11, 0.28)
  end
end

-- ------------------------------------------------------------------ save

local function load_save()
  st.visits = clamp(save.get("visits", 0), 0, 100000)
  st.photos = clamp(save.get("photos", 0), 0, 100000)
  for i, key in ipairs({"pip", "moth", "pearl", "nib"}) do
    local g = save.get(key, "none")
    st.gift[i] = (g == "teacup" or g == "ribbon" or g == "flower") and g or "none"
  end
end

local function save_tea()
  save.set("visits", st.visits)
  save.set("pip", st.gift[PIP])
  save.set("moth", st.gift[MOTH])
  save.set("pearl", st.gift[PEARL])
  save.set("nib", st.gift[NIB])
  save.set("photos", st.photos)
  save.write()
end

-- ------------------------------------------------------------------ the lines

local function react(s, frames)
  st.react_line, st.react_left = s, frames
end

local function runner()
  for i = 1, st.ncats do if st.gift[i] ~= "none" then return i end end
  return nil
end

local function reunion_line(who)
  if who == MOTH then return "Moth kept a ribbon." end
  if who == PEARL then return "Pearl kept her flower." end
  return "Pip kept a teacup."
end

-- What the focused cat would love now, as a picture.
local function ask_of(who)
  local h = st.hearts[who]
  if h >= 3 then return st.cheered and "note" or "sparkle" end
  if h == 1 then return "cake" end
  if h == 2 then return "hug" end
  return wish_of(who)
end
pics.ask_of = ask_of

local function ask_line(who)
  local k = ask_of(who)
  if who == NIB and k ~= "cake" and k ~= "hug" and st.hearts[who] < 3 then return "Nib copies a friend." end
  if k == "cake" then return NAMES[who] .. " wants a cupcake." end
  if k == "hug" then return NAMES[who] .. " wants a big hug." end
  if k == "yarn" then return "Moth wants the yarn." end
  if k == "flower" then return "Pearl wants a flower." end
  if k == "cup" then return "Pip would love some tea." end
  if k == "note" then return "Play a song for them." end
  return NAMES[who] .. " wants to play."
end

local function care_line(who, kind)
  if kind == "cake" then return NAMES[who] .. " ate the cupcake." end
  if kind == "hug" then return "A big unicorn hug!" end
  if kind == "sparkle" then return NAMES[who] .. " does a little dance." end
  if who == NIB then return "Nib bumped her nose." end
  if kind == "yarn" then return "The yarn rolled back." end
  if kind == "flower" then return "Pearl wears a flower." end
  return "Pip sipped her tea."
end

local TREAT_LINE = {balloon = "A balloon for the party!", cake = "A cupcake for the party!", flower = "Flowers for the party!", star = "A star for the party!"}

local function leaving() return input.down("1p") and input.down("2p") end

local function rest_line()
  if leaving() then return "They will keep the gifts." end
  if st.phase == "sky" then
    if st.hurry then return "The party is waiting." end
    if st.swoop_t > 0 then return "She leans in the clouds." end
    return "She flies to the castle."
  end
  if st.phase == "door" then
    if st.visits == 3 then return "A kitten came to play." end
    local who = runner()
    if who then return reunion_line(who) end
    return "They saved her a seat."
  end
  return ask_line(st.focus)
end

-- ------------------------------------------------------------------ the party's rules

local function seat_x(i) return st.ncats == 4 and 60 + (i - 1) * 88 or 72 + (i - 1) * 120 end
local function head_y(i) return i == st.focus and 236 or 226 end
pics.seat_x, pics.head_y = seat_x, head_y

local function begin_door()
  st.phase, st.door_t = "door", 0
  if st.visits < 100000 then st.visits = st.visits + 1 end
  st.ncats = st.visits >= 3 and 4 or 3
  if st.focus > st.ncats then st.focus = PIP end
  save_tea()
  log("tea arrive " .. st.visits)
  log("tea treats " .. #st.basket)
  music.stop()
  notes({72, 76, 79}, 0.12, 0.3)
  local who = runner()
  if who then tune_for(who, wish_of(who)) end
end

local function all_full()
  for i = 1, st.ncats do if st.hearts[i] < 3 then return false end end
  return true
end

local function play_song_note(who)
  local m = SONG[st.song_i % #SONG + 1]
  sfx.note("tri", m, 0.45, 0.4)
  sfx.note("sine", m - 12, 0.5, 0.15)
  st.song_i = st.song_i + 1
  st.delight[who], st.care_kind[who] = 30, "note"
  particles.spawn(seat_x(who) + rnd(-10, 10), head_y(who) - 40, rnd(-0.6, 0.6), -1.2, 70, 6, hsv(st.song_i * 0.13, 0.5, 1), "star", 0, 0.99)
  if st.song_i % #SONG == 0 then
    for i = 1, 24 do
      particles.spawn(rnd(20, W - 20), rnd(-20, 20), rnd(-0.5, 0.5), rnd(0.6, 1.6), 140, rnd(3, 5), hsv(rnd(), 0.45, 1), i % 2 == 0 and "heart" or "star", 0, 1)
    end
    react("They loved the song!", REACT_FRAMES)
    log("tea song")
  else
    react("La la la!", 40)
  end
end

local function care(who)
  local kind, filled = ask_of(who), false
  if who ~= NIB then st.last_friend = who end
  if st.song_mode then
    play_song_note(who)
    st.care_wait = CARE_GAP // 2
    return
  end
  if (kind == "cup" or kind == "yarn" or kind == "flower") and GIFT_FOR[who] then st.gift[who] = GIFT_FOR[who] end
  if st.hearts[who] < 3 then
    st.hearts[who] = st.hearts[who] + 1
    filled = st.hearts[who] == 3
    st.heart_pop[who] = 18
    if st.hearts[who] == 1 then sfx.note("sine", 96, 0.15, 0.12) end
  end
  st.delight[who], st.care_kind[who] = 50, kind
  st.toss_t, st.toss_who, st.toss_kind = 18, who, kind
  log(fmt("tea heart %s %d", NAMES[who], st.hearts[who]))
  tune_for(who, kind)
  particles.burst(seat_x(who), head_y(who) - 30, 10, 2, 34, 4, alpha(C.ROOF, 230), "heart")
  if kind == "flower" then particles.burst(seat_x(who), head_y(who) - 24, 12, 2.5, 30, 3, 0xff9ac8, "dot") end
  if kind == "cake" then particles.burst(seat_x(who), head_y(who) + 14, 8, 1.5, 24, 2, 0xffe0a0, "square") end
  if all_full() and not st.cheered then
    st.cheered, st.cheer_left = true, CHEER_FRAMES
    react("The whole table glows.", CHEER_FRAMES // 2)
    notes({72, 76, 79, 84}, 0.14, 0.32)
    fx.confetti(40)
    st.photo_t = 1
    save_tea()
    log("tea cheer")
  else
    react(filled and (NAMES[who] .. " is so happy.") or care_line(who, kind), REACT_FRAMES)
    save_tea()
  end
  st.care_wait = CARE_GAP
end

-- ------------------------------------------------------------------ the flight

local function treat_x(t) local k = t.z / 0.85 return W / 2 + t.lane * LANE_X * k * k end
local function treat_y(t) return 165 + 95 * (t.z / 0.85) ^ 1.4 end
pics.treat_x, pics.treat_y = treat_x, treat_y

local KINDS = {"balloon", "cake", "flower", "star"}

local function spawn_treat()
  if #st.treats >= 10 then return end
  local r = rndi(0, 99)
  st.treats[#st.treats + 1] = {on = 1, z = 0.02, lane = r < 50 and 0 or r < 75 and -1 or 1, kind = KINDS[rndi(1, 4)], color = rndi(0, 4)}
end

-- The next treat coming, for the swoop and for the built-in player.
local function next_coming()
  local best
  for _, t in ipairs(st.treats) do
    if t.on == 1 and t.z < 0.8 and (not best or t.z > best.z) then best = t end
  end
  return best
end

local PENT = {72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96}

local function catch_treat(t)
  t.fx, t.fy = treat_x(t), treat_y(t)
  t.on, t.fly_t = 2, 0
  t.slot = min(#st.basket + 1, BASKET_MAX)
  st.got[t.kind] = st.got[t.kind] + 1
  if #st.basket < BASKET_MAX then st.basket[#st.basket + 1] = t.kind end
  local m = PENT[(#st.basket - 1) % 11 + 1]
  sfx.note("tri", m, 0.3, 0.35)
  sfx.note("sine", m + 12, 0.2, 0.12)
  particles.burst(t.fx, t.fy, 14, 2.5, 30, 3, t.kind == "balloon" and pics.balloon_col(t.color) or C.GOLD, "star")
  react(TREAT_LINE[t.kind], 70)
  log("tea treat " .. (({balloon = 0, cake = 1, flower = 2, star = 3})[t.kind]))
end

local function sky_step(held, button)
  local prev = st.lane
  if input.pressed("left") then st.lane = max(-1, st.lane - 1) end
  if input.pressed("right") then st.lane = min(1, st.lane + 1) end
  local swoop = input.pressed("up") or input.pressed("down")
  if swoop then
    -- Up and down swoop to wherever the next treat is coming.
    local t = next_coming()
    st.lane = t and t.lane or 0
  end
  if st.lane ~= prev or swoop then
    st.swoop_t = 40
    sfx.slide("sine", 600, 900, 0.15, 0.12)
  end
  if st.swoop_t > 0 then st.swoop_t = st.swoop_t - 1 end
  if button then
    st.sparkle_t = 50
    snd.sparkle()
    particles.burst(st.uni_x, 250, 10, 2, 30, 3, C.GOLD, "star")
  end
  if st.sparkle_t > 0 then st.sparkle_t = st.sparkle_t - 1 end
  st.uni_lx = approach(st.uni_lx, st.lane * LANE_X, 0.16)
  st.tilt = approach(st.tilt, (st.lane * LANE_X - st.uni_lx) * 0.02, 0.2)
  st.uni_x = W / 2 + st.uni_lx
  local step = held and HURRY_STEP or SKY_STEP
  if game.fast then step = step * 8 // 5 end
  st.fly = min(FLY_DONE, st.fly + step)
  local speed = held and 0.012 or 0.007
  music.tempo(held and 1.4 or 1)
  -- Clouds fly past. Bump a big one and it squishes and giggles.
  for _, c in ipairs(st.clouds) do
    c.z = c.z + speed * (0.4 + c.z)
    if c.squish > 0 then c.squish = c.squish * 0.9 end
    if c.z > 1.25 then c.z, c.a = 0.02, rnd(0, tau) end
    if c.z > 0.75 and c.z < 0.95 and st.bump_cool == 0 then
      local d = c.z * c.z * 340
      local x, y = W / 2 + cos(c.a) * d * 1.2, 140 + sin(c.a) * d * 0.7 + c.z * 60
      if dist(x, y, st.uni_x, 330) < 50 then
        c.squish, st.bump_cool = 1, 40
        sfx.note("sine", 81, 0.12, 0.15)
        sfx.note("sine", 88, 0.08, 0.08)
      end
    end
  end
  -- Treats along the rainbow. The sparkle reaches the next lane too.
  st.next_treat = st.next_treat - 1
  if st.next_treat <= 0 and st.fly < FLY_DONE * 92 // 100 then
    spawn_treat()
    st.next_treat = held and 34 or 52
  end
  for _, t in ipairs(st.treats) do
    if t.on == 2 then
      t.fly_t = t.fly_t + 1
      if t.fly_t >= 26 then t.on = 0 end
    elseif t.on == 1 then
      t.z = t.z + (held and 0.0135 or 0.0085) * (game.fast and 1.4 or 1)
      if t.z > 0.8 and t.z < 0.92 then
        local reach = st.sparkle_t > 0 and 1 or 0
        if abs(t.lane - st.uni_lx / LANE_X) <= 0.5 + reach then catch_treat(t) end
      end
      if t.z > 1.15 then t.on = 0 end
    end
  end
  sweep(st.treats, function(t) return t.on ~= 0 end)
  if st.fly >= FLY_DONE or game.frame >= 1300 then begin_door() end
end

-- ------------------------------------------------------------------ the built-in player (tests, the reel)

function bot()
  if st.phase == "sky" then
    local t = next_coming()
    if t and t.lane ~= st.lane and game.frame % 6 == 0 then input.bot(t.lane < st.lane and "left" or "right") end
    if (game.frame // 50) % 3 == 1 then input.bot("low") end
  elseif st.phase == "party" then
    if game.frame % 24 == 0 then input.bot((st.hearts[st.focus] < 3 or st.song_mode) and "low" or "right") end
  end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.22)
  sfx.limit(3000)
  load_save()
  for i = 1, 12 do st.clouds[i] = {a = rnd(0, tau), z = rnd(), squish = 0} end
  music.play(sky_bed)
end

local function party_step(button, held)
  local l = input.down("left") or input.down("up")
  local r = input.down("right") or input.down("down")
  local prev = input.pressed("left") or input.pressed("up")
  local nxt = input.pressed("right") or input.pressed("down")
  -- A held stick walks on to the next cat about twice a second.
  if l or r then
    st.stick_hold = st.stick_hold + 1
    if st.stick_hold > 30 and st.stick_hold % 30 == 0 then prev, nxt = l and not r, r end
  else
    st.stick_hold = 0
  end
  if prev and not nxt then
    st.focus = (st.focus - 2 + st.ncats) % st.ncats + 1
  elseif nxt then
    st.focus = st.focus % st.ncats + 1
  end
  if prev or nxt then
    sfx.note("sine", 72 + (st.focus - 1) * 4, 0.12, 0.15)
    log("tea focus " .. NAMES[st.focus])
  end
  if button then st.care_from_party = true end
  if not held then st.care_from_party = false end
  if st.care_wait > 0 then st.care_wait = st.care_wait - 1 end
  if st.care_from_party and (button or (held and st.care_wait == 0)) then care(st.focus) end
  if st.cheer_left > 0 then
    st.cheer_left = st.cheer_left - 1
    if st.cheer_left == 0 then
      st.song_mode = true
      react("Play a song for them.", REACT_FRAMES)
    end
  end
  if st.photo_t > 0 then
    st.photo_t = st.photo_t + 1
    if st.photo_t > 80 then
      st.photo_t = 0
      st.photos = st.photos + 1
      save_tea()
      snd.chime()
      log("tea photo " .. st.photos)
    end
  end
  if st.idle_t > 0 then
    st.idle_t = st.idle_t - 1
  elseif game.frame % 130 == 0 then
    st.idle_who = (st.idle_who + rndi(0, st.ncats - 1)) % st.ncats + 1
    if st.idle_who == st.focus then st.idle_who = st.idle_who % st.ncats + 1 end
    st.idle_t = 40
  end
  st.uni_x = approach(st.uni_x, seat_x(st.focus), 0.16)
end

function update()
  local button, held = input.action(), input.action_down()
  st.hurry = held and st.phase == "sky"
  if leaving() and not st.goodbye then
    snd.bye()
    st.goodbye = true
  end
  if st.phase == "sky" then
    sky_step(held, button)
  elseif st.phase == "door" then
    if button then
      sfx.note("sine", 79, 0.1, 0.15)
      particles.burst(W / 2 + 40, 340, 8, 2, 26, 3, C.GOLD, "star")
    end
    st.door_t = st.door_t + 1
    if st.door_t >= (game.fast and DOOR_FRAMES * 5 // 8 or DOOR_FRAMES) then
      st.phase = "party"
      music.play(party_bed)
      music.tempo(1)
      st.uni_x = seat_x(st.focus)
      log("tea party")
    end
  else
    party_step(button, held)
  end
  for i = 1, 4 do
    st.cat_lean[i] = approach(st.cat_lean[i], (i == st.focus and st.phase == "party") and 1 or 0, 0.2)
    if st.delight[i] > 0 then st.delight[i] = st.delight[i] - 1 end
    if st.heart_pop[i] > 0 then st.heart_pop[i] = st.heart_pop[i] - 1 end
  end
  if st.react_left > 0 then st.react_left = st.react_left - 1 end
  if st.toss_t > 0 then st.toss_t = st.toss_t - 1 end
  if st.bump_cool > 0 then st.bump_cool = st.bump_cool - 1 end
  st.wing = sin(game.frame * (held and 0.35 or 0.16)) * 0.7
end

function draw()
  if st.phase == "sky" then pics.draw_sky()
  elseif st.phase == "door" then pics.draw_door()
  else pics.draw_party() end
  particles.draw()
  local line
  if st.react_left > 0 and st.phase ~= "door" and not leaving() then line = st.react_line else line = rest_line() end
  ui.band(line)
end
