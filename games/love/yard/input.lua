-- The deck (CARTS.md § 4 input): the cabinet's joystick, the PC keyboard, the cart's bot, and test scripts.
--
-- The cabinet's deck is one joystick. Under SDL 2.0.7 (the stock games) its buttons were LOW 0, TL 1, TR 3,
-- 1P 6, 2P 7, and the stick 15 to 18 (up, left, right, down) (GAMEDEV.md § 2). LÖVE counts from 1. SDL 2.30
-- is expected to number them the same way; the LÖVE probe records what it really sends, and a file
-- /data/Games/yard-deck.txt (lines "button N NAME") or YARD_DECK overrides this table without a rebuild.
local I = {}
local NAMES = {"up", "down", "left", "right", "low", "tl", "tr", "1p", "2p", "start", "select"}
local SCRIPT_NAMES = {UP = "up", DOWN = "down", LEFT = "left", RIGHT = "right", LOW = "low", TL = "tl", TR = "tr",
                      ["1P"] = "1p", ["2P"] = "2p", START = "start", SELECT = "select",
                      A = "low", B = "tl", X = "tr", L = "1p", R = "2p"}
local JOY = {[1] = "low", [2] = "tl", [4] = "tr", [7] = "1p", [8] = "2p", [16] = "up", [17] = "left", [18] = "right", [19] = "down"}
local KEYS = {up = "up", down = "down", left = "left", right = "right", z = "low", x = "tl", c = "tr",
              ["1"] = "1p", ["2"] = "2p", ["return"] = "start", rshift = "select"}

local held, prev, human, bot = {}, {}, {}, {}
local script, script_frame, script_title = nil, 0, nil
local scripts_by_title = {}
local quit_frames, quit_since, quit_progress = 0, nil, 0
local shot_request

local function load_deck_file(path)
  local f = path and io.open(path)
  if not f then return end
  for line in f:lines() do
    local n, name = line:match("^%s*button%s+(%d+)%s+(%S+)")
    if n then JOY[tonumber(n)] = SCRIPT_NAMES[name:upper()] or name:lower() end
  end
  f:close()
end
load_deck_file(os.getenv("YARD_DECK") or "/data/Games/yard-deck.txt")

-- CAB_SCRIPT, the same format as engine/cab.c: "title=<window title>" sections, "<frame> down NAME",
-- "<frame> up NAME", "<frame> shot <path>", "<frame> quit". Each title keeps its own frame count.
local function parse_script(path)
  local f = path and path ~= "" and io.open(path)
  if not f then return nil end
  local sections, titled, cur = {}, false, "*"
  for line in f:lines() do
    line = line:gsub("#.*", ""):match("^%s*(.-)%s*$")
    if line:sub(1, 6) == "title=" then
      titled = true
      cur = line:sub(7)
    elseif line ~= "" then
      local fr, op, arg = line:match("^(%d+)%s+(%S+)%s*(%S*)")
      if fr then
        sections[cur] = sections[cur] or {}
        table.insert(sections[cur], {frame = tonumber(fr), op = op, arg = arg})
      end
    end
  end
  f:close()
  return {sections = sections, titled = titled}
end
local loaded = parse_script(os.getenv("CAB_SCRIPT"))

function I.scripted() return loaded ~= nil end

