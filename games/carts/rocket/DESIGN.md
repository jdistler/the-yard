# Starship: three worlds, six lost star-creatures, a duet

A cart: `games/carts/rocket/` (`main.lua` rules, `pictures.lua` drawing, `songs.lua` music). Split-hands co-op (CONTROLS.md):
the Pilot holds the stick, the Co-Pilot holds LOW/TL/TR (the Star-Bubble Beam); one person can play both and the stick alone
finishes every world. **Controls, world lengths (1500/1800/2100 distance at 2.2/frame), spawn rates, and the soft bumps are
unchanged.** The first star waits above the ship and world 1 has no rocks for its first 2.5 s. Save keys `best` and `voyages`
keep their meaning.

## Story
Moon-Mama's Star Lantern keeps six baby star-creatures warm (Pim star-pup, Mochi moon-bunny, Bloop comet-jelly, Nova comet-fox,
Dot dust-moth, Zuzu sun-cub). The wind blows them across three worlds. Story screen (about 6 s, any button skips after 0.4 s;
a returning player sees only the map beat, about 2.7 s): lanterns and sleepers, WHOOSH, then the voyage map with the friends
found so far and "?" silhouettes for the rest, and the two hands (STICK flies, BUTTON pops).

Each world holds a **lost friend** (always brought home at touchdown) and a **shy friend** (peeks from behind the world once the
crew catches 3 star-kitties or makes a TEAM!, and joins at touchdown). Friends arrive in a bubble, hop to the ship, and then
**ride along** around the ship (they cheer on catches and worry on bumps). The landing card is the **voyage map**: three worlds,
this voyage's friends under each, the ship travelling to the next. World 3's card is the gallery of all six plus the Star
Lantern glowing brighter for each friend aboard.

## A turn
Story -> world 1 Pastel Nebula (rose planet) -> touchdown, friends, map -> world 2 Candy Ring Planet -> world 3 Starlight Moon
-> voyage complete, lantern -> story (short) and a fresh voyage at 0 points. One scene layer, repainted in place per world
and landing (6 paintings).

## In flight
* Stars have faces that watch the ship; every third is a star-kitty. Rocks have faces (grumpy, wide-eyed when a beam is
  coming, X-eyes when they bump you and tumble away). A near miss is a "whew" (`rocket whew`).
* **Star Road** (all worlds): seven stars in a wave; each catch is the next note of a rising tune; all seven +300.
* **Sleepy boulder** (worlds 2, 3): 3 or 4 beam pops (cracks, wakes, grumps), then it bursts into a star shower for the Pilot
  (+300). If left, it rolls by. It only bumps.
* **Duet score**: touch catches are the Pilot's, beam pops/catches the Co-Pilot's (HUD shows both). Three alternating deeds within
  ~2 s fill the TEAM pips and make **TEAM!** (+300, a banner, a chord, 7 s of a wider catch reach and a glow). Landing with both
  scores >= 200 and within 2x of each other is a **DUET** (+300).
* Ship unlocks (saved, derived from friends known): 2 = rainbow flame, 4 = gold fins, 6 = crown star.

## The duet in music (`songs.lua`)
Three songs, 8 bars, 6 tracks (1 lead 2 counter 3 bass 4 drums 5 pad 6 sparkle): C major dreamy (100 bpm), F major bouncy (118),
D major stately (92). Layers follow the flight, not the clock: bass+pad+soft lead; the lead after the first deed; drums after 3
deeds (or a rock close); counter at 35%; sparkle at 60%; at 82% `music.play{keep=true}` turns it to the **approach** section
(all layers, busier parts). A TEAM! lifts lead and sparkle; a bump drops the lead.
* The Pilot's catch is a **sine bell** (+ quiet tri octave) rising up the chord-tone ladder; the Co-Pilot's pop is a **square
  duty 0.125 pluck** one octave lower on different chord tones (5th, 8ve, 10th...). Both are `music.cue` from the chord under the
  step, so any mashing harmonises; Star Road stars play the world's pentatonic tune instead; TEAM! is a five-voice chord.
* Touchdown: fanfare, then a music-box "home" tune from the world's own hook (fuller in world 3), and each friend's four-note
  signature on arrival. Story: music box, wind, ship theme entering by beat.

## Saved (`rocket.sav`)
`best`, `voyages` (kept); new, all clamped: `c1..c6` (times each friend was brought home), `stars`, `pops`, `teams`, `kitties`,
`lands`, `visits`. Saved at touchdown, each friend's arrival, and in `quit()`. Never taken away.

## Rules kept
Logic never reads `music.step()`; chance is a small integer generator of this cart (Park-Miller, seeded from the frame, world,
visits), identical on both runtimes; `rnd()` only throws particles (under a 150 cap). `sfx.limit(8000)`. No per-frame
allocation in the loops (HUD strings cached, figures drawn from shared upvalues). Log lines: `rocket story`, `world N`, `beam`,
`pop`, `kitty N`, `team N`, `shy`, `road start`, `road`, `boulder`, `boulder pop`, `whew`, `approach`, `duet`, `land N`, `crew NAME`,
`lantern`; kept `best`, `world`, `beam`, `pop`, `land`.

## Not done
Friends are drawn live (no stamps); sound was checked by CAB_AUDIO_WAV levels, not by ear.
