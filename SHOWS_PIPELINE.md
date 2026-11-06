# The shows' pipeline: how a show is reviewed, improved and shipped

One workflow for every piece of work on Home's idle shows (`games/love/home/<show>.lua`), from "is this scene
any good?" to "it's on the cabinet". Use it every time, in this order, instead of reaching for tools one by
one. [SHOWS_BLUEPRINT.md](SHOWS_BLUEPRINT.md) has the rules a scene is held to; each show's notebook,
`shows/<show>.md`, holds what the review found, the plan, and what was done.

```
 1 MEASURE    tools/show_review.py SHOW --keep          the numbers, a film strip per scene, the timeline
 2 WATCH      read show.png, scene_NN.png, the frames   the craft scorecard, by eye, scene by scene
 3 LISTEN     the report's music table, songcheck       the music and the sounds, by structure
 4 BRAINSTORM shows/<show>.md                           each scene as chapters; ideas ranked; the plan
 5 BUILD      <show>.lua, tools/art/<show>.py, songs.lua
 6 VERIFY     show_review.py SHOW --scenes N            against the baseline; the strips; --flicker; --cab
 7 SHIP       cart push; --baseline; the notebook; commit
```

## 1. Measure: `tools/show_review.py`

```
tools/show_review.py SHOW [SHOW ...] [--scenes 2,5] [--keep] [--out DIR] [--baseline] [--cab] [--flicker]
```

Plays each scene of the show on the PC (headless, 1/60 s a frame, each scene from its own start, four at a time),
**twice**: once as the kids see it (frames for the film strips, and Home's trace: `HOME_TRACE`, the scene, the song,
the camera 10 times a second, every sound effect, every caption, plate and speech bubble, with show time), and once
with the camera held at the whole picture (`HOME_NOCAM`). The life measures come from the second, looked at
through the first's camera, second by second: what moved is the world, at the size the kids see it, not the
camera. (Measured with the camera, a scene where nothing happens but the camera drifts scores 60 beats a minute;
San Antonio did.) A Lua error in any scene fails it. Output in `OUT/SHOW/` (default `/tmp/show_review/`):

The measures, per scene (after its first 5 s, the title card):

