-- yard on LÖVE. On the cabinet: full screen on the 1024x768 framebuffer, vsync on. YARD_HEADLESS=1 (tests,
-- the cloud): a tiny hidden-in-practice window just for the GL context; nothing is shown.
function love.conf(t)
  t.identity = "yard"
  t.version = "11.5"
  t.console = false
  local headless = os.getenv("YARD_HEADLESS") == "1"
  t.window.title = "The Yard"
  t.window.width = headless and 64 or 768
  t.window.height = headless and 64 or 1024
  t.window.fullscreen = not headless and os.getenv("YARD_WINDOWED") ~= "1"
  t.window.fullscreentype = "desktop"
  t.window.vsync = headless and 0 or 1
  t.modules.physics = false
  t.modules.video = false
  t.modules.thread = false
end
