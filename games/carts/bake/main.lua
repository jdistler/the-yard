-- Bake: the Royal Kitty Bakery. Little band (CONTROLS.md, CASTLE.md): any stick direction moves along the tray of
-- choices, any right-hand button does the next little bit of baking, and nothing can be lost. DESIGN.md is beside this.
--
-- A turn: a friend from the castle (Pip, Moth, Pearl, Nib, the Unicorn) walks in with a picture of what they would
-- love. She picks a kind (once she has more than cupcakes), stirs a flavour, bakes it, pipes the frosting colour the
-- stick chose, sprinkles, picks a topping (her Garden flower too), and serves it. Every step is a little play AND a
-- layer of the kitchen song (shaker, bass, melody, bells); serving swings the song into its chorus. Whatever she
-- makes delights them; the wish is only a suggestion, and a match earns the special dance. Her last six treats
-- stand in the shop window. bake.sav keeps treats, last (a word for Tea), and s1..s6 (the window).
--
-- Rules for the code: game logic counts game.frame and never reads music.step(); the step only picks the pitch of a
-- music.cue and drives drawing (things bounce on the beat). Chance is one rnd() in init; after that a small integer
-- generator (Park-Miller) of our own, so the customers and their wishes never depend on the order of calls.

local pics = import("pictures")
local songs = import("songs")
local C = pics.C
local KIND, FLAV, FROST, TOP, UNLOCK = pics.KIND, pics.FLAV, pics.FROST, pics.TOP, pics.UNLOCK
local FLAVC, FROSTC, KS, SHS = pics.FLAVC, pics.FROSTC, pics.KS, pics.SHS
local CNAME, COLS = pics.CNAME, pics.COLS

local WHO = {"Pip", "Moth", "Pearl", "Nib", "Unicorn"}
local PICK, MIX, BAKE, FROSTS, SPRK, TOPS, SERVE, REACT = 0, 1, 2, 3, 4, 5, 6, 7
local NEED = {[MIX] = 3, [BAKE] = 2, [FROSTS] = 2, [SPRK] = 3, [TOPS] = 1, [SERVE] = 1}
local CX, WX, WY, TY = 110, 192, 312, 372        -- customer, workstation, treat base, tray row
local BAKE_F, SERVE_F, IDLE_F, HELP_F, ACT = 66, 172, 210, 40, 36
local RT = {1, 2, 3, 0, 5}                       -- Pip licks, Moth's whiskers, Pearl bites, Nib copies, Unicorn sparkles
local PW = {50, 58, 62, 70}                      -- plate half-width per kind
local KIN = {0.8, 1.0, 0.95, 0.52}               -- scale inside the oven
local TOPH = {80, 32, 64, 128}                   -- how tall each kind stands, at scale 1
local FH = {52, 24, 62, 60}                      -- where the frosting is
local WS = {0.62, 0.62, 0.52, 0.5}               -- scale in the wish bubble
local SHX = {-30, 0, 30}
local SKEY = {"s1", "s2", "s3", "s4", "s5", "s6"}
local KPHRASE = {"cupcake", "cookie", "layer cake", "castle cake"}
local TPHRASE = {"a cherry", "a star", "a heart", "a strawberry", "a flower"}

local S = {
  treats = 0, nkinds = 1, rs = 1, w0 = 0, ncust = 0, who = 1, party = false, photos = 0, ntop = 4,
  wk = 1, wf = 1, wt = 1, wkey = "", wflow = 1,
  stage = MIX, n = 0, st_t = 0, kind = 1, fl = 1, fr = 1, tp = 1, tfc = 1,
  kind_i = 1, flav_i = 1, frost_i = 1, top_i = 1, shx_i = 2,
  bk = 0, bt = 0, door = 0, glow = 0, peek_t = 0, oven_out = 0, rise = 0,
  fk = 0, fk_t = 0, spr = 0, lift = 0, sa = 0, stir_t = 0, tool_t = 0, shake_t = 0,
  sv = -1, match = false, rtype = 1, prev_r = 0, prev_w = 0, newk = 0, copyw = 0,
  arr_t = 0, ccx = 470, glad = 0, layers = 0,
  sh = {}, shown = {}, shift_t = 0, lastw = "", bq = {}, l_serve = "", l_song = "", tstr = "0",
  idle = 0, help_t = 0, hv = 0,
  move_cool = 0, act_cool = 0, saw_release = false, goodbye = false,
  react = "", react_left = 0,
}
-- Drawing's memory of the music: when the last beat sounded.
local B = {pos = 0, f = 0, beat = -999}

local function react_to(s) S.react, S.react_left = s, 110 end
local function find(list, v) for i = 1, #list do if list[i] == v then return i end end end

-- ------------------------------------------------------------------ words and saving

-- kind_flavour_frosting_topping, e.g. cupcake_berry_pink_star; a flower is flower + its colour (flowerlilac).
local function word_of(k, f, r, t, fc)
  return KIND[k] .. "_" .. FLAV[f] .. "_" .. FROST[r] .. "_" .. (t == 5 and ("flower" .. CNAME[fc]) or TOP[t])
end

local function item(k, f, r, t, fc)
  local w = word_of(k, f, r, t, fc)
  return {kind = k, fl = f, fr = r, tp = t, fc = fc, word = w, key = "sh:" .. w}
end

