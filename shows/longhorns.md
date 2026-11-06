# Longhorns (`games/love/home/longhorns.lua`, `tools/art/longhorns.py`)

## Round 2 (2026-11-06): the pipeline, and the cast joins the show

The review found 30 red findings. Underneath them were two problems. The show had **no hero**: no Pac-Man,
no ghosts, only small generic fans. And the season board, which plays all season, had never been looked at on
the PC: rendered with ESPN's schedule (`--env HOME_UT_SCHED=tools/show_fixtures/ut_sched.json`), it was a still
table of text for 38 of its 60 s. Five scenes had almost no sound effects, and three songs went round 2-3 times.

### Measured (before -> after; stale s, beats a minute; with the season board in season)

| scene | stale | beats/m | sound gap s | song loops |
|---|---|---|---|---|
| Game Day | 56 -> 29 (by eye: a tailgate, a catch, Bevo: see Ideas) | 5.5 -> 20.3 | 65 -> 14 | 1.7 |
| The Season | **54 -> 10** | 1.1 -> 32.7 | 8 -> 16 | 1.8 |
| The Longhorn Band | 12 -> 12 | 37.8 | **65 -> 16** | 1.2 |
| Smokey and the Flag | 19 -> 13 | 30.5 -> 35.1 | **52 -> 15** | **3.5 -> 1.2** |
| Hook 'em | 12 -> 12 | 18.5 | **55 -> 8** | **2.1 -> 1.0** |
| The Drive | 18 -> 7 | 18.0 -> 30.0 | **56 -> 8** | **2.7 -> 1.2** |
| Legends | 26 -> 14 | 26.7 -> 30.0 | 40 -> 26 | 1.2 |
| Red River Rivalry | **76 -> 9** | 5.6 -> 26.1 | 50 -> 14 | 2.1 -> 1.0 |
| The Hex Rally | **47 -> 18** | 7.4 -> 13.8 | 34 -> 18 | 1.0 |
| The Tower Lit Orange | **37 -> 18** | 6.4 -> 29.6 | 5 -> 6 | 1.7 -> 1.1 |

30 red findings -> 4. With the measure's final form (the hero moving counts), every scene's longest still
stretch is 4-12 s (Game Day 9, The Season 5, the band 12, Smokey 8, Hook 'em 12, the Drive 7, Legends 11,
Red River 4, the Hex Rally 6, the Tower 6); one red finding left: the Hex Rally is "still 60% of the time" (a
candlelight vigil, calm on purpose; checked by eye).

### Done

* **The cast, as fans in burnt-orange caps** (`cast()`, with a Hook 'em hand): their own tailgate on Game Day
  (the canopy, the grill, a catch across the lawn that bonks Clyde, Bevo walking through); Coach Clyde on the
  season's chalkboard; the sideline at Smokey (ears covered before each shot); the ride on the Texas Star and
  the corny dogs eaten like pac-dots at the fair; the field stormed after the Drive's touchdown and the Rose
  Bowl (Pac-Man on top of the dogpile with the trophy); the candles at the Hex Rally; the South Mall under the
  Tower.
* **The season board in season**: after the rows come in, each game replayed as two helmets clashing and the
  score stamped (an honest L when it was one); the next game's helmets face off, bumping; Bevo pawing; the cast.
* **The chalkboard (out of season)**: the O's are the cast, the X's chase the ball, chalk dust on a touchdown.
* **Red River**: the cast's gondola round the Texas Star (the camera rides with them), corny dogs, the stands'
  halves jumping when their side scores, the Golden Hat carried.
* **The Hex Rally**: the 1941 story told in a crystal ball (the mist, a red candle, 23-0); the cast's candles
  lit from Pac-Man's match, passed along.
* **The Tower**: lit floor by floor from the bottom, a chime each; the sparkler wave across the crowd.
* **Smokey**: a shot every 6 s, a smoke ring each.
* **Sounds**: a `CUES` table like the other shows' (the band's drum, the snap and tackle of every play, the
  card stunt, the chant, the replay); **songs**: the drumline 20 -> 60 s, Hook 'em 29 -> 58 s, the Drive
  32 -> 70 s, the fair 44 -> 87 s (a midway strain, a key change), the Tower a second strain.
* Fixed on the way: `prog` and `lin` were missing (the pipeline caught the Lua errors).

## Ideas

* **Game Day**: a bigger gag at the tailgate (the canopy blowing away, Pac-Man chasing it).
* **The Hex Rally** (still 60%): the crowd swaying with their candles; the ball flashing the 1941 game.
* **The Tower**: a firework spelling TEXAS.
* **Legends**: the sound goes quiet for 26 s in the wall-of-titles half: a bell for each title.
* **The band**: the cast marching in the band (Pac-Man on the big drum).
* **Variety between runs**: none yet.
