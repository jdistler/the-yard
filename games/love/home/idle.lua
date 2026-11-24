-- idle.lua: main.lua's "the idle shows" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local A, D, ST, cfg_write, high_score, items, lg, load_art, log, manage_labels, night, play, save_state, shelf, shows, t, tv, utgame
function M.sync_t(v) t = v end   -- (main assigns t; it hands the new value over)

return function(c)
A, D, ST, cfg_write, high_score, items = c.A, c.D, c.ST, c.cfg_write, c.high_score, c.items
lg, load_art, log, manage_labels, night, play = c.lg, c.load_art, c.log, c.manage_labels, c.night, c.play
save_state, shelf, shows, t, tv, utgame = c.save_state, c.shelf, c.shows, c.t, c.tv, c.utgame

local SHOW_BLURB = {
  auto = "Follows the calendar: Halloween to New Year's in season, the Longhorns on game days, Texas, Mission " ..
         "Control and the Freedom Show by day, the night sky at night. LOWER BUTTON: watch now.",
}
local function show_card()
  for _, it in ipairs(items) do
    if it.kind == "show" then
      it.sub = ST.SHOW_NAMES[ST.show_mode] .. "   ·   top buttons change it"
      it.blurb = SHOW_BLURB[ST.show_mode] or (ST.SHOW_NAMES[ST.show_mode] .. " only, whenever nobody's playing. LOWER BUTTON: watch now.")
    end
  end
end
-- The idle shows need the GPU memory the menu's pictures hold: Home has ~35 MB on this cabinet and the Mali
-- driver keeps ~20 of it (2026-11-01: the Freedom Show over the menu's 12 MB of labels and logos ran the OOM
-- killer). So a show frees them, and waking paints them again (the cards in view at once, the rest a few a frame).
ST.menu_freed = false
local function free_menu_pictures()
  if ST.menu_freed then return end
  ST.menu_freed = true
  for _, it in ipairs(items) do
    if it.art then it.art:release() it.art = nil end
    if it.shot then it.shot:release() it.shot = nil end
    it.asked = nil
  end
  for k, e in pairs(D.neon_cache) do e.img:release() D.neon_cache[k] = nil end
  if ST.world then ST.world:release() ST.world = nil ST.world_name = nil end
  for i = #D.label_jobs, 1, -1 do D.label_jobs[i] = nil end
  ST.labels_for, ST.labels_sel, ST.near_sel = {}, nil, nil
  collectgarbage()
end
-- (ST.demo) -- started from a show's tiles: its id (back to them at the end)
ST.auto_rot = 0                      -- AUTO: ordinary days take turns
local function stop_show()
  if ST.cur_show then ST.cur_show.stop() ST.cur_show = nil end
  ST.curtain = nil
  night.set_only(nil)
  -- the show's painted labels go with it (in AUTO, show follows show with no menu between: they piled up)
  if ST.menu_freed then
    for k, e in pairs(D.neon_cache) do e.img:release() D.neon_cache[k] = nil end
  end
end
-- Arcade and FAVORITES pictures follow the chosen card: asked for within 3, released beyond 5.
function ST.near_shots(all)
  if ST.menu_freed or (ST.near_sel == ST.sel and not all) then return end
  ST.near_sel = ST.sel
  for k, it in ipairs(items) do
    if (it.kind == "arcade" or it.kind == "game") and it.game.art then
      local d = math.abs(k - ST.sel)
      if (d <= 3 or (all and it.kind == "arcade")) and not it.shot and not it.asked and ST.worker then
        it.asked = true
        love.thread.getChannel("home_work"):push({"art", k, it.game.art})
      elseif d > 5 and it.shot and not all then
        it.shot:release()
        it.shot, it.asked = nil, nil
      end
    elseif it.id and love.filesystem.getInfo("art/" .. it.id .. ".png") then
      local d = math.abs(k - ST.sel)
      if d <= 3 and not it.shot then
        it.shot = lg.newImage("art/" .. it.id .. ".png")
        it.shot:setFilter("linear", "linear")
      elseif d > 5 and it.shot and not all then
        it.shot:release()
        it.shot = nil
      end
    end
  end
end

