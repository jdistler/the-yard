-- Partycade TV's network thread (a love.thread, started by tv.lua): runs tvnet (games/tv/tvnet.c), one job at
-- a time, and passes its progress lines back, so the guide keeps its frame rate while lists and logos load.
--   "tv_work" <- {"sync", NAME, BIN, DIR, TMP}     one playlist's groups, channels and guide
--             <- {"logos", LISTFILE, BIN, OUTDIR}   the logos named in LISTFILE ("key url" lines), into OUTDIR
--             <- {"now", NAME, BIN, DIR, TMP}        what the household's TVs watch (TMP/NAME/now.tsv)
--             <- {"line", NAME, BIN, DIR, TMP, SID}  who holds the line SID needs (TMP/line.txt)
--             <- {"quit"}
--   "tv_done" -> {"sync", NAME, line} ... {"syncdone", NAME}; {"logo", key, "ok"|"have"|"fail"} ... {"logosdone"}
local work = love.thread.getChannel("tv_work")
local done = love.thread.getChannel("tv_done")

local function safe(s) return (s or ""):gsub("[^%w/._-]", "") end

while true do
  local job = work:demand()
  if job[1] == "quit" then break end
  if job[1] == "sync" then
    local name, bin, dir, tmp = safe(job[2]), safe(job[3]), safe(job[4]), safe(job[5])
    local cmd = string.format("%s/tvnet sync %s/account.conf %s %s/%s %s/%s 2>&1", bin, dir, name, dir, name, tmp, name)
    local p = io.popen(cmd, "r")
    if p then
      for line in p:lines() do done:push({"sync", name, line}) end
      p:close()
    else
      done:push({"sync", name, "error start cannot run tvnet"})
    end
    done:push({"syncdone", name})
  elseif job[1] == "now" then
    -- What the household's TVs are watching (the Pink TV gate's /__gate/now) -> TMP/NAME/now.tsv
    local name, bin, dir, tmp = safe(job[2]), safe(job[3]), safe(job[4]), safe(job[5])
    os.execute(string.format("mkdir -p %s/%s; %s/tvnet now %s/account.conf %s %s/%s/now.tsv >/dev/null 2>&1", tmp, name, bin, dir, name, tmp, name))
    done:push({"nowdone", name})
  elseif job[1] == "line" then
    -- Why a channel didn't open: is a TV on the household's line? -> TMP/line.txt (+ .watching)
    local name, bin, dir, tmp, sid = safe(job[2]), safe(job[3]), safe(job[4]), safe(job[5]), safe(job[6])
    os.execute(string.format("%s/tvnet line %s/account.conf %s %s %s/line.txt >/dev/null 2>&1", bin, dir, name, sid, tmp))
    done:push({"linedone", name, sid})
  elseif job[1] == "logos" then
    local list, bin, tmp = safe(job[2]), safe(job[3]), safe(job[4])
    local p = io.popen(string.format("%s/tvnet logos %s %s 168 96 2>/dev/null", bin, list, tmp), "r")
    if p then
      for line in p:lines() do
        local key, st = line:match("^logo (%S+) (%a+)")
        if key then done:push({"logo", key, st}) end
      end
      p:close()
    end
    done:push({"logosdone"})
  end
end
