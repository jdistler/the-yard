-- Partycade Home: the cabinet's front end (games/love/home). Full screen on the 1024x768 framebuffer, vsync
-- on; HOME_HEADLESS=1 (tests): a tiny window just for the GL context.
function love.conf(t)
  t.identity = "partycade-home"
  t.version = "11.5"
  t.console = false
  local headless = os.getenv("HOME_HEADLESS") == "1"
  t.window.title = "Partycade Home"
  t.window.width = headless and 64 or 1024
  t.window.height = headless and 64 or 768
  t.window.fullscreen = not headless and os.getenv("HOME_WINDOWED") ~= "1"
  t.window.fullscreentype = "desktop"
  t.window.vsync = headless and 0 or 1
  t.modules.physics = false
  t.modules.video = false
  t.modules.thread = true     -- worker.lua makes the music and decodes the logos off the frame
end
