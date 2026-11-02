-- The Longhorns' next game, for Home: from ESPN's public team endpoint (Texas is team 251), fetched by tvnet
-- (games/tv/tvnet.c "get": HTTPS through the cabinet's libavformat) in the background, now and then, more often
-- around kickoff, every 30 s while the game is on, into /tmp. After a power cut with no network yet, the
-- countdown comes from the season kept on /data (ut_season.txt).
--   utgame.update(dt)           in Home's update (cheap: a file read when one is due)
--   utgame.game                 nil, or {opp, opp_abbr, opp_loc, home, kickoff (epoch), state "pre"|"in"|"post",
--                               detail ("Q3 4:12", "Final"), us, them (scores), net ("ESPN"), record ("6-2")}
--   utgame.window(now)          true from 2 h before kickoff until the game has been over an hour (AUTO: the
--                               Longhorns show)
--   utgame.scored               set when our score went up since last read (the show celebrates; it clears it)
--   utgame.season               the whole season from ESPN's schedule (every 6 h; decoded by utsched.lua, a thread):
--                               {games = {game...}, rank ("14" or nil), record ("6-2")}; a game as utgame.game plus
--                               day ("2026-11-14", local), tbd (no kickoff time yet), post (a bowl or playoff game),
--                               note ("Cheez-It Citrus Bowl"), venue, neutral, won, opp_rank
--   utgame.status(now)          for AUTO (shows.pick): {window, gameday, won (the day after a win), week ("redriver",
--                               "lonestar", "bowl": the six days before), season (true/false; nil: no data)}
--   utgame.games(), utgame.last(now), utgame.next(now)   the season with the next game merged in; the last result
-- HOME_UT_JSON=path (tests): read this file instead of fetching; HOME_UT_SCHED=path likewise for the schedule;
-- HOME_UT_NOW=epoch: pretend it is then.
local json = require("json")
local U = {}
local URL = "https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/251"
-- (in RAM: during a game it comes every 30 s, ~8 MB of writes a game on /data's flash. After a power cut the
-- next game comes from the season kept on /data, ut_season.txt, until the network is back.)
local FILE = os.getenv("HOME_UT_JSON") or "/tmp/ut.json"
local BIN = os.getenv("TV_BIN") or "/data/tv/bin"
local fixed = os.getenv("HOME_UT_JSON") ~= nil
local SCHED_URL = URL .. "/schedule"
-- (the download, ~430 KB, goes to RAM and is deleted once read: /data is ~96% full. What it says, a couple of
-- KB, is kept on /data for the next start.)
local SCHED_FILE = os.getenv("HOME_UT_SCHED") or "/tmp/ut_sched.json"
local sched_fixed = os.getenv("HOME_UT_SCHED") ~= nil or fixed
local SEASON_FILE = os.getenv("HOME_UT_SEASON") or (not sched_fixed and "/data/home/ut_season.txt") or nil
local season_text
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

-- The local calendar day of a game: from its kickoff, or (no time yet: ESPN puts those at 05:00Z, the night
-- before in Texas) from the date as written.
function U.day_of(iso, tbd, kickoff)
  if tbd or not kickoff then
    local y, mo, d = iso:match("^(%d+)-(%d+)-(%d+)")
    return y and string.format("%s-%s-%s", y, mo, d) or nil
  end
  return os.date("%Y-%m-%d", kickoff)
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
  local note = comp.notes and comp.notes[1] and comp.notes[1].headline
  local g = {
    tbd = ev.timeValid == false, post = ev.seasonType and ev.seasonType.type == 3, note = note,
    venue = comp.venue and comp.venue.fullName, neutral = comp.neutralSite,
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
  g.day = U.day_of(ev.date or comp.date or "", g.tbd, g.kickoff)
  g.won = g.state == "post" and (g.us or 0) > (g.them or 0)
  local old = U.game
  if old and old.state == "in" and g.us and old.us and g.us > old.us then U.scored = g.us - old.us end
  -- a game just ended: the schedule again soon, for the result
  if old and old.state ~= "post" and g.state == "post" then U.sched_soon = true end
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

-- ------------------------------------------------------------------ the season (ESPN's schedule)
local sched_next_fetch, sched_next_read, sched_size, sched_thread = 20, 2, nil, nil

local function sched_parse(text)
  if text == "" then return end
  season_text = text
  local season = {games = {}}
  for line in text:gmatch("[^\n]+") do
    local f = {}
    for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
    if f[1] == "team" then
      season.rank = f[2] ~= "" and f[2] or nil
      season.record = f[3] ~= "" and f[3] or nil
    elseif f[1] == "game" then
      local tbd = f[3] == "0"
      local kickoff = iso_epoch(f[2])
      local g = {kickoff = kickoff, tbd = tbd, state = f[4], post = f[5] == "3", opp_abbr = f[6], opp = f[7],
                 opp_loc = f[8], home = f[9] == "1", neutral = f[10] == "1", us = tonumber(f[11]), them = tonumber(f[12]),
                 won = f[13] == "1", venue = f[14], note = f[15] ~= "" and f[15] or nil, opp_rank = tonumber(f[16])}
      g.day = U.day_of(f[2], tbd, kickoff)
      season.games[#season.games + 1] = g
    end
  end
  table.sort(season.games, function(a, b) return (a.kickoff or 0) < (b.kickoff or 0) end)
  U.season = season
  log(string.format("utgame: season %d games, %s, rank %s", #season.games, season.record or "?", season.rank or "-"))
end

local function sched_update()
  if sched_thread then
    local text = love.thread.getChannel("ut_sched"):pop()
    if text then
      sched_thread = nil
      local old = season_text
      sched_parse(text)
      if not sched_fixed and text ~= "" then
        os.remove(SCHED_FILE)
        sched_size = nil
        -- kept for the next start, only when it changed (flash)
        if SEASON_FILE and text ~= old then
          local f = io.open(SEASON_FILE .. ".new", "wb")
          if f then
            f:write(text)
            f:close()
            os.rename(SEASON_FILE .. ".new", SEASON_FILE)
          end
        end
      end
    elseif not sched_thread:isRunning() then
      log("utgame: schedule thread: " .. tostring(sched_thread:getError()))
      sched_thread = nil
    end
    return
  end
  if clock >= sched_next_read then
    sched_next_read = clock + 60
    local f = io.open(SCHED_FILE, "rb")
    if f then
      local size = f:seek("end")
      f:close()
      if size and size > 0 and size ~= sched_size then
        sched_size = size
        sched_thread = love.thread.newThread("utsched.lua")
        sched_thread:start(SCHED_FILE)
      end
    end
  end
  if U.sched_soon then
    U.sched_soon = nil
    sched_next_fetch = math.min(sched_next_fetch, clock + 900)
  end
  if not sched_fixed and clock >= sched_next_fetch then
    sched_next_fetch = clock + 6 * 3600
    os.execute(string.format("%s/tvnet get '%s' %s >/dev/null 2>&1 &", BIN, SCHED_URL, SCHED_FILE))
  end
end

-- Every game we know: the season, with the next game (it may be a bowl, which the schedule leaves out) in its
-- place, newest data first.
function U.games()
  local out, seen = {}, {}
  local g = U.game
  if g and g.day then out[1] = g seen[g.day] = true end
  for _, s in ipairs(U.season and U.season.games or {}) do
    if s.day and not seen[s.day] then out[#out + 1] = s seen[s.day] = true end
  end
  table.sort(out, function(a, b) return (a.day or "") < (b.day or "") end)
  return out
end

local function noon(day)
  local y, m, d = day:match("^(%d+)-(%d+)-(%d+)")
  return os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})
end
-- whole days from today to that day
local function days_to(day, now)
  return math.floor((noon(day) - noon(os.date("%Y-%m-%d", now))) / 86400 + 0.5)
end

function U.last(now)
  now = now or U.now()
  local today, best = os.date("%Y-%m-%d", now), nil
  for _, g in ipairs(U.games()) do
    if g.state == "post" and g.day <= today then best = g end
  end
  return best
end

function U.next(now)
  now = now or U.now()
  local today = os.date("%Y-%m-%d", now)
  for _, g in ipairs(U.games()) do
    if g.state ~= "post" and g.day >= today then return g end
  end
end

function U.status(now)
  now = now or U.now()
  local st = {window = U.window(now)}
  local today = os.date("%Y-%m-%d", now)
  local games = U.games()
  for _, g in ipairs(games) do
    local dd = days_to(g.day, now)
    if g.day == today then st.gameday = g end
    if dd == -1 and g.state == "post" and g.won then st.won = g end
  end
  local nx = U.next(now)
  if nx then
    local dd = days_to(nx.day, now)
    if dd >= 0 and dd <= 6 then
      if nx.opp_abbr == "OU" then st.week = "redriver"
      elseif nx.opp_abbr == "TA&M" then st.week = "lonestar"
      elseif nx.post then st.week = "bowl" end
    end
  end
  -- the season (nil: the calendar decides): a game within a month is the season; the last game a week to three
  -- months ago, with none to come, is the season over
  if nx and days_to(nx.day, now) <= 30 then st.season = true
  elseif not nx then
    local last = U.last(now)
    local ago = last and -days_to(last.day, now)
    if ago and ago > 7 and ago < 90 then st.season = false end
  end
  return st
end

function U.start(logf)
  log = logf or log
  read()
  -- the season as last read (until the next download)
  local f = SEASON_FILE and io.open(SEASON_FILE, "rb")
  if f then
    local text = f:read("*a")
    f:close()
    if text and text ~= "" then sched_parse(text) end
  end
  if not U.game then
    local nx = U.next()
    if nx then U.game = nx end
  end
  next_fetch = 5                         -- a first look soon after Home starts (the network may come later)
end

function U.update(dt)
  clock = clock + dt
  sched_update()
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

-- Any game on: the next game's live state, else by the clock for every game with a kickoff time.
function U.window(now)
  now = now or U.now()
  local g = U.game
  if g and g.state == "in" then return true end
  for _, x in ipairs(U.games()) do
    if x.kickoff and not x.tbd and x.state ~= "post" and now > x.kickoff - 2 * 3600 and now < x.kickoff + 4.5 * 3600 then
      return true
    end
    -- (over early: an hour after the final, from the next game's own state)
    if x == g and x.state == "post" and now > x.kickoff - 2 * 3600 and now < x.kickoff + 4.5 * 3600 then
      return now < x.kickoff + 3.5 * 3600
    end
  end
  return false
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
