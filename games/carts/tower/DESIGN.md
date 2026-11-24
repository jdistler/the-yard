# Tower: three towers, a sleepy giant, a gallery of friends

A cart: `games/carts/tower/` (`main.lua` the rules, `pictures.lua` the drawing, `songs.lua` the music). Walk-up band
(CONTROLS.md), blurb "climb ladders, hop barrels", `5+`. The depth pass follows [ADVENTURE.md](../ADVENTURE.md) ("Tower")
and CASTLE.md's rules. **Controls did not change**: the stick walks and climbs a ladder you stand at, LOW/TL/TR jump,
the Star Swatter smashes barrels by itself. Nothing is harder: the first barrel still waits 170 frames, the ramp is as
gentle as the audit left it, a new floor still mends a heart, three hearts per tower, the run is three towers and
resets for the next player.

## The story (in pictures)

Big Grumble is not bad, he is **sleepy**. Three little friends (Twinkle the star, Buzzy the bee, Puff the cloud kitten)
giggled all night, so he got grumpy and locked each one in a cage at the top of a tower, and began rolling barrels so
nobody comes. The hero arrives with a Star Swatter.

* **Story screen** at the start of each visit and each new run (about 6 s; any button skips after 0.4 s, and a held
  button from the menu never skips it). Four beats, one cream line each: he sleeps on a pillow with the friends
  circling; the giggles wake him (eyes pop, brows down); he stomps, roars "GRRR!", the cages drop with the friends in
  them and a pile of barrels appears; the hero walks in and the gallery slides up. A returning player (any rescue or a
  best score saved) sees only the last two beats, about 2 s.
* **Payoff** (each tower): the cage opens, the friend flies to his shoulder and **sings him a lullaby** (the song
  turns to a music box); his face goes shock, grump, soft, a big yawn, then asleep with a smile, and a dream bubble
  shows the friend (on tower 3, all three). The card then says "<friend> is free!". Nobody loses; he just needed a nap.

## A turn

Story (skippable) -> tower 1 (Girder Tower, night city) -> win payoff -> tower 2 (Vine Treehouse) -> tower 3 (Castle Sky
Spire) -> "ALL CLEAR" -> short story and a fresh run at score 0. Losing three hearts replays the same tower after a
beat. The first ever tower is the same length as before; the payoff adds about 3.5 s per tower (any button after the
card appears goes on; it also goes on by itself).

## The climb is a rising song (`songs.lua`)

One song per tower, each in a higher key and its own feel: **C major march** (132), **G major skip** (124, a marimba
counter), **D major anthem** (116). 8 bars, 6 tracks, written to sound right with any subset: 1 lead, 2 counter,
3 bass, 4 drums, 5 pad, 6 bells. The mix follows the floor (never `music.step()`):

| Floor | Layers |
| :-- | :-- |
| 1 | bass, pad, a soft lead (a barrel within 120 px brings the drums in at 0.7) |
| 2 | + drums, the lead lifts |
| 3 | + counter, + bells (0.6) |
| 4 (top) | `music.play{keep = true}` into the **climax** section: all six layers, a heavier lead (duty 0.5), driving 8th bass, busier drums, 16th arpeggios and bells. Going back down turns it back |
| Star Swatter | lead +0.3, bells to 1.2 |
| hurt | the lead drops to 0.2 and the drums halve for a moment |

Notes on the beat (`music.cue`, pitch from the chord under the step, sound only):

* **a jump** is the next chord tone up a ladder (resets after 2.5 s still), **a hop over a barrel** is a square note plus
  an octave bell, rising with the hop streak (`hop 3` also turns the band line to "Hop streak!"), **a star** is a bell up
  the ladder, **a smash** and **a new floor** are the full chord, **the Swatter** a chord stinger.
