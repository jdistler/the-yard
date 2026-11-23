-- Band: the Starlight Stage. She conducts five friends, and the song is built from what she does.
-- Little band (CONTROLS.md, CASTLE.md): any stick direction moves the spotlight, any right-hand button
-- does the verb, and a turn cannot be lost. The design is DESIGN.md beside this file.
--
-- A turn: pick a song from the setlist board, then press to wake the friends one by one. Each friend owns a
-- track (Unicorn harp melody, Pip drums, Moth bass, Pearl bells, Nib claps and shaker) that comes in when
-- they wake. A press on a friend who is already playing is a solo: a note from the chord under the song, on
-- the next step. When all five play, the verse swings into the chorus, then the big finish: a bow, confetti,
-- a new song learned, new fans in the seats. band.sav keeps songs (encores), tunes (songs learned), fans.
--
-- Rules for the code: game logic counts game.frame and never reads music.step(); the step is only used to
-- draw (bounce, lights) and to pick the pitch of a music.cue. Chance is only the seeded rnd, only in init.

local pics = import("pictures")
local songs = import("songs")
local SONGS = songs.songs
local C = pics.C
local X, Y, NAME, COL = pics.X, pics.Y, pics.NAME, pics.COL

local BAND = 32
local CHORUS_FRAMES, FINISH_FRAMES, IDLE_WAKE = 600, 330, 330
local MAX_SEATS = 40
local RING = {2, 1, 4, 5, 3}                       -- Pip, Unicorn, Pearl, Nib, Moth: round the stage
local RINGPOS = {[2] = 1, [1] = 2, [4] = 3, [5] = 4, [3] = 5}
local UPM = {[1] = 4, [2] = 1, [3] = 2, [4] = 1, [5] = 4}
local DOWNM = {[1] = 3, [2] = 3, [3] = 5, [4] = 5, [5] = 4}
local LX = {192, 66, 128, 318, 256}                -- where each friend's lamp hangs
local TONIC = {53, 48, 48, 50}
local ZZ = {1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2}

local S = {
  phase = "pick", song = 1, pick = 1, sel = 1, nawake = 0,
  awake = {false, false, false, false, false},
  hop = {0, 0, 0, 0, 0}, glow = {0, 0, 0, 0, 0}, solo_n = {0, 0, 0, 0, 0}, solo_said = {false, false, false, false, false},
  solos = 0, stuck = 0, chorus_t = 0, finish_t = 0, idle = 0, wiggle = 0,
  songs = 0, tunes = 0, fans = 0, last = 0, new_song = false,
  move_cool = 0, act_cool = 0, saw_release = false, goodbye = false,
  react = "", react_left = 0, seed = 1, owl = false, owl_t = 0,
  photos = 0, gardens = 0, sx = 192, sl = 192, sy = 198,
  seat_age = {}, arr = nil,
}
-- Drawing's memory of the music: when each track last played a note, and which.
local B = {pos = 0, f = 0, last = {-999, -999, -999, -999, -999, -999}, mid = {0, 0, 0, 0, 0, 0},
  K = -999, S = -999, H = -999, C = -999}
local SEATX, SEATY = {}, {}
local TONES = {0, 0, 0, 0, 0, 0, 0, 0}
local bg_key

local function react_to(s) S.react, S.react_left = s, 100 end
local function mhz(m) return 440 * 2 ^ ((m - 69) / 12) end
local function fold(m, lo)
  while m < lo do m = m + 12 end
  while m >= lo + 12 do m = m - 12 end
  return m
end

-- ------------------------------------------------------------------ saving

local function save_all()
  save.set("songs", S.songs)
  save.set("tunes", S.tunes)
  save.set("fans", S.fans)
  save.set("last", S.last)
  save.write()
end

local function add_fan(n)
  local old = S.fans
  S.fans = min(S.fans + n, 100000)
  for k = old + 1, min(S.fans, MAX_SEATS) do S.seat_age[k] = game.frame end
