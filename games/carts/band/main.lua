-- Band: Starlight Unicorn Parade & Music Stage (4+ little band!)
-- Every stick direction sweeps the rainbow spotlight across Unicorn, Pip, Moth, Pearl, and Nib!
-- Every right-hand button press plays the next harmonized note, makes them jump, and launches fireworks!
-- Zero wrong notes, zero fail states; encores saved in band.sav.

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, SKY1 = 0x241848, SKY2 = 0x523484,
  STAGE = 0xc88450, GOLD = 0xffd84a, ROSE = 0xf47eb2, LILAC = 0xb998f0,
  MINT = 0x78dcc8, BLUE = 0x7ec8ff, WHITE = 0xfffcf8,
}

local STARS = {
  {name = "Unicorn", col = C.CREAM, accent = C.ROSE, wave = "sine", oct = 0, x = 76},
  {name = "Pip", col = 0xf29a3a, accent = C.GOLD, wave = "tri", oct = 0, x = 154},
  {name = "Moth", col = 0x8a8f9c, accent = C.BLUE, wave = "sine", oct = -12, x = 230},
  {name = "Pearl", col = C.WHITE, accent = C.MINT, wave = "tri", oct = 12, x = 308},
}
local MELODY = {72, 74, 76, 79, 81, 79, 76, 74, 72, 76, 79, 84}

local stage_bed = {bpm = 96, steps = 2,
  {"C3 - - - G2 - - - A2 - - - F2 - - - ", wave = "sine", vol = 0.14, release = 0.4, attack = 0.04}}

