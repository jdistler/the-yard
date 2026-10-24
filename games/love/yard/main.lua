-- yard on LÖVE: the cart runtime with the GPU drawing. The same carts as games/engine/runtime.c, the same API
-- (CARTS.md), the same sandbox rules; the picture is drawn by love.graphics at the panel's resolution.
--
--   love yard.love            the menu (the cart with system = true)
--   love yard.love keep       one cart
--
-- Carts come from YARD_CARTS (a folder of cart folders), else yard.pak (YARD_PAK, default beside the
-- program on the cabinet: /data/Games/yard.pak). Saves are <name>.sav in the current directory, as the C
-- runtime writes them, so both runtimes share them.
local bit = require("bit")
local gfx = require("gfx")
local audio = require("audio")
local input = require("input")
local lg = love.graphics

local CART_MAX_STEPS_FRAME, CART_MAX_STEPS_INIT = 150000000, 400000000
local MEM_CAP = (tonumber(os.getenv("YARD_MEM_MB") or "") or 32) * 1024 * 1024
local headless = os.getenv("YARD_HEADLESS") == "1"
local carts, by_id = {}, {}
local Host_launch
local pak_files = {}
local fast = false
local log_file

local function log(s)
  io.stderr:write(s, "\n")
  if log_file then log_file:write(s, "\n") log_file:flush() end
end

-- ------------------------------------------------------------------ cart files: a folder, or the pack

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function crc32(s)
  local crc = 0xffffffff
  for i = 1, #s do
    crc = bit.bxor(crc, s:byte(i))
    for _ = 1, 8 do
      local m = -bit.band(crc, 1)
      crc = bit.bxor(bit.rshift(crc, 1), bit.band(0xedb88320, m))
    end
  end
  return bit.band(bit.bnot(crc), 0xffffffff) % 4294967296
end

local function u32(s, i) local a, b, c, d = s:byte(i, i + 3) return a + b * 256 + c * 65536 + d * 16777216 end

-- The pack written by `cart pack`: "YARDPAK1", u32 count, u32 used, then (u16 name length, name, u32 length,
-- u32 crc32, data) per file. A file that fails its checksum drops its whole cart.
local function open_pak(path)
  local s = read_file(path)
  if not s or s:sub(1, 8) ~= "YARDPAK1" then return false end
  local count, used = u32(s, 9), u32(s, 13)
  local o, bad = 17, {}
  for _ = 1, count do
    if o + 1 > used then break end
    local nl = s:byte(o) + s:byte(o + 1) * 256
    local name = s:sub(o + 2, o + 1 + nl)
    o = o + 2 + nl
    local len, crc = u32(s, o), u32(s, o + 4)
    o = o + 8
    local data = s:sub(o, o + len - 1)
    o = o + len
    if crc32(data) ~= crc then
      log("yard: " .. path .. ": " .. name .. " fails its checksum")
      bad[name:match("^([^/]+)") or ""] = true
    else
      pak_files[name] = data
    end
  end
  for name in pairs(pak_files) do
    if bad[name:match("^([^/]+)") or ""] then pak_files[name] = nil end
  end
  return true
end

local function cart_read(cart, name)
  if cart.pak then return pak_files[cart.id .. "/" .. name] end
  return read_file(cart.dir .. "/" .. name)
end

-- ------------------------------------------------------------------ the sandbox

local SAFE = {"assert", "error", "ipairs", "next", "pairs", "pcall", "select", "tonumber", "tostring", "type",
              "unpack", "xpcall", "rawget", "rawset", "rawequal", "rawlen", "setmetatable", "getmetatable"}

local function copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end

-- The engine's generator (xorshift32), so a seed replays the same game as the C runtime.
local rng_state = 0x9e3779b9
local function rng_u32()
  local x = rng_state
  x = bit.bxor(x, bit.lshift(x, 13))
  x = bit.bxor(x, bit.rshift(x, 17))
  x = bit.bxor(x, bit.lshift(x, 5))
  rng_state = x
  return x % 4294967296