end

-- ------------------------------------------------------------------ the music

-- Quiet the tracks nobody has woken. Level 0 is silent; the pad is always there.
local function set_levels()
  music.track(1, 1)
  for i = 1, 5 do music.track(i + 1, S.awake[i] and 1 or 0) end
end

local function play_song(idx, arr_name)
  local sg = SONGS[idx]
  S.arr = sg.arr[arr_name]
  music.play(S.arr.song)
  set_levels()
end

-- A friend's note, from the chord under the step the cue will land on. Sound only: nothing here is read
-- back by the game. Whatever the child mashes, it is a chord tone, on the grid.
local function solo_sound(i)
  local sg = SONGS[S.song]
  local root, t3, f5, s7 = songs.chord(sg, music.step() + 1)
  local n = S.solo_n[i]
  S.solo_n[i] = n + 1
  if i == 1 then
    local b = fold(root, 60)
    TONES[1], TONES[2], TONES[3], TONES[4] = 0, t3, f5, s7
    TONES[5], TONES[6], TONES[7], TONES[8] = 12, 12 + t3, 12 + f5, 12 + s7
    music.cue{wave = "tri", note = b + TONES[ZZ[n % 14 + 1]], dur = 0.5, vol = 0.2, release = 0.45}
  elseif i == 2 then
    local k = n % 4
    local m = fold(root, 52)
    if k == 0 then music.cue{wave = "sine", hz = 150, hz_end = 46, dur = 0.2, vol = 0.32, release = 0.18}
    elseif k == 1 then music.cue{wave = "noise", hz = 14000, dur = 0.14, vol = 0.16, release = 0.13}
    elseif k == 2 then music.cue{wave = "sine", hz = mhz(m + 7), hz_end = mhz(m), dur = 0.22, vol = 0.26, release = 0.2}
    else music.cue{wave = "sine", hz = mhz(m), hz_end = mhz(m - 7), dur = 0.24, vol = 0.28, release = 0.22} end
  elseif i == 3 then
    local k = n % 4
    local m = fold(root, 40) + (k == 1 and f5 or k == 2 and 12 or k == 3 and t3 or 0)
    music.cue{wave = "tri", note = m, dur = 0.32, vol = 0.3, release = 0.28}
  elseif i == 4 then
    TONES[1], TONES[2], TONES[3], TONES[4] = 0, t3, f5, s7
    TONES[5], TONES[6], TONES[7] = 12, 12 + t3, 12 + f5
    local m = fold(root, 72) + TONES[(n * 3) % 7 + 1]
    music.cue{wave = "sine", note = m, dur = 0.55, vol = 0.16, release = 0.5}
    music.cue{wave = "sine", note = m + 12, dur = 0.3, vol = 0.05, release = 0.28}
  else
    local k = n % 4
    if k < 2 then music.cue{wave = "noise", hz = 30000, dur = 0.06, vol = 0.09, release = 0.055}
    elseif k == 2 then music.cue{wave = "noise", hz = 16000, dur = 0.1, vol = 0.17, release = 0.09}
    else
      music.cue{wave = "noise", hz = 44100, dur = 0.16, vol = 0.1, release = 0.14}
      music.cue{wave = "tri", note = 96, dur = 0.08, vol = 0.05, release = 0.07}
    end
  end
end

local function stinger()
  local t = TONIC[S.song]
  sfx.arp("tri", {t + 24, t + 28, t + 31, t + 36, t + 40, t + 43, t + 48}, 0.07, 0.3)
  sfx.arp("sine", {t + 12, t + 19, t + 24}, 0.1, 0.25)
  sfx.noise(0.5, 0.12, 9000)
end

-- ------------------------------------------------------------------ turns

