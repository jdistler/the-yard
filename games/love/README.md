# LÖVE: the GPU runtime

The C runtime (`games/engine/`) draws every pixel on the CPU into one frame and uploads it. The cabinet has a Mali-400 GPU that the stock games barely use. This folder runs the same carts on [LÖVE 11.5](https://love2d.org), which draws with OpenGL ES 2 on that GPU, mixes sound in OpenAL, and runs Lua on LuaJIT.

Status (2026-10-24): built and tested on the PC only. **Nothing here has run on the cabinet.** [FIELD_TASKS.md](../../FIELD_TASKS.md) is the plan for the first run.

| | C runtime (`yard`) | LÖVE runtime (`yard.love`) |
| :--- | :--- | :--- |
| Drawing | CPU, one texture upload a frame | GPU: shapes, text, layers, light map in shaders, 4x MSAA |
| Lua | Lua 5.4.7 | LuaJIT 2.1 (Lua 5.1 language). LÖVE turns the JIT off on ARM; the probe measures both |
| Sound | 16-voice synth in the audio callback | Each sound rendered once into a cached buffer, played by OpenAL |
| Carts | The same carts, the same pack, the same save files | |
| Size | 420 KB (expected) | 8.9 MB unpacked, 4.1 MB as `love.tar.gz` |
| On the cabinet | Tile 10, via The Yard | A "GPU yard" row, once FIELD_TASKS.md task 4 is done |

The C runtime stays the shipping one until the cabinet has measured the GPU runtime.

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

The same environment variables as the C runtime work: `CAB_SCRIPT`, `CAB_AUTOPLAY`, `CAB_SEED`, `CAB_MAX_FRAMES`, `YARD_PAK`, `YARD_CARTS`, `YARD_CHECK_FRAMES`, `YARD_STATS`, `YARD_MEM_MB`. Its own: `YARD_MSAA` (default 4), `YARD_UPRIGHT=1` (no rotation), `YARD_DECK` (a button map file), `YARD_LOG`, `YARD_NATIVE_DIR`.

## Writing carts for both

A cart is written once. It must stay inside the Lua both runtimes understand, which is Lua 5.1 plus what the library adds. `cart check` lints for it, and parses with LuaJIT when the PC build is there.

* Integer division: `idiv(a, b)`, not `a // b`.
* `atan2(y, x)`, not `math.atan(y, x)`. `unpack(t)`, not `table.unpack(t)`.
* No `<<`, `>>`, `&`, `|`, or `~` operators, no `utf8`, `math.type`, `math.tointeger`, `table.move`, `string.pack`.
* `idiv` returns a float on Lua 5.4 (3.0, not 3). That's fine for table keys, loops, and `%d`. Don't compare `math.type`.

## Differences you might notice

* **Shapes are GPU shapes.** Edges are smoothed by 4x MSAA rather than the C renderer's coverage, so a pixel-for-pixel compare differs slightly. Text uses the same font at the same size.
* **Sound.** The synth renders at 22050 Hz. A held music note is faded rather than released when the next step starts.
* **Launching.** The menu runs a cart in the same process, not as a child, so a crashing cart shows the Oops screen and the menu carries on. A native program (Orb) still gets the screen to itself: the window closes, it runs, the window reopens. The LÖVE rows are hidden inside the GPU menu.
* **Shake and particles** draw from the cart's own seeded generator, so a seed replays the same game, as in C.

## What the cabinet has to tell us

The probe answers these. Until then they are expected, not verified:

1. Does KMSDRM come up on the stock `libmali` and its `libgbm`? (SDL 2.30's KMSDRM is newer than 2.0.7's.)
2. The real GL limits, texture formats (ETC1?), and whether 4x MSAA is affordable.
3. Frame times for clears, sprites, batches, shapes, text, a full-screen shader, and an MSAA canvas.
4. Lua speed in the interpreter and with `jit.on()`.
5. Does OpenAL open the sound card through ALSA?
6. Do the joystick buttons keep their SDL 2.0.7 numbers? If not, `/data/Games/yard-deck.txt` (lines `button N NAME`) fixes the map without a rebuild.
7. How much memory is left with the GPU runtime running.