-- A cart starts: its section of the script, from frame 0. The menu, coming back, carries on.
function I.begin(title, resume)
  script_title = title
  if loaded then
    local cmds = {}
    for name, list in pairs(loaded.sections) do
      if not loaded.titled or name == title or name == "*" then
        for _, c in ipairs(list) do cmds[#cmds + 1] = c end
      end
    end
    script = cmds
    if resume and scripts_by_title[title] then script_frame = scripts_by_title[title]
    else script_frame = 0 end
  end
  for _, n in ipairs(NAMES) do held[n], prev[n], human[n], bot[n] = false, false, false, false end
  -- A button still held from the menu is not a new press.
  quit_frames, quit_since, quit_progress = 0, nil, 0
end
function I.suspend() if script_title then scripts_by_title[script_title] = script_frame end end

-- Called once a frame, before update. Returns false when the cart should leave.
function I.poll()
  local quit = false
  for _, n in ipairs(NAMES) do prev[n] = held[n] human[n] = false end
  for key, name in pairs(KEYS) do if love.keyboard.isDown(key) then human[name] = true end end
  if love.keyboard.isDown("escape") then quit = true end
  for _, j in ipairs(love.joystick.getJoysticks()) do
    for b, name in pairs(JOY) do
      if b <= j:getButtonCount() and j:isDown(b) then human[name] = true end
    end
    if j:getAxisCount() >= 2 then
      local ax, ay = j:getAxis(1), j:getAxis(2)
      if ax < -0.25 then human.left = true elseif ax > 0.25 then human.right = true end
      if ay < -0.25 then human.up = true elseif ay > 0.25 then human.down = true end
    end
    if j:getHatCount() >= 1 then
      local h = j:getHat(1)
      if h:find("u") then human.up = true end
      if h:find("d") then human.down = true end
      if h:find("l") then human.left = true end
      if h:find("r") then human.right = true end
    end
  end
  if script then
    -- Latest frame wins per button; holds latch until up.
    local latest = {}
    for _, c in ipairs(script) do
      if c.frame <= script_frame then
        if c.op == "down" or c.op == "up" then
          local n = SCRIPT_NAMES[c.arg:upper()]
          if n and (not latest[n] or c.frame >= latest[n].frame) then latest[n] = c end
        elseif c.frame == script_frame and c.op == "shot" then
          shot_request = c.arg
        elseif c.frame == script_frame and c.op == "quit" then
          quit = true
        end
      end
    end
    for n, c in pairs(latest) do human[n] = c.op == "down" end
    local maxf = tonumber(os.getenv("CAB_MAX_FRAMES") or "")
    if maxf and script_frame + 1 >= maxf then quit = true end
    script_frame = script_frame + 1
  end
  for _, n in ipairs(NAMES) do held[n] = human[n] or bot[n] end
  quit_progress = 0
  if (human["1p"] and human["2p"]) or (human.select and human.start) then
    if loaded then
      quit_frames = quit_frames + 1
      quit_progress = quit_frames / 60
      if quit_frames >= 60 then quit = true end
    else
      quit_since = quit_since or love.timer.getTime()
      quit_progress = (love.timer.getTime() - quit_since) / 1
      if quit_progress >= 1 then quit = true end
    end
  else
    quit_frames, quit_since = 0, nil
  end
  return not quit
end

function I.take_shot() local s = shot_request shot_request = nil return s end
function I.quit_progress() return math.min(1, quit_progress) end

-- ------------------------------------------------------------------ the cart API

local api = {}
I.api = api
local function check(b)
  for _, n in ipairs(NAMES) do if n == b then return b end end
  error("no button named '" .. tostring(b) .. "' (the deck has up down left right low tl tr 1p 2p)", 3)
end
function api.down(b) return held[check(b)] end
function api.pressed(b) b = check(b) return held[b] and not prev[b] end
function api.released(b) b = check(b) return prev[b] and not held[b] end
function api.action() return (held.low and not prev.low) or (held.tl and not prev.tl) or (held.tr and not prev.tr) end
function api.action_down() return held.low or held.tl or held.tr end
function api.dir()
  return (held.right and 1 or 0) - (held.left and 1 or 0), (held.down and 1 or 0) - (held.up and 1 or 0)
end
function api.any() for _, n in ipairs(NAMES) do if human[n] then return true end end return false end
function api.quitting() return I.quit_progress() end
function api.bot(b, down) bot[check(b)] = down == nil and true or down end
function api.bot_clear() for _, n in ipairs(NAMES) do bot[n] = false end end

return I
