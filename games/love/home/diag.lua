-- Home's frame diagnostics (main.lua's love.update until HOME_REFACTOR.md CP5): a hitch is logged with what the
-- frame did (home_note) and, past 250 ms, how much memory was free; every FPS_EVERY frames a frames line.
local M = {}
local lg = love.graphics
M.SLOW_MS = tonumber(os.getenv("HOME_SLOW_MS") or "")   -- (notes for parts over this many ms; default 30)
local FPS_EVERY = tonumber(os.getenv("HOME_FPS_EVERY") or "") or 300   -- the frames line: every this many frames
local fps_t, fps_n, hitches = 0, 0, 0
local ST, log, music

function M.init(c) ST, log, music = c.ST, c.log, c.music end

function M.frame(dt)
  -- a frame that took too long (a hitch you can see): logged with what was going on, the first 300 a run
  if dt > 0.045 and ST.frame > 10 and hitches < 300 then
    hitches = hitches + 1
    local avail = ""
    if dt > 0.25 then
      local mi = io.open("/proc/meminfo")
      local m = mi and mi:read("*a") or ""
      if mi then mi:close() end
      avail = ", available " .. (m:match("MemAvailable:%s*(%d+)") or "?") .. " kB"
    end
    log(string.format("hitch %d ms, scene %s%s, music %s, lua %d KB%s%s", dt * 1000, ST.scene,
                      ST.cur_show and ST.cur_show.act and (" " .. tostring(ST.cur_show_id) .. ":" .. tostring(ST.cur_show.act())) or "",
                      tostring(music.now) .. (ST.wake and (", waking " .. ST.wake.phase) or ""), collectgarbage("count"), avail,
                      #ST.notes > 0 and (", did " .. table.concat(ST.notes, " ")) or ""))
  end
  for i = #ST.notes, 1, -1 do ST.notes[i] = nil end
  fps_t, fps_n = fps_t + dt, fps_n + 1
  if fps_n == FPS_EVERY then
    local st = lg.getStats()
    log(string.format("frames: %.1f fps (%.2f ms), scene %s, lua %d KB, textures %d KB (%d), draws %d", fps_n / fps_t,
                      fps_t / fps_n * 1000, ST.scene, collectgarbage("count"), st.texturememory / 1024, st.images + st.canvases,
                      st.drawcalls))
    fps_t, fps_n = 0, 0
  end
end

-- update and draw each note their own time when over 30 ms: a hitch's notes then say where the frame went
function M.slow(what, t0)
  local ms = (love.timer.getTime() - t0) * 1000
  if ms > (M.SLOW_MS or 30) then home_note(string.format("%s %dms", what, ms)) end
end

return M