local function start_pick()
  S.phase = "pick"
  S.nawake, S.solos, S.stuck, S.new_song = 0, 0, 0, false
  for i = 1, 5 do
    S.awake[i], S.hop[i], S.glow[i], S.solo_n[i], S.solo_said[i] = false, 0, 0, 0, false
  end
  -- Start on the song she has not learned yet; once she knows all four, on the one after the last.
  S.pick = S.tunes < 4 and S.tunes + 1 or S.last % 4 + 1
  S.song = S.pick
  S.sel, S.sx, S.sl, S.sy = 1, X[1], LX[1], Y[1]
  music.volume(1)
  play_song(S.pick, "verse")
  react_to("Pick a song, then press!")
end

local function begin_song()
  S.song = S.pick
  S.phase = "play"
  S.idle = 0
  log("band song " .. SONGS[S.song].id)
  if S.owl and S.owl_t == 0 then
    S.owl_t = 1
    log("band visitor owl")
  end
  react_to("Wake your friends!")
end

local function start_chorus()
  S.phase = "chorus"
  S.chorus_t = CHORUS_FRAMES
  S.arr = SONGS[S.song].arr.chorus
  music.play{bpm = S.arr.song.bpm, steps = S.arr.song.steps, keep = true,
    S.arr.song[1], S.arr.song[2], S.arr.song[3], S.arr.song[4], S.arr.song[5], S.arr.song[6]}
  add_fan(2)
  log("band chorus")
  sfx.arp("tri", {72, 76, 79, 84, 88}, 0.05, 0.22)
  particles.burst(W / 2, 150, 20, 3, 44, 3.5, C.GOLD, "star")
  react_to("Chorus! Everybody plays!")
  save_all()
end

local function finish()
  S.phase = "finish"
  S.finish_t = FINISH_FRAMES
  S.songs = min(S.songs + 1, 100000)
  log("band encore " .. S.songs)
  S.new_song = false
  if S.song == S.tunes + 1 and S.tunes < 4 then
    S.tunes = S.tunes + 1
    S.new_song = true
    log("band learned " .. S.tunes)
  end
  S.last = S.song
  add_fan(S.new_song and 6 or 3)
  log("band fans " .. S.fans)
  save_all()
  music.volume(0)
  stinger()
  for i = 1, 5 do S.hop[i] = 40 end
  for i = 1, 36 do
    local h = pics.hash(i)
    particles.spawn(W / 2 + (h - 0.5) * 300, 120 + pics.hash(i + 40) * 40, (pics.hash(i + 80) - 0.5) * 5,
      -4.5 * pics.hash(i + 120) - 1, 80, 3 + pics.hash(i + 7) * 2, pics.STRIPES[i % 4 + 1], "star", 0.1, 0.99, 0.1)
  end
  react_to(S.new_song and "A new song! You learned it!" or "Bravo! Take a bow!")
end

local function wake(i, auto)
  S.awake[i] = true
  S.nawake = S.nawake + 1
  S.hop[i], S.glow[i], S.stuck = 44, 24, 0
  music.track(i + 1, 1)
  log("band wake " .. NAME[i])
  add_fan(1)
  solo_sound(i)
  sfx.slide("sine", 380, 760, 0.16, 0.12)
  particles.burst(X[i], Y[i] - 10, 12, 2.6, 34, 3.5, COL[i], "star")
  react_to(NAME[i] .. (auto and " woke up!" or " joins the band!"))
  if S.nawake >= 5 then start_chorus() else save_all() end
end

