-- Keep: catch what falls, one season at a time. Walk-up band (CONTROLS.md).
--
-- Pip, one of the Tea cats, is stocking Starlight Castle's pantry with jam for the Tea party. The stick moves her
-- basket along the bottom of the orchard; a button dashes the way she leans (never needed to catch). Fruit shakes
-- on the branch before it drops, and its shadow grows on the grass where it lands. Catches in a row build a
-- multiplier. Bees (summer on) cost a heart. Three misses end the round.
--
-- A round is a year: Blossom, Summer, Harvest, Snow. Each season has its own orchard (one reused picture,
-- repainted in place), its own special fruit, its own song. Catch enough and a jar of jam is made and goes on the
-- pantry shelf (saved); a year of four jars is the Tea party. The first season is gentle (no bees, slower fruit).
--
-- The music is played by the run: every catch is the next note of the season's tune (music.cue), and layers come
-- in as a streak grows (bass, arp, drums, stabs, the hook, then the chorus); a miss takes one layer away gently.
-- Game logic never reads music.step(): the music is sound only. Chance is the seeded rnd/rndi, never in drawing.
--
-- keep.sav: "best N" (as ever) and, new, all clamped: jar1..jar4 (jars per season), lid1..lid4 (perfect ones,
-- with a ribbon), years (Tea parties held), visits. KEEP_SELFTEST=1 plays until a catch, saves, and quits.

local pics = import("pictures")
local songs = import("songs")
local SEA = pics.SEA

local GROUND, BASKET_W, MAXF = 292, 40, 8
local INK, CREAM, GOLD = 0x2a1630, pal.cream, pal.sun

local fruit = {}             -- {type, x, y, vx, vy, hang, phase, mood, si}
local lives, combo, mult, score, catches
local spawn_in, dash_cd, dash_t, hurt_t, round_frames
local px, vx, lean, squash, facing = W / 2, 0, 0, 0, 1
local dirty = false          -- the pantry changed and is not written yet

-- Everything the pictures read.
local S = {
  season = 1, jp = 0, perfect = true, sp = 0, year = 0,
  jars = {0, 0, 0, 0}, lids = {0, 0, 0, 0}, rjars = {0, 0, 0, 0}, years = 0, visits = 0,
  banner_t = 0, jar_show = 0, jar_perf = false, new_s = 0, new_t = 0,
  phase = "play", party_t = 0, rel = false,
  ml = 0, chorus = false, dip_t = 0,
  face = "", face_t = 0, idle_t = 0, lookx = 0, looky = 0, mood = "",
  title_t = 0, story = false, vase = nil, vase_n = 0,
}
pics.S = S

local PIPO = {mood = "", look_x = 0, look_y = 0, facing = 1, lean = 0, sq = 0, tail_speed = 0.07, season = 1,
              heap = 0, droop = 0, twitch = 0}
local KEYS = {"s1", "s2", "s3", "s4"}
local JAMTXT = {}
for i = 1, 4 do JAMTXT[i] = SEA[i].jam .. "!" end
local BANDS = {"Blossom: Pip picks fruit for the Tea party jam", "Summer: busy bees about, mind the buzz",
               "Harvest: the plums are ripe, fill the jar!", "Snow: Pip's last jar for the Tea party"}
local score_s, best_s, best_n, pantry_s, title_s = "0", "best 0", -1, "", ""

local function level()
  local l = score / 18 + round_frames / 3600
  if S.season == 1 then l = l * 0.8 end   -- the first season is gentle
  return game.fast and l * 1.3 + 0.6 or l
end

-- ------------------------------------------------------------------ the music

local LV = {-1, -1, -1, -1, -1, -1}
local function set_track(i, v)
  if LV[i] ~= v then LV[i] = v music.track(i, v) end
end
-- Tracks: 1 pad, 2 bass, 3 arp, 4 drums, 5 stabs, 6 the hook. A better run, more of them.
local function layers()
  local m = S.ml
  set_track(1, 1)
  set_track(2, m >= 1 and 1 or 0.75)
  set_track(3, m >= 1 and 1 or 0)
  set_track(4, m >= 2 and 1 or 0)
  set_track(5, m >= 3 and 1 or 0)
  set_track(6, m >= 4 and (S.dip_t > 0 and 0.35 or 1) or 0)
