-- Garden: Unicorn's Fairy Garden & Butterfly Sanctuary (4+ little band!).
-- Every stick direction moves the glowing fairy ring; every right-hand button grows magic flowers!
-- Zero fail states, zero punishment, gentle pentatonic harp music, persistent blooms in garden.sav.

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, SKY1 = 0x90d0ff, SKY2 = 0xffe6f4,
  GRASS1 = 0x86dc82, GRASS2 = 0x6ec66c, SOIL = 0xb07a52,
  GOLD = 0xffd84a, ROSE = 0xf47eb2, LILAC = 0xb998f0, MINT = 0x78dcc8,
  SUN = 0xffe066, WHITE = 0xfffcf8, BLUE = 0x7ec8ff,
}

local FLOWERS = {
  {name = "Rainbow Rose", col = C.ROSE, mid = C.GOLD},
  {name = "Sunburst Tulip", col = C.SUN, mid = C.ROSE},
  {name = "Moonbell", col = C.LILAC, mid = C.WHITE},
  {name = "Mint Blossom", col = C.MINT, mid = C.GOLD},
  {name = "Sky Daisy", col = C.BLUE, mid = C.SUN},
  {name = "Heart Lily", col = 0xff7096, mid = C.CREAM},
}
local BEDS = {{84, 290}, {192, 276}, {300, 290}, {84, 404}, {192, 392}, {300, 404}}
local SONG = {72, 74, 76, 79, 81, 84, 81, 79, 76, 74, 72, 76, 79, 84, 88, 84}

local garden_bed = {bpm = 88, steps = 2,
  {"C5 . E5 . G5 . E5 . A5 . G5 . E5 . D5 . ", wave = "sine", vol = 0.14, release = 0.35, attack = 0.02, pan = -0.2},
  {"C3 - - - - - - - F3 - - - G3 - - - ", wave = "sine", vol = 0.14, release = 0.45, attack = 0.04, pan = 0.2}}

