# Chomp: the stars the ghosts scattered

Cart `games/carts/chomp/`: `main.lua` rules, bot and music wiring, `pictures.lua` all drawing, `songs.lua` the music. The Yard lists it as "Chomp", band `4+`. Depth pass per [ADVENTURE.md](../ADVENTURE.md) ("Chomp") and CASTLE.md's rules. Walk-up band, controls unchanged: the stick steers (auto-cornering), any right-hand button is the Turbo Dash, 1P+2P held leaves. Not harder: ghosts still ramp 2/3/4, three tags is a soft restart (eaten dots stay eaten), and the first minute is the same maze as before.

## The story (in pictures)

The sky's stars lit a Chompy-shaped constellation. The four ghosts tossed them down into six little maze worlds. Chompy gobbles the star dust in each maze and one star goes home.

* **Story screen** at the start of a visit (about 6.7 s, any button skips after 0.4 s; never read-only, the cream band says one line per beat): the full constellation, the ghosts float in, each grabs stars and tosses them in arcs onto six maze thumbnails, Chompy rolls up, then the sky map with what he has saved. A returning player (`visits > 1` and a star home) sees only the last 2.8 s.
* **A goal you can see:** the HUD's thin bar fills with the star dust eaten; four small stars light as the maze's four big stars (the power pellets) are taken; the constellation's faint outline is on the sky screens.
* **Payoff:** after the "MAZE n CLEAR!" banner, the **star map**: the star flies from Chompy to its place in the constellation and pops (`chomp lands K`). At 22 stars the sky shines (gold glow, fireworks, `chomp lantern`); later mazes still add to the count ("N stars gobbled home").

## Six worlds (one reused scene layer)

Stage `n` uses maze `(n-1)%6+1` and world `((n-1) + (n-1)//6) % 6 + 1`, so after stage 6 the pairings change. Each world is a palette, a wall accent, floor details painted once, animated scenery drawn each frame (a few glows and circles), and its own song.

| World | Look | Scenery | Song |
| :-- | :-- | :-- | :-- |
| 1 Night Garden | neon blue | twinkles | C major, 144 |
| 2 Firefly Meadow | emerald, grass tufts | fireflies | G major sway, 132 |
| 3 Plum Moonlight | magenta, sparkles | rising sparkles | A minor, 138 |
| 4 Candy Lane | pink stripes, sprinkles | falling sprinkles | F polka, 152 |
| 5 Frost Cave | ice, crystals | snow | D minor, 124 |
| 6 Coral Reef | orange, rings | bubbles | B-flat, 140 |

Mazes 4 to 6 are new (symmetric, no dead ends, same ghost house and warp row; checked by flood fill).

## The ghosts

* **Reddy** (red, tuft): bold, runs straight at Chompy. Brows down, steams and shows teeth when close. Laughs low.
* **Rosie** (pink, bow): sly, aims three tiles ahead. Lashes, a wink now and then, blows a heart when close. Laughs in two high notes.
* **Zippy** (cyan, sparking antenna): giddy, circles round him; blue, he zigzags away. Big wandering eyes, tongue. Giggles.
* **Goofy** (orange, propeller cap): shy, runs for the bottom-left when close. Small eyes looking away, blush, a sweat drop while he runs.

All four sleep (lids, a "z") in the house, tremble when blue (accessories stay on), and stick a tongue out for a second after a tag (`taunt`). Chompy has moods too: determined brows with the power, squinting eyes and orbiting stars on a tag, happy eyes on "whew!" (a ghost close while he dashes: `chomp whew F`, never a tag) and on the clear.

## The music (`songs.lua`)

Six tracks, 8 bars of 16 steps (128), in every world and section: 1 lead, 2 counter-stabs, 3 bass, 4 shimmer, 5 drums, 6 pad. Each is written to sound right alone. Chords come from `prog` (one per bar, `X/Y` splits a bar).

* **Layers follow the star dust eaten** (`music.track`): bass and pad from the start; shimmer at 5 %; drums at 15 % (or when a chasing ghost is within 80 px); stabs at 30 %; the lead at 45 % (0.85) and 75 % (1.2). A tag lets the lead and drums drop for a moment.
* **Ghosts go blue:** `music.play{keep = true}` into the "blue" section of the same song (driving arpeggio, pumping bass, busy drums, everything on) and `music.tempo(1.12)`; when it ends, back to the verse on the same bar. Same on a restart.
* **Every dot is a note:** `music.cue` on the next step, a note of the chord under it, alternating its low and high tones in a walk that restarts after a pause (`dot_note`). At most one cue per step: dot cues are spaced 7 frames apart and rest for a moment after a stinger.
* **Stingers on the beat:** a fruit is the world's chord an octave up; a big star, the chord; each ghost chomp the chord (an octave higher from the third in a chain); the star landing on the map a major chord. Turbo is a high note.
* **Other music:** a fanfare per world in its key, the star map's music box (the twinkle track comes in with the stars home), the story (the ghosts tiptoe; Chompy's theme joins when he rolls up).
* Game logic never reads `music.step()`; it only picks the pitch of a cue.

## What grows between visits (`chomp.sav`)

`best`, `hi` as ever (clamped 0..100000, 999999). New, all clamped: `stars` (mazes cleared in all; a save from before the sky starts with `best` of them home), `visits`, `fr1..fr5` (each bonus fruit eaten), `gh1..gh4` (each ghost chomped), `grand` (four chomps in one big star).

* **The constellation** has 22 stars (the eye, the mouth, 17 round the outline, then the three dots Chompy eats). Never taken away.
* **The shelf** on the sky screens: five fruit (a "?" until the first), the four ghosts (a "?" until the first), and a trophy star for four in a row. Saved at the moments (first of each, four in a row, a clear, a restart, leaving).
* **Looks** by stars home: a red bow (3), a blue cap with a star (8), a golden crown (15). `chomp look N`.
* The fruit that appears is `((stage - 1 + stars) % 5) + 1`, so the shelf fills over visits.
* `info.lua`'s stat is unchanged (`N pts`, or mazes).

## Log lines

`chomp hi N`, `chomp sky N`, `chomp story`, `chomp stage N`, `chomp world N`, `chomp ghost PTS`, `chomp friend ID`, `chomp chain4`, `chomp fruit PTS`, `chomp newfruit K`, `chomp whew F`, `chomp restart F`, `chomp clear N`, `chomp star N`, `chomp look N`, `chomp lands K`, `chomp lantern`.

## The bot

A breadth-first path-follower (`bfs` in `main.lua`): nearest star dust (big stars count six steps nearer), the bonus fruit if it is a short detour, blue ghosts while the power is long, keeping two cells from chasing ghosts unless that leaves nothing. It clears about three mazes in 2.5 minutes and eats every fruit and ghost kind. (The old greedy bot dithered for minutes on one maze.)

## Pictures and memory

One scene layer for ever (768 KB): the six mazes and the star map are painted into it in place when the picture changes; no second white-flash layer (the clear flashes with `gfx.flash`). No `rnd()` in drawing (an integer hash places scenery), texts are built when they change, the crown polygon reuses one table, particles are the engine's capped ones. On LÖVE `images` stays 768 KB over 24000 frames and `lua` falls back to about 2.2 MB after each peak (peak 5.8 MB).