end

local function set_ml(v)
  v = clamp(v, 0, 5)
  if v == S.ml then return end
  S.ml = v
  log("keep layer " .. v)
  local want = v >= 5
  if want ~= S.chorus then   -- the verse turns into the chorus, no restart
    S.chorus = want
    music.play(songs.song(S.season, want, true))
  end
  layers()
end

local function play_season()
  S.chorus = S.ml >= 5
  for i = 1, 6 do LV[i] = -1 end
  music.play(songs.song(S.season, S.chorus))
  layers()
end

-- a chord on the beat (sound only: the pitch may follow the song, the game never does)
local function chord(vol)
  local r, q = songs.root(S.season, music.step())
  r = r + 12
  music.cue{note = r, wave = "sine", dur = 0.4, vol = vol, at = "beat"}
  music.cue{note = r + q, wave = "sine", dur = 0.4, vol = vol * 0.8, at = "beat"}
  music.cue{note = r + 7, wave = "sine", dur = 0.4, vol = vol * 0.8, at = "beat"}
end

-- ------------------------------------------------------------------ the pantry (saved)

local function save_pantry()
  if not dirty or arcade.demo then return end
  arcade.save()
  for i = 1, 4 do
    save.set("jar" .. i, S.jars[i])
    save.set("lid" .. i, S.lids[i])
  end
  save.set("years", S.years)
  save.set("visits", S.visits)
  if save.write() then dirty = false else log("keep: the pantry did not save") end
end

local function pantry_line()
  local n = S.jars[1] + S.jars[2] + S.jars[3] + S.jars[4]
  pantry_s = n > 0 and (plural(n, "jar") .. " in Pip's pantry") or ""
  title_s = n > 0 and fmt("best %d    %s", arcade.best, pantry_s) or ""
  return n
end

-- ------------------------------------------------------------------ seasons

local function begin_season(si)
  S.season, S.jp, S.perfect, S.sp = si, 0, true, 0
  S.banner_t = S.jar_show > 0 and 150 or 110
  spawn_in = max(spawn_in, S.jar_show > 0 and 80 or 40)
  play_season()
  log("keep season " .. si)
end

local function finish_season()
  local s = S.season
  if not arcade.demo then
    S.jars[s] = min(S.jars[s] + 1, 999)
    if S.perfect then S.lids[s] = min(S.lids[s] + 1, S.jars[s]) end
    S.new_s, S.new_t = s, 90
    dirty = true
  end
  S.rjars[s] = S.rjars[s] + 1
  S.jar_show, S.jar_perf = s, S.perfect
  log(fmt("keep jar %d %d", s, S.jars[s]))
  gfx.flash(alpha(SEA[s].tint, 120), 12)
  sfx.arp("sine", {84, 88, 91, 96}, 0.06, 0.3)
  particles.burst(px, GROUND - 24, 24, 3, 40, 2.5, SEA[s].tint, "star")
  S.face, S.face_t = "cheer", 90
  if s == 4 then
    S.years = min(S.years + (arcade.demo and 0 or 1), 999)
    S.year = S.year + 1
    S.phase, S.party_t, S.rel = "party", 0, false
    dirty = dirty or not arcade.demo
    lives = 3
    log("keep party " .. S.year)
    music.play(songs.party())
    for i = 1, 6 do LV[i] = -1 end
    save_pantry()
  else
    if lives < 3 then lives = lives + 1 end   -- a breather between seasons
    begin_season(s + 1)
    save_pantry()
  end
end

local function end_party()
  S.phase = "play"
  S.banner_t = 0
  begin_season(1)
  S.jar_show = 0
  S.banner_t = 110
end

