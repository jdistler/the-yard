# Partycade TV: the plan (2026-10-27; status 2026-11-01, 2026-11-22 and 2026-11-25 below)

## Status 2026-11-25: the player rebuilt for smoothness (measured on the cabinet)

"Blocky video, hard edges of rectangles through transitioning frames" (the user, 2026-11-24). What was found,
each measured with the player's own log (`tvplay.log`, now on the SD card) and `tools/cab.sh shot`:

* **The cause of the blocks: the Wi-Fi.** The cabinet had joined the outdoor access point at boot (-76 dBm,
  2.4 GHz, 5.5 Mbps, 70 % of pings lost) and stayed 15 h, though the office AP was at -54 dBm: wpa_supplicant had
  no background scan. The stream starved and reconnected, and a decoder fed a broken stream draws blocks until the
  next keyframe. Now: wpa_supplicant built with bgscan (`simple:30:-65:300`, added by yardnet to a RAM copy of
  wifi.conf), wpa_cli in the bundle, the link logged a minute at a time to /tmp/wifi.link. After: 0 % loss, 7 ms,
  26 Mbit/s to the cabinet (a channel is 4-8).
* **Only 45 of 60 pictures a second on 720p60, worse the longer it played**, on a perfect link: the skip rule's
  "lead" grew with every late frame and hardly shrank, until a quarter of the pictures were thrown away. The VPU
  decodes 720p at 100 fps: with no skipping it showed 60.0. Now pictures are skipped only while frames really
  come out late (three in a second), for two seconds.
* **Judder on 30 fps channels**: pictures 1, 3, 2, 2 refreshes apart instead of 2, 2, 2 (the audio position,
  the clock, moves in 23 ms steps). Now the pictures follow a smoothed clock (the monotonic timer steered 2 % a
  frame toward the audio): 95 % of gaps at two refreshes, A/V within 20 ms.
* **Garbage at the start of a channel**: the gate joins a stream mid-picture-group. Now decoding starts at a
  keyframe, and again after a jump in the stream (the decoder reset).
* **HEVC skipping could corrupt**: sub-layer non-reference pictures are only safe to drop from the highest
  temporal layer. Now only those.
* **Decoder buffers handed back while the GPU might still read them**: now two flips later.
* **The backdrop's 36 x 48 cells showed as soft blocks** (still, blurred: "distracting", the user): replaced by a
  calm glow, each band one gradient from Home's dark to the colour of that edge of the picture, eased over ~1.5 s
  (a 1 x 4 texture; ~130 reads every 4th frame; no banding on the cabinet's screen).
* **Changing channel** quit the player and showed Home's "changing channel" picture between two programs. Now
  tvplay plays the whole row (`TVPLAY_LIST`), flips in place: the next channel's bands at once over the last
  one's colours, its picture in 1.7-2.7 s. It reads the address from account.conf itself (the password was on
  its command line, visible in `ps`). tvloop is a launcher; `games/test.py system` checks it.
* **"Blockiness and jitter in fast motion" on SEC Network** (the user, watching football): the player's numbers were
  clean (30 shown a second, even cadence, no decoder errors). The stream is the limit: SEC Network arrives as
  720p at 29.97 fps and ~3.4 Mbit/s (sports is usually 60 fps at 2-3 times that); the gate passes it through.
  At 30 fps a fast pan moves in 33 ms steps (judder no player can remove without inventing frames), and at that
  bitrate the encoder's own blocks show in fast motion. What the player could do: shrink the picture with four
  reads a pixel instead of one (thin moving lines no longer step and crawl, block edges softened); on 30 fps
  channels that fits the GPU (30 shown, none late), on 60 fps it does not (30 of 60), so it is chosen by the
  channel's frame rate. Also found: the Wi-Fi hopping to weak 5 GHz APs mid-game (now 2.4 GHz only).