-- A word from a save: an item, or nil when it is not a treat of ours.
local function parse(w)
  if type(w) ~= "string" or #w > 32 then return nil end
  local a, b, c, d = w:match("^([a-z]+)_([a-z]+)_([a-z]+)_([a-z]+)$")
  if not a then return nil end
  local k, f, r = find(KIND, a), find(FLAV, b), find(FROST, c)
  if not (k and f and r) then return nil end
  local t, fc = find(TOP, d), 0
  if not t then
    local cn = d:match("^flower([a-z]+)$")
    fc = cn and find(CNAME, cn)
    if not fc then return nil end
    t = 5
  end
  return item(k, f, r, t, fc)
end

local function save_all()
  save.set("treats", S.treats)
  if S.lastw ~= "" then save.set("last", S.lastw) end
  for i = 1, 6 do save.set(SKEY[i], S.sh[i] and S.sh[i].word or nil) end
  save.write()
end

local function kinds_open(n)
  local c = 0
  for k = 1, 4 do if UNLOCK[k] <= n then c = c + 1 end end
  return c
end

-- ------------------------------------------------------------------ music and small helpers

local function cue(k, dur, vol, wave, oct)
  music.cue{wave = wave or "tri", note = songs.cue_note(music.step(), k, oct), dur = dur, vol = vol, release = dur * 0.9}
end

local function layer(i, on)
  music.track(i, on and 1 or 0)
end

local function burst(x, y, n, sp, life, size, col, kind)
  if particles.count() < 130 then particles.burst(x, y, n, sp, life, size, col, kind) end
end

local function lcg()
  S.rs = (S.rs * 16807) % 2147483647
  return S.rs
end

