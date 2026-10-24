# Tea: a unicorn, a castle, and the cats

Built in `games/tea/tea.c`. The Yard lists it under Orb, blurb "tea with the cats," band 4+. `games/test.py` (run by `stress.sh`) plays the checks at the bottom of this note.

Where it runs: the first build is on the cabinet, on the Yard row under Orb, as of the 2026-10-23 22:00 flash. This note is version 2 (2026-10-24), which has been played on the PC with `games/playtest.py` and not flashed.

Audience is a four-year-old, in short turns, on the Partycade. She said: a unicorn is flying to a tea party at the princess castle, the party is full of kitty cats, and you play with them and take care of them. The game is that sentence, played with one hand if that is all she uses.

This is the little band in [CONTROLS.md](../../CONTROLS.md). Every stick direction does something useful. Every button on the right does the care. There is no way to lose, no way to hurt a cat, and no clock that makes them sad while the cabinet is off.

## What changed in version 2, and why

Version 1 followed this note's first draft faithfully. Played frame by frame through the cabinet path, three things were wrong with it for a four-year-old:

* **The flight was a wait.** Fifteen seconds of a unicorn flying with nothing for her hand to do. Leaning moved the picture a few pixels and changed nothing.
* **Every care was the same press with the same answer.** Three presses on a cat filled three hearts with the same picture. The picture never taught anything new.
* **The party ended at the cheer.** After the last heart, the buttons did a sparkle and nothing changed.

Version 2 keeps every promise below and fixes those:

1. **Treats on the way.** Balloons, cupcakes, flowers, and stars float toward her down the rainbow in three lanes. Left and right change lanes, up and down swoop to the next treat, a press sparkles and catches the side lanes too. Half of them come down the middle, so watching still catches some. Nothing is missed in a way that hurts: a treat she does not catch floats past.
2. **What she catches decorates the party.** Balloons tie to the table, cupcakes sit on the cloth, flowers go in a vase, stars hang on the bunting. The flight matters, and she sees why.
3. **Three hearts, three different asks.** The cat's own wish (tea, yarn, a flower), then a cupcake, then a big hug. The picture over the cat changes each time, so the picture is always the instruction.
4. **A song after the cheer.** Each press plays the next note of the party song, the cats sway in time, and the sixteenth note rains hearts. Mashing makes music.
5. **A photo on the wall.** Each cheer hangs a framed photo on the castle wall, and the photos stay between visits, the way Chest's gem pile does. She can see how many parties she has had.

## What a turn feels like

She walks up. A unicorn is already in the sky, wings beating, a small castle far ahead on a rainbow. Something sparkly is floating toward her: a pink balloon. If she does nothing, it reaches the unicorn's horn, pops into a little basket at the bottom of the screen, and a bright note plays. If she pushes the stick, the unicorn swoops to the next lane, where a cupcake is coming. If she presses a button, the unicorn sparkles and hurries, and her sparkle reaches the next lane too.

The castle grows. The door swings open on warm light. Cats peek out one by one. One who remembers her runs to meet the unicorn, wearing what she gave it last time.

At the table, three cats (four, from the third visit) sit behind a cloth. Her balloons are tied at the ends, her cupcakes sit on the cloth, stars twinkle along the bunting. A soft gold ring sits on one cat; a bubble over its head shows one big picture. A press does that thing, a heart fills on the same frame, and the cat answers. The next press on that cat shows a new picture: a cupcake, then a heart for a hug.

When every heart on the table glows, the party cheers, a photo floats up to the castle wall, and the picture over the cats becomes a music note. Each press is the next note of a song.

## The promise

* She cannot crash, miss, or make a cat unhappy.
* Watching is already play. Treats come down the middle, the cats blink and look at her, the yarn ball wobbles, someone does a little idle about every two seconds.
* The first press on a cat succeeds. That success is the whole lesson.
* A turn is about two minutes if she fills every heart. It is allowed to be ten seconds or ten minutes.
* Leaving is a goodbye: the cats wave. The gifts and the photos stay. Coming back is a reunion, not a rescue.
* She never has to read. A cream band at the bottom carries one short line for a grown-up to say out loud.

## Who is at the table

| | Looks like | Their own wish | Answers by | Tune |
| :--- | :--- | :--- | :--- | :--- |
| **Pip** | Round orange cat, cream muzzle | A teacup | Sips; keeps a milk mustache | A warm purr under a soft note |
| **Moth** | Grey cat, darker stripes, tall ears | The yarn | The yarn rolls away, bounces, rolls back | Two quick high notes |
| **Pearl** | White cat, gold bow | A flower | Twirls, petals burst, wears the flower | Three little bells |
| **Nib** | A tiny cream kitten, orange patches, on a lilac cushion | Copies the friend she just played with | A smaller version, then bumps the unicorn's nose | The friend's tune, a fifth higher |