* **The tearing in fast motion: the GPU drew into the picture being shown** (found with the user watching test
  patterns on the cabinet, 2026-11-25). Bars sliding down tore near the screen's right edge (where each frame's
  scan starts, the panel being the framebuffer turned); sliding sideways did not. `tools/cabview/fliptest.c`
  (dumb buffers, no GPU) switched cleanly every way (async flip at random moments, blocking set-CRTC): the VOP and
  the panel latch at the frame boundary. With the GPU: the pipelined swap (SDL_KMSDRM_PIPELINE=1) tore at the
  right; plain flips were clean only because the Mali defers its drawing to the swap; forcing it to finish early
  tore mid-screen. `SDL_KMSDRM_SAFE=1` (games/love/patches: each flip waited for, the old buffer given back at
  once) was clean in the worst case and keeps the TV at 60 fps; tvloop uses it. It halves Home (58 -> 29 fps:
  Home overlaps CPU and GPU), and a pipelined variant (=2) reached only 34: the Mali surface's buffer accounting
  contradicts itself. The games now draw into four scanout buffers of SDL's own (tear-free at full speed); Home still
  uses the pipelined swap (SYSTEM_AUDIT.md K7b, K7c).
* Tearing was suspected from seams in screen grabs; a grab takes ~70 ms (four refreshes), and grabs taken with
  the picture held still (`TVPLAY_HOLD`) show none. Not a defect of the player.

## Status 2026-11-22: the Pink TV household (verified on the cabinet)

The two Skywave syndication proxies this plan was built on are gone (deleted 2026-11-20 with the rest of
Skywave's Supabase sync). The cabinet is now a screen of the Pink TV household (~/Projects/tivi-remote,
plans/reunification): one playlist, `PINK_TV`, whose server is the home panel gate on the LAN
(`http://192.168.1.10:8800`, login `arcade.home`). The gate gives it the household's curated lineup and
guide, logos that keep their shape, failover between Nova and 4K Live, and it plays every stream through the
gate, sharing a TV's line when the arcade picks the channel a TV is watching. Playlist names are one word
(they go on shell command lines); `_` shows as a space. tvnet has `now` and `line` for the gate's
`/__gate/now` and `/__gate/line`; channels.tsv has a line per group membership (the gate's `category_ids`),
in each group's order. The sections below are the original plan; where they say "proxy" or "fullent" /
"Strong", read "the gate".

## Status (2026-11-01, verified on the cabinet)

Built and working end to end: Home's TV tab (CLASSICS / THE YARD / **TV** / MORE) opens the guide in Home itself
(`games/love/home/tv.lua`, 60 fps); RECENT, then FULLENT's groups, then STRONG's, each a row of channel tiles with
logos and now-playing progress, an info panel with now / next / description. The lower button tunes in: Home paints
a "tuning in" picture with the controls, `tvloop` (`games/tv/tvloop.sh`) runs `tvplay`; CNN first picture in 4.7 s,
A/V +0.02 s, 0 drops. Stick up/down flips channels in the row ("changing channel" picture between, dead channels
skipped), 2-PLAYER comes back to the guide on the channel watched, hold 1P + 2P goes to Home. `tvnet` syncs each
playlist (handshake sets the clock, groups, channels, the curated XMLTV cut to 12 h) in ~6-9 s from a background
thread, and fetches logos into `/mnt/sdcard/partycade/tv-logos` (the SD slot is on since 2026-11-01). Lists live
in `/data/tv/<NAME>/` (offline copy), the guide in `/tmp/tv`. Lessons: the cabinet's LÖVE is draw-call bound (the
rows draw in passes: 17 -> 10 ms CPU), and no scissor in Home (it draws turned onto the framebuffer).