local S = {
  sel = 1, blooms = 0, parades = 0,
  beds = {}, butterflies = {}, rain_t = 0, rain_bed = 1,
  parade_t = 0, song_i = 0, move_cool = 0, act_cool = 0, saw_release = false,
  react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 120 end

local function all_bloomed()
  for i = 1, #BEDS do if S.beds[i].stage < 3 then return false end end
  return true
end

local function spawn_butterfly(bed_i)
  local b = BEDS[bed_i]
  local cols = {C.ROSE, C.GOLD, C.BLUE, C.LILAC, C.MINT}
  S.butterflies[#S.butterflies + 1] = {
    x = b[1], y = b[2] - 28, hx = b[1], hy = b[2] - 46,
    col = cols[(bed_i - 1) % #cols + 1], ph = bed_i * 1.6,
  }
end

local function tend_bed()
  local bed = S.beds[S.sel]
  local pos = BEDS[S.sel]
  if all_bloomed() then
    -- Musical wind-chime song after all 6 beds bloom!
    S.song_i = S.song_i + 1
    local note = SONG[(S.song_i - 1) % #SONG + 1]
    sfx.note("sine", note, 0.3, 0.26)
    sfx.note("tri", note + 12, 0.18, 0.12)
    particles.burst(pos[1], pos[2] - 24, 14, 2.5, 32, 3.5, FLOWERS[S.sel].col, "heart")
    log("garden chime " .. S.song_i)
    if S.song_i % #SONG == 0 then
      S.parade_t = 140
      S.parades = S.parades + 1
      save.set("parades", S.parades)
      save.write()
      particles.burst(W / 2, 190, 32, 3.5, 48, 4, C.GOLD, "star")
      react_to("The butterflies love your song!")
    else
      react_to("Twinkle, twinkle, magic flowers!")
    end
    return
  end

  if bed.stage == 0 then
    bed.stage = 1
    log("garden seed " .. S.sel)
    sfx.note("sine", 72, 0.18, 0.24)
    particles.burst(pos[1], pos[2] - 4, 12, 2, 24, 2.5, C.GOLD, "star")
    react_to("A magic seed! Press again for rainbow rain!")
  elseif bed.stage == 1 then
    bed.stage = 2
    S.rain_t, S.rain_bed = 36, S.sel
    log("garden rain " .. S.sel)
    sfx.arp("sine", {74, 76, 79}, 0.06, 0.24)
    particles.burst(pos[1], pos[2] - 16, 16, 2.2, 28, 2.5, C.BLUE, "dot")
    react_to("Rainbow rain! A little sprout popped up!")
  elseif bed.stage == 2 then
    bed.stage = 3
    S.blooms = min(S.blooms + 1, 100000)
    save.set("blooms", S.blooms)
    save.write()
    spawn_butterfly(S.sel)
    log("garden bloom " .. S.sel)
    sfx.arp("tri", {72, 76, 79, 84}, 0.07, 0.28)
    particles.burst(pos[1], pos[2] - 22, 22, 2.8, 36, 3.5, FLOWERS[S.sel].col, "heart")
    react_to("A " .. FLOWERS[S.sel].name .. " bloomed!")
    if all_bloomed() then
      S.parade_t = 180
      S.parades = min(S.parades + 1, 100000)
      save.set("parades", S.parades)
      save.write()
      log("garden parade " .. S.parades)
      sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.08, 0.34)
      for i = 1, 30 do
        particles.spawn(W / 2 + rnd(-120, 120), 200, rnd(-2.5, 2.5), rnd(-4, -1), 85, rnd(3, 5),
          i % 2 == 0 and C.ROSE or C.GOLD, "heart", 0.08, 0.99, 0.08)
      end
      react_to("Butterfly Parade! Press to play music!")
    end
  else
    -- Already bloomed: wiggle and sparkle, then hop ring to next unbloomed bed!
    sfx.note("sine", 84, 0.18, 0.22)
    particles.burst(pos[1], pos[2] - 24, 12, 2, 24, 3, C.GOLD, "star")
    for i = 1, #BEDS do
      local nxt = (S.sel + i - 1) % #BEDS + 1
      if S.beds[nxt].stage < 3 then S.sel = nxt break end
    end
    react_to("The butterfly does a happy dance!")
  end
end

function bot()
  if not all_bloomed() then
    if S.beds[S.sel].stage >= 3 then
      if game.frame % 16 == 0 then input.bot("right") end
    elseif game.frame % 20 == 0 then
      input.bot("low")
    end
  elseif game.frame % 18 == 0 then
    input.bot("low")
  end
end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.blooms = clamp(save.get("blooms", 0), 0, 100000)
  S.parades = clamp(save.get("parades", 0), 0, 100000)
  for i = 1, #BEDS do S.beds[i] = {stage = 0} end
  log("garden blooms " .. S.blooms)
  music.play(garden_bed)
  react_to("Press any button to plant a magic seed!")
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.rain_t > 0 then S.rain_t = S.rain_t - 1 end
  if S.parade_t > 0 then S.parade_t = S.parade_t - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  -- Every stick direction does something useful!
  if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
    local step = (mx < 0 or my < 0) and -1 or 1
    S.sel = (S.sel - 1 + step) % #BEDS + 1
    S.move_cool = 18
    sfx.slide("sine", 520, 680, 0.08, 0.16)
  end
  if S.saw_release and ((pressed and S.act_cool <= 12) or (held and S.act_cool == 0)) then
    tend_bed()
    S.act_cool = 28
  end
  for _, bf in ipairs(S.butterflies) do
    local t = game.frame * 0.04 + bf.ph
    if S.parade_t > 0 then
      bf.x = approach(bf.x, W / 2 + cos(t * 1.4) * 110, 0.06)
      bf.y = approach(bf.y, 185 + sin(t * 2.2) * 44, 0.06)
    else
      bf.x = approach(bf.x, bf.hx + cos(t) * 28, 0.06)
      bf.y = approach(bf.y, bf.hy + sin(t * 1.5) * 14, 0.06)
    end
  end
  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

local function paint_garden_bg()
  gfx.vgrad(0, 0, W, 190, C.SKY1, C.SKY2)
  -- Rainbow arch in the sky!
  local rcols = {0xff88a8, 0xffd070, 0x98e898, 0x80d0ff, 0xc8a0ff}
  for i, col in ipairs(rcols) do gfx.ring(W / 2, 220, 175 - i * 8, 8, alpha(col, 140)) end
  -- Rolling hills + meadow.
  gfx.circle(80, 210, 90, C.GRASS1)
  gfx.circle(300, 214, 100, C.GRASS1)
  gfx.vgrad(0, 188, W, H - 32 - 188, C.GRASS1, C.GRASS2)
  -- Cozy fountain at top center.
  toon(function()
    toon.ellipse(W / 2, 184, 34, 12, C.CREAM)
    toon.rrect(W / 2 - 8, 152, 16, 30, 5, C.CREAM)
    toon.ellipse(W / 2, 152, 22, 8, C.BLUE)
  end, 2, C.INK)
end

function draw()
  backdrop("garden_bg", paint_garden_bg)
  -- Fountain water sparkles.
  if game.frame % 10 == 0 then
    particles.spawn(W / 2 + rnd(-10, 10), 146, rnd(-0.6, 0.6), -1.6, 26, 2.5, C.BLUE, "dot", 0.08)
  end

  -- 6 Flowerbeds!
  for i, pos in ipairs(BEDS) do
    local x, y = pos[1], pos[2]
    local st = S.beds[i].stage
    local fl = FLOWERS[i]
    if i == S.sel then
      gfx.glow(x, y, 48, alpha(C.GOLD, 130 + floor(sin(game.frame * 0.14) * 40)))
      gfx.ring(x, y + 4, 38, 3, C.GOLD)
    end
    gfx.ellipse_o(x, y + 10, 32, 12, C.SOIL, C.INK, 2)
    if st == 1 then
      gfx.circle_o(x, y + 6, 5, C.GOLD, C.INK, 1.5)
    elseif st == 2 then
      gfx.line(x, y + 8, x, y - 10, 4, 0x4ca848)
      gfx.ellipse_o(x - 7, y - 4, 7, 4, 0x62cc6a, C.INK, 1.5)
      gfx.ellipse_o(x + 7, y - 8, 7, 4, 0x62cc6a, C.INK, 1.5)
    elseif st >= 3 then
      local sway = sin(game.frame * 0.07 + i) * 3
      gfx.line(x, y + 8, x + sway, y - 24, 5, 0x4ca848)
      gfx.ellipse_o(x - 9, y - 4, 8, 4, 0x62cc6a, C.INK, 1.5)
      gfx.ellipse_o(x + 9, y - 8, 8, 4, 0x62cc6a, C.INK, 1.5)
      for p = 0, 5 do
        local a = p * 1.047 + game.frame * 0.015
        gfx.circle_o(x + sway + cos(a) * 14, y - 26 + sin(a) * 14, 9, fl.col, C.INK, 1.8)
      end
      gfx.circle_o(x + sway, y - 26, 9, fl.mid, C.INK, 1.8)
      -- Smiling flower face!
      gfx.circle(x + sway - 3, y - 27, 1.5, C.INK)
      gfx.circle(x + sway + 3, y - 27, 1.5, C.INK)
    end
  end

  -- Smiling rainbow rain cloud!
  if S.rain_t > 0 then
    local p = BEDS[S.rain_bed]
    toon(function()
      toon.circle(p[1] - 14, p[2] - 64, 14, C.WHITE)
      toon.circle(p[1] + 14, p[2] - 64, 14, C.WHITE)
      toon.circle(p[1], p[2] - 72, 18, C.WHITE)
    end, 2, C.INK)
    for k = -2, 2 do
      gfx.line(p[1] + k * 8, p[2] - 48, p[1] + k * 8 - 3, p[2] - 20, 2.5, C.BLUE)
    end
  end

  -- Fluttering butterflies!
  for _, bf in ipairs(S.butterflies) do
    local flap = abs(sin(game.frame * 0.35 + bf.ph)) * 6 + 3
    gfx.ellipse_o(bf.x - 8, bf.y - 2, 8, flap, bf.col, C.INK, 1.4)
    gfx.ellipse_o(bf.x + 8, bf.y - 2, 8, flap, bf.col, C.INK, 1.4)
    gfx.ellipse(bf.x, bf.y, 2.5, 6, C.INK)
  end

  -- Top counter pill.
  gfx.rrect_o(10, 10, 148, 28, 10, C.CREAM, C.INK, 2)
  gfx.text("BLOOMS: " .. S.blooms, 84, 15, 14, C.INK, "center")

  particles.draw()
  local line = S.react_left > 0 and S.react or (all_bloomed() and "Press to play a song for the butterflies!" or "Press any button to grow your garden!")
  if input.down("1p") and input.down("2p") then line = "Your flowers will stay!" end
  ui.band(line)
end
