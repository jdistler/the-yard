-- Three initials for a new arcade record, when the board itself didn't ask for any (Frogger, Bomb Jack,
-- Elevator Action, a 1942 score below its name-entry ranks...). Shown by Home right after the game, arcade
-- style: the stick changes the letter, the lower button takes it, top-left goes back. The initials are kept
-- in the card's library/saves/arcade/names.tsv (shelf.save_name) and shown wherever the board's table is.
local I = {}
local lg = love.graphics

local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.!?-"
local ctx, W, H
local cur, pos, picks, t, done_t

function I.load(c)
  ctx = c
  W, H = c.W, c.H
end

-- it: the arcade card; score: the new record.
function I.start(it, score)
  cur = {it = it, score = score}
  pos, picks, t, done_t = 1, {1, 1, 1}, 0, nil
end

function I.active() return cur ~= nil end

local function letter(i) return LETTERS:sub(picks[i], picks[i]) end

-- A press. Returns the initials when the third is taken.
function I.handle(name)
  if not cur or done_t then return end
  if name == "up" or name == "right" then
    picks[pos] = picks[pos] % #LETTERS + 1
    ctx.play("move")
  elseif name == "down" or name == "left" then
    picks[pos] = (picks[pos] - 2) % #LETTERS + 1
    ctx.play("move")
  elseif name == "low" or name == "1p" then
    ctx.play("toggle")
    if pos < 3 then
      pos = pos + 1
      picks[pos] = picks[pos - 1]
    else
      done_t = 0
      local got = letter(1) .. letter(2) .. letter(3)
      if ctx.done then ctx.done(cur.it, cur.score, got) end
      return got
    end
  elseif name == "tl" and pos > 1 then
    pos = pos - 1
    ctx.play("back")
  end
end

-- Held stick: letters repeat after 0.35 s.
local hold = {}
function I.update(dt)
  if not cur then return end
  t = t + dt
  for _, d in ipairs({"up", "down", "left", "right"}) do
    if ctx.down[d] then
      local h = hold[d] or {held = 0, next = 0.35}
      h.held = h.held + dt
      if h.held >= h.next then
        h.next = h.held + 0.11
        I.handle(d)
      end
      hold[d] = h
    else
      hold[d] = nil
    end
  end
  if done_t then
    done_t = done_t + dt
    if done_t > 0.6 then cur = nil return "done" end
  end
end

function I.draw()
  if not cur then return end
  local r, g, b = ctx.rgb(cur.it.tint)
  lg.setColor(0.02, 0.0, 0.06, 0.96)
  lg.rectangle("fill", 0, 0, W, H)
  ctx.fx.glow(W / 2, 470, 360, 260, r, g, b, 0.3)
  ctx.neon_draw("NEW HIGH SCORE!", 0, 230, 54, 0xffd23f, 1, "center", W, 0.9 + 0.1 * math.sin(t * 3), 1)
  lg.setFont(ctx.font(30))
  lg.setColor(0.9, 0.88, 1, 1)
  lg.printf(cur.it.title, 0, 320, W, "center")
  lg.setFont(ctx.font(64))
  lg.setColor(1, 1, 1, 1)
  lg.printf(ctx.commas(cur.score), 0, 370, W, "center")
  lg.setFont(ctx.font(28))
  lg.setColor(1, 0.85, 0.3, 1)
  lg.printf("YOUR INITIALS", 0, 480, W, "center")
  for i = 1, 3 do
    local x = W / 2 + (i - 2) * 130
    local on = i == pos and not done_t
    lg.setColor(r, g, b, on and (0.6 + 0.4 * math.sin(t * 8)) or 0.5)
    lg.setLineWidth(on and 5 or 2)
    ctx.rrect("line", x - 52, 540, 104, 130, 18)
    if i <= pos then
      ctx.neon_draw(letter(i), x - 52, 556, 64, cur.it.tint, 1.2, "center", 104, 1, 1.4)
    end
  end
  lg.setFont(ctx.font(22))
  lg.setColor(0.86, 0.84, 0.98, 0.9)
  lg.printf("STICK  change letter     LOWER BUTTON  next     TOP-LEFT  back", 0, 720, W, "center")
end

return I
