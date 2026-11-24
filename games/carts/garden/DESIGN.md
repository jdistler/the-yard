# Garden: the Fairy Garden sings what she grows

Six beds are six instruments, and the tune she hears is the garden she grew (CASTLE.md, "Garden").

## A turn
1. **Plant.** The stick moves the fairy ring (left/right along a row, up/down to the other row; each move plucks
   that bed's note softly). Any right-hand button gives the bed what it wants. The fairy's pouch shows the next
   seed's colour; each planting takes the next colour (rose, gold, sky, lilac, mint, coral), starting one
   colour further on every garden, so where she plants decides which bed gets which colour.
2. **Grow.** Seed (wants water, a drop in a bubble), sprout (wants sun), bud (wants a song, a note), bloom.
   Each care has its own picture (rain cloud, sunbeam, rising notes), sound and log line. After a bloom the ring
   hops to the next bed that still needs a hand. A press on a bloomed flower plays it (`music.cue` of its note,
   it sways, sparkles, and its butterfly flies up). Doing nothing: every 5 s (300 frames) the fairy tends the
   bed herself, so a watcher sees the garden grow.
3. **Evening.** All six bloom: a 1.5 s beat, then the sky turns to dusk (backdrop swap + flash), fireflies come,
   Pip, Moth and Pearl pop up on the hill, and drums and bass join (`music.track` 5, 6). 8 s (480 frames) of
   playing the song; the flowers bounce on their own notes (drawn from `music.step()`).
4. **Bouquet.** The fairy ties the first four colours grown (`bouquet`, e.g. `rose-gold-sky-lilac`), shown big
   for 5.5 s with a new-seed banner if a packet opened. Then morning: bare beds, day sky, drums off, an empty
   arpeggio, ready for the next player. Nothing of the half-grown garden is saved.

## Music (songs.lua)
C major pentatonic over C, Am, F, G, 4 bars of 8 steps, 92 bpm (32 steps, about 10 s). Tracks: 1 pad (slow
chord tones), 2 soft bass, 3 arpeggio, 4 echo of the arpeggio (3 steps late, quiet), 5 evening drums, 6 evening
bass groove. Day is tracks 1-4 and sounds complete with no flower. Beds are C5 D5 E5 / G5 A5 C6 (left to
right, top row then bottom). Each bloom rebuilds tracks 3 and 4 from the bloomed beds and calls
`music.play{keep = true}`, so the song never restarts. Every cue is a pentatonic note of the bed pressed
(sounds are in key whatever she mashes); the stage sounds are short rising pentatonic runs.

## Visitors
Butterflies match the flower colour and land on it (frame-driven), a snail crosses the lawn (from bloom 1,
very slowly), the ladybug rests on a flower and flies to the next (bloom 2), Nib wanders in between the beds and
sniffs flowers (bloom 2), the bee flies a figure eight and squashes on the beat (bloom 3), fireflies at evening.
Rare, one `rnd()` in `init`: a hedgehog in the evening, or a rainbow after three waterings.

## Seeds over visits
Tulip from the start; daisy, sunflower, rose, star-lily, rainbow rose at gardens 1, 2, 4, 6, 9. The shelf along
the bottom shows six packets (padlocked until opened), the next seed glows, and the last bouquet stands in a
vase at the end of the shelf.

## Persistence (garden.sav)
`blooms` (all blooms, the menu stat), `parades` (evenings reached), `gardens` (bouquets tied; Band shows a
flower arch from 3, Tea reads it too), `bouquet` (one word, colours joined by `-`; Tea's vase, Bake's topping).
Saved at each bloom, at evening, at the bouquet, and in `quit()`. Loads are clamped; a bad `bouquet` is ignored.

## Log lines
`garden blooms N`, `garden gardens N`, `garden seed BED COLOUR`, `garden water BED`, `garden sun BED`,
`garden song BED`, `garden bloom BED COLOUR`, `garden evening`, `garden parade N`, `garden bouquet a-b-c-d`,
`garden gardens N`, `garden unlock KIND`, `garden morning`, `garden visitor ladybug|nib|hedgehog|rainbow`,
`garden nib sniff BED`.

## Rules kept
Logic counts `game.frame`; `music.step()` only draws (bounces, lights, drum hits) and picks cue pitch. The only
chance is one `rnd()` in `init`. `bot()` plays a whole garden (every 20 frames) and the evening, reaching the
bouquet at about frame 1050. One backdrop at a time (day or dusk, 768 KB); particles under 100.

## Drawing speed (GPU runtime)
The Mali is fill-rate bound and every shape is a call, so on the GPU runtime (`game.gpu`) the figures are painted
once and copied: blooms (petals and face, three size steps, per kind and colour; let go after 900 idle frames, a
garden's colours are not the last garden's), stalks (per pixel of sway), buds, cats and the unicorn (body, face,
tail in five steps; only open eyes are live), the fairy (wings, dress, face, pouch, wand star), the sun (rays in
twelve turns), and one sheet of small pictures (fireflies, dots, toadstools, packets, butterflies). Every key is a
pose out of a fixed set, never a frame. The C runtime draws everything live, as before.
