-- The Yard: the little menu that opens when Dig Dug II is chosen.
--
-- A night yard. A lantern hangs beside the highlighted game. Each row shows what the game
-- is, who it is for, and what it remembers. The stick moves the lantern (held, it
-- repeats). Any button opens the game. Hold 1P and 2P to go back to the stock menu.
-- yard.sav keeps the last highlighted row as "best N" (N counts from 0).
-- The rows are every cart on the cart path, in each label's order.

local INK, CREAM, GOLD, DIM = pal.night, pal.cream, pal.sun, pal.dim
local TOP, ROW_H = 92, 38
local VISIBLE = 5        -- rows on screen; with more games the list scrolls to keep the lantern's row in view

local carts, stats = {}, {}
local row, shown_row, swing, hold = 0, 0, 0, 0
local top, shown_top = 0, 0
local opening, iris = false, 0
local note, note_left = nil, 0
local sel = {}
local stars = {}
local shoot = {t = 0}
local pocket = false

local night = {
  bpm = 76, steps = 4,
  {"C5 . G4 . E5 . G4 . D5 . G4 . E5 . . . A4 . E4 . C5 . E4 . B4 . E4 . G4 . . .", wave = "tri", vol = 0.16, release = 0.25, attack = 0.01, pan = -0.3},
  {"C3 - - - - - - - - - - - - - - - A2 - - - - - - - - - - - - - - - ", wave = "sine", vol = 0.18, release = 0.4, attack = 0.05},
  {"E4 - - - - - - - G4 - - - - - - - E4 - - - - - - - D4 - - - - - - - ", wave = "sine", vol = 0.07, release = 0.5, attack = 0.3, pan = 0.3},
  {". . . . H . . . . . . . . . H . . . . . . . . . . . H . . . . . . . . H", wave = "noise", vol = 0.025, release = 0.03, pan = 0.5},
}

local function load_stats()
  for _, c in ipairs(carts) do stats[c.id] = yard.stat(c.id) end
end

local function start_music()
  sfx.master(0.32)
  music.play(night)
end