local function new_round()
  fruit = {}
  score, lives, combo, mult, catches = 0, 3, 0, 1, 0
  spawn_in, px, vx = 30, W / 2, 0
  dash_cd, dash_t, hurt_t, round_frames = 0, 0, 0, 0
  S.phase, S.year, S.ml, S.chorus, S.dip_t = "play", 0, 0, false, 0
  S.face, S.face_t, S.idle_t, S.jar_show = "", 0, 0, 0
  for i = 1, 4 do S.rjars[i] = 0 end
  score_s = "0"
  particles.clear()
  music.volume(1)
  begin_season(1)
end

local function end_round()
  sfx.arp("tri", {67, 64, 60, 55}, 0.12, 0.4)
  music.volume(0.35)
  S.banner_t, S.face, S.face_t = 0, "sulk", 99999
  pantry_line()
  arcade.over()
  log(fmt("keep over %d best %d", score, arcade.best))
  save_pantry()
end

-- ------------------------------------------------------------------ fruit

local function spawn()
  if #fruit >= MAXF then return end
  local r, l = rndi(0, 99), level()
  local f = {vx = 0, vy = 0, phase = rnd() * tau, mood = 0, si = S.season}
  local sea = S.season
  if sea >= 2 and score >= 10 and r < floor(8 + l * 4) and r < 24 then
    f.type = "bee"
    local bm = rndi(1, 2)   -- each season's bees have their own ways
    f.mood = sea == 2 and (bm == 1 and 1 or 3) or sea == 3 and (bm == 1 and 2 or 3) or 4
  elseif r > 94 then f.type = "gold"
  elseif r >= 86 then f.type = "special"
  elseif r > 70 then f.type = "pear"
  else f.type = "apple" end
  f.x = pics.TREE_X[rndi(1, 10)]
  f.y = 48 + rnd(0, 10)
  f.hang = f.type == "bee" and 20 or floor(46 - clamp(l * 6, 0, 22)) + (sea == 1 and 8 or 0)
  if f.type == "bee" then
    f.y = 40
    f.vx = rnd() < 0.5 and -1 or 1
    if f.mood == 1 then f.vx = f.vx * 0.6 end   -- a dozy bee drifts
  end
  fruit[#fruit + 1] = f
end

local FRUITCOL = {apple = 0xff5a4a, pear = 0xc8e05a, gold = GOLD}

local function catch(f)
  local t = f.type
  local pts = t == "gold" and 5 or t == "special" and 3 or t == "pear" and 2 or 1
  local c = t == "special" and SEA[f.si].col or FRUITCOL[t]
  combo, catches = combo + 1, catches + 1
  mult = min(5, 1 + idiv(combo, 6))
  score = score + pts * mult
  score_s = tostring(score)
  S.idle_t = 0
  S.jp = S.jp + ((t == "gold" or t == "special") and 2 or 1)
  if arcade.score(score) then
    sfx.arp("square", {72, 76, 79, 84}, 0.07, 0.25)
    particles.text(W / 2, 110, GOLD, "NEW BEST")
  end
  -- the catch run is a melody: the next note of the season's tune, on the grid
  local wave, vol = songs.tune_wave(S.season)
  music.cue{note = songs.tune_note(S.season, combo), wave = wave, dur = 0.32, vol = vol, release = 0.25}
  if t == "gold" or t == "special" then
    chord(0.14)
    gfx.flash(alpha(t == "gold" and 0xfff0b0 or SEA[f.si].tint, 90), 10)
    S.face, S.face_t = "cheer", 40
    if t == "special" then
      S.sp = S.sp + 1
      log("keep special " .. f.si)
    end
  else
    S.face, S.face_t = "happy", 18
  end
  squash = 1
  particles.text(f.x, GROUND - 46, c, mult > 1 and fmt("+%dx%d", pts, mult) or "+" .. pts)
  particles.burst(f.x, GROUND - 26, 10 + pts * 3, 2.4, 30, 2, c, (t == "gold" or t == "special") and "star" or "dot")
  if combo % 6 == 0 then
    particles.burst(px, GROUND - 20, 18, 3, 40, 2.5, GOLD, "star")
    sfx.slide("square", 600, 1200, 0.2, 0.18)
    chord(0.12)
    S.face, S.face_t = "cheer", 50
  end
  if combo % 3 == 0 then set_ml(S.ml + 1) end
  log("keep catch " .. score)
  if S.jp >= SEA[S.season].quota then finish_season() end
end

local function lose_life(x, bee)
  lives, combo, mult, hurt_t = lives - 1, 0, 1, 40
  S.perfect = false
  gfx.shake(5)
  snd.bump()
  particles.burst(x, bee and GROUND - 24 or GROUND, 16, 2.2, 34, 2.2, bee and 0xffd84a or 0xd23a3a, "dot")
  S.face, S.face_t = "ouch", 40
  log("keep miss lives " .. lives)
  if lives <= 0 then
    end_round()
    return
  end
  -- gently: one layer of the music goes, the hook dips a moment
  S.dip_t = 90
  set_ml(S.ml - 1)
  layers()
end

-- ------------------------------------------------------------------ the built-in player

function bot()
  if arcade.state ~= "play" then
    if (arcade.state == "title" and game.frame % 40 == 5) or (arcade.state == "over" and arcade.t > 60 and arcade.t % 30 == 0) then
      input.bot("low")
    end
    return
  end
  local target, best_t = nil, 1e9
  for _, f in ipairs(fruit) do
    if f.type ~= "bee" then
      local t = f.hang + (f.vy > 0 and (GROUND - 30 - f.y) / (f.vy + 1) or 60)
      if t < best_t then best_t, target = t, f end
    end
  end
  if target then
    local dx = target.x - px
    for _, b in ipairs(fruit) do
      if b.type == "bee" and abs(b.x - target.x) < 26 and b.y > 150 then
        dx = target.x + (b.x < target.x and 30 or -30) - px
      end
    end
    if dx < -4 then input.bot("left") elseif dx > 4 then input.bot("right") end
    if abs(dx) > 80 and best_t < 50 and dash_cd == 0 and game.frame % 2 == 1 then input.bot("low") end
  end
end

-- ------------------------------------------------------------------ the rules

local function party_tick()
  S.party_t = S.party_t + 1
  if S.party_t == 1 then
    for k = #fruit, 1, -1 do fruit[k] = nil end
    particles.clear()
    sfx.arp("square", {72, 76, 79, 84, 88, 91}, 0.08, 0.2)
  end
  if S.party_t % 22 == 3 then
    local bx = 30 + (S.party_t * 53) % 180
    particles.burst(bx, 120 + (S.party_t * 7) % 60, 16, 2.6, 46, 2.4, pics.PARTYCOL[(idiv(S.party_t, 22)) % 4 + 1], "star")
    gfx.flash(alpha(0xfff0c0, 40), 4)
  end
  if not input.action_down() then S.rel = true end
  if S.party_t > 330 or (S.party_t > 100 and S.rel and input.action()) then end_party() end
end

local function play()
  if S.phase == "party" then
    party_tick()
    return
  end
  local dir = input.dir()
  local maxv = game.fast and 4.2 or 3.4
  round_frames = round_frames + 1
  if dir ~= 0 then facing = dir end
  if dir ~= 0 or input.action() then S.idle_t = 0 else S.idle_t = S.idle_t + 1 end
  if input.action() and dash_cd == 0 then
    vx = facing * (game.fast and 9 or 8)
    dash_t, dash_cd = 9, 22
    snd.whoosh()
    particles.burst(px, GROUND - 2, 8, 1.5, 20, 2, alpha(0xe8f0c0, 200), "dot")
  end
  if dash_t > 0 then
    dash_t = dash_t - 1
  else
    vx = vx + dir * 0.9
    if dir == 0 then vx = vx * 0.72 end
    vx = clamp(vx, -maxv, maxv)
  end
  if dash_cd > 0 then dash_cd = dash_cd - 1 end
  px = px + vx
  if px < BASKET_W / 2 + 2 then px, vx = BASKET_W / 2 + 2, 0 end
  if px > W - BASKET_W / 2 - 2 then px, vx = W - BASKET_W / 2 - 2, 0 end
  lean = approach(lean, clamp(vx / 3, -1, 1), 0.3)
  squash = squash * 0.82
  if hurt_t > 0 then hurt_t = hurt_t - 1 end
  if S.dip_t > 0 then
    S.dip_t = S.dip_t - 1
    if S.dip_t == 0 then layers() end
  end
  if S.banner_t > 0 then S.banner_t = S.banner_t - 1 end
  if S.new_t > 0 then S.new_t = S.new_t - 1 end
  spawn_in = spawn_in - 1
  if spawn_in <= 0 then
    if #fruit < 1 + floor(clamp(level(), 0, 3)) then spawn() end
    spawn_in = floor(clamp(70 - level() * 12, 26, 70)) + rndi(0, 14)
  end
  local g = 0.06 + clamp(level() * 0.012, 0, 0.06)
  local rim = GROUND - 22
  local i = 1
  local look_t, tx, ty = 1e9, px, GROUND - 80
  local bee_near = false
  while i <= #fruit do
    local f, gone = fruit[i], false
    if f.type ~= "bee" then
      local pr = f.hang * 4 + (GROUND - f.y)
      if pr < look_t then look_t, tx, ty = pr, f.x, f.y end
    end
    if f.hang > 0 then
      f.hang = f.hang - 1
      if f.hang == 0 then
        if f.type == "bee" then
          if f.mood == 2 then sfx.slide("saw", 220, 150, 0.12, 0.05)
          elseif f.mood == 1 then sfx.slide("sine", 500, 360, 0.2, 0.05)
          else sfx.tone("sine", 1100, 0.05, 0.06) end
        else
          sfx.tone("sine", 900, 0.04, 0.08)
        end
      end
    else
      if f.type == "bee" then
        f.vy = 1.1 + level() * 0.1
        f.x = f.x + f.vx * 1.2
        if f.x < 12 or f.x > W - 12 then f.vx = -f.vx end
        f.y = f.y + f.vy
        if f.y > 150 and f.y < GROUND - 26 and abs(f.x - px) < 44 then bee_near = true end
      else
        f.vy = clamp(f.vy + g, 0, game.fast and 6 or 5)
        f.y = f.y + f.vy
      end
      if f.y >= rim - 6 and f.y <= rim + 8 and abs(f.x - px) < BASKET_W / 2 + 4 then
        gone = true
        if f.type == "bee" then
          log("keep sting")
          lose_life(f.x, true)
        else
          catch(f)
        end
      elseif f.y > GROUND then
        gone = true
        if f.type ~= "bee" then
          local near = abs(f.x - px) < BASKET_W / 2 + 24
          lose_life(f.x, false)
          if near and arcade.state == "play" then   -- so close: Pip gasps
            S.face, S.face_t = "oh", 40
            log("keep near")
          end
        elseif abs(f.x - px) < BASKET_W / 2 + 22 then   -- a bee buzzed past her
          S.face, S.face_t = "oh", 36
          local txt = f.mood == 1 and "zzz" or f.mood == 2 and "grr!" or f.mood == 3 and "hi!" or "brr"
          particles.text(f.x, GROUND - 34, 0xffe070, txt)
          log("keep whew")
        end
      end
    end
    if gone then table.remove(fruit, i) else i = i + 1 end
    if arcade.state ~= "play" or S.phase == "party" then return end
  end
  if bee_near and S.face_t < 4 then S.face, S.face_t = "oh", 4 end
  S.lookx = approach(S.lookx, clamp((tx - px) * 0.06, -1.8, 1.8), 0.2)
  S.looky = approach(S.looky, clamp((ty - (GROUND - 80)) * 0.02, -1.4, 1), 0.2)
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.42)
  sfx.limit(8000)
  for i = 1, 4 do
    S.jars[i] = clamp(save.get("jar" .. i, 0), 0, 999)
    S.lids[i] = clamp(save.get("lid" .. i, 0), 0, S.jars[i])
  end
  S.years = clamp(save.get("years", 0), 0, 999)
  S.visits = clamp(save.get("visits", 0), 0, 100000) + 1
  -- Garden's last bouquet stands in a vase on the table, if she has grown one
  local w = save.peek("garden", "bouquet", "")
  local VASE = {rose = 0xe86b9a, gold = 0xf2c14e, sky = 0x8ac8ff, lilac = 0xb9a0e8, mint = 0x7ec8c3, coral = 0xff8a7a}
  if type(w) == "string" and #w <= 32 then
    local n = 0
    local v = {}
    for tok in w:gmatch("[a-z]+") do
      if VASE[tok] and n < 4 then n = n + 1 v[n] = VASE[tok] end
    end
    if n > 0 then S.vase, S.vase_n = v, n end
  end
  arcade.setup({key = "best", start = new_round, title = function()
    S.title_t = 420
    music.play(songs.title())
  end})
  new_round()
  pantry_line()
  S.story = S.visits <= 1 and arcade.best == 0 and pantry_line() == 0
  S.title_t = S.story and 0 or 420
  music.play(songs.title())
  if S.story then music.track(1, 0) music.track(4, 0) end
  log(S.story and "keep story new" or "keep story back")
  if game.selftest then game.autoplay = true end