* Win: a two-bar fanfare in the tower's key, then the lullaby (a music box, bass, pad, bells), plus a sung note every 22
  frames while he drifts off. Story: the giggle bells, Big Grumble's low "grumble" (a minor bass and horn) that come in
  when he wakes, and the hero's march that comes in when she arrives.

## The world answers

* **Big Grumble** (pupils follow the hero): sleeps, shocked when the hero jumps a barrel or takes the Swatter,
  winds up before every throw (he lifts a barrel overhead 46 frames ahead, then roars as it rolls: the telegraph a
  five-year-old can read), laughs and pounds his chest when the hero is hurt (never longer than a moment), sleepy after
  10 s of idling. Over the visits he **softens**: from 3 rescues his brows ease and his frown flattens, from 12 he sometimes
  pouts with a small smile.
* **Barrels** have faces: grumpy and looking where they roll, cheering (^ ^) once hopped, wide-eyed and scared when the
  Swatter is on. Each tower has its own barrels (red-banded wood, mossy with leaf bands, purple with gold).
* **The friend** in the cage watches the hero: worried on floor 1, hopeful, then cheering from floor 3.
* **The hero** has legs that walk, arms that climb, a jump pose, a "whew!" face on a near miss (a barrel within 34 px,
  `tower whew`), an "ouch", cheers on a hop, and yawns with a "z" after 8 s still.
* **Stars** (7 or 8 per tower, a ground star and a hop star on a floor): each +25, each the next note of the song, shown
  as a row under the HUD. Collecting all of them is "EVERY STAR" (+300) and puts a **gold rim** on that friend's frame
  for good. Optional, never blocks anything.
* **Towers are themes of one reused layer** (`pictures.lua`, `scene`): Girder Tower (a night city, a crescent moon, steel
  girders), Vine Treehouse (a moonlit forest, planks with hanging vines, rope ladders, fireflies), Castle Sky Spire
  (a pink dusk over clouds, two far castles, gold-trimmed stone, pennants). The layer is repainted in place when the
  tower changes (and for the story's night), so picture memory is one 384x512 layer for ever.

## What grows between visits (`tower.sav`)

* `best N` (best run score) and `rescues N` (rescues in all): as ever, clamped (999999, 100000).
* New, all clamped: `g1 g2 g3` (rescues of each friend), `pf1 pf2 pf3` (1 = an every-star tower for that friend: the gold
  rim), `stars` (stars caught), `hops` (barrels hopped), `visits`.
* **The gallery** (story screen and the win card): three frames, a "?" silhouette until the friend is freed, then the
  portrait with a count; below, Big Grumble's three **gifts**: a nightcap at 5 rescues, a teddy bear at 12, a star
  blanket at 25. He wears them in every later tower; the card announces a new one and it appears on him as he falls asleep.
  Never taken away.
* Saves happen at a rescue, at the losing of a tower, and in `quit()`. `info.lua`'s stat still reads `best`.

## Rules kept

* Game logic never reads `music.step()` (it counts `game.frame`); the music clock is only used to pick a cue's pitch
  and for the sprites' drawing. The seeded `rnd` is used only for particles. The bot plays the same on both runtimes
  (the love test needs the same log lines and the same `tower.sav`).
* Log lines (new): `tower story full|short`, `story done`, `floor N`, `star N`, `swatter`, `hop N`, `whew`, `smash`,
  `perfect N`, `gift N`, `sleep N`. Kept: `tower best`, `tower level N`, `tower jump`, `tower hurt N`, `tower rescue N`.
* `sfx.limit(8000)`; the song sits under the effects. No per-frame tables in the hot paths (the drawing reuses its
  polygons, strings are cached for the HUD); particle bursts are small.
* The bot skips the story, climbs, jumps barrels, takes the Swatter, and continues past the win card.

## Not done

* The cage and the friends are drawn live each frame (a dozen shapes); baking them as stamps would save a little fill on
  the cabinet if the frame rate is ever short.
* There is no "Grumble wakes and hugs" ending on tower 3 beyond the dream bubble of all three friends.
