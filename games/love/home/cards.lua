-- cards.lua: main.lua's "the cards" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local CAT, D, ST, W, shelf

return function(c)
CAT, D, ST, W, shelf = c.CAT, c.D, c.ST, c.W, c.shelf



-- An arcade board's best score, and its line on the info panel ("23,310  JRN").
function ST.arcade_best(it)
  local t = shelf.arcade_table(it.id)
  return t and t[1][1] or 0
end
function ST.arcade_score_text(it)
  local t = shelf.arcade_table(it.id)
  if not t or t[1][1] <= 0 then return nil end
  if t[1][3] then return shelf.commas(t[1][1]) .. "  (HOUSE)" end   -- (no player record yet: the house's to beat)
  return shelf.commas(t[1][1]) .. (t[1][2] ~= "" and ("  " .. t[1][2]) or "")
end
for _, it in ipairs(CAT.items) do
  if it.kind == "arcade" then it.table = shelf.arcade_table(it.id) it.score = ST.arcade_score_text(it) end
end

-- FAVORITES (favs.lua): the game played last, then the most played, as cards that launch straight away.
ST.favs = require("favs")
do
  local stats = ST.favs.credit(ST.STATE)
  local last = ST.favs.last(stats)
  local order, seen = {}, {}
  if last then order[1], seen[last] = last, true end
  for _, k in ipairs(ST.favs.ranked(stats)) do
    if not seen[k] and #order < 8 then order[#order + 1], seen[k] = k, true end
  end
  local favs = {}
  for i, k in ipairs(order) do
    local base
    local sys, file = k:match("^game:([^/]+)/(.+)$")
    if sys then
      local g = shelf.find(sys, file)
      if g then
        base = {kind = "game", game = g, id = sys .. "/" .. file, title = g.title:upper(), blurb = g.blurb,
                tint = g.tint or 0xff4fd8}
      end
    else
      for _, it in ipairs(CAT.items) do if CAT.item_key(it) == k then base = it break end end
    end
    if base and base.kind ~= "stock" then
      local c = {}
      for kk, vv in pairs(base) do c[kk] = vv end
      c.section, c.fav, c.statkey = 1, true, k
      c.sub = (i == 1 and k == last and "LAST PLAYED  ·  " or "") .. ST.favs.line(stats[k])
      favs[#favs + 1] = c
    end
  end
  if #favs == 0 then
    favs[1] = {kind = "favhint", fav = true, section = 1, title = "FAVORITES", sub = "YOUR MOST-PLAYED GAMES",
               blurb = "Play anything and it lands here: the last game played, then the ones played most.", tint = 0xff7ab8}
  end
  for i = #favs, 1, -1 do table.insert(CAT.items, 1, favs[i]) end
end





-- The brand: STARLIGHT in its script neon (a painted label, like any other).
ST.BRAND, ST.C, ST.ACCENT = "Starlight", 0xffd36b, 0x6ef0c8
function ST.draw(x, y, px, alpha, sc, align, width)
  D.face = "script"
  D.neon_draw(ST.BRAND, x or 0, y, px, ST.C, 1.5, align or "center", width or W, alpha, sc)
  D.face = "round"
end
function ST.img(px)
  D.face = "script"
  local e = D.neon_img(ST.BRAND, px, ST.C, 1.5)
  D.face = "round"
  return e
end



return M
end