local function solo(i)
  S.hop[i], S.glow[i] = 26, 22
  S.solos = S.solos + 1
  solo_sound(i)
  if not S.solo_said[i] then
    S.solo_said[i] = true
    log("band solo " .. NAME[i])
  end
  if particles.count() < 110 then
    particles.burst(X[i], Y[i] + 20, 8, 2.4, 28, 3, COL[i], "star")
    particles.spawn(X[i], Y[i] - 40, ((S.solos % 5) - 2) * 0.5, -2.2, 46, 4, C.ROOF, "heart", 0.04)
  end
  if S.solos % 10 == 0 then
    add_fan(1)
    log("band fan " .. S.fans)
  end
  react_to(NAME[i] .. " plays a solo!")
  -- Mashing one friend: after a few solos the spotlight points at a sleepy one, so the next press wakes them.
  S.stuck = S.stuck + 1
  if S.stuck >= 6 and S.nawake < 5 then
    S.stuck = 0
    for k = 1, 5 do
      local j = RING[(RINGPOS[i] - 1 + k) % 5 + 1]
      if not S.awake[j] then
        S.sel = j
        react_to(NAME[j] .. " is sleepy! Press to wake!")
        sfx.slide("sine", 540, 720, 0.07, 0.1)
        break
      end
    end
  end
end

local function nav(mx, my)
  local s = S.sel
  if mx ~= 0 then return RING[(RINGPOS[s] - 1 + mx) % 5 + 1] end
  return my < 0 and UPM[s] or DOWNM[s]
end

local function unlocked() return min(4, S.tunes + 1) end

local function pick_move(mx, my)
  local u = unlocked()
  if u <= 1 then
    S.wiggle = 16
    sfx.note("sine", 84, 0.12, 0.12)
    return
  end
  local p
  if mx ~= 0 then
    p = (S.pick - 1 + mx) % u + 1
  else
    p = S.pick <= 2 and S.pick + 2 or S.pick - 2
    if p > u then p = S.pick % u + 1 end
  end
  if p ~= S.pick then
    S.pick, S.song = p, p
    play_song(p, "verse")
    sfx.note("tri", 76 + p * 2, 0.14, 0.14)
  end
  S.wiggle = 16
end

-- ------------------------------------------------------------------ the cart

function bot()
  if game.frame % 20 ~= 0 then return end
  if S.phase == "pick" then
    input.bot("low")
  elseif S.phase == "play" then
    input.bot(S.awake[S.sel] and "right" or "low")
  elseif S.phase == "chorus" then
    input.bot(game.frame % 40 == 0 and "low" or "right")
  end
end

function quit() save_all() end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.songs = clamp(save.get("songs", 0), 0, 100000)
  S.tunes = clamp(save.get("tunes", 0), 0, 4)
  S.fans = clamp(save.get("fans", 0), 0, 100000)
  S.last = clamp(save.get("last", 0), 0, 4)
  S.photos = clamp(save.peek("tea", "photos", 0), 0, 4)
  S.gardens = clamp(save.peek("garden", "gardens", 0), 0, 1000)
  S.seed = rndi(1, 9999)
  S.owl = rnd() < 0.3
  log("band songs " .. S.songs)
  for k = 1, MAX_SEATS do S.seat_age[k] = -1000 end
  -- Seats fill from the middle out, front row after back row.
  local order = {}
  for k = 1, MAX_SEATS do order[k] = k end
  for k = 1, MAX_SEATS do
    local col, row = (k - 1) % 20, idiv(k - 1, 20)
    SEATX[k] = 22 + col * 18.6 + row * 9
    SEATY[k] = 448 + row * 20
  end
  for a = 2, MAX_SEATS do
    local v = order[a]
    local b = a - 1
    while b >= 1 and abs(SEATX[order[b]] - 192) > abs(SEATX[v] - 192) do
      order[b + 1] = order[b]
      b = b - 1
    end
    order[b + 1] = v
  end
  local ox, oy = {}, {}
  for k = 1, MAX_SEATS do ox[k], oy[k] = SEATX[order[k]], SEATY[order[k]] end
  for k = 1, MAX_SEATS do SEATX[k], SEATY[k] = ox[k], oy[k] end
  start_pick()
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  if S.wiggle > 0 then S.wiggle = S.wiggle - 1 end
  for i = 1, 5 do
    if S.hop[i] > 0 then S.hop[i] = S.hop[i] - 1 end
    if S.glow[i] > 0 then S.glow[i] = S.glow[i] - 1 end
  end
  if mx ~= 0 or my ~= 0 or held then S.idle = 0 else S.idle = S.idle + 1 end

  local go = S.saw_release and ((pressed and S.act_cool <= 10) or (held and S.act_cool == 0))
  if S.phase == "pick" then
    if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
      pick_move(mx, my)
      S.move_cool = 16
    end
    if go then
      begin_song()
      S.act_cool = 22
    end
  elseif S.phase == "play" or S.phase == "chorus" then
    if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
      S.sel = nav(mx, my)
      S.stuck = 0
      S.move_cool = 14
      sfx.slide("sine", 540, 720, 0.07, 0.1)
    end
    if go then
      if S.awake[S.sel] then solo(S.sel) else wake(S.sel) end
      S.act_cool = 22
    end
    if S.phase == "play" and S.idle >= IDLE_WAKE then
      -- Doing nothing is still play: the next sleepy friend wakes by themselves.
      for k = 1, 5 do
        local i = RING[(RINGPOS[S.sel] - 1 + k) % 5 + 1]
        if not S.awake[i] then
          S.sel = i
          wake(i, true)
          break
        end
      end
      S.idle = 0
    end
    if S.phase == "chorus" then
      S.chorus_t = S.chorus_t - 1
      if S.chorus_t <= 0 then finish() end
    end
  elseif S.phase == "finish" then
    S.finish_t = S.finish_t - 1
    if S.finish_t <= 0 then start_pick() end
  end
  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

