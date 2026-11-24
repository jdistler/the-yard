# Keep: Pip stocks the Tea party's pantry, one season at a time

Cart `games/carts/keep/` (`main.lua` rules, `pictures.lua` drawing, `songs.lua` music). Walk-up band (CONTROLS.md), 240x320. Follows ADVENTURE.md ("Keep") and CASTLE.md's rules. **Controls did not change:** the stick moves the basket, a button dashes the way Pip leans (never needed to catch).

## The story (in pictures)
Pip is one of the Tea cats (drawn as in `tea/pictures.lua`: orange, cream muzzle, pink nose, blush, whiskers; Moth, Pearl and Nib sit at the table). The Tea party is tonight and the castle pantry is bare. The title screen *is* the story for a new player (about 6 s; any button starts, the cream band says one line per beat): the cats look at an empty shelf (a jar in a thought bubble), Pip wakes, takes her basket out to the orchard, comes back with fruit, and the first jar pops onto the shelf. A returning player sees the shelf as it is, with their jars, balloons for each party held, Garden's bouquet in the vase, and Pip dozing.

## A turn
A round is a year: **Blossom, Summer, Harvest, Snow**. Each has its own orchard (one reused 240x320 layer, repainted in place), weather (petals, butterflies, leaves, snow), special fruit, bees and song. Catching fills the jar in the corner (and heaps fruit on the basket's rim); a full jar is made into jam (a banner, a flash), a heart comes back, and the next season starts. Four jars in a row is the **Tea party** (the kitchen, every cat cheering, confetti); then a new year begins. Three misses still end the round (the pantry keeps everything made so far). Catches to fill a jar: 8, 12, 14, 16. A special fruit or gold fills two.

* **Gentle first season:** no bees, fruit hangs longer and falls slower, difficulty scaled by 0.8. Nothing else got harder: level, speed and spawn curves are the original ones.
* **Special fruit** (+3, a chord on the beat): cherry, peach, plum, frostberry. Gold is as before (+5).
* **Bees with personality** (only the harm is the old one, one heart): the dozy summer bee (sleepy lids, drifting z, slower), the grumpy harvest bee (a scowl, a low growl), the cheery bee (a flower, a grin, "hi!"), the snow bee in a red scarf with breath puffs. A bee that buzzes past her gets a text and Pip gasps.

## The world answers
* **Pip's faces:** blink, happy (catch), cheer (gold, special, multiplier, season done), "oh" (a near miss: fruit that lands just beside the basket, or a bee past her; also a bee close above), ouch (hurt), sulk (the round over: ears droop), worried ears at one heart, sleepy / yawn / asleep with "z" after 5, 7, 12 seconds of doing nothing. Her eyes follow the fruit that lands next; her ears twitch; her tail swishes faster as the streak grows. She wears a flower (Blossom), a straw hat (Summer), a leaf (Harvest), a knit hat and scarf (Snow).
* **Fruit with faces:** asleep on the branch with a smile, wide-eyed when it starts to shake, an "O" while falling, a grin when the basket is under it.
* The cats at the table look at Pip, hop when she is cheering, and put on party hats at the party.

## The music (`songs.lua`: 8 bars x 16 steps, 6 tracks, same order in every season)
Tracks: 1 pad, 2 bass, 3 arp, 4 drums, 5 stabs, 6 the hook. Blossom (C major, 104 bpm), Summer (G, 118, off-beat stabs), Harvest (A minor jig, 124), Snow (E minor music box, 92). Every part is written to be a song with any subset on.
* **The catch run is a melody:** each catch is the next note of that season's 16-note tune (`music.cue`, on the next step; `music.tune_note`), the run restarts the tune after a miss. Gold and special fruit and each multiplier step add a chord on the beat.
* **Layers by the run (`S.ml` 0..5, +1 per 3 catches in a row):** 0 pad and a soft bass; 1 bass up and arp; 2 drums; 3 stabs; 4 the hook; 5 the **chorus** (`music.play{keep = true}`: busier drums, driving bass and arp, brighter hook). **A miss takes one layer away** (not all of them), and the hook dips for 1.5 s.
* Title: a music box over a soft bass; for a new player the lead joins when Pip sets off and the tick when she returns. Party: an F major polka. Game logic never reads `music.step()`; it is used only to pick the root of a chord stinger.

## What persists (`keep.sav`)
`best` (as ever, unchanged meaning), and new, all clamped on load: `jar1..jar4` (jars made per season, 0..999), `lid1..lid4` (those made in a season without a miss: shown with a red ribbon), `years` (Tea parties held, 0..999, one balloon each up to five), `visits`. Written at a jar, a party, the end of a round and in `quit()`, never from the attract demo (a demo changes nothing saved). The shelf shows up to 8 jars per season and the count beyond. `info.lua`'s stat still reads `best`.

## Log lines
`keep story new|back`, `keep season N`, `keep catch SCORE`, `keep special S`, `keep jar S N`, `keep party Y`, `keep layer N`, `keep miss lives N`, `keep sting`, `keep near`, `keep whew`, `keep over SCORE best B`.

## Pictures and memory
One 240x320 layer for ever (about 300 KB): the orchard in each season and the kitchen are painted into it in place on a change, with an integer hash for placement (no `rnd()` in drawing). Everything else is live toon drawing with reused tables; fruit, bees and weather are a few shapes each. Measured on LÖVE over 6000 frames of the bot (several seasons and a party): images 300 KB the whole way, Lua bounded (1.5-3.4 MB, garbage collected).

## Controls
| Input | What it does |
| :--- | :--- |
| Stick left/right | Moves the basket |
| `LOW`, `TL`, `TR` | Dashes the way Pip leans; starts a round; skips the party after a moment |
| `1P` + `2P` held | Quit (everything is saved) |
