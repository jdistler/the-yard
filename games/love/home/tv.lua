-- Partycade TV: the live TV guide inside Home (games/tv/PLAN.md). Home's TV tab opens it in place; choosing a
-- channel hands the screen to tvplay through homeloop ("tv" request, games/tv/tvloop.sh) and Home comes back
-- on the same channel when the viewer leaves the picture.
--
-- Data (written by tvnet, games/tv/tvnet.c, run from tvworker.lua so the guide never waits on the network):
--   TV_DIR/account.conf            the playlists, in order: name, server, user, password (never read here)
--   TV_DIR/<NAME>/groups.tsv       category_id, name                 (kept on NAND: the guide works offline)
--   TV_DIR/<NAME>/channels.tsv     category_id, stream_id, name, epg_channel_id, logo_url
--   TV_TMP/<NAME>/epg.tsv          epg_channel_id, start, stop, title, description (RAM, refetched per boot)
--   TV_TMP/logos/<key>.rgba        logos, decoded and shrunk by tvnet ("RGBA", w, h, pixels)
--   TV_DIR/recent.tsv              the last channels watched: playlist, stream_id
-- The playlists appear one after another, each group a row (the way TiviMate lists them), after RECENT.
local T = {}
local lg = love.graphics

local DIR = os.getenv("TV_DIR") or "/data/tv"
local TMP = os.getenv("TV_TMP") or "/tmp/tv"
local BIN = os.getenv("TV_BIN") or (DIR .. "/bin")
-- Logos are kept on the microSD card when one is in (they survive power-off), else in RAM.
local function logo_dir()
  local card = os.getenv("TV_CARD") or "/mnt/sdcard"
  local d = card .. "/partycade/tv-logos"
  os.execute("mkdir -p " .. d .. " 2>/dev/null")
  local f = io.open(d .. "/.probe", "w")
  if f then f:close() os.remove(d .. "/.probe") return d end
  return TMP .. "/logos"
end
local LOGOS
local SYNC_EVERY = 3 * 3600                 -- the guide's lists and programme times, refetched after this
local IDLE_OUT = 300                        -- seconds untouched in the guide before Home takes over again

local ctx                                   -- Home's drawing kit and controls (T.load)
local W, H
local playlists = {}                        -- {name, tint, groups = {{id, name, channels}}, status, err}
local rows = {}                             -- {key, title, tint, header, channels}
local epg = {}                              -- [playlist name][epg id] = {{t0, t1, title, desc}, ...}
local logos = {}                            -- [key] = Image | false (none) | "want" | "asked"
local logo_count = 0
local dead = {}                             -- ["NAME/stream_id"] = true: off the air this session
local recent = {}                           -- {{pl, sid}}
local sel, cols = 1, {}                     -- the chosen row; the chosen column of each row (by key)
local yscroll, xscroll = 0, {}
local t, idle = 0, 0
local note, note_t
local worker, logo_busy, logo_wait = nil, false, 0
local syncing = {}
local hold = {}                             -- held stick directions: seconds held, time to the next repeat
local TINTS = {0x6ef0c8, 0xff9c5a, 0x8ab4ff, 0xff6bd6}
local RECENT_TINT = 0xffd23f

-- ------------------------------------------------------------------ small helpers

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, s)
  local f = io.open(path .. ".new", "wb")
  if not f then return false end
  f:write(s)
  f:close()
  return os.rename(path .. ".new", path)
end

local function split_tab(line)
  local out, i = {}, 1
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do out[i] = field i = i + 1 end
  return out
end

-- Superscript tags the panels put in names (ESPN ᴴᴰ, ᴸᶦᵛᵉ) as plain letters; the round font has only Latin.
local SUPER = {["ᴴᴰ"] = "HD", ["ᵁᴴᴰ"] = "UHD", ["ᶠᴴᴰ"] = "FHD", ["ᴿᴬᵂ"] = "RAW", ["ᴸᶦᵛᵉ"] = "LIVE", ["ˢᴰ"] = "SD",
               ["⁴ᴷ"] = "4K", ["ᴴᴰᴿ"] = "HDR", ["ᵂᴱᴮ"] = "WEB", ["ᴺᵉʷ"] = "NEW", ["ᴿᵉᵖˡᵃʸ"] = "REPLAY"}
