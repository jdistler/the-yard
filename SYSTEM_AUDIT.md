# Partycade system audit (2026-11-24)

An end-to-end audit of the Partycade as a system: how it is built, the hardware it has to live inside, what has
been optimised so far, how it feels to play, and how it is tested. Then what to change, in order, as a checklist
that is ticked as the work lands. Everything is on the table, including rebuilding parts of it.

Evidence is from this cabinet unless marked otherwise: Home's own log (`/mnt/sdcard/partycade/logs/home.log` and
`.1`: 59,702 lines, 250 Home starts, Nov 14-24), on-device runs of every Yard game with `YARD_STATS=1`
(2026-11-23/24), `/proc`, `dmesg`, and the repo (218 commits, 211 tests).

## 1. The system as it stands

```
power ─► U-Boot ─► kernel 4.4 ─► stock rcS ─► stage2 (binds our S50ui)
                                                └► homeloop (shell supervisor, /data/home/homeloop)
                                                     ├─ Home  (LÖVE/LuaJIT, home.love: menu, shows, TV guide, Shelf browser, Hall of Fame)
                                                     │    exits with a request ─┐
                                                     ├─ classic N   (stock Namco binaries, /data/Games)
                                                     ├─ cart ID     (GPU yard: LÖVE runtime + yard.pak carts)
                                                     ├─ shelf SYS F (our libretro player + cores, SD card)
                                                     ├─ native ID   (Orb, The Yard C runtime)
                                                     └─ tv          (tvloop/tvplay/tvnet, MPP video)
```

* **One program on screen at a time.** Home exits to launch anything and is started again afterwards (median 1.46 s
  to its first frame, n = 212). This is the right shape for a 115 MB box: nothing idles in memory behind a game.
* **Failure ladder (homeloop):** retry, then safe mode (`HOME_SAFE=1`, extras off via `guard.lua`), then the
  stock menu. Added 2026-11-23 after a data bug sent the cabinet to the stock menu at every cold boot.
* **Two Yard runtimes** with one cart API: the C runtime (tests, the classic Yard) and the LÖVE GPU runtime (what the
  cabinet actually runs from Home). A parity test makes the same bot produce the same log and save on both.
* **Storage:** `/userdata` (SPI NAND, ext2, 29.7 MB, **861 KB free**) holds the binaries, Home, the Yard pack, saves,
  and some logs. The microSD (ext2, 30 GB) holds the Shelf library, cores, art, thumbs, Home's log, a 128 MB swap
  file (off).
* **Deploy:** `games/cart push` over Wi-Fi (sha-checked per file, slot files written in place, Home stopped and
  restarted). `tools/shelf_sync.sh` for the library. Flash writes outside that are forbidden (AGENTS.md).

## 2. Hardware limits, and what has been done about each

| Limit | Measured | What we did | Still true |
| :--- | :--- | :--- | :--- |
| RAM 115 MB, no swap | 42 MB available with Home up; Home killed at ~60 MB RSS (Nov 7) | One program at a time; Home frees menu pictures for the Shelf; art caches with caps; the GPU yard's 32 MB / 64 MB caps; unbaked layers now collected at once (2026-11-23) | No early warning before the kernel's OOM killer; no swap; no zram in this kernel |
| Mali-400, fill-bound; GPU memory is system RAM | One full-screen layer is 3 MB of GPU; blend-mode switches tank fps | Pipelined swap (patched SDL), backdrops painted once, batched additive passes, cached neon labels | Garden draws ~30 fps when full; Home's show scenes hitch |
| CPU 2 x Cortex-A7, fixed 1008 MHz | LuaJIT | Fixed-timestep games; FFI synth; music after the first frame | Startup work on the main thread (art, labels, sounds: ~0.8 s) |
| `/userdata` 29.7 MB ext2, 97 % full | 861 KB free; `home.love` 901 KB is replaced through a `.new` copy | Pictures and thumbs moved to the SD card | A Home push needs ~900 KB free; an unbounded log lives there (below) |
| ext2 only (no journal), kids power off with the switch | `dmesg`: both filesystems "mounting unchecked fs" at every boot | Saves: temp file, fsync, rename | No fsck ever runs; a power cut mid-write can damage metadata |
| SPI NAND, flash writes risky | | rk_restore only, user-approved block lists | |
| Kernel 4.4: no PSI, no zram module, no ext4 | `/proc/filesystems`, `/lib/modules` absent | | Freeze diagnosis has to use `/proc/vmstat` and `/proc/diskstats` |
| One stick (4-way gate), one cluster, 1P/2P | Deck reports every 20 ms, no bounce | CONTROLS.md bands; split-hands co-op | |

