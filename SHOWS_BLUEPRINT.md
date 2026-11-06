# The shows' blueprint: rules for a lively scene

What we learned watching the kids watch: they lean in at the transitions (the whole picture changes) and in
scenes where a story moves on (the launch: the count, ignition, liftoff, staging), and drift away when a scene
holds one picture for a minute with a few lights blinking (Mission Control's room, Houston's rocket park). Every
scene in every show follows these rules; `tools/show_pulse.py` measures them.

## The measures (tools/show_pulse.py)

The show is rendered at one frame a second, each frame cut into 32 px blocks.

* **motion**: the share of the screen that changed since the last second.
* **new**: the share of the screen showing something this scene has not shown before. Loops, sways and twinkles
  stop counting once they have gone round once; only the story moving on counts.
* **beat**: a second where 12% of the screen moved or 6% of it is new. Something happened.
* **stale**: the longest run of seconds without a beat. This is the dead time.
* **still**: the share of seconds where almost nothing moved (under 3% of the screen).

## The gates (every scene, after its title card)

| measure | gate | why |
|---|---|---|
| stale | **at most 12 s** | a five-year-old's patience for "nothing happening" |
| beats per minute | **at least 8** | a beat every 7-8 s, the launch scene's pace and more |
| still | **at most 0.35** | the picture is alive two thirds of the time |
| new (mean) | **at least 0.04** | the scene ends somewhere other than where it began |

## The rules

1. **Every scene is a story, not a picture.** It starts in one state and ends in another the kid can see:
   the room goes from dark to every console lit, the basket from empty to full, the rocket from the pad to
   orbit. Write the scene as 4-6 *chapters* of 8-15 s, each one changing the picture.
2. **Progress lives in the world.** No bars, no counters on top: show it as things piling up, lighting up,
   filling in, being built, travelling along a road the kid can see. A kid who walks in mid-scene can tell how
   far along it is.
3. **A hero with a job, always on screen.** One character moving with purpose (walking somewhere, carrying,
   chasing, building), not swaying in place. When the hero finishes a job, the next one starts.
4. **Three layers of life.** The background always breathes (clouds, water, stars, lights); the middle has the
   supporting cast doing their own little loops and gags; the front has the hero's action. A painted picture
   never stands alone for more than 3 s.
5. **Cause and effect you can see.** Things react: a splash when something lands, sparks when it clicks,
   the ghosts' heads turning to follow the action, the crowd jumping on the touchdown.
6. **The camera moves too.** Transitions are what the kids love, so bring them inside the scenes: every
   20-30 s a push in, a pan to the next place, a cut to a close-up (the button being pressed, the face), then
   back. A scene is two or three shots, not one.
7. **A gag in every scene.** One surprise a kid will wait for the next time round: a ghost who gets it wrong,
   something falling, a sneeze, a peek. Set it up, then pay it off.
8. **The big finish.** The last 8-10 s of a scene are its biggest moment (the poll's final GO, the parachutes
   opening, the touchdown), and the transition follows straight from it.
9. **On the music.** Lights, bounces and the crowd move on the song's beat; the chapters land on its phrases.
10. **No reading needed.** Words are a bonus for grown-ups; every story beat is told in pictures first.
11. **Variety between runs.** A seed picks among two or three versions of a gag or a chapter, so the tenth
    watch has something the ninth did not.
12. **The cabinet decides.** 55-60 fps on the cabinet, its GPU memory freed at the show's end, or it does not
    ship. Particles in showlib's batches; pictures painted once.

## How a scene is written

```
SCENE  (length)       the story in one line: from ... to ...
  0-5   title card    the place, the cast arriving
  ch1   ...           first job; what changes on screen
  ch2   ...           the camera moves; a new thing appears
  ch3   ...           the gag set up
  ch4   ...           the gag pays off; the job nearly done
  end   ...           the big finish; the transition
  layers: back / middle / front
```

**The night sky is the exception.** It plays while the house sleeps (10 PM to 8 AM), dark on purpose. Its gates
are gentler: stale at most 30 s, a small story every 20-30 s (the chase catches someone, a meteor lands, the
UFO takes and gives back), but no flashing and nothing big.

