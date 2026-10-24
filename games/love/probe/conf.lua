-- The LÖVE probe: what the cabinet's GPU, sound, and deck can do under LÖVE. See games/love/LOVE.md.
function love.conf(t)
  t.identity = "yardprobe"
  t.version = "11.5"
  t.console = false
  t.window.title = "LOVE probe"
  t.window.fullscreen = true
  t.window.fullscreentype = "desktop"
  t.window.vsync = 1
  t.window.msaa = 0
  t.modules.physics = false
  t.modules.video = false
end
