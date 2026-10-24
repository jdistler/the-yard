-- {{TITLE}}: a gentle story game in the little band (CONTROLS.md): nothing can be lost,
-- every button does the kind thing, the stick picks who. The cream band at the bottom
-- tells a grown-up what is happening; every line is logged as "{{ID}} say ..." for tests.

local friends = {
  {name = "Bun", color = 0xffd0e0, x = W * 0.25},
  {name = "Moss", color = 0xb8e8a0, x = W * 0.5},
  {name = "Pip", color = 0xffd890, x = W * 0.75},
}
local pick, line, line_left = 1, nil, 0
local floor_y = H * 0.62

local function say(s, frames) line, line_left = s, frames or 120 end

function init()
  save.set("visits", save.get("visits", 0) + 1)
  save.write()
  for _, f in ipairs(friends) do f.joy, f.hop = 0, 0 end
  music.play({bpm = 84, steps = 2,
    {"C5 . E5 . G5 . A5 . G5 . E5 . ", wave = "sine", vol = 0.08},
    {"C3 - - - F3 - - - ", wave = "sine", vol = 0.08}})
  task(function()
    say("Three friends are waiting.", 90)
    wait(90)
    say("Pick a friend and press a button.", 120)
  end)
end

function update()
  if input.pressed("left") then pick = (pick - 2) % #friends + 1 snd.tick(pick) end
  if input.pressed("right") then pick = pick % #friends + 1 snd.tick(pick) end
  if input.action() then
    local f = friends[pick]
    f.joy, f.hop = 60, 1
    fx.hearts(f.x, floor_y - 50)
    snd.purr()
    say(f.name .. " is so happy!")
    log("{{ID}} hug " .. f.name)
  end
  for _, f in ipairs(friends) do
    f.joy = max(0, f.joy - 1)
    f.hop = approach(f.hop, 0, 0.12)
  end
  if line_left > 0 then line_left = line_left - 1 end
end

function bot()
  if game.frame % 50 == 0 then input.bot("right") end
  if game.frame % 50 == 25 then input.bot("low") end
end

-- Sizes follow the screen, so the same cart looks right small (240 wide) or large (384).
local k = W / 384

local function friend(f, chosen)
  local y = floor_y - abs(sin(f.hop * math.pi)) * 18 * k
  if chosen then gfx.ring(f.x, floor_y + 30 * k, (34 + sin(game.frame * 0.1) * 2) * k, 3, alpha(pal.sun, 220)) end
  shadow(f.x, floor_y + 30 * k, 26 * k)
  toon(function()
    toon.ellipse(f.x, y + 12 * k, 28 * k, 24 * k, f.color)
    toon.ellipse(f.x - 16 * k, y - 18 * k, 8 * k, 14 * k, f.color)
    toon.ellipse(f.x + 16 * k, y - 18 * k, 8 * k, 14 * k, f.color)
    toon.circle(f.x, y - 6 * k, 24 * k, f.color)
  end, 2.5)
  face.eyes(f.x, y - 8 * k, 8 * k, 1.2 * k, 0, 0, f.joy > 0 and "happy" or (face.blinking(f.x) and "blink" or nil))
  face.blush(f.x, y, 14 * k, 1.2 * k)
  face.smile(f.x, y + 4 * k, 4 * k, 1.2 * k, f.joy > 0)
end

function draw()
  backdrop("room", function()
    gfx.vgrad(0, 0, W, floor_y + 10, 0xbfe2ff, 0xfff0f6)
    gfx.rect(0, floor_y + 10, W, H - floor_y, 0xf6d8e8)
  end)
  for i, f in ipairs(friends) do friend(f, i == pick) end
  particles.draw()
  ui.band(line_left > 0 and line or (friends[pick].name .. " would love a hug."))
end
