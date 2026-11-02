-- Home's music thread (a love.thread, started by music.lua): synth.lua playing songs.lua into a QueueableSource,
-- a little ahead of the speaker, for as long as Home runs. Commands on "music_cmd":
--   {"play", name, fade_s}   that song from its start ("none": silence), crossfading
--   {"vol", v, ramp_s}       the music's volume (0..1)
--   {"sfx", name, gain}      a sound effect (songs.SFX) over the music
--   {"quit"}
require("love.audio")
require("love.sound")
require("love.timer")
require("love.filesystem")
local ffi = require("ffi")
local synth = require("synth")
local songs = require("songs")

local cmd = love.thread.getChannel("music_cmd")
local N = 1024                                    -- samples a buffer (46 ms); 6 queued: ~0.28 s ahead
local src = love.audio.newQueueableSource(synth.RATE, 16, 1, 6)
local sd = love.sound.newSoundData(N, synth.RATE, 16, 1)
local out = ffi.cast("int16_t*", sd:getFFIPointer())
local buf = ffi.new("float[?]", N)
local fxbuf = ffi.new("float[?]", N)
local mx = synth.mixer(songs)
local effects = {}                                -- sound effects playing: {player, gain}

while true do
  local c = cmd:pop()
  while c do
    if c[1] == "quit" then src:stop() return end
    if c[1] == "play" then mx:play(c[2], c[3] or 1.5, c[4])
    elseif c[1] == "vol" then mx:volume(c[2], c[3] or 0.5)
    elseif c[1] == "sfx" and songs.SFX[c[2]] and #effects < 8 then
      effects[#effects + 1] = {synth.player(songs.SFX[c[2]], c[2]), c[3] or 1}
    end
    c = cmd:pop()
  end
  local queued = 0
  while src:getFreeBufferCount() > 0 and queued < 6 do
    mx:render(buf, N)
    if #effects > 0 then
      for i = 0, N - 1 do fxbuf[i] = 0 end
      local keep = {}
      for _, e in ipairs(effects) do
        local alive = true
        for o = 0, N - 1, synth.BLOCK do
          if not e[1]:block(fxbuf, o) then alive = false break end
        end
        if alive then keep[#keep + 1] = e end
      end
      effects = keep
      for i = 0, N - 1 do buf[i] = buf[i] + fxbuf[i] * 0.8 end
    end
    for i = 0, N - 1 do
      local v = buf[i]
      if v > 1 then v = 1 elseif v < -1 then v = -1 end
      out[i] = v * 32767
    end
    src:queue(sd)
    queued = queued + 1
  end
  if not src:isPlaying() then src:play() end
  love.timer.sleep(0.01)
end