-- ------------------------------------------------------------------ drawing

-- What the music is doing, for the pictures only: which step, how far into it, who played a note on it.
local function beat_update()
  local arr = S.arr
  local pos = music.step() % arr.len + 1
  if pos ~= B.pos then
    B.pos, B.f = pos, game.frame
    for t = 1, 6 do
      if (t == 1 or S.awake[t - 1]) and arr.on[t][pos] then
        B.last[t], B.mid[t] = game.frame, arr.mid[t][pos]
        if t == 3 then
          local k = arr.toks[3][pos]
          if k == "K" then B.K = game.frame elseif k == "S" then B.S = game.frame
          elseif k == "H" then B.H = game.frame else B.C = game.frame end
        end
      end
    end
  end
end

local function amp(f, sf) return max(0, 1 - (game.frame - f) / (sf * 1.8)) end

local function draw_friend(i, phase, sf)
  local x, y = X[i], Y[i]
  local awake = S.awake[i]
  local h = S.hop[i]
  local lift = h > 0 and -abs(sin(h * 0.25)) * min(h, 30) * 0.5 or 0
  local active = awake or S.phase == "finish"
  local bow = S.phase == "finish" and abs(sin((FINISH_FRAMES - S.finish_t) * 0.06)) * 6 or 0
  if active then lift = lift - abs(sin(phase * math.pi)) * (S.phase == "chorus" and 6 or 3.5) + bow
  else lift = sin(game.frame * 0.04 + i) * 1.5 end
  y = y + lift
  local g = S.glow[i] / 22
  local mood = not active and "sleep" or ((h > 0 or S.phase ~= "play") and "happy" or nil)
  if awake then gfx.glow(x, y + 24, 62, alpha(COL[i], 60 + floor(70 * g))) end
  local lx = X[S.sel]
  if i == 2 then
    local k, sn, hh, cr = 0, 0, 0, 0
    if awake then
      k, sn, hh, cr = amp(B.K, sf), amp(B.S, sf), amp(B.H, sf), amp(B.C, sf)
      k, sn = max(k, g), max(sn, g)
    end
    pics.kit_back(x, y, cr, hh)
    pics.cat(1, x, y, 1, mood, lx)
    pics.kit_front(x, y, k, sn)
    pics.sticks(x, y, C.ORANGE, max(sn, cr), max(k, hh))
  elseif i == 1 then
    local a = awake and max(amp(B.last[2], sf), g) or 0
    pics.unicorn(x, y, 1, mood, lx)
    pics.harp(x, y, a, B.mid[2] % 7 + 1)
  elseif i == 3 then
    local a = awake and max(amp(B.last[4], sf), g) or 0
    pics.cat(2, x, y, 1, mood, lx)
    pics.bass(x, y, a, B.mid[4] % 4 + 1)
    gfx.circle_o(x + 44, y + 6, 5, C.GREY, C.INK, 1.5)
    gfx.circle_o(x + 46, y + 40 + a * 3, 5, C.GREY, C.INK, 1.5)
  elseif i == 4 then
    local a = awake and max(amp(B.last[5], sf), g) or 0
    pics.cat(3, x, y, 1, mood, lx)
    pics.bars(x, y, C.WHITE, B.mid[5] % 5 + 1, a)
  else
    local a = awake and max(amp(B.last[6], sf), g) or 0
    pics.cat(4, x, y, 1, mood, lx)
    pics.tambourine(x, y, C.CREAM, a)
  end
  if not active then
    -- Zzz drifting up from a sleeper.
    for k = 0, 2 do
      local t = ((game.frame * 0.6 + k * 24 + i * 11) % 72) / 72
      gfx.text("z", x + 22 + k * 5 + t * 14, y - 36 - t * 34, 13 + k * 3, alpha(C.WHITE, floor(230 * (1 - t))), "center", alpha(C.INK, 200))
    end
  end
