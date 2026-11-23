# Dig: tunnels, critters, boulders, a garden to win back

A cart: `games/carts/dig/` (`main.lua` has the rules, `pictures.lua` the drawing, `songs.lua` the music). The Yard lists it under Chest, blurb "dig tunnels, pop foes, find gems", band `5+`. `games/test.py` (run by `stress.sh`) plays the checks at the bottom. The depth pass follows [ADVENTURE.md](../ADVENTURE.md) ("Dig") and CASTLE.md's rules.

Audience is a five-year-old who loves Dig Dug and colorful critters (and already plays Chest). Classic Dig Dug is punishing for young hands: tight grid corners, one-hit deaths, falling rocks that crush you, and awkward directional pumping. **Dig** keeps everything magical about Dig Dug (cozy tunnels through four colorful layers of earth, inflating goofy critters until they POP, boulders dropped for a mega bonk, buried gems) while making it joyful, readable, and forgiving.

This is the walk-up band in [CONTROLS.md](../../../CONTROLS.md). Controls did not change.

## The sentence

The stick digs and walks through the earth, and `LOW` (or `TL`/`TR`) puffs your pump!

## The story (told in pictures)

The critters carried the veggie garden down into the caves (they were hungry, not bad). Each cave cleared brings one veggie home; it is planted on the garden map, and every fifth cave is a harvest party where the critters bring everything back and share.

* **Story screen** at the start of each visit (any button skips; it ends by itself after about 6.5 s; a returning player sees only the last part, from "?" on the bare plots). The full garden, three critters trotting in, each stuffing veggies into a sack and diving down the hole, Diggy arriving and hopping in after them. The cream band says one line per beat. The press that skips it is also the first puff of cave 1 (so a held button from the menu never fires it).
* **A goal you can see:** the garden tray in the cave's HUD shows this row's five plots. Planted ones show their veggie, the next one pulses.
* **Garden map between caves** (after the "cave clear" banner, any button or 4 s): the new veggie arcs from Diggy into its plot, the next plot shows a "?" silhouette, critters' eyes watch from the hole.
* **Harvest party** (cave 5, 10, 15...): bunting, fireworks, the critters come out of the hole in party hats with a basket of veggies, Diggy dances. The party song. Then a fresh row.

A turn is: story, cave (dig, puff, grab gems, dodge), clear banner (Diggy holds the veggie up), garden map, next cave. The garden carries on across visits; the cave number continues from `best + 1`. Difficulty does not: every visit starts at difficulty 1 and climbs by one per cave cleared in that visit (`S.diff = min(level, 1 + clears)`), so the first minute stays gentle.

## The five cave worlds (one per garden plot)

| Plot | Veggie | World | Key, tempo |
| :-- | :-- | :-- | :-- |
| 1 | carrot | Meadow Mine: sunny sky, bones and roots, Garden's bouquet flowers on the grass | G major, 142 |
| 2 | turnip | Crystal Deep: dusk sky and moon, glowing crystals, twinkling stars | D minor / F, 146 |
| 3 | mushroom | Mushroom Grove: toadstools above and below, drifting spores | C major, 128 |
| 4 | pineapple | Ember Deep: sunset, embers and a lava glow in the deep, rising sparks | A minor, 150 |
| 5 | pumpkin | Crown Cave: golden afternoon, far castle, pumpkins on the grass, gold flecks | D major march, 120 |

## The pump is an instrument

Every part of the music is in `songs.lua`: 8 bars of 16 steps (128 steps), six tracks in the same order in every world and section: 1 lead, 2 counter-stabs, 3 bass, 4 shimmer, 5 drums, 6 pad. Worlds 1 and 2 keep the original hand-written tunes; 3 to 5 have new hooks, with the harmony tracks built from the chord list (`roots`, one chord per half bar). Each part sounds right alone.

* **Tunnelling alone:** bass, pad, shimmer and a soft lead (0.55). Each freshly dug cell also plays the next chord tone, low, on the grid (a marimba), at most every 10 frames.
* **A critter close (130 px):** drums and the counter-stabs come in (`music.track`), and stay 2 s after it leaves. The lead lifts to 0.9.
* **Pops in a row (within 7 s):** the lead goes to 1.25. A run is also scored (+50 per pop beyond the first).
* **Each pump** is the next note up the chord ladder (root, third, fifth, octave, ...) on the next step, so pumping a critter three times plays a rising arpeggio of the chord under the song. A miss, a flame puffed out, a gem, a rock landing: each its own cue from the same chord. A pop is the full chord (a stinger), an octave higher on a streak of 3; a bonk is the chord too.
* **Last critter:** `music.play{keep = true}` into the world's "hunt" section (busier drums, a driving bass, the shimmer all the way through) and the tempo goes to 1.2.
* **Being hurt:** the lead drops away (0.3) for a moment, gently.
* **Clear:** the victory fanfare, transposed into the world's key. **Garden:** a slow music box in C. **Harvest:** an F major polka. **Story:** the thieves tiptoe (Am F C E) and Diggy's theme (track 3 lead and 4 drums) comes in when he arrives.