local function fcol_of() return COLS[S.bq[(S.treats % max(1, #S.bq)) + 1] or 1] end
local function fcid_of() return S.bq[(S.treats % max(1, #S.bq)) + 1] or 1 end

local function wish_text()
  return FROST[S.wf] .. " " .. KPHRASE[S.wk] .. " with " .. (S.wt == 5 and "your flower" or TPHRASE[S.wt])
end

-- ------------------------------------------------------------------ a customer

local function new_customer()
  S.ncust = S.ncust + 1
  S.party = S.photos > 0 and S.ncust % 5 == 3
  S.who = S.party and 5 or ((S.w0 + S.ncust * 2) % 5) + 1
  S.wk = lcg() % S.nkinds + 1
  S.wf = lcg() % 5 + 1
  S.ntop = #S.bq > 0 and 5 or 4
  S.wt = lcg() % S.ntop + 1
  S.wflow = fcid_of()
  if S.wkey ~= "" then unbake(S.wkey) end
  S.wkey = "w:" .. S.wk .. S.wf .. S.wt .. S.wflow
  S.arr_t, S.sv, S.match, S.newk, S.glad, S.idle, S.help_t = 0, -1, false, 0, 0, 0, 0
  S.n, S.st_t = 0, 0
  S.stage = S.nkinds > 1 and PICK or MIX
  S.kind_i = 1
  S.kind = 1
  S.bk, S.bt, S.door, S.glow, S.peek_t, S.oven_out, S.rise = 0, 0, 0, 0, 0, 0, 0
  S.fk, S.fk_t, S.spr, S.lift, S.shake_t, S.tool_t = 0, 0, 0, 0, 0, 0
  S.layers = 0
  local nm = S.party and "the party" or WHO[S.who]
  S.l_serve, S.l_song = "Press to serve " .. nm .. "!", "The song plays for " .. nm .. "!"
  for i = 2, 6 do layer(i, false) end
  music.play(songs.song(false, true))
  log("bake customer " .. (S.party and "party" or WHO[S.who]))
  log("bake wish " .. KIND[S.wk] .. "_" .. FROST[S.wf] .. "_" .. (S.wt == 5 and "flower" or TOP[S.wt]))
  react_to((S.party and "A party order! " or (WHO[S.who] .. " would love ")) .. "a " .. wish_text() .. "!")
end

-- ------------------------------------------------------------------ the steps (one press, one action)

local function go_stage(st)
  S.stage, S.n, S.st_t = st, 0, 0
end

local function serve()
  local k, f, r, t = S.kind, S.fl, S.fr, S.tp
  local fc = t == 5 and S.tfc or 0
  local it = item(k, f, r, t, fc)
  S.match = k == S.wk and r == S.wf and t == S.wt
  S.treats = min(S.treats + 1, 100000)
  local old = S.nkinds
  S.nkinds = kinds_open(S.treats)
  S.newk = S.nkinds > old and S.nkinds or 0
  table.insert(S.sh, 1, it)
  S.sh[7] = nil
  S.lastw = it.word
  S.tstr = tostring(S.treats)
  log("bake serve " .. it.word .. (S.match and " match" or " other"))
  log("bake serve " .. S.treats)
  if S.newk > 0 then log("bake unlock " .. KIND[S.newk]) end
  save_all()
  go_stage(REACT)
  S.sv = 0
  if S.who == 4 and not S.party then
    S.rtype = S.prev_r > 0 and S.prev_r or 1
    S.copyw = S.prev_w
    if S.prev_w > 0 then log("bake copy " .. WHO[S.prev_w]) end
  else
    S.rtype = RT[S.who]
    S.prev_r, S.prev_w = S.rtype, S.who
  end
  -- The full chorus: the same chords, every track in, the drums too.
  music.play(songs.song(true, true))
  for i = 2, 6 do layer(i, true) end
  S.layers = 5
  sfx.noise(0.25, 0.08, 4200)
  sfx.arp("tri", {72, 76, 79, 84, 88}, 0.07, 0.3)
  burst(WX, WY - 60, 24, 3.2, 40, 4, C.ROOF, "heart")
  react_to(S.match and ("Just what " .. (S.party and "the party" or WHO[S.who]) .. " wished for!")
    or ((S.party and "The party" or WHO[S.who]) .. " LOVES it!"))
end

local function press(auto)
  local st = S.stage
  S.glad = 26
  if auto then log("bake helper") end
  if st == PICK then
    S.kind = S.kind_i
    log("bake kind " .. KIND[S.kind])
    cue(2, 0.3, 0.2)
    burst(WX, WY - 40, 12, 2.4, 26, 3, C.GOLD, "star")
    go_stage(MIX)
    react_to("A " .. KPHRASE[S.kind] .. "! Press to stir!")
  elseif st == MIX then
    S.n = S.n + 1
    S.stir_t = 30
    if S.n == 1 then
      layer(2, true)
      S.layers = max(S.layers, 1)
    end
    cue(S.n * 2, 0.25, 0.2)
    sfx.note("sine", 60 + S.n * 4, 0.1, 0.1)
    burst(WX, WY - 22, 10, 2.2, 22, 3, FLAVC[S.flav_i], "dot")
    if S.n >= 3 then
      S.fl = S.flav_i
      log("bake mix " .. FLAV[S.fl])
      go_stage(BAKE)
      react_to(FLAV[S.fl] .. " batter in the pan!")
    end
  elseif st == BAKE then
    if S.bk == 0 then
      S.bk, S.bt = 1, 0
      log("bake oven in")
      layer(3, true)
      S.layers = max(S.layers, 2)
      sfx.noise(0.12, 0.08, 900)
      cue(0, 0.3, 0.2, "tri", -12)
      react_to("Into the warm oven!")
    elseif S.bk == 1 then
      S.peek_t = 24
      cue(3, 0.2, 0.14, "sine")
      sfx.noise(0.08, 0.04, 2600)
    else
      S.oven_out = 18
      go_stage(FROSTS)
      S.rise = 1
      log("bake out")
      sfx.arp("tri", {79, 84, 88}, 0.06, 0.2)
      burst(WX, WY - 60, 18, 2.6, 30, 3, C.WHITE, "dot")
      react_to("Out of the oven! Pick a frosting colour!")
    end
  elseif st == FROSTS then
    S.n = S.n + 1
    S.tool_t = 30
    if S.n == 1 then
      layer(4, true)
      S.layers = max(S.layers, 3)
      S.fk_t = 0.5
      cue(1, 0.35, 0.2)
      react_to(FROST[S.frost_i] .. " frosting!")
    else
      S.fk_t = 1
      S.fr = S.frost_i
      log("bake frost " .. FROST[S.fr])
      cue(4, 0.4, 0.22)
      go_stage(SPRK)
      react_to("Press for sprinkles!")
    end
    sfx.arp("sine", {74 + S.n * 4, 78 + S.n * 4}, 0.07, 0.14)
    burst(WX + SHX[2], WY - FH[S.kind] * KS[S.kind], 12, 2, 26, 3, FROSTC[S.frost_i], "heart")
  elseif st == SPRK then
    S.n = S.n + 1
    S.spr = S.n
    S.shake_t = 26
    if S.n == 1 then
      layer(5, true)
      S.layers = max(S.layers, 4)
      log("bake sprinkle")
    end
    -- Each rain of sprinkles is a little twinkle on the beat, three notes rising.
    cue(S.n, 0.3, 0.16, "sine", 12)
    cue(S.n + 2, 0.3, 0.14, "sine", 12)
    cue(S.n + 4, 0.4, 0.12, "sine", 12)
    sfx.arp("sine", {88, 91, 96}, 0.05, 0.1)
    local sx, sy = WX + SHX[S.shx_i], WY - TOPH[S.kind] * KS[S.kind] - 30
    for i = 1, 9 do
      if particles.count() < 130 then
        particles.spawn(sx + (i - 5) * 3, sy + 20, (i - 5) * 0.12, 1 + (i % 3) * 0.3, 34, 3, pics.RAINBOW[i % 6 + 1], "square", 0.12, 0.99)
      end
    end
    if S.n >= 3 then
      go_stage(TOPS)
      react_to("Pick a topping and press!")
    end
  elseif st == TOPS then
    S.tp = S.top_i
    S.tfc = fcid_of()
    S.lift = 36
    log("bake top " .. (S.tp == 5 and ("flower " .. CNAME[S.tfc]) or TOP[S.tp]))
    cue(5, 0.5, 0.22)
    sfx.arp("tri", {84, 88, 91, 96}, 0.06, 0.18)
    burst(WX, WY - TOPH[S.kind] * KS[S.kind], 14, 2.4, 28, 3, C.GOLD, "star")
    go_stage(SERVE)
    react_to("All done! Press to serve " .. WHO[S.who] .. "!")
  elseif st == SERVE then
    serve()
  else
    -- She cheers while the friend enjoys the treat.
    cue(S.n, 0.2, 0.14, "sine", 12)
    S.n = S.n + 1
    burst(S.ccx, 120, 6, 2, 24, 3, C.ROOF, "heart")
  end
end

-- The stick: left/up one way along the tray, right/down the other. Each stage gives it a use.
local function stick(d)
  local st = S.stage
  if st == PICK then
    S.kind_i = (S.kind_i - 1 + d) % S.nkinds + 1
    cue(S.kind_i, 0.25, 0.14, "sine")
  elseif st == MIX then
    S.flav_i = (S.flav_i - 1 + d) % 4 + 1
    cue(S.flav_i, 0.25, 0.14, "sine")
  elseif st == FROSTS then
    S.frost_i = (S.frost_i - 1 + d) % 5 + 1
    cue(S.frost_i, 0.25, 0.14, "sine")
  elseif st == TOPS then
    S.top_i = (S.top_i - 1 + d) % S.ntop + 1
    cue(S.top_i, 0.25, 0.14, "sine")
  elseif st == BAKE then
    S.peek_t = 24
    if S.bk == 1 then
      log("bake peek")
      cue(3, 0.2, 0.12, "sine", 12)
    end
  elseif st == SPRK then
    S.shx_i = (S.shx_i - 1 + d) % 3 + 1
    cue(S.shx_i, 0.2, 0.12, "sine")
  else
    cue(S.n, 0.2, 0.12, "sine", 12)
    burst(WX, 250, 5, 2, 20, 3, C.GOLD, "star")
    S.n = S.n + 1
  end
end

-- Doing nothing is still play: after a while Nib comes to help. He turns the tray to what the customer wished
-- (so a watcher sees a happy match) and does the next step, one every 2/3 s.
local function helper()
  local st = S.stage
  local want, cur
  if st == PICK then want, cur = S.wk, S.kind_i
  elseif st == FROSTS then want, cur = S.wf, S.frost_i
  elseif st == TOPS then want, cur = S.wt, S.top_i end
  if want and cur ~= want then
    stick(1)
    return
  end
  if st == BAKE and S.bk == 1 then return end
  press(true)
end

-- ------------------------------------------------------------------ the reaction

local function react_events()
  local sv, x = S.sv, S.ccx
  if sv == 22 then
    for i = 1, 8 do
      if particles.count() < 130 then
        particles.spawn(x + (i - 4.5) * 9, 100, (i - 4.5) * 0.3, -1.5 - (i % 3) * 0.3, 44, 4, C.ROOF, "heart", -0.01, 0.99)
      end
    end
    if S.match then
      sfx.arp("tri", {72, 76, 79, 84, 88, 91, 96}, 0.06, 0.24)
      burst(x, 76, 16, 3.2, 44, 4, C.GOLD, "star")
      fx.confetti(18)
      cue(0, 0.4, 0.2, "tri", 12)
    end
  end
  local rt = S.rtype
  if S.party then
    if sv == 24 or sv == 40 then sfx.slide("sine", 500, 800, 0.12, 0.14) end
    if sv == 30 then sfx.arp("tri", {84, 88, 91, 96, 100}, 0.06, 0.14) end
    if sv >= 24 and sv <= 120 and sv % 8 == 0 and particles.count() < 130 then
      particles.spawn(x - 70 + (sv % 5) * 40, 100, 0, 1, 40, 3, pics.RAINBOW[sv % 6 + 1], "square", 0.06, 0.99)
    end
  elseif rt == 1 then
    if sv == 24 or sv == 40 or sv == 56 then sfx.slide("sine", 420, 760, 0.12, 0.16) end
  elseif rt == 2 then
    if sv == 24 or sv == 46 then sfx.arp("tri", {76, 78, 76, 78, 76, 78}, 0.05, 0.12) end
  elseif rt == 3 then
    if sv == 26 or sv == 54 then
      sfx.noise(0.05, 0.1, 3000)
      sfx.arp("sine", {88, 91, 95}, 0.08, 0.1)
      burst(CX + 14, 270, 6, 1.4, 26, 2.5, C.CREAM, "dot")
    end
  else
    if sv == 24 then sfx.arp("tri", {84, 88, 91, 96, 100, 103}, 0.06, 0.14) end
    if sv >= 24 and sv <= 120 and sv % 5 == 0 and particles.count() < 130 then
      particles.spawn(x - 4, 92, (sv % 7 - 3) * 0.5, -0.4, 36, 3.5, C.GOLD, "star", 0.04, 0.98)
    end
  end
  if S.match and sv >= 24 and sv <= 120 and sv % 12 == 0 and particles.count() < 130 then
    particles.spawn(284, 120, (sv % 5 - 2) * 0.6, -1.2, 40, 4, C.ROOF, "heart", 0.02, 0.99)
  end
  if sv == 130 then sfx.slide("sine", 400, 900, 0.3, 0.12) end
  if sv == 150 then
    -- The treat lands in the window.
    S.shown = {}
    for i = 1, #S.sh do S.shown[i] = S.sh[i] end
    S.shift_t = 20
    burst(44, 450, 14, 2.2, 28, 3, C.GOLD, "star")
    sfx.arp("tri", {84, 91, 96}, 0.06, 0.14)
  end
  if sv >= SERVE_F then
    -- Back to the verse with only the hum, and the next friend walks in.
    new_customer()
  end
end

-- ------------------------------------------------------------------ the cart

function bot()
  local f = game.frame
  local st = S.stage
  local want, cur
  if st == PICK then want, cur = S.wk, S.kind_i
  elseif st == FROSTS then want, cur = S.wf, S.frost_i
  elseif st == TOPS then want, cur = S.wt, S.top_i end
  -- Every other friend gets exactly the wish (the stick turns the tray first), the rest get whatever is chosen.
  if want and cur ~= want and S.ncust % 2 == 1 then
    if f % 15 == 9 then input.bot("right") end
    return
  end
  if f % 15 == 3 then input.bot("low") end
  if f % 150 == 100 then input.bot("left") end
end

function quit() save_all() end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.treats = clamp(save.get("treats", 0), 0, 100000)
  S.nkinds = kinds_open(S.treats)
  S.tstr = tostring(S.treats)
  local n = 0
  for i = 1, 6 do
    local it = parse(save.get(SKEY[i], ""))
    if it then n = n + 1 S.sh[n] = it end
  end
  local lw = parse(save.get("last", ""))
  S.lastw = lw and lw.word or ""
  for i = 1, #S.sh do S.shown[i] = S.sh[i] end
  local w = save.peek("garden", "bouquet", "")
  if type(w) == "string" and #w <= 32 then
    for tok in w:gmatch("[a-z]+") do
      local c = find(CNAME, tok)
      if c and #S.bq < 4 then S.bq[#S.bq + 1] = c end
    end
  end
  S.photos = clamp(save.peek("tea", "photos", 0), 0, 100000)
  S.rs = rndi(1, 2000000)
  S.w0 = rndi(0, 4)
  log("bake treats " .. S.treats)
  music.play(songs.song(false))
  for i = 2, 6 do layer(i, false) end
  new_customer()
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.glad > 0 then S.glad = S.glad - 1 end
  if S.peek_t > 0 then S.peek_t = S.peek_t - 1 end
  if S.stir_t > 0 then S.stir_t = S.stir_t - 1 end
  if S.tool_t > 0 then S.tool_t = S.tool_t - 1 end
  if S.shake_t > 0 then S.shake_t = S.shake_t - 1 end
  if S.oven_out > 0 then S.oven_out = S.oven_out - 1 end
  if S.shift_t > 0 then S.shift_t = S.shift_t - 1 end
  if S.lift > 0 then S.lift = S.lift - 2 end
  if S.arr_t < 40 then S.arr_t = S.arr_t + 1 end
  S.st_t = S.st_t + 1
  S.sa = S.sa + 0.03 + S.stir_t * 0.012
  S.fk = step_to(S.fk, S.fk_t, 0.03)

  local real = pressed or held or mx ~= 0 or my ~= 0
  if real then S.idle, S.help_t = 0, 0 else S.idle = S.idle + 1 end
  S.hv = approach(S.hv, (S.idle >= IDLE_F and S.stage ~= REACT) and 1 or 0, 0.12)

  if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
    S.move_cool = 14
    stick((mx < 0 or my < 0) and -1 or 1)
  end
  if S.saw_release and ((pressed and S.act_cool <= ACT - 12) or (held and S.act_cool == 0)) then
    press(false)
    S.act_cool = ACT
  end
  if S.idle >= IDLE_F and S.stage ~= REACT then
    S.help_t = S.help_t - 1
    if S.help_t <= 0 then
      helper()
      S.help_t = HELP_F
    end
  end

  -- The oven runs by itself, in frames.
  if S.stage == BAKE then
    if S.bk == 1 then
      S.bt = S.bt + 1
      if S.bt >= BAKE_F then
        S.bk = 2
        log("bake ding")
        sfx.note("tri", 96, 0.5, 0.22)
        sfx.arp("sine", {91, 96, 103}, 0.1, 0.14)
        burst(WX, 236, 14, 2.2, 28, 3, C.GOLD, "star")
        react_to("DING! Press to take it out!")
      end
    end
    local rise = S.bk == 0 and 0 or (S.bk == 1 and S.bt / BAKE_F or 1)
    S.rise = rise
    S.glow = approach(S.glow, S.bk == 1 and 1 or (S.bk == 2 and 0.5 or 0), 0.06)
    S.door = step_to(S.door, S.bk >= 1 and 1 or 0, 0.1)
    if S.bk == 2 and game.frame % 12 == 0 then
      particles.spawn(WX + (game.frame % 5 - 2) * 12, 214, 0, -1, 34, 4, C.WHITE, "dot", -0.01, 0.99)
    end
  else
    S.glow = approach(S.glow, 0, 0.1)
  end

  -- The customer walks in, and (after the reaction) walks out.
  if S.stage == REACT then
    S.sv = S.sv + 1
    if S.sv >= 150 then
      S.ccx = lerp(CX, -110, ease.in_quad(min(1, (S.sv - 150) / 20)))
    else
      S.ccx = CX
    end
    react_events()
  else
    S.ccx = lerp(470, CX, ease.out_cubic(min(1, S.arr_t / 30)))
  end
  if S.arr_t == 22 and S.stage ~= REACT then
    sfx.arp("tri", {84, 88}, 0.07, 0.12)
  end

  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

-- ------------------------------------------------------------------ drawing

local function amp(f, n) return max(0, 1 - (game.frame - f) / n) end

local function beat_update()
  local pos = music.step() % songs.LEN + 1
  if pos ~= B.pos then
    B.pos, B.f = pos, game.frame
    if pos % 2 == 1 then B.beat = game.frame end
  end
end

local BULB = {0x7ee8c8, 0x7ec8ff, 0xff8fbc, 0xffd84a, 0xb998f0, 0xff8a6a, 0x7ee8c8}
local function draw_bulbs()
  local t = game.frame
  local bt = amp(B.beat, 10)
  for i = 1, 7 do
    local on = i <= S.layers
    local x = i * 48
    if on then
      local k = 0.55 + 0.45 * bt
      if S.layers >= 5 then k = (B.pos + i) % 2 == 0 and 1 or 0.4 end
      gfx.glow(x, 41, 14 + 8 * k, alpha(BULB[i], floor(90 * k)))
      gfx.circle_o(x, 41, 6.5 + 1.5 * k, BULB[i], C.INK, 1.8)
    else
      gfx.circle_o(x, 41, 5.5, 0xd8c4d0, C.INK, 1.5)
    end
  end
end

local function draw_customer()
  local t = game.frame
  local who = S.who
  local sv = S.sv
  local react = S.stage == REACT and sv >= 22 and sv < 150
  local bounce = -amp(B.beat, 10) * 3
  local sway = 0
  if S.stage == REACT and sv >= 22 then
    if S.match then
      bounce = -abs(sin(sv * 0.28)) * (sv < 140 and 18 or 4)
      sway = sin(sv * 0.2) * 14
    else
      bounce = -abs(sin(sv * 0.3)) * (sv < 140 and 7 or 2)
    end
  elseif S.glad > 0 then
    bounce = bounce - abs(sin(S.glad * 0.3)) * 4
  end
  local x = S.ccx + sway
  local mood = (react or S.glad > 0) and "happy" or nil
  gfx.clip(0, 46, W, 159)
  if S.party then
    pics.cat(1, x - 74, 158 + bounce * 0.6, 0.75, mood, x)
    pics.cat(2, x + 76, 160 + bounce * 0.6, 0.75, mood, x)
    if react then
      pics.tongue(x - 74, 158 + bounce * 0.6, 20, sv)
      pics.whiskers(x + 76, 160 + bounce * 0.6, 20, sv)
    end
  end
  if who == 5 then
    pics.unicorn(x, 140 + bounce, 0.8, mood, WX)
    if S.party then pics.hat(x, 140 + bounce, 0.8) end
    if react and (S.rtype == 5 or S.party) then
      gfx.glow(x, 90 + bounce, 24 + sin(t * 0.2) * 6, alpha(0xfff0a0, 110))
      for k = 0, 3 do
        local a = t * 0.06 + k * 1.57
        gfx.star(x + cos(a) * 52, 118 + bounce + sin(a) * 28, 4 + (k % 2) * 2, t * 0.04, 0xfff0a0)
      end
    end
  else
    local s = who == 4 and 1.25 or 1
    local r = (who == 4 and 20 or 27) * s
    local cy = 140 + bounce
    pics.cat(who, x, cy, s, mood, WX)
    if react and not S.party then
      local rt = S.rtype
      if rt == 1 then pics.tongue(x, cy, r, sv)
      elseif rt == 2 then pics.whiskers(x, cy, r, sv)
      elseif rt == 3 then
        gfx.ellipse(x - r * 0.62, cy + r * 0.32, 8, 5, alpha(0xff6f98, 120))
        gfx.ellipse(x + r * 0.62, cy + r * 0.32, 8, 5, alpha(0xff6f98, 120))
        for k = 0, 2 do
          local u = ((sv * 0.02 + k * 0.33) % 1)
          gfx.circle(x + 30 + sin(u * 6 + k) * 6, cy - 20 - u * 36, 2.5, alpha(C.GOLD, floor(255 * (1 - u))))
        end
      else
        gfx.glow(x, cy - 40, 20, alpha(0xfff0a0, 90))
        gfx.star(x - 26, cy - 40 + sin(t * 0.1) * 4, 5, t * 0.05, 0xfff0a0)
        gfx.star(x + 30, cy - 36 + cos(t * 0.1) * 4, 4, -t * 0.05, 0xfff0a0)
      end
      if who == 4 and S.copyw > 0 then
        pics.cat(S.copyw, x + 56, cy + 36 + sin(t * 0.2) * 2, 0.34, "happy", x)
      end
    end
  end
  gfx.clip()
end

local function draw_wish()
  if S.stage == REACT and S.sv >= 150 then return end
  local k = ease.out_back(min(1, max(0, (S.arr_t - 22) / 14)))
  if k <= 0 then return end
  local t = game.frame
  local bx, by = 284, 112 + sin(t * 0.06) * 3
  local r = 48 * k
  gfx.circle_o(bx - 52, by + 46, 6.5 * k, C.WHITE, C.INK, 2)
  gfx.circle_o(bx - 70, by + 58, 4 * k, C.WHITE, C.INK, 1.8)
  gfx.circle_o(bx, by, r, C.WHITE, C.INK, 3)
  if k > 0.85 then
    pics.treat_stamp(S.wkey, bx, by + 34, S.wk, WS[S.wk], FLAVC[4], FROSTC[S.wf], S.wt, S.wflow, 0)
  end
  if S.match and S.stage == REACT then
    gfx.ring(bx, by, 52 + sin(t * 0.3) * 3, 4, C.GOLD)
    gfx.heart(bx + 34, by - 36, 16 + sin(t * 0.3) * 2, 0xff5a8a)
  end
end

-- What she is making, from the bowl to the plate.
local function draw_work()
  local t = game.frame
  local st = S.stage
  local k = S.kind
  local ks = KS[k]
  local enter = ease.out_cubic(min(1, S.st_t / 16))
  local dy = (1 - enter) * 70
  local bt = amp(B.beat, 8)
  if st == PICK then
    local i = S.kind_i
    pics.plate(WX, WY, PW[i])
    pics.treat(i, WX, WY + 2 - bt * 3, KS[i], 1, FLAVC[S.flav_i], nil, 0, 0)
  elseif st == MIX then
    pics.bowl(WX, WY - 36 + dy, S.sa, (S.n + 0.4) / 3.4, FLAVC[S.flav_i], S.stir_t)
  elseif st == BAKE or S.oven_out > 0 then
    local oy = 208 + (st == BAKE and dy or (1 - S.oven_out / 18) * 120)
    local prog = S.bk == 0 and 0 or (S.bk == 1 and S.bt / BAKE_F or 1)
    local glow = S.peek_t > 0 and max(S.glow, 0.8) or S.glow
    pics.oven_back(WX, oy, glow, prog)
    gfx.clip(WX - 66, oy + 34, 132, 86)
    local rise = S.rise
    pics.treat(k, WX, oy + 114, KIN[k], rise, FLAVC[S.fl], nil, 0, 0)
    gfx.clip()
    pics.oven_front(WX, oy, S.peek_t > 0 and 0 or S.door, glow)
  end
  if st >= FROSTS and st <= SERVE then
    local bob = -bt * 2
    pics.plate(WX, WY, PW[k])
    local fcol = FROSTC[st == FROSTS and S.frost_i or S.fr]
    pics.treat(k, WX, WY + 2 + bob, ks, 1, FLAVC[S.fl], fcol, S.fk, S.spr)
    if st == TOPS then
      pics.treat_top(k, S.top_i, WX, WY + 2 + bob, ks, 1, fcid_of(), 14 + sin(t * 0.12) * 4)
    elseif st == SERVE then
      pics.treat_top(k, S.tp, WX, WY + 2 + bob, ks, 1, S.tfc, max(0, S.lift) * 0.8)
      if t % 14 == 0 then burst(WX + (t % 5 - 2) * 20, WY - 50, 1, 1, 24, 3, C.GOLD, "star") end
    end
    -- The tool hovering over it.
    if st == FROSTS then
      local a = S.tool_t * 0.4
      pics.tool("bag", WX + (S.tool_t > 0 and cos(a) * 8 or 0), WY - FH[k] * ks - 18 + (S.tool_t > 0 and sin(a) * 4 or 0) + sin(t * 0.08) * 2,
        S.tool_t / 30, FROSTC[S.frost_i])
    elseif st == SPRK then
      local sx = WX + SHX[S.shx_i]
      local sy = WY - TOPH[k] * ks - 22 + sin(t * 0.08) * 2
      pics.tool("shaker", sx + (S.shake_t > 0 and sin(S.shake_t * 1.4) * 6 or 0), sy + (S.shake_t > 0 and abs(sin(S.shake_t * 0.7)) * 4 or 0), 0)
    end
  end
end

-- The treat being served, from the counter to the customer's plate and on to the window.
local function draw_serve()
  local sv = S.sv
  local k = S.kind
  local u = ease.out_cubic(min(1, sv / 22))
  local px, py, sc = lerp(WX, CX, u), lerp(WY, 298, u), lerp(KS[k], KS[k] * 0.62, u)
  local fcol = FROSTC[S.fr]
  if sv >= 130 then
    local w = ease.in_out(min(1, (sv - 130) / 20))
    px, py, sc = lerp(CX, 44, w), lerp(298, 466, w), lerp(KS[k] * 0.62, SHS[k], w)
  else
    pics.plate(px, py, PW[k] * 0.66)
  end
  if sv < 150 then
    local dip = (S.rtype == 3 or S.party) and sv > 24 and sv < 70 and abs(sin(sv * 0.4)) * 4 or 0
    pics.treat(k, px, py + dip, sc, 1, FLAVC[S.fl], fcol, 1, 3)
    pics.treat_top(k, S.tp, px, py + dip, sc, 1, S.tfc, 0)
  end
end

local function draw_tray()
  local t = game.frame
  local st = S.stage
  local what, count, sel, want
  if st == PICK then what, count, sel, want = 1, 4, S.kind_i, S.wk
  elseif st == MIX then what, count, sel, want = 2, 4, S.flav_i, 0
  elseif st == FROSTS then what, count, sel, want = 3, 5, S.frost_i, S.wf
  elseif st == TOPS then what, count, sel, want = 4, S.ntop, S.top_i, S.wt end
  if what then
    local sp = count == 5 and 68 or 84
    for i = 1, count do
      local x = 192 + (i - (count + 1) / 2) * sp
      if what == 1 and i > S.nkinds then
        pics.locked(x, TY)
      else
        local on = i == sel
        local k = on and (1.22 + sin(t * 0.14) * 0.04) or 0.92
        if i == want then
          gfx.glow(x, TY, 36 + sin(t * 0.12) * 4, alpha(0xffe070, 120))
          gfx.star(x, TY - 36 - sin(t * 0.14) * 3, 7, t * 0.05, C.GOLD)
        end
        if on then gfx.ring(x, TY, 24 * k + 5, 3.5, C.GOLD) end
        pics.choice(what, i, x, TY, k, i == 5 and fcid_of() or 1)
      end
    end
  else
    -- No choice to make: the rail of what has been done and what comes next.
    local cur = st == MIX and 1 or st == BAKE and 2 or st == FROSTS and 3 or st == SPRK and 4 or st == TOPS and 5 or st == SERVE and 6 or (st == REACT and 7 or 0)
    for i = 1, 6 do
      local x = 192 + (i - 3.5) * 58
      local on = i == cur
      pics.rail_icon(i, x, TY, on and (1.25 + sin(t * 0.14) * 0.05) or 1, i <= cur)
      if i < cur then gfx.circle_o(x, TY + 25, 4, C.GOLD, C.INK, 1.4) end
      if on then gfx.ring(x, TY, 25, 3.5, C.GOLD) end
    end
  end
end

local function draw_want()
  local st = S.stage
  if st == REACT then return end
  local t = game.frame
  local x, y, r = 330, 256 + sin(t * 0.1) * 3, 24
  local need, done = NEED[st] or 1, S.n
  if st == PICK then pics.want("kind", x, y, r)
  elseif st == MIX then pics.want("spoon", x, y, r)
  elseif st == BAKE then
    pics.want(S.bk == 2 and "mitt" or "flame", x, y, r)
    done = S.bk >= 1 and 1 or 0
  elseif st == FROSTS then pics.want("bag", x, y, r, nil, nil, FROSTC[S.frost_i])
  elseif st == SPRK then pics.want("shaker", x, y, r)
  elseif st == TOPS then
    pics.want(nil, x, y, r)
    pics.topping(S.top_i, x, y + 10, 1.25, fcid_of())
  else pics.want("bell", x, y, r) end
  if need > 1 then
    for k = 1, need do
      local dx = x + (k - (need + 1) / 2) * 13
      gfx.circle_o(dx, y + r + 11, 4.5, k <= done and C.GOLD or C.WHITE, C.INK, 1.6)
    end
  end
end

local function draw_window()
  local t = game.frame
  for i = 1, #S.shown do
    local it = S.shown[i]
    local x = 14 + 29.6 + (i - 1) * 59.3
    if i >= 2 and S.shift_t > 0 then x = x - 59.3 * S.shift_t / 20 end
    pics.treat_stamp(it.key, x, 466 - (i == 1 and S.shift_t > 0 and sin(S.shift_t / 20 * 3.14) * 6 or 0),
      it.kind, SHS[it.kind], FLAVC[it.fl], FROSTC[it.fr], it.tp, it.fc, 3)
  end
  pics.glass()
end

local function draw_helper()
  if S.hv < 0.03 then return end
  local t = game.frame
  local e = ease.out_back(min(1, S.hv))
  gfx.clip(0, 226, 118, 114)
  pics.cat(4, 52, lerp(350, 292, e) + sin(t * 0.2) * 2, 0.85, "happy", WX)
  gfx.clip()
end

local function band_line()
  local st = S.stage
  if input.down("1p") and input.down("2p") then return "Your treats will stay!" end
  if S.react_left > 0 then return S.react end
  if st == PICK then return "What shall we bake? Move the stick, then press!"
  elseif st == MIX then return "Press to stir! The stick picks the flavour."
  elseif st == BAKE then
    return S.bk == 0 and "Press to put it in the oven!" or (S.bk == 1 and "Warm and rising! Peek with the stick." or "DING! Press to take it out!")
  elseif st == FROSTS then return "The stick picks a colour. Press to pipe it on!"
  elseif st == SPRK then return "Press for sprinkles! The stick moves the jar."
  elseif st == TOPS then return "Pick a topping with the stick, then press!"
  elseif st == SERVE then return S.l_serve end
  return S.l_song
end

function draw()
  local t = game.frame
  beat_update()
  backdrop("bake:bg", pics.paint)
  draw_bulbs()
  draw_customer()
  draw_wish()
  draw_work()
  if S.stage == REACT then draw_serve() end
  draw_helper()
  draw_want()
  draw_tray()
  draw_window()
  -- Her treat count, top left.
  gfx.rrect_o(6, 48, 96, 24, 10, C.CREAM, C.INK, 2)
  pics.treat(1, 24, 69, 0.3, 1, FLAVC[1], FROSTC[1], 1, 0)
  gfx.text(S.tstr, 90, 51, 16, C.INK, "right")
  particles.draw()
  if S.stage == REACT and S.newk > 0 and S.sv > 30 and S.sv < 150 then
    local k = ease.out_back(min(1, (S.sv - 30) / 14))
    gfx.rrect_o(294 - 80 * k, 270 - 28 * k, 160 * k, 56 * k, 14, C.CREAM, C.GOLD, 4)
    if k > 0.9 then
      pics.treat(S.newk, 250, 292, pics.SHS[S.newk] * 0.8, 1, FLAVC[1], FROSTC[1], 1, 0)
      gfx.text("NEW!", 324, 258, 26, C.ROOF, "center", C.INK)
    end
  end
  ui.band(band_line())
end
