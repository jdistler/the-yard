# cabview: see and drive the cabinet over Wi-Fi

Written 2026-10-27, when two bugs only showed on the real screen: a black stock menu after GPU yard, and
magenta blocks over The Yard's row titles. Neither showed in any log or PC test.

## Pieces

| | |
| :--- | :--- |
| `cabctl.c` | static armhf tool on the cabinet (`/data/tools/cabctl`, installed by `tools/cab.sh` on first use) |
| `build.sh` | builds it in the `partycade-armhf` image |
| `flow.py` | player-style runs with checked screenshots: `yard`, `home`, `classic` |

`tools/cab.sh` wraps it:

```sh
tools/cab.sh shot [OUT.png]     # what the display shows, upright (default captures/screen/, not in git)
tools/cab.sh key down           # press a control: up down left right 1p 2p low tl tr volup voldown
tools/cab.sh hold 1p 2p 2500    # hold several together for N ms
tools/cab.sh look               # CRTC, planes, framebuffers
tools/cab.sh watch 30           # print the controls as a player presses them, for 30 s
tools/cabview/flow.py yard      # stock menu -> Dig Dug II -> GPU yard -> hold 1P+2P -> stock menu
```

## How it sees

`cabctl grab` asks the display driver which framebuffer the CRTC scans out (`GETCRTC`, `GETFB`) and maps it
(`MAP_DUMB`, or PRIME). That is the picture on the HDMI wire, whoever drew it: the stock menu's MiniGUI
buffers, LÖVE's, ffplay's. A black screen grabs black. A copy counts only if the same buffer is still on screen
after it (a page flip mid-copy would mix two frames). `/dev/fb0` is not the screen: it holds the kernel
console's "LOADING..." picture, shown only between programs.

The framebuffer is 1024x768 and the panel is turned; `shot` rotates it 90° clockwise to the player's view.

## How it drives

Writing `struct input_event` to `/dev/input/event0` (`uart-keys`) injects presses that every reader sees,
the stock menu and SDL alike. There is no `/dev/uinput`. The stock menu wants a press held ~150 ms.

## Rules

* It takes the screen. Do not run flows while someone is playing.
* Nothing is written on the cabinet: `/tmp` is RAM. On 2026-10-27, 16 MB of test screenshots left in `/tmp`
  got the stock menu killed for memory while Galaxian ran.
* A fresh stock menu shows its intro and a copyright page first; presses then are lost. `flow.py` waits until
  the screen looks like the menu.
* Where The Yard opens depends on `yard.sav` (`best N`, the last row): read it, do not assume.
