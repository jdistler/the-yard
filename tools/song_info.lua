-- Each song's shape, as JSON lines for tools/show_review.py (plain LuaJIT, no LÖVE); first, the sound effects' names:
--   {"name", "bpm", "secs" (one time through), "parts" (the order), "lanes", "drums"}
--   games/out/love-x86/luajit tools/song_info.lua
local home = arg[0]:gsub("[^/]+$", "") .. "../games/love/home/"
package.path = home .. "?.lua;" .. package.path
local synth = require("synth")
local songs = require("songs")
local function q(s) return '"' .. tostring(s):gsub('"', '\\"') .. '"' end
local names = {}
for k in pairs(songs) do if k ~= "SFX" then names[#names + 1] = k end end
table.sort(names)
local fx = {}
for k in pairs(songs.SFX) do fx[#fx + 1] = q(k) end
table.sort(fx)
print('{"sfx": [' .. table.concat(fx, ", ") .. ']}')
for _, name in ipairs(names) do
  local song = songs[name]
  local ok = pcall(synth.compile, song, name)
  local lanes, seen, drums = {}, {}, false
  for _, part in pairs(song.parts or {}) do
    for lane in pairs(part) do
      if not seen[lane] then seen[lane] = true lanes[#lanes + 1] = q(lane) end
      if lane:match("^drums") then drums = true end
    end
  end
  table.sort(lanes)
  local order = {}
  for _, p in ipairs(song.order or {}) do order[#order + 1] = q(p) end
  print(string.format('{"name": %s, "bpm": %s, "secs": %.2f, "parts": [%s], "lanes": [%s], "drums": %s, "next": %s}',
    q(name), tostring(song.bpm or 0), ok and song.length and song.length / synth.RATE or 0, table.concat(order, ", "),
    table.concat(lanes, ", "), tostring(drums), song.after and q(song.after) or "null"))
end
