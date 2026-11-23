-- A module that is nice to have, not needed to play (the Longhorns' schedule, the TV guide, the games card's
-- library): its first error is logged and turns it off until Home restarts, instead of taking Home down.
-- 2026-11-08: a season row cached from a game in progress crashed Home at every cold boot, twice running, and
-- homeloop put the cabinet on the stock menu. Off, a module's functions return its defaults (no games, no
-- channels, nothing to draw), so its callers need no change.
--
--   guard(mod, name, defaults, log [, off])   defaults: function name -> function returning the safe answer;
--                                             a function with no default returns nothing. off: start off
--                                             (HOME_SAFE=1, homeloop's safe mode).
local unpack = unpack or table.unpack

return function(mod, name, defaults, log, off)
  mod.__off = off or false
  if off then log("safe mode: " .. name .. " off") end
  for k, f in pairs(mod) do
    if type(f) == "function" then
      local d = defaults[k]
      mod[k] = function(...)
        if mod.__off then
          if d then return d(...) end
          return
        end
        -- (HOME_FAIL_MODULE=<name>: the tests make this module's first call fail)
        if os.getenv("HOME_FAIL_MODULE") == name and not mod.__failed_once then
          mod.__failed_once = true
          f = function() error("test failure (HOME_FAIL_MODULE)") end
        end
        local r = {pcall(f, ...)}
        if r[1] then return unpack(r, 2, table.maxn(r)) end
        mod.__off = true
        log(string.format("%s: %s failed (%s); %s is off until Home restarts", name, k, tostring(r[2]), name))
        if d then return d(...) end
      end
    end
  end
  return mod
end
