-- homestate.lua: main.lua's "state" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local CAT, D, H, ST, W, fx, headless, lg, read_file, shows, shelf, log

return function(c)
CAT, D, H, ST, W, fx = c.CAT, c.D, c.H, c.ST, c.W, c.fx
headless, lg, read_file, shows, shelf, log = c.headless, c.lg, c.read_file, c.shows, c.shelf, c.log


ST.sel, ST.pos = 1, 1
ST.frame = 0
-- HOME_TRACE=PATH (tools/show_review.py): what a show does, as it plays, one line an event: "<show secs> <kind> ..."
-- (act: the scene; music: the song; sfx: a sound; cam x y zoom, 10 a second; say/caption/plate: words shown).
ST.TRACE = os.getenv("HOME_TRACE") and io.open(os.getenv("HOME_TRACE"), "w")
ST.trace_t, ST.trace_seen = nil, {}
local function trace(kind, a, b, c)
  if kind == "t" then ST.trace_t = a return end
  local when = ST.trace_t or ST.frame / 60
  if kind == "parts" then
    if ST.frame % 30 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f parts %d %d\n", when, a, b))
    return
  end
  if kind == "crowd" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f crowd %s\n", when, a))
    return
  end
  if kind == "cast" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f cast %.0f %.0f %.0f\n", when, a, b or 0, c or 0))
    return
  end
  if kind == "cam" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f cam %.0f %.0f %.3f\n", when, a, b, c))
    return
  end
  if kind == "say" or kind == "caption" or kind == "plate" then
    -- (words are drawn every frame: once, then again only after a second away)
    local k = kind .. a
    local last = ST.trace_seen[k]
    ST.trace_seen[k] = ST.frame
    if last and ST.frame - last < 60 then return end
  end
  ST.TRACE:write(string.format("%.2f %s %s\n", when, kind, tostring(a)))
  if kind == "act" or kind == "music" then ST.TRACE:flush() end
end
ST.scene = "intro"           -- intro, menu, attract, night, show (an idle show), shows (a show's tiles), tv
ST.intro_t = 0
ST.idle = 0
ST.attract_t = 0
ST.launch_t, ST.launch_item = 0, nil
ST.note, ST.note_t = nil, 0
ST.stars = {}
-- The living menu's world (tools/art/home.py): a painting a season, on the SD card; nil: the synthwave grid.
ST.WORLD_ART = (os.getenv("HOME_SHOW_ART") or "/mnt/sdcard/partycade/art") .. "/home"
function ST.world_load(name)
  if ST.world and ST.world_name == name then return end
  if ST.world then ST.world:release() ST.world = nil end
  ST.world_name = name
  home_note("world:" .. name)
  local f = io.open(ST.WORLD_ART .. "/world_" .. name .. ".pkm", "rb")
  if not f then f = io.open(ST.WORLD_ART .. "/world_base.pkm", "rb") end
  if not f then return end
  local bytes = f:read("*a")
  f:close()
  local ok, img = pcall(function()
    local fd = love.filesystem.newFileData(bytes, "w.pkm")
    local cd = love.image.newCompressedData(fd)
    fd:release()
    local im = lg.newImage(cd)
    cd:release()
    return im
  end)
  if ok then img:setFilter("linear", "linear") ST.world = img end
end
ST.direct = not headless and os.getenv("HOME_CANVAS") ~= "1"


ST.vol_level, ST.vol_t, ST.vol_read = nil, 0, nil
ST.night_t = 0
-- (ST.cur_show, ST.cur_show_id) -- the idle show playing (its module; nil for the night sky), and its id
-- A show's start behind a curtain: the screen black while it sets up (its pictures, its labels: 300 ms and more
-- on the cabinet, which froze whatever was moving), its clock still until frames come smoothly, then a fade in.

-- The curtain's step: true when the show may run as usual this frame.
local function curtain_step(dt)
  local cu = ST.curtain
  if not cu then return true end
  cu.n = cu.n + 1
  if cu.phase == "cover" then
    if cu.n >= 2 then home_note("show start") ST.cur_show.start(cu.seed, cu.at) cu.phase, cu.n = "settle", 0 end
    return false
  elseif cu.phase == "settle" then
    ST.cur_show.update(0)                                      -- (its labels paint; its clock stays)
    cu.good = dt < 0.025 and cu.good + 1 or 0
    cu.held = (cu.held or 0) + dt
    -- (from idle: the NOW SHOWING card holds a moment, to be read)
    if (cu.good >= 8 or cu.n > 240) and (not cu.card or cu.held > 3.2) then cu.phase = "fade" end
    return false
  end
  cu.f = cu.f + dt
  if cu.f >= 0.4 then ST.curtain = nil end
  return true