end

-- Leaving (1P+2P): keep the jars and the best found so far.
function quit()
  save_pantry()
end

function update()
  local st = arcade.update()
  if st == "play" then
    play()
  elseif st == "title" then
    S.title_t = S.title_t + 1
    if S.story then   -- the music joins in as the story goes
      if S.title_t == 110 then music.track(1, 1) end
      if S.title_t == 300 then music.track(4, 1) end
    end
  end
  -- Pip's face this frame
  local m = ""
  if S.face_t > 0 then
    S.face_t = S.face_t - 1
    m = S.face
  elseif st == "play" and S.phase == "play" then
    if S.idle_t > 700 then m = "asleep"
    elseif S.idle_t > 420 then m = "sleepy"
    elseif S.idle_t > 300 and S.idle_t % 150 < 40 then m = "yawn" end
  end
  S.mood = m
  if game.selftest then
    if catches >= 1 and game.frame > 8 then
      save.set("best", arcade.best)
      assert(save.write() and save.get("best") == arcade.best, "keep self-test: the save did not stick")
      arcade.saved = arcade.best
      game.quit()
    elseif game.frame > 900 then
      error("keep self-test: no catch in 900 frames")
    end
  end
end

-- ------------------------------------------------------------------ pictures

local function draw_pip()
  local x, y = px, GROUND - 4
  local sq = squash * 0.25
  local bw, bh = BASKET_W * (1 + sq), 18 * (1 - sq * 0.8)
  if hurt_t > 0 and idiv(hurt_t, 4) % 2 == 1 then return end
  if dash_t > 0 then
    for k = 1, 3 do gfx.rrect(x - bw / 2 - vx * k * 2, y - bh, bw, bh, 5, alpha(0xffffff, 60 - k * 15)) end
  end
  gfx.ellipse(x, GROUND + 2, bw * 0.55, 4, alpha(0x1a3a20, 120))
  local o = PIPO
  o.mood, o.look_x, o.look_y = S.mood, S.lookx, S.looky
  o.facing, o.lean, o.sq, o.season = facing, lean, sq, S.season
  o.tail_speed = 0.07 + min(combo, 18) * 0.012
  o.heap = min(3, idiv(S.jp * 4, SEA[S.season].quota))
  o.droop = (lives == 1 or S.mood == "sulk" or S.mood == "ouch") and 0.8 or 0
  o.twitch = (game.frame % 260 < 16) and max(0, sin(game.frame * 0.9)) or 0
  pics.pip(x, y, bw, bh, o)
  if S.mood == "asleep" then
    local zt = game.frame % 60
    gfx.text("z", x + 18, y - 52 - zt * 0.2, 12, alpha(0xffffff, floor(255 - zt * 3.5)), "center", INK)
  end
  if mult > 1 then
    gfx.rrect(x + bw / 2 - 2, y - bh - 15, 20, 13, 5, GOLD)
    gfx.text("x" .. mult, x + bw / 2 + 8, y - bh - 15, 11, INK, "center")
  end
