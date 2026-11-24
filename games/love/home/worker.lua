-- Home's background worker (a love.thread): the slow things to make, off the frame. Asked through the
-- "home_work" channel with {"art", key, path} (decode a PNG into ImageData); answers on "home_done" with
-- {"art", key, imagedata}. (It made the old menu music too, which alone stalled Home for 0.36 s on the cabinet;
-- the music is music.lua's own thread now.)
require("love.image")
require("love.sound")
require("love.filesystem")
local work = love.thread.getChannel("home_work")
local done = love.thread.getChannel("home_done")

while true do
  local job = work:demand()
  if job[1] == "quit" then break end
  if job[1] == "art" then
    local bytes
    if job[4] == "love" then
      bytes = love.filesystem.read(job[3])                 -- (a file inside home.love: the tiles' pictures)
    else
      local f = io.open(job[3], "rb")
      bytes = f and f:read("*a")
      if f then f:close() end
    end
    local ok, data = false, nil
    if bytes then ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(bytes, "a.png")) end
    done:push({"art", job[2], ok and data or nil})
  elseif job[1] == "world" then
    -- {"world", name, path, fallback}: the menu's world picture (ETC1 .pkm) as CompressedData, for the main thread
    -- to upload (homestate.lua's ST.world_load)
    local function read(p)
      local f = io.open(p, "rb")
      local b = f and f:read("*a")
      if f then f:close() end
      return b
    end
    local bytes = read(job[3]) or read(job[4])
    local ok, cd = false, nil
    if bytes then
      ok, cd = pcall(function()
        local fd = love.filesystem.newFileData(bytes, "w.pkm")
        local c = love.image.newCompressedData(fd)
        fd:release()
        return c
      end)
    end
    done:push({"world", job[2], ok and cd or nil})
  end
end
