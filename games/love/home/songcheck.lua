-- Checks Home's music on the PC (plain LuaJIT, no LÖVE): every song compiles, every lane fits its part, and
-- each song's length, loudness (RMS), peak and render speed. Optionally writes WAVs to listen to.
--   games/out/love-x86/luajit games/love/home/songcheck.lua [WAVDIR]
package.path = arg[0]:gsub("[^/]+$", "") .. "?.lua;" .. package.path
local ffi = require("ffi")
local synth = require("synth")
local songs = require("songs")
local wavdir = arg[1]

local function wav(path, buf, n)
  local f = assert(io.open(path, "wb"))
  local function u32(v) f:write(string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)) end
  local function u16(v) f:write(string.char(v % 256, math.floor(v / 256) % 256)) end
  f:write("RIFF") u32(36 + n * 2) f:write("WAVEfmt ") u32(16) u16(1) u16(1) u32(synth.RATE) u32(synth.RATE * 2) u16(2) u16(16)
  f:write("data") u32(n * 2)
  local out = {}
  for i = 0, n - 1 do
    local v = math.floor(math.max(-1, math.min(1, buf[i])) * 32767)
    if v < 0 then v = v + 65536 end
    out[#out + 1] = string.char(v % 256, math.floor(v / 256))
    if #out == 4096 then f:write(table.concat(out)) out = {} end
  end
  f:write(table.concat(out))
  f:close()
end

local names = {}
for k, v in pairs(songs) do if k ~= "SFX" then names[#names + 1] = k end end
table.sort(names)
local bad = 0
local function check(name, song, cap)
  -- lanes that do not fit their part (a lane shorter than the part must divide it)
  for pname, part in pairs(song.parts) do
    local lens, maxl = {}, 0
    for lane, text in pairs(part) do
      local n = 0
      for tok in text:gsub("|", " "):gmatch("%S+") do
        n = n + (tonumber(tok:match("%*(%d+)$")) or 1)
      end
      lens[lane] = n
      if n > maxl then maxl = n end
    end
    for lane, n in pairs(lens) do
      if maxl % n ~= 0 then
        print(string.format("  !! %s.%s.%s: %d steps, part %d", name, pname, lane, n, maxl))
        bad = bad + 1
      end
    end
  end
  local ok, err = pcall(synth.compile, song, name)
  if not ok then print("  !! " .. name .. ": " .. err) bad = bad + 1 return end
  local secs = math.min(song.length / synth.RATE, cap)
  local mx = synth.mixer({x = song})
  mx:play("x", 0)
  local n = math.floor(secs * synth.RATE / synth.BLOCK) * synth.BLOCK
  local buf = ffi.new("float[?]", n)
  local t0 = os.clock()
  mx:render(buf, n)
  local cpu = os.clock() - t0
  local sum, peak = 0, 0
  for i = 0, n - 1 do
    local v = buf[i]
    sum = sum + v * v
    if math.abs(v) > peak then peak = math.abs(v) end
  end
  local rms = math.sqrt(sum / n)
  print(string.format("%-10s %6.1f s (loop %6.1f)  rms %.3f  peak %.2f  render %4.1f%% realtime", name, secs,
                      song.length / synth.RATE, rms, peak, 100 * cpu / secs))
  if wavdir then wav(wavdir .. "/" .. name .. ".wav", buf, n) end
end
for _, name in ipairs(names) do check(name, songs[name], 240) end
print("-- sound effects")
local fxn = {}
for k in pairs(songs.SFX) do fxn[#fxn + 1] = k end
table.sort(fxn)
for _, name in ipairs(fxn) do check(name, songs.SFX[name], 6) end
print(bad == 0 and "all good" or (bad .. " problem(s)"))
os.exit(bad == 0 and 0 or 1)
