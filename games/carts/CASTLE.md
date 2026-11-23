# The Castle: Tea, Garden, Bake, and Band as one world

Four carts in the little band (CONTROLS.md) share a cast (the Unicorn; Pip, Moth, Pearl, and the kitten Nib) and
a place: Starlight Castle. Tea came first and came from the player herself, a four-year-old: "a unicorn is flying
to a tea party at the princess castle, the party is full of kitty cats, and you play with them and take care of
them" (tea/DESIGN.md). Garden, Bake, and Band were added later as one-note toys: a press makes the next thing
happen, the song is one loop that ignores her, and nothing she does outlasts the turn.

This note makes them one world with depth, without making them harder.

## What depth means at four

Not more rules, more buttons, or anything to read. Depth here is:

1. **Her choices show.** What she picked (a colour, a friend, a flower) is on the screen afterwards, and later
   somewhere else in the castle.
2. **The world answers.** Every press, every stick move, and doing nothing at all each get their own reaction.
   Characters look at her, remember her, have moods and small habits.
3. **She makes the music.** The song is built from what she does. Her presses are notes in key and on the beat
   (`music.cue`), her progress brings instruments in (`music.track`), and finishing turns the verse into a
   chorus (`music.play{keep = true}`). Mashing must always sound like music.
4. **Something new each visit.** A new seed, a new song, a new friend in the audience, a rare visitor. Saved
   between visits, shown on screen, never taken away.
5. **The castle is one place.** Each cart writes what she made to its own save; the others read it with
   `save.peek` and put it on screen. If the other cart was never played, nothing is missing: the default is a
   plain, complete picture.

## Ergonomics (unchanged, and they win any argument)

Read CONTROLS.md's little band. In short:

* The stick is 4-way. Every direction does something useful. Left/right and up/down may mean the same thing.
* Every right-hand button (LOW, TL, TR) does the care. No chords. 1P and 2P are never gameplay; 1P+2P held
  is goodbye.
* The first press succeeds. There is no way to lose, fail, run out, or make anyone sad. No timers that punish.
* Doing nothing is still play: the world moves, idles, and finishes things slowly by itself.
* The picture is the instruction. A cream band at the bottom (`ui.band`) carries one short line a grown-up
  can read out. She never has to read.
* A held button repeats gently, at most once every ~0.35 s (no runaway).
* A turn ends in a state the next child can start from.
* Readable at a glance on the cabinet: big shapes, strong outlines, high contrast, faces with expressions.

## The shared save keys (what each cart writes; others may read)

| Cart (save) | Key | Value | Read by |
| :--- | :--- | :--- | :--- |
| garden | `bouquet` | one word: up to 4 flower colour names joined by `-`, the last garden's (e.g. `rose-gold-sky-lilac`) | Tea (the vase), Bake (a flower topping) |
| garden | `gardens` | gardens finished | Tea, Band (a flower arch on stage after 3) |
| bake | `last` | one word: the last treat, `kind_flavour_frosting_topping` (e.g. `cupcake_berry_pink_star`) | Tea (the cupcake ask shows it) |
| bake | `treats` | treats served | Tea (cake stand fills up) |
| band | `tunes` | songs learned (1..4) | Tea (the party song is the newest learned tune) |
| band | `fans` | audience size | |
| tea | `visits`, `photos` | as today | Band (photos on the stage wall), Bake (a party order) |

Keys are lower case. Values are a number or one word of letters, digits, `_ - .`, at most 32 characters.
Clamp what you read. Never write another cart's save (the API can't, and that is on purpose).

## Hard rules for the code

* **Game logic must not read `music.step()`.** The tests run every cart's bot on the C runtime and on LÖVE and
  require the same log lines and the same save file; the music clock differs between them. Use `game.frame`
  and your own counters for logic. `music.step()` is for drawing (bounces, lights, dancing) and for picking the
  pitch of a `music.cue` (sound only).
* Randomness: use the cart's seeded generator as the cart already does (`rnd`), never `os.time`.
* `log()` the moments that matter (a stage reached, a song learned) as short lines the tests can read.
* A `bot()` that plays a whole turn under `CAB_AUTOPLAY` and reaches the big moments.
* Save at the moments that matter and in `quit()`. Clamp loads. A missing or broken save opens fresh.
* Performance (RK3032, Mali-400, fill-bound): static scenery in `backdrop()`, no per-frame tables in hot loops,
  particles under ~150, no full-screen gradients redrawn each frame. Check `./cart check <id>` image memory.
* Sound: `sfx.limit(8000)`, `sfx.master` about 0.3. Music under the effects. Up to 6 tracks, 128 steps.
* Pictures in `pictures.lua` (look at `tea/pictures.lua` for how the cats and the Unicorn are drawn: Band,
  Bake, and Garden should draw the same characters the same way, with the same colours, so it is one cast;
  copy the drawing code in, a cart can only import its own files).

## Garden: the Fairy Garden sings what she grows

Now: six beds, a ring she moves, a press grows the bed a step; a full garden plays a song, then clears.

Make it:

* **Beds are instruments.** Each of the six beds has its own pitch in a pentatonic scale. A bloomed flower adds
  its note to the garden's song: rebuild the song's arpeggio track from the bloomed beds and
  `music.play{..., keep = true}`, so the tune she hears *is* her garden. A press on a bloomed flower plays it
  (`music.cue` at the next step) and it sways and sparkles.
* **Real growing.** Seed, sprout, bud, bloom, each its own picture and sound, and a picture over the bed of what
  it wants next (a water drop, the sun, a little song note). A press gives it. Doing nothing: the fairy
  sprinkles slowly by herself, so watching still grows.
* **Her colours.** The stick stays for moving between beds (left/right along a row, up/down between rows). The
  fairy's seed pouch shows the next seed's colour, and each planting takes the next colour in a gentle cycle.
  Which bed gets which colour is her choice, made by where she goes. Every button still plants.
* **Visitors.** Butterflies match flower colours and land on them; a ladybug, a snail, a bee that buzzes on the
  beat. A rare one on some visits (a hedgehog, a rainbow after the sprinkle rain). Nib wanders in and sniffs
  flowers.
* **Evening.** When all six bloom: the sky goes to dusk, fireflies come, the drums and bass come in
  (`music.track`), and the garden plays its whole song while the flowers bounce in time (draw only). Then the
  fairy picks a bouquet of four (saved as `bouquet`), the beds rest, and morning comes for the next player.
* **New seeds over visits.** Tulip from the start; daisy, sunflower, rose, star-lily, rainbow rose unlock at
  gardens 1, 2, 4, 6, 9. Show the seed packets on a little shelf.

## Bake: the Royal Kitty Bakery serves real customers

Now: pick one of four flavours, press through five steps, a cupcake appears, repeat.

Make it:

* **A customer at the counter.** Pip, Moth, Pearl, Nib, or the Unicorn walks in with a picture bubble of what
  they would love (a pink cupcake with a star). It is a suggestion. Whatever she makes, they are delighted.
  If it matches, they do their special happy dance.
* **Every step is a little play, and builds the song.**
  * Mix: each press stirs, the batter swirls and rises; a shaker track comes in.
  * Bake: the treat rises in the oven window; the stick peeks (the oven light), a ding; the bass comes in.
  * Frost: the stick chooses the colour on big swatches (the customer's wish glows); a press swirls it on;
    the melody comes in.
  * Sprinkle: each press rains sprinkles, each a `music.cue` twinkle on the step; bells come in.
  * Topping: cherry, star, heart, strawberry, and her Garden flower (from `bouquet`, if she has grown one).
  * Serve: slide it across the counter; the customer reacts in their own way (Pip licks, Moth's whiskers
    wobble, Pearl takes a dainty bite, Nib copies whoever came before, the Unicorn sparkles). Full chorus.
* **Kinds over visits.** Cupcakes first; cookies after 3 treats, a layer cake after 8, a castle cake after 15.
* **The display case.** The last six treats she made stand in the window, as she made them (saved as words),
  so the bakery fills up with her work. Save the newest as `last`.

## Band: the Starlight Stage, where she conducts

Now: four circles with ears, the press plays the next melody note, a one-track bass bed.

Make it:

* **Each friend is an instrument with its own track.** Unicorn: melody (harp/triangle). Pip: drums. Moth:
  bass. Pearl: bells (arpeggio). Nib: claps and shaker. The song starts with only a soft pad. The stick moves
  the spotlight; a press on a quiet friend wakes them and their track comes in (`music.track`); they play their
  instrument in time (draw from `music.step()`). A press on a playing friend is a solo: a note from the chord
  under the current step, on the next step (`music.cue`), with a jump and sparks. Mashing is a solo, never noise.
* **The chorus.** All five playing: `music.play{keep = true}` into the chorus arrangement, stage lights swing,
  the audience dances. After the chorus runs its course: the big finish, a bow, "new song learned" if it was
  new (`tunes`), confetti.
* **Four songs, learned over visits.** A lullaby, a march, a disco-funk, a waltz (or other clearly different
  feels), each a real arrangement with verse and chorus, written to sound good with any subset of tracks
  playing. Songs she has learned are on the setlist board; the stick on the board picks one between songs.
* **The audience.** Little fans (bunnies, birds, fireflies) take seats as she plays, saved as `fans`, and stay.
  After Tea photos exist (`save.peek("tea", "photos", 0)`), they hang on the stage wall.
* **Real characters.** Draw the cast as in Tea, with instruments: Pip's drum kit, Moth's big upright bass,
  Pearl's bells, Nib's tiny tambourine, the Unicorn's harp.

## Tea: the party collects the castle (careful: it is her favourite)

Tea is good and loved. Change it gently and additively; do not change its controls, pacing, or its flight.

* The vase on the table holds her Garden `bouquet` colours when there is one.
* The cupcake ask shows her last Bake treat (`last`) when there is one.
* The song after the cheer is her newest Band tune (`tunes`) when she has learned one, played with
  `music.cue` on the beat over a soft bed, so the notes land in time.
* The flight's music layers in as treats are caught (`music.track`).
* Keep every existing test passing and its save keys as they are.
