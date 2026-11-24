-- catalog.lua: main.lua's "the games" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local ST, log, read_file, shelf, shows

return function(c)
ST, log, read_file, shelf, shows = c.ST, c.log, c.read_file, c.shelf, c.shows


-- tint: each classic's own colour (its card's glow and frame), from its logo.
local CLASSICS = {
  {title = "PAC-MAN", year = 1980, tint = 0xffd23f, blurb = "Eat the dots. Mind the ghosts."},
  {title = "PAC & PAL", year = 1983, tint = 0xff9a3c, blurb = "Flip the cards, find the treats."},
  {title = "SUPER PAC-MAN", year = 1982, tint = 0xff8a4c, blurb = "Keys, doors, and a super-size power pellet."},
  {title = "PAC-MAN PLUS", year = 1982, tint = 0xff5aa8, blurb = "Pac-Man, with tricks in the maze."},
  {title = "PAC-LAND", year = 1984, tint = 0x5fd16a, blurb = "Run the whole town back to Fairyland."},
  {title = "PAC-MANIA", year = 1987, tint = 0x6aa8ff, blurb = "Jump the ghosts in rolling 3-D mazes."},
  {title = "GALAGA", year = 1981, tint = 0x3fd6c0, blurb = "Win your captured fighter back. Fly two."},
  {title = "GALAXIAN", year = 1979, tint = 0x4fe0a0, blurb = "The swarm dives. Stay sharp."},
  {title = "MAPPY", year = 1983, tint = 0x5ab8ff, blurb = "A police mouse, a mansion, trampolines."},
  {title = "DIG DUG", year = 1982, tint = 0xff7a4a, blurb = "Dig, pump, and drop the rocks."},
  {title = "DIG DUG II", year = 1985, tint = 0x9ad65a, blurb = "Sink the island under the monsters."},
  {title = "ROMPERS", year = 1989, tint = 0xff6a7a, blurb = "Push the walls down on the monsters."},
}
-- The Yard games, from their own info.lua (cartinfo.lua): title, tint, blurb, stat line, as The Yard shows them.
local OURS = require("cartinfo").list(log)
local SECTIONS = {
  {name = "FAVORITES", tint = 0xff7ab8},
  {name = "CLASSICS", tint = 0xffd23f},
  {name = "ARCADE", tint = 0xffb43c},
  {name = "GAMES", tint = 0xff4fd8},
  {name = "THE YARD", tint = 0x6ef0c8},
  {name = "TV", tint = 0xff6b6b},
  {name = "SHOWS", tint = 0xff4a5a},
  {name = "EXTRAS", tint = 0x8ab4ff},
}
-- How to come back to Home from each kind of game (said on the info panel and on the "get ready" picture).
local LEAVE = {
  classic = {"HOLD  1-PLAYER  FOR 5 SECONDS", "to come back to Home (your high score is saved)"},
  cart = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  native = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  game = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  arcade = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  yard = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
}
-- (FAVORITES is section 1 and CLASSICS 2, written as numbers: main.lua is at Lua's 200-local limit)
local ARCADE_SECTION, GAMES_SECTION, YARD_SECTION, TV_SECTION, SHOWS_SECTION, MORE_SECTION = 3, 4, 5, 6, 7, 8

local PREVIEW = os.getenv("HOME_MODE") == "preview"
local items = {}
for i, c in ipairs(CLASSICS) do
  items[#items + 1] = {kind = "classic", index = i - 1, section = 2, title = c.title,
                       sub = c.year .. "  NAMCO", blurb = c.blurb, tint = c.tint}
end
-- The Shelf (shelf.lua): the games on the microSD card, a card per row (PARTY PICKS, then each system), each
-- opening the browser there. No card in the slot: one card that says so.
shelf.init()
-- The arcade boards on the card (shelf.lua): a card each, like the classics, with the board's own high-score
-- table (its top score and initials on the panel, the top five on the get-ready picture).
-- The Hall of Fame (hall.lua): every board's record and the players ranked across them, first in ARCADE.
if #shelf.arcade_games() > 0 then
  items[#items + 1] = {kind = "hall", section = ARCADE_SECTION, title = "HALL OF FAME", sub = "EVERY RECORD  ·  THE CHAMPIONS",
                       blurb = "The top score on every game, and who holds the most.", tint = 0xffd23f}
end
for _, g in ipairs(shelf.arcade_games()) do
  local meta = {}
  if g.year ~= "" then meta[#meta + 1] = g.year end
  if g.maker ~= "" then meta[#meta + 1] = g.maker:upper() end
  items[#items + 1] = {kind = "arcade", id = g.set, game = g, section = ARCADE_SECTION, title = g.title:upper(),
                       sub = table.concat(meta, "  "), blurb = g.blurb, tint = g.tint or 0xffb43c}
end
do
  local cards = shelf.cards()
  for _, c in ipairs(cards) do
    items[#items + 1] = {kind = "shelf", row = c.key, section = GAMES_SECTION, title = c.title,
                         sub = c.sub:upper(), blurb = shelf.card_blurb(c.key), tint = c.tint}
  end
  if #cards == 0 then
    items[#items + 1] = {kind = "shelf", section = GAMES_SECTION, title = "GAMES", sub = "THE GAMES CARD",
                         blurb = "Put the YARD card in the slot (power off first) for the arcade and console games.",
                         tint = 0xff4fd8}
  end
end
for _, g in ipairs(OURS) do
  items[#items + 1] = {kind = g.native and "native" or "cart", id = g.id, native = g.native, section = YARD_SECTION,
                       title = g.title, sub = "THE YARD", blurb = g.blurb, tint = g.tint, statdef = g}
end
-- Live TV (tv.lua): one card, which opens the guide in Home itself.
items[#items + 1] = {kind = "tv", section = TV_SECTION, title = "LIVE TV", sub = "CHANNEL GUIDE",
                     blurb = "Live sports, news and locals.", tint = 0xff6b6b}
-- The idle shows (shows.lua): a card each (LOWER: its parts, to watch any of them), and the SCHEDULE.
for _, sh in ipairs(shows.LIST) do
  if shows.available(sh.id) then
    items[#items + 1] = {kind = "showcard", show = sh.id, section = SHOWS_SECTION, title = sh.title,
                         sub = "IDLE SHOW  ·  LOWER BUTTON: pick a part to watch", blurb = sh.blurb, tint = sh.tint}
  end
end
items[#items + 1] = {kind = "show", section = SHOWS_SECTION, title = "SCHEDULE", sub = "AUTO", blurb = "", tint = 0xff4a5a}
-- HOME_MODE=preview (opened from a Yard row to try Home): the last card goes back to The Yard.
if PREVIEW then
  items[#items + 1] = {kind = "stock", section = MORE_SECTION, title = "BACK TO THE YARD", sub = "HOME PREVIEW",
                       blurb = "Home is a preview for now: this goes back to The Yard.", tint = 0xff9c5a}
else
  items[#items + 1] = {kind = "yard", section = MORE_SECTION, title = "YARD MENU", sub = "THE WHOLE YARD",
                       blurb = "Every Yard game, in its own menu.", tint = 0x7fe8ff}
  items[#items + 1] = {kind = "stock", section = MORE_SECTION, title = "ORIGINAL MENU", sub = "ARCADE1UP",
                       blurb = "The menu as it came. On it, hold 1-PLAYER + 2-PLAYER to come back.", tint = 0xff9c5a}
end

-- A card's name in the state file (numbers move when cards are added).
local function item_key(it)
  -- (a FAVORITES card has its own name, so coming back from the original card returns to the original)
  return (it.fav and "fav:" or "") .. it.kind .. ":" .. tostring(it.id or it.show or it.index or it.title):gsub("%s", "_")
end
local function item_by_key(k)
  for i, it in ipairs(items) do if item_key(it) == k then return i end end
end

-- The stock menu's settings: one byte per classic.
local function cfg_read(name)
  local s = read_file(ST.GAMES .. "/" .. name)
  local t = {}
  for i = 1, 12 do t[i] = s and s:byte(i) or 0 end
  return t
end
local function cfg_write(name, t)
  local f = io.open(ST.GAMES .. "/" .. name, "wb")
  if not f then return end
  local b = {}
  for i = 1, 12 do b[i] = string.char(t[i] == 1 and 1 or 0) end
  f:write(table.concat(b))
  f:close()
end
ST.speed, ST.smooth = cfg_read("Speed.cfg"), cfg_read("Smoothing.cfg")

-- The classics' high scores, from the boards' own save memory (each game its own layout). Every decoding was
-- checked against the score the game shows on its attract screen (2026-10-27, tools/cabview screenshots).
local function bcd(b) return math.floor(b / 16) * 10 + b % 16 end
local function bcd_be(s, at, n) local v = 0 for i = 0, n - 1 do v = v * 100 + bcd(s:byte(at + i) or 0) end return v end
local function bcd_le(s, at, n) local v = 0 for i = n - 1, 0, -1 do v = v * 100 + bcd(s:byte(at + i) or 0) end return v end
local function digits(s, at, n, low_first)
  local v = 0
  for i = 0, n - 1 do
    local d = s:byte(low_first and (at + n - 1 - i) or (at + i)) or 0
    if d > 9 then d = 0 end                 -- a blank
    v = v * 10 + d
  end
  return v
end
local function be32(s, at) local a, b, c, d = s:byte(at, at + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
local function best(s, first, stride, count, f)
  local m = 0
  for k = 0, count - 1 do
    local at = first + k * stride
    if at + stride - 1 <= #s then m = math.max(m, f(s, at)) end
  end
  return m
end
-- index -> {save file, decoder}; "fast" games keep a second save (PacManFast.sav).
local SCORES = {
  [0] = {"PacMan", function(s) return bcd_le(s, 1, 3) end, fast = "PacManFast"},
  [1] = {"PacandPal", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [2] = {"SuperPacMan", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [3] = {"PacManPlus", function(s) return bcd_le(s, 1, 3) end, fast = "PacManPlusFast"},
  [4] = {"PacLand", function(s) return best(s, 1, 16, 5, function(t, a) return digits(t, a, 5) * 10 end) end},
  [5] = {"PacMania", function(s) return best(s, 2049, 8, 10, function(t, a) return bcd_be(t, a, 4) * 10 end) end},
  [6] = {"Galaga", function(s) return best(s, 1, 6, 5, function(t, a) return digits(t, a, 6, true) end) end},
  [7] = {"Galaxian", function(s) return bcd_le(s, 1, 3) end},
  [8] = {"Mappy", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [9] = {"DigDug", function(s) return best(s, 1, 3, 5, function(t, a) return bcd_be(t, a, 3) end) end},
  [10] = {"DigDugII", function(s) return best(s, 1, 16, 5, function(t, a) return digits(t, a, 6) * 10 end) end},
  [11] = {"Rompers", function(s) return best(s, 2049, 4, 5, function(t, a) return be32(t, a) * 10 end) end},
}
local function high_score(index)
  local e = SCORES[index]
  if not e then return nil end
  local s = ST.speed[index + 1] == 1 and e.fast and read_file(ST.GAMES .. "/" .. e.fast .. ".sav")
  s = s or read_file(ST.GAMES .. "/" .. e[1] .. ".sav")
  if not s or #s < 3 then return nil end
  local ok, v = pcall(e[2], s)
  return ok and v > 0 and v < 100000000 and v or nil
end


M.CLASSICS = CLASSICS
M.LEAVE = LEAVE
M.PREVIEW = PREVIEW
M.SECTIONS = SECTIONS
M.cfg_write = cfg_write
M.high_score = high_score
M.item_by_key = item_by_key
M.item_key = item_key
M.items = items
return M
end
