-- The LÖVE probe. It runs a short series of measurements on the cabinet and writes what it found to
-- PROBE_OUT (default /data/Games/love-probe.txt), then quits. Hold 1P+2P (or press Escape) to quit early.
--
-- Stages: info (renderer, limits, formats), then timed draw loads at 768x1024 rotated, then sound, then
-- ten seconds of "press every button" that records what the deck sends.

local rotate = require("rotate")
local out = {}
local function say(fmt, ...)
  local s = select("#", ...) > 0 and fmt:format(...) or fmt
  out[#out + 1] = s
  print(s)
end

local fast = os.getenv("PROBE_FAST") == "1"     -- the cloud test: short stages
local STAGE_SECONDS = fast and 0.5 or 4
local stages, stage, stage_t, times = {}, 0, 0, {}
local img, batch, quad_img, font, shader, msaa_canvas
local deck_until, pressed = nil, {}
local last_stats
local beep

local function meminfo()
  local f = io.open("/proc/meminfo")
  if not f then return "n/a" end
  local t = f:read("*a")
  f:close()
  return (t:match("MemAvailable:%s+(%d+)") or "?") .. " kB available"
end

local function info()
  local name, version, vendor, device = love.graphics.getRendererInfo()
  say("renderer: %s | %s | %s | %s", name, version, vendor, device)
  local ww, wh = love.graphics.getDimensions()
  local dw, dh = love.window.getDesktopDimensions()
  say("window %dx%d, desktop %dx%d, dpi scale %s", ww, wh, dw, dh, love.graphics.getDPIScale())
  local lim = love.graphics.getSystemLimits()
  local keys = {}
  for k in pairs(lim) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do say("limit %s = %s", k, tostring(lim[k])) end
  for k, v in pairs(love.graphics.getSupported()) do say("supported %s = %s", k, tostring(v)) end
  local tf = love.graphics.getImageFormats()
  local fmts = {}
  for k, v in pairs(tf) do if v then fmts[#fmts + 1] = k end end
  table.sort(fmts)
  say("image formats: %s", table.concat(fmts, " "))
  local cf = love.graphics.getCanvasFormats()
  fmts = {}
  for k, v in pairs(cf) do if v then fmts[#fmts + 1] = k end end
  table.sort(fmts)
  say("canvas formats: %s", table.concat(fmts, " "))
  say("os %s, %d cores, lua %s, %s", love.system.getOS(), love.system.getProcessorCount(), _VERSION,
    jit and jit.version or "no jit")
  say("memory at start: %s", meminfo())
  -- LÖVE switches LuaJIT's compiler off on ARM (src/modules/love/jitsetup.lua); a game may switch it back
  -- on. Time the same loop both ways.
  local function bench()
    local t0, s = love.timer.getTime(), 0
    for i = 1, 2000000 do s = s + (i % 7) * 0.5 end
    return (love.timer.getTime() - t0) * 1000
  end
  say("lua loop 2M: interpreter %.0f ms", bench())
  if jit then
    jit.on()
    jit.flush()
    say("lua loop 2M: jit on %.0f ms (status %s)", bench(), tostring(jit.status()))
    jit.off()
  end
  for _, j in ipairs(love.joystick.getJoysticks()) do
    say("joystick %q: %d buttons, %d axes, %d hats, gamepad %s, guid %s", j:getName(), j:getButtonCount(),
      j:getAxisCount(), j:getHatCount(), tostring(j:isGamepad()), j:getGUID())
  end
end

-- A 32x32 sprite painted in code, so the probe needs no picture files.
local function make_sprite()
  local d = love.image.newImageData(32, 32)
  d:mapPixel(function(x, y)
    local dx, dy = x - 15.5, y - 15.5
    local r = math.sqrt(dx * dx + dy * dy)
    if r > 15 then return 0, 0, 0, 0 end
    return 1, 0.75 - r / 60, 0.4, 1
  end)
  return love.graphics.newImage(d)
end

local loads = {
  {"clear", function() love.graphics.clear(0.1, 0.1, 0.2) end},
  {"sprites 500", function()
    love.graphics.clear(0.1, 0.1, 0.2)
    for i = 1, 500 do love.graphics.draw(img, (i * 37) % 740, (i * 53) % 1000) end
  end},
  {"batch 4000", function()
    love.graphics.clear(0.1, 0.1, 0.2)
    love.graphics.draw(batch)
  end},
  {"shapes 300", function()
    love.graphics.clear(0.15, 0.2, 0.3)
    for i = 1, 300 do
      love.graphics.setColor((i % 7) / 7, 0.6, 0.8)
      love.graphics.circle("fill", (i * 37) % 768, (i * 53) % 1024, 12 + i % 9)
      love.graphics.polygon("fill", (i * 41) % 768, (i * 29) % 1024, (i * 41) % 768 + 20, (i * 29) % 1024 + 5,
        (i * 41) % 768 + 8, (i * 29) % 1024 + 24)
    end
    love.graphics.setColor(1, 1, 1)
  end},
  {"text 40 lines", function()
    love.graphics.clear(0.2, 0.1, 0.2)
    love.graphics.setFont(font)
    for i = 0, 39 do love.graphics.print("The quick fox jumps over the lazy dog " .. i, 10, i * 25) end
  end},
  {"fullscreen shader", function()
    love.graphics.setShader(shader)
    love.graphics.rectangle("fill", 0, 0, 768, 1024)
    love.graphics.setShader()
  end},
  {"msaa canvas", function()
    if not msaa_canvas then return end
    love.graphics.setCanvas(msaa_canvas)
    love.graphics.clear(0.1, 0.2, 0.1)
    for i = 1, 100 do love.graphics.circle("fill", (i * 37) % 768, (i * 53) % 1024, 20) end
    rotate.begin()
    love.graphics.draw(msaa_canvas)
  end},
}

function love.load()
  rotate.init()
  info()
  img = make_sprite()
  batch = love.graphics.newSpriteBatch(img, 4000, "static")
  for i = 1, 4000 do batch:add((i * 37) % 740, (i * 53) % 1000) end
  font = love.graphics.newFont(20)
  shader = love.graphics.newShader([[
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
      float v = 0.5 + 0.5 * sin(sc.x * 0.05 + sc.y * 0.03);
      return vec4(v, 0.4, 1.0 - v, 1.0) * c;
    }]])
  local ok, c = pcall(love.graphics.newCanvas, 768, 1024, {msaa = 4})
  if ok then msaa_canvas = c else say("msaa canvas: %s", tostring(c)) end
  -- A beep, made in code.
  local rate, n = 44100, math.floor(44100 / 4)
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do sd:setSample(i, math.sin(i / rate * 2 * math.pi * 660) * 0.3 * (1 - i / n)) end
  beep = love.audio.newSource(sd, "static")
  stage = 1
  stage_t = 0
  times = {}
end

local function report_stage()
  table.sort(times)
  local sum = 0
  for _, t in ipairs(times) do sum = sum + t end
  local n = #times
  if n == 0 then return end
  say("load %-18s frames %4d  mean %6.2f ms  median %6.2f  p95 %6.2f  max %6.2f  (%.1f fps)", loads[stage][1], n,
    sum / n * 1000, times[math.max(1, math.floor(n / 2))] * 1000, times[math.max(1, math.floor(n * 0.95))] * 1000,
    times[n] * 1000, n / sum)
  local st = last_stats or love.graphics.getStats()
  say("   drawcalls %d, texture memory %.1f MB, %s", st.drawcalls, st.texturememory / 1048576, meminfo())
end

local function finish()
  say("memory at end: %s", meminfo())
  local path = os.getenv("PROBE_OUT") or "/data/Games/love-probe.txt"
  local f = io.open(path, "w")
  if f then
    f:write(table.concat(out, "\n"), "\n")
    f:close()
    print("wrote " .. path)
  else
    print("could not write " .. path)
  end
  love.event.quit()
end

function love.update(dt)
  if love.keyboard.isDown("escape") then finish() return end
  local js = love.joystick.getJoysticks()[1]
  if js and js:getButtonCount() > 7 and js:isDown(7) and js:isDown(8) then finish() return end
  if stage >= 1 and stage <= #loads then
    stage_t = stage_t + dt
    if stage_t > 0.5 then times[#times + 1] = dt end -- skip the first half second (shader compile, uploads)
    if stage_t > STAGE_SECONDS + 0.5 then
      report_stage()
      stage, stage_t, times = stage + 1, 0, {}
    end
  elseif stage == #loads + 1 then
    beep:play()
    say("sound: playing %s, %d sources active", tostring(beep:isPlaying()), love.audio.getActiveSourceCount())
    stage = stage + 1
    deck_until = love.timer.getTime() + (fast and 0.5 or 10)
  elseif stage == #loads + 2 and love.timer.getTime() > deck_until then
    local seen = {}
    for k in pairs(pressed) do seen[#seen + 1] = k end
    table.sort(seen)
    say("deck: %d inputs seen: %s", #seen, table.concat(seen, ", "))
    stage = stage + 1
    finish()
  end
end

function love.joystickpressed(j, b) pressed["joy button " .. b] = true end
function love.joystickaxis(j, a, v) if math.abs(v) > 0.5 then pressed["joy axis " .. a .. (v > 0 and "+" or "-")] = true end end
function love.joystickhat(j, h, d) if d ~= "c" then pressed["joy hat " .. h .. " " .. d] = true end end
function love.keypressed(k) pressed["key " .. k] = true end

function love.draw()
  rotate.begin()
  if stage >= 1 and stage <= #loads then
    loads[stage][2]()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(loads[stage][1], 20, 20, 0, 2)
  else
    love.graphics.clear(0.1, 0.12, 0.25)
    love.graphics.setFont(font)
    love.graphics.printf("Press every button and move the stick.\nThe top of this text should be at the top of the panel.",
      40, 400, 690, "center")
    local y = 520
    for k in pairs(pressed) do
      love.graphics.print(k, 300, y)
      y = y + 24
    end
  end
  rotate.finish()
  last_stats = love.graphics.getStats()
end
