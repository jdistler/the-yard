# Star Kart: the Star Cup

Cart `games/carts/kart/`: `main.lua` rules, bot and music wiring, `pictures.lua` all drawing and the static data (tracks, rivals, paints), `songs.lua` the music. The Yard lists it as "Star Kart", band `5+`. Depth pass per [ADVENTURE.md](../ADVENTURE.md) ("Star Kart") and CASTLE.md's rules. Walk-up band, controls unchanged: the stick steers left/right (up is a little faster), LOW/TL/TR uses the item, 1P+2P held leaves. Not harder: races are still 13 to 17 s, item boxes stay when your hands are full, the cup score resets per cup, and the first-ever races give rivals 3% less speed.

## The story (in pictures)

A comet drops the golden Star Cup at the end of the Rainbow Skyway. Four rivals of our own want it: **Ember** (fox, cocky), **Bibi** (bee, sweet), **Moss** (frog, laid back) and **Pebble** (penguin, proud and grumpy). Race three tracks to win it.

* **Story screen** (about 6 s, any button skips after 0.2 s; the cream band says one line a beat): the comet falls, the cup lands and shines, the rivals roll in one by one to the start line and look back, you roll in last in your paint. A returning player sees only the line-up.
* **Garage** after the story, and again after every cup: the kart on its turntable, the paint swatches (stick left/right picks an unlocked one; locked ones say how: "3 races", "1 cup"), the trophy shelf, the medal shelf, the rival stickers. LOW starts the cup.
* **Cup map** between races: a map with the three lands, the road gold up to where you are, a medal on each finished stop (your place), the kart driving to the next stop, and the cup table below (faces, points, bars).
* **Grid:** three lights, then GO. **Race:** the road with a theme per track (below), a progress bar with every racer on it, a face-and-name bubble when a rival speaks. **Last stretch:** a gold arch, the song turns. **Finish:** the table of the race, fanfare, confetti, and "New kart paint" if one was earned.
* **Podium** after race 3: the five racers by cup points rise onto steps 1 to 3 (4th and 5th stand beside it) with their faces and cup score; the winner holds the Star Cup. Then back to the garage with the new trophy blinking on the shelf.

## Three tracks, one reused scene layer

| Track | Theme | Roadside | Song |
| :-- | :-- | :-- | :-- |
| Meadow Circuit | blue sky, windmill, hills | round trees, flower bushes, signs | C major, 148 |
| Beach Boardwalk | sunset sea, sailboats, gulls | palms, umbrellas, sandcastles; planks on the road | G major calypso (3-3-2), 136 |
| Rainbow Skyway | night, ringed planet, crescent moon, crystal spires | star lanterns, crystals, floating rings; a rainbow road | A minor, 152 |

Two layers for ever: a 384x132 sky strip (repainted in place per track) and one 384x512 scene layer (story, garage, map, podium, repainted in place when the screen changes). Images stay at 966 KB. The road (24 strips) and the roadside (at most 18 objects) are drawn with plain primitives each frame; no full-screen alpha layer, no closures or tables made per frame in the race.

## The rivals