local function restore_menu_pictures()
  stop_show()
  if not ST.menu_freed then return end
  ST.menu_freed = false
  for k, e in pairs(D.neon_cache) do e.img:release() D.neon_cache[k] = nil end
  -- Reclaim show/night textures before allocating menu art so Mali doesn't peak over 118 MB on wakeup.
  collectgarbage()
  load_art()
  ST.world_load(ST.world_want)
  ST.img(96)
  ST.labels_for, ST.labels_sel = {}, nil
  manage_labels(false)
  D.label_jobs[#D.label_jobs + 1] = function() D.neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1) end
  lg.setCanvas()
end

-- The games browser takes the menu's pictures' memory while it's open (2026-11-07: both at once, with its box
-- art, ran Home out of memory), and gives it back on the way out.
function ST.shelf_open(row, file, failed)
  free_menu_pictures()
  ST.go("shelf")
  if file then shelf.enter_at(row, file, failed) else shelf.enter(row) end
end
function ST.shelf_close()
  shelf.quit()
  ST.go("menu")
  restore_menu_pictures()
end

-- Play a show (from its segment seg, if given; demo: from its tiles).
local function play_show(id, seg, from_demo)
  free_menu_pictures()
  stop_show()
  ST.demo = from_demo and id or nil
  ST.cur_show_id = id
  local sg = seg and seg > 0 and shows.segments(id)[seg] or nil
  if id == "night" then
    -- the night sky is the menu's world, darkened: its painting stays (384 KB)
    ST.world_load(ST.world_want)
    ST.go("night")
    ST.auto_night_t = 0
    night.set_only(sg and sg[3] or nil)
    ST.night_t = (sg and not sg[3]) and sg[1] / ST.NIGHT_SPEED or 0
  else
    ST.cur_show = shows.module(id)
    if not ST.cur_show then ST.go("menu") restore_menu_pictures() return end
    ST.go("show")
    ST.curtain = {phase = "cover", n = 0, good = 0, f = 0, seed = os.time() + math.random(1, 1e6), at = sg and sg[1] or nil,
               card = (not from_demo and not os.getenv("HOME_SHOW")) and id or nil}
  end
  log("show " .. id .. (sg and (": " .. sg[2]) or ""))
end
-- The Longhorns' news for AUTO (utgame.status: the game window, game day, a big week, ...), every second.
ST.game_now = {}
-- Nobody has played for a while: the show for this mode (and the calendar).
local function start_show()
  local id = ST.show_mode
  if id == "auto" then
    id = shows.pick(os.time(), ST.game_now, ST.auto_rot)
    ST.auto_rot = ST.auto_rot + 1
  end
  play_show(id)
end
-- The cards that say what's coming: the SCHEDULE (AUTO: what the calendar picks next) and the LONGHORNS (the
-- next game, the live score, the final). Every half minute, and when the mode changes.
local function update_cards()
  -- (a refresh that fails is logged and skipped: the cards keep what they had)
  local ok, err = pcall(ST.update_cards_inner)
  if not ok then log("update_cards: " .. tostring(err)) end
end
ST.update_cards_inner = function()
  for _, it in ipairs(items) do
    if it.kind == "show" and ST.show_mode == "auto" then
      local id = shows.pick(os.time(), ST.game_now, ST.auto_rot)
      it.sub = "AUTO   ·   UP NEXT: " .. (ST.SHOW_NAMES[id] or "") .. "   ·   top buttons change it"
    elseif it.kind == "showcard" and it.show == "longhorns" then
      local g = utgame.game
      local text = shows.BY_ID.longhorns.blurb
      if g and g.kickoff then
        local now = utgame.now()
        local where = (g.home and "VS " or "AT ") .. string.upper(g.opp_loc ~= "" and g.opp_loc or g.opp or "")
        if g.state == "in" then
          local det = (g.detail and g.detail ~= "") and ("  ·  " .. string.upper(g.detail)) or ""
          text = string.format("LIVE NOW: TEXAS %d, %s %d%s%s", g.us or 0, g.opp_abbr or "OPP", g.them or 0, det,
                               g.net and ("  ·  " .. g.net) or "")
        elseif g.state == "post" and now - g.kickoff < 24 * 3600 then
          text = string.format("FINAL: TEXAS %d, %s %d%s", g.us or 0, g.opp_abbr or "OPP", g.them or 0, (g.us or 0) > (g.them or 0) and "  ·  HOOK 'EM!" or "")
        elseif g.state == "pre" and g.kickoff - now < 10 * 86400 then
          local when
          if g.tbd and g.day then
            local y, m, dd = g.day:match("(%d+)-(%d+)-(%d+)")
            when = string.upper(os.date("%a %b %d", os.time({year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12}))):gsub(" 0", " ")
                   .. ", TIME TBD"
          else
            when = string.upper(os.date("%a %b %d, %I:%M %p", g.kickoff)):gsub(" 0", " ")
          end
          text = "NEXT: " .. where .. "  ·  " .. when .. (g.net and ("  ·  " .. g.net) or "")
        end
      end
      it.blurb = text
    end
  end
  tv.tick()
  ST.update_world()
