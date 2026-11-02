-- The Longhorns' next game, for Home: from ESPN's public team endpoint (Texas is team 251), fetched by tvnet
-- (games/tv/tvnet.c "get": HTTPS through the cabinet's libavformat) in the background, now and then, more often
-- around kickoff, every 30 s while the game is on. The last copy is kept (/data/home/ut.json), so the countdown
-- is there after a power cut with no network yet.
--   utgame.update(dt)           in Home's update (cheap: a file read when one is due)
--   utgame.game                 nil, or {opp, opp_abbr, opp_loc, home, kickoff (epoch), state "pre"|"in"|"post",
--                               detail ("Q3 4:12", "Final"), us, them (scores), net ("ESPN"), record ("6-2")}
--   utgame.window(now)          true from 2 h before kickoff until the game has been over an hour (AUTO: the
--                               Longhorns show)
--   utgame.scored               set when our score went up since last read (the show celebrates; it clears it)
-- HOME_UT_JSON=path (tests): read this file instead of fetching; HOME_UT_NOW=epoch: pretend it is then.
local json = require("json")
local U = {}
local URL = "https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/251"
local FILE = os.getenv("HOME_UT_JSON") or "/data/home/ut.json"
local BIN = os.getenv("TV_BIN") or "/data/tv/bin"
local fixed = os.getenv("HOME_UT_JSON") ~= nil
local log = function() end

local next_fetch, next_read, fetching = 0, 0, false
local last_size

function U.now()
  return tonumber(os.getenv("HOME_UT_NOW") or "") or os.time()
end

-- "2026-11-07T17:00Z" -> epoch (UTC)
local function iso_epoch(s)
  local y, mo, d, h, mi = s:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if not y then return nil end
  -- os.time reads the table as local time: correct by the zone's offset now
  local t = os.time({year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = 0})
  local utc = os.time(os.date("!*t", t))
  return t + (t - utc)
end

local function score(c)
  local s = c and c.score
  if type(s) == "table" then s = s.displayValue or s.value end
  return tonumber(s)
end

-- (tests: HOME_UT_JSON2 replaces the file after HOME_UT_SWAP seconds: a score changing during a game)
local swap_file, swap_at = os.getenv("HOME_UT_JSON2"), tonumber(os.getenv("HOME_UT_SWAP") or "")
local clock = 0
local function read()
  if swap_file and swap_at and clock >= swap_at then FILE, swap_file = swap_file, nil last_size = nil end
  local f = io.open(FILE, "rb")
  if not f then return end
  local s = f:read("*a")
  f:close()
  if #s == last_size and U.game then return end
  last_size = #s
  local d = json.decode(s)
  local team = d and d.team
  local ev = team and team.nextEvent and team.nextEvent[1]
  if not ev then return end
  local comp = ev.competitions and ev.competitions[1]
  if not comp then return end
  local us, them
  for _, c in ipairs(comp.competitors or {}) do
    if c.team and c.team.id == "251" then us = c else them = c end
  end
  if not us or not them then return end
  local st = comp.status and comp.status.type or {}
  local g = {
    opp = them.team.shortDisplayName or them.team.displayName or "OPPONENT",
    opp_abbr = them.team.abbreviation or "OPP",
    opp_loc = them.team.location or them.team.shortDisplayName or "",
    opp_color = them.team.color,
    home = us.homeAway == "home",
    kickoff = iso_epoch(ev.date or comp.date or ""),
    state = st.state or "pre",
    detail = st.shortDetail or st.detail or "",
    us = score(us), them = score(them),
    net = comp.broadcasts and comp.broadcasts[1] and comp.broadcasts[1].media and comp.broadcasts[1].media.shortName,
    record = team.record and team.record.items and team.record.items[1] and team.record.items[1].summary,
  }
  local old = U.game
  if old and old.state == "in" and g.us and old.us and g.us > old.us then U.scored = g.us - old.us end
  U.game = g
  log(string.format("utgame: %s %s, %s, %s %s-%s", g.home and "vs" or "at", g.opp_abbr, g.state, g.detail,
                    tostring(g.us), tostring(g.them)))
end

-- How long until the next fetch: often near and during a game, else every three hours.
local function interval()
  local g = U.game
  if not g or not g.kickoff then return 3 * 3600 end
  if g.state == "in" then return 30 end
  local now = U.now()
  if g.state == "pre" and g.kickoff - now < 1800 then return 60 end
  if g.state == "post" and now - g.kickoff < 6 * 3600 then return 1800 end
  return 3 * 3600
end

function U.start(logf)
  log = logf or log
  read()
  next_fetch = 5                         -- a first look soon after Home starts (the network may come later)
end

function U.update(dt)
  clock = clock + dt
  if clock >= next_read then
    next_read = clock + 5
    read()
  end
  if not fixed and clock >= next_fetch then
    next_fetch = clock + interval()
    -- in the background (the shell returns at once); tvnet writes the file whole, then renames it
    os.execute(string.format("%s/tvnet get '%s' %s >/dev/null 2>&1 &", BIN, URL, FILE))
  end
end

function U.window(now)
  local g = U.game
  if not g or not g.kickoff then return false end
  now = now or U.now()
  if g.state == "in" then return true end
  return now > g.kickoff - 2 * 3600 and now < g.kickoff + 4.5 * 3600
end

-- "KICKOFF IN 2:14:05" style countdown, or nil
function U.countdown(now)
  local g = U.game
  if not g or not g.kickoff or g.state ~= "pre" then return nil end
  local s = g.kickoff - (now or U.now())
  if s <= 0 then return "KICKOFF ANY MINUTE" end
  if s > 86400 * 2 then return nil end
  return string.format("KICKOFF IN %d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

return U