## 3. Findings

Severity: **P0** hurts the kids now or can break the cabinet; **P1** a real defect or a large gain; **P2**
worth doing; **P3** polish.

### Stability

1. **P0. Multi-second freezes are real and unexplained.** Home's log has hitches of 45.9 s, 31.9 s, 22.1 s and 8.7 s
   in attract (idle), 16.7 s in the menu, and 4.9 to 7.0 s in the Shelf. Home has no sleep state, so these are
   stalls the kids see (the "cabinet is frozen" reports, Nov 7 and Nov 22). Candidates: memory thrashing (no swap;
   file pages evicted and re-read), SD card I/O stalls (ext2, a 30 GB card, `shelf_sync` copies), or the kernel.
   Nothing on the box records memory or I/O over time, so the cause can't be named from the log.
2. **P1. 189 hitches over 250 ms** and 491 between 100 and 250 ms across 250 Home runs. By scene: shows (100
   big, 260 mid), the Shelf (52 big), the menu (23 big, 177 mid). They cluster at scene starts (art and show
   loads on the main thread).
3. **Fixed already, confirmed in the log:** `main.lua: upper(nil)` (the Nov 8 cold-boot crash) and
   `freedom.lua: S nil` (a show asked for its act before it started; guarded since).
4. **P1. The failure ladder has no "last known good".** A Home build that fails at startup goes retry, safe mode,
   stock menu. Safe mode only turns extras off; if the new `home.love` itself is broken, the cabinet ends on the
   stock menu until someone pushes again.

### Storage

5. **P0. An unbounded log on the full partition.** `YARD_LOG=/data/Games/love-yard.log` is opened for append at
   every game launch and never trimmed (112 KB now, of 861 KB free). When `/userdata` fills, saves fail
   (`save.write` returns false) and the next Home push fails. Three stale probe logs from Oct/Nov 1 hold another
   ~120 KB there (`love-probe.log`, `probe.log`, `yard.log`).
6. **P1. No filesystem check, ever.** Both ext2 filesystems mount unchecked at every boot. The SD card can be
   checked safely (it is ours; `e2fsck` is on the box) when its clean flag is down. `/userdata` is flash: checking
   it writes flash, so it needs the user's written approval under AGENTS.md (recommendation only).
7. **P2. The swap file exists and is off, on purpose:** on 2026-11-02, running out of memory with swap on froze the
   whole cabinet (the card swapping) instead of the kernel killing Home, which homeloop restarts (homeloop.sh).
   Swap stays off unless the freeze record (B) shows a case it would help.

### Design and code

8. **P1. Home's game cards duplicate every cart's `info.lua`.** `main.lua` keeps its own title, tint, blurb, and
   stat line for each Yard game; they have already drifted (Band's card counts encores while Band now leads with
   fans; blurbs differ). Every cart change needs a second edit in Home that nobody remembers.
9. **P1. `main.lua` is a monolith at LuaJIT's limits** (2,515 lines; 200 locals and 60 upvalues reached; new state
   goes in a table `ST` to dodge the limit). Every Home change is riskier than it should be. Shows are separate
   modules already; the menu, cards, art cache, input repeat, music, and scenes are not.
