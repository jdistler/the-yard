-- The panel shows the 1024x768 framebuffer turned 90 degrees clockwise. Games draw upright into a 768x1024
-- canvas; this turns it so the top of the game lands on the left of the framebuffer, as cab_present does.
-- Off (PROBE_UPRIGHT=1, or a window taller than wide) the canvas is shown upright and letterboxed.
local R = {}
R.w, R.h = 768, 1024

function R.init()
  R.canvas = love.graphics.newCanvas(R.w, R.h)
  local ww, wh = love.graphics.getDimensions()
  R.turn = ww > wh and os.getenv("PROBE_UPRIGHT") ~= "1"
end

function R.begin()
  love.graphics.setCanvas(R.canvas)
  love.graphics.origin()
end

function R.finish()
  love.graphics.setCanvas()
  love.graphics.origin()
  love.graphics.clear(0, 0, 0)
  love.graphics.setColor(1, 1, 1)
  local ww, wh = love.graphics.getDimensions()
  if R.turn then
    local s = math.min(ww / R.h, wh / R.w)
    -- Rotate -90 degrees about the screen middle: the canvas top goes to the screen's left.
    love.graphics.draw(R.canvas, ww / 2, wh / 2, -math.pi / 2, s, s, R.w / 2, R.h / 2)
  else
    local s = math.min(ww / R.w, wh / R.h)
    love.graphics.draw(R.canvas, ww / 2, wh / 2, 0, s, s, R.w / 2, R.h / 2)
  end
end

return R
