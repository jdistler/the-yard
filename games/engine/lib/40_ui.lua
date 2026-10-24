-- The words on screen.

ui = {}

-- The caption band: a cream strip along the bottom where a grown-up reads what is going
-- on, a line at a time. Each new line goes to the log as "<cart> say <line>", which is how
-- the tests follow a game. band = 32 pixels on the large picture, 22 on the small one.
local said
function ui.band(line, size)
  local h = W >= 384 and 32 or 22
  size = size or (h >= 32 and 23 or 15)
  -- Long lines shrink to fit rather than run off the edge.
  while size > 10 and gfx.textw(line, size) > W - 12 do size = size - 1 end
  gfx.rect(0, H - h, W, h, pal.cream)
  gfx.rect(0, H - h, W, 2, alpha(pal.ink, 60))
  gfx.text(line, W / 2, H - h + (h - gfx.lineh(size)) / 2 + 1, size, pal.ink, "center")
  if line ~= said then
    said = line
    log(game.id .. " say " .. line)
  end
end
function ui.band_height() return W >= 384 and 32 or 22 end

-- "press to start", blinking.
function ui.prompt(text, y, size, color)
  if blink(60) then gfx.text(text, W / 2, y, size or 18, color or pal.cream, "center", pal.ink) end
end

-- A panel: a soft dark rounded box to put words on.
function ui.panel(x, y, w, h, color) gfx.rrect(x, y, w, h, 12, color or alpha(0x2a1630, 200)) end

-- A big title with a bob: ui.title("Keep", 104, 44, pal.sun).
function ui.title(text, y, size, color, outline)
  local bob = sin(game.frame * 0.05) * 3
  gfx.text(text, W / 2, y + bob, size or 44, color or pal.sun, "center", outline or pal.night)
end

-- The leaving hint for games with a score screen: small, in a corner, out of the way.
function ui.quit_hint(color)
  gfx.text("1P+2P: leave", 4, H - 14, 11, color or alpha(0xd0f0c0, 200), "left", alpha(0x1a3a20, 200))
end
