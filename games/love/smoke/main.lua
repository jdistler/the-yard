-- The LÖVE bundle's libraries, without a screen: Lua, C++ exceptions, images, sound, fonts, zlib.
-- Each line is "ok" or "FAIL"; the last line is "smoke ok" only if every one passed.
local bad = 0
local function check(what, f)
  local ok, res = pcall(f)
  if not ok or res == false then bad = bad + 1 end
  print(((ok and res ~= false) and "ok   " or "FAIL ") .. what .. (ok and res ~= nil and res ~= true and res ~= false and (": " .. tostring(res)) or (not ok and (": " .. tostring(res)) or "")))
end

function love.load()
  check("version", function() return table.concat({love.getVersion()}, ".", 1, 3) .. ", " .. jit.version .. " " .. jit.arch end)
  check("lua loop", function()
    local t0, s = love.timer.getTime(), 0
    for i = 1, 3e6 do s = s + math.sin(i) end
    return ("3M sines in %.0f ms"):format((love.timer.getTime() - t0) * 1000)
  end)
  check("a C++ exception comes back as a Lua error", function()
    local ok, err = pcall(love.image.newImageData, "no-such-file.png")
    return not ok and err:find("no%-such%-file") ~= nil
  end)
  check("image data", function() return love.image.newImageData(64, 64):getWidth() == 64 end)
  check("png encode", function() return love.image.newImageData(8, 8):encode("png"):getSize() > 0 end)
  check("sound data", function() return love.sound.newSoundData(100, 22050, 16, 1):getSampleCount() == 100 end)
  check("freetype", function() return love.font.newRasterizer(20):getHeight() > 0 end)
  check("zlib", function()
    local z = love.data.compress("string", "zlib", ("yard "):rep(100))
    return love.data.decompress("string", "zlib", z) == ("yard "):rep(100)
  end)
  check("bit ops", function() return bit.bxor(0x9e3779b9, bit.lshift(1, 13)) ~= 0 end)
  print(bad == 0 and "smoke ok" or ("smoke FAILED: " .. bad))
  love.event.quit(bad == 0 and 0 or 1)
end
