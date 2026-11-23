-- Bake: Royal Kitty Bakery (4+ little band!)
-- Pip, Moth, Pearl, and Nib visit the castle bakery!
-- Every stick direction picks a cute frosting color or kitty; every right-hand button mixes,
-- bakes, frosts, sprinkles, and serves the dream treat! Zero fail states; treats saved in bake.sav.
-- Left/up and right/down step through the four flavors. One press = one step (a held button does not
-- run the recipe), so the cupcake is never skipped. A served cupcake leaves a clean bowl for the next cook.

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, WALL = 0xffe8f0, WOOD = 0xd89c68,
  GOLD = 0xffd84a, ROSE = 0xf47eb2, MINT = 0x78dcc8, LILAC = 0xb998f0,
  BLUE = 0x7ec8ff, RED = 0xe84855, WHITE = 0xfffcf8,
}
local CATS = {
  {name = "Pip", col = 0xf29a3a, bow = C.ROSE},
  {name = "Moth", col = 0x8a8f9c, bow = C.BLUE},
  {name = "Pearl", col = C.WHITE, bow = C.GOLD},
  {name = "Nib", col = 0xf8dcc0, bow = C.LILAC},
}
local FROST = {
  {name = "Strawberry", col = C.ROSE},
  {name = "Mint", col = C.MINT},
  {name = "Lilac", col = C.LILAC},
  {name = "Vanilla", col = C.GOLD},
}
local bake_bed = {bpm = 96, steps = 2,
  {"C5 . E5 . G5 . E5 . F5 . A5 . G5 . E5 . ", wave = "tri", vol = 0.14, release = 0.28, attack = 0.01, pan = -0.2},
  {"C3 - - - G2 - - - F2 - - - G2 - - - ", wave = "sine", vol = 0.15, release = 0.35, attack = 0.03, pan = 0.2}}

local S = {
  treats = 0, cat_i = 1, frost_i = 1, step = 0, -- 0:mix, 1:bake, 2:frost, 3:sprinkle, 4:serve!
  happy_t = 0, spin_t = 0, puff_t = 0,
  move_cool = 0, act_cool = 0, saw_release = false,
  react = "", react_left = 0, goodbye = false,
}

local function react_to(s) S.react, S.react_left = s, 110 end

local function do_bake_step()
  local cat = CATS[S.cat_i]
  if S.step == 0 then
    S.step, S.spin_t = 1, 28
    log("bake mix")
    sfx.arp("sine", {72, 76, 79}, 0.06, 0.24)
    particles.burst(W / 2, 340, 14, 2.4, 24, 3, FROST[S.frost_i].col, "dot")
    react_to("Swirl, swirl! Mix the yummy batter!")
  elseif S.step == 1 then
    S.step, S.puff_t = 2, 32
    log("bake oven")
    sfx.note("tri", 84, 0.25, 0.28)
    particles.burst(W / 2, 330, 16, 2.2, 26, 3, C.GOLD, "star")
    react_to("DING! It baked up big and warm!")
  elseif S.step == 2 then
    S.step = 3
    log("bake frost")
    sfx.arp("sine", {76, 81, 84}, 0.06, 0.25)
    particles.burst(W / 2, 316, 18, 2.5, 28, 3.5, FROST[S.frost_i].col, "heart")
    react_to(FROST[S.frost_i].name .. " frosting! Press for sprinkles!")
  elseif S.step == 3 then
    S.step, S.puff_t = 4, 24
    log("bake sprinkle")
    sfx.arp("tri", {84, 88, 91}, 0.05, 0.24)
    particles.burst(W / 2, 308, 18, 2.6, 30, 3, C.GOLD, "star")
    react_to("Sprinkles and a cherry! Press to serve!")
  else
    -- Serve to the kitty!
    S.treats = min(S.treats + 1, 100000)
    save.set("treats", S.treats)
    save.write()
    S.step, S.happy_t = 0, 75
    log("bake serve " .. S.treats)
    sfx.arp("tri", {72, 76, 79, 84, 88}, 0.07, 0.32)
    particles.burst(W / 2, 180, 28, 3.2, 40, 4, C.ROSE, "heart")
    react_to(cat.name .. " LOVED the cupcake! Yum yum!")
    S.cat_i = S.cat_i % #CATS + 1
  end
end

function bot()
  if game.frame % 26 == 0 then input.bot("low") end
  if game.frame % 90 == 0 then input.bot("right") end
end

-- Leaving (1P+2P): the treat count is saved at every serve; write once more to be safe.
function quit()
  save.set("treats", S.treats)
  save.write()
end

function init()
  sfx.master(0.30)
  sfx.limit(8000)
  S.treats = clamp(save.get("treats", 0), 0, 100000)
  log("bake treats " .. S.treats)
  music.play(bake_bed)
  react_to("Pip wants a cupcake! Press to mix!")
end

function update()
  local pressed, held = input.action(), input.action_down()
  local mx, my = input.dir()
  if not held then S.saw_release = true end
  if S.move_cool > 0 then S.move_cool = S.move_cool - 1 end
  if S.act_cool > 0 then S.act_cool = S.act_cool - 1 end
  if S.happy_t > 0 then S.happy_t = S.happy_t - 1 end
  if S.spin_t > 0 then S.spin_t = S.spin_t - 1 end
  if S.puff_t > 0 then S.puff_t = S.puff_t - 1 end
  if S.react_left > 0 then S.react_left = S.react_left - 1 end

  if (mx ~= 0 or my ~= 0) and S.move_cool == 0 then
    local d = (mx < 0 or my < 0) and -1 or 1
    S.frost_i = (S.frost_i - 1 + d) % #FROST + 1
    S.move_cool = 18
    sfx.note("sine", 74 + S.frost_i * 2, 0.12, 0.2)
    react_to(FROST[S.frost_i].name .. " flavor!")
  end
  if S.saw_release and pressed and S.act_cool <= 10 then
    do_bake_step()
    S.act_cool = 28
  end
  if input.down("1p") and input.down("2p") and not S.goodbye then
    snd.bye()
    S.goodbye = true
  end
