-- Home's music, from the main thread: which song plays (musicthread.lua plays it; songs.lua has them all).
--   music.start()               the thread (once, after the first frame)
--   music.play(name, fade)      a song, crossfaded in over fade seconds (default 1.5); the same one again is
--                               left playing; "none" is silence
--   music.volume(v, ramp)       0..1
--   music.sfx(name, gain)       a sound effect from songs.SFX
--   music.check()               the thread's error, if it stopped (Home logs it)
local M = {current = nil}
local thread, ch
local pending_vol

function M.start()
  if thread or not love.thread then return end
  ch = love.thread.getChannel("music_cmd")
  thread = love.thread.newThread("musicthread.lua")
  thread:start()
  if pending_vol then ch:push({"vol", pending_vol, 0}) end
  if M.current then ch:push({"play", M.current, 0}) end
end

function M.play(name, fade)
  M.now = name
  if name == M.current then return end
  M.current = name
  if M.log then M.log("music: " .. name) end
  if ch then ch:push({"play", name, fade or 1.5}) end
end

function M.volume(v, ramp)
  pending_vol = v
  if ch then ch:push({"vol", v, ramp or 0.8}) end
end

function M.sfx(name, gain)
  if ch then ch:push({"sfx", name, gain or 1}) end
end

function M.check()
  if not thread then return nil end
  local err = thread:getError()
  if err then thread = nil ch = nil end
  return err
end

function M.quit()
  if ch then ch:push({"quit"}) end
end

return M
