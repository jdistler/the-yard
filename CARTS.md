# Carts: making games for The Yard

Every game on the cabinet except Orb is a **cart**: a folder of Lua that the `yard` runtime plays. The runtime is one C program. It holds the renderer, the synth, the deck, Lua 5.4, and a library of helpers, and it runs each cart in a sandbox. A cart cannot touch files, start programs, or hang the cabinet. If it errors, loops forever, or eats memory, the player sees a gentle "Oops" screen and goes back to the menu.

This file is the whole API. [GAMEDEV.md](GAMEDEV.md) covers the cabinet itself. [CONTROLS.md](CONTROLS.md) says which verb goes on which button, for which age.

## Contents

1. [Five minutes to a running cart](#1-five-minutes-to-a-running-cart)
2. [The work loop](#2-the-work-loop)
3. [What a cart is](#3-what-a-cart-is)
4. [API reference](#4-api-reference)
5. [The library](#5-the-library)
6. [The sandbox and its messages](#6-the-sandbox-and-its-messages)
7. [The quality bar](#7-the-quality-bar)
8. [Speed](#8-speed)
9. [Testing a cart](#9-testing-a-cart)
10. [Shipping](#10-shipping)
11. [How the pieces fit](#11-how-the-pieces-fit)

## 1. Five minutes to a running cart

```bash
cd games
./cart new bubbles --from arcade      # or blank, or story; --large for 384x512
./cart run bubbles                    # a window; saving a .lua file restarts the cart
./cart shots bubbles 10 300 --auto    # pictures in out/shots/bubbles/, to look at
./cart check bubbles                  # the gate: lint, 30 s of play, 30 s of mashing, cost
```

In the window, the arrow keys are the stick. `Z`, `X` and `C` are the three buttons: LOW, then TL and TR, top left and top right. Hold `1` and `2` to leave.

The three templates:

| Template | What you get | For |
| :--- | :--- | :--- |
| `blank` | A toon character you can walk, a pop on the button, a little song | Anything |
| `arcade` | A full score game: title, attract demo, rounds, hearts, "game over", best score saved | Walk-up games (Keep, Lamp) |
| `story` | Three friends, a pick ring, a caption band, hearts on a hug, visits saved | The little band (Tea): no fail state, any button is kind |

## 2. The work loop

1. **Read the brief.** [CONTROLS.md](CONTROLS.md) sets the band and its verbs. Write the design down as `DESIGN.md` in the cart folder, like [carts/tea/DESIGN.md](games/carts/tea/DESIGN.md).
2. **Make it** with `./cart new`, then build it up.
3. **Look at it.** Don't guess what a frame looks like. Run `./cart shots ID 10 120 600 --auto` and open the PNGs.
4. **Play it.** `python3 playtest.py start ID`, then `python3 playtest.py do "wait 60; tap LOW; look"`. It runs the cabinet's real picture path and four-way stick ([GAMEDEV.md](GAMEDEV.md) § 13).
5. **Gate it** with `./cart check ID`. It must say `all carts pass`.
6. **Test it.** Add your cart's checks to `games/test.py` (§ 9) and run `./stress.sh`.
7. **Ship it** with `./cart pack`, then `./cart deploy` (§ 10). Deploy only stages a plan. Writing the cabinet needs the user's written approval for the exact blocks.

## 3. What a cart is

```
games/carts/bubbles/
  info.lua       the label on the box: title, blurb, band, icon, what the menu shows from the save
  main.lua       the game
  pictures.lua   optional: any other .lua, loaded with import("pictures")
  DESIGN.md      the spec (stays in the tree; not shipped)
  *.png *.txt *.ttf   optional pictures, data, fonts
```

### info.lua

`info.lua` returns a table. The menu reads it in its own small state; the game reads it as the global `info`.

```lua
return {
  title = "Bubbles",            -- the menu row and the window title
  blurb = "pop the bubbles",    -- one short line under the title
  band = "ALL",                 -- ALL, 4+, 5+, 8+ (CONTROLS.md)
  tint = 0x8ec6ff,              -- the row's highlight color
  size = "small",               -- "small" 240x320, or "large" 384x512
  save = "bubbles",             -- the save file: bubbles.sav
  order = 60,                   -- place in the menu, low first (Keep 10 ... Chest 50)
  stat = function(s) return (s.best or 0) > 0 and ("best " .. s.best) or nil end,
  icon = function(x, y, lit, t) gfx.star(x, y, 8, t, lit and pal.sun or pal.dim) end,
}
```

* `stat(s)` gets the cart's save as a table, `{best = 12, ...}`. It returns a short line, or nil for "new".
* `icon(x, y, lit, t)` draws about 24 pixels centred on x, y. `lit` is true on the highlighted row. `t` is seconds.
* `system = true` marks the menu itself (`carts/yard`). `native = "orb"` marks a program that is not Lua (Orb).

### main.lua

```lua
function init() end      -- once, after main.lua has loaded
function update() end    -- 60 times a second: read the deck, change the world
function draw() end      -- after each update: paint the frame from scratch
function bot() end       -- optional: press the deck like a player (tests, attract demo)
function quit() end      -- optional: the player is leaving; save if you must
```

Declare your state with `local` at the top of `main.lua`. After `init()` the runtime is strict: a new global is an error, and so is a name nobody set (§ 6).

Write Lua 5.1 plus the library. The C runtime is Lua 5.4, but the GPU runtime ([games/love/README.md](games/love/README.md)) is LuaJIT, and a cart runs on both. So use `idiv(a, b)` for `a // b`, `atan2(y, x)` for `math.atan(y, x)`, and `unpack(t)` for `table.unpack(t)`, and no bit operators (`<<`, `&`, `~`...), `utf8`, `math.type`, `table.move`, or `string.pack`. `./cart check` flags each of these.

### The `game` table

| Field | Meaning |
| :--- | :--- |
| `game.frame` | Frames since the cart started, counting from 0 |
| `game.w`, `game.h` (also `W`, `H`) | The picture size: 240×320 or 384×512 |
| `game.id`, `game.title` | From the folder and the label |
| `game.fast` | The stock menu's speed setting is on (`-fast`). Make it a little harder |
| `game.autoplay` | `CAB_AUTOPLAY` is set: `bot()` drives from frame 0 (tests, reels) |
| `game.demo` | The attract demo is running (set by `arcade`) |
| `game.selftest` | `<ID>_SELFTEST` is set: do a short self-check and `game.quit()` |
| `game.scripted` | A test script is pressing the deck |
| `game.dev` | `./cart run`: hot reload is on |
| `game.quit()` | Leave, back to the menu |

## 4. API reference

**Colors** are numbers. `0xRRGGBB` is opaque. `0xAARRGGBB`, with an AA from 01 to FF, is see-through. Use `alpha(c, a)` to make one. **Coordinates** are picture pixels; fractions are fine and edges are anti-aliased. **Time** is frames.

### Colors and chance

| Call | Returns |
| :--- | :--- |
| `rgb(r, g, b)`, `rgba(r, g, b, a)`, `hex("#ffd257")` | A color |
| `alpha(c, a)` | c at alpha a (1–255) |
| `mix(a, b, t)` | Between two colors, t from 0 to 1 |
| `shade(c, k)` | Darker (k < 1) or lighter (k > 1) |
| `hsv(h, s, v)` | From hue (0–1), saturation, and value |
| `rnd()`, `rnd(n)`, `rnd(lo, hi)` | A float in [0, 1), [0, n), or [lo, hi) |
| `rndi(lo, hi)` | An integer, both ends included |

All chance comes from one seeded generator, `math.random` included. `CAB_SEED=N` replays a game exactly; under a test it is 1.

### gfx: drawing

| Call | Draws |
| :--- | :--- |
| `gfx.clear(c)` | The whole target |
| `gfx.rect(x, y, w, h, c)`, `gfx.frame(x, y, w, h, thick, c)` | A filled, or an outlined, rectangle |
| `gfx.rrect(x, y, w, h, r, c)` | A rounded rectangle |
| `gfx.vgrad(x, y, w, h, top, bottom)`, `gfx.hgrad(...)` | A gradient (dithered: no bands) |
| `gfx.circle(x, y, r, c)`, `gfx.ellipse(x, y, rx, ry, c)` | Filled |
| `gfx.ring(x, y, r, thick, c)` | An outline circle |
| `gfx.tri(x0, y0, x1, y1, x2, y2, c)`, `gfx.poly({x1, y1, ...}, c)` | Up to 64 points |
| `gfx.line(x0, y0, x1, y1, thick, c)` | Round-ended |
| `gfx.circle_o`, `gfx.ellipse_o`, `gfx.rrect_o` | The same shapes with an ink outline: `(..., fill, ink, thick)` |
| `gfx.glow(x, y, r, c)` | An additive soft light: halos, sparkles, lamps |
| `gfx.star(x, y, r, rot, c)`, `gfx.heart(x, y, size, c)` | |
| `gfx.pixel(x, y, c)` | |
| `gfx.dim(k)` | Darken everything drawn so far (k of the light kept) |
| `gfx.shake(px)`, `gfx.flash(c, frames)` | Screen shake and a full-screen flash, applied at present |
| `gfx.offset(dx, dy)`, `gfx.clip(x, y, w, h)`, `gfx.clip()` | Move later drawing; limit it to a box; lift the limit |
| `gfx.iris(x, y, r, c)` | Paint everything outside a circle: the wipe between scenes |

### Text

The built-in font is round and friendly (Fredoka SemiBold). `y` is the top of the line.

| Call | |
| :--- | :--- |
| `gfx.text(s, x, y, size, color, align, outline, font)` | Returns the width. `align` is "left", "center", or "right". An outline color adds a ring around each letter |
| `gfx.text(s, x, y, {size =, color =, align =, outline =, font =})` | The same, with named options |
| `gfx.textw(s, size, font)`, `gfx.lineh(size, font)` | Width, line height |
| `gfx.pixtext(s, x, y, scale, color, align, outline)` | The old 8×8 pixel font, for a retro look |
| `gfx.font(readtext("my.ttf"))` | Add a TrueType font from the cart; returns its number |

Sizes that read on the panel: 11 at the least on the small picture, 14 on the large one. Titles run from 28 to 46.

### Toon figures

The house style is outlined toon shapes. `toon(fn)` calls `fn` twice: once painting every shape grown in ink, once filling them. One outline then wraps the whole figure.

```lua
toon(function()
  toon.ellipse(x, y + 10, 20, 16, 0xffd0e0)   -- body
  toon.circle(x, y - 8, 14, 0xffd0e0)         -- head
  if toon.fill() then                          -- only on the fill pass: details without an outline
    gfx.circle(x - 4, y - 9, 1.5, pal.ink)
  end
end, 2.5, pal.ink)                             -- outline thickness and ink (defaults 2 and 0x3a2a44)
```

The shapes are `toon.circle`, `toon.ellipse`, `toon.rrect`, `toon.line`, `toon.tri`, and `toon.poly`. They take the same arguments as their `gfx` versions.

### Layers, pictures, pixel art

| Call | |
| :--- | :--- |
| `local l = gfx.layer(w, h)` | A see-through surface, up to 1024 on a side |
| `l:paint(fn [, color])` | Clear it (to see-through, or to a color), then draw `fn` into it. Coordinates are the layer's own |
| `gfx.blit(l, x, y)`, `gfx.blit_key(l, x, y)` | Copy it to the screen. `blit` is opaque and fastest. `blit_key` skips untouched pixels |
| `gfx.image("hero.png")` | A PNG from the cart folder |
| `gfx.art({"..kk..", ".kyyk."}, {k = 0x3a2a44, y = 0xffd257})` | Pixel art from strings; `.` and space are clear |
| `gfx.draw(img, x, y, {scale =, sx =, sy =, rot =, ox =, oy =, flip =, alpha =, tint =, quad = {x, y, w, h}})` | Draw an image, art, or layer. `ox`, `oy` (0 to 1) pick the anchor: 0.5, 0.5 is the middle. `quad` is one frame of a sprite sheet |
| `img:w()`, `img:h()` | |

Layers and images count toward the cart's memory (§ 6). Make them once, in `init()` or through `bake` (§ 5), not every frame.

### light: darkness and lamps

```lua
light.begin(0, 92, W, 214, 0.07)  -- a box at an ambient level (0 dark, 1 lit)
light.add(px, py, 60, 1.15)        -- round lights: x, y, radius, strength
light.fill(0.3)                    -- raise the whole box (a sunrise)
light.apply(0x00000e)              -- darken the box by its light; shadows lean to this tint
```

Draw the scene, light it, then draw what should glow on top. Lamp's meadow is this.

### input: the deck

Buttons are named `"up" "down" "left" "right"` (the stick), `"low" "tl" "tr"` (the three play buttons), and `"1p" "2p"`.

| Call | |
| :--- | :--- |
| `input.down(b)`, `input.pressed(b)`, `input.released(b)` | Held now; went down this frame; went up this frame |
| `input.action()`, `input.action_down()` | Any of LOW, TL, or TR, pressed or held: **the verb**, as CONTROLS.md asks |
| `input.dir()` | `dx, dy`, each −1, 0, or 1 |
| `input.any()` | A real hand is on the deck (not the bot) |
| `input.quitting()` | How far the 1P+2P hold has come, 0 to 1 (wave goodbye) |
| `input.bot(b [, down])`, `input.bot_clear()` | For `bot()`: hold a button from the next frame |

1P and 2P held together for a second always leave. The runtime does that, and draws a meter. Don't give 1P or 2P a game verb.

### sfx and music

Waves are `"sine" "tri" "square" "saw" "noise"`. Notes are MIDI numbers (60 is middle C).

| Call | |
| :--- | :--- |
| `sfx.note(wave, midi, dur, vol)` | One note |
| `sfx.tone(wave, hz, dur, vol)`, `sfx.slide(wave, hz0, hz1, dur, vol)` | By frequency; a pitch slide |
| `sfx.arp(wave, {72, 76, 79}, step, vol)` | Notes one after another, up to 8 |
| `sfx.noise(dur, vol, hz)` | A burst: splashes, whooshes |
| `sfx.play{wave =, hz =, hz_end =, dur =, vol =, attack =, release =, duty =, vib_hz =, vib_depth =, pan =}` | Everything |
| `sfx.master(v)` | Overall level. Games set about 0.2 to 0.4 |
| `sfx.limit(peak)` | Hard cap on output (of 32767). Tea and Chest use 3000 |

```lua
music.play{bpm = 96, steps = 2,              -- steps per beat
  {"C5 . E5 . G5 - - . ", wave = "tri", vol = 0.08, release = 0.2, attack = 0.01, pan = -0.2},
  {"C3 - - - G2 - - - ", wave = "sine", vol = 0.12},
  {"K . H . S . H . ", wave = "noise", vol = 0.05}}
```

A track is a string of steps. `C5`, `F#4`, and `Bb3` are notes. `.` is a rest, `-` holds the last note, and `K S H C` are kick, snare, hat, and clap. A song has up to 6 tracks of up to 128 steps, and loops. `music.stop()` stops it. `music.volume(v)` fades the level, `music.tempo(k)` changes the speed, and `music.step()` returns the current step, to animate in time.

### particles

| Call | |
| :--- | :--- |
| `particles.burst(x, y, n, speed, life, size, color, kind)` | n flung in all directions |
| `particles.spawn(x, y, vx, vy, life, size, color, kind, grav, drag, spin)` | One |
| `particles.text(x, y, color, "+3")` | A floating label |
| `particles.draw()` | Draw them, where you call it in `draw()` |
| `particles.clear()`, `particles.count()` | |

`kind` is `"dot" "glow" "star" "heart" "square" "ring"`. Particles move by themselves each frame.

### save

`<info.save>.sav` sits beside the games on the cabinet. Its lines are `key value`, and the value is a whole number or one word.

| Call | |
| :--- | :--- |
| `save.get(key, default)` | The value. When the default is a number and the file has a word, you get the default: a broken save opens as new |
| `save.set(key, value)` | A whole number (±1e9), one word (letters, digits, `_ - .`), or nil to drop the key |
| `save.write()` | Write the file: temp file, fsync, rename. Returns true on success |
| `save.all()` | A copy of every key |

Write at moments that matter (a record, a gift, the end of a round), not every frame. Clamp what you load: `clamp(save.get("gems", 0), 0, 100000)`.

### card, files, modules

| Call | |
| :--- | :--- |
| `import("pictures")` | Run `pictures.lua` from the cart once; returns what it returns |
| `readtext("levels.txt")` | A data file from the cart, as a string |
| `card.here()`, `card.read(name)`, `card.write(name, text)` | The microSD or USB card, when the cabinet has one (GAMEDEV.md § 9). One-word names, at most 4096 bytes |
| `log(...)` (also `print`) | One line to the log. Tests read these |

## 5. The library

These are written in Lua, in `games/engine/lib/`, and built into the runtime. They are there before `main.lua` runs.

### Helpers

* `clamp(v, lo, hi)`, `lerp(a, b, t)`, `sign(v)`, `round(v)`, `dist(x1, y1, x2, y2)`.
* `idiv(a, b)` is `floor(a / b)`. `atan2(y, x)` is the angle to a point. `unpack(t)` spreads a list. All three work on Lua 5.1 and 5.4 alike.
* `approach(v, target, rate)` moves a fraction of the way each frame: smooth, and it never overshoots. `step_to(v, target, step)` moves by at most `step`.
* `wave(period, lo, hi)` swings with the frame. `blink(period, on)` is true part of the time, for prompts.
* `choose(list)`, `shuffle(list)`, `copy(t)`.
* `sweep(list, keep)` removes in place the items where `keep(item)` is false.
* `fmt(...)` is `string.format`. `plural(3, "night")` is "3 nights".
* `sin cos abs floor ceil sqrt min max`, plus `tau` (2π).
* `ease.linear in_quad out_quad in_out out_cubic out_back out_elastic out_bounce`, each from t in [0, 1].

### Time

```lua
after(30, function() snd.ok() end)                 -- once, in 30 frames
every(60, function() spawn() end)                  -- every 60 frames (return false to stop)
tween(cat, 20, {y = 100}, ease.out_back)           -- slide fields to new values
task(function()                                     -- a little script that can wait
  say("Ready?") wait(60) say("Go!") wait_until(function() return done end)
end)
cancel(job); cancel_all()
```

These run before `update()` each frame.

### Pictures

| Call | |
| :--- | :--- |
| `backdrop(key, paint)` | A whole-screen picture painted once and copied every frame. For anything that never moves. Change the key to repaint |
| `bake(key, w, h, paint)`, `unbake(key)` | Any layer painted once and kept under a key |
| `stamp(key, w, h, ox, oy, x, y, paint)` | A figure painted once and drawn at x, y with its anchor at ox, oy. Name the pose in the key (`"cat:happy:3"`) |
| `shadow(x, y, w)` | A soft oval under something standing |
| `face.eyes(x, y, gap, s, look_x, look_y, mood)` | `mood` nil, "happy", or "blink" |
| `face.blush`, `face.smile`, `face.blinking(seed)` | |
| `hearts(n, max, x, y, size)`, `meter(x, y, w, h, k, color)` | |
| `bubble(x, y, r, tail_x, tail_y)`, `soap(x, y, r, color)` | A speech bubble; a soap bubble |
| `say_text(s, x, y, size, color, align, outline)` | Text in the house look |
| `fx.pop(x, y, color)`, `fx.dust`, `fx.hearts`, `fx.label(x, y, "+1")`, `fx.confetti(n)` | |

`pal` is the house palette: `ink night cream white gold sun rose pink blush red orange mint leaf grass sky blue cyan lilac purple wood brown grey dim`. Start from these.

### Sound

`snd.note(i)` plays a rising five-note scale; pass a running count. The rest are `snd.pick(i)`, `snd.ok()`, `snd.win()`, `snd.fanfare()`, `snd.sad()`, `snd.bump()`, `snd.oops()`, `snd.tick(i)`, `snd.whoosh()`, `snd.sparkle()`, `snd.zap()`, `snd.chime()`, `snd.start()`, `snd.bye()`, and `snd.purr()`.

### ui

* `ui.band(line)`: the cream caption strip along the bottom. A grown-up reads it there. Each new line is logged as `<cart> say <line>`, which is how tests follow a story.
* `ui.prompt(text, y)`: a blinking prompt.
* `ui.panel(x, y, w, h)`, `ui.title(text, y, size)`, `ui.quit_hint()`.

### arcade: the score-game shell

```lua
function init() arcade.setup({key = "best", start = new_round}) end
function update() if arcade.update() == "play" then play() end end
-- in play(): arcade.score(points) as points come in (true = a new best just now), arcade.over() at the end
function draw()
  ...
  if arcade.state == "title" then arcade.draw_title("Bubbles", {{"pop them all"}}) end
  if arcade.state == "over" then arcade.draw_over("all popped", score) end
  arcade.draw_demo()
end
```

It does the title, the round, and the "game over" card ("press to play again" after 50 frames). It saves the best score, but never from a demo. After ten idle seconds on the title it runs the attract demo through your `bot()`. A real press ends the demo. It logs `<cart> demo` and `<cart> demo off`.

## 6. The sandbox and its messages

A cart sees only what this file lists. There is no `io`, `os`, `require`, `load`, `dofile`, or `debug`, and no bytecode. A path can't climb out of the cart folder.

| Guard | Limit | What the player sees | The log line |
| :--- | :--- | :--- | :--- |
| Errors | Any Lua error | "Oops! This game tripped." for 5 s or a press, then the menu | `<cart> error: main.lua:12: ...` with a traceback |
| Stuck loop | 150 M VM steps a frame (400 M in `init`) | The same | `update() ran far too long: is there a loop that never ends?` |
| Memory | 32 MB for Lua and pictures together (`YARD_MEM_MB`) | The same | `update() used up the game's memory (32 MB)...` |
| Unknown name | Reading a global nobody set | The same | `unknown name 'scroe': a typo, or something never set` |
| Leaked global | A new global after `init()` | The same | `new global 'count' made while the game runs: add 'local', or set it at the top of main.lua` |

The menu runs each cart as its own process. A cart that falls over takes nothing with it, and the menu says "that game tripped". Under `./cart run`, the Oops screen waits for you to save a fix, then restarts the cart.

On the cabinet the menu itself runs under a small supervisor (2026-10-25): when a game is opened, the menu's process exits, the game runs, and a fresh menu starts after it. That gives back the 6 MB the graphics driver leaks each time a process reopens the screen, and every byte the menu held. The fresh menu learns how the game went from `yard.returned()` (the game's id and `ok`, `missing`, or `stumbled`), so the "tripped" note still shows. The supervisor also keeps the stock menu safe from the kernel's out-of-memory killer and starts it again if it is gone when The Yard quits. `YARD_SUPERVISE=1` turns it on for a PC test; `test.py system` checks it with a stand-in stock menu.

## 7. The quality bar

These are the same rules [GAMEDEV.md](GAMEDEV.md) and [CONTROLS.md](CONTROLS.md) set, as a checklist. `./cart check` can't judge most of them, so look at your shots and play.

**Look**
* Every character is a toon figure with an ink outline, eyes that blink, and a little blush. Nothing is a bare rectangle.
* Every background is a `backdrop` with depth: a gradient sky, two layers of hills or walls, ground detail.
* Every screen has motion even when nobody plays: bobbing, twinkling, swaying.
* Every press answers on the same frame with a sound, particles, and a squash or a glow.
* Text is the round font with an outline, 11 px or bigger on the small picture.
* Colors come from `pal`, plus the cart's own few. Warm, soft, and no pure black.

**Sound**
* There is a song (`music.play`), quiet under the effects.
* Every event has its own sound, short and soft. Use `sfx.limit` if a band of children will hear it.

**Feel**
* The verb is on all three right-hand buttons (`input.action()`).
* The stick does something useful in every direction for the little band.
* A held button doesn't repeat a press it already made. Wait for a release when a round starts.
* Nothing punishes a four-year-old. Walk-up games can end a round, but never in the first 20 seconds.
* After ten idle seconds the title plays itself, and a press hands it back.

**Robust**
* `bot()` plays the whole game: it reaches every phase and the payoff.
* Saves are clamped on load and written at moments, not every frame.
* `./cart check` passes, and your checks are in `test.py`.

## 8. Speed

The cabinet is a 1 GHz Cortex-A7 with a frame every 16.7 ms. All drawing is in C. Lua decides what to draw.

* **The budget.** `./cart perf ID` measures PC instructions per frame. Tea, the busiest cart, is about 7 M. Treat 9 M as the ceiling until a cabinet measurement says otherwise; the estimate is in STATUS.md.
* **Paint once.** Anything that doesn't move goes in a `backdrop`. A figure with a few poses is a `stamp`, with the pose in the key. Tea's unicorn is eight wing steps, baked once each.
* **Big fills cost.** A full-screen glow or gradient every frame is the most expensive thing you can draw. `light` costs about one pass over its box.
* **Lua is for logic.** Hundreds of draw calls a frame are fine. Tens of thousands of `gfx.pixel` calls are not; use a layer.
* **Make tables in `init`, not every frame.** Particles are free: they live in C.

## 9. Testing a cart

* **`bot()`.** Write it first. It is the test player, the attract demo, and the reel. It presses through `input.bot`, the same path as the deck.
* **Log lines.** Log the moments a test should see: `log("bubbles pop " .. score)`. `ui.band` logs its lines for you.
* **The self-test.** `game.selftest` (from `BUBBLES_SELFTEST=1`): play a little, save, check the save, `game.quit()`.
* **`test.py`.** Add the cart to `play()` (a session to its payoff), and to `stress()` if it has edges: broken saves, held buttons, records. Scripts press exact buttons on exact frames:

```
title=Bubbles
10 down LOW
11 up LOW
300 shot out/play/bubbles-300.bmp
301 quit
```

* **On the cabinet, the log is a file.** The runtime appends to `/data/Games/yard.log` (moved to `yard.log.1` past 256 KB, flushed every line): what each start found (screen mode, renderer, joystick and its button count, audio, free memory), each cart opened, frame times every 300 frames, and every `log()` line. A play test leaves it behind, and FIELD_TASKS.md task 6 reads it back from a dump. `YARD_LOG=FILE` does the same on the PC.
* **`./cart check`** lints (including the Lua 5.1 rules in § 3), runs your bot for 30 seconds, then a random child mashing every button for 30 seconds, then takes pictures and measures the cost. A cart the menu opens during a check stops after the same number of frames.
* **On the GPU runtime.** `./cart love ID` plays it on LÖVE, and `python3 test.py love` checks that the bot's game logs the same lines and writes the same save on both runtimes. Add a new cart to `LOVE_CARTS` in `test.py`.

## 10. Shipping

```bash
./cart pack                                   # out/yard.pak, every cart, checksummed, padded to 4 MB
./cart deploy --raw RAW --out ~/partycade-dumps/<date>_yard         # every later update
./cart deploy --raw RAW --out ~/partycade-dumps/<date>_yard --first # the first time only
```

* **On the cabinet** there are three files in `/data/Games`: `yard` (the runtime, padded to 2 MB), `orb` (padded to 1 MB), and `yard.pak` (every cart, padded to 4 MB). Tile 10 runs `yard`.
* **Updates only rewrite blocks the files already own.** Because each file has a fixed size, an update is `data_patch.py --overwrite`: the new bytes go into the disk blocks the file already has. No block is allocated, so only flash pages that have been written before change. That is the case SFTL's in-place patch handles.
* **`--first` installs the three files.** It removes the old C game binaries first, so the new files can reuse their freed blocks, which have been written before. If a page still lands where SFTL never wrote, the patch refuses and nothing is staged.
* **Deploy never writes the cabinet.** It builds for the cabinet, packs, pads, patches a copy of the raw dump, and checks the round trip. Then it writes `PLAN.md` with the block list and the restore command. The write itself follows [RUNBOOK.md](RUNBOOK.md): a `diff` that says none in the same session, then the user's written approval of exactly those blocks.
* **`--reinstall`** writes `yard`, `orb`, and `yard.pak` whole. Deploys before 2026-10-25 left their zero blocks unallocated, so an in-place update refuses them ("has holes"); one `--reinstall` fixes that for good.
* **`--with-net --ssh-key KEY.pub`** also stages the network helper (`games/net/yardnet.sh`): a USB-Ethernet adapter on USB-A gets an address, and that key logs in as root over SSH. Then a later update can be an `scp` into `/data/Games` instead of a flash write (FIELD_TASKS.md R5).
* **`--with-sysprobe`** also stages the read-only "System probe" row (`games/sysprobe/sysprobe.sh`), which records what Linux sees about flash, USB, the card slot, and drivers.
* **`--with-love-probe`** also stages the GPU runtime as `love.tar.gz` with its two launchers and menu rows ("LOVE probe", "GPU yard"). [FIELD_TASKS.md](FIELD_TASKS.md) task 4 is the first time.
* **The pack is safe to read.** The runtime checks every file's crc32 when it opens the pack. A damaged cart is left out of the menu and the others still load.

## 11. How the pieces fit

```
games/
  cart                 the CLI: new, list, run, check, shots, perf, pack, deploy, love, love-pack
  carts/<id>/          the games, one folder each (yard is the menu, orb is a label for the native game)
  templates/           blank, arcade, story
  engine/
    runtime.c          the host: sandbox, carts and the pack, menu launching, the Oops screen, hot reload
    api.c              every function in § 4
    lib/*.lua          the library in § 5, embedded by tools/bin2c.py
    gfx.c + *.inc      the software renderer: shapes, toon, text (stb_truetype), images (stb_image), light
    sfx.c              the synth and sequencer
    cab.c, cab_gl.c    the cabinet: deck, rotation, scripts, control mode, audio, saves, card
    lua/               Lua 5.4.7, unchanged
    vendor/            stb_image.h, stb_truetype.h (public domain)
    fonts/             Fredoka SemiBold (SIL OFL 1.1)
  native/orb, native/probe   the two C programs that are not carts
  sysprobe/            the System probe: a read-only shell script and its menu row (FIELD_TASKS.md)
  love/                the GPU runtime: LÖVE 11.5 built from source, the same carts on OpenGL ES (love/README.md)
  test.py, playtest.py, feel.py   checks, the frame-at-a-time player, the reel
```

`make` builds `out/pc/yard`, `orb`, and `probe`, and links `out/pc/keep` and the rest to `yard`, so `out/pc/tea` runs the Tea cart. The runtime finds carts in this order: `YARD_CARTS`, then `yard.d/carts` beside the program, then `yard.pak` beside it (or `YARD_PAK`), then `games/carts` in the tree, then `yard/carts` on a card. The first cart with a given id wins.

Change the engine only with a reason a cart can't work around. Then add a binding in `api.c`, a line in this file, and a check in `test.py`. Run `python3 tools/bin2c.py` after editing `engine/lib/`; `make` does it too, and `test.py system` fails if the embedded copy is stale.