| measure | what it is | gate (red / yellow) |
|---|---|---|
| stale | the longest run of seconds with nothing happening (no beat) | > 15 / > 8 s (aim: 12) |
| beats/m | seconds a minute where 12% of the view moved, 6% of it is new, or the hero (the biggest of the cast) moved through the world by half its size | < 8 / < 14 |
| seen b/m | the same, with the camera's moves (for comparison only: a moving camera beats every second) | |
| still | share of seconds with almost no motion | > 0.5 / > 0.35 |
| new | share of the screen showing something the scene hasn't shown before (the story moving) | < 0.02 / < 0.04 |
| cover | share of the picture that ever moves, while the camera holds still | < 0.15 / < 0.3 |
| things | separate moving things in a second, camera still (a floor: water and twinkles count too) | < 1.5 / < 2.5 |
| cast px | the biggest of the cast on the screen, median (from the trace) | < 85 px: yellow (the blueprint's hero: ~170) |
| cam hold | the longest the camera holds one shot | > 40 / > 25 s |
| cuts | camera cuts (jumps) | |
| sfx/m, sfx gap | sound cues a minute; the longest stretch without one | < 1.5 / < 3; > 30 / > 18 s |
| song (loops) | the scene's song; how many times it goes round in the scene | > 3 / > 2 |
| light | mean brightness (dark scenes hide small motion) | < 28 |
| fps | `--cab`: the cabinet's lowest frame rate in the scene | < 55 fails |

Plus music findings (a loop under 25 s under a long scene; a song that is one part repeated; a song that
hands over to another counts the whole chain), sounds (a sound effect that doesn't exist in `songs.lua`'s
`M.SFX` is red: it plays silent, as the Hill Country's camera timer did for weeks; one effect over 60% of the
cues) and words (more than 8 lines a minute: is it told in pictures?).

**Calibrated** (2026-11-06) on the Freedom Show, the model: every scene's worst stretch 0-3 s, its quiet sunset
11 s. Big changes (12% of the view) are beats, and so is the hero moving: the trace records the biggest of the
cast each frame (its size and where it is on the screen, through every transform), and a second where it moved
through the world by half its own size counts. That catches a skier crossing the lake, a tracking shot of a
jumper, a calf on a rope; it still misses a hop on the spot, a tray sliding, a face changing. So a stretch of
8-15 s is checked by eye on the film strip before anything is changed for it. Over 15 s is dead.

The numbers find dead time and thin scenes; they cannot tell a good scene from a busy one. That is step 2.

## 2. Watch: the craft scorecard

Read `show.png` first (does each scene look different from the last? does the day move?), then each
`scene_NN.png`, then the full frames (`work/sNN/`) at the moments the timeline names. Score every scene
0-3 on each line and write the scores in the notebook (`shows/<show>.md`); a 0 or 1 is a finding.

| | craft | 3 means |
|---|---|---|
| S | **story** | it starts in one state and ends in another a kid can see; 4-6 chapters, each changing the picture |
| H | **hero** | someone with a job is always on screen, big enough (a sixth of the screen's height with the camera in) |
| L | **layers** | the back breathes (sky, water, crowd), the middle has its own small loops, the front has the action |
| A | **animation** | things move like things: anticipation, squash and stretch, ease in and out, follow-through, feet that step (no sliding, no popping in) |
| D | **detail** | the place is specific: the props, signs, light, weather and people you'd only see *there*; something new to find on the tenth watch |
| C | **camera** | every shot has a reason (the action moved, a close-up of the payoff); 2-4 shots a scene |
| G | **gag** | a set-up and a pay-off a kid will wait for next time |
| F | **finish** | the biggest moment is last and the transition comes straight from it |
| M | **music** | fits the place and mood, doesn't audibly loop, and the scene's moments land on it (a stinger, a key change) |
| X | **sound** | every cause has its sound: a landing thumps, a door creaks, a crowd cheers |

30 is the top. A scene under 18 is rebuilt; 18-24 gets its weakest lines fixed; over 24 is polished.

## 3. Listen: the music and the sounds

The report's music table gives each scene's song, its tempo, whether it has drums, its loop length and how many
times it goes round, carried across scenes (a song that carries on into the next scene keeps counting).
`tools/song_info.lua` gives every song's shape; `games/out/love-x86/luajit games/love/home/songcheck.lua
WAVDIR` renders WAVs (for a person to listen to) and checks loudness. Questions for each scene:

* Does the song go round more than twice? Write it longer (a B part, a bridge, a key change on the last A) or
  split the scene between two songs.
* Does the music change when the story does (the storm comes, the bats come out, the touchdown)? A song can
  hand over to another at a chapter (CUES can switch `S.song`), or a stinger SFX can mark the moment.
* Does the tempo and feel fit (a cattle drive wants a trot, a campfire a slow guitar, a party drums)?
* The sound effects: the timeline lists every one. Every visible cause should have one; the same sound for
  everything is a finding.

## 4. Brainstorm: the notebook

`shows/<show>.md` per show: the scorecard per scene, then for each scene below 24, the scene rewritten as
chapters (SHOWS_BLUEPRINT.md's format: what changes on screen each 8-15 s, the three layers, the gag, the
finish), and a list of ideas each tagged with what it fixes (S/H/L/A/D/C/G/F/M/X) and its cost (S/M/L). Also
show-level ideas: a scene missing from the trip, a scene that's the same as another, the arc of the show
(time of day, a running gag across scenes, a callback in the finale). Then the plan: what is done this round,
in order, biggest kid-impact for least cost first.

## 5. Build

* Scenes are `D.<scene>(lt, len)`, `CAM.<scene>(lt)` (L.shot keys), `CUES.<scene>` (timed sounds and
  functions). showlib has the cast (`L.pac`, `L.ghost` with moods), `L.path`, `L.hop`, `G:say`, plates,
  particles (`G:puff`, `G:spark`, `G:rocket`), the camera.
* A painted backdrop (`tools/art/<show>.py`, then `~/.venvs/partycade-art/bin/python tools/show_art.py
  show:name`) paints the place, never what the story builds (SHOWS_BLUEPRINT.md's lessons).
* Songs in `songs.lua` (synth.lua's notation); after a new song, `tools/song_levels.py` evens the levels.
* Keep the cabinet in mind while building: few big soft particles under a zoomed camera, pictures painted once.

## 6. Verify

* `tools/show_review.py SHOW --scenes N,M --keep` for the scenes changed: the findings gone, the measures
  against the baseline, the film strips looked at (the numbers are not enough: open the PNGs).
* `--flicker` (show_qa.py) after fast effects: flashes, lightning, blinking.
* The whole show once (`tools/show_review.py SHOW`): no Lua error anywhere, scene to scene.
* `--cab` on the cabinet (when it is free): every scene 55-60 fps.
* `python3 games/test.py shows` before a commit that touches several shows.

## 7. Ship

`games/cart push` (refuses while the cabinet is busy); `tools/show_review.py SHOW --baseline` to make this
the new baseline (`tools/show_baseline/<show>.json`, committed); the notebook's scorecard and "done" list
updated; STATUS.md for anything the cabinet showed; commit. Never push without being asked.
