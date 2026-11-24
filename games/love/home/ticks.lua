-- ticks.lua: main.lua's "the ticks" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local CAT, HS, IDLE, ST, headless, music, night, shelf, shows, tv

return function(c)
CAT, HS, IDLE, ST, headless, music = c.CAT, c.HS, c.IDLE, c.ST, c.headless, c.music
night, shelf, shows, tv = c.night, c.shelf, c.shows, c.tv


-- The song for what is on the screen (songs.lua; the night has one for each of its scenes), and its volume.
local NIGHT_SONG = {dusk = "dusk", quiet = "quiet", rest = "none", dawn = "dawn"}
local music_vol
local function music_tick()
  if ST.scene == "intro" then return end
  local want, vol, fade = "menu", 0.32, 1.2
  if ST.scene == "night" then
    local sc = night.scene_at(ST.night_t * ST.NIGHT_SPEED)
    want, vol, fade = NIGHT_SONG[sc] or sc, 0.26, 3
  elseif ST.scene == "show" and ST.cur_show then
    -- (behind the curtain, before the show has started, it isn't asked: silence until it has)
    if ST.curtain and ST.curtain.phase == "cover" then return end
    want, vol, fade = ST.cur_show.music(), 0.42, 2
    if ST.TRACE then
      if ST.cur_show.clock then HS.trace("t", ST.cur_show.clock()) end
      if want ~= ST.trace_seen.music then ST.trace_seen.music = want HS.trace("music", want) end
      local act = ST.cur_show.act and ST.cur_show.act()
      if act ~= ST.trace_seen.act then ST.trace_seen.act = act HS.trace("act", act) end
    end
  elseif ST.scene == "tv" or ST.scene == "shelf" then want = "tv"
  elseif ST.scene == "attract" then want = "attract" end
  -- (headless tests choose the song too, so a show that can't say which is caught on the PC, but play nothing)
  if headless then return end
  if vol ~= music_vol then music_vol = vol music.volume(vol, 1.5) end
  music.play(want, fade)
end

-- The TV guide, attract, and the idle shows (night sky, Freedom Show), with their music. (Out of love.update:
-- LuaJIT allows a function 60 upvalues.)
local cards_t = 0
local function update_idle(dt)
  cards_t = cards_t - dt
  if cards_t <= 0 then cards_t = 30 IDLE.update_cards() end
  if ST.scene == "tv" then
    ST.idle = 0
    if tv.update(dt) == "exit" then ST.go("menu") end
  end
  if ST.scene == "shelf" then
    ST.idle = 0
    if shelf.update(dt) == "exit" then ST.shelf_close() end
  end
  if ST.scene == "initials" then
    ST.idle = 0
    if ST.initials.update(dt) == "done" then ST.go("menu") end
  end
  if ST.scene == "hall" then
    ST.idle = 0
    if ST.hall.update(dt) == "exit" then ST.go("menu") ST.near_sel = nil end
  end
  ST.idle = ST.idle + dt
  if ST.scene == "menu" and ST.idle > ST.IDLE_ATTRACT then ST.go("attract") ST.attract_t = 0 ST.attract_sel = ST.sel end
  if ST.scene == "attract" then
    ST.attract_t = ST.attract_t + dt
    if ST.attract_t > 3.5 then ST.attract_t = 0 ST.sel = ST.sel % #CAT.items + 1 end
    if ST.idle > ST.IDLE_NIGHT then IDLE.start_show() end
  end
  if ST.scene == "night" then
    ST.night_t = ST.night_t + dt
    ST.auto_night_t = ST.auto_night_t + dt
    -- AUTO: the night sky has had its half hour (or the Longhorns kick off): the calendar's show.
    if ST.show_mode == "auto" and not ST.demo and (ST.auto_night_t > ST.AUTO_NIGHT_BLOCK or ST.game_now.window) then
      local id = shows.pick(os.time(), ST.game_now, ST.auto_rot)
      if id ~= "night" then ST.auto_rot = ST.auto_rot + 1 IDLE.play_show(id) else ST.auto_night_t = 0 end
    end
  end
  if ST.scene == "show" and ST.cur_show then
    ST.idle = 0
    if HS.curtain_step(dt) and ST.cur_show.update(dt) then
      if os.getenv("HOME_SHOW_ONCE") then love.event.quit(0) return end   -- (tools/show_lint.py)
      -- The show is over: its tiles again (watching one), the same show (one show only), or the night sky's
      -- turn (AUTO; the Longhorns go on while the game is on).
      if ST.demo then IDLE.open_tiles(ST.demo)
      elseif ST.show_mode ~= "auto" then IDLE.play_show(ST.show_mode)
      elseif ST.cur_show_id == "longhorns" and ST.game_now.window then IDLE.play_show("longhorns")
      else IDLE.play_show("night") end
    end
  end
  if ST.scene == "shows" then
    shows.update(dt)
    if ST.idle > ST.IDLE_NIGHT then shows.close() IDLE.start_show() end
  end
  music_tick()
end


M.update_idle = update_idle
return M
end