**Motion is not story.** A disco floor flashing or a flag waving moves the screen all the time and still tells
nothing (New Year's party and midnight score high on motion, low on new). The "new" gate is what catches it.

## Lessons from the rebuild (2026-11-05/06)

* **Big soft smoke and fog under a zoomed camera are expensive.** Halloween's graveyard fell to 49 fps on the
  cabinet with fog puffs (size 30, 20 a second) at zoom 1.5; size 22 at 6 a second holds 60. Keep puffs few and
  small, and check every show on the cabinet after a camera change.
* **A painted backdrop must not paint what the story builds.** Leaf piles, lit windows, the feast, the donuts,
  the brisket: paint the empty place and build the thing live, or the progress cannot show.
* **Titles and captions are on the screen, not in the picture.** showlib draws plates and captions after the
  camera; hold a wide shot for the first ~9 s while the title is up, or the title lands on a zoomed sign.
* **Black backgrounds hide motion from the measure** (and from kids across a room): small dots on black read as
  "nothing happening". Give the scene something that fills in (a heart filling, a wall drawing itself).
* **A second round must look different** (a maze, a power pellet, the ghosts chasing): repeating a loop scores
  no "new" and bores the second time.
* **The night sky is checked by eye**: at its scale twinkling stars and its small stories look the same to the
  measure (show_pulse's gentle thresholds for "night" are a floor, not a gate).

## Lessons from the pipeline's first round (2026-11-06, Texas, Longhorns, Summer, Mission Control)

* **Measure the world, not the camera.** A camera drifting over a still painting scores as lively as a battle:
  San Antonio scored 60 beats a minute with the camera and 7 without it. `show_review.py` measures with the
  camera held still, through the camera's view.
* **The hero is a sixth of the screen.** Most of the cast was drawn at radius 24-30 (about 60 px on a 1024 px
  screen): a story told by things that small reads as nothing from the couch. The trace records the biggest of
  the cast each frame (`cast px`); under 85 px is a finding. Scaling the cast up 30% and bringing the camera in
  did more for the Moon and Barton Springs than any new story would have.
* **A sound that doesn't exist is silent, and nobody notices.** `"tick"` was asked for in three scenes and never
  played. The review checks every sound against `songs.lua`.
* **A song as long as its scene.** A 20 s loop under a 70 s scene is heard three times; write B and C parts (or a
  key change on the repeat: `"C+2"`) until the song is the scene's length.
* **Live data needs fixtures.** The Longhorns' season board plays all season from ESPN's schedule, and the PC
  had never seen it: rendered with `--env HOME_UT_SCHED=tools/show_fixtures/ut_sched.json`, it was a still table
  for 38 s. Review every path a scene can take.
* **Character comedy is quiet to the measure.** A hop, a tray sliding, a calf on a rope are real beats that move
  a few percent of the screen. A stretch of 8-15 s is checked on the film strip before it is "fixed".
* **The cast belongs in every show.** The Longhorns show had no Pac-Man or ghosts at all: no hero. In caps, as
  fans, they tailgate, ride the Texas Star, carry the Golden Hat, light the candles and storm the field.

## Where the shows stand (2026-11-06)

Every show rebuilt to these rules, measured on the PC and checked at 57-60 fps on the cabinet: Mission Control,
Thanksgiving, Christmas, New Year's Eve, Texas, Summer, Halloween, Egg Hunt, Sweethearts, Longhorns (its
off-season board now a chalkboard of plays and a countdown); the Freedom Show already passed. The night sky
has small stories in its thinnest scenes (shooting stars, a fireball, the digger's treasure, the night train,
the UFO giving its ghost back). `python3 games/test.py shows` is the gate: no scene more than 15 s still.

## What the measures found (2026-11-05, every show, start to end)

12 of 89 scenes pass. The Freedom Show passes all eight: something happens every 1-3 s, and the story moves
(dawn, the flag, the eagle, the alert, the invaders, the battle, the pellet, the victory). It is the model.

Most other scenes share the same five problems:

1. **A painting with small things on it.** A big painted backdrop, and the cast as 20-40 px sprites along
   the bottom edge. On the cabinet's screen the cast is too small to follow and the painting never changes.
2. **One shot.** The camera never moves, so a 60-90 s scene is one picture.
3. **The story is there but too slow or too small to see.** The egg basket fills, the resolutions get
   checked, the ball comes down, the pies get eaten, but in steps a kid cannot see from the couch.
4. **Long title cards at the end.** HAPPY HALLOWEEN holds still for 65 s, SUMMER 40 s, MERRY CHRISTMAS 35 s.
5. **Off-season and data scenes** (Longhorns' season board, out of season) show text and nothing else.

## The catalogue

Per scene: its measure now (stale s / still / beats a minute), what is on screen, and the scene as it should
be, in chapters. ✅ passes, 🟡 close, 🔴 dead time.

### Mission Control (space) — the kids' favourite, and the pilot

* 🔴 **Houston** (59 s / 0.90 / 3.6). The Saturn V lying in its shed, seven tiny visitors. *Make it:* a field
  trip. A school bus pulls in, the ghosts pile out in a line behind Pac-Man, walking the rocket's length from
  the engines to the nose (the camera pans with them, the rocket is 363 ft: they are ants beside it). A ghost
  climbs into an F-1 engine bell and his eyes peek out; the guide points; a little NASA tram goes by; at the
  nose they look up: CUT to the sky, a jet's contrail, and they run for the bus: "To Mission Control!"
* 🔴 **Mission Control** (57 s / 0.95 / 3.7). The room, the map, four ghosts at consoles, the poll typed on.
  *Make it:* the room wakes up. Chapter 1: dark room, the lights come on bank by bank with a clunk each,
  the consoles boot (screens fill row by row), the big map draws its continents. Chapter 2: the cast walks in
  with coffee (one spills), sits, headsets on. Chapter 3: the poll as the show it is: the camera moves along
  the consoles, each controller in close-up turning to say GO with a green lamp lighting over their head and
  on a big GO/NO-GO board (BOOSTER... CAPCOM), one ghost asleep (NO-GO? he is nudged, wakes: GO!). Chapter 4:
  the flight director, close up, stands: "WE ARE GO FOR LAUNCH", every lamp green, the room jumps, the
  big screen cuts to the pad and the clock starts: T-MINUS 60 counting into the launch scene.
* 🟡 **Launch** (30 s / 0.48 / 26). The best scene already: the count, ignition, liftoff, staging.
  *Make it:* fill the 30 s hole after staging: the second stage lights, the fairing splits, the Earth's
  curve grows, the stars come out, a camera on the rocket looking back at the falling stage; a cut back to
  the room cheering between.
* 🔴 **Orbit** (37 s / 0.24 / 7.8). The station drifts across, an astronaut on a tether. *Make it:* a job
  outside: Pac-Man floats out, fixes a solar wing (it unfolds, sparkles, the station's lights come on), a
  ghost's wrench floats away and he chases it, the sunrise over the edge, Texas goes by (the Gulf, a label
  as it passes), a pizza floats in the window. The station gets visibly more lit and complete.
* 🔴 **The Moon** (76 s / 0.76 / 2.8). Earthrise, the lander, a hop, two flags. *Make it:* the landing
  itself first (the lander coming down, dust blowing, the legs touching, "THE EAGLE HAS LANDED"), the hatch,
  the ladder, the first step leaving a print that stays, big slow hops with a long fall, the rover
  unfolding and driving off with bounces, a golf shot that never comes down, footprints filling the ground
  as the scene goes on, Earthrise behind, and lift-off of the top half at the end.
* 🔴 **Splashdown** (39 s / 0.67 / 5.6). Three parachutes, the ocean, the helicopter. *Make it:* re-entry
  first (the capsule glowing through the sky, the drogues, then the three mains blooming one, two, three,
  close), the splash big, the dye spreading green, the frogmen's raft, the collar inflating, the helicopter
  lifting the crew one by one, the carrier's crowd waving.
* 🟡 **Party** (29 s / 0 / 6.9). *Make it:* confetti from the ceiling, the flags waved, the big screen
  showing the trip again (a 10 s replay of the launch, the Moon, the splash), cigars of candy, Pac-Man lifted.

### Texas — a painting per place (all 🔴 but the finale)

* **Gulf Coast** (54 s / 0.95). Sunrise, the pier, tiny boats. *Make it:* sunrise as a story (dark to gold,
  the beach waking: a shrimp boat out with gulls behind it, pelicans diving and coming up with fish, a
  sandcastle built tower by tower by the ghosts, a wave that takes it, a kite).
* **Hill Country** (46 s / 0.93). Bluebonnets, oaks. *Make it:* a walk through: the camera along a road,
  bluebonnets thickening, the family photo in the flowers (every Texan's), the armadillo crossing, a
  mockingbird, monarchs lifting in a cloud as Pac-Man walks through.
* **Round Rock** (14 s / 0.88). The rock, then a donut box. *Make it:* the cattle crossing at the rock (the
  Chisholm Trail), then the donut box filling one by one and being eaten.
* **Austin** (59 s / 0.87). The Capitol up Congress. *Make it:* down Congress Avenue: traffic, the taco
  truck's line, a band on a stage, scooters, the camera rising up to the dome at the end.
* **Fort Worth** (51 s / 0.33). The cattle drive, small. *Make it:* the drive big, close, longhorns filling
  the street, cowboys, a calf that wanders off and is brought back.
* **San Antonio** (26 s / 0.80). The Alamo still. *Make it:* the River Walk at dusk: boats, lights strung
  coming on, mariachis.
* **Barbecue** (27 s / 0.91). Smoker and paper. *Make it:* the pit opened (smoke billows), the brisket
  sliced slice by slice onto the paper, the line, a ghost with sauce on his face.
* **Panhandle** (44 s / 0.85). *Make it:* the supercell growing over the canyon, the windmill speeding,
  tumbleweeds, a train across the plain, a lightning strike far off, the sunset colours walking down the canyon.
* **Bats** (37 s / 0.96). *Make it:* the crowd on the bridge waiting, the first bat, then the river of a
  million and a half pouring out in a ribbon across the sky (a particle stream), the crowd's "ooh".
* **Big Bend** (59 s / 0.98). *Make it:* the Milky Way rising, shooting stars, a campfire with the cast
  telling stories, the Marfa lights dancing and teasing them.
* ✅-ish **Lone Star** (14 s). Keep; add fireworks over the flag.

### Longhorns

* 🔴 **Game Day** (56 s / 0.83). The Tower, tiny tailgates. *Make it:* the campus waking: the Tower's clock,
  tailgates setting up tent by tent, the grill smoking, Bevo walked through, a crowd growing to a river
  heading to the stadium.
* 🔴 **The Season** (53 s / 0.95). Out of season: a text board. *Make it:* the board animates each game
  as a little play (helmets clash, the score flips), out of season the highlights of last season, a
  calendar counting down days to kickoff with Bevo pacing.
* ✅ **Band**, 🟡 **Smokey** (13 s / 0.35). Close: add the cannon's smoke ring and the tunnel run close up.
* 🔴 **Hook 'em** (41 s / 0.07). *Make it:* the card stunt built row by row, the wave going round.
* 🔴 **The Drive** (19 s / 0.75), **Legends** (30 s). Good stories; tighten the gaps between plays with the
  crowd and the band reacting, a camera that follows the ball.
* 🔴 **Red River** (44 s), **Hex** (37 s), **Tower** (37 s / 0.82). Big Tex waving and talking, the Texas
  Star turning with riders; candles lit one by one across the Mall; the Tower lighting floor by floor.

### Summer

* 🔴 **Lake Travis** (68 s), **Barton Springs** (56 s), **Snow cones** (46 s / 0.93), **Tubing** (66 s),
  **Fireflies** (74 s). The same shape: a painting, tiny swimmers. *Make it:* the cannonball as the big
  finish, wakes and a skier, a chain of tubes linking up and drifting past close; the snow cone built
  colour by colour as it melts and drips, ending in a brain freeze; jars of fireflies filling.
* 🟡 **Storm** (27 s). Closest: the clouds rolling in, the first drops, the downpour, the rainbow.

### Halloween

* 🔴 **Haunted house** (67 s), **Trick or treat** (77 s), **Graveyard dance** (67 s, motion but no story),
  **Witch** (57 s), **Happy Halloween** (64 s / 0.98). *Make it:* the house's windows lighting one by one
  with a new face each, the door creaking; the trick-or-treaters' bags filling, the doors at each house
  opening to a different gag; the dance building (one skeleton, then two, then the whole yard, a conga);
  the witch's potion changing colour as ingredients go in; the finale's pumpkins lit one by one, then a
  ghost parade.
* ✅ **Lights out**. Keep.

### Thanksgiving

* 🔴 **Parade** (21 s, close), **Turkey chase** (68 s), **Autumn** (47 s), **Table** (55 s / 0.93),
  **Football** (48 s), **Pie** (36 s). *Make it:* the balloons bigger and closer; the chase with the turkey
  hiding in new places (the barn, the hay, behind the cow); leaves piling up and a leap into the pile; dishes
  passed hand to hand along the table and the plates filling, the turkey carved slice by slice; the TV game
  with the family jumping on a touchdown; the pies eaten slice by slice with crumbs.

### Christmas

* 🔴 **Cul-de-sac** (83 s / 0.95), **Sleigh** (67 s), **Texas Christmas** (66 s), **Tree** (66 s),
  **Cookies** (46 s), **Silent night** (93 s / 0.97), **Merry Christmas** (34 s). *Make it:* the lights
  going up on the house string by string (the switch, the flicker, ON); the sleigh landing on a roof and
  presents going down; the tree trimmed ornament by ornament and the star last; the cookie plate emptying
  and crumbs pointing at the guilty ghost; silent night with the town's windows going dark one by one and
  Santa crossing the moon.

### New Year's Eve

* 🔴 **Resolutions** (74 s / 0.92). The list written and checked too small to see. *Make it:* each
  resolution acted out (EAT MORE POWER PELLETS: a pellet eaten; STOP CHASING PEOPLE: a ghost trying not
  to), then checked big.
* 🔴 **The ball drop** (85 s / 0.98). The ball sits still until the last seconds. *Make it:* the ball
  lowers the whole scene long, the crowd growing, the clock ticking, the last ten huge.
* 🔴 **Midnight** (motion, no story), **Auld lang syne** (87 s). Fireworks building to a finale; sparklers
  lit one from the next down the line.

### Egg Hunt

* 🔴 **Hunt** (48 s), **Dye** (46 s), **Cascarones** (66 s / 0.93). *Make it:* eggs found big, one by
  one (a ghost finding a rock), the basket full; eggs dipped and lifted out new colours, the row of dyed
  eggs growing; cascarones cracked with a burst of confetti each.
* 🟡 **Bunny** (28 s), **Secret level** (27 s). Close.

### Sweethearts

* 🟡 **They meet** (22 s), **Card** (34 s). 🔴 **Candy hearts** (49 s), **Date night** (69 s),
  **Heart of dots** (40 s). *Make it:* the jar filling as hearts tumble in big; the milkshake drained
  sip by sip with the others pressing faces to the window; the dots eaten faster with sound.

### Night Sky (its own gentler rules)

* Dusk, Starfield, Meteors, the Digger, Dawn: 85 s without a beat; the Chase, Swarm, City, UFO, Dreams:
  around 80 s. The sprites are small and few. *Make it:* every 20-30 s a small story: the chase ends with a
  power pellet and the turn, the UFO beams up a ghost and gives him back, a meteor lands and something
  climbs out, the digger finds treasure. Calm colours, no flashing.

## The plan

1. **Tools first.** `tools/show_pulse.py` (done) as a gate in the test suite, so a scene that goes dead
   fails. Add to showlib: a camera (push in, pan, cut, shake), characters at a size you can see (a hero at
   a sixth of the screen's height), a crowd that reacts, and "progress props" (a thing that fills, lights,
   piles up, is built).
2. **Mission Control first**, all seven scenes, as the pilot. Watch the kids watch it.
3. Then show by show, the calendar's next first: Thanksgiving (later this month), Christmas, New Year's, Texas, Summer, Halloween, Longhorns, Easter, Sweethearts, the night.
4. Every scene measured on the PC and the show checked at 55-60 fps on the cabinet before it ships.
