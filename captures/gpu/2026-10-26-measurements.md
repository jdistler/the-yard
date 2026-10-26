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