10. **P2. Docs are many and partly stale.** 18 top-level documents (4,531 lines); AGENTS.md still describes shipping
    as `./cart pack` then `./cart deploy` (staging for a flash write), while every install since Oct 26 is
    `cart push` over Wi-Fi. A new agent reading in order learns an obsolete deploy.
11. **P3. Stray files in git:** `games/keep.sav`, `games/lamp.sav` (test leftovers at the games root).

### Performance (on the cabinet)

12. Measured 2026-11-23/24, logic at 56-60 steps/s for every game (no slowdown of game speed anywhere):

| Game | Drawn fps | Images | RSS |
| :--- | :--- | :--- | :--- |
| Keep | 55-60 | 0.3 MB | 27 MB |
| Chomp | 52-60 | 0.8 MB | 30 MB |
| Bake | 53-59 | 0.9 MB | 28 MB |
| Star Kart | 41-56 | 1.0 MB | 32 MB |
| Tower | 49-57 | 0.8 MB | 31 MB |
| Starship | 51-58 | 0.8 MB | 32 MB |
| Safari | 39-52 | 0.8 MB | 29 MB |
| Chest | 35-50 | 0.8 MB | 32 MB |
| Dig | 35-46 | 1.6 MB | 33 MB |
| Tea | 44-58 | 13 MB (stamps, flat) | 26 MB |
| Band | 31-45 | 0.8 MB | 26 MB |
| Garden | 30-49, falls as it fills | 0.8 MB | 27 MB |

    **P2:** Garden and Band are the slowest drawers (many live-drawn characters and particles per frame); baking
    the characters' poses as stamps is the known fix (Tea does it).

### Ergonomics and feel

13. The control bands (CONTROLS.md) are now applied across all games (audits of 2026-11-23); held buttons across a
    launch, the 1P+2P quit hold, and the little band's "no fail" are tested.
14. **P2. Loudness is not managed across games.** Each cart sets its own `sfx.master` and arrangement levels; nobody
    has compared them. A child switching games gets volume jumps. Nothing measures it.
15. **P3.** Home's first frame is 1.46 s median after a game; with the return picture painted in between, this reads
    as fluid. Not a priority.

### Testing

16. **What exists is good:** 211 checks in `games/test.py` (quick, play, stress, system, love, home, shows),
    C-vs-LÖVE parity for 13 carts, held-button and quit-chord edges, broken saves, the music API, Home in safe
    mode, show lint, `cart check` (bot + mash per cart), `cart shots`.
17. **P1. No test catches a slow leak.** The GPU yard's unbake leak (768 KB per garden) passed every test; it showed
    only in an 80-second run on the cabinet. A long-run memory check per cart would have caught it on the PC.
18. **P1. Nothing tests sound.** Music for 12 games was written without anyone listening; silence, a stuck note,
    clipping, or a game twice as loud as the others would all pass.
19. **P1. Nothing measures the cabinet automatically.** Every on-device number above came from a hand-written
    script in a scratch folder. There is no repeatable bench with a baseline to compare a change against.
20. **P3.** One 1,300-line test file, serial; the full suite takes 3 minutes (measured 2026-11-24), so splitting
    or parallelising it isn't worth it yet. No pre-push hook.
21. **P1. On-cabinet test runs wrote into the kids' saves.** Running a game's bot on the cabinet (this audit's own
    measurements, Nov 23-24) saved its progress over the real saves: Safari's Field Book full, Band's fans and
    tunes, Bake's window, Dig's harvests. Found from Home's play history (no kid play since Nov 22).

## 4. Recommendations

**Diagnose before redesigning the memory system.** The freezes are the worst thing a child sees, and their cause
decides between swap, smaller caches, I/O scheduling, or none of these. Record memory and I/O continuously
(cheaply, from the supervisor), then fix what the record shows.

**Protect the full partition.** Logs go to the SD card (or `/tmp`) and are trimmed; stale logs leave `/userdata`.

