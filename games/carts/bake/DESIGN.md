# Bake: the Royal Kitty Bakery serves real customers

A friend from the castle walks in with a picture of what they would love, and every step of making it is a layer
of the kitchen song (CASTLE.md, "Bake").

## A turn
1. **A customer.** Pip, Moth, Pearl, Nib or the Unicorn slides in; a thought bubble shows a treat (kind, frosting
   colour, topping). It is only a suggestion: whatever she makes delights them, a match earns the special dance.
   Order: a fixed cycle (stepping two round the five) from one `rnd()` in `init`; wishes from our own
   Park-Miller generator, so nothing depends on call order.
2. **Pick** (only once a second kind is open): kinds on the tray, the stick moves, a press picks. Cupcakes only
   at first, so a new player never sees this step.
3. **Mix** (3 presses): the bowl swirls, the batter rises; the stick picks the flavour (berry, honey, cocoa, cloud)
   and the batter changes colour live. Shaker track comes in.
4. **Bake** (2 presses): put in, the door shuts, the treat rises in the window and the oven clock turns (66
   frames, counted in frames); the stick peeks (door opens a crack, light, a note); DING; a second press takes it
   out. Bass comes in.
5. **Frost** (2 presses): five big swatches along the counter, the wish glows and has a star. The frosting on the
   treat takes the highlighted colour live; the second press locks it. Melody comes in.
6. **Sprinkle** (3 presses): the stick moves the jar left, middle, right; each press rains sprinkles and three
   rising `music.cue` twinkles on the step. Bells come in.
7. **Topping** (1 press): cherry, star, heart, strawberry, and a flower in her Garden colours when `garden.bouquet`
   exists (the next colour of the bouquet each treat). It hovers over the treat, then drops.
8. **Serve** (1 press): the treat slides to the counter in front of the customer, the song swings into the chorus
   (`music.play{keep = true}`, every track in, drums too), and the customer reacts in their own way for about
   2 s: Pip licks his lips, Moth's whiskers wobble, Pearl takes dainty bites, Nib copies whoever came before
   (a small copy of them stands beside him), the Unicorn sparkles. The Unicorn with a party hat and Pip and Moth
   is the party order. A match adds the dance (bounce, sway, gold ring, hearts, confetti). The treat then flies to
   the window, and the next friend walks in. A turn is about 12 presses, 20 to 40 seconds.

## Kinds over visits
Cupcake from the start; cookie at 3 treats served, layer cake at 8, castle cake at 15 (`bake unlock KIND`, a NEW
plaque). Locked kinds show a padlock on the Pick tray.

## The window
Her last six treats, as she made them, newest on the left; they slide along when a new one lands. Painted once per
word with `bake()` and blitted (no per-frame work). The awning bulbs are the song meter: one lights as each layer
comes in and all flash on the beat in the chorus.

## Doing nothing is still play
After 3.5 s of no input Nib pops up at the counter and helps, one move every 2/3 s: he turns the tray to the
customer's wish, then does the next step. A watcher sees a whole treat, usually a match, in about 18 s. Any input
sends him away. First press always works; presses are edges (a held button repeats once every 0.6 s).

## Music (songs.lua)
C major over C, Am, F, G, 4 bars of 8 steps, 104 bpm. Tracks: 1 hum (pad, always), 2 shaker, 3 bass, 4 melody,
5 bells, 6 drums (chorus only). The chorus has its own melody, busier bass and bells; same length and tempo, so
it swings in at any step. After the reaction the verse comes back (`keep`), tracks 2-6 off, for the next treat.
Every cue is a chord tone of the bar it will land in (`songs.cue_note`, read from `music.step()` for pitch only),
so mashing is always in key.

## Persistence (bake.sav)
`treats` (menu stat; unlocks), `last` (one word `kind_flavour_frosting_topping`, e.g.
`cupcake_berry_pink_star`; a flower is `flowerlilac`; Tea shows it), `s1`..`s6` (the window, same words). Saved at
every serve and in `quit()`. Loads are clamped; a word that is not one of ours is skipped, so a broken save opens
fresh. Read: `garden.bouquet`, `tea.photos` (party order as every 5th customer's 3rd, only when photos > 0).

## Log lines
`bake treats N`, `bake customer NAME|party`, `bake wish kind_frost_top`, `bake kind K`, `bake mix FLAVOUR`,
`bake oven in`, `bake peek`, `bake ding`, `bake out`, `bake frost COLOUR`, `bake sprinkle`, `bake top T`,
`bake serve WORD match|other`, `bake serve N` (the count; test.py looks for `bake serve 1`), `bake copy NAME`,
`bake unlock KIND`, `bake helper`.

## Rules kept
Logic counts `game.frame`; `music.step()` only draws (bulbs, bounces) and picks cue pitch. `bot()` serves a
customer about every 520 frames (a match for every other friend, the stick turning the tray first). One
backdrop (768 KB); particles guarded under 130; shapes go through prebuilt functions and `bake()` so a frame
allocates no closures.