## The world answers

* **Critters** have faces: the pupils follow Diggy; each is brave (brows), sleepy (lids, a "z" when far away) or sneaky (smirk) by its number; worried (brows up, a sweat drop) when puffed or when it is the last; one that bumps Diggy cheers (arms up, jumps).
* **Diggy** has moods: cheer (clear, garden, harvest), ouch (stars), whew (a rock or flame just missed him: "whew!" and a sweat drop), worry (a critter within 70 px), puffing cheeks while pumping, yawning after 5.5 s still and asleep ("z") after 12 s, the headlamp dimming as he nods off. Rocks have worried faces while they wobble.
* **Near misses:** a falling rock passing within 46 px, a flame within 34 px, or the hop-aside logs `dig whew`.
* The garden tray, the run's notes (coloured dots by the HUD) and the gem pill show what the song is doing.

## What grows between visits (`dig.sav`)

* `best N` (highest cave cleared), `hi N` (best score), `gems N` (total gems): as ever, clamped 0..100000 (hi to 999999).
* New, all clamped: `harvests` (rows picked), `rowq` (this row's plots as base-4 digits: 0 plain, 1 plump from the bonus veggie, 2 golden; only plots the saved `best` has reached are read), `v1..v5` (veggies saved, by kind), `gold` (golden veggies), `gk1..gk4` (gems by colour), `visits`.
* **The shelf** on the story and garden screens: five jars (veggies saved, "?" until the first), a rosette (harvests), the golden veggie count, the four gem colours, and a hat meter.
* **Hats** earned by total gems (Diggy's hard hat): red, sunny yellow (25), leaf green (80), violet with a star (160), rainbow (300). Never taken away. `dig hat N`.
* **A rare golden veggie:** the bonus veggie that appears after two boulders drop is golden one time in five (+6 gems, +600, longer-lived, shown golden in the plot). The ordinary one is +3 gems and a sparkle on its plot.
* **One world with Garden:** the flowers of Garden's last bouquet (`save.peek("garden", "bouquet")`) grow on the grass of every cave.
* `info.lua` stat still reads `level N` from `best`.

## Who is underground

* **Diggy:** cheerful explorer in a hard hat with a glowing headlamp and a cozy blue suit.
* **Puff:** round rosy-orange critter with big goggles (homage to Pooka).
* **Char:** orange-coral dragon with a glowing tail flame (homage to Fygar); takes a visible breath before a short purple-orange puff of fire.
* **Wobbly Boulders** bonk critters below, never the hero; they hop him aside.
* **Buried Gems** in four colours.

## Log lines (the tests read these)

`dig best N`, `dig story N`, `dig level N`, `dig pump`, `dig pop F`, `dig bonk F`, `dig gem N`, `dig hurt K F`, `dig restart F`, `dig last F`, `dig whew F`, `dig clear N`, `dig veg SLOT GRADE`, `dig garden SLOT`, `dig plant SLOT GRADE`, `dig harvest N`, `dig bonus N`, `dig golden N`, `dig goldveg`, `dig bonusveg`, `dig hat N`.

## Pictures and memory

Two layers for ever, 1.5 MB: the scenery layer (`scene()` in `pictures.lua`: repainted *in place* when the world or the garden scene changes, so nothing is allocated or left for the garbage collector, and playing a hundred caves costs no more than one) and the tunnels layer (repainted only when a cell is dug). The five tiny tray veggies are stamped once each (about 0.1 MB). No `rnd()` in drawing; scenery is placed with an integer hash. Particles stay under the engine's cap, every other effect is a few glows and circles.

## Controls

| Input | What it does |
| :--- | :--- |
| Stick (4-way) | Dig fresh earth or walk through tunnels (auto-centers in lanes) |
| `LOW`, `TL`, `TR` (press or hold) | Puff the air pump at the nearest critter (3 puffs = POP!); on the story, the clear banner, the garden and the harvest, go on |
| `1P` + `2P` held | Quit (the cabinet rule). Everything is saved |
