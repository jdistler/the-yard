-- Home's input (main.lua's "input" until HOME_REFACTOR.md CP2): the deck and the PC's keys, the 1-player and
-- 2-player rules, the queue of presses the loop handles, and the tests' HOME_SCRIPT. It installs LÖVE's key and
-- joystick callbacks when loaded.
local I = {}

-- The cabinet's deck through SDL (games/love/yard/input.lua has the same map), and keys on a PC. Buttons 20
-- and 21 are volume down and up: the kernel changes the volume itself (volctrl.sh); Home only shows it.
I.JOY = {[1] = "low", [2] = "tl", [4] = "tr", [7] = "1p", [8] = "2p", [16] = "up", [17] = "left", [18] = "right",
         [19] = "down", [20] = "voldown", [21] = "volup"}
I.KEYS = {up = "up", down = "down", left = "left", right = "right", z = "low", x = "tl", c = "tr",
          ["1"] = "1p", ["2"] = "2p", ["return"] = "low", space = "low", ["-"] = "voldown", ["="] = "volup"}
-- Holding 1-player + 2-player for a second leaves the preview (The Yard's convention, with its meter), so 1P
-- launches on release, and only when 2P was not pressed with it.
I.HOLD_SECS = 1
I.pressed_q, I.down, I.both_seen, I.hold_t = {}, {}, false, 0
I.down_at = {}
function I.press(name) I.pressed_q[#I.pressed_q + 1] = name end
function I.control_down(name)
  local down = I.down
  down[name] = true
  I.down_at[name] = love.timer.getTime()
  if (name == "1p" and down["2p"]) or (name == "2p" and down["1p"]) then I.both_seen = true end
  if name ~= "1p" and name ~= "2p" then I.press(name) end
end
function I.control_up(name)
  -- A 1-player tap starts the game: only a press Home saw begin, and short. (Leaving a classic is a 5 s
  -- 1-player hold; let go after Home is back, and Home saw only the release: it started the game again,
  -- filmed 2026-10-27.)
  local down, down_at = I.down, I.down_at
  local seen = down[name] and down_at[name] and love.timer.getTime() - down_at[name] < 0.8
  down[name] = nil
  if name == "1p" and seen and not I.both_seen then I.press("1p") end
  if name == "2p" and seen and not I.both_seen and not down["1p"] then I.press("2p") end
  if not down["1p"] and not down["2p"] then I.both_seen = false end
end
function love.joystickpressed(_, b) if I.JOY[b] then I.control_down(I.JOY[b]) end end
function love.joystickreleased(_, b) if I.JOY[b] then I.control_up(I.JOY[b]) end end
function love.keypressed(k)
  if k == "escape" then love.event.quit(0) end
  if I.KEYS[k] then I.control_down(I.KEYS[k]) end
end
function love.keyreleased(k) if I.KEYS[k] then I.control_up(I.KEYS[k]) end end

-- HOME_SCRIPT (tests): lines "<frame> press NAME", "<frame> down NAME", "<frame> up NAME", "<frame> shot PATH",
-- "<frame> quit".
I.script = {}
do
  local path = os.getenv("HOME_SCRIPT")
  local f = path and io.open(path, "rb")
  local s = f and f:read("*a")
  if f then f:close() end
  if s then
    for line in s:gmatch("[^\n]+") do
      local fr, op, arg = line:match("^(%d+)%s+(%a+)%s*(.*)$")
      if fr then I.script[#I.script + 1] = {tonumber(fr), op, arg} end
    end
  end
end

return I
