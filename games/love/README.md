# LÖVE: the GPU runtime

The C runtime (`games/engine/`) draws every pixel on the CPU into one frame and uploads it. The cabinet has a Mali-400 GPU that the stock games barely use. This folder runs the same carts on [LÖVE 11.5](https://love2d.org), which draws with OpenGL ES 2 on that GPU, mixes sound in OpenAL, and runs Lua on LuaJIT.

Status (2026-10-25): **it runs on the cabinet** (field run, 2026-10-24: the "GPU yard" row). The user found it "crystal clear" next to the soft CPU picture, but Lamp was sluggish, the music lagged, and Orb opened from it had no deck or sound. Those are fixed in this tree and not yet on the cabinet ([FIELD_TASKS.md](../../FIELD_TASKS.md) round 2).

| | C runtime (`yard`) | LÖVE runtime (`yard.love`) |
| :--- | :--- | :--- |
| Drawing | CPU, one texture upload a frame | GPU: shapes, text, layers, light map, 4x MSAA where the GPU has it (the cabinet's doesn't) |
| Lua | Lua 5.4.7 | LuaJIT 2.1 (Lua 5.1 language). LÖVE turns the JIT off on ARM; the probe measures both |
| Sound | 16-voice synth in the audio callback | Each sound rendered once into a cached buffer, played by OpenAL |
| Carts | The same carts, the same pack, the same save files | |
| Size | 420 KB (expected) | 8.9 MB unpacked, 4.1 MB as `love.tar.gz` |
| On the cabinet | Tile 10, via The Yard | A "GPU yard" row, once FIELD_TASKS.md task 4 is done |

The C runtime stays the shipping one until round 2 shows the GPU runtime smooth, and the memory question is settled: LÖVE took about 40 MB beside the stock menu's 53 MB of the cabinet's 118 MB.

## What's here

| Path | What it is |
| :--- | :--- |
| `build.sh arm\|x86` | Builds LÖVE and every library it needs from source, with `zig cc` as the cross compiler. Output: `games/out/love-arm/` or `games/out/love-x86/`. Sources go to `~/lovebuild` (`LOVE_WORK`) |
| `include/` | Headers for DRM, GBM, EGL, GLES, ALSA, and udev. Nothing links against them; see its README |
| `rtshim.c` | Four float helpers LuaJIT wants from libgcc on ARM |
| `check_abi.py` | Checks that a bundle will load on the cabinet: ARM, hard float, glibc ≤ 2.29, libstdc++ ≤ 3.4.22, every library present |
| `smoke.sh [ROOTFS]` | Runs the ARM bundle under qemu with no screen (`smoke/`): Lua, C++ exceptions, images, sound, fonts, zlib |
| `yard/` | The runtime: `main.lua` (the pack, the sandbox, the menu and launching), `gfx.lua`, `audio.lua`, `input.lua`, `conf.lua` |
| `probe/` | The cabinet probe: GL limits and formats, frame times for seven loads, Lua speed with the JIT on and off, a beep, and ten seconds of "press every button" |
| `loveprobe.sh` | The launcher on the cabinet, installed twice as `/data/Games/loveprobe` and `/data/Games/loveyard`. Unpacks `love.tar.gz` to `/data/love` the first time |
| `label/` | The two menu rows for those launchers ("LOVE probe", "GPU yard") |

## The build recipe

The cabinet has glibc 2.29, GCC 6's libstdc++ (GLIBCXX 3.4.22), SDL 2.0.7, and no compiler. Rather than match an old distribution, `build.sh` builds everything with zig's clang for `arm-linux-gnueabihf.2.28 -mcpu=cortex_a7`. Zig ships glibc stubs for that version and its own libc++, so nothing newer than the cabinet can leak in.

* **SDL 2.30.9**, with KMSDRM, GLES2, and ALSA loaded at run time (`*_SHARED`). The cabinet's own Mali, libdrm, libgbm, and libasound are used; none is bundled.
* **LuaJIT v2.1** with its own unwinder on ARM (`LUAJIT_NO_UNWIND`). **OpenAL Soft 1.23.1** over ALSA. **ogg, vorbis, theora (decoder), modplug, freetype 2.13.2, zlib 1.3.1.**
* **LÖVE 11.5** without mpg123, enet, or luasocket.
* Every library is filed under its SONAME and stripped. `run.sh` sets `LD_LIBRARY_PATH`, `SDL_VIDEODRIVER=kmsdrm`, and `LOVE_GRAPHICS_USE_OPENGLES=1`.

The first build takes about 15 minutes; later ones reuse what's done (`~/lovebuild/build-*/NAME.done`). Needs `git make cmake ninja autoconf automake libtool pkg-config zip readelf` and `pip install ziglang==0.13.0`. The PC build also carries `luajit`, which `cart check` uses to parse every cart as Lua 5.1.

## Playing and testing

```bash
games/love/build.sh x86
games/cart love            # the menu in a window (keys: arrows, Z X C, 1 and 2 held to quit, Esc)
games/cart love chest      # one cart
python3 games/test.py love # the bot plays each cart on both runtimes; logs and saves must match
```

The test runs headless (`YARD_HEADLESS=1`, `SDL_VIDEODRIVER=offscreen`, `ALSOFT_DRIVERS=null`). With the same seed and the same bot, Chest, Keep, Lamp, and Tea write identical log lines and identical saves on both runtimes: 105, 8, 21, and 60 lines over 1200 frames.

The same environment variables as the C runtime work: `CAB_SCRIPT`, `CAB_AUTOPLAY`, `CAB_SEED`, `CAB_MAX_FRAMES`, `YARD_PAK`, `YARD_CARTS`, `YARD_CHECK_FRAMES`, `YARD_STATS`, `YARD_MEM_MB`. Its own: `YARD_MSAA` (default 4), `YARD_UPRIGHT=1` (no rotation), `YARD_DECK` (a button map file), `YARD_LOG`, `YARD_NATIVE_DIR`, `YARD_JIT=0` (compiler off), `YARD_LAUNCH_FILE` (where to ask the launcher for a native program), `YARD_RETURNED` (how the last one went).

## Writing carts for both

A cart is written once. It must stay inside the Lua both runtimes understand, which is Lua 5.1 plus what the library adds. `cart check` lints for it, and parses with LuaJIT when the PC build is there.

* Integer division: `idiv(a, b)`, not `a // b`.
* `atan2(y, x)`, not `math.atan(y, x)`. `unpack(t)`, not `table.unpack(t)`.
* No `<<`, `>>`, `&`, `|`, or `~` operators, no `utf8`, `math.type`, `math.tointeger`, `table.move`, `string.pack`.
* `idiv` returns a float on Lua 5.4 (3.0, not 3). That's fine for table keys, loops, and `%d`. Don't compare `math.type`.

## Differences you might notice

* **Shapes are GPU shapes.** Edges are smoothed by MSAA where the GPU offers it (the cabinet's Mali-400 doesn't on canvases), not the C renderer's coverage, so a pixel-for-pixel compare differs slightly. Text uses the same font at the same size.
* **Sound.** The synth renders at 22050 Hz. A held music note is faded rather than released when the next step starts.
* **Launching.** The menu runs a cart in the same process, not as a child, so a crashing cart shows the Oops screen and the menu carries on. A native program (Orb) gets the whole machine: on the cabinet LÖVE quits, `loveprobe.sh` runs it, and starts LÖVE again; on the PC the window closes, it runs, and the window reopens. The LÖVE rows are hidden inside the GPU menu.
* **Shake and particles** draw from the cart's own seeded generator, so a seed replays the same game, as in C.

## What the cabinet told us (2026-10-24)

From `captures/love/love-probe.txt`, `love-probe.log`, and `love-yard.log` (verified on this cabinet):

* **GPU:** `OpenGL ES 2.0 | ARM | Mali-400 MP`. Textures up to 4096, ETC1, no MSAA on canvases (so `YARD_MSAA` falls back to none), no `highp` in fragment shaders.
* **Frame times at 768×1024:** a clear 16.7 ms (vsync), 500 sprites 18.7 ms, text 20 ms, 300 shapes 22 ms, a full-screen shader 32.6 ms, 4000 sprites in a batch 39 ms. So a full-screen shader pass costs about 16 ms: one is the whole frame.
* **LuaJIT:** 563 ms interpreted, 164 ms with `jit.on()` (2M loop). The runtime now turns the compiler on (`YARD_JIT=0` turns it off).
* **The deck under SDL 2.30:** buttons 1, 2, 4, 7, 8, 16–21, exactly SDL 2.0.7's numbers plus one. No `yard-deck.txt` needed.
* **Sound:** plays; OpenAL's ALSA output logged `mmap commit error: Broken pipe`. The bundle now carries `alsoft.conf` with `mmap = false`.
* **KMSDRM** came up on the stock `libmali`/`libgbm` once SDL was really built with it (the field agent's fix to `build.sh`).
* **Menu:** 11–12 ms a frame to draw. Lua memory grew from 6 to 8 MB between collections; the collector now runs sooner (`setpause 150`).

What changed after it (2026-10-25):

* **Light** (`gfx.lua`): lights are queued and drawn in one canvas switch per frame. Each switch on the Mali-400 writes the screen out of tile memory and back, and Lamp adds a dozen lights a frame. The warm curve and the shadow tint are computed at the cart's resolution; the two passes over the screen are plain blends.
* **Sound** (`audio.lua`): samples are written through LuaJIT's FFI rather than one call each, and a song's notes are all made when it starts.
* **Native programs:** on the cabinet the GPU yard writes `native:orb` to `$YARD_LAUNCH_FILE` and quits; `loveprobe.sh` runs Orb with the whole machine, then starts LÖVE again with `YARD_RETURNED` set, and the menu says how it went (`yard.returned()`).
* **The pack** is read only as far as its header says it is used (not the whole 4 MB slot).

Open, for round 2: Lamp, Tea, and the menu frame times now; whether `stock_menu stop` (the C supervisor, `yard.conf`) gives LÖVE the room to be the main runtime.