end

local function curtain_draw()
  local cu = ST.curtain
  if not cu then return end
  local a = cu.phase == "fade" and math.max(0, 1 - cu.f / 0.6) or 1
  lg.setColor(0.02, 0.01, 0.05, a)
  lg.rectangle("fill", 0, 0, W, H)
  if cu.card then
    -- NOW SHOWING: the brand, the show's name in its own colour, what it is
    local sh = shows.BY_ID[cu.card]
    if sh then
      local k = math.min(1, (cu.held or 0) / 0.5) * a
      fx.glow(W / 2, 470, 360, 220, D.rgb(sh.tint, 0.18 * k))
      ST.draw(0, 250, 72, k)
      D.neon_draw("NOW SHOWING", 0, 380, 30, ST.ACCENT, 0.8, "center", W, k)
      local px = math.min(72, 64 * 620 / (D.font(64):getWidth(sh.title) + 20))
      D.neon_draw(sh.title, 0, 440, 64, sh.tint, 1.2, "center", W, k, px / 64)
      lg.setFont(D.font(26))
      lg.setColor(0.93, 0.9, 1, 0.9 * k)
      lg.printf(sh.blurb, 80, 560, W - 160, "center")
    end
  end
end
ST.auto_night_t = 0            -- AUTO: how long the night sky has had its turn
ST.menu_in = 0                 -- the menu fading in after the intro (seconds left)
-- (ST.attract_sel) -- the card before the attract tour: given back on waking
ST.returning = false           -- Home started again after a game (not at power-on)
-- (ST.celebrate) -- {score, title, tint, t}: back from a classic with a new high score
ST.party = 0                   -- party mode (the secret code): seconds left
ST.code_buf = {}
local CODE = {"up", "up", "down", "down", "left", "right", "left", "right", "tl", "low"}
-- (ST.last_played) -- the card of the last game played (state file)

-- The cards' neon titles (two pictures each, ~0.2 MB of GPU memory per card): painted for the cards near the
-- chosen one, given back for the far ones (all of them painted, Home's labels alone were most of its 12 MB of
-- pictures, and GPU memory is what this cabinet runs out of).
ST.labels_for, ST.labels_sel = {}, nil
local function title_labels(it)
  D.neon_img(it.title, 64, it.tint, 1.2)
  D.neon_img(it.title, 44, it.tint, 0.9)
end
local function neon_release(s, px, c, glow)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1) .. (D.face == "script" and "|s" or "")
  local e = D.neon_cache[key]
  if e then e.img:release() D.neon_cache[key] = nil end
