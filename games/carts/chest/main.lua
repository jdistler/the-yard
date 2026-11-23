-- Chest: walk to the key past Zam's purple fairies, open the chest, take the sword, duel Zam,
-- then duel Pika when he leaps out of the chest, and celebrate with a grand victory!
-- Walk-up band (CONTROLS.md). The stick walks. Any button shoots.
-- On the path the button blows a bubble from his wand, and the game aims it: at a purple
-- bubble about to reach him, else at the nearest purple fairy, else the way he faces. A
-- bubbled fairy turns gold, follows him, and in the duels flies at the boss to wrap him.
-- In the duels the sword points at the boss by itself (or at a purple fairy close to him), so
-- the stick is for dodging bubbles, lightning rings, and stepping onto stars.
-- A grown-up reads the cream band. chest.sav is "gems N". The spec is DESIGN.md beside this.

local pics = import("pictures")
local songs = import("songs")

local SPEED, POP_FRAMES, WRAP_FRAMES, REACT_FRAMES = 2, 60, 120, 120
local ZAMBOW_FRAMES, PIKAPOP_FRAMES = 70, 55
local WIN_MIN_FRAMES, WIN_AUTO_FRAMES, RESTART_FRAMES = 120, 320, 60
local SHOT_GAP, HOLD_GAP = 12, 30
local MARKS_WIN, PIKA_MARKS_WIN = 12, 10
local ZX, ZY, PY, FIGHT_TOP, TELE_FRAMES, SHIELD_FRAMES = 192, 118, 146, 300, 40, 90
local SPOTS = {120, 192, 264}
local PIKA_SPOTS = {104, 192, 280}
local KEY_SPOTS = {{128, 348}, {300, 356}, {72, 268}, {318, 270}, {84, 420}}
-- The path's purple fairies: where they hover (one always guards the key), how fast their
-- bubbles drift (slower than he walks), and his wand's bubbles.
local FOE_SPOTS = {{300, 300}, {76, 300}, {312, 410}, {70, 410}, {300, 250}}
local PUFF_FRAMES, PUFF_SPEED, PUFF_GAP, PATH_GRACE = 30, 1.3, 50, 120
local WAND_SPEED, WAND_LIFE, WAND_MAX, SAVE_FRAMES, STUCK_FRAMES = 4.5, 80, 4, 30, 30
local START_X, START_Y = 200, 420
local C = pics.C

local function trunc(v) return v >= 0 and floor(v) or ceil(v) end

-- Everything the game knows. pictures.lua reads it to draw.
local S = {
  phase = "path", boss = "zam", gems = 0, marks = 0, pips = 0, level = 0, marks_win = MARKS_WIN,
  nx = 200, ny = 420, face_x = 0, face_y = -1, has_key = false, has_sword = false, key_x = 128, key_y = 348,
  pop_t = 0, bow_t = 0, fight_t = 0, hop = 0, react_left = 0, react = "", shot_cool = 0, saw_release = false,
  telegraph = 0, spray = false, fairy = nil, fairy_x = 0, fairy_y = 0, wrap = 0, wrap_alive = false,
  ring = nil, star = nil, splash = nil, hurt_cool = 0, shot_once = false, spoon_flash = 0, goodbye = false,
  zx = ZX, zy = ZY, spot = 2, tele_t = 0, tele_to = 2, shield_t = 0, flinch_t = 0, dizzy_t = 0, bend_t = 0,
  surge = false,
  -- Pika state (Duel 2)
  px = ZX, py = PY, pspot = 2, phop_t = 0, phop_from = ZX, phop_to = ZX,
  dash_t = 0, dash_from = ZX, dash_to = ZX, strike = nil,
  bubbles = {}, beam = nil, walk_t = 0, pile_hop = 0, moving = false, prize_t = 0, prize_kind = 0, deco = {},
  TELE_FRAMES = TELE_FRAMES, SHIELD_FRAMES = SHIELD_FRAMES, ZX = ZX, ZY = ZY, PY = PY,
  PUFF_FRAMES = PUFF_FRAMES, SAVE_FRAMES = SAVE_FRAMES, WIN_MIN_FRAMES = WIN_MIN_FRAMES,
  -- the path: purple fairies, his wand's bubbles, what the next one will go for, gold friends following him
  foes = {}, shots = {}, aim = nil, friends = 0, friend_next = 0, trail = {}, path_t = 0, puff_gap = 0,
  stuck = 0, back_line = "", saved_any = false, START_X = START_X, START_Y = START_Y,
  -- the song and how the world answers it (sound and drawing only), and what he has won across visits
  song = "path", sect = 1, run = 0, run_left = 0, best_run = 0, run_line = false, wn = 0, cheer = 0, oops = 0,
  rescued = 0, clean = 0, hurts_round = 0, dirty = false, fresh = false, room_t = 0, room_out = 0,
}
pics.S = S

-- ------------------------------------------------------------------ the music (songs.lua has the arrangements)
-- The song plays the game: the path's band gains a voice for each gold fairy that follows him, the duels turn
-- through three sections (verse, surge at half marks, climax for the last few) with music.play{keep = true},
-- each sword hit is a note of a rising run (music.cue), and the big moments are chords on the bar. Nothing
-- here reads back: game rules never ask music.step(); it only picks the pitch of a cue.
local LV = {1, 1, 1, 1, 1, 1}
local function set_level(i, v)
  if LV[i] ~= v then
    LV[i] = v
    music.track(i, v)
  end
end
local function play(name, song, keep)
  S.song = name
  music.play(song)
  if not keep then for i = 1, 6 do LV[i] = 1 end end
end
local function path_song() play("path", songs.path()) end
local function duel_song(sect, keep)
  S.sect = sect
  play(S.boss, songs.duel(S.boss, sect, keep), keep)
end
-- A note from the chord under the step it will land on, climbing a ladder (n = 0, 1, 2 ...).
local function ladder_note(n, up) return songs.ladder(S.song, music.step() + 1, n) + (up or 0) end
local function cue_note(n, up, vol, wave, dur, at)
  music.cue{wave = wave or "tri", note = ladder_note(n, up), dur = dur or 0.22, vol = vol or 0.22, release = 0.18, at = at}
end
-- A bright chord (root, third, fifth, octave) on the beat or the bar: a stinger.
local function cue_chord(vol, at, up)
  local root, t3 = songs.chord(S.song, music.step() + 1)
  root = root + (up or 0)
  music.cue{wave = "square", duty = 0.25, note = root, dur = 0.45, vol = vol, release = 0.4, at = at}
  music.cue{wave = "tri", note = root + t3, dur = 0.45, vol = vol * 0.9, release = 0.4, at = at}
  music.cue{wave = "tri", note = root + 7, dur = 0.45, vol = vol, release = 0.4, at = at}
  music.cue{wave = "sine", note = root + 12, dur = 0.55, vol = vol * 0.9, release = 0.5, at = at}
end

local function tone(hz, dur, vol) sfx.tone("tri", hz, dur, vol) end
local function notes(m, step, vol) sfx.arp("tri", m, step, vol) end

-- Active boss coordinates (Zam in Duel 1, Pika in Duel 2).
local function boss_xy()
  if S.boss == "pika" then return S.px, S.py end
  return S.zx, S.zy
end

-- ------------------------------------------------------------------ the rules