end

local function paint_bakery()
  gfx.vgrad(0, 0, W, 250, 0xffeef6, 0xffd8ea)
  -- Bakery awning stripes!
  for i = 0, 7 do
    gfx.rrect(i * 48, 0, 48, 42, 10, i % 2 == 0 and C.ROSE or C.CREAM)
  end
  -- Window frame.
  gfx.rrect_o(66, 62, W - 132, 174, 18, C.BLUE, C.INK, 3)
  gfx.rrect(74, 70, W - 148, 158, 12, 0xb8e6ff)
  -- Warm wooden kitchen counter.
  gfx.rect(0, 236, W, H - 32 - 236, C.WOOD)
  gfx.rect(0, 236, W, 14, 0xe8b482)
  gfx.line(0, 236, W, 236, 3, C.INK)
end

function draw()
  backdrop("bakery_bg", paint_bakery)
  -- Visiting kitty at the bakery window!
  local cat = CATS[S.cat_i]
  local bob = S.happy_t > 0 and -abs(sin(game.frame * 0.25)) * 12 or sin(game.frame * 0.08) * 3
  local cx, cy = W / 2, 172 + bob
  toon(function()
    toon.tri(cx - 24, cy - 16, cx - 34, cy - 44, cx - 8, cy - 26, cat.col)
    toon.tri(cx + 24, cy - 16, cx + 34, cy - 44, cx + 8, cy - 26, cat.col)
    toon.ellipse(cx, cy, 34, 28, cat.col)
  end, 2.5, C.INK)
  if S.happy_t > 0 then
    gfx.line(cx - 15, cy - 4, cx - 10, cy - 9, 2.5, C.INK)
    gfx.line(cx - 10, cy - 9, cx - 5, cy - 4, 2.5, C.INK)
    gfx.line(cx + 5, cy - 4, cx + 10, cy - 9, 2.5, C.INK)
    gfx.line(cx + 10, cy - 9, cx + 15, cy - 4, 2.5, C.INK)
  else
    gfx.circle(cx - 11, cy - 5, 3.5, C.INK)
    gfx.circle(cx + 11, cy - 5, 3.5, C.INK)
    gfx.circle(cx - 12, cy - 6.5, 1.3, C.WHITE)
    gfx.circle(cx + 10, cy - 6.5, 1.3, C.WHITE)
  end
  gfx.ellipse(cx - 18, cy + 4, 5, 3, alpha(C.ROSE, 150))
  gfx.ellipse(cx + 18, cy + 4, 5, 3, alpha(C.ROSE, 150))
  gfx.tri(cx - 3, cy + 1, cx + 3, cy + 1, cx, cy + 5, C.ROSE)

  -- Center baking station on the counter!
  local bx, by = W / 2, 354
  local fcol = FROST[S.frost_i].col
  if S.step == 0 then
    -- Mixing bowl!
    local j = S.spin_t > 0 and sin(game.frame * 0.8) * 5 or 0
    toon(function()
      toon.ellipse(bx + j, by + 10, 56, 34, C.CREAM)
      toon.ellipse(bx + j, by - 4, 52, 16, fcol)
    end, 2.5, C.INK)
    gfx.line(bx + 14 + j, by - 6, bx + 42 + j, by - 44, 7, C.WOOD)
  else
    -- Rising cupcake!
    local sc = S.puff_t > 0 and (1 + sin(S.puff_t * 0.2) * 0.14) or 1
    toon(function()
      toon.poly({bx - 36 * sc, by + 36, bx - 44 * sc, by - 6, bx + 44 * sc, by - 6, bx + 36 * sc, by + 36}, 0xf2c088)
      toon.ellipse(bx, by - 14, 48 * sc, 28 * sc, S.step >= 3 and fcol or S.step == 2 and 0xd89a52 or 0xf4e0a8)
    end, 2.5, C.INK)
    if S.step >= 4 then
      -- Colorful sprinkles + cherry on top!
      gfx.circle_o(bx, by - 46, 11, C.RED, C.INK, 2)
      gfx.circle(bx - 3, by - 49, 3, alpha(C.WHITE, 210))
      for i = -2, 2 do
        gfx.circle(bx + i * 14, by - 16 + (i % 2) * 8, 3.5, i % 2 == 0 and C.GOLD or C.WHITE)
      end
    end
  end

  -- Flavor swatches along the bottom of counter.
  for i, fr in ipairs(FROST) do
    local fx = 78 + (i - 1) * 76
    if i == S.frost_i then gfx.ring(fx, 444, 18, 3, C.GOLD) end
    gfx.circle_o(fx, 444, 13, fr.col, C.INK, 2)
  end

  -- Royal Display Case counter.
  gfx.rrect_o(10, 48, 128, 26, 9, C.CREAM, C.INK, 2)
  gfx.text("TREATS: " .. S.treats, 74, 52, 13, C.INK, "center")

  particles.draw()
  local prompts = {"Press to mix the batter!", "Press to bake it warm!", "Press to swirl on frosting!", "Press for sprinkles!", "Press to serve the kitty!"}
  local line = S.react_left > 0 and S.react or prompts[S.step + 1]
  if input.down("1p") and input.down("2p") then line = "Your treats will stay!" end
  ui.band(line)
end