end

local function draw_board()
  local t = game.frame
  gfx.rrect_o(14, 34, 356, 380, 18, 0x3a2258, C.GOLD, 4)
  gfx.rrect(20, 40, 344, 34, 12, alpha(0xffffff, 26))
  gfx.text("SETLIST", 192, 42, 22, C.GOLD, "center", C.INK)
  gfx.star(60, 58, 10, t * 0.02, C.GOLD)
  gfx.star(324, 58, 10, -t * 0.02, C.GOLD)
  local u = unlocked()
  for i = 1, 4 do
    local sg = SONGS[i]
    local cx0, cy0 = 26 + ((i - 1) % 2) * 178, 82 + idiv(i - 1, 2) * 164
    local sel = i == S.pick
    local bounce = sel and abs(sin(t * 0.12)) * 4 or 0
    local wig = sel and S.wiggle > 0 and sin(S.wiggle * 1.2) * 4 or 0
    local x, y = cx0 + wig, cy0 - bounce
    local state = i <= S.tunes and "learned" or (i == S.tunes + 1 and "new" or "locked")
    local bg = state == "locked" and 0x2a1a40 or mix(sg.col, 0x2a1a40, 0.35)
    if sel then gfx.glow(x + 82, y + 78, 110, alpha(sg.col, 90)) end
    gfx.rrect_o(x, y, 164, 152, 14, bg, sel and 0xffffff or C.INK, sel and 5 or 2.5)
    if state == "locked" then
      gfx.text("?", x + 82, y + 22, 54, alpha(C.WHITE, 120), "center")
      gfx.rrect_o(x + 62, y + 84, 40, 30, 6, 0x6a5a88, C.INK, 2)
      gfx.ring(x + 82, y + 82, 12, 4, 0x6a5a88)
      gfx.circle(x + 82, y + 98, 4, C.INK)
    else
      pics.song_icon(i, x + 82, y + 56, 1.25, sg.col, t)
      gfx.text(sg.name, x + 82, y + 112, 17, C.WHITE, "center", C.INK)
      if state == "learned" then
        gfx.star(x + 142, y + 22, 14, t * 0.01, C.INK)
        gfx.star(x + 142, y + 22, 11, t * 0.01, C.GOLD)
      else
        local p = 1 + 0.12 * sin(t * 0.2)
        gfx.rrect_o(x + 8, y + 8, 50, 22, 8, C.ROOF, C.INK, 2)
        gfx.text("NEW", x + 33, y + 10, 15, C.WHITE, "center")
        gfx.star(x + 142, y + 22, 13 * p, t * 0.03, C.GOLD)
      end
    end
  end