local function react_to(s) S.react, S.react_left = s, REACT_FRAMES end
local function near_chest() return S.ny < 268 and S.nx > 156 and S.nx < 236 end
local function near_key() return (S.nx - S.key_x) ^ 2 + (S.ny - S.key_y) ^ 2 < 36 * 36 end
-- Zam can be hit when he is all there: not mid-teleport.
local function zam_solid() return S.tele_t == 0 or S.tele_t > TELE_FRAMES - 4 end
-- Pika can be hit when he is not mid-dash.
local function pika_solid() return S.dash_t == 0 end

local function clear_fight()
  S.boss = "zam"
  S.marks, S.pips, S.fight_t, S.telegraph, S.spray, S.surge = 0, 0, 0, 0, false, false
  S.bubbles, S.fairy, S.wrap, S.wrap_alive, S.ring, S.star, S.strike = {}, nil, 0, false, nil, nil, nil
  S.shot_once, S.hurt_cool, S.tele_t, S.shield_t, S.spot, S.zx, S.zy = false, 0, 0, 0, 2, ZX, ZY
  S.shots, S.foes, S.stuck, S.friend_next = {}, {}, 0, 60
  -- He learns a trick for each of the first three gems, and takes three more zaps each time.
  S.level = min(S.gems, 3)
  -- The very first duel on a fresh save is two zaps shorter.
  S.marks_win = MARKS_WIN + 3 * S.level - (S.gems == 0 and 2 or 0)
  S.run, S.run_left, S.run_line = 0, 0, false
end

local function clear_pika()
  S.boss = "pika"
  S.marks, S.pips, S.fight_t, S.telegraph, S.spray, S.surge = 0, 0, 0, 0, false, false
  S.bubbles, S.fairy, S.wrap, S.wrap_alive, S.ring, S.star, S.strike = {}, nil, 0, false, nil, nil, nil
  S.shot_once, S.hurt_cool, S.tele_t, S.shield_t = false, 0, 0, 0
  S.pspot, S.px, S.py, S.phop_t, S.dash_t = 2, ZX, PY, 0, 0
  S.shots, S.stuck, S.friend_next = {}, 0, 100
  S.level = min(S.gems, 3)
  S.marks_win = PIKA_MARKS_WIN + 2 * S.level
  S.run, S.run_left, S.run_line = 0, 0, false
end

local function take_key()
  S.has_key = true
  log("chest key " .. game.frame)
  sfx.note("tri", 84, 0.3, 0.35)
  sfx.note("sine", 96, 0.2, 0.15)
  particles.burst(S.key_x, S.key_y - 20, 18, 2.5, 34, 2.5, C.GOLD, "star")
  cue_chord(0.2, "beat", 0)
  react_to("The key is his.")
end

-- The pile and the room's counters: gems, fairies turned gold, duels won without a hurt, the longest run of zaps.
local function save_all()
  save.set("gems", S.gems)
  save.set("rescued", S.rescued)
  save.set("clean", S.clean)
  save.set("run", S.best_run)
  save.write()
  S.dirty = false
end