The second ask is always a cupcake (the cat holds it, two bites, crumbs, a happy three-note tune). The third is a hug (the unicorn walks right up to the table, hearts rise, a long purr).

Nib arrives on the third visit. Until then the table is Pip, Moth, and Pearl, always in that order, so her hand learns the seats.

Cats smile (a small "w" mouth), blink, and look toward the unicorn. A happy cat's eyes become arcs and its smile opens. Every couple of seconds one cat that is not focused tilts its head.

## Controls

One sentence: the stick moves her (in the sky) or the ring (at the party), and any right-hand button does the picture.

| Input | In the sky | At the party |
| :--- | :--- | :--- |
| Left, right | Change lane | The ring moves to the next cat that way (it wraps) |
| Up, down | Swoop to the lane of the next treat coming | Up goes left, down goes right |
| Holding a direction | Stays in that lane | The ring walks on about twice a second |
| `LOW`, `TL`, `TR` (press) | A sparkle for almost a second: her reach covers the next lane | The picture over the focused cat; after the cheer, the next note of the song |
| Holding a right-hand button | Hurry: the castle comes sooner, treats come faster | The care repeats about twice a second, visibly |
| `1P` + `2P` held | Quit, the cabinet rule (the cats wave) | Quit |

The stick never has to be precise. Lanes are a third of the picture wide. The ring snaps.

A button held from the Yard into the game hurries the flight and does not pour a pile of tea at the party: the care waits for a new press after the door.

## The three beats

### Sky

About fifteen seconds if she only watches, about eight if a button is held, never more than about twenty-two. A treat leaves the castle every second or so (faster in a hurry): half down the middle lane, a quarter on each side. It grows as it comes and meets her at the horn. The catch is on the frame it arrives: a burst of stars, a rising note (each catch a step higher on a pentatonic scale), the line names it ("A cupcake for the party!"), and the treat arcs down into the basket at the bottom left. Clouds still fly past and giggle if she bumps a big one. Five stars on the rainbow light as the castle gets closer.

### The door

About a second and a half, and it plays itself. Two gold leaves swing open on warm light, the cats peek out, a cat wearing a gift runs out to her. The basket stays at the bottom, full of what she brought.

### The party

The castle wall fills the top, with her photos framed on it. A scalloped cloth runs across the middle, with the teapot steaming, a cake, Moth's yarn ball, and what she caught. The unicorn stands in front and trots to whichever cat the ring is on.

Care, on the press frame: the heart fills and pops, the picture arcs from the unicorn to the cat, small hearts rise, and the cat starts its answer. Hearts never drain.

When the last heart fills: the cheer (the teapot spins stars, everyone hops, confetti of hearts and stars), then a photo floats up from the table to the next free frame on the wall, with a little camera chime. Then the ask picture is a music note, and the song begins.

## What "take care of them" means

The Tamagotchi feeling with the punishment taken out. The cabinet's clock is stuck at the epoch, and we do not want a hunger timer anyway.

`tea.sav` keeps:

* `visits N`: how many times she has arrived. Nib comes on the third.
* The last gift each cat is wearing: `none`, `teacup`, `ribbon` (on Moth's yarn), or `flower`.
* `photos N`: one for each party that reached the cheer. Up to twelve show on the wall.

Hearts, treats, and the song are fresh every visit, on purpose.

```
visits 3
pip teacup
moth ribbon
pearl flower
nib none
photos 2
```

Unknown lines are ignored. A gift word outside the list is `none`. Numbers outside 0 to 100000 are clamped. A missing or broken file is the first visit. Saves are written on arrival, on each gift, on the cheer, and when the photo lands, through a temp file, fsync, rename, and a directory fsync.

## Pictures

2D, upright, 384×512, the panel's exact ×2 scale, drawn in code with `games/common/gfx.c` (no picture files). Every figure is outlined toon shapes: each part painted once in ink a little larger, then filled. Nothing is from a film, a book, or a product.

* The unicorn is seen from behind, so she is you: cream body, rainbow mane down her back, gold horn, lilac hooves, wings of soft puffs that beat in the sky and fold at the table. Her wing beat is cut into eight steps and each is drawn once and reused, which keeps the frame cheap on the cabinet's CPU.
* Treats: a balloon (five colors), a cupcake with sprinkles and a cherry, a pink flower, a gold star. Each glows softly as it comes.
* Ask pictures: teacup, yarn, flower, cupcake, heart (a hug), music note, and a sparkle for a happy cat before the cheer.
* Everything important is at least 32 pixels tall. Hearts are about 25 pixels; the ask bubble is 64.

Palette, unchanged: sky `#8ec6ff`, cream `#fff6ea`, castle `#f4b6d0`, roof and hearts `#e86b9a`, gold `#f2c14e`, mint `#7ec8c3`, lilac `#b9a0e8`, tea `#c9865a`, Pip `#f29a3a`, Moth `#8a8f9c`, ink `#3a2a44`.

No full-screen flash: a flash is a startle.

## Sound

The synth in `games/common/sfx.c`, sine and triangle only, major and pentatonic. The output is capped at 3000 of 32767 (`sfx_limit`), under the Keep beep. The cabinet's volume buttons own loudness.

| Moment | What she hears |
| :--- | :--- |
| Sky | A quiet bed, C5 E5 G5 A5 over a soft bass; a little faster in a hurry |
| Change lane, swoop | A soft upward slide |
| A treat caught | The next note up a pentatonic scale, with a bell an octave above |
| Sparkle | A bright slide |
| Cloud bump | A soft A5 pop |
| Door | C5 E5 G5, and the tune of the cat who runs out |
| Party | A very quiet music-box bed |
| Pip's tea | A purr around G3 under E5 |
| Moth's yarn | G5 then C6 |
| Pearl's flower | C6 E6 G6, bells |
| Cupcake | G5 E5 C6 |
| Hug | A long purr, C5 G5 C6 |
| Nib | The friend's tune, a fifth higher |
| Cheer | C5 E5 G5 C6 |
| The song | One note per press: C5 E5 G5 E5 A5 G5 E5 C5 D5 E5 G5 C6 A5 G5 E5 G5 |
| Quit | A falling G5, E5 |

## The line you read

One line of the 8×8 font at ×2 in the cream band. It is narration, never a control hint. It changes on the frame the moment changes. A reaction borrows it for about two seconds.

| Moment | The line |
| :--- | :--- |
| Sky, watching | `She flies to the castle.` |
| Sky, changing lanes | `She leans in the clouds.` |
| Sky, hurrying | `The party is waiting.` |
| A treat caught | `A balloon for the party!`, `A cupcake for the party!`, `Flowers for the party!`, `A star for the party!` |
| Door, first visit | `They saved her a seat.` |
| Door, a cat kept a gift | `Pearl kept her flower.` (or `Moth kept a ribbon.`, `Pip kept a teacup.`) |
| Door, third visit | `A kitten came to play.` |
| Ring on a cat, its own wish | `Pip would love some tea.`, `Moth wants the yarn.`, `Pearl wants a flower.`, `Nib copies a friend.` |
| Second ask | `Pip wants a cupcake.` |
| Third ask | `Pip wants a big hug.` |
| Just cared | `Pip sipped her tea.`, `The yarn rolled back.`, `Pearl wears a flower.`, `Nib bumped her nose.`, `Pip ate the cupcake.`, `A big unicorn hug!` |
| That cat's third heart | `Pip is so happy.` |
| A happy cat pressed before the cheer | `Pip does a little dance.` |
| The cheer | `The whole table glows.` |
| After the cheer | `Play a song for them.` |
| A note | `La la la!` |
| The whole song | `They loved the song!` |
| Goodbye | `They will keep the gifts.` |

## What this game will not do

* No sickness, hunger, dirt, scolding, or a cat that cries because she left.
* No game over, no score to beat, no timer counting down. Treats are counted in a basket, never as a score.
* No reading required, no menu of tools, no mode that changes what a button means. The picture changes; the button still means "do the picture."
* No second player with their own stick. A grown-up can hold the button while she holds the stick.
* No 3D, no video, no recorded music file.

## How we know it works

`games/test.py` plays these headless (`stress.sh`):

* Autoplay reaches the cheer, the three gifts are saved, treats were caught, and the photo is saved (`photos 1`).
* A held button from the launch hurries the flight and pours nothing.
* `TL`, `TR`, and `LOW` each fill a heart; the stick moves the ring.
* A gift is saved when given; the cat who kept it runs to the door next visit.
* A broken save opens as the first visit; Nib comes on the third.
* After the cheer, presses play the song through to "They loved the song!"
* 1P and 2P quit.

And by hand with `games/playtest.py`, through the cabinet's framebuffer path and a strict four-way stick: the flight catches, the cupcake and hug asks, the four-cat table, the photo, the song.

## What we kept from her sentence

1. **The flight cannot fail** and always arrives. A held button only makes it sooner.
2. **The cat asks in a picture.** She never chooses tea versus yarn; the cat shows what would be lovely now.
3. **Hearts refill as a hello every visit. Gifts and photos stay.** Nib joins at the third arrival.
4. **Pip, Moth, and Pearl**, orange-and-tea, grey-and-yarn, white-and-flower.
5. **Big flat 2D**, pink castle, cream unicorn, thick outlines.
6. **A grown-up quits** with 1-player and 2-player. She is never asked to.
