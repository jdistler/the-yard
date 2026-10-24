-- {{TITLE}}. Start here: CARTS.md is the whole API, GAMEDEV.md the design rules.
--
-- init() runs once. update() runs 60 times a second: read the deck, move things.
-- draw() paints the frame. bot() presses the deck for the tests and the attract demo.

local x, y = W / 2, H / 2

function init()
  music.play({bpm = 90, steps = 2,
    {"C5 . E5 . G5 . E5 . ", wave = "tri", vol = 0.06},
    {"C3 - - - G2 - - - ", wave = "sine", vol = 0.1}})
end

function update()
  local dx, dy = input.dir()
  x, y = clamp(x + dx * 2, 20, W - 20), clamp(y + dy * 2, 20, H - 20)
  if input.action() then
    fx.pop(x, y)
    snd.ok()
  end
end

function bot()
  if game.frame % 60 < 30 then input.bot("right") else input.bot("left") end
  if game.frame % 90 == 0 then input.bot("low") end
end

function draw()
  gfx.vgrad(0, 0, W, H, 0x2a2a6a, 0x7a5aa8)
  shadow(x, y + 22, 18)
  toon(function()
    toon.circle(x, y, 18, 0xffc0d0)
    toon.circle(x - 12, y - 14, 7, 0xffc0d0)
    toon.circle(x + 12, y - 14, 7, 0xffc0d0)
  end, 2.5)
  face.eyes(x, y - 2, 6, 1, 0, 0, face.blinking() and "blink" or nil)
  face.blush(x, y + 4, 11)
  face.smile(x, y + 6, 3)
  particles.draw()
  say_text("{{TITLE}}", W / 2, 20, 28, pal.sun, "center", pal.night)
end
