-- Home's little delights: shooting stars, a soft glow sprite, and the night scene's chase along the horizon
-- (a round yellow chomper and four ghosts, drawn from shapes; after a power pellet the ghosts turn blue and the
-- chase turns round).
local lg = love.graphics
local F = {}
local W, H = 768, 1024

local glow_img
function F.load()
  local n = 128
  local d = love.image.newImageData(n, n)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    local v = math.max(0, 1 - (dx * dx + dy * dy))
    return 1, 1, 1, v * v
  end)
  glow_img = lg.newImage(d)
  glow_img:setFilter("linear", "linear")
end

-- A soft round light of radius r (additive), tinted r, g, b.
function F.glow(x, y, rx, ry, r, g, b, a)
  lg.setBlendMode("add")
  lg.setColor(r, g, b, a)
  lg.draw(glow_img, x, y, 0, rx * 2 / 128, (ry or rx) * 2 / 128, 64, 64)
  lg.setBlendMode("alpha")
end

-- ------------------------------------------------------------------ shooting stars

local shooting = {}
local next_star = 4
function F.update(dt, enabled)
  next_star = next_star - dt
  if enabled and next_star <= 0 then
    next_star = 5 + math.random() * 9
    local x = 80 + math.random() * (W - 160)
    shooting[#shooting + 1] = {x = x, y = 30 + math.random() * 260, vx = (math.random() < 0.5 and -1 or 1) * (380 + math.random() * 200),
                               vy = 160 + math.random() * 90, life = 0, max = 0.9 + math.random() * 0.4}
  end
  for i = #shooting, 1, -1 do
    local s = shooting[i]
    s.life = s.life + dt
    s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
    if s.life > s.max then table.remove(shooting, i) end
  end
end

function F.draw_shooting()
  lg.setBlendMode("add")
  lg.setLineWidth(2)
  for _, s in ipairs(shooting) do
    local k = s.life / s.max
    local a = math.sin(k * math.pi)
    local len = 0.12
    for j = 0, 5 do
      local f0, f1 = j / 6, (j + 1) / 6
      lg.setColor(1, 0.85, 1, a * (1 - f0) * 0.8)
      lg.line(s.x - s.vx * len * f0, s.y - s.vy * len * f0, s.x - s.vx * len * f1, s.y - s.vy * len * f1)
    end
    lg.setColor(1, 1, 1, a)
    lg.circle("fill", s.x, s.y, 2.2, 8)
  end
  lg.setBlendMode("alpha")
end

-- ------------------------------------------------------------------ the chase

local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}

local function chomper(x, y, r, dir, t, al)
  al = al or 1
  local open = (0.15 + 0.85 * math.abs(math.sin(t * 14))) * 0.42
  local a0 = dir > 0 and 0 or math.pi
  lg.setColor(1, 0.86, 0.15, al)
  lg.arc("fill", "pie", x, y, r, a0 + open, a0 + 2 * math.pi - open, 28)
  lg.setColor(0.1, 0.05, 0.1, al)
  lg.circle("fill", x + r * 0.1 * (dir > 0 and 1 or -1), y - r * 0.5, r * 0.11, 8)
end

local function ghost(x, y, r, c, dir, t, scared, blink, al)
  al = al or 1
  local body = scared and (blink and {0.95, 0.95, 1} or {0.2, 0.3, 1}) or c
  lg.setColor(body[1], body[2], body[3], al)
  lg.arc("fill", "pie", x, y, r, math.pi, 2 * math.pi, 24)
  lg.rectangle("fill", x - r, y, r * 2, r * 0.75)
  -- The wavy hem: three bumps that shuffle as it runs.
  local wob = math.floor(t * 8) % 2
  for i = 0, 2 do
    local bx = x - r + r / 3 + i * r * 2 / 3
    lg.circle("fill", bx, y + r * 0.75, r / 3 + (wob == i % 2 and 1 or -1), 10)
  end
  if scared then
    lg.setColor(1, 0.85, 0.75, al)
    lg.circle("fill", x - r * 0.35, y - r * 0.2, r * 0.13, 8)
    lg.circle("fill", x + r * 0.35, y - r * 0.2, r * 0.13, 8)
    lg.setLineWidth(2)
    local pts = {}
    for i = 0, 6 do pts[#pts + 1] = x - r * 0.6 + i * r * 0.2 pts[#pts + 1] = y + r * 0.3 + (i % 2 == 0 and 0 or -r * 0.12) end
    lg.line(pts)
  else
    for s = -1, 1, 2 do
      lg.setColor(1, 1, 1, al)
      lg.ellipse("fill", x + s * r * 0.38, y - r * 0.15, r * 0.26, r * 0.32, 12)
      lg.setColor(0.15, 0.25, 0.9, al)
      lg.circle("fill", x + s * r * 0.38 + dir * r * 0.12, y - r * 0.12, r * 0.13, 8)
    end
  end
end

-- One lap of the chase: 18 s. The first half the ghosts chase it to the right; at the far side it eats a
-- power pellet and chases the blue ghosts back to the left. Returns true at the moment of the pellet.
local PERIOD = 18
local last_phase = 0
function F.draw_chase(t, y, alpha)
  local p = (t % PERIOD) / PERIOD
  local r = 20
  local pellet = false
  local phase = p < 0.5 and 1 or 2
  if phase == 2 and last_phase == 1 then pellet = true end
  last_phase = phase
  lg.push()
  if alpha < 1 then lg.setColor(1, 1, 1, alpha) end
  if phase == 1 then
    local k = p / 0.5
    local x = -60 + (W + 400) * k
    -- The pellet waits at the right edge until Pac-Man eats it.
    if x < W - 30 and math.floor(t * 4) % 2 == 0 then
      lg.setColor(1, 0.85, 0.7, alpha)
      lg.circle("fill", W - 30, y, 8, 12)
    end
    chomper(x, y, r, 1, t, alpha)
    for i, c in ipairs(GHOSTS) do ghost(x - 70 - i * 52, y, r, c, 1, t + i, false, false, alpha) end
  else
    local k = (p - 0.5) / 0.5
    local x = W + 340 - (W + 680) * k
    for i, c in ipairs(GHOSTS) do
      local blink = k > 0.7 and math.floor(t * 6) % 2 == 0
      ghost(x - 90 - (5 - i) * 52 + 40, y, r, c, -1, t + i, true, blink, alpha)
    end
    chomper(x, y, r, -1, t, alpha)
  end
  lg.pop()
  return pellet
end

F.ghost = ghost
F.chomper = chomper
return F
