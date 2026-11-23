# The adventures: depth for Dig, Chest, Safari, Keep, Chomp, Star Kart, Tower, and Starship

Companion to CASTLE.md (the little band's four). These are the walk-up band (CONTROLS.md): a five-year-old and up,
with grown-ups and older kids taking turns. Dig, Chest, Safari, and Keep are the ones the kids pick most
(the cabinet's play counts, 2026-11-23); Chomp, Star Kart, Tower, and Starship are new.

They play fine. What they lack is what makes a child come back: a reason, a world that answers, music that is
part of the play, and something that grows between visits. Read CASTLE.md's "What depth means", "Hard rules for
the code", and its ergonomics: all of it applies here, with the walk-up band's controls instead of the little
band's (a round can end; the reason is on screen; failure is soft and the retry is instant).

## What every one of them gets

1. **A reason, told in pictures.** A one-screen story at the start (a few seconds, skippable with any button,
   never read-only: pictures carry it, the cream band says one line), a goal you can see, and a payoff
   picture. Not a cutscene: something the child understands in two seconds.
2. **Music that plays the game** (CARTS.md, interactive music):
   * Layers follow the action with `music.track`: calm when safe, the drums and bass when danger is near,
     the lead when you are on a streak, everything at the climax.
   * The player's verb is an instrument with `music.cue`: each pump, catch, hit, or bubble a note from the
     chord on the beat, rising through a run so a streak is a melody. Big moments are stingers on the bar.
   * Sections change without a restart (`music.play{keep = true}`): a boss arrives and the song turns.
   * Each game a real arrangement: chord progression, a bass that follows it, a groove, a hook.
     Up to 6 tracks, 128 steps; write each part so the song is good with any subset of layers on.
3. **A world that answers.** Characters react to the player (look at them, cheer, sulk, taunt, celebrate);
   near misses get a reaction; idling gets an idle animation; every event has its own small sound and picture.
4. **Something that grows between visits,** saved and shown: a collection, a map that fills in, a trophy
   shelf, unlockable looks or levels. Never taken away. Home's card reads `info.stat`, so keep it valid.
5. **Detail.** Backgrounds with depth (cached in `backdrop`), animated characters with expressions,
   particles that fit, screen shake used sparingly, readable at 384x512 (or the cart's size) on the cabinet.

## Rules (in addition to CASTLE.md's)

* Keep the controls each game has now (CONTROLS.md; the previous audit already fixed them). Do not add a
  second verb a five-year-old has to coordinate.
* Do not make it harder. If anything, the first minute gets easier and the depth arrives with play.
* Keep existing save keys and their meaning; add keys freely. Keep the tests in `games/test.py` about each game
  passing unchanged (grep for the cart's id); keep `CAB_AUTOPLAY` bots reaching the big moments.
* Performance on the cabinet matters: these run on LÖVE on a Mali-400. Aim for the frame-drawn rate to stay
  over ~40 fps: no full-screen alpha layers stacked every frame, batched glows, particle caps. `unbake` what
  you stop using.
* Homage is fine; names and pictures must be our own (no real Pokémon, Nintendo, or Namco names).

## Each game

**Dig** (most played; Dig Dug homage). A story: the critters have carried off the veggie garden into the caves;
each cave cleared brings a veggie home, and a little garden map between caves fills up row by row, with a
big harvest party every five caves. The pump is an instrument: each pump a step up the scale on the beat,
the pop a chord. Danger layer when a critter is close, a calm layer when tunnelling alone, the "last critter"
section switch. A rare golden veggie. Gems shown on a shelf.

**Chest** (most played; carefully designed, see chest/DESIGN.md: be additive, like Tea). Music: the path's song
gains a voice for each gold fairy following him (they are his band); the duels change section by phase
(`keep`), and each sword hit is a note of a rising run. A treasure room for the gems he has won, visible at
the start of each visit, that fills over visits. Do not lengthen duels; you may shorten the very first duel
of a fresh save a little.

**Safari** (most played). A journey: three habitats, three gyms, a guide character (our own, e.g. an owl
ranger) who gives one-picture goals; the dex as a picture book that fills in; a rare shiny variant of each
friend. Music per habitat with a layer for each friend in the party; the catch jingle on the beat; gym music
that intensifies as the gym leader's strength drops. Buddies follow you on the map.

**Keep** (most played; Pip catches fruit). Seasons as rounds (blossom, summer, harvest, snow) with the orchard
repainted for each; a pantry shelf that fills with jars (saved) and a special fruit per season. The catch run is
a melody (each catch the next note of the tune, on the beat); the multiplier brings layers in; a miss drops a
layer, gently.

**Chomp** (new; maze homage). A story (Chompy collecting the stars the ghosts scattered); maze themes that
change; ghosts with personalities in their faces; music that speeds and layers with dots eaten, a section
switch when the ghosts turn blue, the dot-eating sound as a rhythmic part of the song.

**Star Kart** (new). A cup with a map; rival racers with faces and names of our own; the music's layers by
race position and boost; a finish-line fanfare; trophies on a shelf; unlockable kart paint.

**Tower** (new; climbing homage). Big Grumble's story in pictures; floor themes; the climb as a rising song (each
floor a key change or a new layer); rescues collected in a picture gallery.

**Starship** (new; split-hands co-op). A voyage map of worlds; rescued star-creatures that join a crew picture;
the pilot's catches and the co-pilot's pops as two interlocking instruments on the beat (a duet, so the
two players hear themselves together); a team bonus when both score close together.