end

local function draw_hud()
  hearts(lives, 3, 29, 82, 4.3)
  gfx.text(SEA[S.season].name, 8, 92, 11, CREAM, "left", INK)
  gfx.text(score_s, W / 2, 66, 28, CREAM, "center", INK)
  if arcade.best ~= best_n then best_n = arcade.best best_s = "best " .. best_n end
  gfx.text(best_s, W - 5, 76, 12, GOLD, "right", INK)
  -- the jar that is filling: when it is full, the season is done
  local sea = SEA[S.season]
  local k = clamp(S.jp / sea.quota, 0, 1)
  pics.jar(W - 17, 118, 16, 24, sea.jar, k, false, 0)
end

local function draw_banner()
  local b = S.banner_t
  if b <= 0 or arcade.state ~= "play" then return end
  if S.jar_show > 0 and b > 70 then
    local k = ease.out_back(clamp((150 - b) / 25, 0, 1))
    pics.jar(W / 2, 192, 34 * k, 48 * k, SEA[S.jar_show].jar, 1, S.jar_perf, 1)
    gfx.text(JAMTXT[S.jar_show], W / 2, 106, 22, GOLD, "center", INK)
    if S.jar_perf then gfx.text("perfect season", W / 2, 130, 12, CREAM, "center", INK) end
  else
    local a = clamp(b / 30, 0, 1)
    gfx.text(SEA[S.season].name, W / 2, 104, 30, alpha(SEA[S.season].tint, floor(255 * a)), "center", alpha(INK, floor(255 * a)))
  end
  ui.band(BANDS[S.season])
