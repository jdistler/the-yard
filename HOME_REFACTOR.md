# Breaking up Home's monolith (games/love/home/main.lua)

Home is the cabinet's front end: the menu, the idle shows' driver, the TV guide's host, the Shelf and Hall of
Fame's host, the pictures between programs, and the loop. Most of it is one file that has reached the limits of
the language it is written in. This plan breaks it up in small steps that each prove they changed nothing,
measured on the PC and on the cabinet. It follows SYSTEM_AUDIT.md item H.

## 1. Analysis (2026-11-24)

**Size and limits** (`tools/home_metrics.py`, from LuaJIT's bytecode listing):

| | Now | LuaJIT's limit |
| :--- | :--- | :--- |
| `main.lua` | 2,538 lines, 160 functions | |
| Top-level named locals | **192** | 200 ("too many local variables") |
| Main chunk register slots | 202 | 250 |
| Most upvalues in one function | **54** (`love.load`), 53 (`love.update`) | 60 ("too many upvalues") |

Already hit twice: new state has had to go into a table `ST` (2026-11-02) and helpers into `ST.*` functions
(2026-11-23) because a new `local` would not compile. `love.load` and `love.update` can take six and seven more
upvalues. The next feature of any size does not fit.

**Its sections** (the file's own `-- ---- name` markers) and what each uses from the others:

| Section | Lines | Declares | Uses names from |
| :--- | :--- | :--- | :--- |
| head (modules, paths, flags, log, fonts, `ST`) | 130 | 38 | |
| the games (classics, arcade, Yard, sections) | 176 | 26 | head |
| colors and drawing (rgb, rrect, neon labels) | 187 | 11 | head, games |
| input (deck, keys, press queue) | 51 | 16 | head |
| **state** (selection, scene, timers, labels, art, save/load) | 241 | **44** | head, drawing, games |
| drawing (the menu, cards, info panel, overlays) | **682** | 21 | **state 17**, head 12, games |
| the pictures between programs | 103 | 6 | head, drawing |
| actions (launch, sections, volume) | 84 | 7 | head, games, state |
| the idle shows (curtain, schedule, play) | 357 | 15 | **state 21**, head 11 |
| the loop (`love.load/update/draw`, handle) | 510 | 18 | **state 34**, head 27, shows 10, drawing 8 |

**What this says.** The `state` section is the hub: 44 names that every other section reads and writes as
upvalues. That is why the loop functions run out of upvalues: each name it touches is one. Moving a section to a
module only helps if the state it touches travels with it, so the order is fixed by the coupling: the leaves first
(drawing helpers, input, pictures), then state into one context table, then the big consumers (idle shows, menu
drawing, the loop) on top of it.

**What already works as modules** and shows the shape to follow: `hall.lua` (a scene with `load(ctx)`,
`enter`, `handle`, `update`, `draw`, given a small context table), `shelf.lua`, `tv.lua`, `favs.lua`,
`initials.lua`, `cartinfo.lua`, `guard.lua`, the shows.

## 2. Target

```
main.lua        LÖVE's callbacks, the app table, the scene dispatcher            (< 600 lines)
app             one table: paths and flags, fonts, items, selection, scene, timers, log, play, the art cache
draw.lua        rgb, rrect, fonts, the neon label cache                          (from "colors and drawing")
input.lua       the deck and keys, the press queue, the 1P/2P rules, HOME_SCRIPT (from "input")
catalog.lua     the classics, arcade, Yard, TV, shows and extras cards; state file load/save (from "the games", part of "state")
pictures.lua    boot, welcome-back, launch pictures for /dev/fb0                (from "the pictures between programs")
actions.lua     launch, section jumps, volume                                  (from "actions")
idle.lua        attract, night, the idle shows' curtain and schedule           (from "the idle shows")
menu.lua        the menu scene: cards, info panel, overlays                    (from "drawing")
scenes          intro, menu, attract, night, show, shows, tv, shelf, hall: each {enter, handle, update, draw}
```

Measured targets at the end: main.lua under 600 lines, under 80 top-level locals, no function over 35 upvalues;
the tour identical; Home's startup, frame rate and memory on the cabinet no worse than the baseline.

## 3. Rules for every step

1. **One move per commit, no behaviour change.** A bug found on the way is fixed in its own commit first, the
   golden re-saved after looking at the changed pictures, and only then the move.
2. **Gates, in order** (a step that fails one is reverted, not patched forward):
   * G1 `tools/home_tour.py`: all 50 steps match the golden, pixel for pixel (pictures, launch requests, the
     rendered boot and welcome-back pictures, no ERROR in any log).
   * G2 `python3 games/test.py home` and `tools/show_lint.py`.
   * G3 `tools/home_metrics.py`: top-level locals and the loop's upvalues no higher than before the step (the
     number goes in the commit message).
   * G4 at each milestone: the full suite, `python3 games/test.py`.
   * G5 at each milestone: on the cabinet (`cart push`; `tools/home_bench.py`): startup to first frame, menu and
     attract fps, texture memory, RSS, no ERROR in home.log, against the cabinet baseline.
3. **Moves keep code identical** where they can: a function moves with its body unchanged, and its callers change
   from `f(x)` to `M.f(x)`. Hot paths (per-card, per-frame loops) keep a module-level local alias, never a table
   lookup per call inside a loop.
4. **Rollback:** `git revert` of the step; on the cabinet, homeloop's last good Home runs if a pushed build fails
   as it starts (SYSTEM_AUDIT.md C).

## 4. Checkpoints

**CP0. A safety net.** *(done 2026-11-24)*
- [x] Determinism hooks for tests: `HOME_NOW` (a fixed "now" for os.time/os.date), `HOME_SEED`.
- [x] `tools/home_tour.py`: 9 scripted runs (menu sections and cards, shows tiles, idle attract, a show at three
      points, the intro, the night, the TV guide, two launches) plus the boot and welcome-back renders: 50 steps,
      deterministic across runs (`--twice`), golden in `captures/home_tour/golden.tsv`.
- [x] `tools/home_metrics.py`: the limits above, measured.
- [x] Both in `games/test.py home`.
- [x] A bug the tour found, fixed first: the stick stopped at an empty section (ARCADE with no card).

**CP1. The cabinet's baseline.**
- [x] `tools/home_bench.py`: on the cabinet, sound muted, Home started cold (file cache dropped) and warm, driven
      by a script through the sections, the attract (state, stats and log are /tmp copies). Baseline in
      `captures/home_tour/cabinet_baseline.tsv`: startup 1.05 s cold / 0.82 s warm, menu 58 fps, attract 58 fps,
      textures 12.2 MB, RSS 39 MB, no errors. A repeat run is within 0.05 s and 0.8 fps (the gate's margins are
      0.3 s and 3 fps). The night scene comes only at night: not measured.
- [x] Experiment, a call on the cabinet (LÖVE's LuaJIT, its JIT off, see below): local/upvalue function 302 ns,
      module field `M.f` 356 ns (+18 %), nested `app.M.f` 390 ns (+29 %), an alias made before the loop 286 ns.
      So rule 3: a module call costs ~0.05 us; alias only in loops of more than ~1,000 calls a frame (0.05 ms).
- [x] Found on the way: **LuaJIT's JIT is off on the cabinet.** LÖVE's `jitsetup.lua` turns it off on ARM
      (code-allocation range limits there can make compiling slow and unreliable). Turned on, the same call takes
      9.3 ns (32 x faster). A separate experiment (SYSTEM_AUDIT.md G4), not part of this refactor.

**CP2. The leaves.** One commit each; G1-G3 each.
- [ ] `draw.lua` from "colors and drawing" (11 names -> 1).
- [ ] `input.lua` from "input" (16 names -> 1; the LÖVE key callbacks move with it).
- [ ] `pictures.lua` from "the pictures between programs" (6 names -> 1).
- [ ] Milestone: G4, G5.

**CP3. One context table.** The hub becomes `app`.
- [ ] `app` created in main; the head's paths, flags and modules move into it (callers use `app.X`; hot loops keep
      aliases).
- [ ] The state section moves into `app` one group at a time, a commit each: selection and scene; timers; labels;
      art cache; volume; the curtain and show control; codes and party mode.
- [ ] Milestone: G4, G5. Expected: top-level locals under 110, the loop's upvalues under 30.

**CP4. The big consumers.**
- [ ] `catalog.lua`: the cards and the state file.
- [ ] `actions.lua`.
- [ ] `idle.lua`: attract, night, the shows' curtain and schedule.
- [ ] `menu.lua`: the menu scene's drawing.
- [ ] Milestone: G4, G5.

**CP5. Scenes.**
- [ ] A scene table and dispatcher in main: `love.update/draw/handle` call the current scene; intro, menu, attract,
      night, show, shows, tv, shelf, hall each a scene object (hall, shelf and tv already nearly are).
- [ ] Milestone: G4, G5, and the targets in section 2.

**CP6. Done.**
- [ ] A short HOME.md: the modules, the app table's fields, how to add a card, a scene, a section.
- [ ] Cabinet soak: a day of normal use with vm.log and hitch notes; no new ERROR, no new hitch class.
- [ ] SYSTEM_AUDIT.md H ticked.

## 5. Log

(Each checkpoint: date, commits, metrics before and after, gates passed, cabinet numbers.)

* **CP0, 2026-11-24:** locals 192/200, slots 202/250, upvalues 54/60 (love.load). Tour 50 steps, golden saved.
* **CP1, 2026-11-24:** cabinet baseline saved; call-cost experiment done (numbers above).
