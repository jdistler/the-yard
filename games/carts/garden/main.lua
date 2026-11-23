-- Garden: the Fairy Garden sings what she grows. Little band (CONTROLS.md, CASTLE.md): any stick direction
-- moves the fairy ring between the six beds, any right-hand button does the care, and nothing can be lost.
-- The design is DESIGN.md beside this file.
--
-- A turn: plant a seed (the fairy's pouch shows its colour), water it, give it sun, sing to it: seed,
-- sprout, bud, bloom, each with a picture of what it wants next. Every bloomed bed is an instrument: its
-- note joins the garden's arpeggio, so the tune she hears is her garden. When all six bloom the sky goes to
-- evening, fireflies come, drums and bass join, the fairy ties a bouquet, and morning comes for the next
-- player. garden.sav keeps blooms, parades (evenings), gardens (finished), bouquet (one word of colours).
--
-- Rules for the code: game logic counts game.frame and never reads music.step(); the step is only used to
-- draw (flowers bounce on their notes) and to pick the pitch of a music.cue. Chance is only the seeded rnd,
-- only in init.

local pics = import("pictures")
local songs = import("songs")
local C = pics.C
local COLS, CNAME, KNAME, UNLOCK = pics.COLS, pics.CNAME, pics.KNAME, pics.UNLOCK
local BEDX, BEDY = pics.BEDX, pics.BEDY
local ARPBED, DRUMTOK, BEDNOTE = songs.ARPBED, songs.DRUMTOK, songs.BEDNOTE

local NB = 6
local PRE_FRAMES, EVE_FRAMES, BQ_FRAMES = 90, 480, 330
local IDLE_FIRE, GROW = 300, 34
local WANT = {[0] = "seed", "drop", "sun", "note", "note"}
local LINES = {[0] = "Press to plant a seed!", "Press to water it!", "Press for sunshine!",
  "Press to sing to it!", "Press to play the flower!"}
local PIPX, PIPY, MOTHX, MOTHY, PEARLX, PEARLY = 128, 172, 258, 176, 338, 152

local S = {
  phase = "grow", pt = 0, sel = 1, planted = 0, nbloom = 0, idle = 0,
  stage = {0, 0, 0, 0, 0, 0}, kind = {1, 1, 1, 1, 1, 1}, ci = {1, 1, 1, 1, 1, 1},
  grow = {999, 999, 999, 999, 999, 999}, pulse = {999, 999, 999, 999, 999, 999}, scat = {0, 0, 0, 0, 0, 0},
  mask = {false, false, false, false, false, false}, bord = {0, 0, 0, 0, 0, 0},
  bkind = {1, 1, 1, 1}, bci = {1, 1, 1, 1}, bword = "", vase = {0, 0, 0, 0},
  blooms = 0, parades = 0, gardens = 0, nunl = 1, newk = 0,
  rain_t = 0, rain_bed = 1, sun_t = 0, sun_bed = 1, song_t = 0, song_bed = 1, water = 0, glad = 0,
  rare = 0, rainbow = false, fly = 0, eve_t = 0, bq_t = 0, morn_t = 0,
  fx = 80, fy = 250, fdir = 1,
  nst = 0, ntm = 120, nx = -40, ny = 330, nb = 1, ndir = 1,
  lb = 0, lx = 0, ly = 0, lt = 0, lmv = false, snx = -40,
  move_cool = 0, act_cool = 0, saw_release = false, goodbye = false,
  react = "", react_left = 0,
}
-- Drawing's memory of the music: when each bed's note last sounded, and the drums.
local B = {pos = 0, f = 0, beat = -999, bf = {-999, -999, -999, -999, -999, -999}, K = -999, S = -999, H = -999}
local bg_key

local function react_to(s) S.react, S.react_left = s, 110 end

-- ------------------------------------------------------------------ saving

local function save_all()
  save.set("blooms", S.blooms)
  save.set("parades", S.parades)
  save.set("gardens", S.gardens)
  if S.bword ~= "" then save.set("bouquet", S.bword) end
  save.write()
end

local function unlocked_count(g)
  local n = 0
  for k = 1, 6 do if UNLOCK[k] <= g then n = n + 1 end end
  return n
end

-- ------------------------------------------------------------------ music

local function bloom_mask()
  for i = 1, NB do S.mask[i] = S.stage[i] == 4 end
end

-- The arpeggio is rebuilt from the bloomed beds and swung in without a restart.
local function rebuild_song()
  bloom_mask()
  music.play(songs.song(S.mask, true))
end

local function cue(i, off, dur, vol, wave)
  music.cue{wave = wave or "tri", note = BEDNOTE[i] + off, dur = dur, vol = vol, release = dur * 0.9}
end

-- ------------------------------------------------------------------ the garden

local function seed_kind(n) return (n + S.gardens) % S.nunl + 1 end
local function seed_col(n) return (S.gardens + n) % 6 + 1 end

local function hop_to_unfinished()
  for k = 1, NB do
    local j = (S.sel + k - 1) % NB + 1
    if S.stage[j] < 4 then S.sel = j return end
  end
end

local function begin_evening()
  S.phase, S.eve_t, S.fly = "evening", EVE_FRAMES, 4
  S.parades = min(S.parades + 1, 100000)
  log("garden evening")
  log("garden parade " .. S.parades)
  music.track(5, 1)
  music.track(6, 1)
  music.track(2, 0.8)
  sfx.arp("tri", {72, 76, 79, 84, 88, 91, 96}, 0.08, 0.3)
  sfx.arp("sine", {60, 67, 72}, 0.14, 0.2)
  gfx.flash(0xffc890, 36)
  particles.burst(W / 2, 200, 24, 3, 50, 3.5, C.GOLD, "star")
  if S.rare == 1 then log("garden visitor hedgehog") end
  react_to("Evening! The fireflies come!")
  save_all()
end

local function begin_bouquet()
  S.phase, S.bq_t = "bouquet", BQ_FRAMES
  for k = 1, 4 do
    local b = S.bord[k]
    S.bkind[k], S.bci[k] = S.kind[b], S.ci[b]
    S.vase[k] = S.ci[b]
  end
  S.bword = CNAME[S.bci[1]] .. "-" .. CNAME[S.bci[2]] .. "-" .. CNAME[S.bci[3]] .. "-" .. CNAME[S.bci[4]]
  local old = S.nunl
  S.gardens = min(S.gardens + 1, 1000)
  S.nunl = unlocked_count(S.gardens)
  S.newk = S.nunl > old and S.nunl or 0
  log("garden bouquet " .. S.bword)
  log("garden gardens " .. S.gardens)
  if S.newk > 0 then log("garden unlock " .. KNAME[S.newk]) end
  save_all()
  sfx.arp("tri", {79, 84, 88, 91, 96}, 0.09, 0.3)
  for i = 1, 30 do
    local h = pics.hash(i)
    particles.spawn(W / 2 + (h - 0.5) * 300, 150 + pics.hash(i + 40) * 40, (pics.hash(i + 80) - 0.5) * 5,
      -4.5 * pics.hash(i + 120) - 1, 80, 3 + pics.hash(i + 7) * 2, COLS[i % 6 + 1], i % 2 == 0 and "heart" or "star", 0.1, 0.99, 0.1)
  end
  react_to(S.newk > 0 and "A new seed packet for next time!" or "A bouquet for you!")
end

-- Morning: the beds rest, the garden is bare, the next player starts from a fresh seed.
local function new_day()
  S.phase = "grow"
  for i = 1, NB do
    S.stage[i], S.grow[i], S.pulse[i], S.scat[i] = 0, 999, 999, 0
  end
  S.planted, S.nbloom, S.water, S.fly, S.sel, S.idle = 0, 0, 0, 0, 1, 0
  S.rainbow, S.newk = false, 0
  S.nst, S.ntm, S.nx, S.lb, S.lmv = 0, 200, -40, 0, false
  music.track(5, 0)
  music.track(6, 0)
  music.track(2, 1)
  rebuild_song()
  gfx.flash(0xfff6d0, 30)
  log("garden morning")
  react_to("Good morning, garden!")
end

local function bloom(i, auto)
  S.stage[i], S.grow[i] = 4, 0
  S.nbloom = S.nbloom + 1
  S.bord[S.nbloom] = i
  S.blooms = min(S.blooms + 1, 100000)
  log("garden bloom " .. i .. " " .. CNAME[S.ci[i]])
  rebuild_song()
  cue(i, 0, 0.7, 0.28)
  sfx.arp("tri", {BEDNOTE[i], songs.up(BEDNOTE[i]), songs.up(songs.up(BEDNOTE[i])), 84, 88}, 0.07, 0.24)
  particles.burst(BEDX[i], BEDY[i] - 54, 22, 2.8, 38, 3.5, COLS[S.ci[i]], "heart")
  particles.burst(BEDX[i], BEDY[i] - 54, 10, 2, 30, 3, C.GOLD, "star")
  react_to(auto and "The fairy made a flower!" or ("A " .. CNAME[S.ci[i]] .. " flower bloomed!"))
  if S.nbloom >= NB then
    S.phase, S.pt = "pre", PRE_FRAMES
  else
    hop_to_unfinished()
  end
  save_all()
end

-- The one verb: give the bed what it wants. Each stage has its own picture, sound and log line.
local function tend(i, auto)
  local st = S.stage[i]
  local x, y = BEDX[i], BEDY[i]
  S.glad = 50
  S.idle = 0
  if st == 0 then
    S.kind[i], S.ci[i] = seed_kind(S.planted), seed_col(S.planted)
    S.planted = S.planted + 1
    S.stage[i], S.grow[i] = 1, 0
    log("garden seed " .. i .. " " .. CNAME[S.ci[i]])
    cue(i, -12, 0.3, 0.24)
    sfx.noise(0.12, 0.05, 2500)
    particles.burst(x, y - 2, 12, 2, 26, 2.8, COLS[S.ci[i]], "star")
    react_to(auto and "The fairy planted a seed!" or "A seed! Press to water it!")
  elseif st == 1 then
    S.stage[i], S.grow[i] = 2, 0
    S.rain_t, S.rain_bed = 50, i
    S.water = S.water + 1
    log("garden water " .. i)
    cue(i, 0, 0.35, 0.22)
    sfx.noise(0.5, 0.05, 7000)
    sfx.arp("sine", {BEDNOTE[i], songs.up(BEDNOTE[i]), songs.up(songs.up(BEDNOTE[i]))}, 0.07, 0.14)
    particles.burst(x, y - 14, 14, 2, 28, 2.5, C.DROP, "dot")
    if S.rare == 2 and S.water >= 3 and not S.rainbow then
      S.rainbow = true
      log("garden visitor rainbow")
      react_to("A rainbow came out!")
    else
      react_to(auto and "The fairy sprinkled it!" or "A little sprout! Press for sunshine!")
    end
  elseif st == 2 then
    S.stage[i], S.grow[i] = 3, 0
    S.sun_t, S.sun_bed = 50, i
    log("garden sun " .. i)
    cue(i, 0, 0.4, 0.22, "sine")
    sfx.arp("sine", {songs.up(BEDNOTE[i]), 84, 88}, 0.08, 0.14)
    particles.burst(x, y - 30, 14, 2.2, 28, 3, C.SUN, "star")
    react_to("A bud! Press to sing to it!")
  elseif st == 3 then
    S.song_t, S.song_bed = 60, i
    sfx.arp("tri", {BEDNOTE[i] - 12, BEDNOTE[i], songs.up(BEDNOTE[i])}, 0.1, 0.2)
    log("garden song " .. i)
    bloom(i, auto)
  else
    S.pulse[i], S.scat[i] = 0, 80
    cue(i, 0, 0.5, 0.26)
    cue(i, 12, 0.3, 0.07, "sine")
    particles.burst(x, y - 56, 10, 2.2, 28, 3, COLS[S.ci[i]], "star")
    particles.spawn(x, y - 80, 0, -1.4, 50, 4, C.ROOF, "heart", -0.01)
  end
end

-- Doing nothing is still play: now and then the fairy sprinkles on her own.
local function auto_tend()
  if S.stage[S.sel] == 4 then hop_to_unfinished() end
  if S.stage[S.sel] < 4 then tend(S.sel, true) end
end

-- ------------------------------------------------------------------ visitors (rules only; drawing is below)

local function next_bloomed(from)
  for k = 1, NB do
    local j = (from + k - 1) % NB + 1
    if S.stage[j] == 4 then return j end
  end
  return 0
end

local function nib_spot(b)
  local col = (b - 1) % 3
  return BEDX[b] + (col < 2 and 54 or -54), BEDY[b] + 26
end

local function visitors()
  -- Nib wanders in once two flowers have bloomed, sniffs one, and moves on to the next.
  if S.nst == 0 then
    if S.nbloom >= 2 then
      S.ntm = S.ntm - 1
      if S.ntm <= 0 then
        S.nb = next_bloomed(S.nb)
        local tx, ty = nib_spot(S.nb)
        S.nx, S.ny, S.nst = -40, ty, 1
        log("garden visitor nib")
      end
    end
  elseif S.nst == 1 then
    local tx, ty = nib_spot(S.nb)
    S.ndir = tx >= S.nx and 1 or -1
    S.nx = step_to(S.nx, tx, 1.2)
    S.ny = step_to(S.ny, ty, 1.2)
    if S.nx == tx and S.ny == ty then
      S.nst, S.ntm = 2, 150
      S.pulse[S.nb], S.scat[S.nb] = 0, 60
      log("garden nib sniff " .. S.nb)
      particles.spawn(S.nx, S.ny - 30, 0, -1, 44, 4, C.ROOF, "heart", -0.01)
    end
  else
    S.ntm = S.ntm - 1
    if S.ntm == 70 then particles.spawn(S.nx, S.ny - 30, 0, -1, 44, 4, C.ROOF, "heart", -0.01) end
    if S.ntm <= 0 then
      local j = next_bloomed(S.nb)
      if j ~= 0 and j ~= S.nb then S.nb, S.nst = j, 1 else S.ntm = 150 end
    end
  end
  -- The ladybug rests on a flower, then flies to the next.
  if S.nbloom >= 2 and S.lb == 0 then
    S.lb = S.bord[1]
    S.lx, S.ly, S.lt = BEDX[S.lb] + 14, BEDY[S.lb] - 56, 240
    log("garden visitor ladybug")
  elseif S.lb > 0 then
    if S.lmv then
      local tx, ty = BEDX[S.lb] + 14, BEDY[S.lb] - 56
      S.lx = step_to(S.lx, tx, 1.5)
      S.ly = step_to(S.ly, ty, 1.5)
      if S.lx == tx and S.ly == ty then S.lmv, S.lt = false, 300 end
    else
      S.lt = S.lt - 1
      if S.lt <= 0 then
        local j = next_bloomed(S.lb)
        if j ~= 0 and j ~= S.lb then S.lb, S.lmv = j, true else S.lt = 300 end
      end
    end
  end
  -- The snail crawls along the bottom of the lawn, very slowly.
  if S.nbloom >= 1 then
    S.snx = S.snx + 0.12
    if S.snx > W + 40 then S.snx = -40 end
  end
end

-- ------------------------------------------------------------------ the cart

function bot()
  if game.frame % 20 ~= 0 then return end
  if S.phase == "grow" then
    input.bot("low")
  elseif S.phase == "pre" or S.phase == "evening" then
    input.bot(game.frame % 40 == 0 and "low" or "right")
  end
end

function quit() save_all() end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.blooms = clamp(save.get("blooms", 0), 0, 100000)
  S.parades = clamp(save.get("parades", 0), 0, 100000)
  S.gardens = clamp(save.get("gardens", 0), 0, 1000)
  S.nunl = unlocked_count(S.gardens)
  local w = save.get("bouquet", "")
  if type(w) == "string" and #w <= 32 then
    local n = 0
    for tok in w:gmatch("[a-z]+") do
      for k = 1, 6 do
        if CNAME[k] == tok and n < 4 then n = n + 1 S.vase[n] = k end
      end
    end
    if n > 0 then S.bword = w end
  end
  local r = rnd()
  S.rare = r < 0.2 and 1 or (r < 0.4 and 2 or 0)
  log("garden blooms " .. S.blooms)
  log("garden gardens " .. S.gardens)
  bloom_mask()
  music.play(songs.song(S.mask, false))
  music.track(5, 0)
  music.track(6, 0)
  S.fx, S.fy = BEDX[1] - 48, BEDY[1] - 40
  react_to("Press any button to plant a seed!")
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.rain_t > 0 then S.rain_t = S.rain_t - 1 end
  if S.sun_t > 0 then S.sun_t = S.sun_t - 1 end
  if S.song_t > 0 then S.song_t = S.song_t - 1 end
  if S.glad > 0 then S.glad = S.glad - 1 end
  for i = 1, NB do
    if S.grow[i] < 999 then S.grow[i] = S.grow[i] + 1 end
    if S.pulse[i] < 999 then S.pulse[i] = S.pulse[i] + 1 end
    if S.scat[i] > 0 then S.scat[i] = S.scat[i] - 1 end
  end
  if mx ~= 0 or my ~= 0 or held then S.idle = 0 else S.idle = S.idle + 1 end

  -- Every stick direction does something useful: left and right along a row, up and down to the other row.
  if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
    local col, row = (S.sel - 1) % 3, idiv(S.sel - 1, 3)
    if mx ~= 0 then col = (col + mx) % 3 else row = (row + 1) % 2 end
    S.sel = row * 3 + col + 1
    S.move_cool = 16
    S.fdir = mx ~= 0 and mx or S.fdir
    cue(S.sel, 0, 0.25, 0.08, "sine")
  end
  local go = S.saw_release and ((pressed and S.act_cool <= 10) or (held and S.act_cool == 0))
  if go then
    if S.phase ~= "bouquet" then tend(S.sel, false) end
    S.act_cool = 22
  end
  if S.phase == "grow" and S.idle >= IDLE_FIRE then
    auto_tend()
    S.idle = 0
  end

  if S.phase == "pre" then
    S.pt = S.pt - 1
    if S.pt <= 0 then begin_evening() end
  elseif S.phase == "evening" then
    S.eve_t = S.eve_t - 1
    if S.fly < 14 and game.frame % 25 == 0 then S.fly = S.fly + 1 end
    if S.eve_t <= 0 then begin_bouquet() end
  elseif S.phase == "bouquet" then
    S.bq_t = S.bq_t - 1
    if S.bq_t <= 0 then new_day() end
  end
  visitors()
  if game.frame % 10 == 0 and particles.count() < 100 then
    particles.spawn(192 + pics.hash(game.frame) * 10 - 5, 164, pics.hash(game.frame + 3) * 1.2 - 0.6, -1.6, 26, 2.5, 0xbfe4ff, "dot", 0.08)
  end
  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

-- ------------------------------------------------------------------ drawing

-- What the music is doing, for the pictures only: which step, and which bed's note or drum just sounded.
local function beat_update()
  local pos = music.step() % songs.LEN + 1
  if pos ~= B.pos then
    B.pos, B.f = pos, game.frame
    if pos % 2 == 1 then B.beat = game.frame end
    local b = ARPBED[pos]
    if b > 0 and S.stage[b] == 4 then B.bf[b] = game.frame end
    if S.phase == "evening" or S.phase == "bouquet" then
      local k = DRUMTOK[pos]
      if k == "K" then B.K = game.frame elseif k == "S" then B.S = game.frame else B.H = game.frame end
    end
  end
end

local function amp(f, n) return max(0, 1 - (game.frame - f) / n) end

local function bfly(i, f)
  local x0, y0 = BEDX[i], BEDY[i] - 62
  local u = ((f + i * 83) % 480) / 480
  local L = 0
  if u > 0.45 and u < 0.55 then L = (u - 0.45) * 10
  elseif u >= 0.55 and u <= 0.8 then L = 1
  elseif u > 0.8 and u < 0.9 then L = 1 - (u - 0.8) * 10 end
  local sc = S.scat[i]
  if sc > 0 then L = L * max(0, 1 - (80 - sc) / 12) * (sc > 12 and 0 or 1) end
  local a = u * 18.85
  local fx, fy = x0 + cos(a) * 32, y0 - 14 + sin(a * 1.5) * 12
  if sc > 0 then
    local up = sin(sc / 80 * 3.1416)
    fx, fy = fx + up * 20, fy - up * 44
  end
  local flap = abs(sin(f * 0.35 + i))
  if L > 0 then flap = lerp(flap, 0.4 + 0.3 * sin(f * 0.06), L) end
  return lerp(fx, x0 + 13, L), lerp(fy, y0 + 10, L), flap
end

local function draw_bed(i, dusk)
  local st = S.stage[i]
  if st == 0 then return end
  local x, y = BEDX[i], BEDY[i]
  local k = ease.out_cubic(min(1, S.grow[i] / GROW))
  local pm = S.pulse[i]
  local pa = pm < 40 and (1 - pm / 40) or 0
  local ba = 0
  if st == 4 then ba = amp(B.bf[i], 24) * (dusk and 1 or 0.55) end
  local sway = sin(game.frame * 0.05 + i) * 2.5 + pa * sin(game.frame * 0.45) * 4
  if dusk and st == 4 then gfx.glow(x, y - 58, 40, alpha(COLS[S.ci[i]], 60 + floor(70 * ba))) end
  pics.plant(x, y, st, k, S.kind[i], COLS[S.ci[i]], sway, max(pa, ba), S.phase ~= "grow" and st == 4)
end

local function draw_bubbles()
  local t = game.frame
  for i = 1, NB do
    local st = S.stage[i]
    local sel = i == S.sel
    local show = (st >= 1 and st <= 3 and S.grow[i] >= 24) or (st == 0 and sel and S.phase == "grow")
      or (st == 4 and sel and S.grow[i] >= 40 and S.phase ~= "bouquet")
    if show then
      local x, y = BEDX[i], BEDY[i]
      local bob = sin(t * 0.1 + i) * 2.5
      local r = sel and 21 + sin(t * 0.14) * 1.5 or 16
      local by = y - (st == 4 and 120 or 100) - bob
      pics.want(WANT[st], x, by, r, x, by + r + 15, seed_col(S.planted))
    end
  end
end

local function draw_weather()
  local t = game.frame
  if S.rain_t > 0 then
    local x, y = BEDX[S.rain_bed], BEDY[S.rain_bed]
    pics.rain_cloud(x, y - 118)
    for k = -2, 2 do
      local dy = ((t * 4 + k * 17) % 80)
      gfx.line(x + k * 9, y - 104 + dy, x + k * 9 - 2, y - 92 + dy, 2.5, C.DROP)
    end
  end
  if S.sun_t > 0 then
    local x, y = BEDX[S.sun_bed], BEDY[S.sun_bed]
    local k = min(1, S.sun_t / 12)
    gfx.tri(330, 80, x - 30, y - 10, x + 30, y - 10, alpha(0xfff0a0, floor(60 * k)))
    gfx.glow(x, y - 36, 46, alpha(0xfff0a0, floor(120 * k)))
  end
  if S.song_t > 0 then
    local x, y = BEDX[S.song_bed], BEDY[S.song_bed]
    local e = (60 - S.song_t)
    for k = 1, 3 do
      local u = min(1, e / 50 + (k - 2) * 0.05)
      pics.note(x + (k - 2) * 22, y - 50 - u * 40 - k * 6, 1.1, pics.STRIPES[k], 1 - u)
    end
  end
end

local function draw_visitors(dusk, phase)
  local t = game.frame
  for i = 1, NB do
    if S.stage[i] == 4 and S.grow[i] > 20 then
      local x, y, flap = bfly(i, t)
      pics.butterfly(x, y, COLS[S.ci[i]], flap)
    end
  end
  if S.lb > 0 then
    local x, y = S.lx, S.ly
    if S.lmv then y = y - 6 - sin(t * 0.3) * 3 end
    pics.ladybug(x, y, 1, S.lmv and abs(sin(t * 0.8)) or 0)
  end
  if S.nbloom >= 3 then
    local a = t * 0.014
    local sq = amp(B.beat, 9)
    pics.bee(192 + sin(a) * 150, 336 + sin(a * 2) * 46 - sq * 4, sq, cos(a) >= 0 and 1 or -1)
  end
  if S.nbloom >= 1 then pics.snail(S.snx, 424, 1, t) end
  if dusk and S.rare == 1 then
    local hx = 50 + ((t * 0.3) % 290)
    local k = amp(B.K, 14)
    pics.hedgehog(hx, 352 - k * 7, k > 0.5 and 1 or 0, 1)
  end
  if dusk then
    for k = 1, S.fly do
      local h = pics.hash(k * 5)
      local fx = 24 + h * 336 + sin(t * 0.011 + k) * 22
      local fy = 215 + pics.hash(k * 5 + 2) * 230 + cos(t * 0.013 + k * 2) * 18
      local g = 0.5 + 0.5 * sin(t * 0.07 + k * 2.1)
      pics.firefly(fx, fy, max(g, amp(B.beat, 10) * 0.8))
    end
  end
end

local function draw_cast(phase)
  local glad = S.glad > 0 or S.phase ~= "grow"
  local lx = S.fx
  pics.unicorn(46, 128, 0.58, glad and "happy" or nil, lx)
  if S.phase == "evening" or S.phase == "bouquet" then
    local e = ease.out_back(min(1, (EVE_FRAMES - S.eve_t) / 40))
    if S.phase == "bouquet" then e = 1 end
    local bounce = abs(sin(phase * 3.1416)) * 5
    if e > 0.05 then
      pics.cat(1, PIPX, PIPY - bounce, 0.6 * e, "happy", lx)
      pics.cat(2, MOTHX, MOTHY - bounce, 0.6 * e, "happy", lx)
      pics.cat(3, PEARLX, PEARLY - bounce, 0.6 * e, "happy", lx)
    end
  end
end

local function draw_hud()
  gfx.rrect_o(8, 8, 124, 26, 11, C.CREAM, C.INK, 2)
  for k = 1, NB do
    local b = S.bord[k]
    local cx = 24 + (k - 1) * 19
    if k <= S.nbloom then
      gfx.circle_o(cx, 21, 7.5, COLS[S.ci[b]], C.INK, 1.6)
    else
      gfx.circle_o(cx, 21, 6.5, 0xe8dccc, 0xb8a8b8, 1.5)
    end
  end
  gfx.rrect_o(W - 98, 8, 90, 26, 11, C.CREAM, C.INK, 2)
  pics.head(1, W - 80, 25, 0.38, COLS[1], false)
  gfx.text(tostring(S.blooms), W - 40, 12, 16, C.INK, "center")
end

local function draw_banner()
  local t = game.frame
  if S.phase == "evening" and S.eve_t > EVE_FRAMES - 120 then
    local k = ease.out_back(min(1, (EVE_FRAMES - S.eve_t) / 24))
    gfx.rrect_o(W / 2 - 100 * k, 76 - 22 * k, 200 * k, 44 * k, 14, C.CREAM, C.GOLD, 4)
    if k > 0.9 then gfx.text("EVENING", W / 2, 60, 28, C.ROOF, "center") end
  elseif S.phase == "bouquet" then
    local k = ease.out_back(min(1, (BQ_FRAMES - S.bq_t) / 30))
    gfx.dim(1 - 0.4 * min(1, (BQ_FRAMES - S.bq_t) / 20))
    local cx, cy = 200, 232
    gfx.glow(cx, cy, 150 * k, alpha(0xfff0b0, 70))
    pics.bouquet(cx, cy - 4, 1.85 * k, 4, S.bkind, S.bci, true)
    pics.fairy(74, 268, 1.7 * k, 1, true, abs(sin(t * 0.2)), COLS[seed_col(0)], 1)
    gfx.rrect_o(W / 2 - 120, 50, 240, 52, 16, C.CREAM, C.GOLD, 4)
    gfx.text("A BOUQUET!", W / 2, 58, 32, C.ROOF, "center")
    if S.newk > 0 then
      pics.packet(S.newk, 330, 372, 1, t, true)
      gfx.text("NEW SEED!", 330, 346, 16, C.CREAM, "center", C.INK)
    end
  end
end

function draw()
  local t = game.frame
  beat_update()
  local dusk = S.phase == "evening" or S.phase == "bouquet"
  local key = fmt("garden:%d:%d", dusk and 1 or 0, (S.rainbow and not dusk) and 1 or 0)
  if bg_key and bg_key ~= key then unbake(bg_key) end
  bg_key = key
  backdrop(key, function() pics.paint(dusk, S.rainbow and not dusk, S.nunl) end)
  local frac = min(1, (t - B.f) / songs.STEP_FRAMES)
  local phase = ((B.pos - 1) % 2 + frac) / 2
  if dusk then
    for k = 1, 7 do
      local g = 0.5 + 0.5 * sin(t * 0.05 + k * 1.9)
      gfx.star(30 + pics.hash(k * 3) * 300, 20 + pics.hash(k * 3 + 1) * 120, 2.5 + g * 2.5, t * 0.01, alpha(0xfff6c8, 120 + floor(120 * g)))
    end
  else
    pics.sun(322, 80, t, S.sun_t > 0)
  end
  draw_cast(phase)
  -- Fairy's target: beside the bed she is at.
  local tx, ty = BEDX[S.sel] - 48, BEDY[S.sel] - 56
  local px = S.fx
  S.fx, S.fy = approach(S.fx, tx, 0.2), approach(S.fy, ty, 0.2)
  if abs(S.fx - px) > 0.6 then S.fdir = S.fx > px and 1 or -1 end
  for i = 1, 3 do draw_bed(i, dusk) end
  if S.nst > 0 then
    local mood = S.nst == 2 and "happy" or nil
    pics.cat(4, S.nx, S.ny, 0.55, mood, S.nst == 2 and BEDX[S.nb] or S.nx + S.ndir * 40)
  end
  for i = 4, NB do draw_bed(i, dusk) end
  draw_visitors(dusk, phase)
  if S.phase ~= "bouquet" then
    pics.ring(BEDX[S.sel], BEDY[S.sel], t)
    pics.fairy(S.fx, S.fy + sin(t * 0.07) * 3, 1.15, S.fdir, S.glad > 0, abs(sin(t * 0.33)), COLS[seed_col(S.planted)], seed_kind(S.planted))
  end
  draw_bubbles()
  draw_weather()
  -- The shelf: the seed packets (the next one glows), and the last bouquet in a vase.
  local nk = seed_kind(S.planted)
  for k = 1, 6 do
    local st = UNLOCK[k] <= S.gardens and 1 or 0
    if st == 1 and k == nk and S.phase == "grow" then st = 2 end
    pics.packet(k, 44 + (k - 1) * 52, 441, st, t, false)
  end
  if S.vase[1] > 0 then pics.vase(350, 457, S.vase[1], S.vase[2], S.vase[3], S.vase[4]) end
  draw_hud()
  particles.draw()
  draw_banner()
  local line
  if S.react_left > 0 and S.phase ~= "bouquet" then
    line = S.react
  elseif S.phase == "pre" or S.phase == "evening" then
    line = "Evening! Press to play the song!"
  elseif S.phase == "bouquet" then
    line = S.newk > 0 and "A new seed packet for next time!" or "A bouquet for you!"
  else
    line = LINES[S.stage[S.sel]]
  end
  if input.down("1p") and input.down("2p") then line = "Your garden will stay!" end
  ui.band(line)
end
