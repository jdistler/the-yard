-- Home's sounds: a tiny chiptune synth (square and triangle voices, a short attack and a decay).
-- Samples go straight into the SoundData through the FFI, with LuaJIT's compiler on: the old per-sample
-- setSample loop took 1.8 s of Home's start on the cabinet (2026-10-27). The effects are made at load (a few
-- ms). The music is music.lua's (its own synth and thread).
local ffi = require("ffi")
if jit then jit.on() end

local S = {}
local RATE = 22050
local function note_hz(n) return 440 * 2 ^ ((n - 69) / 12) end

-- notes: {{midi, start_s, len_s, wave?, vol?}, ...}
local function render(notes, dur, wave, vol)
  local n = math.floor(dur * RATE)
  local acc = ffi.new("float[?]", n)
  for _, nt in ipairs(notes) do
    local per = RATE / note_hz(nt[1])
    local s0, len = math.floor(nt[2] * RATE), math.floor(nt[3] * RATE)
    local tri = (nt[4] or wave) == "tri"
    local noise = (nt[4] or wave) == "noise"
    local v0 = nt[5] or vol
    local seed = 12345
    for i = 0, len - 1 do
      local k = s0 + i
      if k >= n then break end
      local ph = (i % per) / per
      local v
      if noise then
        seed = (seed * 1103515245 + 12345) % 2147483648
        v = seed / 1073741824 - 1
      elseif tri then
        v = ph < 0.5 and (ph * 4 - 1) or (3 - ph * 4)
      else
        v = ph < 0.5 and 1 or -1
      end
      local env = (i < 200 and i / 200 or 1) * (1 - i / len) ^ 1.6
      acc[k] = acc[k] + v * env * v0
    end
  end
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local out = ffi.cast("int16_t*", sd:getFFIPointer())
  for i = 0, n - 1 do
    local v = acc[i]
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    out[i] = v * 32767
  end
  return sd
end

local sfx = {}
S.sfx = sfx

function S.load()
  local function src(notes, dur, wave, vol) return love.audio.newSource(render(notes, dur, wave, vol), "static") end
  sfx.move = src({{84, 0, 0.05}}, 0.06, "sq", 0.10)
  sfx.section = src({{79, 0, 0.05}, {86, 0.05, 0.07}}, 0.13, "sq", 0.11)
  sfx.toggle = src({{76, 0, 0.04}, {72, 0.04, 0.06}}, 0.11, "sq", 0.11)
  -- Launch: a coin drops (two bright blips), then a rising run.
  sfx.launch = src({{95, 0, 0.05}, {100, 0.05, 0.12}, {72, 0.16, 0.07}, {76, 0.22, 0.07}, {79, 0.28, 0.07},
                    {84, 0.34, 0.32}, {60, 0.34, 0.32, "tri", 0.2}}, 0.7, "sq", 0.12)
  -- Each letter of the marquee lighting: a click with a little buzz.
  sfx.tick = src({{50, 0, 0.03, "noise", 0.10}, {88, 0, 0.03, "sq", 0.05}}, 0.04, "sq", 0.1)
  -- The intro sting: an arpeggio up to a held chord.
  sfx.intro = src({{60, 0, 0.12}, {64, 0.1, 0.12}, {67, 0.2, 0.12}, {72, 0.3, 0.12}, {76, 0.4, 0.12},
                   {79, 0.5, 0.9}, {72, 0.5, 0.9, "tri", 0.18}, {48, 0.5, 0.9, "tri", 0.22}}, 1.5, "sq", 0.10)
  -- Volume: one soft blip (the meter shows the level).
  sfx.volume = src({{81, 0, 0.05, "tri", 0.25}}, 0.06, "sq", 0.1)
  -- Waking from the night scene: a yawn up.
  sfx.wake = src({{67, 0, 0.1, "tri", 0.2}, {72, 0.08, 0.1, "tri", 0.2}, {79, 0.16, 0.25, "tri", 0.2}}, 0.45, "sq", 0.1)
  -- Back in Home after a game: two soft notes, up.
  sfx.back = src({{79, 0, 0.12, "tri", 0.22}, {84, 0.1, 0.25, "tri", 0.22}}, 0.4, "sq", 0.1)
  -- A new high score: a little fanfare.
  sfx.fanfare = src({{72, 0, 0.1}, {72, 0.12, 0.1}, {72, 0.24, 0.1}, {77, 0.36, 0.5}, {65, 0.36, 0.5, "tri", 0.2},
                     {81, 0.9, 0.12}, {84, 1.02, 0.6}, {69, 1.02, 0.6, "tri", 0.2}}, 1.7, "sq", 0.11)
  -- The night scene's power pellet.
  sfx.pellet = src({{60, 0, 0.08}, {67, 0.06, 0.08}, {72, 0.12, 0.08}, {79, 0.18, 0.16}}, 0.36, "sq", 0.05)
end

function S.play(name)
  local s = sfx[name]
  if s then s:stop() s:play() end
end

S.render = render
return S
