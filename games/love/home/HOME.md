# Home: how it is put together

Partycade Home is the cabinet's front end (LÖVE/LuaJIT, `home.love`, started by `homeloop.sh`). Until 2026-11-24
it was one 2,538-line `main.lua` at LuaJIT's limits; HOME_REFACTOR.md (repo root) is how it was taken apart, and
the gates it built are how to change it safely.

## The modules

| File | What it is |
| :--- | :--- |
| `main.lua` | LÖVE's callbacks (`love.load`, `love.update`, `love.draw`, `love.quit`), the head (modules, W and H, `log`), `ST`, and the wiring: it requires the modules below in order and hands each the names it uses |
| `catalog.lua` | The cards: classics, arcade boards, the Yard (from `cartinfo.lua`), TV, shows, extras; the sections; the stock settings (Speed/Smoothing); the classics' high scores |
| `cards.lua` | Arcade scores on the cards, the FAVORITES cards (`favs.lua`), the brand helpers (`ST.draw`, `ST.img`) |
| `cartinfo.lua` | A Yard card from its cart's own `info.lua` (bundled by `cart` home_pack) |
| `draw.lua` | Colours, fonts, neon text, the painted-label cache and its paint queue, `rrect` |
| `input.lua` | The deck and keys, the 1-player/2-player rules, the press queue, the 1P+2P hold, `HOME_SCRIPT` |
| `menu.lua` | Drawing every scene: the menu (marquee, tabs, cards, info panel), the intro, attract, night, overlays (`draw_scene`) |
| `idle.lua` | Input by scene (`handle`), the attract, the night, the idle shows' curtain, schedule and play |
| `ticks.lua` | The music for what is on screen, and the idle timers (`update_idle`) |
| `homestate.lua` | The state file (load/save), the labels for the cards in view, the art cache and the worker's uploads, the curtain, the trace |
| `actions.lua` | Launching (`request`, `launch`), moving the selection, sections, volume, the secret code |
| `pictures.lua` | The pictures between programs: get ready, welcome back, power-on |
| `diag.lua` | The hitch and frames lines in the log |
| `guard.lua` | Turns a nice-to-have module off at its first error instead of ending Home |
| `tv.lua`, `shelf.lua`, `hall.lua`, `initials.lua`, `favs.lua` | Scenes and helpers with their own `load(ctx)`, `handle`, `update`, `draw` |
| `shows.lua`, `showlib.lua`, the shows | The idle shows (SHOWS_PIPELINE.md) |
| `music.lua`, `songs.lua`, `synth.lua`, `sound.lua` | Music (its own thread) and sound effects |

## `ST`, the app table

Home's shared state and settings live in one table, `ST` (created at the top of `main.lua`): the selection
(`ST.sel`, `ST.pos`), the scene (`ST.scene`), timers, the show playing, flags, paths (`ST.GAMES`, `ST.STATE`, ...)
and the functions modules share (`ST.draw`, `ST.near_shots`, ...). A module reads and writes `ST.x`; nothing
copies state.

**Change scene with `ST.go(name)`,** never `ST.scene = name`: every change passes through one function (where
anything a scene needs on entering or leaving goes, and where the change is noted for the hitch log).

`t`, the frame clock, is main's: a module that reads it keeps a mirror and main hands it the new value each frame
(`MENU.sync_t(t)`). `W`, `H`, the module handles and `log` are plain locals everywhere.

## How a moved module is shaped

`catalog`, `cards`, `idle`, `menu`, `homestate`, `ticks` were moved verbatim by `tools/home_move.py`: the module
declares, as its own locals, the names of main's it uses (its "mirrors"), and returns a function main calls with
them, where the section used to be:

```lua
local IDLE = require("idle")({A = A, D = D, ST = ST, items = CAT.items, ...})
```

so their code reads exactly as it did in `main.lua`. The rule that keeps mirrors honest: a mirror is never
assigned, by the module or by main, after the call (the mover refuses a move that would break it; such names live
in `ST`). A function is shared by reference; so is a table, as long as nobody replaces it.

## Adding things

* **A Yard game:** a cart in `games/carts/<id>/` with its `info.lua` (title, tint, blurb, band, `stat`). Home's
  card comes from it; nothing to edit here.
* **A classic or arcade card, a section:** `catalog.lua`.
* **An idle show:** SHOWS_PIPELINE.md (`shows.lua`'s list, a module like `night.lua`).
* **A scene:** a module with `load(ctx)`, `handle(name)`, `update(dt)`, `draw()` like `hall.lua`; enter it with
  `ST.go("name")`, give it a branch in `idle.lua`'s `handle` and `menu.lua`'s `draw_scene`.
* **New state:** a field of `ST`, not a new top-level `local` in `main.lua`.

## Before calling a change done

1. `tools/home_tour.py`: 50 scripted, pixel-exact steps (sections, cards, shows tiles, attract, night, a show,
   the intro, the TV guide, launches, the boot and welcome-back pictures). A change meant to look different: look
   at the pictures in `games/out/home_tour/run/`, then `--save`.
2. `python3 games/test.py home` (the tour, the metrics ceilings, no stray globals, the supervisor's ladder, the
   cards), and `tools/show_lint.py` when shows are touched.
3. `tools/home_metrics.py`: main.lua's locals, slots and upvalues against LuaJIT's limits; the globals main.lua
   writes (only `home_note`); names a module uses that it was never given.
4. On the cabinet after `games/cart push`: `tools/home_bench.py` (startup, menu and attract fps, textures, RSS,
   errors) against `captures/home_tour/cabinet_baseline.tsv`.