-- Sparks that never ask the random generator (so the bot's sequence stays as it was).
local function sparks(x, y, n, speed, life, size, col, kind)
  for i = 0, n - 1 do
    local a = i * 6.2832 / n + (x + y) * 0.013
    particles.spawn(x, y, cos(a) * speed, sin(a) * speed, life, size, col, kind or "star")
  end
end

local function begin_pop()
  if S.phase ~= "path" or not S.has_key then return end
  S.phase, S.boss, S.pop_t = "pop", "zam", 0
  log("chest pop " .. game.frame)
  -- A fairy still turning gold comes along too.
  for _, f in ipairs(S.foes) do
    if f.state == "saving" then
      f.state, S.friends = "gold", S.friends + 1
      particles.burst(f.x, f.y, 16, 2.5, 30, 2.5, C.GOLD, "star")
    end
  end
  notes({72, 76, 79, 84}, 0.08, 0.35)
  gfx.shake(4)
  particles.burst(ZX, 170, 30, 3.5, 40, 3, C.GOLD, "star")
  duel_song(1, false)
  cue_chord(0.22, "beat", 0)
  react_to("Pop! He threw the sword.")
  S.react_left = 80
end

local function begin_zambow()
  S.phase, S.bow_t, S.bend_t = "zambow", 0, 0
  S.bubbles, S.tele_t, S.shield_t, S.ring, S.star, S.fairy, S.wrap, S.wrap_alive = {}, 0, 0, nil, nil, nil, 0, false
  log("chest zambow " .. game.frame)
  notes({72, 76, 79, 84}, 0.09, 0.36)
  particles.burst(S.zx, S.zy, 26, 3.2, 36, 3, C.GOLD, "star")
  S.cheer = 80
  cue_chord(0.24, "beat", 0)
  react_to("Zam bows! What's in the chest?")
end

local function begin_pikapop()
  S.phase, S.boss, S.pop_t, S.pips = "pikapop", "pika", 0, 0
  S.px, S.py = ZX, 166
  log("chest pikapop " .. game.frame)
  sfx.slide("square", 440, 1320, 0.25, 0.25)
  notes({76, 79, 84, 88}, 0.07, 0.34)
  gfx.shake(5)
  particles.burst(ZX, 164, 34, 4, 42, 3.5, C.PIKA, "star")
  duel_song(1, false)
  cue_chord(0.22, "beat", 0)
  react_to("Pika jumped out! Watch the sparks!")
  S.react_left = 90
end

local function begin_win()
  S.phase, S.bow_t, S.bend_t = "winbow", 0, 0
  S.prize_kind, S.prize_t = S.gems % 9, 1
  if S.gems < 100000 then S.gems = S.gems + 1 end
  if S.hurts_round == 0 then
    S.clean = min(S.clean + 1, 100000)
    log("chest clean " .. S.clean)
  end
  save_all()
  log("chest win " .. game.frame)
  log("chest victory " .. game.frame)
  log("chest gems " .. S.gems)
  notes({72, 76, 79, 84, 88, 96}, 0.09, 0.38)
  for i = 1, 44 do
    local col = i % 4 == 0 and C.PIKA or i % 4 == 1 and C.ROSE or i % 4 == 2 and C.CYAN or C.GOLD
    particles.spawn(ZX + rnd(-120, 120), 180 + rnd(-40, 40), rnd(-3.5, 3.5), rnd(-5.5, -1), 90, rnd(3, 5.5), col,
      i % 3 == 0 and "heart" or i % 2 == 0 and "star" or "square", 0.12, 0.99, 0.12)
  end
  S.bubbles, S.tele_t, S.shield_t, S.ring, S.star, S.fairy, S.strike = {}, 0, 0, nil, nil, nil, nil
  S.wrap, S.wrap_alive, S.dash_t = 0, false, 0
  S.zx, S.zy = 104, 134
  S.px, S.py = 280, 158
  play("win", songs.win())
  cue_chord(0.26, "bar", 0)
  S.cheer = 400
  react_to("You beat Zam and Pika!")
end

local function add_marks(n, big, shot)
  S.marks = S.marks + n
  S.spoon_flash, S.flinch_t = 16, 14
  local bx, by = boss_xy()
  if shot then
    -- Each hit is the next note of a run (a pause of a second and a half starts it over); a hurt ends it.
    S.run, S.run_left = S.run + 1, 90
    if S.run > S.best_run then S.best_run, S.dirty = S.run, true end
    if not big then cue_note(S.run - 1, 0, 0.2, "tri", 0.2, "step") end
    if S.run % 7 == 0 then
      log("chest tune " .. S.run)
      S.cheer = 70
      sparks(S.nx, S.ny - 40, 10, 2.2, 28, 2.5, C.GOLD, "star")
      cue_chord(0.2, "step", 12)
    elseif S.run == 4 and not S.run_line then
      S.run_line = true
      S.react, S.react_left = "Zap, zap, zap! Every zap is a note.", REACT_FRAMES
    end
  end
  if big then
    log("chest big")
    cue_chord(0.24, "step", 0)
    notes({79, 84}, 0.07, 0.4)
    gfx.shake(5)
    S.dizzy_t = 70
    particles.burst(bx, by, 34, 4, 40, 3, C.GOLD, "star")
    particles.text(bx, by - 72, C.GOLD, "+" .. n)
    react_to("The big bubble popped!")
  else
    log("chest mark " .. S.marks)
    sfx.slide("square", 900, 600, 0.08, 0.18)
    particles.burst(bx, by - 10, 10, 2, 24, 2, C.CREAM, "star")
    react_to(S.boss == "pika" and "The sword zapped Pika!" or "The sword zapped him.")
  end
  -- Halfway surge: bosses get extra lively at half marks.
  if not S.surge and S.marks >= idiv(S.marks_win, 2) and S.marks < S.marks_win then
    S.surge = true
    sfx.arp("sine", {72, 76, 79, 84}, 0.05, 0.25)
    particles.burst(bx, by, 22, 3, 30, 3, S.boss == "pika" and C.PIKA or C.PURPLE, "star")
    react_to(S.boss == "pika" and "Pika is super charged!" or "Zam is powering up!")
  end
  if S.marks >= S.marks_win then
    if S.phase == "fight" then
      begin_zambow()
    elseif S.phase == "pika" then
      begin_win()
    end
  end
end

-- Three purple hurts on the path: a soft start-over. The key floats back to its spot, he
-- hops back to the start, the gold friends he made stay with him.
local function path_back()
  S.phase, S.bow_t = "pathback", 0
  S.back_line = S.has_key and "Pop! The key went back." or "Pop! Back to the start."
  log("chest pathback " .. game.frame)
  notes({79, 76}, 0.14, 0.3)
  if S.has_key then
    S.has_key = false
    particles.burst(S.key_x, S.key_y - 20, 18, 2.5, 34, 2.5, C.GOLD, "star")
  end
  S.bubbles, S.shots = {}, {}
end

local function hurt()
  local on_path = S.phase == "path"
  local in_duel = S.phase == "fight" or S.phase == "pika"
  if (not in_duel and not on_path) or S.hurt_cool > 0 then return end
  S.pips = S.pips + 1
  S.hurts_round, S.run, S.run_left, S.oops = S.hurts_round + 1, 0, 0, 40
  if on_path then
    -- A purple bubble wraps him for half a second, then pops; he blinks a while after.
    S.hurt_cool, S.stuck = 90, STUCK_FRAMES
  else
    S.hurt_cool = 44
    S.ny = min(S.ny + 16, 450)
  end
  log(fmt("chest hurt %d %d", S.pips, game.frame))
  sfx.slide("tri", 300, 110, 0.25, 0.35)
  gfx.shake(4)
  particles.burst(S.nx, S.ny - 10, 14, 2.5, 30, 3, C.PURPLE, "ring")
  if on_path then
    if S.pips >= 3 then path_back() else react_to("A purple bubble got him.") end
  elseif S.pips >= 3 then
    S.phase, S.bow_t = "restart", 0
    log("chest restart " .. game.frame)
    notes({79, 76}, 0.14, 0.3)
    react_to("Pop. The sword stayed.")
  else
    react_to(S.boss == "pika" and "Zap! That spark got him." or "That bubble got him.")
  end
end

-- A purple fairy is rescued: wrapped in his bubble, she spins, turns gold, and follows him.
local function save_fairy(f)
  f.state, f.save_t, f.tele = "saving", SAVE_FRAMES, 0
  S.saved_any = true
  S.rescued, S.dirty = min(S.rescued + 1, 100000), true
  log("chest rescue " .. game.frame)
  sfx.slide("sine", 600, 1200, 0.15, 0.2)
  particles.burst(f.x, f.y, 12, 2, 24, 2.5, C.AQUA, "dot")
end

-- What the next wand bubble will go for: a purple bubble coming at him, else the nearest
-- purple fairy, else nothing (it flies the way he faces).
local function pick_aim()
  local best, bd = nil, 150 * 150
  for _, b in ipairs(S.bubbles) do
    local dx, dy = S.nx - b.x, S.ny - b.y
    local d = dx * dx + dy * dy
    if d < bd and dx * b.vx + dy * b.vy > 0 then best, bd = b, d end
  end
  if best then return best end
  bd = 1e9
  for _, f in ipairs(S.foes) do
    if f.state == "purple" then
      local d = (S.nx - f.x) ^ 2 + (S.ny - f.y) ^ 2
      if d < bd then best, bd = f, d end
    end
  end
  return best
end

-- Before the sword: the wand. A bubble the game aims; it can also tap the key and the lock.
local function wand()
  log("chest bolt")
  sfx.slide("sine", 700, 1150, 0.1, 0.2)
  S.wn = S.wn + 1
  cue_note(S.wn % 7, 0, 0.1, "sine", 0.16, "step")
  local x, y = S.nx + (S.face_x ~= 0 and S.face_x * 14 or -14), S.ny - 14
  local tgt = pick_aim()
  local vx, vy
  if tgt then
    local dx, dy = tgt.x - x, tgt.y - y
    local d = max(1, sqrt(dx * dx + dy * dy))
    vx, vy = dx / d * WAND_SPEED, dy / d * WAND_SPEED
  else
    local fx, fy = S.face_x, S.face_y
    if fx == 0 and fy == 0 then fy = -1 end
    vx, vy = fx * WAND_SPEED, fy * WAND_SPEED
  end
  if #S.shots >= WAND_MAX then table.remove(S.shots, 1) end
  S.shots[#S.shots + 1] = {x = x, y = y, vx = vx, vy = vy, tgt = tgt, life = WAND_LIFE}
  particles.burst(x, y, 5, 1.2, 14, 2, C.AQUA, "dot")
end

local function pop_at(x, y, c)
  sfx.tone("sine", 1250, 0.05, 0.16)
  cue_note(4, 12, 0.12, "sine", 0.18, "step")
  particles.burst(x, y, 10, 2, 18, 2, c, "dot")
end

-- His bubbles: they steer to what they were aimed at while it is still there.
local function step_shots()
  for _, s in ipairs(S.shots) do
    local t = s.tgt
    if t and not t.gone and (t.state == nil or t.state == "purple") then
      local dx, dy = t.x - s.x, t.y - s.y
      local d = max(1, sqrt(dx * dx + dy * dy))
      s.vx, s.vy = lerp(s.vx, dx / d * WAND_SPEED, 0.25), lerp(s.vy, dy / d * WAND_SPEED, 0.25)
    end
    s.x, s.y, s.life = s.x + s.vx, s.y + s.vy, s.life - 1
    for _, b in ipairs(S.bubbles) do
      if not b.gone and (b.x - s.x) ^ 2 + (b.y - s.y) ^ 2 < 30 * 30 then
        b.gone, s.gone = true, true
        log("chest popped " .. game.frame)
        pop_at(b.x, b.y, C.PURPLE)
        break
      end
    end
    if not s.gone then
      for _, f in ipairs(S.foes) do
        if f.state == "purple" and (f.x - s.x) ^ 2 + (f.y - s.y) ^ 2 < 30 * 30 then
          s.gone = true
          save_fairy(f)
          break
        end
      end
    end
    -- A bubble with nothing to aim at (blown the way he faces) can also tap the key and the lock.
    if not s.gone and S.phase == "path" and not s.tgt then
      if not S.has_key and (s.x - S.key_x) ^ 2 + (s.y - S.key_y + 16) ^ 2 < 30 * 30 then
        s.gone = true
        take_key()
      elseif S.has_key and s.y < 200 and s.x > 156 and s.x < 236 then
        s.gone = true
        begin_pop()
      end
    end
    if not s.gone and (s.life <= 0 or s.x < -20 or s.x > W + 20 or s.y < -20 or s.y > H - 30) then
      s.gone = true
      pop_at(s.x, s.y, C.AQUA)
    end
  end
  sweep(S.shots, function(s) return not s.gone end)
end

-- Purple bubbles & electric orbs drift until they touch him.
local function step_bubbles(reach)
  for _, b in ipairs(S.bubbles) do
    if not b.gone then
      b.x, b.y = b.x + b.vx, b.y + b.vy
      if (b.x - S.nx) ^ 2 + (b.y - S.ny) ^ 2 < reach * reach then
        b.gone = true
        hurt()
      elseif b.y > H - 40 or b.y < -20 or b.x < 0 or b.x > W then
        b.gone = true
      end
    end
  end
  sweep(S.bubbles, function(b) return not b.gone end)
end

-- A new walk to the key: purple fairies (one more for each gem, up to three), one guarding the key.
local function setup_path()
  S.foes, S.shots, S.bubbles, S.friends, S.pips, S.path_t, S.puff_gap = {}, {}, {}, 0, 0, 0, 0
  S.saved_any, S.stuck, S.trail, S.boss = false, 0, {}, "zam"
  local n = min(1 + S.gems, 3)
  local spots = {{S.key_x, S.key_y - 76}}
  for _, p in ipairs(FOE_SPOTS) do
    local far_key = (p[1] - S.key_x) ^ 2 + (p[2] - S.key_y) ^ 2 > 90 * 90
    local far_start = (p[1] - START_X) ^ 2 + (p[2] - START_Y) ^ 2 > 110 * 110
    if far_key and far_start then spots[#spots + 1] = p end
  end
  for i = 1, n do
    local p = spots[i]
    S.foes[i] = {hx = p[1], hy = p[2], x = p[1], y = p[2], ph = i * 2.1, state = "purple", tele = 0,
      cool = PATH_GRACE + (i - 1) * 55, save_t = 0}
  end
  log("chest fairies " .. n)
end

local function step_foes()
  S.path_t = S.path_t + 1
  if S.puff_gap > 0 then S.puff_gap = S.puff_gap - 1 end
  local period = S.gems == 0 and 170 or 140
  for _, f in ipairs(S.foes) do
    if f.state == "purple" then
      -- Hover round her spot.
      local t = S.path_t
      f.x = f.hx + sin(t * 0.021 + f.ph) * 30
      f.y = f.hy + sin(t * 0.033 + f.ph * 1.7) * 14
      if f.tele > 0 then
        f.tele = f.tele - 1
        if f.tele == 0 then
          local a = atan2(S.ny - f.y, S.nx - f.x)
          S.bubbles[#S.bubbles + 1] = {x = f.x, y = f.y + 8, vx = cos(a) * PUFF_SPEED, vy = sin(a) * PUFF_SPEED}
          sfx.slide("sine", 500, 300, 0.2, 0.15)
          log("chest puff " .. game.frame)
          f.cool = period
        end
      elseif f.cool > 0 then
        f.cool = f.cool - 1
      else
        -- She warns before she blows, never two at once, never point-blank, never while he blinks.
        local d2 = (S.nx - f.x) ^ 2 + (S.ny - f.y) ^ 2
        if S.puff_gap == 0 and S.hurt_cool == 0 and d2 > 80 * 80 and d2 < 300 * 300 then
          f.tele, S.puff_gap = PUFF_FRAMES, PUFF_GAP + PUFF_FRAMES
          sfx.slide("sine", 300, 620, 0.45, 0.1)
        else
          f.cool = 20
        end
      end
    elseif f.state == "saving" then
      f.save_t = f.save_t - 1
      f.y = f.y - 0.4
      if f.save_t <= 0 then
        f.state = "gold"
        S.friends = S.friends + 1
        log("chest friends " .. S.friends)
        cue_note(S.friends + 2, 0, 0.2, "sine", 0.4, "step")
        cue_note(S.friends + 4, 0, 0.14, "sine", 0.4, "step")
        notes({76, 79, 84}, 0.07, 0.3)
        particles.burst(f.x, f.y, 16, 2.5, 30, 2.5, C.GOLD, "star")
        react_to("She's a gold fairy now!")
      end
    end
  end
  sweep(S.foes, function(f) return f.state ~= "gold" end)
end

-- With the sword: a laser that flies at the active boss. A shield stops it, a teleport/dash lets it pass.
local function laser()
  local sx, sy = S.nx, S.ny - 12
  local bx, by = boss_xy()
  log("chest bolt")
  snd.zap()
  S.beam = {x0 = sx, y0 = sy, x1 = bx, y1 = by, t = 10, blocked = false}
  S.shot_once = true
  if S.phase ~= "fight" and S.phase ~= "pika" then return end
  -- A purple fairy close to him comes first: the laser bubbles her and she turns gold.
  if S.fairy == "purple" and (S.fairy_x - sx) ^ 2 + (S.fairy_y - sy) ^ 2 < 140 * 140 then
    S.beam.x1, S.beam.y1 = S.fairy_x, S.fairy_y
    S.fairy, S.friends = nil, S.friends + 1
    S.rescued, S.dirty = min(S.rescued + 1, 100000), true
    S.friend_next = max(S.friend_next, S.fight_t + 80)
    log("chest rescue " .. game.frame)
    notes({76, 79, 84}, 0.07, 0.3)
    particles.burst(S.fairy_x, S.fairy_y, 16, 2.5, 30, 2.5, C.GOLD, "star")
    react_to("She's a gold fairy now!")
    return
  end
  if S.phase == "fight" then
    if not zam_solid() then
      S.beam.x1, S.beam.y1 = trunc(sx + (bx - sx) * 1.6), 8
      S.splash = {S.beam.x1, S.beam.y1}
      return
    end
    if S.shield_t > 0 and S.wrap == 0 then
      local k = (sy - (by + 62)) / (sy - by)
      S.beam.x1, S.beam.y1, S.beam.blocked = trunc(sx + (bx - sx) * k), by + 62, true
      S.splash = {S.beam.x1, S.beam.y1}
      sfx.note("sine", 100, 0.15, 0.2)
      react_to("His shield is up. Wait.")
      log("chest blocked")
      return
    end
  elseif S.phase == "pika" then
    if not pika_solid() then
      S.beam.x1, S.beam.y1 = trunc(sx + (bx - sx) * 1.4), 12
      S.splash = {S.beam.x1, S.beam.y1}
      return
    end
  end
  if S.wrap > 0 then
    S.wrap, S.wrap_alive = 0, false
    add_marks(2, true, true)
  else
    add_marks(1, false, true)
  end
end

local function fire()
  if S.has_sword and S.phase ~= "path" then laser() else wand() end
  if S.splash then particles.burst(S.splash[1], S.splash[2], 8, 2, 18, 2, S.beam.blocked and C.CYAN or C.CREAM, "dot") end
end

local function spawn_bubbles()
  local n = S.spray and 3 or 1
  for k = 0, n - 1 do
    local bx, by = S.zx + (k - (n - 1) / 2) * 30, S.zy - 30
    local a = atan2(S.ny - by, S.nx - bx) + (k - (n - 1) / 2) * 0.38
    S.bubbles[#S.bubbles + 1] = {x = bx, y = by, vx = cos(a) * 2.3, vy = sin(a) * 2.3}
  end
  sfx.slide("sine", 500, 300, 0.2, 0.2)
end

local function spawn_sparks()
  local n = S.spray and 2 or 1
  for k = 0, n - 1 do
    local bx, by = S.px + (k - (n - 1) / 2) * 26, S.py + 4
    local a = atan2(S.ny - by, S.nx - bx) + (k - (n - 1) / 2) * 0.32
    S.bubbles[#S.bubbles + 1] = {x = bx, y = by, vx = cos(a) * 2.4, vy = sin(a) * 2.4, spark = true}
  end
  sfx.slide("square", 900, 420, 0.16, 0.18)
end

local function begin_teleport()
  local to
  repeat to = rndi(1, 3) until to ~= S.spot
  S.tele_t, S.tele_to = TELE_FRAMES, to
  sfx.slide("sine", 400, 1600, 0.25, 0.2)
  react_to("Zam jumped! Find him.")
  log("chest teleport " .. (to - 1))
end

local function wrap_him(x, y, kind, line)
  S.wrap, S.wrap_alive = WRAP_FRAMES, true
  S.bubbles, S.telegraph, S.shield_t, S.dash_t = {}, 0, 0, 0
  log("chest wrap " .. game.frame)
  sfx.note("sine", 88, 0.4, 0.3)
  particles.burst(x, y, 16, 2.5, 30, 2.5, C.GOLD, kind)
  react_to(line)
end

local function step_to_int(v, d, max_step) return v + (d > max_step and max_step or d < -max_step and -max_step or d) end

-- Shared fairy, ring, and star logic for both Zam and Pika duels.
local function step_duel_fairies()
  local bx, by = boss_xy()
  local solid = S.boss == "pika" and pika_solid() or zam_solid()
  local bname = S.boss == "pika" and "Pika" or "Zam"
  if not S.fairy and S.wrap == 0 and not S.ring and not S.star then
    local t = S.fight_t
    if S.friends > 0 and t >= S.friend_next then
      local f = table.remove(S.trail, S.friends) or {S.nx, S.ny - 20}
      S.fairy, S.fairy_x, S.fairy_y = "gold", floor(f[1]), floor(f[2])
      S.friends, S.friend_next = S.friends - 1, t + 330
      log("chest friend " .. game.frame)
      react_to("His gold fairy flies to " .. bname .. "!")
    elseif t == 70 or t == 480 then S.fairy, S.fairy_x, S.fairy_y = "gold", 40, 180
    elseif t == 270 then S.fairy, S.fairy_x, S.fairy_y = "blue", 340, 240
    elseif (S.shot_once and t == 200) or t == 540 then S.fairy, S.fairy_x, S.fairy_y = "purple", 48, 300 end
    if S.fairy then sfx.note("sine", S.fairy == "purple" and 67 or 88, 0.2, 0.18) end
  end
  if S.fairy == "gold" then
    local dx, dy = trunc(bx) - S.fairy_x, trunc(by) + 10 - S.fairy_y
    S.fairy_x, S.fairy_y = step_to_int(S.fairy_x, dx, 4), step_to_int(S.fairy_y, dy, 4)
    if abs(dx) < 14 and abs(dy) < 14 and solid then
      S.fairy = nil
      wrap_him(bx, by, "glow", "Gold fairy has " .. (S.boss == "pika" and "Pika!" or "him."))
    end
  elseif S.fairy then
    local dx, dy = S.nx - S.fairy_x, S.ny - S.fairy_y
    S.fairy_x, S.fairy_y = step_to_int(S.fairy_x, dx, 3), step_to_int(S.fairy_y, dy, 3)
    if abs(dx) < 14 and abs(dy) < 14 then
      S.ring = {x = S.nx, y = S.ny, r = 8, safe = S.fairy == "blue"}
      S.fairy = nil
    end
  end
  local ring = S.ring
  if ring then
    local inside = (S.nx - ring.x) ^ 2 + (S.ny - ring.y) ^ 2 < (ring.r + 6) ^ 2
    if not ring.safe and not inside then
      S.ring = nil
      tone(880, 0.08, 0.25)
      particles.burst(ring.x, ring.y, 12, 2, 20, 2, C.PURPLE, "dot")
    elseif ring.safe and ring.r > 22 then
      S.ring = nil
      S.star = {x = S.nx < 60 and S.nx + 28 or S.nx - 28, y = S.ny, life = 180}
      log("chest star " .. game.frame)
      notes({76, 79}, 0.1, 0.3)
      particles.burst(S.nx, S.ny, 14, 2.5, 24, 2, C.BLUE, "dot")
      react_to("Walk over the star.")
    elseif not ring.safe and ring.r > 26 and inside then
      S.ring = nil
      hurt()
    else
      ring.r = ring.r + 1
      if not ring.safe and ring.r % 4 == 0 then sfx.tone("sine", 300 + ring.r * 12, 0.06, 0.08) end
    end
  end
  local star = S.star
  if star then
    if (S.nx - star.x) ^ 2 + (S.ny - star.y) ^ 2 < 22 * 22 then
      S.star, S.tele_t, S.dash_t = nil, 0, 0
      wrap_him(star.x, star.y, "star", "The star wrapped " .. (S.boss == "pika" and "Pika!" or "him."))
    else
      star.life = star.life - 1
      if star.life <= 0 then S.star = nil end
    end
  end
end

local function fight_step()
  S.fight_t = S.fight_t + 1
  if S.wrap > 0 then
    S.wrap = S.wrap - 1
    if S.wrap == 0 and S.wrap_alive then
      S.wrap_alive = false
      add_marks(1, false)
    end
  end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.spoon_flash > 0 then S.spoon_flash = S.spoon_flash - 1 end
  if S.phase ~= "fight" then return end
  -- At half marks, Zam gently drifts left and right around his spot when not teleporting.
  if S.surge and S.tele_t == 0 and S.wrap == 0 then
    S.zx = clamp(SPOTS[S.spot] + sin(S.fight_t * 0.03) * 34, 84, W - 84)
  elseif S.tele_t == 0 then
    S.zx = approach(S.zx, SPOTS[S.spot], 0.15)
  end
  local len = S.level == 0 and (S.surge and 120 or 150) or 300
  local c = S.fight_t % len
  if S.tele_t > 0 then
    S.tele_t = S.tele_t - 1
    if S.tele_t == idiv(TELE_FRAMES, 2) then
      S.spot = S.tele_to
      S.zx = SPOTS[S.spot]
      particles.burst(S.zx, S.zy, 16, 2, 26, 2.5, 0xc8a8ff, "star")
    end
  elseif S.level >= 1 and c == (S.level >= 2 and 250 or 180) and S.wrap == 0 then
    begin_teleport()
  end
  if S.shield_t > 0 then
    S.shield_t = S.shield_t - 1
    if S.wrap > 0 then S.shield_t = 0 end
  elseif S.level >= 2 and c == 150 and S.wrap == 0 and S.tele_t == 0 then
    S.shield_t = SHIELD_FRAMES
    sfx.note("sine", 88, 0.3, 0.25)
    sfx.note("sine", 95, 0.3, 0.12)
    react_to("His shield is up. Wait.")
    log("chest shield")
  end
  if S.telegraph > 0 then
    S.telegraph = S.telegraph - 1
    if S.telegraph == 0 then spawn_bubbles() end
  elseif S.wrap == 0 and not S.fairy and S.tele_t == 0 and c == 40 then
    S.telegraph = 30
    S.spray = S.level >= 3 and idiv(S.fight_t, len) % 2 == 1
    tone(S.spray and 587 or 659, 0.12, 0.2)
    if S.spray then react_to("Three bubbles! Step away.") end
  end
  step_bubbles(28)
  step_duel_fairies()
end

local function pika_step()
  S.fight_t = S.fight_t + 1
  if S.wrap > 0 then
    S.wrap = S.wrap - 1
    if S.wrap == 0 and S.wrap_alive then
      S.wrap_alive = false
      add_marks(1, false)
    end
  end
  if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
  if S.spoon_flash > 0 then S.spoon_flash = S.spoon_flash - 1 end
  if S.phase ~= "pika" then return end

  -- Bouncy hop between spots.
  if S.phop_t > 0 then
    S.phop_t = S.phop_t - 1
    local k = 1 - S.phop_t / 24
    S.px = lerp(S.phop_from, S.phop_to, k)
    S.py = PY - sin(k * math.pi) * 26
    if S.phop_t == 0 then
      S.px, S.py = S.phop_to, PY
      particles.burst(S.px, S.py + 24, 6, 1.5, 16, 2, C.PIKA, "dot")
    end
  end
  -- Quick electric dash across the top (invincible during the streak).
  if S.dash_t > 0 then
    S.dash_t = S.dash_t - 1
    local k = 1 - S.dash_t / 30
    S.px = lerp(S.dash_from, S.dash_to, ease.in_out(k))
    S.py = PY - sin(k * math.pi) * 14
    if S.dash_t % 3 == 0 then particles.spawn(S.px, S.py, 0, 0, 18, 3, C.PIKA, "star") end
    if S.dash_t == 0 then
      S.px, S.py = S.dash_to, PY
      particles.burst(S.px, S.py, 12, 2.2, 22, 2.5, C.PIKA, "star")
    end
  end

  local len = S.surge and 200 or 240
  local c = S.fight_t % len
  -- Move 1: Thunder Spark (aimed purple-electric orb).
  if S.telegraph > 0 then
    S.telegraph = S.telegraph - 1
    if S.telegraph == 0 then spawn_sparks() end
  elseif S.wrap == 0 and S.dash_t == 0 and c == 36 then
    S.telegraph = 32
    S.spray = S.level >= 2 or S.surge
    sfx.slide("square", 620, 980, 0.14, 0.14)
    react_to("Pika's cheeks are glowing!")
  end

  -- Move 2: Lightning Strike (ground target ring -> bolt from the sky!).
  if S.strike then
    local st = S.strike
    if st.t > 0 then
      st.t = st.t - 1
      if st.t % 12 == 0 then sfx.tone("sine", 440 + (68 - st.t) * 8, 0.06, 0.1) end
      if st.t == 0 then
        st.flash = 16
        sfx.noise(0.18, 0.25, 3200)
        sfx.slide("square", 1100, 180, 0.2, 0.22)
        gfx.shake(4)
        particles.burst(st.x, st.y, 20, 3, 28, 3, C.PIKA, "star")
        if (S.nx - st.x) ^ 2 + (S.ny - st.y) ^ 2 < 34 * 34 then hurt() end
      end
    elseif st.flash > 0 then
      st.flash = st.flash - 1
      if st.flash == 0 then S.strike = nil end
    end
  elseif S.wrap == 0 and S.dash_t == 0 and c == 120 then
    S.strike = {x = S.nx, y = S.ny, t = 68, flash = 0}
    log("chest strike " .. game.frame)
    sfx.slide("sine", 500, 1000, 0.2, 0.15)
    react_to("Lightning! Step out of the ring!")
  end

  -- Move 3: Hop or Quick Dash to a new spot.
  if S.wrap == 0 and S.phop_t == 0 and S.dash_t == 0 and S.telegraph == 0 and c == 175 then
    local to
    repeat to = rndi(1, 3) until to ~= S.pspot
    S.pspot = to
    if S.surge or S.level >= 1 then
      S.dash_t, S.dash_from, S.dash_to = 30, S.px, PIKA_SPOTS[to]
      log("chest dash " .. game.frame)
      sfx.slide("square", 600, 1500, 0.2, 0.18)
      react_to("Pika zipped away!")
    else
      S.phop_t, S.phop_from, S.phop_to = 24, S.px, PIKA_SPOTS[to]
      sfx.slide("sine", 520, 880, 0.12, 0.16)
    end
  end

  step_bubbles(26)
  step_duel_fairies()
end

-- The layers follow what is happening (music.track only on a change). The path: the band gains a voice for each
-- gold fairy that follows him. The duels: sections by marks (verse, surge at half, climax for the last few), the
-- choir is his gold fairies still to fly (or the one wrapping the boss). The bow is a hush before the next song.
local function mix()
  local ph, f = S.phase, S.friends
  if ph == "path" or ph == "pathback" or ph == "pop" then
    set_level(1, S.stuck > 0 and 0.25 or #S.bubbles > 0 and 0.7 or S.has_key and 1.15 or 0.9)
    set_level(3, S.has_key and 1 or 0)
    set_level(4, f >= 1 and (f >= 4 and 1.35 or 1) or 0)
    set_level(5, f >= 2 and (f >= 5 and 1.35 or 1) or 0)
    set_level(6, f >= 3 and 1 or 0)
  elseif ph == "winbow" then
    set_level(5, f >= 1 and 1.1 or 0.5)
    set_level(6, f >= 2 and 1.1 or 0.5)
  elseif ph == "zambow" then
    set_level(1, 0.6) set_level(2, 0.9) set_level(3, 0) set_level(4, 0) set_level(5, 1.3) set_level(6, 1.2)
  elseif ph == "fight" or ph == "pika" or ph == "restart" or ph == "pikapop" then
    if ph == "fight" or ph == "pika" then
      local want = S.marks >= S.marks_win - 3 and 3 or S.surge and 2 or 1
      if want ~= S.sect then duel_song(want, true) end
    end
    local shield = ph == "fight" and S.shield_t > 0
    set_level(1, ph == "restart" and 0.3 or S.hurt_cool > 0 and 0.4 or shield and 0.5 or S.wrap > 0 and 1.15 or 0.95)
    set_level(2, 1)
    set_level(3, ph == "restart" and 0.4 or shield and 0.5 or 1)
    set_level(4, S.sect >= 2 and 1 or 0)
    set_level(5, 0.9)
    set_level(6, S.wrap > 0 and 1.25 or min(1.1, f * 0.45))
  end
end

local function leaving() return input.down("1p") and input.down("2p") end

local function rest_line()
  if leaving() then return "The gems will stay." end
  local p = S.phase
  if p == "pop" then return "Pop! He threw the sword." end
  if p == "zambow" then return "Zam bows! What's in the chest?" end
  if p == "pikapop" then return "Pika jumped out! Watch the sparks!" end
  if p == "winbow" then
    if S.bow_t >= WIN_MIN_FRAMES then return "You did it! Press to play again!" end
    return "You beat Zam and Pika!"
  end
  if p == "restart" then return "Pop. The sword stayed." end
  if p == "pathback" then return S.back_line end
  if p == "pika" then
    if S.dash_t > 0 then return "Pika zipped away!" end
    if S.strike and S.strike.t > 0 then return "Lightning! Step out of the ring!" end
    if S.telegraph > 0 then return "Pika's cheeks are glowing!" end
    if S.wrap > 0 then return "Gold fairy has Pika!" end
    if S.ring and S.ring.safe then return "A blue bubble. Catch it." end
    if S.star then return "Walk over the star." end
    if S.ring then return "Purple. Step out of it." end
    return "Pika! Watch out for sparks."
  end
  if p == "fight" then
    if S.tele_t > 0 then return "Zam jumped! Find him." end
    if S.telegraph > 0 then return S.spray and "Three bubbles! Step away." or "A bubble is coming." end
    if S.wrap > 0 then return "Gold fairy has him." end
    if S.shield_t > 0 then return "His shield is up. Wait." end
    if S.ring and S.ring.safe then return "A blue bubble. Catch it." end
    if S.star then return "Walk over the star." end
    if S.ring then return "Purple. Step out of it." end
    if not S.shot_once then return "The sword can zap him." end
    return "Gold one. He's the boss."
  end
  if S.stuck > 0 then return "A purple bubble got him." end
  for _, f in ipairs(S.foes) do
    if f.tele > 0 then return "She's blowing a bubble. Step away." end
  end
  if #S.bubbles > 0 then return "A purple bubble! Pop it." end
  if #S.foes > 0 and not S.saved_any then return "Purple fairy! Bubble her." end
  if not S.has_key then
    if S.hop > 0 then return "The lock wants the key." end
    local dx, dy = input.dir()
    if dx ~= 0 or dy ~= 0 then return "He walks to the key." end
    return "The key is glowing."
  end
  return "Now walk to the chest."
end

-- ------------------------------------------------------------------ the built-in player (tests, the reel)

function bot()
  local tx, ty = S.nx, S.ny
  if S.phase == "path" then
    tx, ty = S.has_key and ZX or S.key_x, S.has_key and 240 or S.key_y
  elseif S.phase == "fight" or S.phase == "pika" then
    local bx = S.boss == "pika" and S.px or S.zx
    tx, ty = trunc(bx) + (sin(game.frame * 0.014) > 0 and -44 or 44), 400
    if S.star then tx, ty = S.star.x, S.star.y end
    if S.strike and S.strike.t > 0 then
      tx, ty = S.strike.x + (S.strike.x < ZX and 80 or -80), S.strike.y
    end
    if S.ring and not S.ring.safe then tx, ty = S.ring.x + (S.ring.x < ZX and 80 or -80), S.ring.y end
    for _, b in ipairs(S.bubbles) do
      if abs(b.x - S.nx) < 52 and b.y < S.ny then tx = S.nx + (b.x < S.nx and 72 or -72) end
    end
  elseif S.phase == "winbow" then
    if S.bow_t >= WIN_MIN_FRAMES + 10 and game.frame % 4 == 0 then input.bot("low") end
    return
  else
    return
  end
  if not (abs(tx - S.nx) < 6 and abs(ty - S.ny) < 6) then
    if tx < S.nx - 2 then input.bot("left") end
    if tx > S.nx + 2 then input.bot("right") end
    if ty < S.ny - 2 then input.bot("up") end
    if ty > S.ny + 2 then input.bot("down") end
  end
  -- With the sword, shoot whenever the boss is open.
  if S.phase == "fight" and S.shield_t == 0 and game.frame % 2 == 1 then input.bot("low") end
  if S.phase == "pika" and S.dash_t == 0 and game.frame % 2 == 1 then input.bot("low") end
  -- On the path, blow bubbles whenever there is something to aim at.
  if S.phase == "path" and S.aim and game.frame % 2 == 1 then input.bot("low") end
end

-- ------------------------------------------------------------------ the cart

function init()
  sfx.master(0.32)
  sfx.limit(8000)
  S.gems = clamp(save.get("gems", 0), 0, 100000)
  S.rescued = clamp(save.get("rescued", 0), 0, 100000)
  S.clean = clamp(save.get("clean", 0), 0, 100000)
  S.best_run = clamp(save.get("run", 0), 0, 999)
  S.fresh = S.gems == 0 and S.rescued == 0 and S.clean == 0
  log("chest gems " .. S.gems)
  for i = 1, 40 do
    local x
    repeat x = rnd(16, W - 16) until not (x > 128 and x < 256)
    S.deco[i] = {x, rnd(80, H - 32 - 8), rndi(0, 4)}
  end
  setup_path()
  path_song()
  -- The treasure room is shown first (pictures.lua draws it over the meadow while he starts to walk).
  S.react = S.fresh and "Get the key. Open the chest. Win treasure!" or "Ned's treasure room. Now, the key!"
  S.react_left = 200
end

local function start_next_round()
  S.phase, S.has_key, S.has_sword, S.bend_t = "path", false, false, 0
  clear_fight()
  local k = KEY_SPOTS[rndi(2, 5)]
  S.key_x, S.key_y = k[1], k[2]
  S.hurts_round = 0
  setup_path()
  path_song()
  S.react, S.react_left = "The key is back. Go on.", REACT_FRAMES
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  S.splash = nil
  if not held then S.saw_release = true end
  S.moving = false
  if S.phase == "pop" or S.phase == "pikapop" then
    -- He hops back to the fighting line while the boss unfolds.
    S.nx = S.nx + trunc((ZX - S.nx) * 0.08)
    if S.ny < 400 then S.ny = S.ny + 3 end
  elseif S.phase == "winbow" then
    -- Ned trots proudly to center stage for the victory celebration!
    S.nx = approach(S.nx, ZX, 0.08)
    S.ny = approach(S.ny, 376, 0.08)
  elseif S.phase ~= "zambow" and S.phase ~= "restart" and S.phase ~= "pathback" and S.stuck == 0 then
    local top = (S.phase == "fight" or S.phase == "pika") and FIGHT_TOP or 230
    S.nx = clamp(S.nx + mx * SPEED, 24, W - 24)
    S.ny = clamp(S.ny + my * SPEED, top, 450)
    if mx ~= 0 or my ~= 0 then
      S.moving = true
      S.walk_t = S.walk_t + 1
      S.face_x, S.face_y = mx, my
      if mx ~= 0 and my ~= 0 then S.face_x = 0 end
      if S.walk_t % 16 == 0 then particles.spawn(S.nx, S.ny + 32, rnd(-0.5, 0.5), -0.3, 18, 2.5, alpha(0xe8f0d0, 160), "dot") end
    end
  end
  -- His gold friends drift after him, one each side, a little behind (or dance in a ring on victory).
  for k = 1, min(S.friends, 5) do
    local f = S.trail[k]
    if not f then
      f = {S.nx, S.ny - 30}
      S.trail[k] = f
    end
    if S.phase == "winbow" then
      local a = game.frame * 0.07 + k * (tau / max(1, min(S.friends, 5)))
      f[1] = approach(f[1], S.nx + cos(a) * 52, 0.12)
      f[2] = approach(f[2], S.ny - 10 + sin(a) * 28, 0.12)
    else
      local side = k % 2 == 1 and 30 or -30
      f[1] = approach(f[1], S.nx + side, 0.06 / k + 0.02)
      f[2] = approach(f[2], S.ny - 18 + k * 6, 0.06 / k + 0.02)
    end
  end
  if S.stuck > 0 then S.stuck = S.stuck - 1 end
  if S.phase == "path" then
    if S.hurt_cool > 0 then S.hurt_cool = S.hurt_cool - 1 end
    step_foes()
    step_bubbles(22)
  end
  if S.phase == "path" or S.phase == "pop" then step_shots() end
  if S.phase == "path" then S.aim = pick_aim() else S.aim = nil end
  if not S.has_key and S.phase == "path" and near_key() then take_key() end
  if S.phase == "path" and near_chest() then
    if S.has_key then
      begin_pop()
    elseif S.hop == 0 then
      S.hop = 10
      tone(330, 0.1, 0.25)
      react_to("The lock wants the key.")
    end
  end
  if S.shot_cool > 0 then S.shot_cool = S.shot_cool - 1 end
  -- A press fires at once (no faster than five a second); a held button repeats twice a second.
  local can_fire = S.phase == "path" or S.phase == "pop" or S.phase == "fight" or S.phase == "pika" or S.phase == "pikapop"
  if S.saw_release and can_fire and S.stuck == 0
      and ((pressed and S.shot_cool <= HOLD_GAP - SHOT_GAP) or (held and not pressed and S.shot_cool == 0)) then
    fire()
    S.shot_cool = HOLD_GAP
  end
  if S.phase == "pop" then
    S.pop_t = S.pop_t + 1
    if S.pop_t >= POP_FRAMES then
      S.phase, S.has_sword = "fight", true
      clear_fight()
      log("chest sword " .. game.frame)
      log("chest level " .. S.level)
    end
  elseif S.phase == "fight" then
    fight_step()
  elseif S.phase == "zambow" then
    S.bow_t = S.bow_t + 1
    if S.bow_t > 12 and S.bend_t < 40 then S.bend_t = S.bend_t + 1 end
    if S.bow_t > 40 and S.bow_t % 6 == 0 then
      particles.burst(ZX + rnd(-26, 26), 156, 4, 2.2, 20, 2.5, C.PIKA, "star")
    end
    if S.bow_t >= ZAMBOW_FRAMES then begin_pikapop() end
  elseif S.phase == "pikapop" then
    S.pop_t = S.pop_t + 1
    if S.pop_t >= PIKAPOP_FRAMES then
      S.phase, S.has_sword = "pika", true
      clear_pika()
      log("chest pika " .. game.frame)
    end
  elseif S.phase == "pika" then
    pika_step()
  elseif S.phase == "winbow" then
    S.bow_t = S.bow_t + 1
    if S.bow_t > 16 and S.bend_t < 40 then S.bend_t = S.bend_t + 1 end
    if S.bow_t % 12 == 0 then
      local col = S.bow_t % 36 == 0 and C.PIKA or S.bow_t % 24 == 0 and C.ROSE or C.CYAN
      particles.spawn(rnd(40, W - 40), 70, rnd(-1.5, 1.5), rnd(0.5, 2), 80, rnd(3, 4.5), col,
        S.bow_t % 24 == 0 and "star" or "square", 0.05, 0.99, 0.1)
    end
    if S.prize_t > 0 then
      S.prize_t = S.prize_t + 1
      if S.prize_t > 60 then
        S.prize_t, S.pile_hop = 0, 30
        sfx.note("sine", 91, 0.2, 0.25)
        particles.burst(50, 50, 16, 2.5, 28, 3, C.GOLD, "star")
      end
    end
    -- Celebratory sparkles on button press during the first 2 seconds; press after that plays again!
    if pressed and S.saw_release then
      if S.bow_t < WIN_MIN_FRAMES then
        sfx.arp("tri", {79, 84, 88}, 0.05, 0.25)
        particles.burst(S.nx, S.ny - 44, 18, 3.5, 34, 3, C.GOLD, "star")
      else
        snd.ok()
        start_next_round()
      end
    elseif S.bow_t >= WIN_AUTO_FRAMES then
      start_next_round()
    end
  elseif S.phase == "pathback" then
    S.bow_t = S.bow_t + 1
    if S.bow_t == 30 then
      S.nx, S.ny = START_X, START_Y
      particles.burst(S.nx, S.ny, 14, 2, 24, 2.5, C.AQUA, "star")
    end
    if S.bow_t >= 60 then
      S.phase, S.pips, S.path_t, S.hurt_cool, S.stuck = "path", 0, 0, 0, 0
      for i, f in ipairs(S.foes) do f.cool, f.tele = 60 + (i - 1) * 55, 0 end
    end
  elseif S.phase == "restart" then
    S.bow_t = S.bow_t + 1
    if S.bow_t >= RESTART_FRAMES then
      S.has_sword = true
      if S.boss == "pika" then
        S.phase = "pika"
        clear_pika()
      else
        S.phase = "fight"
        clear_fight()
      end
    end
  end
  if S.run_left > 0 then
    S.run_left = S.run_left - 1
    if S.run_left == 0 then S.run = 0 end
  end
  -- The room: he looks in on his treasure for a few seconds while he starts to walk. The chimes are only sound.
  S.room_t = S.room_t + 1
  if S.room_out == 0 and (S.phase ~= "path" or S.room_t > (S.fresh and 420 or 300)
      or S.room_t > 110 and (mx ~= 0 or my ~= 0 or pressed)) then
    S.room_out = S.room_t
  end
  local own = min(S.gems, 9)
  if S.room_t >= 30 and S.room_t < 30 + 7 * own and (S.room_t - 30) % 7 == 0 then
    local i = idiv(S.room_t - 30, 7)
    music.cue{wave = "sine", note = ({72, 74, 76, 79, 81, 84, 86, 88, 91})[i + 1], dur = 0.25, vol = 0.12, release = 0.22}
    sparks(40 + i * 38 + 19, 52, 5, 1.2, 20, 2, C.GOLD, "star")
  end
  mix()
  for _, k in ipairs({"hop", "pile_hop", "react_left", "flinch_t", "dizzy_t", "cheer", "oops"}) do
    if S[k] > 0 then S[k] = S[k] - 1 end
  end
  if leaving() and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

function quit()
  if S.dirty then save_all() end
end

function draw()
  pics.draw()
  particles.draw()
  local line = S.react_left > 0 and S.react or rest_line()
  if leaving() then line = rest_line() end
  ui.band(line)
end