function init()
  carts = yard.carts()
  load_stats()
  for i = 1, 70 do stars[i] = {rnd(0, W), rnd(0, 230), rnd(0, tau)} end
  row = clamp(save.get("best", 0), 0, max(0, #carts - 1))
  shown_row = row
  top = clamp(row - VISIBLE + 1, 0, max(0, #carts - VISIBLE))
  shown_top = top
  for i = 1, #carts do sel[i] = 0 end
  if card.read("label") then
    pocket = true
    card.write("visited", "yard\n")
  end
  start_music()
  if game.selftest then
    save.set("best", row)
    assert(save.write() and save.get("best") == row, "yard self-test: the row did not save")
    game.quit()
  end
end

-- Where row r (from 0) is drawn, with the list scrolled.
local function row_y(r) return TOP + (r - shown_top) * ROW_H end

local function open(c)
  save.set("best", row)
  save.write()
  log("yard open " .. c.id)
  local how = yard.launch(c.id)
  start_music()
  load_stats()
  if how == "missing" then
    note, note_left = "that game is missing", 180
    log("could not open " .. c.id)
    sfx.slide("square", 300, 120, 0.3, 0.3)
  elseif how == "stumbled" then
    note, note_left = "that game tripped. try again?", 180
    log("yard: " .. c.id .. " stumbled")
  end
end

function update()
  local n = #carts
  if n == 0 then return end
  if opening then
    iris = iris - 0.07
    if iris <= 0 then
      opening, iris = false, 0
      open(carts[row + 1])
    end
    return
  end
  if iris < 1 then iris = clamp(iris + 0.06, 0, 1) end
  local up = input.down("up") or input.down("left")
  local down = input.down("down") or input.down("right")
  local step = 0
  if up ~= down then
    hold = hold + 1
    if hold == 1 or (hold > 18 and (hold - 18) % 7 == 0) then step = up and -1 or 1 end
  else
    hold = 0
  end
  if step ~= 0 then
    row = (row + n + step) % n
    swing = step * 5
    snd.tick(row)
    if row < top then top = row elseif row > top + VISIBLE - 1 then top = row - VISIBLE + 1 end
    particles.burst(30, TOP + (row - top) * ROW_H + 15, 6, 1.2, 24, 1.5, alpha(carts[row + 1].tint or GOLD, 220), "glow")
  end
  swing = swing * 0.9
  shown_row = approach(shown_row, row, 0.3)
  shown_top = approach(shown_top, top, 0.3)
  for i = 1, n do sel[i] = approach(sel[i], i == row + 1 and 1 or 0, 0.2) end
  if input.action() then
    sfx.arp("tri", {67, 72, 76, 79}, 0.06, 0.35)
    particles.burst(120, row_y(row) + 15, 24, 2.5, 40, 2.5, alpha(carts[row + 1].tint or GOLD, 255), "star")
    opening, iris = true, 1
  end
  if note_left > 0 then note_left = note_left - 1 end
end

-- ------------------------------------------------------------------ pictures

local function paint_backdrop()
  gfx.vgrad(0, 0, W, 250, 0x070a22, 0x3a2660)
  gfx.glow(214, 20, 34, alpha(0x8090ff, 70))
  gfx.circle(214, 20, 10, 0xfff3d4)
  gfx.circle(219, 16, 9, 0x0c0f2a)
  gfx.poly({0, 262, 40, 246, 90, 254, 140, 240, 190, 250, 240, 238, 240, 320, 0, 320}, 0x1c1640)
  gfx.poly({0, 286, 50, 276, 110, 284, 170, 274, 240, 282, 240, 320, 0, 320}, 0x13102c)
  for x = 4, W - 1, 16 do gfx.poly({x, 292, x + 3, 287, x + 6, 292, x + 6, 312, x, 312}, 0x2b2350) end
  gfx.rect(0, 297, W, 3, 0x2b2350)
  gfx.rect(0, 306, W, 3, 0x2b2350)
  gfx.rect(0, 312, W, 8, 0x0f0c22)
end

local function draw_sky()
  backdrop("night", paint_backdrop)
  for i, s in ipairs(stars) do
    local a = 60 + floor((0.5 + 0.5 * sin(game.frame * 0.05 + s[3])) * 180)
    if (i - 1) % 9 == 0 then gfx.star(s[1], s[2], 2.2, 0, alpha(0xfff2c0, a)) else gfx.pixel(s[1], s[2], alpha(0xdfe6ff, a)) end
  end
  if shoot.t > 0 then
    local k = 1 - shoot.t / 40
    local x, y = shoot.x - k * 90, shoot.y + k * 40
    gfx.line(x, y, x + 16, y - 7, 1.5, alpha(0xfff6d0, floor(shoot.t * 6)))
    gfx.glow(x, y, 6, alpha(0xffffff, 200))
    shoot.t = shoot.t - 1
  elseif rndi(0, 400) == 0 then
    shoot = {t = 40, x = rnd(120, 240), y = rnd(10, 60)}
  end
end

local function draw_row(i, c, y)
  local is_sel = i == row + 1
  local tint = c.tint or GOLD
  local x, w = 16 + 7 * ease.out_back(sel[i]), 210
  if is_sel then
    gfx.glow(x + 17, y + 15, 34, alpha(tint, 90))
    gfx.rrect(x - 2, y - 2, w + 4, 34, 9, tint)
  end
  gfx.rrect(x, y, w, 30, 8, is_sel and 0x2e2458 or alpha(0x1c1640, 200))
  gfx.circle(x + 17, y + 15, 12, is_sel and alpha(tint, 60) or alpha(0, 60))
  yard.icon(c.id, x + 17, y + 15, is_sel, game.frame / 60)
  local tw = gfx.text(c.title, x + 34, y - 1, 20, is_sel and CREAM or mix(DIM, CREAM, 0), "left", INK)
  local stat = stats[c.id]
  gfx.text(is_sel and (c.blurb or "") or (stat or "new"), x + 34, y + 17, 11, is_sel and mix(tint, CREAM, 0.35) or alpha(DIM, 170), "left")
  local band = c.band or "ALL"
  local bw = gfx.textw(band, 10) + 8
  gfx.rrect(x + w - bw - 6, y + 5, bw, 12, 4, is_sel and tint or alpha(0x3a3266, 220))
  gfx.text(band, x + w - bw / 2 - 6, y + 5, 10, is_sel and INK or DIM, "center")
  if is_sel and stat then gfx.text(stat, x + 40 + tw, y + 5, 11, GOLD, "left") end
end

local function draw_lantern(y)
  local x = 8 + sin(game.frame * 0.06) * 3 + swing
  gfx.glow(x, y + 15, 30, alpha(0xffa030, 110))
  gfx.line(8, y - 6, x, y + 6, 1, 0x8a7050)
  gfx.rrect_o(x - 4, y + 6, 8, 15, 2, 0xffd27a, INK, 1)
  gfx.rect(x - 2, y + 9, 4, 9, 0xfff6c8)
  gfx.rect(x - 4, y + 5, 8, 2, 0x5a4030)
end

function draw()
  draw_sky()
  local bob = sin(game.frame * 0.04) * 1.5
  gfx.text("The Yard", W / 2 - 6, 14 + bob, 38, GOLD, "center", INK)
  gfx.text(#carts == 1 and "a little game by the fence" or "little games by the fence", W / 2, 56 + bob, 12, 0xc0b8ff, "center")
  if #carts > VISIBLE then gfx.clip(0, TOP - 4, W, VISIBLE * ROW_H) end
  for i, c in ipairs(carts) do
    local y = row_y(i - 1)
    if y > TOP - ROW_H and y < TOP + VISIBLE * ROW_H then draw_row(i, c, y) end
  end
  if #carts > 0 then draw_lantern(row_y(shown_row) + 4) end
  if #carts > VISIBLE then
    gfx.clip()
    -- Little arrows say there are more games above or below.
    local b = sin(game.frame * 0.1) * 1.5
    if shown_top > 0.05 then gfx.tri(W - 14, TOP - 8 + b, W - 8, TOP - 8 + b, W - 11, TOP - 13 + b, alpha(CREAM, 200)) end
    if shown_top < #carts - VISIBLE - 0.05 then
      local yb = TOP + VISIBLE * ROW_H - 2 - b
      gfx.tri(W - 14, yb, W - 8, yb, W - 11, yb + 5, alpha(CREAM, 200))
    end
  end
  if pocket then
    gfx.circle(W - 10, H - 30, 4, 0x40d2dc)
    gfx.text("card in", W - 18, H - 36, 11, 0x40d2dc, "right")
  end
  for i = 0, 4 do
    local a = game.frame * 0.01 + i * 1.7
    local fx = (30 + i * 47 + sin(a * 1.3) * 18 + game.frame * 0.1) % W
    local fy = 270 + sin(a * 2.1) * 14 + i * 3
    gfx.glow(fx, fy, 7, alpha(0xd8ff70, floor((0.5 + 0.5 * sin(game.frame * 0.08 + i)) * 200)))
    gfx.pixel(fx, fy, 0xf4ffc0)
  end
  particles.draw()
  if note and note_left > 0 then
    gfx.rrect(20, 282, W - 40, 18, 6, alpha(0x6a1e30, 230))
    gfx.text(note, W / 2, 284, 12, CREAM, "center")
  elseif #carts == 0 then
    gfx.text("no games found", W / 2, 140, 16, CREAM, "center")
  else
    gfx.text("stick: choose     button: play", W / 2, 283, 12, 0xb0a8e0, "center")
    gfx.text("hold 1P + 2P to go back", W / 2, 298, 11, alpha(DIM, 200), "center")
  end
  if iris < 1 then gfx.iris(40, row_y(row) + 15, iris * 420) end
end