end
local function manage_labels(all_now)
  if ST.labels_sel == ST.sel then return end
  ST.labels_sel = ST.sel
  for k, it in ipairs(CAT.items) do
    local d = math.abs(k - ST.sel)
    if d <= 3 and not ST.labels_for[k] then
      ST.labels_for[k] = true
      if all_now or d <= 1 then title_labels(it)
      else D.label_jobs[#D.label_jobs + 1] = function() if ST.labels_for[k] then title_labels(it) end end end
    elseif d > 5 and ST.labels_for[k] then
      ST.labels_for[k] = nil
      neon_release(it.title, 64, it.tint, 1.2)
      neon_release(it.title, 44, it.tint, 0.9)
    end
  end
end

local function load_state()
  local s = ST.STATE and read_file(ST.STATE)
  local n = s and (CAT.item_by_key(s:match("selkey (%S+)") or "") or tonumber(s:match("sel (%d+)")))
  if n and CAT.items[n] then ST.sel, ST.pos = n, n end
  local sm = s and s:match("show (%a+)")
  if sm and ST.SHOW_NAMES[sm] then ST.show_mode = sm end
  local lp = s and (CAT.item_by_key(s:match("playedkey (%S+)") or "") or tonumber(s:match("played (%d+)")))
  if lp and CAT.items[lp] then ST.last_played = CAT.items[lp] end
  -- At power-on, never on the original menu's card (the last choice made before the power went off).
  if os.getenv("HOME_INTRO") == "1" and CAT.items[ST.sel].kind == "stock" then ST.sel, ST.pos = 1, 1 end
  -- Nothing played yet: start on the first real card (Pac-Man), not on the empty FAVORITES card.
  if CAT.items[ST.sel].kind == "favhint" then ST.sel, ST.pos = 2, 2 end
  return s and s:match("returned (.+)")
end
local function save_state(extra, played)
  if not ST.STATE then return end
  local lp = played
  if not lp and ST.last_played then
    for k, it in ipairs(CAT.items) do if it == ST.last_played then lp = k end end
  end
  local f = io.open(ST.STATE, "w")
  if f then
    f:write("sel " .. ST.sel .. "\nselkey " .. CAT.item_key(CAT.items[ST.sel]) .. "\n" ..
            (lp and ("played " .. lp .. "\nplayedkey " .. CAT.item_key(CAT.items[lp]) .. "\n") or "") ..
            "show " .. ST.show_mode .. "\n" .. (extra or ""))
    f:close()
  end
end

-- The classics' logos (cut from the stock menu by tools/home_art.py, on the cabinet only). The cards in view
-- are loaded at once; the rest are decoded by the worker and arrive over the first frames.

local function art_image(data)
  local ok, img = pcall(lg.newImage, data, {mipmaps = true})
  if not ok then return nil end
  img:setFilter("linear", "linear")
  img:setMipmapFilter("linear")
  return img
end
local function art_path(it) return ST.ART .. "/classic_" .. it.index .. ".png" end
local function load_art()
  for k, it in ipairs(CAT.items) do
    if it.kind == "classic" then
      if math.abs(k - ST.sel) <= 2 or not ST.worker then
        local b = read_file(art_path(it))
        if b then
          local ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(b, "c.png"))
          if ok then
            if it.art then it.art:release() end
            it.art = art_image(data)
            pcall(function() data:release() end)
          end
        end
      else
        love.thread.getChannel("home_work"):push({"art", k, art_path(it)})
      end
    elseif it.kind == "arcade" or it.kind == "game" then
      -- The board's title screen, from the card (decoded on the worker; the reply sets it.shot). Only the cards
      -- near the chosen one: all of them at once, with the browser's box art, ran Home out of memory.
      if it.game.art and not it.shot and not it.asked and math.abs(k - ST.sel) <= 3 then
        it.asked = true
        if ST.worker then love.thread.getChannel("home_work"):push({"art", k, it.game.art})
        else
          local b = read_file(it.game.art)
          local ok, data = pcall(function() return love.image.newImageData(love.filesystem.newFileData(b, "a.png")) end)
          if ok then
            it.shot = art_image(data)
            pcall(function() data:release() end)
          end
        end
      end
    elseif it.id and not it.shot and (math.abs(k - ST.sel) <= 2 or not ST.worker) and love.filesystem.getInfo("art/" .. it.id .. ".png") then
      -- Our games: a frame of the game itself (cart shots), packed into home.love (loaded near sel).
      it.shot = lg.newImage("art/" .. it.id .. ".png")
      it.shot:setFilter("linear", "linear")
    end
  end
end


-- The art worker's results (worker.lua decodes on its own thread): at most 2 GPU texture uploads per frame, so
-- waking from idle never spikes Mali memory or hitches. (main.lua's love.update until HOME_REFACTOR.md CP5)
local function drain_worker()
  if not ST.worker then return end
  local n_up = 0
  while n_up < 2 do
    local msg = love.thread.getChannel("home_done"):pop()
    if not msg then break end
    n_up = n_up + 1
    home_note("upload:" .. tostring(msg[2]))
    if msg[1] == "art" and type(msg[2]) == "string" and msg[2]:sub(1, 6) == "shelf:" then
      if msg[3] then shelf.art_ready(msg[2], msg[3]) else shelf.art_failed(msg[2]) end
    elseif msg[1] == "art" and type(msg[2]) == "string" then
      if msg[3] then shows.thumb_ready(msg[2], msg[3]) end
    elseif msg[1] == "art" and msg[3] then
      if not ST.menu_freed then
        local it = CAT.items[msg[2]]
        if it then
          if it.kind == "arcade" or it.kind == "game" then
            if it.shot then it.shot:release() end
            it.shot = art_image(msg[3])
          else
            if it.art then it.art:release() end
            it.art = art_image(msg[3])
          end
        end
      end
      pcall(function() msg[3]:release() end)   -- (always release decoded ImageData, even if menu_freed)
    end
  end
  local err = ST.worker:getError()
  if err then log("worker: " .. err) ST.worker = nil end
end

M.CODE = CODE
M.art_image = art_image
M.curtain_draw = curtain_draw
M.curtain_step = curtain_step
M.drain_worker = drain_worker
M.load_art = load_art
M.load_state = load_state
M.manage_labels = manage_labels
M.neon_release = neon_release
M.save_state = save_state
M.trace = trace
return M
end