end

local function draw_audience(phase)
  local glad = S.phase == "chorus" or S.phase == "finish"
  local n = min(S.fans, MAX_SEATS)
  for k = n, 1, -1 do
    local x, y = SEATX[k], SEATY[k]
    local age = game.frame - S.seat_age[k]
    local drop = 0
    if age < 50 then drop = (1 - ease.out_bounce(age / 50)) * 80 end
    local up = glad and abs(sin(phase * math.pi + k * 0.7)) * 8 or max(0, sin(game.frame * 0.05 + k * 1.3) - 0.8) * 10
    pics.fan((k * 7 + S.seed) % 5 + 1, x, y - drop, up, glad)
  end
  if glad and game.frame % 14 == 0 and n > 0 and particles.count() < 90 then
    local k = (game.frame * 7) % n + 1
    particles.spawn(SEATX[k], SEATY[k] - 14, 0, -1.2, 40, 4, C.ROOF, "heart", -0.01)
  end
end

local function draw_stage(phase, sf)
  local sg = SONGS[S.song]
  local chorus = S.phase == "chorus" or S.phase == "finish"
  -- Lamps: lit for whoever is awake; in the chorus the whole rig swings.
  for i = 1, 5 do pics.lamp(LX[i], S.awake[i] or chorus, COL[i]) end
  if chorus then
    for i = 1, 5 do
      local a = sin(game.frame * 0.05 + i * 1.3) * 60
      gfx.tri(LX[i], 42, X[i] + a - 34, 300 + (i % 2) * 40, X[i] + a + 34, 300 + (i % 2) * 40, alpha(COL[i], 42))
    end
  end
  -- The spotlight glides to the friend she has chosen.
  S.sx = approach(S.sx, X[S.sel], 0.25)
  S.sl = approach(S.sl, LX[S.sel], 0.25)
  S.sy = approach(S.sy, Y[S.sel], 0.25)
  gfx.tri(S.sl, 42, S.sx - 50, S.sy + 82, S.sx + 50, S.sy + 82, alpha(0xfff0b0, 58))
  gfx.ellipse(S.sx, S.sy + 80, 52, 11, alpha(0xfff0b0, 90))
  gfx.glow(S.sx, S.sy + 10, 70, alpha(0xfff0b0, 60))
  -- Back row first, then the front row.
  draw_friend(2, phase, sf)
  draw_friend(1, phase, sf)
  draw_friend(4, phase, sf)
  draw_friend(3, phase, sf)
  draw_friend(5, phase, sf)
  -- The arrow over her choice.
  local bob = sin(game.frame * 0.18) * 4
  local ay = S.sy - (S.sel == 1 and 86 or 54) - bob
  gfx.tri(S.sx - 11, ay - 12, S.sx + 11, ay - 12, S.sx, ay + 6, C.INK)
  gfx.tri(S.sx - 8, ay - 9, S.sx + 8, ay - 9, S.sx, ay + 2, C.GOLD)
  -- The chorus bar: it fills as the song goes on, towards the big finish.
  if S.phase == "chorus" then
    local k = 1 - S.chorus_t / CHORUS_FRAMES
    gfx.rrect_o(48, 406, 288, 10, 5, 0x6a4030, C.INK, 2)
    for j = 0, 5 do
      local w = 288 / 6
      local fillw = clamp(k * 6 - j, 0, 1) * (w - 3)
      if fillw > 1 then gfx.rrect(50 + j * w, 408, fillw, 6, 3, pics.STRIPES[j % 4 + 1]) end
    end
  end
  if S.owl and S.owl_t > 0 then
    -- The rare visitor on the lamp rail.
    local ox, oy = 360, 36
    gfx.ellipse_o(ox, oy + 6, 11, 13, 0xa07850, C.INK, 2)
    gfx.circle_o(ox - 5, oy - 2, 6, C.CREAM, C.INK, 1.5)
    gfx.circle_o(ox + 5, oy - 2, 6, C.CREAM, C.INK, 1.5)
    gfx.circle(ox - 5 + sin(game.frame * 0.03) * 1.5, oy - 2, 2.2, C.INK)
    gfx.circle(ox + 5 + sin(game.frame * 0.03) * 1.5, oy - 2, 2.2, C.INK)
    gfx.tri(ox - 2, oy + 2, ox + 2, oy + 2, ox, oy + 6, C.ORANGE)
  end