local S = {
  sel = 1, songs = 0, step = 0, encore_t = 0,
  hops = {0, 0, 0, 0},
  move_cool = 0, act_cool = 0, saw_release = false,
  react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 110 end

local function play_note()
  local st = STARS[S.sel]
  S.step = S.step % #MELODY + 1
  local idx = S.step
  local midi = MELODY[idx] + st.oct
  S.hops[S.sel] = 28
  log("band note " .. st.name)
  sfx.note(st.wave, midi, 0.28, 0.28)
  sfx.note("sine", midi + 7, 0.2, 0.1)
  particles.burst(st.x, 310, 14, 2.6, 34, 3.5, st.accent, "star")
  particles.spawn(st.x, 220, rnd(-1.2, 1.2), -2.5, 48, 4, st.accent, "heart", 0.05)
  if S.step == #MELODY then
    S.songs = min(S.songs + 1, 100000)
    S.encore_t = 130
    save.set("songs", S.songs)
    save.write()
    for i = 1, 4 do S.hops[i] = 44 end
    log("band encore " .. S.songs)
    sfx.arp("tri", {72, 76, 79, 84, 88, 96}, 0.06, 0.34)
    for i = 1, 34 do
      particles.spawn(W / 2 + rnd(-130, 130), 170, rnd(-3, 3), rnd(-4.5, -1), 80, rnd(3, 5),
        i % 3 == 0 and C.GOLD or i % 3 == 1 and C.ROSE or C.MINT, "star", 0.08, 0.99, 0.1)
    end
    react_to("ENCORE! Everyone plays together!")
  else
    react_to(st.name .. " plays a sparkly note!")
  end
end

function bot()
  if game.frame % 18 == 0 then input.bot("low") end
  if game.frame % 42 == 0 then input.bot("right") end
end

-- Leaving (1P+2P): the encore count is saved at every encore; write once more to be safe.
function quit()
  save.set("songs", S.songs)
  save.write()
end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.songs = clamp(save.get("songs", 0), 0, 100000)
  log("band songs " .. S.songs)
  music.play(stage_bed)
  react_to("Press any button to make music!")
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.encore_t > 0 then S.encore_t = S.encore_t - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end
  for i = 1, 4 do if S.hops[i] > 0 then S.hops[i] = S.hops[i] - 1 end end

  if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
    local d = (mx < 0 or my < 0) and -1 or 1
    S.sel = (S.sel - 1 + d) % #STARS + 1
    S.move_cool = 16
    sfx.slide("sine", 540, 720, 0.08, 0.14)
  end
  if S.saw_release and ((pressed and S.act_cool <= 10) or (held and S.act_cool == 0)) then
    play_note()
    S.act_cool = 22
  end
  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

local function paint_stage()
  gfx.vgrad(0, 0, W, 336, C.SKY1, C.SKY2)
  for i = 1, 36 do
    gfx.circle((i * 73) % W, (i * 41) % 240, (i % 2) + 1.2, alpha(C.GOLD, 160))
  end
  gfx.rrect_o(-10, 332, W + 20, H - 32 - 332 + 10, 18, C.STAGE, C.INK, 3)
  gfx.rect(0, 332, W, 14, 0xe4a46a)
end

function draw()
  backdrop("band_stage", paint_stage)
  -- Encore Rainbow progress arc across the sky!
  local filled = S.encore_t > 0 and #MELODY or (S.step % #MELODY)
  local rcols = {C.ROSE, C.GOLD, C.MINT, C.BLUE, C.LILAC}
  for i = 1, #MELODY do
    local a = math.pi + (i - 0.5) / #MELODY * math.pi
    local rx, ry = W / 2 + cos(a) * 145, 224 + sin(a) * 115
    local lit = i <= filled
    gfx.circle_o(rx, ry, lit and 10 or 7, lit and rcols[(i - 1) % #rcols + 1] or 0x483868, C.INK, 1.5)
    if lit then gfx.glow(rx, ry, 16, alpha(rcols[(i - 1) % #rcols + 1], 140)) end
  end

  -- Spotlight cone on selected performer!
  local cur = STARS[S.sel]
  gfx.tri(W / 2, 0, cur.x - 54, 360, cur.x + 54, 360, alpha(cur.accent, 55))

  -- The 4 Band Friends!
  for i, st in ipairs(STARS) do
    local hop = S.hops[i] > 0 and -abs(sin(S.hops[i] * 0.25)) * 22 or sin(game.frame * 0.08 + i) * 2
    local x, y = st.x, 344 + hop
    gfx.ellipse(st.x, 370, 22, 6, alpha(0x2a1838, 100))
    toon(function()
      if i == 1 then -- Unicorn horn!
        toon.tri(x - 5, y - 22, x + 5, y - 22, x, y - 42, C.GOLD)
      else -- Kitty ears!
        toon.tri(x - 16, y - 12, x - 22, y - 32, x - 4, y - 18, st.col)
        toon.tri(x + 16, y - 12, x + 22, y - 32, x + 4, y - 18, st.col)
      end
      toon.circle(x, y, 22, st.col)
    end, 2.2, C.INK)
    if S.hops[i] > 0 or S.encore_t > 0 then
      gfx.line(x - 11, y - 2, x - 7, y - 7, 2.2, C.INK)
      gfx.line(x - 7, y - 7, x - 3, y - 2, 2.2, C.INK)
      gfx.line(x + 3, y - 2, x + 7, y - 7, 2.2, C.INK)
      gfx.line(x + 7, y - 7, x + 11, y - 2, 2.2, C.INK)
    else
      gfx.circle(x - 7, y - 4, 2.5, C.INK)
      gfx.circle(x + 7, y - 4, 2.5, C.INK)
    end
    gfx.ellipse(x - 12, y + 3, 3.5, 2, alpha(C.ROSE, 140))
    gfx.ellipse(x + 12, y + 3, 3.5, 2, alpha(C.ROSE, 140))
    if i == S.sel then gfx.ring(st.x, 370, 28, 3, C.GOLD) end
  end

  gfx.rrect_o(10, 10, 142, 26, 9, C.CREAM, C.INK, 2)
  gfx.text("ENCORES: " .. S.songs, 81, 14, 13, C.INK, "center")

  particles.draw()
  local line = S.react_left > 0 and S.react or ("Spotlight on " .. cur.name .. "! Press to play!")
  if input.down("1p") and input.down("2p") then line = "Your encores will stay!" end
  ui.band(line)
end
