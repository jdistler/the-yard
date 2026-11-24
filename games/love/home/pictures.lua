-- The pictures between programs (main.lua's section until HOME_REFACTOR.md CP2): "get ready" before a game, the
-- "welcome back" picture homeloop shows when it ends, and the power-on picture. Painted into /dev/fb0 through
-- splash.lua. What they borrow from Home comes in P.init(ctx): draw_background, ST (the brand), LEAVE (how to come
-- back from each kind of game), shelf, fx, splash, BACK (the welcome-back file), uptime, log.
local P = {}
local lg = love.graphics
local D = require("draw")
local W = 768
local C

function P.init(ctx)
  C = ctx
  W = ctx.W or W
end

-- The backdrop of every picture: the sky, the grid and the sign, still.
function P.backdrop()
  C.draw_background(0.3)
  C.ST.draw_bulbs(1)
  C.ST.draw(0, 24, 96, 1)
end

-- "Get ready": the game's logo (or name) big, and how to come back.
function P.picture_launch(it)
  if it.kind == "arcade" then return C.shelf.picture_arcade(it.game, it.shot, it.tint) end
  if it.kind == "game" then return C.shelf.picture_game(it.game, it.shot, it.tint) end
  P.backdrop()
  local r, g, b = D.rgb(it.tint)
  C.fx.glow(W / 2, 430, 420, 240, r, g, b, 0.35)
  if it.art then
    local iw, ih = it.art:getDimensions()
    local s = math.min(620 / iw, 300 / ih)
    lg.setColor(1, 1, 1, 1)
    lg.draw(it.art, W / 2, 430, 0, s, s, iw / 2, ih / 2)
  elseif it.shot then
    D.neon_draw(it.title, 0, 214, 54, it.tint, 1.2, "center", W, 1, 1.2)
    local iw, ih = it.shot:getDimensions()
    local s = math.min(270 / iw, 290 / ih)
    local dw, dh = iw * s, ih * s
    local dx, dy = math.floor((W - dw) / 2), math.floor(445 - dh / 2)
    lg.setColor(0.05, 0.02, 0.12, 0.92)
    D.rrect("fill", dx - 10, dy - 10, dw + 20, dh + 20, 18)
    lg.setColor(1, 1, 1, 1)
    lg.draw(it.shot, dx, dy, 0, s, s)
    lg.setColor(r, g, b, 0.95)
    lg.setLineWidth(3)
    D.rrect("line", dx - 10, dy - 10, dw + 20, dh + 20, 18)
  else
    D.neon_draw(it.title, 0, 380, 64, it.tint, 1.2, "center", W, 1, #it.title > 9 and 1.1 or 1.5)
  end
  D.neon_draw("GET READY!", 0, 628, 44, 0xffd23f, 1, "center", W)
  local leave = C.LEAVE[it.kind]
  if leave then
    lg.setColor(0.04, 0.0, 0.10, 0.85)
    D.rrect("fill", 60, 800, W - 120, 130, 24)
    lg.setColor(r, g, b, 0.9)
    lg.setLineWidth(2)
    D.rrect("line", 60, 800, W - 120, 130, 24)
    D.neon_draw(leave[1], 0, 822, 34, it.tint, 0.8, "center", W)
    lg.setFont(D.font(24))
    lg.setColor(0.9, 0.88, 1, 1)
    lg.printf(leave[2], 60, 880, W - 120, "center")
  end
end

-- "Welcome back": clean, section-neutral card over the sky & marquee (never looks like a frozen empty menu).
function P.picture_back()
  P.backdrop()
  local r, g, b = D.rgb(C.ST.ACCENT)
  C.fx.glow(W / 2, 490, 380, 180, r, g, b, 0.25)
  lg.setColor(0.05, 0.02, 0.12, 0.88)
  D.rrect("fill", 124, 424, W - 248, 132, 24)
  lg.setColor(r, g, b, 0.9)
  lg.setLineWidth(2.5)
  D.rrect("line", 124, 424, W - 248, 132, 24)
  D.neon_draw("WELCOME BACK", 0, 444, 40, C.ST.C, 1.0, "center", W)
  lg.setFont(D.font(24))
  lg.setColor(0.92, 0.90, 1, 0.9)
  lg.printf("Returning to Starlight...", 124, 504, W - 248, "center")
end

-- Power-on: a bold, lit Starlight hero splash while Linux & LÖVE start up.
function P.picture_boot()
  C.draw_background(0.22)
  C.ST.draw_bulbs(1, 1)
  C.ST.draw(0, 24, 96, 1)
  local r, g, b = D.rgb(C.ST.C)
  local ar, ag, ab = D.rgb(C.ST.ACCENT)
  C.fx.glow(W / 2, 445, 440, 240, r, g, b, 0.28)
  C.fx.glow(W / 2, 575, 340, 120, ar, ag, ab, 0.22)
  -- (the sign above is the brand: Starlight, the name the family chose; no second name under it)
  lg.setColor(0.05, 0.02, 0.12, 0.88)
  D.rrect("fill", 194, 550, W - 388, 66, 20)
  lg.setColor(ar, ag, ab, 0.9)
  lg.setLineWidth(2)
  D.rrect("line", 194, 550, W - 388, 66, 20)
  lg.setFont(D.font(26))
  lg.setColor(1, 0.95, 0.84, 0.95)
  lg.printf("STARTING UP...", 194, 568, W - 388, "center")
end

function P.file_exists(p) local f = p and io.open(p, "rb") if f then f:close() return true end return false end

-- Just before quitting for a game: its picture on the screen, and the welcome-back picture for homeloop
-- (once per boot: it lives in /tmp).
function P.pictures_for(it)
  local t0 = C.uptime()
  local ok, bytes = pcall(C.splash.render, function() P.picture_launch(it) end)
  if ok then C.splash.show(bytes) end
  if C.BACK and not P.file_exists(C.BACK) then
    local ok2, back = pcall(C.splash.render, P.picture_back)
    if ok2 then C.splash.save(back, C.BACK) end
  end
  C.log(string.format("pictures %s in %.2f s", ok and "shown" or ("failed: " .. tostring(bytes)), C.uptime() - t0))
end

return P