Each has a face (front: portrait, bubble, table rows; back: ears, antennae, eye bumps, tuft, the kid's helmet), a way to drive (`spd`, `lane`, `amp` in `pictures.lua`) and a way to feel.

* **Passing is a moment.** A rival that overtakes you taunts (smug lids, tongue out, a bubble with its word); one you pass is beaten in its own way: Ember and Pebble sulk (tear, frown), Bibi cheers you on, Moss yawns. A rival that stays just ahead for 0.75 s glances back and taunts. A rival just behind you sprints now and then (a short burst, rubber-banded) so they really do come past. A seeker hit makes it sulk; bumping you makes it say "Oopsie!"; the wobble wave makes them all "wow".
* Bubbles are at most one every 2/3 s; each rival has its own sound (Ember a sly slide, Bibi a buzzy trill, Moss a ribbit, Pebble a gruff slide). `kart taunt NAME`, `kart pass NAME`, `kart bonk NAME`.
* **After the line** they react to the result (the winner cheers, those ahead of you smirk, those behind sulk or cheer by personality), and on the podium the winner's arms go up and the cup is lifted.
* Rubber band as before (rivals ahead slow, rivals behind catch up). In the cup each rival earns the same points table as you (500/350/250/150/150 for 1st to 5th); your score pill and `best` are still your own points.
* Your driver is a kid in a helmet whose colour is your kart's trim; the face turns to the camera on a boost ("wow"), a box ("happy"), a bump ("ouch") and at the line.

## The items (our own names)

Comet Dash (was Turbo Star): a long boost, rainbow kart, rivals bounce off. Seeker Spark (was Green Shell): an orb that finds the rival ahead. Bubble Shield: soaks one bump. Wobble Wave (was Lightning Zap): every rival wobbles and slows for a moment. Same odds, same effects, same scores.

## The music (`songs.lua`)

Six tracks, 8 bars of 16 steps (128), the same order in every song and section: 1 lead, 2 counter-stabs, 3 bass, 4 drums, 5 shimmer, 6 pad. Each is written to sound right alone.

* **Layers follow your place and boost** (`music.track`, changed only when a level changes; the place must hold 0.5 s): the bass and pad are always on; leading brings the lead up and the shimmer in; chasing (4th, 5th) brings the stabs and full drums and softens the lead; a boost or a comet brings everything in and louder. Passing someone and the lead rising is the reward.
* **Last stretch:** `music.play{keep = true}` into the "final" section (the same tune, busier drums, a driving bass, arpeggios where the pad was) with `music.tempo(1.05)` and a bell chord on the beat.
* **Pickups are notes:** a box, a boost pad, an item, a pass, a bonk each `music.cue` the next rung of a ladder over the chord under the song (root, third, fifth, octave, ...), on the step or beat; a run within 3 s climbs, so a good stretch is a melody. Seekers and the wobble wave are a bell chord on the beat.
* **Start:** the grid plays the song with only bass, shimmer and pad (the build-up); at GO a bell chord and the lead and drums arrive.
* **Other music:** a fanfare per track in its key, and a gentler "good race" one when you were 4th or 5th; the map's travelling tune (the twinkle track comes in with each stop); the podium march (a layer arrives with each step: the pad, bass, drums, harmony, and the lead for 1st); the story (a comet of bells, then the racers' theme when they line up).
* Game logic never reads `music.step()`: only the pitch of a cue.

## What grows between visits (`kart.sav`)

`best` (high score) and `cups` (cups won, now the cup table's top three) as ever. New, all clamped: `visits`, `races`, `wins`, `gold`/`silver`/`bronze` (cup trophies), `paint` (the one you chose), `m1..m3` (your best place on each track), `b1..b4` (times you finished ahead of each rival). Saved at each finish, each podium, leaving the garage, and in `quit()`.

* **Trophies** on the shelf: gold/silver/bronze with counts, and the Star Cup that shines after the first one; medals per track; rival stickers (a "?" until you have finished ahead of them).
* **Kart paint** (`kart paint N`): Cherry (start), Sunny (1 race), Minty (3 races), Grape (6 races), Bubblegum with a star (1 cup), Ocean (1 gold), Rainbow (10 race wins). Never taken away.
* `info.lua`'s stat is unchanged (`N cups`, or `best N`).

## Log lines

`kart best N`, `kart visit N`, `kart story`, `kart garage`, `kart pick N`, `kart race N`, `kart item NAME`, `kart pass NAME`, `kart taunt NAME`, `kart bonk NAME`, `kart final N`, `kart finish N PLACE`, `kart paint N`, `kart podium RANK`.

## The bot

Steers for the next item box when its hands are empty, for a boost pad when it holds an item, uses the item every 10 frames, and presses to move through every screen after half a second. It finishes race 1 inside 1000 frames and plays a whole cup in about 2700 frames (all of it identical on the C and LÖVE runtimes; checked over 3400 frames).