end

-- The world's season (the menu's painting) and the now-and-next line, from the calendar and the Longhorns' news.
local HOLIDAY_WORLD = {christmas = "christmas", newyear = "newyear", thanksgiving = "thanksgiving", halloween = "halloween",
                       valentine = "valentine", easter = "easter", freedom = "july4", space = "summer", texas = "spring"}
function ST.update_world()
  local now = os.time()
  local d = os.date("*t", now)
  local want = "base"
  local h = now > 1700000000 and shows.holiday(d)
  if ST.game_now.window or ST.game_now.gameday then want = "gameday"
  elseif h and HOLIDAY_WORLD[h] then want = HOLIDAY_WORLD[h]
  elseif d.month >= 6 and d.month <= 8 then want = "summer"
  elseif d.month >= 3 and d.month <= 5 then want = "spring" end
  ST.world_want = want
  if not ST.menu_freed and ST.world_name ~= want then ST.world_load(want) end
  -- now and next
  local parts = {}
  if now > 1700000000 then
    local id = shows.pick(now, ST.game_now, ST.auto_rot)
    if ST.SHOW_NAMES[id] and id ~= "night" then parts[#parts + 1] = "ON TONIGHT: " .. ST.SHOW_NAMES[id] end
  end
  local g = utgame.game
  if g and g.kickoff then
    local un = utgame.now()
    if g.state == "in" then
      parts[#parts + 1] = string.format("LIVE: TEXAS %d, %s %d", g.us or 0, g.opp_abbr, g.them or 0)
    elseif g.state == "pre" and g.kickoff - un < 8 * 86400 then
      -- A kickoff ESPN hasn't set yet (timeValid false) comes as 05:00Z, which reads 11:00 PM the night before:
      -- the game's own day (utgame's g.day) and "TIME TBD" instead (2026-11-07: "AT LSU FRI 11:00 PM").
      local when
      if g.tbd and g.day then
        local y, m, dd = g.day:match("(%d+)-(%d+)-(%d+)")
        when = string.upper(os.date("%a", os.time({year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12})))
               .. " · TIME TBD"
      else
        when = (string.upper(os.date("%a %I:%M %p", g.kickoff)):gsub(" 0", " "))
      end
      parts[#parts + 1] = "LONGHORNS " .. (g.home and "VS " or "AT ") .. string.upper(g.opp_abbr) .. " " .. when
    end
  end
  ST.now_line = #parts > 0 and table.concat(parts, "   ·   ") or nil
end

-- (ST.shows_ctx) -- for the SHOWS tiles (love.load)
local function open_tiles(id)
  free_menu_pictures()
  stop_show()
  ST.demo = nil
  shows.open(ST.shows_ctx, id)
  ST.go("shows")
end

local function handle(name)
  if name == "volup" or name == "voldown" then
    -- The kernel has changed it (volctrl.sh saves it); read it a moment later and show it.
    A.read_volume()
    ST.vol_t, ST.vol_read = 1.8, 0.2
    if ST.scene ~= "night" then play("volume") end
    return
  end
  ST.idle = 0
  if ST.scene == "intro" then
    ST.go("menu")
    ST.menu_in = 0.3
    return
  end
  if ST.scene == "attract" then
    ST.go("menu")
    if ST.attract_sel then ST.sel = ST.attract_sel end
    return
  end
  if ST.scene == "night" or ST.scene == "show" then
    -- The first press only wakes it: back to the show's tiles (watching one), or the menu.
    if ST.demo then
      open_tiles(ST.demo)
    else
      ST.go("menu")
      if ST.attract_sel then ST.sel, ST.pos = ST.attract_sel, ST.attract_sel end
      restore_menu_pictures()
    end
    play("wake")
    return
  end
  if ST.scene == "shows" then
    local r = shows.handle(name)
    if r == "back" then
      shows.close()
      ST.go("menu")
      restore_menu_pictures()
      play("back")
    elseif type(r) == "table" then
      shows.close()
      play("launch")
      play_show(r[2], r[3], true)
    end
    return
  end
  if ST.scene == "tv" then
    if tv.handle(name) == "exit" then ST.go("menu") end
    return
  end
  if ST.scene == "shelf" then
    if shelf.handle(name) == "exit" then ST.shelf_close() end
    return
  end
  if ST.scene == "initials" then
    ST.initials.handle(name)
    return
  end
  if ST.scene == "hall" then
    if ST.hall.handle(name) == "exit" then ST.go("menu") ST.near_sel = nil end
    return
  end
  if ST.launch_item then return end
  if name == "2p" then return end
  if A.secret(name) then
    -- (the code's presses moved the cards and maybe a setting: put back as they were)
    for _, it in ipairs(items) do if it.kind == "classic" then it.score = high_score(it.index) end end
    ST.party = 20
    ST.celebrate = {score = "PARTY MODE", title = "you found the secret", tint = 0xff4fd8, t = 0, big = true}
    log("party mode")
    return
  end
  local it = items[ST.sel]
  if name == "up" then A.move(-1)
  elseif name == "down" then A.move(1)
  elseif name == "left" then A.jump_section(-1)
  elseif name == "right" then A.jump_section(1)
  elseif (name == "tl" or name == "tr") and it.kind == "classic" then
    local i = it.index + 1
    if name == "tl" then
      ST.speed[i] = 1 - ST.speed[i]
      cfg_write("Speed.cfg", ST.speed)
      it.score = high_score(it.index)      -- fast Pac-Man keeps its own high score
    else ST.smooth[i] = 1 - ST.smooth[i] cfg_write("Smoothing.cfg", ST.smooth) end
    play("toggle")
  elseif (name == "low" or name == "1p") and ST.returning and t < 0.6 then
    -- Just back from a game: a button still being mashed there (fire is the lower button) is not a choice.
    return
  elseif (name == "tl" or name == "tr") and it.kind == "show" then
    local i = 1
    for k, m in ipairs(ST.SHOW_MODES) do if m == ST.show_mode then i = k end end
    if name == "tr" then i = i % #ST.SHOW_MODES + 1 else i = (i - 2) % #ST.SHOW_MODES + 1 end
    ST.show_mode = ST.SHOW_MODES[i]
    show_card()
    update_cards()
    save_state()
    play("toggle")
  elseif (name == "low" or name == "1p") and it.kind == "show" then
    -- Watch it now (AUTO: what the calendar picks).
    ST.attract_sel = ST.sel
    play("launch")
    play_show(ST.show_mode == "auto" and shows.pick(os.time(), ST.game_now, ST.auto_rot) or ST.show_mode)
  elseif (name == "low" or name == "1p") and it.kind == "showcard" then
    ST.attract_sel = ST.sel
    play("launch")
    open_tiles(it.show)
  elseif (name == "low" or name == "1p") and it.kind == "favhint" then
    -- The empty FAVORITES card: nothing to start (a launch here would have been the original menu).
    play("back")
  elseif (name == "low" or name == "1p") and it.kind == "hall" then
    ST.go("hall")
    ST.near_shots(true)   -- (its rows show every board's title screen)
    ST.hall.enter()
    play("launch")
  elseif (name == "low" or name == "1p") and it.kind == "shelf" then
    -- The browser opens in Home itself, at this card's row.
    if it.row then
      ST.shelf_open(it.row)
      play("launch")
    end
  elseif (name == "low" or name == "1p") and it.kind == "tv" then
    -- The guide opens in Home itself: no program to start.
    ST.go("tv")
    tv.enter()
    play("launch")
  elseif name == "low" or name == "1p" then
    ST.launch_item = it
    ST.launch_t = 0
    play("launch")
  end
end


M.handle = handle
M.open_tiles = open_tiles
M.play_show = play_show
M.show_card = show_card
M.start_show = start_show
M.update_cards = update_cards
return M
end
