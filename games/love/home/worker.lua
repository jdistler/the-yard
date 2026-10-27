-- Home's background worker (a love.thread): the slow things to make, off the frame. Asked through the
-- "home_work" channel with {"art", key, path} (decode a PNG into ImageData) and {"music"}; answers on
-- "home_done" with {"art", key, imagedata} and {"music", sounddata}. Without it, the music alone stalled
-- Home for 0.36 s on the cabinet right after its first frame (2026-10-27).
require("love.image")
require("love.sound")
require("love.filesystem")
local work = love.thread.getChannel("home_work")
local done = love.thread.getChannel("home_done")

while true do
  local job = work:demand()
  if job[1] == "quit" then break end
  if job[1] == "art" then
    local f = io.open(job[3], "rb")
    local bytes = f and f:read("*a")
    if f then f:close() end
    local ok, data = false, nil
    if bytes then ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(bytes, "a.png")) end
    done:push({"art", job[2], ok and data or nil})
  elseif job[1] == "music" then
    local sound = require("sound")
    done:push({"music", sound.music_data()})
  end
end
