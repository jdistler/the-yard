-- Favorites: how often and how long each thing on the cabinet is played, for Home's FAVORITES section (the
-- last played, then the most played). Everything counts: the classics, the arcade boards, the Yard's games,
-- console games from the Shelf. homeloop adds "ran <seconds>" to Home's state file when a game ends; Home
-- credits it to what it launched ("playedkey" for a card, "playedgame" for a Shelf game) and drops the line.
-- Kept on the card (partycade/stats.tsv; /data/home when there is no card): key, plays, seconds, last.
local F = {}

local function path()
  local f = io.open("/mnt/sdcard/partycade/.", "r")
  if f then f:close() return "/mnt/sdcard/partycade/stats.tsv" end
  return (os.getenv("HOME_STATS") or "/data/home/stats.tsv")
end
local PATH = os.getenv("HOME_STATS") or path()

local function read_file(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

function F.load()
  local stats = {}
  for line in (read_file(PATH) or ""):gmatch("[^\n]+") do
    local k, n, s, last = line:match("^([^\t]+)\t(%d+)\t(%d+)\t(%d+)")
    if k then stats[k] = {plays = tonumber(n), secs = tonumber(s), last = tonumber(last)} end
  end
  return stats
end

local function save(stats)
  local lines = {}
  for k, v in pairs(stats) do lines[#lines + 1] = table.concat({k, v.plays, v.secs, v.last}, "\t") end
  table.sort(lines)
  local f = io.open(PATH .. ".new", "w")
  if not f then return end
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()
  os.rename(PATH .. ".new", PATH)
end

-- The game that just ended, from Home's state file: credited once (the "ran" line is removed after).
function F.credit(state_path)
  local stats = F.load()
  local s = state_path and read_file(state_path)
  if not s then return stats end
  local ran = tonumber(s:match("\nran (%d+)") or s:match("^ran (%d+)"))
  local key = s:match("playedgame ([^\n]+)") or s:match("playedkey (%S+)")
  if key then key = key:gsub("^fav:", "") end
  if ran and key then
    local e = stats[key] or {plays = 0, secs = 0, last = 0}
    e.plays = e.plays + 1
    e.secs = e.secs + ran
    -- (the cabinet's clock is right once the network has set it; before that, a counter keeps the order)
    local seq = 0
    for _, v in pairs(stats) do if v.last > seq then seq = v.last end end
    e.last = math.max(os.time(), seq + 1)
    stats[key] = e
    save(stats)
    local out = s:gsub("ran %d+\n?", "")
    local f = io.open(state_path, "w")
    if f then f:write(out) f:close() end
  end
  return stats
end

-- Keys by how much they're played: time first (a long Pokemon session counts more than a quick try), then plays.
function F.ranked(stats)
  local keys = {}
  for k, v in pairs(stats) do if v.plays > 0 then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b)
    local x, y = stats[a], stats[b]
    if x.secs ~= y.secs then return x.secs > y.secs end
    return x.plays > y.plays
  end)
  return keys
end

function F.last(stats)
  local best, at = nil, -1
  for k, v in pairs(stats) do if v.last > at then best, at = k, v.last end end
  return best
end

-- "PLAYED 12 TIMES  ·  3 HRS"
function F.line(v)
  if not v then return "" end
  local t = v.secs >= 3600 and string.format("%.1f HRS", v.secs / 3600) or (math.max(1, math.floor(v.secs / 60)) .. " MIN")
  return "PLAYED " .. v.plays .. (v.plays == 1 and " TIME" or " TIMES") .. "  ·  " .. t
end

return F