end
local function rng_seed(s) rng_state = (s ~= 0) and bit.tobit(s) or 0x9e3779b9 end
local function rng_f() return math.floor(rng_u32() / 256) / 16777216 end
local function rng_int(lo, hi) if hi <= lo then return lo end return lo + rng_u32() % (hi - lo + 1) end
gfx.rng_f, gfx.rng_int = rng_f, rng_int

local function color_api(env)
  local rgba = gfx.rgba
  local function pack(r, g, b, a)
    local c = math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
    if a and a < 0.999 then c = c + math.max(1, math.floor(a * 255 + 0.5)) * 16777216 end
    return c
  end
  env.rgb = function(r, g, b) return (r % 256) * 65536 + (g % 256) * 256 + (b % 256) end
  env.rgba = function(r, g, b, a) return (r % 256) * 65536 + (g % 256) * 256 + (b % 256) + math.max(1, math.min(255, a)) * 16777216 end
  env.hex = function(s)
    s = s:gsub("^#", "")
    if #s == 3 then s = s:gsub(".", "%0%0") end
    return tonumber(s, 16)
  end
  env.alpha = function(c, a)
    a = math.max(1, math.min(255, math.floor(a)))
    return (c % 0x1000000) + a * 0x1000000
  end
  env.mix = function(a, b, t)
    local r0, g0, b0, a0 = rgba(a)
    local r1, g1, b1, a1 = rgba(b)
    return pack(r0 + (r1 - r0) * t, g0 + (g1 - g0) * t, b0 + (b1 - b0) * t, a0 + (a1 - a0) * t)
  end
  env.shade = function(c, k)
    local r, g, b, a = rgba(c)
    return pack(math.min(1, r * k), math.min(1, g * k), math.min(1, b * k), a)
  end
  env.hsv = function(h, s, v)
    s, v = s or 1, v or 1
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
    return pack(r, g, b)
  end
  env.rnd = function(a, b)
    if a == nil then return rng_f() elseif b == nil then return rng_f() * a end
    return a + (b - a) * rng_f()
  end
  env.rndi = function(lo, hi) return rng_int(lo, hi) end
end

local steps_left, phase_name = 0, "start"
local function watchdog()
  steps_left = steps_left - 100000
  if steps_left < 0 then
    steps_left = 1e15
    error(phase_name .. "() ran far too long: is there a loop that never ends?", 2)
  end
end

local function budget(name, steps)
  phase_name, steps_left = name, steps
end

