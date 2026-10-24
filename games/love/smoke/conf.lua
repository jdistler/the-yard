-- No window, no sound card: this runs under qemu-arm on a PC (games/love/smoke.sh).
function love.conf(t)
  t.window = nil
  t.modules.window, t.modules.graphics, t.modules.audio, t.modules.joystick = false, false, false, false
end
