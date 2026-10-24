-- The core library. Every cart gets these, before its own main.lua runs.
-- Time is counted in frames: 60 frames are one second on the cabinet.

W, H = game.w, game.h
tau = math.pi * 2
sin, cos, abs, floor, ceil, sqrt, min, max = math.sin, math.cos, math.abs, math.floor, math.ceil, math.sqrt, math.min, math.max

function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
function lerp(a, b, t) return a + (b - a) * t end
-- Move v a fraction of the way to target each frame: smooth, never overshoots.
function approach(v, target, rate) return v + (target - v) * rate end
-- Move v toward target by at most step.
function step_to(v, target, step)
  if v < target then return min(v + step, target) end
  return max(v - step, target)
end
function sign(v) return v > 0 and 1 or (v < 0 and -1 or 0) end
function round(v) return floor(v + 0.5) end
function dist(x1, y1, x2, y2) local dx, dy = x2 - x1, y2 - y1 return sqrt(dx * dx + dy * dy) end
-- A value that swings between lo and hi every period frames.
function wave(period, lo, hi, offset)
  local k = 0.5 + 0.5 * sin(((game.frame + (offset or 0)) / period) * tau)
  return lerp(lo or -1, hi or 1, k)
end
-- True for on frames out of every period: blinking prompts.
function blink(period, on)
  period = period or 60
  return game.frame % period < (on or period // 2)
end
function choose(t) return t[rndi(1, #t)] end
function shuffle(t)
  for i = #t, 2, -1 do
    local j = rndi(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end
function copy(t)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end
-- Keep only the items for which keep(item) is true, in place.
function sweep(list, keep)
  local j = 1
  for i = 1, #list do
    local v = list[i]
    list[i] = nil
    if keep(v) then list[j] = v j = j + 1 end
  end
  return list
end
function fmt(...) return string.format(...) end
-- "1 night", "3 nights".
function plural(n, one, many) return n .. " " .. (n == 1 and one or (many or one .. "s")) end

-- Easing: t from 0 to 1 in, 0 to 1 out.
ease = {
  linear = function(t) return t end,
  in_quad = function(t) return t * t end,
  out_quad = function(t) return 1 - (1 - t) * (1 - t) end,
  in_out = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end,
  out_cubic = function(t) return 1 - (1 - t) ^ 3 end,
  out_back = function(t) local c = 1.70158 return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2 end,
  out_elastic = function(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    return 2 ^ (-10 * t) * sin((t * 10 - 0.75) * tau / 3) + 1
  end,
  out_bounce = function(t)
    local n, d = 7.5625, 2.75
    if t < 1 / d then return n * t * t
    elseif t < 2 / d then t = t - 1.5 / d return n * t * t + 0.75
    elseif t < 2.5 / d then t = t - 2.25 / d return n * t * t + 0.9375
    else t = t - 2.625 / d return n * t * t + 0.984375 end
  end,
}

-- Timers, tweens, and tasks. They run before update() every frame.
local jobs = {}

local function add(job) jobs[#jobs + 1] = job return job end

-- Call fn once, frames from now.
function after(frames, fn) return add({left = frames, fn = fn}) end
-- Call fn every frames frames until it returns false or the job is cancelled.
function every(frames, fn) return add({left = frames, period = frames, fn = fn}) end
-- Slide fields of obj to the values in goal over frames: tween(pip, 30, {x = 100}, ease.out_back).
function tween(obj, frames, goal, easing, done)
  local from = {}
  for k in pairs(goal) do from[k] = obj[k] end
  return add({t = 0, frames = max(1, frames), obj = obj, from = from, goal = goal, easing = easing or ease.out_cubic, done = done})
end
-- Run fn as a little script that can wait: task(function() say("hi") wait(60) say("bye") end).
function task(fn, ...)
  local co = coroutine.create(fn)
  local job = add({co = co, wait = 1})
  local ok, w = coroutine.resume(co, ...)
  if not ok then error(w, 0) end
  if coroutine.status(co) == "dead" then job.dead = true else job.wait = w or 1 end
  return job
end
-- Inside a task: wait some frames (default 1).
function wait(frames) coroutine.yield(frames or 1) end
-- Inside a task: wait until pred() is true.
function wait_until(pred) while not pred() do coroutine.yield(1) end end
function cancel(job) if job then job.dead = true end end
function cancel_all() jobs = {} end
function busy() return #jobs > 0 end

local function run_jobs()
  local list = jobs
  for i = 1, #list do
    local j = list[i]
    if not j.dead then
      if j.co then
        j.wait = j.wait - 1
        if j.wait <= 0 then
          local ok, w = coroutine.resume(j.co)
          if not ok then error(w, 0) end
          if coroutine.status(j.co) == "dead" then j.dead = true else j.wait = w or 1 end
        end
      elseif j.obj then
        j.t = j.t + 1
        local k = j.easing(min(1, j.t / j.frames))
        for f, v in pairs(j.goal) do j.obj[f] = j.from[f] + (v - j.from[f]) * k end
        if j.t >= j.frames then
          j.dead = true
          if j.done then j.done(j.obj) end
        end
      else
        j.left = j.left - 1
        if j.left <= 0 then
          if j.period then
            if j.fn() == false then j.dead = true else j.left = j.period end
          else
            j.dead = true
            j.fn()
          end
        end
      end
    end
  end
  -- Drop finished jobs; keep any added while running.
  if list == jobs then
    sweep(jobs, function(j) return not j.dead end)
  end
end

-- The hooks the runtime calls. A cart defines init, update, draw, and if it plays itself, bot.
local hooks = {before_update = {}, after_draw = {}, quit = {}}
-- Library pieces hook in here; a cart rarely needs to.
function on_update(fn) hooks.before_update[#hooks.before_update + 1] = fn end
function on_draw(fn) hooks.after_draw[#hooks.after_draw + 1] = fn end
function on_quit(fn) hooks.quit[#hooks.quit + 1] = fn end

-- Strict names. Once main.lua has loaded, reading a name nobody ever set is an error (a typo
-- such as "scroe" would otherwise quietly be nil), and once init() has run, making a new
-- global is an error too (a forgotten "local" inside update() would otherwise leak).
local function cart(name) return rawget(_G, name) end
local function strict(writes)
  setmetatable(_G, {
    __index = function(_, k)
      error("unknown name '" .. tostring(k) .. "': a typo, or something never set", 2)
    end,
    __newindex = writes and function(_, k)
      error("new global '" .. tostring(k) .. "' made while the game runs: add 'local', or set it at the top of main.lua", 2)
    end or nil,
  })
end

function __yard_init()
  strict(false)
  if cart("init") then init() end
  strict(true)
end

function __yard_update()
  run_jobs()
  for _, fn in ipairs(hooks.before_update) do fn() end
  -- The built-in player: the tests (CAB_AUTOPLAY) and the attract demo drive the deck through it.
  if cart("bot") and (game.autoplay or game.demo) then
    input.bot_clear()
    bot()
  end
  if cart("update") then update() end
end

function __yard_draw()
  if cart("draw") then draw() end
  for _, fn in ipairs(hooks.after_draw) do fn() end
end

function __yard_quit()
  if cart("quit") then quit() end
  for _, fn in ipairs(hooks.quit) do fn() end
end