end

local function draw_banner()
  if S.phase ~= "finish" then return end
  local k = ease.out_back(min(1, (FINISH_FRAMES - S.finish_t) / 30))
  local cx, cy = W / 2, 88
  gfx.rrect_o(cx - 150 * k, cy - 46 * k, 300 * k, 92 * k, 18, C.CREAM, C.GOLD, 4)
  if k > 0.9 then
    gfx.star(cx - 118, cy, 22 + sin(game.frame * 0.2) * 3, game.frame * 0.03, C.GOLD)
    gfx.star(cx + 118, cy, 22 + sin(game.frame * 0.2 + 1) * 3, -game.frame * 0.03, C.GOLD)
    if S.new_song then
      gfx.text("NEW SONG!", cx, cy - 36, 24, C.ROOF, "center")
      gfx.text(SONGS[S.song].name, cx, cy - 2, 26, C.INK, "center")
    else
      gfx.text("BRAVO!", cx, cy - 32, 32, C.ROOF, "center")
      gfx.text(SONGS[S.song].name, cx, cy + 8, 20, C.INK, "center")
    end
  end
end

function draw()
  local sg = SONGS[S.phase == "pick" and S.pick or S.song]
  beat_update()
  local sf = sg.step_frames
  local frac = min(1, (game.frame - B.f) / sf)
  local phase = ((B.pos - 1) % 4 + frac) / 4
  -- One room at a time in memory: the old song's backdrop is let go when the song changes.
  local key = fmt("band:%d:%d:%d", sg.col, S.photos, S.gardens >= 3 and 1 or 0)
  if bg_key and bg_key ~= key then unbake(bg_key) end
  bg_key = key
  backdrop(key, function() pics.paint_stage(sg, S.photos, S.gardens >= 3) end)
  -- The rail: the song's name on the left, fans on the right.
  gfx.text(sg.name, 192, 4, 15, C.CREAM, "center", C.INK)
  gfx.heart(20, 14, 9, C.INK)
  gfx.heart(20, 14, 7, C.ROOF)
  gfx.text(tostring(S.fans), 32, 5, 14, C.CREAM, "left", C.INK)
  if S.phase == "pick" then
    for i = 1, 5 do pics.lamp(LX[i], false, COL[i]) end
    draw_board()
  else
    draw_stage(phase, sf)
  end
  draw_audience(phase)
  draw_banner()
  particles.draw()
  local line
  if S.react_left > 0 and S.phase ~= "pick" then
    line = S.react
  elseif S.phase == "pick" then
    line = unlocked() == 1 and "Press any button to start the band!" or ("Pick a song! " .. sg.name)
  elseif S.phase == "play" then
    line = S.awake[S.sel] and ("Press for a " .. NAME[S.sel] .. " solo!") or ("Press to wake " .. NAME[S.sel] .. "!")
  elseif S.phase == "chorus" then
    line = "Chorus! Press for solos!"
  else
    line = S.react
  end
  if input.down("1p") and input.down("2p") then line = "Your band and fans will stay!" end
  ui.band(line)
end