end

local function draw_title()
  pics.scene("kitchen")
  pics.kitchen("title")
  if blink(60, 30) then gfx.text("press to start", W / 2, 276, 16, CREAM, "center", INK) end
  local t = S.title_t
  local line
  if S.story and t < 400 then
    line = t < 110 and "Tea party tonight, and the pantry is bare." or t < 300 and "Pip fetches fruit from the orchard." or "Catch the fruit. Fill every jar!"
  else
    line = title_s ~= "" and title_s or "Catch the fruit. Fill every jar!"
  end
  ui.band(line)
end

function draw()
  local st = arcade.state
  if st == "title" then
    draw_title()
    arcade.draw_demo(52)
    return
  end
  if S.phase == "party" and st == "play" then
    pics.scene("kitchen")
    pics.kitchen("party")
    particles.draw()
    ui.band("Pip's jam saved the Tea party!")
    return
  end
  pics.scene(KEYS[S.season])
  pics.weather(S.season)
  for _, f in ipairs(fruit) do
    if f.type ~= "bee" then
      -- Where it will land: a shadow that sharpens as it falls.
      local k = clamp((f.y - 40) / (GROUND - 60), 0, 1)
      gfx.ellipse(f.x, GROUND + 1, 4 + k * 5, 2 + k, alpha(0x1a3a20, 60 + floor(k * 100)))
    end
  end
  draw_pip()
  for _, f in ipairs(fruit) do
    local wob = 0
    if f.hang > 0 then wob = sin(game.frame * 0.9 + f.phase) * (f.hang < 20 and 2 or 1) end
    pics.fruit(f, f.x + (f.hang > 0 and wob or 0), f.y, wob, px)
  end
  particles.draw()
  draw_hud()
  if st == "over" then
    arcade.draw_over("the basket's full", score)
    local n = S.rjars[1] + S.rjars[2] + S.rjars[3] + S.rjars[4]
    if n > 0 then
      local x0 = W / 2 - (min(n, 6) - 1) * 10
      local c = 0
      for s = 1, 4 do
        for _ = 1, S.rjars[s] do
          c = c + 1
          if c <= 6 then pics.jar(x0 + (c - 1) * 20, 252, 14, 20, SEA[s].jar, 1, false, 0) end
        end
      end
      gfx.text("jam for the pantry", W / 2, 256, 12, CREAM, "center", INK)
    end
    if arcade.t > 50 and pantry_s ~= "" then gfx.text(pantry_s, W / 2, 274, 11, alpha(CREAM, 220), "center", INK) end
  end
  draw_banner()
  arcade.draw_demo(100)
  if S.banner_t <= 0 or arcade.state ~= "play" then ui.quit_hint() end
end
