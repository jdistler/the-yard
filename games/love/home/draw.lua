-- Home's drawing helpers (main.lua's "colors and drawing" until HOME_REFACTOR.md CP2): colours, fonts, neon text
-- and its painted-label cache, rounded rectangles. The state they keep lives here: the fonts and their faces,
-- the face in use (round, or the brand's script), the cache of painted labels and the queue that paints them.
local D = {}
local lg = love.graphics
local W = 768

D.fonts = {}
D.font_data = nil            -- the round face's file (main.lua's love.load)
D.script_data = nil          -- Starlight's wordmark face (Pacifico, OFL; a subset)
D.script_fonts = {}
D.face = "round"             -- "script" while the brand is drawn
D.trace_font = nil           -- (HOME_TRACE: a new font made; set once the trace exists)
-- Neon labels painted once into a picture (glow included): drawing one is a single quad. Live neon() was 17
-- prints a label, and Home ran at 48-55 fps on the cabinet (2026-10-27). All are painted in love.load, before
-- the first frame (a canvas switch mid-frame is costly on the Mali). Made with no scissor (see gfx.lua's
-- new_canvas: a clip carried onto a canvas left it unpainted).
D.neon_cache = {}
D.label_jobs = {}
D.painted = 0

function D.init(w) W = w end

function D.rgb(c, a)
  return math.floor(c / 65536) % 256 / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255, a or 1
end

function D.font(px)
  -- (whole pixels only: a size that changes smoothly, 22 + ph * 10, made a new font every frame, each with its
  -- glyph texture, until the cabinet ran out of memory 14 minutes into Texas, 2026-11-06)
  px = math.floor(px + 0.5)
  if not D.fonts[px] then
    if D.trace_font then D.trace_font(px) end
    D.fonts[px] = D.font_data and lg.newFont(D.font_data, px) or lg.newFont(px)
  end
  return D.fonts[px]
end
-- Starlight's wordmark face: the marquee and the brand's titles
function D.script_font(px)
  px = math.floor(px + 0.5)
  if not D.script_fonts[px] then
    D.script_fonts[px] = D.script_data and lg.newFont(D.script_data, px) or D.font(px)
  end
  return D.script_fonts[px]
end

-- Text with a neon glow: soft additive copies around it, then the text.
function D.neon(s, x, y, px, c, glow, align, width)
  local f = D.face == "script" and D.script_font(px) or D.font(px)
  lg.setFont(f)
  local r, g, b = D.rgb(c)
  glow = glow or 1
  -- (white on white glow read as blur on the cabinet: pale labels get a crisp dark edge and only a faint glow;
  -- coloured ones keep their neon, tighter)
  local pale = math.min(r, g, b) > 0.75
  if pale then
    lg.setColor(0, 0, 0, 0.55)
    for k = 0, 7 do
      local ang = k * math.pi / 4
      lg.printf(s, x + math.floor(math.cos(ang) * 2 + 0.5), y + math.floor(math.sin(ang) * 2 + 0.5), width or W, align or "center")
    end
  end
  if glow > 0 then
    lg.setBlendMode("add")
    for _, o in ipairs(pale and {{3, 0.04}} or {{2, 0.12}, {4, 0.06}}) do
      local d, a = o[1], o[2] * glow
      lg.setColor(r, g, b, a)
      for k = 0, 7 do
        local ang = k * math.pi / 4
        lg.printf(s, x + math.floor(math.cos(ang) * d + 0.5), y + math.floor(math.sin(ang) * d + 0.5), width or W, align or "center")
      end
    end
    lg.setBlendMode("alpha")
  end
  lg.setColor(r * 0.35 + 0.65, g * 0.35 + 0.65, b * 0.35 + 0.65, 1)   -- the hot white core of a neon tube
  lg.printf(s, x, y, width or W, align or "center")
end

function D.rrect(mode, x, y, w, h, r) lg.rectangle(mode, x, y, w, h, r, r, 16) end

function D.neon_img(s, px, c, glow)
  px = math.floor(px + 0.5)                -- (whole pixels: one picture per text and size, not one a frame)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1) .. (D.face == "script" and "|s" or "")
  local now = love.timer.getTime()
  local e = D.neon_cache[key]
  if e then e.used = now return e end
  -- At most 32 kept: the least recently used goes, but never one used in the last 0.1 s (this frame may still
  -- draw it, and drawing a released canvas is an error that ends Home).
  local n, old_k, old_t = 0, nil, math.huge
  for k, v in pairs(D.neon_cache) do
    n = n + 1
    if (v.used or 0) < old_t then old_k, old_t = k, v.used or 0 end
  end
  if n >= 32 and old_k and now - old_t > 0.1 then
    D.neon_cache[old_k].img:release()
    D.neon_cache[old_k] = nil
  end
  D.painted = D.painted + 1   -- (labels painted, for the hitch notes: main.lua's love.draw)
  local f = D.face == "script" and D.script_font(px) or D.font(px)
  local pad = 10
  local cw, ch = f:getWidth(s) + pad * 2, f:getHeight() + pad * 2
  lg.push("all")
  lg.setScissor()
  local cv = lg.newCanvas(math.max(1, cw), math.max(1, ch))
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  D.neon(s, pad, pad, px, c, glow, "left", cw)
  lg.pop()
  cv:setFilter("linear", "linear")
  e = {img = cv, w = cw, h = ch, pad = pad, used = now}
  D.neon_cache[key] = e
  return e
end
-- Draw a painted label: like neon(s, x, y, ...) with align over width; sc scales it about its top left.
function D.neon_draw(s, x, y, px, c, glow, align, width, alpha, sc)
  local e = D.neon_img(s, px, c, glow)
  sc = sc or 1
  local w = e.w * sc
  local dx = align == "left" and 0 or align == "right" and (width - w + e.pad * sc * 2) or ((width or W) - w) / 2 + e.pad * sc
  local a = alpha or 1
  lg.setBlendMode("alpha", "premultiplied")
  lg.setColor(a, a, a, a)
  -- (on whole pixels: a label drawn at a half pixel is resampled, and soft)
  lg.draw(e.img, math.floor(x + dx - e.pad * sc + 0.5), math.floor(y - e.pad * sc + 0.5), 0, sc, sc)
  lg.setBlendMode("alpha")
end

return D