local function make_save(env, name)
  local values, order = {}, {}
  if name and name:match("^[a-z0-9_-]+$") then
    local f = io.open(name .. ".sav")
    if f then
      for line in f:lines() do
        local k, v = line:match("^(%S+) (%S+)%s*$")
        if k and #order < 256 and k:match("^[a-z0-9_-]+$") and #k <= 32 and v:match("^[%w_%.%-]+$") and #v <= 32 then
          local n = tonumber(v)
          if v:match("^%-?%d+$") then
            if math.abs(n) <= 1e9 then
              if values[k] == nil then order[#order + 1] = k end
              values[k] = n
            end
          else
            if values[k] == nil then order[#order + 1] = k end
            values[k] = v
          end
        end
      end
      f:close()
    end
  end
  local save = {}
  function save.get(k, default)
    local v = values[k]
    if v == nil then return default end
    if type(default) == "number" and type(v) ~= "number" then return default end
    return v
  end
  function save.set(k, v)
    if not tostring(k):match("^[a-z0-9_-]+$") then error("save key '" .. tostring(k) .. "': lower-case letters, digits, _ and -", 2) end
    if type(v) == "number" then
      if math.abs(v) > 1e9 then error("save " .. k .. ": out of range", 2) end
      v = math.floor(v)
    elseif v ~= nil then
      v = tostring(v)
      if not v:match("^[%w_%.%-]+$") or #v > 32 then error("save " .. k .. ": '" .. v .. "' is not one word", 2) end
    end
    if values[k] == nil and v ~= nil then order[#order + 1] = k end
    values[k] = v
  end
  function save.write()
    if not name then error("this cart has no save name (info.lua save = \"...\")", 2) end
    local tmp = name .. ".sav.tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    for _, k in ipairs(order) do
      local v = values[k]
      if v ~= nil then f:write(k, " ", type(v) == "number" and string.format("%d", v) or v, "\n") end
    end
    f:close()
    -- LÖVE has no fsync; rename is atomic, and the sync after it asks the kernel to write it out.
    local ok = os.rename(tmp, name .. ".sav")
    os.execute("sync")
    return ok and true or false
  end
  function save.all() return copy(values) end
  save._values = values
  env.save = save
end

local function new_env(cart, is_info)
  local env = {}
  for _, k in ipairs(SAFE) do env[k] = _G[k] end
  env.string = copy(string)
  env.string.dump = nil
  env.table = copy(table)
  env.math = copy(math)
  env.math.random = function(a, b)
    if a == nil then return rng_f() elseif b == nil then return rng_int(1, a) end
    return rng_int(a, b)
  end
  env.math.randomseed = nil
  env.coroutine = copy(coroutine)
  env._G = env
  env._VERSION = _VERSION
  local function plog(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    log(table.concat(t, " "))
  end
  env.log, env.print = plog, plog
  env.gfx = copy(gfx.api)
  env.gfx.image = function(n)
    if type(n) ~= "string" or n:find("%.%.") or n:sub(1, 1) == "/" then error("image '" .. tostring(n) .. "': a name inside the cart's folder", 2) end
    local b = cart_read(cart, n)
    if not b then error("image '" .. n .. "': no such file in the cart", 2) end
    local img = gfx.image_from_bytes(b, n)
    if not img then error("image '" .. n .. "' did not load (PNG only)", 2) end
    return img
  end
  env.toon = gfx.toon
  env.light = gfx.light
  env.particles = gfx.particles
  env.input = input.api
  env.sfx = audio.sfx
  env.music = audio.music
  color_api(env)
  env.game = {id = cart.id, title = cart.title or cart.id, w = cart.w, h = cart.h, fast = fast,
              autoplay = os.getenv("CAB_AUTOPLAY") ~= nil, scripted = input.scripted(), dev = os.getenv("YARD_DEV") ~= nil,
              selftest = os.getenv(cart.id:upper() .. "_SELFTEST") ~= nil or os.getenv("CART_SELFTEST") ~= nil,
              frame = 0}
  env.game.quit = function() cart.want_quit = true end
  local imported = {}
  env.import = function(name)
    if not tostring(name):match("^[a-z0-9_-]+$") then error("import '" .. tostring(name) .. "': a file name in the cart's folder, without .lua", 2) end
    if imported[name] ~= nil then return imported[name] end
    local src = cart_read(cart, name .. ".lua")
    if not src then error("import '" .. name .. "': no such file", 2) end
    local fn, err = loadstring(src, "@" .. cart.id .. "/" .. name .. ".lua")
    if not fn then error(err, 0) end
    setfenv(fn, env)
    local v = fn()
    if v == nil then v = true end
    imported[name] = v
    return v
  end
  env.readtext = function(name)
    if type(name) ~= "string" or name:find("%.%.") or name:sub(1, 1) == "/" then error("readtext '" .. tostring(name) .. "': a file name in the cart's folder", 2) end
    local s = cart_read(cart, name)
    if not s then error("readtext '" .. name .. "': no such file in the cart", 2) end
    return s
  end
  env.card = {
    here = function() return false end,
    read = function() return nil end,
    write = function() return false end,
  }
  return env
end

local LIB = {}
local function load_lib()
  local names = love.filesystem.getDirectoryItems("lib")
  table.sort(names)
  for _, n in ipairs(names) do
    if n:match("%.lua$") then LIB[#LIB + 1] = {n, love.filesystem.read("lib/" .. n)} end
  end
end

local function run_lib(env)
  for _, l in ipairs(LIB) do
    local fn, err = loadstring(l[2], "=lib/" .. l[1])
    if not fn then error(err, 0) end
    setfenv(fn, env)
    budget("the library", 50000000)
    fn()
  end
end

local function run_chunk(cart, env, file)
  local src = cart_read(cart, file)
  if not src then error(cart.id .. "/" .. file .. ": missing", 0) end
  local fn, err = loadstring(src, "@" .. cart.id .. "/" .. file)
  if not fn then error(err, 0) end
  setfenv(fn, env)
  return fn()
end

-- ------------------------------------------------------------------ finding carts

local function load_info(cart)
  local env = new_env(cart, true)
  env.game.w, env.game.h = 240, 320
  local ok, info = pcall(function()
    debug.sethook(watchdog, "", 100000)
    run_lib(env)
    budget("info.lua", 20000000)
    return run_chunk(cart, env, "info.lua")
  end)
  debug.sethook()
  if not ok or type(info) ~= "table" then
    log("yard: skipping cart " .. cart.id .. ": " .. tostring(ok and "info.lua must return a table" or info))
    return false
  end
  env.info = info
  cart.env_info = env
  cart.info = info
  cart.title = type(info.title) == "string" and info.title or cart.id
  cart.order = tonumber(info.order) or 50
  cart.system = info.system and true or false
  cart.native = type(info.native) == "string" and info.native or nil
  cart.w, cart.h = 240, 320
  if info.size == "large" then cart.w, cart.h = 384, 512 end
  return true
end

local function add_cart(cart)
  if by_id[cart.id] or not cart.id:match("^[a-z0-9_-]+$") then return end
  if load_info(cart) then
    -- The LÖVE rows (loveprobe, loveyard) start LÖVE itself; a second one inside this one would not fit
    -- in the cabinet's 128 MB.
    if cart.native and cart.native:match("^love") then return end
    carts[#carts + 1] = cart
    by_id[cart.id] = cart
  end
end

local function scan()
  local dir = os.getenv("YARD_CARTS")
  if dir and dir ~= "" then
    local p = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
    if p then
      for name in p:lines() do
        if read_file(dir .. "/" .. name .. "/info.lua") then add_cart({id = name, dir = dir .. "/" .. name}) end
      end
      p:close()
    end
  end
  local pak = os.getenv("YARD_PAK") or "/data/Games/yard.pak"
  if open_pak(pak) then
    local ids = {}
    for name in pairs(pak_files) do
      local id = name:match("^([^/]+)/info%.lua$")
      if id then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do add_cart({id = id, pak = true}) end
  end
  table.sort(carts, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
end

-- ------------------------------------------------------------------ running a cart

local current
local present                    -- defined below

local function call(cart, name, steps)
  local fn = rawget(cart.env, name)
  if type(fn) ~= "function" then return true end
  budget(name:gsub("^__yard_", ""), steps)
  debug.sethook(watchdog, "", 100000)
  local ok, err = xpcall(fn, debug.traceback)
  debug.sethook()
  gfx.toon_reset()
  if not ok then cart.err = tostring(err) end
  return ok
end

local function boot(cart)
  local env = new_env(cart)
  cart.env = env
  make_save(env, type(cart.info.save) == "string" and cart.info.save or nil)
  env.info = cart.info
  if cart.system then
    env.yard = {
      carts = function()
        local out = {}
        for _, c in ipairs(carts) do
          if not c.system then
            local t = {id = c.id, title = c.title}
            for k, v in pairs(c.info) do if type(v) == "string" or type(v) == "number" then t[k] = v end end
            out[#out + 1] = t
          end
        end
        return out
      end,
      stat = function(id)
        local c = by_id[id]
        if not c or type(c.info.stat) ~= "function" then return nil end
        local tmp = {}
        make_save(tmp, type(c.info.save) == "string" and c.info.save or c.id)
        local ok, s = pcall(c.info.stat, tmp.save._values)
        return ok and type(s) == "string" and s or nil
      end,
      icon = function(id, x, y, lit, t)
        local c = by_id[id]
        if c and type(c.info.icon) == "function" then
          local ok, err = pcall(c.info.icon, x, y, lit, t)
          if not ok then log("yard: " .. id .. " icon: " .. tostring(err)) c.info.icon = nil end
        end
      end,
      launch = function(id) return Host_launch(id) end,
      card = function() return false end,
    }
  end
  local ok, err = pcall(function()
    debug.sethook(watchdog, "", 100000)
    run_lib(env)
    budget("main.lua", 200000000)
    run_chunk(cart, env, "main.lua")
  end)
  debug.sethook()
  if not ok then cart.err = tostring(err) return false end
  return true
end

local function oops(cart, seconds)
  log(cart.id .. " error: " .. tostring(cart.err))
  audio.music.stop()
  audio.sfx.slide("tri", 520, 180, 0.4, 0.25)
  local t = 0
  while true do
    love.event.pump()
    for e in love.event.poll() do if e == "quit" then return end end
    if not input.poll() then return end
    gfx.begin_frame()
    local a = gfx.api
    a.vgrad(0, 0, cart.w, cart.h, 0x2a1840, 0x4a2050)
    a.text("Oops!", cart.w / 2, 26 + math.sin(t * 0.08) * 2, 28, 0xffd257, "center", 0x1a1230)
    a.text("This game tripped.", cart.w / 2, 62, 14, 0xfff6ea, "center")
    a.text(t > 60 and "Press a button to go back." or "One moment...", cart.w / 2, 80, 14, 0xc0b8ff, "center")
    a.rrect(8, 108, cart.w - 16, cart.h - 124, 6, 0x78000000)
    local y = 116
    for line in tostring(cart.err):gmatch("[^\n]+") do
      if y > cart.h - 24 then break end
      a.text(line:sub(1, 60), 14, y, 10, 0xffe8f0)
      y = y + 12
    end
    present(cart, 0)
    t = t + 1
    if (t > 60 and input.api.action()) or t > seconds * 60 then return end
  end
end

-- Run a cart until it quits. Returns "ok" or "stumbled".
local function run(cart, resume_title)
  local keep = current
  current = cart
  cart.want_quit = false
  gfx.init(cart.w, cart.h, 768 / cart.w)
  gfx.particles.clear()
  audio.reset()
  input.begin(cart.title, false)
  if not boot(cart) or not call(cart, "__yard_init", CART_MAX_STEPS_INIT) then
    oops(cart, 5)
    current = keep
    return "stumbled"
  end
  local frame = 0
  local stats = os.getenv("YARD_STATS") ~= nil
  local check = tonumber(os.getenv("YARD_CHECK_FRAMES") or "")
  local t_up, t_draw = 0, 0
  while not cart.want_quit do
    love.event.pump()
    local quit = false
    for e in love.event.poll() do if e == "quit" then quit = true end end
    if quit or not input.poll() then break end
    cart.env.game.frame = frame
    local t0 = love.timer.getTime()
    if not call(cart, "__yard_update", CART_MAX_STEPS_FRAME) then oops(cart, 5) current = keep return "stumbled" end
    gfx.particles.update()
    audio.update(1 / 60)
    local t1 = love.timer.getTime()
    gfx.begin_frame()
    if not call(cart, "__yard_draw", CART_MAX_STEPS_FRAME) then oops(cart, 5) current = keep return "stumbled" end
    local t2 = love.timer.getTime()
    present(cart, input.quit_progress())
    t_up, t_draw = t_up + (t1 - t0), t_draw + (t2 - t1)
    frame = frame + 1
    if collectgarbage("count") * 1024 + gfx.memory() > MEM_CAP then
      collectgarbage()
      gfx.collect()
      if collectgarbage("count") * 1024 + gfx.memory() > MEM_CAP then
        cart.err = "the game used up its memory (" .. math.floor(MEM_CAP / 1048576) .. " MB). Is a list growing every frame?"
        oops(cart, 5)
        current = keep
        return "stumbled"
      end
    end
    if stats and frame % 300 == 0 then
      log(string.format("stats %s frame %d update %.2fms draw %.2fms lua %dKB images %dKB", cart.id, frame,
        t_up / 300 * 1000, t_draw / 300 * 1000, collectgarbage("count"), gfx.memory() / 1024))
      t_up, t_draw = 0, 0
    end
    if check and frame >= check then break end
  end
  call(cart, "__yard_quit", CART_MAX_STEPS_INIT)
  current = keep
  return "ok"
end

Host_launch = function(id)
  local c = by_id[id]
  if not c or c.system then return "missing" end
  local menu = current
  input.suspend()
  local how
  if c.native then
    -- A native program needs the screen to itself.
    local path = (os.getenv("YARD_NATIVE_DIR") or "/data/Games") .. "/" .. c.native
    if not read_file(path) then
      how = "missing"
    else
      love.window.close()
      local ok = os.execute('"' .. path .. '"' .. (fast and " -fast" or ""))
      love.window.setMode(0, 0, {fullscreen = not headless, fullscreentype = "desktop", vsync = 1})
      how = (ok == 0 or ok == true) and "ok" or "stumbled"
    end
  else
    c.env = nil
    how = run(c)
  end
  -- Back to the menu: its window size, its section of the script.
  gfx.init(menu.w, menu.h, 768 / menu.w)
  input.begin(menu.title, true)
  audio.reset()
  return how
end

-- ------------------------------------------------------------------ the picture

-- The panel shows the 1024x768 framebuffer turned 90 degrees clockwise: the top of the game goes on the left.
local turn
function present(cart, quitting)
  local sx, sy = gfx.finish_frame(quitting)
  local shot = input.take_shot()
  local canvas = gfx.screen()
  if shot then
    local data = canvas:newImageData()
    local png = data:encode("png")
    local f = io.open(shot, "wb")
    if f then f:write(png:getString()) f:close() end
  end
  if headless then return end
  lg.setCanvas()
  lg.origin()
  lg.clear(0, 0, 0, 1)
  lg.setColor(1, 1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  local ww, wh = lg.getDimensions()
  local cw, ch = canvas:getDimensions()
  if turn == nil then turn = ww > wh and os.getenv("YARD_UPRIGHT") ~= "1" end
  if turn then
    local s = math.min(ww / ch, wh / cw)
    lg.draw(canvas, ww / 2 + sx * s, wh / 2 + sy * s, -math.pi / 2, s, s, cw / 2, ch / 2)
  else
    local s = math.min(ww / cw, wh / ch)
    lg.draw(canvas, ww / 2 + sx * s, wh / 2 + sy * s, 0, s, s, cw / 2, ch / 2)
  end
  lg.setBlendMode("alpha")
  lg.present()
end

-- ------------------------------------------------------------------ main

-- A fault in the runtime itself (not in a cart): log it and leave, so the menu or start.sh carries on. LÖVE's
-- own error screen would wait for a keyboard the cabinet does not have.
function love.errorhandler(msg)
  log("yard: runtime error: " .. tostring(msg) .. "\n" .. debug.traceback("", 2))
  return function() return 1 end
end

function love.run()
  return function()
    log_file = os.getenv("YARD_LOG") and io.open(os.getenv("YARD_LOG"), "a")
    local want
    for _, a in ipairs(arg or {}) do
      if a == "-fast" then fast = true elseif a:match("^[a-z0-9_-]+$") then want = a end
    end
    local seed = tonumber(os.getenv("CAB_SEED") or "")
    if seed then rng_seed(seed) elseif input.scripted() or os.getenv("CAB_AUTOPLAY") then rng_seed(1)
    else rng_seed(math.floor(os.time() * 2654435761 % 4294967296)) end
    gfx.msaa = tonumber(os.getenv("YARD_MSAA") or "4")
    gfx.load_font(0, love.filesystem.newFileData("fonts/Fredoka-SemiBold.ttf"))
    load_lib()
    scan()
    if want then
      local c = by_id[want]
      if not c then log("yard: no cart named " .. want) return 127 end
      if c.native then return 127 end
      local how = run(c)
      return how == "ok" and 0 or 3
    end
    for _, c in ipairs(carts) do
      if c.system then
        local how = run(c)
        return how == "ok" and 0 or 3
      end
    end
    log("yard: no menu cart (info.lua with system = true)")
    return 127
  end
end