local function clean(s)
  s = s or ""
  for k, v in pairs(SUPER) do s = s:gsub(k, " " .. v) end
  s = s:gsub("|%a%a|", "")                               -- |US| country tags
  s = s:gsub("^%s*%a%a%s*[:|]%s+", "")                   -- "US | ", "UK: "
  -- Keep ASCII and Latin-1 letters (2-byte sequences from \xC3); drop every other symbol (stars, ✪).
  s = s:gsub("[\xE0-\xF4][\x80-\xBF]+", " "):gsub("[\xC4-\xDF][\x80-\xBF]", " ")
  s = s:gsub(" | ", " · "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return s
end

-- A group's name for its row: "US Sports | Football" -> "Football", "Live | PPV Events" -> "PPV Events".
local function group_title(s)
  local c = clean(s)
  local last = c:match(".*·%s*(.+)$")
  if last and #last > 2 then c = last end
  return c
end

local function hour_min(ts)
  local d = os.date("*t", ts)
  local h = d.hour % 12
  if h == 0 then h = 12 end
  return string.format("%d:%02d", h, d.min), d.hour < 12 and "AM" or "PM"
end
local function clock(ts)
  local hm, ap = hour_min(ts)
  return hm .. " " .. ap
end

-- Text cut to a number of lines in a width, with "..." when cut. Remembered: wrapping every tile's text every
-- frame cost the guide ~20 fps on the cabinet.
local fit_cache, fit_n = {}, 0
local function fit(font, s, w, lines)
  local key = tostring(font) .. "|" .. w .. "|" .. lines .. "|" .. s
  local hit = fit_cache[key]
  if hit then return hit end
  if fit_n > 4000 then fit_cache, fit_n = {}, 0 end
  local r = (function()
  local _, wrapped = font:getWrap(s, w)
  if #wrapped <= lines then return s end
  local out = {}
  for i = 1, lines do out[i] = wrapped[i] end
  local last = out[lines]
  while #last > 0 and font:getWidth(last .. "...") > w do last = last:sub(1, -2) end
  out[lines] = last:gsub("%s+$", "") .. "..."
  return table.concat(out, "\n")
  end)()
  fit_cache[key] = r
  fit_n = fit_n + 1
  return r
end

local function clock_ok() return os.time() > 1700000000 end   -- the cabinet starts at 1970 until tvnet sets it

-- A logo's file name: a hash of its URL (many channels share one logo).
local bit = require("bit")
local function url_key(url)
  local h1, h2 = 5381, 2166136261
  for i = 1, #url do
    local c = url:byte(i)
    h1 = bit.band(bit.bxor(h1 * 33, c), 0x7fffffff)
    h2 = bit.band(bit.bxor(h2, c) * 16777619, 0x7fffffff)
  end
  return bit.tohex(h1) .. bit.tohex(h2)
end

-- ------------------------------------------------------------------ data

local function load_epg(pl)
  local s = read_file(TMP .. "/" .. pl.name .. "/epg.tsv")
  local map = {}
  if s then
    for line in s:gmatch("[^\n]+") do
      local id, t0, t1, title, desc = line:match("^([^\t]*)\t(%d+)\t(%d+)\t([^\t]*)\t?(.*)$")
      if id then
        local l = map[id]
        if not l then l = {} map[id] = l end
        l[#l + 1] = {tonumber(t0), tonumber(t1), clean(title), desc}
      end
    end
    for _, l in pairs(map) do table.sort(l, function(a, b) return a[1] < b[1] end) end
  end
  epg[pl.name] = map
end

local function load_lists(pl)
  local groups, by_id = {}, {}
  local gs = read_file(DIR .. "/" .. pl.name .. "/groups.tsv")
  if gs then
    for line in gs:gmatch("[^\n]+") do
      local f = split_tab(line)
      if f[1] and f[1] ~= "" then
        local g = {id = f[1], name = group_title(f[2]), channels = {}}
        groups[#groups + 1] = g
        by_id[g.id] = g
      end
    end
  end
  local cs = read_file(DIR .. "/" .. pl.name .. "/channels.tsv")
  if cs then
    for line in cs:gmatch("[^\n]+") do
      local f = split_tab(line)
      local g = by_id[f[1]]
      if g and f[2] and f[2] ~= "" then
        g.channels[#g.channels + 1] = {pl = pl.name, sid = f[2], name = clean(f[3]), epg = f[4] ~= "" and f[4] or nil,
                                       logo = (f[5] or ""):match("^https?://%S+$")}
      end
    end
  end
  local kept = {}
  for _, g in ipairs(groups) do if #g.channels > 0 then kept[#kept + 1] = g end end
  pl.groups = kept
end

local function find_channel(pl, sid)
  for _, p in ipairs(playlists) do
    if p.name == pl then
      for _, g in ipairs(p.groups or {}) do
        for _, ch in ipairs(g.channels) do if ch.sid == sid then return ch end end
      end
    end
  end
end

local function load_recent()
  recent = {}
  local s = read_file(DIR .. "/recent.tsv")
  if not s then return end
  for line in s:gmatch("[^\n]+") do
    local pl, sid = line:match("^(%w+)\t(%d+)$")
    if pl then recent[#recent + 1] = {pl, sid} end
  end
end

local function save_recent(ch)
  local out = {ch.pl .. "\t" .. ch.sid}
  for _, r in ipairs(recent) do
    if not (r[1] == ch.pl and r[2] == ch.sid) and #out < 12 then out[#out + 1] = r[1] .. "\t" .. r[2] end
  end
  write_file(DIR .. "/recent.tsv", table.concat(out, "\n") .. "\n")
  load_recent()
end

-- The rows, in order: RECENT, then each playlist's groups. The chosen row and columns are kept by key.
local function build_rows()
  local key = rows[sel] and rows[sel].key
  rows = {}
  local rc = {}
  for _, r in ipairs(recent) do
    local ch = find_channel(r[1], r[2])
    if ch then rc[#rc + 1] = ch end
  end
  if #rc > 0 then rows[#rows + 1] = {key = "recent", title = "RECENT", tint = RECENT_TINT, channels = rc} end
  for i, pl in ipairs(playlists) do
    for k, g in ipairs(pl.groups or {}) do
      rows[#rows + 1] = {key = pl.name .. "/" .. g.id, title = g.name, tint = pl.tint, channels = g.channels,
                         header = k == 1 and pl.name or nil, pl = pl}
    end
    if (pl.groups == nil or #pl.groups == 0) then
      rows[#rows + 1] = {key = pl.name .. "/none", title = pl.name, tint = pl.tint, channels = {}, header = pl.name,
                         pl = pl, empty = true}
    end
  end
  sel = 1
  for i, r in ipairs(rows) do if r.key == key then sel = i end end
end

local now_next_raw
local function now_next(ch)
  -- Looked up again every 10 s per channel, not every frame (the rows drew 13 ms of CPU a frame).
  local tn = love.timer.getTime()
  if ch._np_t and tn - ch._np_t < 10 then return ch._np, ch._nx end
  ch._np, ch._nx = now_next_raw(ch)
  ch._np_t = tn
  return ch._np, ch._nx
end
now_next_raw = function(ch)
  local l = ch.epg and epg[ch.pl] and epg[ch.pl][ch.epg]
  if not l or not clock_ok() then return nil end
  -- Now: of the shows running, the one that started last (panels' guides overlap: a 3:30-6:00 game and a
  -- 4:00-6:00 one). Next: the first to start once it ends (or the first to come, when nothing is on).
  local now = os.time()
  local cur, nxt
  for _, p in ipairs(l) do
    if p[1] <= now and now < p[2] and (not cur or p[1] > cur[1]) then cur = p end
  end
  local from = cur and cur[2] or now
  for _, p in ipairs(l) do
    if p[1] >= from and (not nxt or p[1] < nxt[1]) then nxt = p end
  end
  return cur, nxt
end

local function synced_at(name)
  return tonumber(read_file(TMP .. "/" .. name .. "/synced") or "") or 0
end
local RETRY_AFTER = 600                     -- a playlist that failed is tried again after this
local function failed_at(name)
  return tonumber(read_file(TMP .. "/" .. name .. "/failed") or "") or -1e9
end

local function sync(name)
  if syncing[name] or not worker then return end
  syncing[name] = true
  for _, pl in ipairs(playlists) do if pl.name == name then pl.status = "syncing" end end
  love.thread.getChannel("tv_work"):push({"sync", name, BIN, DIR, TMP})
end

local function sync_stale()

  for _, pl in ipairs(playlists) do
    local up = tonumber((read_file("/proc/uptime") or ""):match("^(%S+)") or "") or 0
    local stale = not clock_ok() or os.time() - synced_at(pl.name) > SYNC_EVERY or not next(epg[pl.name] or {})
    -- After a failure, wait before asking again (measured on uptime: the clock may not be set yet).
    -- (A failure in the first minutes after power-on is usually Wi-Fi still connecting: tried again sooner.)
    local f = failed_at(pl.name)
    if stale and up - f > (f < 180 and 30 or RETRY_AFTER) then sync(pl.name) end
  end
end

-- ------------------------------------------------------------------ logos

local function load_logo(key)
  local s = read_file(LOGOS .. "/" .. key .. ".rgba")
  if not s or #s < 8 or s:sub(1, 4) ~= "RGBA" then logos[key] = false return end
  local w = s:byte(5) + s:byte(6) * 256
  local h = s:byte(7) + s:byte(8) * 256
  if #s < 8 + w * h * 4 then logos[key] = false return end
  local ok, data = pcall(love.image.newImageData, w, h, "rgba8", s:sub(9, 8 + w * h * 4))
  if not ok then logos[key] = false return end
  local img = lg.newImage(data)
  img:setFilter("linear", "linear")
  data:release()
  logos[key] = img
  logo_count = logo_count + 1
end

-- The logo for a channel: drawn if decoded, asked for once otherwise (fetched in the order rows are seen).
local function logo_of(ch)
  if not ch.logo then return nil end
  ch.key = ch.key or url_key(ch.logo)
  local v = logos[ch.key]
  if v == nil then
    if love.filesystem and read_file(LOGOS .. "/" .. ch.key .. ".rgba") then load_logo(ch.key) v = logos[ch.key]
    else logos[ch.key] = "want" end
  end
  return type(v) == "userdata" and v or nil
end

local function ask_logos()
  if logo_busy or not worker then return end
  -- The chosen row first, then the rows around it; a dozen at a time.
  local list, seen = {}, {}
  local order = {sel, sel + 1, sel - 1, sel + 2, sel + 3}
  for _, ri in ipairs(order) do
    local r = rows[ri]
    if r then
      local c = cols[r.key] or 1
      for ci = math.max(1, c - 2), math.min(#r.channels, c + 6) do
        local ch = r.channels[ci]
        if ch.logo then
          ch.key = ch.key or url_key(ch.logo)
          if logos[ch.key] == "want" and not seen[ch.key] and #list < 12 then
            seen[ch.key] = true
            list[#list + 1] = ch.key .. " " .. ch.logo
            logos[ch.key] = "asked"
          end
        end
      end
    end
  end
  if #list == 0 then return end
  os.execute("mkdir -p " .. TMP)
  if write_file(TMP .. "/logos-want.txt", table.concat(list, "\n") .. "\n") then
    logo_busy = true
    love.thread.getChannel("tv_work"):push({"logos", TMP .. "/logos-want.txt", BIN, LOGOS})
  end
end

-- ------------------------------------------------------------------ the scene

function T.load(c)
  ctx = c
  LOGOS = logo_dir()
  W, H = c.W, c.H
  playlists = {}
  local conf = read_file(DIR .. "/account.conf") or ""
  for line in conf:gmatch("[^\n]+") do
    local name = line:match("^(%w+)\t")
    if name and #playlists < 4 then
      playlists[#playlists + 1] = {name = name, tint = TINTS[#playlists + 1], status = "ok"}
    end
  end
  for _, pl in ipairs(playlists) do
    load_lists(pl)
    load_epg(pl)
  end
  load_recent()
  build_rows()
  if love.thread and #playlists > 0 then
    worker = love.thread.newThread("tvworker.lua")
    worker:start()
    sync_stale()
  end
end

function T.channel_count()
  local n, g = 0, 0
  for _, pl in ipairs(playlists) do
    for _, gr in ipairs(pl.groups or {}) do n = n + #gr.channels g = g + 1 end
  end
  return n, g, #playlists
end

function T.has_playlists() return #playlists > 0 end

-- Coming back from tvplay: the row and channel it was started from (TV_TMP/play.tsv, TV_TMP/return).
function T.returning()
  local r = read_file(TMP .. "/return")
  if not r then return nil end
  os.remove(TMP .. "/return")
  local rc, idx = r:match("^(%d+)%s+(%d+)")
  return tonumber(rc), tonumber(idx)
end

function T.enter(rc, idx)
  idle, note = 0, nil
  local pos = read_file(TMP .. "/guide.pos")
  if pos and idx then
    local key = pos:match("^(%S+)")
    for i, r in ipairs(rows) do
      if r.key == key then sel = i cols[key] = math.max(1, math.min(#r.channels, idx)) end
    end
  end
  if rc == 30 or rc == 31 or rc == 32 then
    local r = rows[sel]
    local ch = r and r.channels[cols[r.key] or 1]
    if ch and rc == 30 then dead[ch.pl .. "/" .. ch.sid] = true end
    note = rc == 30 and "That channel isn't on the air right now." or rc == 31 and "The channel stopped. Try it again?"
           or "That channel's picture can't play on the cabinet."
    note_t = 5
  end
  yscroll = sel
  sync_stale()
end

local function move_row(d)
  local n = sel + d
  if n < 1 or n > #rows then return end
  sel = n
  ctx.play("move")
end

local function move_col(d)
  local r = rows[sel]
  if not r or #r.channels == 0 then return end
  local c = (cols[r.key] or 1) + d
  if c < 1 or c > #r.channels then return end
  cols[r.key] = c
  ctx.play("move")
end

local function jump_playlist(d)
  local cur = rows[sel] and rows[sel].pl
  local i = sel
  while true do
    i = i + d
    if i < 1 or i > #rows then return end
    if rows[i].header and rows[i].pl ~= cur then sel = i ctx.play("section") return end
  end
end

-- The picture on the screen while tvplay connects (and how to get around in it).
local function picture_tune(ch, r)
  ctx.backdrop()
  local rr, gg, bb = ctx.rgb(r.tint)
  ctx.fx.glow(W / 2, 400, 360, 200, rr, gg, bb, 0.3)
  local img = logo_of(ch)
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(360 / iw, 200 / ih)
    lg.setColor(1, 1, 1, 1)
    lg.draw(img, W / 2, 400, 0, s, s, iw / 2, ih / 2)
  end
  lg.setFont(ctx.font(40))
  lg.setColor(1, 1, 1, 1)
  lg.printf(fit(ctx.font(40), ch.name, W - 80, 2), 40, 540, W - 80, "center")
  ctx.neon_draw("TUNING IN...", 0, 620, 44, r.tint, 1, "center", W)
  lg.setColor(0.04, 0.0, 0.10, 0.85)
  ctx.rrect("fill", 60, 730, W - 120, 250, 24)
  lg.setColor(rr, gg, bb, 0.9)
  lg.setLineWidth(2)
  ctx.rrect("line", 60, 730, W - 120, 250, 24)
  lg.setFont(ctx.font(24))
  lg.setColor(0.92, 0.9, 1, 1)
  lg.printf("STICK UP / DOWN   change channel\nSTICK LEFT / RIGHT   fit or zoom\nLOWER BUTTON   info on / off\n" ..
            "2-PLAYER   back to the guide\nHOLD 1-PLAYER + 2-PLAYER   Home", 60, 756, W - 120, "center")
end

-- Between channels (stick up/down while watching), tvloop puts this up while the next one connects.
local function picture_zap()
  ctx.backdrop()
  ctx.neon_draw("CHANGING CHANNEL...", 0, 420, 44, 0xff6b6b, 1, "center", W)
  lg.setFont(ctx.font(24))
  lg.setColor(0.92, 0.9, 1, 0.9)
  lg.printf("2-PLAYER   back to the guide", 0, 520, W, "center")
end

local function play_chosen()
  local r = rows[sel]
  if not r or #r.channels == 0 then return end
  local c = cols[r.key] or 1
  local ch = r.channels[c]
  -- For tvloop and tvplay (games/tv/tvloop.sh): the chosen index, the row's name and where logos are; then per
  -- channel its playlist, stream id, name, guide id and logo file key.
  local lines = {c .. "\t" .. group_title(r.title) .. "\t" .. LOGOS}
  for _, x in ipairs(r.channels) do
    if x.logo then x.key = x.key or url_key(x.logo) end
    lines[#lines + 1] = table.concat({x.pl, x.sid, x.name, x.epg or "", x.key or ""}, "\t")
  end
  os.execute("mkdir -p " .. TMP)
  write_file(TMP .. "/play.tsv", table.concat(lines, "\n") .. "\n")
  write_file(TMP .. "/guide.pos", r.key .. "\n")
  save_recent(ch)
  if not read_file(TMP .. "/zap.fb.gz") then ctx.save_picture(TMP .. "/zap.fb.gz", picture_zap) end
  ctx.play("launch")
  ctx.request("tv", function() picture_tune(ch, r) end)
end

-- A press in the guide. Returns "exit" to leave for Home's menu.
function T.handle(name)
  idle = 0
  if name == "up" then move_row(-1)
  elseif name == "down" then move_row(1)
  elseif name == "left" then move_col(-1)
  elseif name == "right" then move_col(1)
  elseif name == "tl" then jump_playlist(-1)
  elseif name == "tr" then jump_playlist(1)
  elseif name == "low" or name == "1p" then
    local r = rows[sel]
    if r and r.empty then sync(r.pl.name) note, note_t = "Trying " .. r.pl.name .. " again...", 3
    else play_chosen() end
  elseif name == "2p" then
    ctx.play("back")
    return "exit"
  end
end

-- Held stick: after 0.35 s it repeats, faster the longer it is held.
local function repeat_held(dt)
  for _, d in ipairs({"up", "down", "left", "right"}) do
    if ctx.down[d] then
      local h = hold[d] or {held = 0, next = 0.35}
      h.held = h.held + dt
      if h.held >= h.next then
        h.next = h.held + (h.held > 1.5 and 1 / 16 or 1 / 8)
        if d == "up" then move_row(-1) elseif d == "down" then move_row(1)
        elseif d == "left" then move_col(-1) else move_col(1) end
        idle = 0
      end
      hold[d] = h
    else
      hold[d] = nil
    end
  end
end

local function poll_worker()
  if not worker then return end
  local ch = love.thread.getChannel("tv_done")
  local msg = ch:pop()
  while msg do
    if msg[1] == "sync" then
      local line = msg[3]
      for _, pl in ipairs(playlists) do
        if pl.name == msg[2] then
          if line:match("^channels") then load_lists(pl) build_rows()
          elseif line:match("^epg") then load_epg(pl) build_rows() for _, r in ipairs(rows) do for _, c in ipairs(r.channels) do c._np_t = nil end end
          elseif line:match("^error") then
            pl.status, pl.err = "error", line
            ctx.log("tv: " .. pl.name .. " " .. line)
          end
        end
      end
    elseif msg[1] == "syncdone" then
      syncing[msg[2]] = nil
      for _, pl in ipairs(playlists) do
        if pl.name == msg[2] then
          os.execute("mkdir -p " .. TMP .. "/" .. pl.name)
          if pl.status ~= "error" then
            pl.status = "ok"
            write_file(TMP .. "/" .. pl.name .. "/synced", tostring(os.time()))
            os.remove(TMP .. "/" .. pl.name .. "/failed")
          else
            local up = (read_file("/proc/uptime") or "0"):match("^(%S+)")
            write_file(TMP .. "/" .. pl.name .. "/failed", up)
          end
          build_rows()
        end
      end
    elseif msg[1] == "logo" then
      if msg[3] == "ok" or msg[3] == "have" then load_logo(msg[2]) else logos[msg[2]] = false end
    elseif msg[1] == "logosdone" then
      logo_busy = false
    end
    msg = ch:pop()
  end
  local err = worker:getError()
  if err then ctx.log("tvworker: " .. err) worker = nil end
end

-- Called from Home's menu loop too: at power-on T.load runs before Wi-Fi is up (~39 s), so the first sync
-- fails and the clock stays at 1970 until a retry after Wi-Fi connects.
function T.tick()
  poll_worker()
  if not clock_ok() then sync_stale() end
end

function T.update(dt)
  t = t + dt
  idle = idle + dt
  repeat_held(dt)
  yscroll = yscroll + (sel - yscroll) * math.min(1, dt * 12)
  for _, r in ipairs(rows) do
    local want = math.max(0, (cols[r.key] or 1) - 2)
    xscroll[r.key] = (xscroll[r.key] or want) + (want - (xscroll[r.key] or want)) * math.min(1, dt * 12)
  end
  if note_t then note_t = note_t - dt if note_t <= 0 then note, note_t = nil, nil end end
  poll_worker()
  logo_wait = logo_wait - dt
  if logo_wait <= 0 then logo_wait = 0.4 ask_logos() end
  if idle > IDLE_OUT then return "exit" end
end

function T.quit()
  if worker then love.thread.getChannel("tv_work"):push({"quit"}) end
end

-- ------------------------------------------------------------------ drawing

local TOP, ROW_H, TILE_W, TILE_H, GAP = 372, 168, 196, 112, 18

-- A tile's body and its border, painted once (white border: tinted when drawn).
local tile_body, tile_border
local function tile_images()
  if tile_body then return end
  lg.push("all")
  lg.setScissor()
  lg.origin()
  tile_body = lg.newCanvas(TILE_W, TILE_H)
  lg.setCanvas(tile_body)
  lg.clear(0, 0, 0, 0)
  lg.setColor(0.10, 0.06, 0.18, 0.92)
  ctx.rrect("fill", 0, 0, TILE_W, TILE_H, 14)
  tile_border = lg.newCanvas(TILE_W + 4, TILE_H + 4)
  lg.setCanvas(tile_border)
  lg.clear(0, 0, 0, 0)
  lg.setColor(1, 1, 1, 1)
  lg.setLineWidth(1.5)
  ctx.rrect("line", 2, 2, TILE_W, TILE_H, 14)
  lg.setCanvas()
  lg.pop()
end

local function draw_logo(ch, cx, cy, mw, mh, a)
  local img = logo_of(ch)
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(mw / iw, mh / ih)
    lg.setColor(1, 1, 1, a)
    lg.draw(img, cx, cy, 0, s, s, iw / 2, ih / 2)
  else
    -- No logo (yet): the channel's name, up to three lines.
    local f = ctx.font(mh > 80 and 22 or 17)
    local s = fit(f, ch.name, mw, 3)
    local _, n = f:getWrap(s, mw)
    lg.setFont(f)
    lg.setColor(0.92, 0.9, 1, 0.95 * a)
    lg.printf(s, cx - mw / 2, cy - #n * f:getHeight() / 2, mw, "center")
  end
  return img ~= nil
end

local function draw_tile_plain(ch, x, y, tint, a)
  -- Most tiles: two painted quads, the logo, one line of text.
  local r, g, b = ctx.rgb(tint)
  local off = dead[ch.pl .. "/" .. ch.sid]
  lg.setColor(1, 1, 1, a)
  lg.draw(tile_body, x, y)
  local cx, cy = x + TILE_W / 2, y + TILE_H / 2
  if logo_of(ch) then
    draw_logo(ch, cx, cy - 10, TILE_W - 30, TILE_H - 46, (off and 0.35 or 1) * a)
    local f = ctx.font(15)
    if not ch._cap then
      ch._cap = fit(f, ch.name, TILE_W - 16, 1)
      ch._capw = f:getWidth(ch._cap)
    end
    lg.setFont(f)
    lg.setColor(0.86, 0.84, 0.96, 0.75 * a)
    lg.print(ch._cap, math.floor(cx - ch._capw / 2), y + TILE_H - 28)
  else
    draw_logo(ch, cx, cy - 2, TILE_W - 20, TILE_H - 24, (off and 0.35 or 1) * a)
  end
  local now = now_next(ch)
  if now then
    local k = math.max(0, math.min(1, (os.time() - now[1]) / math.max(1, now[2] - now[1])))
    lg.setColor(1, 1, 1, 0.12 * a)
    lg.rectangle("fill", x + 12, y + TILE_H - 6, TILE_W - 24, 3)
    lg.setColor(r, g, b, 0.9 * a)
    lg.rectangle("fill", x + 12, y + TILE_H - 6, (TILE_W - 24) * k, 3)
  end
  if off then
    lg.setFont(ctx.font(14))
    lg.setColor(1, 0.5, 0.6, a)
    lg.printf("OFF AIR", x, y + 8, TILE_W, "center")
  end
  lg.setColor(r, g, b, 0.25 * a)
  lg.draw(tile_border, x - 2, y - 2)
end

local function draw_tile(ch, x, y, focus, tint, a)
  if focus <= 0 then return draw_tile_plain(ch, x, y, tint, a) end
  local r, g, b = ctx.rgb(tint)
  local w, h = TILE_W, TILE_H
  local s = 1 + 0.06 * focus
  local cx, cy = x + w / 2, y + h / 2
  w, h = w * s, h * s
  x, y = cx - w / 2, cy - h / 2
  if focus > 0.05 then
    lg.setBlendMode("add")
    for k = 1, 3 do
      lg.setColor(r, g, b, 0.08 * focus)
      lg.setLineWidth(4 + k * 6)
      ctx.rrect("line", x - 3, y - 3, w + 6, h + 6, 16)
    end
    lg.setBlendMode("alpha")
  end
  local off = dead[ch.pl .. "/" .. ch.sid]
  lg.setColor(0.10, 0.06, 0.18, 0.92 * a)
  ctx.rrect("fill", x, y, w, h, 14)
  if logo_of(ch) then
    draw_logo(ch, cx, cy - 10 * s, w - 30, h - 46, (off and 0.35 or 1) * a)
    lg.setFont(ctx.font(15))
    lg.setColor(0.86, 0.84, 0.96, (focus > 0.5 and 1 or 0.75) * a)
    lg.printf(fit(ctx.font(15), ch.name, w - 16, 1), x + 8, y + h - 28, w - 16, "center")
  else
    draw_logo(ch, cx, cy - 2, w - 20, h - 24, (off and 0.35 or 1) * a)
  end
  local now = now_next(ch)
  if now then
    local k = math.max(0, math.min(1, (os.time() - now[1]) / math.max(1, now[2] - now[1])))
    lg.setColor(1, 1, 1, 0.12 * a)
    lg.rectangle("fill", x + 12, y + h - 6, w - 24, 3)
    lg.setColor(r, g, b, 0.9 * a)
    lg.rectangle("fill", x + 12, y + h - 6, (w - 24) * k, 3)
  end
  if off then
    lg.setFont(ctx.font(14))
    lg.setColor(1, 0.5, 0.6, a)
    lg.printf("OFF AIR", x, y + 8, w, "center")
  end
  lg.setColor(r, g, b, (0.25 + 0.75 * focus) * a)
  lg.setLineWidth(focus > 0.5 and 3 or 1.5)
  ctx.rrect("line", x, y, w, h, 14)
end

local function draw_info()
  local r = rows[sel]
  local y0 = 112
  lg.setColor(0.04, 0.0, 0.10, 0.80)
  ctx.rrect("fill", 24, y0, W - 48, 236, 22)
  if not r then return end
  local tr, tg, tb = ctx.rgb(r.tint)
  lg.setColor(tr, tg, tb, 0.7)
  lg.setLineWidth(2)
  ctx.rrect("line", 24, y0, W - 48, 236, 22)
  if r.empty then
    lg.setFont(ctx.font(30))
    lg.setColor(1, 1, 1, 1)
    lg.printf(r.pl.name, 48, y0 + 30, W - 96, "left")
    lg.setFont(ctx.font(22))
    lg.setColor(0.9, 0.88, 1, 0.9)
    local msg = syncing[r.pl.name] and "Getting the channel list..." or
                (r.pl.err and "Can't reach " .. r.pl.name .. " right now. The provider may be down; press the lower button to try again."
                 or "No channels yet.")
    lg.printf(msg, 48, y0 + 84, W - 96, "left")
    return
  end
  local ch = r.channels[cols[r.key] or 1]
  if not ch then return end
  -- The logo on the left, in a tile of its own.
  lg.setColor(0.10, 0.06, 0.18, 1)
  ctx.rrect("fill", 44, y0 + 22, 176, 112, 16)
  draw_logo(ch, 132, y0 + 78, 150, 92, 1)
  local x, wtext = 240, W - 240 - 48
  lg.setFont(ctx.font(30))
  lg.setColor(1, 1, 1, 1)
  lg.printf(fit(ctx.font(30), ch.name, wtext, 1), x, y0 + 18, wtext, "left")
  local now, nxt = now_next(ch)
  local y = y0 + 62
  if now then
    lg.setFont(ctx.font(24))
    lg.setColor(1, 0.92, 0.6, 1)
    local title = fit(ctx.font(24), now[3], wtext, 2)
    lg.printf(title, x, y, wtext, "left")
    local _, lines = ctx.font(24):getWrap(title, wtext)
    y = y + math.min(2, #lines) * 30 + 6
    local k = math.max(0, math.min(1, (os.time() - now[1]) / math.max(1, now[2] - now[1])))
    lg.setFont(ctx.font(17))
    lg.setColor(0.85, 0.82, 0.98, 0.9)
    lg.print(clock(now[1]) .. " - " .. clock(now[2]), x, y)
    lg.setColor(1, 1, 1, 0.15)
    ctx.rrect("fill", x + 170, y + 8, wtext - 170, 6, 3)
    lg.setColor(tr, tg, tb, 1)
    ctx.rrect("fill", x + 170, y + 8, (wtext - 170) * k, 6, 3)
    y = y + 28
  elseif not ch.epg or not clock_ok() then
    lg.setFont(ctx.font(20))
    lg.setColor(0.8, 0.78, 0.92, 0.8)
    lg.printf(clock_ok() and "No guide for this channel" or "Setting the clock...", x, y, wtext, "left")
    y = y + 30
  end
  if nxt then
    lg.setFont(ctx.font(18))
    lg.setColor(0.8, 0.78, 0.92, 0.85)
    lg.printf(fit(ctx.font(18), "NEXT  " .. clock(nxt[1]) .. "   " .. nxt[3], wtext, 1), x, y, wtext, "left")
    y = y + 26
  end
  -- What it's about, in the room left above the tag line.
  local dy = math.max(y + 4, y0 + 146)
  local room = math.floor((y0 + 206 - dy) / 20)
  if now and now[4] and now[4] ~= "" and room >= 1 then
    lg.setFont(ctx.font(16))
    lg.setColor(0.78, 0.76, 0.9, 0.75)
    lg.printf(fit(ctx.font(16), now[4], W - 96, room), 44, dy, W - 96, "left")
  end
  -- The playlist and group, bottom right.
  lg.setFont(ctx.font(15))
  local tag = (ch.pl or "") .. "  ·  " .. r.title
  lg.setColor(tr, tg, tb, 0.85)
  lg.printf(tag, 44, y0 + 210, W - 96, "right")
end

-- The rows, drawn in passes so like things batch into one draw call each (bodies, logos, text, bars, borders):
-- drawn tile by tile they were ~120 draw calls a frame, and the Mali's per-call cost held the guide at 50 fps.
local function draw_rows()
  local vis, titles = {}, {}
  local first = math.max(1, math.floor(yscroll) - 1)
  for i = first, math.min(#rows, math.floor(yscroll) + 5) do
    local r = rows[i]
    local y = TOP + (i - yscroll) * ROW_H
    -- The chosen row sits under the info panel; the rows above it fade out before reaching it.
    local a = math.max(0, math.min(1, (y - 300) / 80))
    if a > 0 and y < H then
      local focus_row = i == sel
      titles[#titles + 1] = {r = r, y = y, a = a, focus = focus_row}
      local xs = xscroll[r.key] or 0
      local c = cols[r.key] or 1
      local lo = math.max(1, math.floor(xs))
      for ci = lo, math.min(#r.channels, lo + 4) do
        local x = 40 + (ci - 1 - xs) * (TILE_W + GAP)
        if x < W then
          vis[#vis + 1] = {ch = r.channels[ci], x = x, y = y + 34, tint = r.tint, a = a * (focus_row and 1 or 0.8),
                           focus = focus_row and ci == c}
        end
      end
    end
  end
  -- Row titles: the playlist chips (shapes), then the small text, then the titles.
  local f15, f22 = ctx.font(15), ctx.font(22)
  for _, tt in ipairs(titles) do
    if tt.r.header then
      local tr, tg, tb = ctx.rgb(tt.r.tint)
      tt.chip = f15:getWidth(tt.r.header) + 20
      lg.setColor(tr, tg, tb, 0.9 * tt.a)
      ctx.rrect("fill", 40, tt.y - 2, tt.chip, 24, 12)
    end
  end
  lg.setFont(f15)
  for _, tt in ipairs(titles) do
    local r = tt.r
    if r.header then
      lg.setColor(0.06, 0.02, 0.12, tt.a)
      lg.print(r.header, 50, tt.y + 2)
    end
    if #r.channels > 0 then
      lg.setColor(0.8, 0.78, 0.92, 0.55 * tt.a)
      local c = cols[r.key] or 1
      local s = tt.focus and (c .. " / " .. #r.channels) or (#r.channels .. " channels")
      lg.print(s, W - 40 - f15:getWidth(s), tt.y)
    elseif r.empty then
      lg.setColor(0.85, 0.8, 1, 0.7 * tt.a)
      lg.print(syncing[r.pl.name] and "Getting the channel list..." or "Not answering right now", 40, tt.y + 70)
    end
  end
  lg.setFont(f22)
  for _, tt in ipairs(titles) do
    local tr, tg, tb = ctx.rgb(tt.r.tint)
    lg.setColor(tr, tg, tb, (tt.focus and 1 or 0.6) * tt.a)
    lg.print(tt.r.title, 40 + (tt.chip and tt.chip + 12 or 0), tt.y - 4)
  end
  -- Tiles. Bodies:
  for _, v in ipairs(vis) do
    if not v.focus then lg.setColor(1, 1, 1, v.a) lg.draw(tile_body, v.x, v.y) end
  end
  -- Logos (one texture each), or the name when there is none:
  local named = {}
  for _, v in ipairs(vis) do
    if not v.focus then
      local ch = v.ch
      local off = dead[ch.pl .. "/" .. ch.sid]
      if logo_of(ch) then
        draw_logo(ch, v.x + TILE_W / 2, v.y + TILE_H / 2 - 10, TILE_W - 30, TILE_H - 46, (off and 0.35 or 1) * v.a)
      else
        named[#named + 1] = v
      end
    end
  end
  local f17 = ctx.font(17)
  lg.setFont(f17)
  for _, v in ipairs(named) do
    local ch = v.ch
    if not ch._nm then ch._nm = fit(f17, ch.name, TILE_W - 20, 3) end
    local _, n = f17:getWrap(ch._nm, TILE_W - 20)
    lg.setColor(0.92, 0.9, 1, 0.95 * v.a)
    lg.printf(ch._nm, v.x + 10, v.y + TILE_H / 2 - 2 - #n * f17:getHeight() / 2, TILE_W - 20, "center")
  end
  -- Captions under the logos:
  lg.setFont(f15)
  for _, v in ipairs(vis) do
    local ch = v.ch
    if not v.focus and logo_of(ch) then
      if not ch._cap then
        ch._cap = fit(f15, ch.name, TILE_W - 16, 1)
        ch._capw = f15:getWidth(ch._cap)
      end
      lg.setColor(0.86, 0.84, 0.96, 0.75 * v.a)
      lg.print(ch._cap, math.floor(v.x + TILE_W / 2 - ch._capw / 2), v.y + TILE_H - 28)
    end
    if not v.focus and dead[ch.pl .. "/" .. ch.sid] then
      lg.setColor(1, 0.5, 0.6, v.a)
      lg.print("OFF AIR", math.floor(v.x + TILE_W / 2 - f15:getWidth("OFF AIR") / 2), v.y + 8)
    end
  end
  -- Programme progress bars:
  local now_t = os.time()
  for _, v in ipairs(vis) do
    if not v.focus then
      local now = now_next(v.ch)
      if now then
        local r, g, b = ctx.rgb(v.tint)
        local k = math.max(0, math.min(1, (now_t - now[1]) / math.max(1, now[2] - now[1])))
        lg.setColor(1, 1, 1, 0.12 * v.a)
        lg.rectangle("fill", v.x + 12, v.y + TILE_H - 6, TILE_W - 24, 3)
        lg.setColor(r, g, b, 0.9 * v.a)
        lg.rectangle("fill", v.x + 12, v.y + TILE_H - 6, (TILE_W - 24) * k, 3)
      end
    end
  end
  -- Borders, tinted:
  for _, v in ipairs(vis) do
    if not v.focus then
      local r, g, b = ctx.rgb(v.tint)
      lg.setColor(r, g, b, 0.25 * v.a)
      lg.draw(tile_border, v.x - 2, v.y - 2)
    end
  end
  -- The chosen tile last, on top, with its glow.
  for _, v in ipairs(vis) do
    if v.focus then draw_tile(v.ch, v.x, v.y, 0.75 + 0.25 * math.sin(t * 4), v.tint, v.a) end
  end
end

local backdrop_mesh
function T.draw()
  tile_images()
  -- A deep violet gradient, the colours of Home's night sky: one pass.
  if not backdrop_mesh then
    backdrop_mesh = lg.newMesh({{0, 0, 0, 0, 0.05, 0.02, 0.11, 1}, {W, 0, 0, 0, 0.05, 0.02, 0.11, 1},
                                {W, H, 0, 0, 0.13, 0.02, 0.16, 1}, {0, H, 0, 0, 0.13, 0.02, 0.16, 1}}, "fan", "static")
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(backdrop_mesh)
  ctx.neon_draw("LIVE TV", 30, 30, 44, 0xff6b6b, 1, "left", W)
  if clock_ok() then
    lg.setFont(ctx.font(28))
    lg.setColor(0.95, 0.92, 1, 0.95)
    lg.printf(clock(os.time()), 0, 44, W - 36, "right")
  end
  for _, pl in ipairs(playlists) do
    if syncing[pl.name] then
      lg.setFont(ctx.font(15))
      lg.setColor(0.8, 0.78, 0.92, 0.5 + 0.3 * math.sin(t * 3))
      lg.printf("updating the guide...", 0, 84, W - 36, "right")
      break
    end
  end
  if #rows == 0 then
    lg.setFont(ctx.font(26))
    lg.setColor(1, 1, 1, 1)
    lg.printf(#playlists == 0 and "No TV playlists on this cabinet yet." or "Tuning in to the channel lists...",
              60, 480, W - 120, "center")
    return
  end
  draw_info()
  draw_rows()
  -- The bottom: how to use it.
  lg.setColor(0.02, 0.0, 0.05, 0.85)
  lg.rectangle("fill", 0, H - 44, W, 44)
  lg.setFont(ctx.font(18))
  lg.setColor(0.85, 0.8, 1, 0.9)
  lg.printf("STICK  browse  ·  LOWER BUTTON  watch  ·  TOP BUTTONS  playlist  ·  2-PLAYER  back", 0, H - 34, W, "center")
  if note then
    local a = math.min(1, note_t)
    lg.setColor(0.25, 0.02, 0.12, 0.92 * a)
    ctx.rrect("fill", 70, 300, W - 140, 60, 20)
    lg.setColor(1, 0.5, 0.6, a)
    ctx.rrect("line", 70, 300, W - 140, 60, 20)
    lg.setFont(ctx.font(22))
    lg.printf(note, 70, 316, W - 140, "center")
  end
end

return T
