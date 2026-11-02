-- utgame.lua's helper thread: ESPN's season schedule for Texas (~430 KB of JSON) decoded off the frame, sent back
-- as one line a game (tab-separated), so the main thread only splits strings. Started with the file's path;
-- answers once on "ut_sched" and ends.
--   line 1:  "team" <rank or ""> <record or "">
--   a game:  "game" <date ISO> <time valid 1|0> <state> <season type> <opp abbr> <opp name> <opp location>
--            <home 1|0> <neutral 1|0> <our score> <their score> <we won 1|0> <venue> <note> <their rank>
require("love.filesystem")
local json = require("json")
local path = ...
local out = love.thread.getChannel("ut_sched")

local f = io.open(path, "rb")
local s = f and f:read("*a")
if f then f:close() end
local ok, d = pcall(json.decode, s or "")
s = nil
if not ok or type(d) ~= "table" or type(d.events) ~= "table" then
  out:push("")
  return
end

local function clean(v) return (tostring(v or ""):gsub("[\t\n]", " ")) end
local function score(c)
  local sc = c and c.score
  if type(sc) == "table" then return sc.displayValue or (sc.value and tostring(math.floor(sc.value))) or "" end
  return sc and tostring(sc) or ""
end
local function rank(c)
  local r = c and c.curatedRank and c.curatedRank.current
  return (r and r > 0 and r < 99) and tostring(r) or ""
end

local lines = {}
local team = d.team or {}
local us_rank = ""
lines[1] = ""
for _, e in ipairs(d.events) do
  local comp = e.competitions and e.competitions[1]
  local us, them
  for _, c in ipairs(comp and comp.competitors or {}) do
    if c.team and c.team.id == "251" then us = c else them = c end
  end
  if us and them then
    local st = comp.status and comp.status.type or {}
    local note = comp.notes and comp.notes[1] and comp.notes[1].headline or ""
    if rank(us) ~= "" then us_rank = rank(us) end
    lines[#lines + 1] = table.concat({"game", clean(e.date), e.timeValid == false and "0" or "1", clean(st.state),
      clean(e.seasonType and e.seasonType.type or 2), clean(them.team.abbreviation), clean(them.team.shortDisplayName),
      clean(them.team.location), us.homeAway == "home" and "1" or "0", comp.neutralSite and "1" or "0", score(us),
      score(them), us.winner and "1" or "0", clean(comp.venue and comp.venue.fullName), clean(note), rank(them)}, "\t")
  end
end
lines[1] = table.concat({"team", us_rank, clean(team.recordSummary or "")}, "\t")
d = nil
out:push(table.concat(lines, "\n"))