Watching (2026-11-01, later): the portrait panel leaves a 16:9 picture 768 x 432 and two 296-pixel bands; they
are now part of the picture (`games/tv/tvview.c`, included by tvplay). Behind everything, a blurred, darkened copy
of the programme; in the top band the logo, name, playlist, row, position and clock; in the bottom band NOW (times,
minutes left, progress) and NEXT, from the playlist's epg.tsv. tvplay draws the bands with "TUNING IN..." before the
stream is even opened, so flipping channels shows the next channel's name and guide within a second. Stick
left/right: FIT or ZOOM (cropped to 4:3, 768 x 576); lower button: info on/off; both kept in `/data/tv/view`.
Text is Home's Fredoka from a glyph sheet (`games/tv/mkfont.py` -> `/data/tv/tvfont.gz`, 115 KB). Measured on a
720p60 channel: draw 7-10 ms a frame, 0 frames skipped. Lessons: the GPU is one Mali-400 core with ~16 ms of
fragments a frame: render-to-texture blur cost 5 ms and a four-tap full-band shader 10 ms (half the frames lost),
so the backdrop is a 36 x 48 image the CPU samples from the decoded frame (NV12, every 4th frame) and the GPU
stretches with one read a pixel. Now/next takes the latest-started show running (panels' guides overlap) and the
first one after it ends. A stream that stops showing pictures for 10 s exits 33 and tvloop tunes it again
("RECONNECTING...", 3 tries); a stalled tvplay once held its memory while Home fell back to the stock menu and the
OOM killer ran (so `cart push` now refuses while TV plays, and `tools/cab.sh stop` stops tvloop/tvplay too).

STRONG: its proxy answered 500 on every categories call (a Skywave bug, fixed and deployed 2026-11-01, skywave
eabc75f); since then the STRONG panel itself is down (connection reset, also from home), so the guide shows
"Not answering right now" and retries every 10 minutes.

Live TV on the cabinet from the user's Xtream account (fullent), with the channel curation they already do in
Skywave. Every claim below was measured on this cabinet or against the real panel on 2026-10-27, unless marked.
An earlier handoff from another agent was checked line by line; where it was wrong, this says so.

## What was measured

### Decoding: the VPU works (the big one)

The kernel's `vcodec_service` exposes `/dev/vpu-service` (H.264) and `/dev/hevc-service` (HEVC). The stock system
never used them (its ffmpeg is built `--disable-rkmpp`). Rockchip's MPP (github rockchip-linux/mpp), built here
for armhf hard-float (`~/mppbuild`; CMake processor `armv7-a_hardfp`), recognises the chip as RK3036 (the device
tree says `rockchip,rk3032-dongle`, `rockchip,rk3036`) with no patching. The VPU clock is already at its rated
maximum (297 MHz; Rockchip's DT: "RK3036's vpu could not run higher than 300M"), so no overclocking.

Real channels (15 s samples from fullent), hardware decode alone (`mpi_dec_test`):

| Sample | Decode | Realtime |
| :--- | :--- | :--- |
| H.264 720p59.94 (most US channels) | 100 fps | 1.7x |
| H.264 1080i (25 frames) | 48 fps | 1.9x |
| H.264 1080p50 | 47 fps | 0.94x |
| H.264 1080p59.94 | 49 fps | 0.82x |
| HEVC 1080p23.98 (24/7 movies) | 60 fps | 2.5x |
| HEVC 1080p50 | 50 fps | 1.0x |

Broadcast streams are 49-74 % non-reference pictures, so a player that skips a non-reference picture when it
is behind keeps 1080p50/60 in realtime (tested: the decoder takes the gapped stream with no errors and clean
pictures). Software decoding (the stock ffmpeg, NEON, both cores) manages only SD-540p (2.1x / 1.7x); 720p25 is
marginal and 720p50+ impossible. **So: hardware decoding, software only as a fallback for SD.**

### Display: zero-copy GPU path works

The Mali's EGL has `EGL_EXT_image_dma_buf_import` and `GL_OES_EGL_image_external`. MPP decodes into DRM buffers;
each is imported as an EGLImage (NV12, two planes from one dma-buf) and sampled by a `samplerExternalOES`
shader (the GPU does YUV to RGB), drawn turned upright and letterboxed (768 x 432 in the portrait view), shown
through our SDL (KMSDRM). Prototype: `games/tv/proto/tvproto.c`. Played from the real samples, paced on the
stream clock, skipping non-reference pictures only when behind (screenshots in the session: correct
orientation, colours, no mirroring):

| Sample | Shown | Skipped | CPU (one core) |
| :--- | :--- | :--- | :--- |
| H.264 720p60 | 59.7 fps (pipelined swap) | 0.1 % | 23 % |
| H.264 1080p50 | 41 fps | 17 % | 15-18 % |
| H.264 1080p60 | 42 fps | 27 % | 15-17 % |
| HEVC 1080p50 | 46 fps | 7 % | 18-21 % |
| HEVC 1080p24 | 24 fps | 0 | 10 % |
| H.264 1080i | 25 fps | 0 | 12 % |

Interlaced 1080i shows no visible combing at this size (1080 lines become ~430; the scaler blends fields). A
field-blend shader is a later option. 4K (HEVC Main 10, 2160p) is beyond the decoder: such channels are hidden.

### Audio

The stock libavcodec decodes AAC / AC3 / EAC3 5.1 / MP2; EAC3 5.1 to stereo 44.1 kHz runs at 7.2x realtime
(~14 % of a core, 22 MB). Output: ALSA `default` through Home's dmix (`games/love/home/alsa.conf`), 44.1 kHz s16
stereo. Volume stays the kernel's (volctrl.sh).

### Memory (118 MB, no swap)

Playing HEVC 1080p50 with Home stopped: graphics buffers (Shmem) +54 MB, the player 19 MB, ~18 MB left (with an
11 MB test file in /tmp that streaming will not have). Tight but fine; cap MPP's buffer group
(`mpp_buffer_group_limit_config`) to the DPB plus a few output frames to buy back ~15 MB. Home must have quit
(homeloop already does this for every program).

### Network and the panel

* **fullent redirects every HTTP request to HTTPS** (API, logos, streams). The handoff's "plain HTTP" is wrong.
  The cabinet's libavformat (FFmpeg 4.1, OpenSSL 1.0.2) does HTTPS with redirects fine; busybox wget has no TLS
  and cannot be used. TLS + demux of an 8 Mbps stream: ~11 % of a core.
* Wi-Fi (AC600): 28-29 Mbps sustained from the panel; the server bursts its backlog (40 s of an 8 Mbps channel
  arrived in 20.7 s), so start-up buffering is quick.
* **max_connections is 2, not 1** (one in use at the time, the user's phone was idle).
* Panel `Date` header present: set the clock from it (the cabinet starts at 1970).
* 73 categories, 4,444 channels. The whole list is 1.7 MB of JSON (too much for the cabinet to parse often);
  per category it is 15-122 KB (36-327 channels) in under a second. `get_short_epg&limit=2`: ~1 KB, 0.4 s,
  UTC `start_timestamp` / `stop_timestamp`, base64 titles. Logos: HTTPS PNGs from the panel.
* Of 26 sampled channels, 8 were dead event slots (no video). Common formats: H.264 720p59.94 (US), H.264
  1080p50/59.94 (UK/CA sports, news), HEVC 1080p (some UK sports, all 24/7 movies), 1080i/576i (news, older
  channels); audio AAC, AC3/EAC3 5.1, MP2.

### Curation: Skywave's syndication proxy already does it

`server/sync/supabase/functions/xtream-proxy` (deployed, answering at
`https://dzyacpjfwaqwiqaxgqmf.supabase.co/functions/v1/xtream-proxy`) serves an Xtream API with the user's
hidden groups, hidden channels, group order and custom groups applied, and redirects streams to the panel.
**The cabinet uses the proxy as its panel**: curated categories and channels with no export step and no file to
copy; Skywave stays the only editor. Video still comes from the panel (the proxy only redirects). The cabinet
keeps a copy of the last curated lists, so it works when Supabase is down (falls back to fullent directly if
there is no copy). Needs the proxy login from Skywave's Syndication screen (not on this PC).

### What the cabinet cannot do

No socket module in our LÖVE build; busybox wget has no TLS. So network I/O is native (libavformat's AVIO).

## Design

Three pieces, each where it fits best:

1. **`tvguide` (LÖVE, Lua, in the Home stack)**: the screens. Categories list, then channels with logo, name,
   what's on now and a progress bar; held stick repeats (~6 rows/s); lower button opens / plays; 2P back;
   hold 1P + 2P (1 s, The Yard's meter) to Home. Fredoka, the neon palette, the "get ready" / welcome-back
   pictures, the volume meter, tools/cabview tests. It never touches the network itself.
2. **`tvnet` (native, small)**: fetches for the guide through libavformat AVIO (HTTPS, redirects): the panel
   handshake (sets the clock from `Date`), categories, one category's channels, short EPG for a list of
   channels, logos (downscaled to 64 px PNGs). Writes results to files the guide reads (in /tmp, RAM; the
   curated lists also to /data/tv, small). Run by the guide from a worker thread, a request at a time.
3. **`tvplay` (native)**: plays one channel. libavformat demuxes the HTTPS MPEG-TS; video packets go to MPP
   (H.264 / HEVC; others fall back to libavcodec software for SD), frames are shown zero-copy (tvproto's path);
   audio decoded by libavcodec, resampled by libswresample to 44.1 kHz stereo, played through ALSA dmix. Audio
   is the master clock; video pictures are shown on their PTS, non-reference pictures skipped when behind.
   Start-up cushion 3 s (Skywave's), 2 s after running dry: fullent's delivery swings between ~4 and ~20 Mbps
   from its side, and 1.5 s ran dry three times in 50 s on 1080p60; at 3 s a 720p60 channel played 60 fps,
   0 drops, 0 rebuffers. Stick up/down: previous / next channel in the same category (debounced 0.4 s, the
   new channel's name shown over the bars); 2P: back to the list on that channel; hold 1P + 2P: back to Home.
   Exits with a code the guide reads (back / channel N / home). Dead channels (no video in 6 s, the panel's
   black placeholder, HTTP errors): back to the list, the row dimmed and remembered.

Home starts `tvguide` from a card (a `cart`-like LÖVE program, or `native tv` with a launcher script);
homeloop's pictures cover every switch, so the screen never flashes the console. Leaving the player shows the
welcome-back picture until the guide's first frame.

### Two playlists, TiviMate style

The guide shows both syndicated playlists one after another, each with its groups as rows: **fullent** (10
curated groups: US Sports, News, Big Four Locals, Football, Basketball, Hockey, Baseball, Soccer, ESPN+, Live
PPV Events) and then **Strong** (6: CBS Good, Ecuador, Sports, SEC Network+, NCAAF, Disney + PPV). Each is its
own Skywave proxy login; tvnet fetches each separately and a failing one shows "couldn't reach" in its own
header while the other still works. Strong's earlier HTTP 500 was transient (5/5 handshakes fine afterwards);
Supabase's log API (old endpoint 410, new one has no edge-function tables) could not show why.

### Rockchip's FFmpeg 4.1.3 is not stock 4.1

`AVStream.codecpar` sits 8 bytes later than in stock 4.1 headers, and AVCodecParameters' width / height / SAR
read as garbage; only codec_id is trustworthy. tvplay finds codecpar by checking codec_id at both offsets and
takes size and aspect from MPP's decoded frame instead. Never write AVFormatContext fields directly; use options.

### Data on the cabinet

`/data/tv/` (NAND, kept small, ~50 KB): `account.conf` (both proxies: name, URL, username, password; mode 600, never in git),
the last curated category list and per-category channel lists (a copy for when the network is down),
`dead.txt`. Logos and EPG: in RAM (/tmp/tv), refetched per boot. The SD card is not needed for TV; enabling the
slot (a device-tree change in the boot image now on the cabinet, `de23d410…`, not the stock one) is a separate
project.

## Build order (each step checked on the cabinet with tools/cabview)

1. **tvplay from a file, then from a URL**: tvproto plus demuxing (libavformat), audio (libavcodec,
   libswresample, ALSA), PTS pacing with audio as the clock, MPP buffer cap, exit codes, 1P + 2P. Needs FFmpeg
   4.1 headers matching the cabinet's libraries (avcodec 58.35, avformat 58.20, avutil 56.22, swresample).
   Test: 10 minutes each of a 720p60, a 1080p50 and an HEVC channel: frames shown, skipped, A/V drift, memory.
2. **tvnet**: handshake + clock, categories, channels, short EPG, logos; against the proxy and fullent.
3. **tvguide**: the two lists, logos, now/next, held-stick repeat, launching tvplay, coming back to the row.
4. **Home card** under THE YARD or its own section ("TV"), with how to come back.
5. **Polish**: channel up/down in the player, dead-channel dimming, failure messages ("No network yet: the
   list is from <time>", "That channel isn't on right now", "Your other device is using the account"),
   interlace blend, an on-screen clock.

## Decided

* Logins: both syndicated proxies, read from Skywave's Supabase (never in git).
* 1080p50/60 at ~41-46 fps: fine.
* TV is its own Home tab: CLASSICS / THE YARD / TV / MORE.