**Add "last known good" to the failure ladder.** After a Home run that lasted (the supervisor already knows: `RAN`),
keep that `home.love` on the SD card. When a new build fails twice at startup, run the last good one before safe
mode, and log it loudly.

**One source of truth for games.** Home reads each cart's `info.lua` (title, tint, blurb, band, stat) from a
manifest generated at pack time, instead of its own copy.

**Make the leak, the sound, and the cabinet testable.** A long-run memory check per cart on the PC; an audio lint per
cart (silence, clipping, loudness spread); an on-device bench (`tools/cab_bench.sh`) with a stored baseline.

**Then refactor Home** in steps behind the existing Home tests: art cache, input repeat, the game cards, and scenes
out of `main.lua`, one module per commit, each with the Home group and show lint passing.

**Bigger options, considered:**
* *Keep Home resident while games run* (no restart): rejected. One program at a time is what keeps 115 MB enough.
* *ext4 / a journal:* not in this kernel; a kernel change means flash writes. The SD card fsck covers most of the risk.
* *Swap on the SD card:* decide after the freeze record (step F).
* *Merge the two Yard runtimes:* no. The C runtime is the fast, deterministic test bed; parity keeps them honest.

## 5. Checklist

Ticked as each lands, with the commit.

**A. Storage and logs (P0)**
- [x] A1. `YARD_LOG` to the SD card's log folder (else `/tmp`), trimmed like Home's log.
- [x] A2. Stale probe logs moved from `/userdata` to the SD card (frees ~270 KB with A1).
- [x] A4. Saves protected from on-cabinet tests: `cab_bench` copies them aside and back; the bot's keys from the
      Nov 23-24 runs removed (backup of every save first: `/mnt/sdcard/partycade/save-backup-2026-11-24/`).
- [x] A3. Test: the supervisor never points a log at `/data`.

**B. Freeze diagnosis (P0)**
- [x] B1. `homeloop` samples `/proc/meminfo`, `/proc/vmstat` and `/proc/diskstats` every 2 s into a small ring in
      `/tmp`; a stall writes the ring to the SD card log beside Home's.
- [x] B2. Home logs, with each big hitch, what it was loading that frame.
- [ ] B3. After a week of records: name the cause in this file and fix it (swap, cache sizes, I/O). *(needs data)*

**C. Last known good (P1)**
- [x] C1. After a Home run over 120 s, `homeloop` keeps that `home.love` on the SD card (only when it changed).
- [x] C2. Two quick failures of a new build: run the last good one before safe mode; log it.
- [x] C3. Test with a broken `home.love` and a good one on the card.

**D. One source of truth for games (P1)**
- [x] D1. The Home pack bundles every cart's `info.lua` (as `carts/<id>.lua`).
- [x] D2. Home builds its Yard cards from them (`cartinfo.lua`, a sandbox for `stat`); its own table is gone.
- [x] D3. Test: every Yard card's title and stat match the cart's `info.lua`.

**E. Tests that would have caught this month's bugs (P1)**
- [x] E1. Long-run memory per cart (LÖVE, 4800 frames): images and Lua must stop growing.
- [x] E2. Audio lint per cart: not silent, limiter hits under a threshold, loudness within a band of the others.
- [x] E3. `tools/cab_bench.sh`: every game on the cabinet, quiet mode, fps/memory/errors against a stored baseline.

**F. Filesystem safety**
- [x] F1. SD card, done over the network 2026-11-24 (no need to take it out): backed up to the PC
      (`~/partycade-dumps/sdcard-2026-11-24/`, 745 files verified by md5), unmounted, reformatted on the cabinet
      (`mke2fs -t ext2 -b 4096 -N 65536 -m 1 -L PARTYCADE`: 68,544 inodes, was 1,949,696), restored and verified
      file by file, swap file re-made. A full check now takes 4.7 s on the cabinet (was about 30). homeloop checks
      it at boot, before anything uses it, when errors are recorded or every 5th mount (watchdog 60 s); verified.
