-- actions.lua: main.lua's "actions" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names, filled by M.init(ctx).
local M = {}
local CODE, P, SECTIONS, ST, cfg_write, headless, high_score, items, log, play, read_file, save_state, splash
function M.init(c)
  CODE, P, SECTIONS, ST, cfg_write, headless = c.CODE, c.P, c.SECTIONS, c.ST, c.cfg_write, c.headless
  high_score, items, log, play, read_file, save_state = c.high_score, c.items, c.log, c.play, c.read_file, c.save_state
  splash = c.splash
end


local function request(s, it, picture, gamekey)
  if picture and (not headless or os.getenv("HOME_FB")) then
    local ok, bytes = pcall(splash.render, picture)
    if ok then splash.show(bytes) end
    if ST.BACK and not P.file_exists(ST.BACK) then
      local ok2, back = pcall(splash.render, P.picture_back)
      if ok2 then splash.save(back, ST.BACK) end
    end
  elseif it and (not headless or os.getenv("HOME_FB")) then P.pictures_for(it) end
  log("launch " .. s)
  -- The classic's high score as it was: on the way back, a higher one is celebrated.
  local played = nil
  if it and it.kind ~= "stock" then played = ST.sel end
  local extra = it and it.kind == "classic" and ("score " .. it.index .. " " .. (high_score(it.index) or 0) .. "\n")
                or it and it.kind == "arcade" and ("ascore " .. it.id .. " " .. ST.arcade_best(it) .. "\n") or ""
  -- (a Shelf game, from the browser or a FAVORITES card: favs.lua credits its play time to it)
  gamekey = gamekey or (it and it.kind == "game" and ("game:" .. it.game.sys .. "/" .. it.game.file))
  if gamekey then extra = extra .. "playedgame " .. gamekey .. "\n" end
  save_state(extra ~= "" and extra or nil, played)
  if ST.REQ then
    local f = io.open(ST.REQ, "w")
    if f then f:write(s .. "\n") f:close() end
  end
  love.event.quit(0)
end

local function launch(it)
  if it.kind == "classic" then
    local i = it.index + 1
    return "classic " .. it.index .. " " .. ST.smooth[i] .. " " .. ST.speed[i]
  elseif it.kind == "cart" then return "cart " .. it.id
  elseif it.kind == "native" then return "native " .. it.native
  elseif it.kind == "arcade" then return "shelf arcade " .. it.game.file
  elseif it.kind == "game" then return "shelf " .. it.game.sys .. " " .. it.game.file
  elseif it.kind == "yard" then return "yard"
  else return "stock" end
end

local function move(d)
  local old = items[ST.sel].section
  ST.sel = math.max(1, math.min(#items, ST.sel + d))
  play(items[ST.sel].section ~= old and "section" or "move")
end

-- (an empty section is skipped: with no card in the slot ARCADE has no cards, and the stick used to stop dead at
-- it, found by the characterization tour, 2026-11-24)
local function jump_section(d)
  local cur = items[ST.sel].section
  local want = cur + d
  while want >= 1 and want <= #SECTIONS do
    for i, it in ipairs(items) do
      if it.section == want then
        ST.sel = i
        play("section")
        return
      end
    end
    want = want + d
  end
end

local function read_volume()
  local s = read_file(ST.VOLUME_FILE)
  local n = s and tonumber(s:match("%d+"))
  if n then ST.vol_level = math.max(0, math.min(15, n)) end
end

-- The secret code: up up down down left right left right, top-left (B), lower (A).
local code_before = {}            -- the card and settings before each press: the code's moves are undone
local function secret(name)
  ST.code_buf[#ST.code_buf + 1] = name
  code_before[#code_before + 1] = {sel = ST.sel, speed = {unpack(ST.speed)}, smooth = {unpack(ST.smooth)}}
  if #ST.code_buf > #CODE then table.remove(ST.code_buf, 1) table.remove(code_before, 1) end
  if #ST.code_buf < #CODE then return false end
  for i = 1, #CODE do if ST.code_buf[i] ~= CODE[i] then return false end end
  local b = code_before[1]
  ST.sel = b.sel
  for i = 1, 12 do
    if ST.speed[i] ~= b.speed[i] or ST.smooth[i] ~= b.smooth[i] then
      ST.speed, ST.smooth = b.speed, b.smooth
      cfg_write("Speed.cfg", ST.speed)
      cfg_write("Smoothing.cfg", ST.smooth)
      break
    end
  end
  ST.code_buf, code_before = {}, {}
  return true
end


M.jump_section = jump_section
M.launch = launch
M.move = move
M.read_volume = read_volume
M.request = request
M.secret = secret

return M
