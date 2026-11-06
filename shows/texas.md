# Texas (`games/love/home/texas.lua`, `tools/art/texas.py`)

## Round 2 (2026-11-06): the first pass through the pipeline

The first show reviewed with `tools/show_review.py`. With the camera's own moves taken out, half the scenes
turned out to be still pictures the camera drifted over (San Antonio scored 60 beats a minute with the camera, 7
without it). Set out to: no dead stretch over 15 s, a story in every scene, more Texas, music that doesn't loop.

### Measured (before -> after; stale and beats are the world's, the camera held still)

| scene | stale s | beats/m | still | cover | song loops |
|---|---|---|---|---|---|
| The Gulf Coast | 13 -> 13 | 21.9 | 0.19 | 0.56 | 1.3 |
| The Hill Country | 9 -> 9 | 19.6 | 0.29 | 0.98 | 1.1 |
| Round Rock | 7 -> 7 | 16.5 | 0.42 | 1.00 | 0.8 |
| Austin | **49 -> 12** | 7.0 -> 17.0 | 0.02 -> 0.05 | 0.41 -> 0.50 | 1.3 -> 0.8 |
| Fort Worth | **24 -> 13** | 12.0 -> 25.0 | 0.18 -> 0.05 | 0.38 -> 0.48 | 1.5 -> 1.1 |
| Dinosaur Valley (new) | 15 | 36.0 | 0.25 | 0.99 | 0.9 |
| San Antonio (the Alamo) | **29 -> 10** | 6.9 -> 27.0 | 0.74 -> 0.40 | 0.35 -> 0.43 | 0.7 -> 0.3 |
| The River Walk (new) | 8 | 34.9 | 0.02 | 0.66 | 0.8 |
| Central Texas Barbecue | **25 -> 18** (then the trays sped up) | 15.4 -> 24.0 | 0.54 -> 0.24 | 0.54 -> 0.50 | 1.2 -> 1.5 |
| The Panhandle | **44 -> 10** | 10.0 -> 24.0 | 0.50 -> 0.20 | 0.30 -> 0.98 | 0.9 -> 1.2 |
| Congress Avenue Bridge | **37 -> 13** | 4.0 -> 28.0 | 0.89 -> 0.07 | 0.28 -> 0.72 | 2.6 -> 0.9 |
| Big Bend | **53 -> 5** | 6.0 -> 40.0 | 0.83 -> 0.33 | 0.19 -> 0.72 | 2.0 -> 1.0 |
| The Lone Star | 8 -> 3 | 27.0 -> 46.0 | 0.05 -> 0.07 | 0.30 -> 0.53 | 0.5 -> 0.7 |

16 red findings -> 1 (the barbecue's trays, sped up after). The show: 10 -> 12.4 minutes, 11 -> 13 scenes.

With the measure's final form (the hero moving counts as a beat, SHOWS_PIPELINE.md), the whole show again:
**0 red**, every scene's longest still stretch 0-8 s (Gulf 5, Hill Country 2, Round Rock 4, Austin 2, Fort Worth 4,
Dinosaur Valley 2, San Antonio 0, River Walk 2, barbecue 5, Panhandle 7, bats 8, Big Bend 5, Lone Star 1).

### Scorecard (0-3: Story Hero Layers Animation Detail Camera Gag Finish Music sound-X; by eye, film strips)

| scene | before | after | notes |
|---|---|---|---|
| Gulf Coast | 22 | 22 | unchanged: the sandcastle, the pelican's dive, the wave |
| Hill Country | 21 | 23 | the camera timer's ticks were silent ("tick" didn't exist): now heard |
| Round Rock | 17 | 18 | ticks fixed; the donut stop is still plain (Ideas) |
| Austin | 11 | 23 | the grackles on the wire drown out the busker; the band's flatbed; the street fills and dances |
| Fort Worth | 17 | 22 | the drive big and close with moos; the calf chase bigger, the ghosts cheering; the calf follows the van |
| Dinosaur Valley | - | 25 | new: the tracks found one by one, long ago (the sauropod, the meat-eater's sneeze), ghosts leave no prints, the hills roar back |
| San Antonio | 9 | 15 | now a short quiet beat (25 s) before the River Walk |
| River Walk | - | 24 | new: the duck family crossing, the lights on string by string, the chips stolen, mariachis, cascarones |
| Barbecue | 11 | 22 | repainted from the front: the line, the pit room's smoke, slicing, a burnt end, the trays, the sauce bottle, seconds |
| Panhandle | 14 | 24 | Cadillac Ranch spray-painted (Clyde gets polka dots), the train close, the storm nearer and nearer, umbrellas, a rainbow |
| Bats | 10 | 21 | kayaks, a stream that sways and thickens, big bats swooping past, phones flashing, the moon |
| Big Bend | 13 | 25 | dusk to stars, the tent on Clyde, the fire, the BOO, the Marfa lights visit (one in Pinky's jar), Saturn, a wish |
| The Lone Star | 11 | 23 | the day's scrapbook: a polaroid from every stop, blown away to the flag |

### Done

* **Music.** B parts so nothing goes round twice: Austin (a stop-time chorus), Fort Worth (a bridge), the Alamo (a
  second strain), the bats (two more parts: 19 -> 58 s), Big Bend (a third part). New: `tx_mariachi` (a son in
  3/4, two trumpets in thirds, then the violins), `tx_dino` (plucky exploring, then low brass and toms).
* **Sounds.** New: quack, moo, honk, whistle, sizzle, tick, roar. `tick` had been asked for and was silent.
* **Art.** New: `bigbend_dusk`, `riverwalk`, `dinovalley`; `bbq` repainted (the joint from the front).
* **Scenes** as in the scorecard; the scene table is now lengths, the starts worked out.

### Checked

* PC: every scene through `show_review.py`, film strips looked at.
* Cabinet (`tools/show_cab.sh`): 60 fps through every scene but one: the River Walk dropped to 41-46 fps once
  its strings of lights were on (115 bulbs, each switching the blend mode twice a frame). Drawn now in one
  additive pass (LÖVE batches the glows into one draw). The first full run stopped at 3:25: the cabinet is in
  the family room, and a press during a measurement starts a game; the halves were measured separately.

## Ideas

* **Round Rock's donut stop**: a glaze waterfall on a conveyor, the box filled from it (D, S; M).
* **East Texas**: Caddo Lake, cypress and Spanish moss, a log that's an alligator (new scene; L).
* **Padre Island**: the sea turtle hatchlings let go at dawn, racing for the waves (S, G; M).
* **Houston's rodeo**: mutton bustin' (G; L).
* **Variety between runs** (blueprint rule 11): none yet in Texas; a seed could pick the Big Bend story, the
  River Walk's thief (a duck, a grackle), the dinosaur's sneeze or roar.
* **Words**: Dinosaur Valley, the barbecue and Big Bend have 9-11 speech bubbles; trim the ones the picture tells.
* **The barbecue's song** (`tx_conjunto`, 33 s) goes round 1.5 times: a C part.
* **The Lone Star's song** is one part twice: a B part for the scrapbook.
