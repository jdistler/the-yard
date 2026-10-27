-- Pictures for /dev/fb0: what the cabinet shows whenever no program holds the display (between Home and a
-- game, at power-on before Home). The kernel console left a white "LOADING..." there; Home puts its own.
--
-- The framebuffer is 1024x768, XRGB8888 (bytes B, G, R, X), and the panel shows it turned: the upright
-- picture's (u, v) is the framebuffer's (x = v, y = 767 - u). Measured on the cabinet (2026-10-27): drawing,
-- turning, reading back and writing a picture takes ~150 ms; writing /dev/fb0 alone 20 ms.
local lg = love.graphics
local P = {}
local W, H = 768, 1024

local swizzle
local function shader()
  swizzle = swizzle or lg.newShader([[
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv) * c; return vec4(p.b, p.g, p.r, 1.0); }]])
  return swizzle
end

-- draw(): draws the upright 768x1024 picture. Returns the framebuffer's bytes (3 MB).
function P.render(draw)
  local up = lg.newCanvas(W, H)
  local fb = lg.newCanvas(H, W)
  lg.push("all")
  lg.origin()
  lg.setScissor()
  lg.setCanvas(up)
  lg.clear(0, 0, 0, 1)
  draw()
  lg.setCanvas(fb)
  lg.origin()
  lg.clear(0, 0, 0, 1)
  lg.setBlendMode("replace")
  lg.setShader(shader())
  lg.setColor(1, 1, 1, 1)
  lg.draw(up, 0, W, -math.pi / 2)
  lg.setShader()
  lg.pop()
  local d = fb:newImageData()
  local s = d:getString()
  d:release()
  up:release()
  fb:release()
  return s
end

-- Where pictures go: /dev/fb0, or HOME_FB (tests: a file).
P.device = os.getenv("HOME_FB") or "/dev/fb0"

function P.show(bytes)
  local f = io.open(P.device, "wb")
  if not f then return false end
  f:write(bytes)
  f:close()
  return true
end

function P.save(bytes, path, gzip)
  local data = gzip and love.data.compress("string", "gzip", bytes, 6) or bytes
  local tmp = path .. ".new"
  local f = io.open(tmp, "wb")
  if not f then return false end
  local ok = f:write(data)
  f:close()
  if not ok then os.remove(tmp) return false end
  return os.rename(tmp, path)
end

return P
