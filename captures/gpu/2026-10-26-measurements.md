# GPU yard on the cabinet, 2026-10-26 (over SSH, carts run by their bots, 600-900 frames each)

Before (canvas 768x1024, then a turned copy to the 1024x768 framebuffer), whole frame:
keep 35 fps, lamp 22, menu 23, tea 25, chest 24. Games and music stepped once per drawn frame, so Lamp
played at about a third of its speed. Turning vsync off changes nothing (the KMSDRM flip waits anyway).

Fill test (games/love fill benchmark, 1024x768): clear only < 16.7 ms; one full-screen layer fits a frame,
two take 22 ms, three 33 ms, so each blended full-screen layer costs about 11 ms. 300 small circles +5.7 ms.
One display mode only (HDMI 1024x768p60); GPU at its single 400 MHz step.

| Mode | keep | lamp | menu | tea | chest |
| :--- | :--- | :--- | :--- | :--- | :--- |
| canvas 768x1024 (old) | 35 | 22 | 23 | 25 | 24 |
| canvas 480x640 | 55 | 37 | 36 | 39 | 33 |
| canvas 384x512 | 60 | 42 | 42 | 33* | 40 |
| direct to framebuffer, full resolution | 60 | 30 | 30 | 25* | 36 |

\* tea with the fixed timestep: its bot's scenes have heavy moments; 56 steps/s.

CPU time issuing draws: 8-12 ms a frame (keep 2.7), not overlapped with the GPU's work.
With the fixed timestep every cart steps at 60/s (true game speed and song tempo) in every mode.

## Later the same day: where the frame goes, and pipelining

A Pac-Man attract demo left running by a killed stock menu (tools/cab.sh now stops its start.sh children too)
held every cart at 30 fps for a while; numbers below are from a clean cabinet.

SDL swap timed (patches/sdl-kmsdrm-pipeline.patch, SDL_KMSDRM_TIMING=1): eglSwapBuffers 0.3-0.5 ms, but
gbm_surface_lock_front_buffer 10-18 ms: it waits for the Mali to finish the frame, so CPU and GPU ran one after
the other. GPU time per frame: keep 10, chest 14.4, menu 17.4, lamp 17.8, tea 15.5 ms.

SDL_KMSDRM_PIPELINE=1 (lock and flip at the next swap; falls back when no buffer is free, never seen):

| cart | before | pipelined |
| :--- | :--- | :--- |
| keep | 60 | 60 |
| chest | 37 | 57-59 |
| menu | 30 | 56-57 |
| lamp | 30 | 55 |
| tea | 25 | 44-45 |

Now CPU-bound: draw (Lua + LÖVE) 8.5-15 ms. Lamp's lights before the frame (YARD_EARLY_LIGHTS) cut its draw
9.7 -> 7.7 ms; a Text-object cache for outlined text did not help (9 draws each instead of one batch) and is off.

## Evening: CPU side and zram

Profiles (LuaJIT jit.p, YARD_PROFILE): text 42% of the menu, glows 23% of Chest, lines and stars in Tea.
Call counts per frame (YARD_COUNT): Tea ~115 circles, 95 lines (each +2 cap circles), 47 ellipses.

| change | effect on the cabinet |
| :--- | :--- |
| outlined labels painted once (YARD_LABELS) | menu 56.5 -> 59.8 fps |
| lazy blend (YARD_LAZY_BLEND) | Tea draw 17.0 -> 15.5 ms |
| thick line = one stadium polygon (YARD_STADIUM) | Chest 57 -> 59, Tea 41 -> 44 |
| Tea's clouds painted once, GPU only (game.gpu) | Tea 44 -> 47 |
| circle segments 0.7 -> 0.5 (YARD_SEG_K) | Tea +0.3 ms only; left at 0.7 |

zram: a zram.ko built the same way as the Wi-Fi modules loads and works (lz4 through the crypto API). With 48 MB
of zram and the stock menu paused, its 46 MB compressed to 19 MB, but Tea still ran out of memory, so GPU yard
keeps stopping the stock menu. Not shipped. (A 50 MB /tmp test also made the OOM killer take the stock menu:
keep memory tests small.)