- [x] F2. `/userdata`, user-approved 2026-11-24: backed up to the PC (`~/partycade-dumps/userdata-2026-11-24/`),
      then, detached on the cabinet (Wi-Fi's log was the only writer, so Wi-Fi went down): remount read-only, check,
      reboot. **It was damaged:** `Games/net/wpa.log` and `Games/net.log` shared block 16748, and the block bitmap
      and two groups' free counts were wrong (a power cut mid-write). Repaired with `e2fsck -f -y` (the shared
      block cloned, counts fixed); a second check is clean; every file but the logs matches the backup.
- [x] F3. Fewer writes to `/userdata`: Wi-Fi's own log (written all the time) and the per-boot dmesg copy go to
      RAM (`yardnet.sh`); the failure-path dmesg copy stays, for a Wi-Fi start that fails.
- [ ] F4. A periodic `/userdata` check: it can only be checked read-only, with Wi-Fi down and a reboot after, so
      not at every boot. Recommendation: the same detached script monthly, or when Home's log shows a save that
      failed to write.

**G. Performance (P2)**
- [x] G1. Garden: characters and flower poses kept as pictures on the GPU runtime: 37 -> 47 fps on the cabinet.
- [x] G2. Band: the same: 42 -> 46 fps. (Shape draws per frame 885 -> 291 and 745 -> 190; images ~2.6 MB, flat.)
- [x] G4. Checked: LuaJIT's JIT is on in Home (`sound.lua`) and in the GPU yard (since 2026-10-24, measured
      3.4 x then); LÖVE turns it off on ARM, both turn it back on. No gain left there.
- [ ] G3. Home: move show and Shelf art loads off the main thread where a hitch shows in B2.

**H. Home refactor: the plan, gates and checkpoints are in [HOME_REFACTOR.md](HOME_REFACTOR.md)**
- [x] H0. Safety net (CP0) and cabinet baseline (CP1).
- [ ] H1. CP2 the leaves (drawing helpers, input, pictures).
- [ ] H2. CP3 one context table.
- [ ] H3. CP4 the big consumers (catalog, actions, idle, menu).
- [ ] H4. CP5 scenes; CP6 docs and soak.

**J. Sound (P2)**
- [x] J1. Loudness measured for every game (E2); spread 7.3 dB -> 5.5 dB (Chomp down, Bake and Band up).

**I. Docs and repo (P2/P3)**
- [x] I1. AGENTS.md: deploy is `cart push`; point to this file.
- [x] I2. Remove `games/keep.sav`, `games/lamp.sav` from git.
- [x] I3. A pre-push hook that runs the quick tests (`tools/hooks/pre-push`, 9 s; installed here).

## 6. Results log

**2026-11-24, first pass** (commits c6fe528 .. this one; all pushed to the cabinet and verified there unless noted):

* **Supervisor:** logs off `/data` (989 KB free, was 861); `vm.log` recording memory and I/O every 2 s (running
  under its own name, verified); the last good Home kept on the card and run before safe mode (PC-tested in
  busybox sh and dash; the cabinet's copy appears after Home's first 2 minutes or first choice).
* **Home:** Yard cards from the carts' `info.lua` (verified: 14 cards with live stat lines); hitches name what the
  frame loaded.
* **Tests:** 247 (was 211): the homeloop ladder, the cards, two-minute memory flatness for 13 games (it found and
  fixed a live leak in Bake), sound for 13 games. `tools/cab_bench.py` with a stored baseline; pre-push hook.
* **Sound:** loudness spread 7.3 -> 5.5 dB.
* **Speed:** Garden 37 -> 47 fps, Band 42 -> 46 fps (cabinet).
* **Saves:** the bot's progress from on-cabinet runs removed (backup on the card); the bench protects saves.
* **Open:** B3 (read a week of vm.log and hitch notes, then fix the freezes), F1 (reformat the card, the user's
  part), F2 (needs approval), G3 and H (Home refactor, behind the Home tests).
