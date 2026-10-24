# Chest: the key, the sword, and Zam

Built on the PC and flashed to tile 10 on 2026-10-23. Rebuilt on 2026-10-24 with new pictures and sound and the same rules and lines; that build is on the PC only. `games/test.py` (run by `stress.sh`) plays the checklist at the bottom.

Audience is a five-year-old who can already steer in Mario Kart, on the Partycade, in a short turn, with a grown-up beside him reading the line and ready to hold the button. He said: you are a person walking to a treasure chest, first you need the key, the key unlocks it, a gold boss pops out and gives you a sword because he is the boss, you shoot lasers at him, a laser that hits you puts a bubble around you, good fairies bubble him, some fairies bubble you and that means start over, some good fairies bubble you and then it pops and you collect it and it goes around him, and bad fairies bubble you and that is how you get hurt.

This is the walk-up band in [CONTROLS.md](../../CONTROLS.md). The stick walks. The lower button shoots. He can win with the stick alone. The button is how the win becomes his.

## The story, in one loop

One room. A person, a glowing key, a chest. He walks to the key and it jumps into his hand. He walks to the chest and the lock opens. A tall gold creature pops out, mustache wide, a spoon in each hand, and throws him a sword. The sword shoots a laser the way he is facing. Fairies drift in. Gold and blue ones wrap Zam so the laser counts. Purple ones, and Zam's own shots, wrap the person, and that is the hurt. Three hurts and the fight starts again, sword still in his hand. Pop Zam enough times and treasure spills onto a pile that stays.

Then the key is glowing again, the chest is shut, and he can walk it again. The pile remembers.

## What a turn feels like

He walks up. The person is already on the path, facing the chest, key shining off to one side. If he holds the stick toward the key, he gets it. The chest is in front of him the whole time, so the plan is a picture, not a maze.

At the chest the lid flies up. Zam unfolds out of it, mustache first, both spoons tapping the lid, and the sword arcs into the person's hand on that same moment.

Now Zam is the boss, and he is smiling. He flicks slow purple bubbles off the spoons. Fairies cross the room one at a time. The person walks out of the purple ones and walks over the blue stars. Whenever someone presses the lower button, a laser leaves the sword. If Zam is wrapped in a bubble, the pop is the big hit. If he is bare, the laser still flashes on the spoons, so the button always answers.

When Zam has had enough, he bows, treasure jumps onto the pile, and the room sets itself back. Losing a fight bows him too, refills the person's bubbles, and starts the duel again. The key does not go back into the grass in the middle of a fight.

You quit the way every game on this cabinet quits: hold 1-player and 2-player.

## The promise

* The first success is the key, and it comes from walking, which he already knows.
* The sword arrives by itself when the chest opens. He does not hunt for a second item.
* A press always shows a laser on that frame, from the sword, the way he faces.
* His own laser never wraps him.
* Purple is the only hurt. He can see it coming, and stepping away breaks a fairy's bubble before it closes.
* Three hurts restart the fight. The sword stays. The gem pile stays. The walk is not repeated as a punishment.
* A turn with no button still ends. Gold fairies wrap Zam, and a wrap that pops on its own still counts. Shooting is faster and louder.
* Nothing sad happens while the cabinet is off. There is no clock, no hunger, and no pile that shrinks.
* He never has to read. The cream band is the sentence you say, and it is also the guide: it names the color of the bubble. The picture works if you say nothing.

## Who is in the room

They are known by shape and color. Names are in the line.

| | Looks like | Does |
| :--- | :--- | :--- |
| **Ned** | A small person, round helmet, blue cape, simple face. Gold sword once the chest has opened | Walks. Faces the way he last moved. Starts facing up, toward the chest |
| **The key** | A gold key taller than his helmet, glowing | Sits in the open, left of the path. Walking into it puts it in his hand |
| **The chest** | Wood and gold, keyhole pulsing at the top of the room | With the key, walking into it opens it. Without the key, it wobbles |
| **Zam** | Tall and thin, gold fur, a long brown mustache that sticks out past his shoulders and curls at the ends, brown plates on his chest and shoulders, narrow eyes, a silver spoon in each hand | Pops out of the chest and tosses the sword. The boss. Bubbles leave the spoons. Bows when he loses and when Ned does |
| **Gold fairy** | Round, gold, two wings | Flies to Zam and wraps him. He stops shooting while the wrap holds |
| **Blue fairy** | Round, blue, a star already showing in her hands | Wraps Ned in a blue bubble that pops into a star. Walking over the star sends a wrap to Zam |
| **Purple fairy** | Round, purple, empty hands | Wraps Ned. The ring grows. Walking out breaks it. If it closes, that is a hurt |

Drawn in flat shapes, big enough to read from a step away. The mustache is the widest thing on him. The two spoons are as tall as his arms. The brown plates sit on the gold chest like a vest. He stands on the chest, feet apart, spoons held out.

Ned is a working name so the lines have someone to talk about. Easy to change before any code.

## Controls

One sentence: the stick walks, and `LOW` shoots a bolt the way he faces.

Walk-up band. `TL` and `TR` shoot the same bolt. A mash of the right-hand cluster still plays. Those buttons never do a second, secret thing.

| Input | On the path | In the fight |
| :--- | :--- | :--- |
| Stick | Walks. Up toward the chest, down toward the bottom, left and right across. He faces the last direction he held. Opposing directions cancel. A diagonal, if the stick ever reports one, walks both ways at once, and the game is finishable without that | Same walk. Stepping out of a growing purple ring breaks it. Stepping onto a star collects it |
| `LOW` | A short gold spark from his hand, the way he faces. It can also pick up the key or tap the lock. Walking onto them does the same thing, so the spark is a flourish | A laser from the sword. Bare Zam: both spoons flash and one mark. Gold wrap: the wrap pops and three marks |
| Hold `LOW` | The spark repeats, about three a second, only after a press that happened in this game | The laser repeats the same way. The repeat is visible |
| `TL`, `TR` | The spark | The laser |
| `1P` + `2P` held | Quit | Quit. A grown-up's chord |
| Volume, power | The cabinet's | The cabinet's |

A button held down from the Yard does not fire a stream on the first frames. The first shot waits for a new press after he is in the room.

You can split the hands. He keeps the stick, which is the skill he already has from the kart. You hold `LOW` and shoot when the line says Zam is wrapped. When he wants the button, it is the same button you were pressing. The panel is already divided that way.

The button means shoot for the whole session. Before the sword the shot is short. After the sword it crosses the room. The picture changed because the sword is in his hand.

He starts facing up. A press with the stick at rest still shoots toward Zam.

## The room

One screen, upright, 384×512, drawn with the SDL renderer the way Tea is. Flat shapes, thick outlines. The whole plan is visible at once.

```
gems along the top
chest, and later Zam, at the top
fairies in the middle
Ned near the bottom
cream band under his feet
```

The key starts in the open, between Ned and the chest, so the first walk is a few seconds of holding up and a little left. Nothing scrolls. He cannot walk off the screen. Reaching the edge stops him.

Ned moves at about two pixels a frame, so he can change his mind. A boss bubble is slow enough to step around. A purple fairy's ring takes about three quarters of a second to close, and the ring is on screen the whole time.

## The four beats

### The path

The key and the chest are both on screen when the picture appears. The stick is already playing. There is no title pose that hides him.

Walking onto the key picks it up the same frame. The key chimes and sits in his hand. Walking onto the chest without it makes the chest hop and the line ask for the key. Walking onto it with the key opens it.

The spark can do those touches too. It is never required.

### The pop

Under a second. The lid rises, Zam unfolds, both spoons out, the sword flies into Ned's hand, and the line is the toss. A press during this beat still shoots a spark and does not break the pop. When the sword lands, the next shot is a laser.

### The fight

Zam stands on the chest. Both spoons flash for about half a second, then a purple bubble drifts from where Ned was standing when the flash began. It does not chase harder than that. Touching it is a hurt.

Fairies enter one at a time, so the room has one new idea:

* Gold flies to Zam, wraps him, and he stops shooting. The wrap holds for about two seconds. A laser during the wrap pops it for three marks. If nobody shoots, it pops itself for one mark.
* Blue flies to Ned and wraps him in blue, star visible inside. That ring is safe. It pops into a star at his feet. The star waits a few seconds. Walking over it sends a gold wrap to Zam. He does not have to press anything to collect.
* Purple flies to Ned and grows an empty ring. Leaving the ring breaks it. If it closes, that is a hurt.

A bare laser that reaches Zam lights one mark and plays the small hit. It never wraps Ned, never bounces, and never hurts him. A laser that hits a wall splashes there, so a shot fired the wrong way is still visible.

Nine marks and Zam bows. Three big pops do it. A mix of bare shots and fairy wraps does it too. Steer-only, with gold fairies popping themselves, still gets there.

The first purple fairy waits until Ned has shot once, or until about eight seconds of the fight, whichever comes first. The key, the sword, and a flash on Zam's spoons all happen before the first hurt.

### The bow

Win: Zam bows, gems hop onto the pile, the line names the treasure. About two seconds. Then the key is back in the grass, the chest is shut, Ned still has his place on the path, and the sword is gone until the next pop. The new gem stays.

Hurt: Ned has three empty bubble pips beside him. A closed purple ring or a boss bubble fills one and pops immediately. He is free on that same moment, knocked a short step, still holding the sword. Control does not stay stuck inside a bubble.

Three pips filled: the fight bows. Zam taps his spoons together, the pips empty, the marks reset, fairies clear, the sword stays, the chest stays open. About a second. The line says the sword stayed. Gems do not decrease.

## Marks, pips, gems

| Event | Result |
| :--- | :--- |
| Laser touches bare Zam | 1 mark. Both spoons flash |
| Laser pops a gold wrap | 3 marks. The big pop |
| Gold wrap expires with no shot | 1 mark. The fairy still helped |
| Blue star collected | A gold wrap on Zam. Marks come from that wrap, not from the star itself |
| Purple ring closes, or a boss bubble touches Ned | 1 pip. At 3 pips the fight restarts |
| Nine marks | Win. Gems increase by one |

The pile draws up to eight gems. Past eight it sparkles instead of crowding the sky. The save remembers the real count.

`chest.sav` is one line, `gems N`. Written when a win adds a gem, the same temp, flush, fsync, rename, and directory fsync as the other games. `N` below 0 or nonsense opens as 0. `N` above 100000 stays at 100000. The name `chest` is not a stock save name. A lost fight does not write. Quitting on the path writes nothing new.

There is no clock read.

## Pictures

Big flat shapes in code. A missing picture file must not be required, because there is no picture file.

| | Hex |
| :--- | :--- |
| Path and band cream | `#fff6ea` |
| Grass | `#7dce7a` |
| Ink outlines | `#3a2a44` |
| Ned's cape | `#3a6ea5` |
| Helmet and skin | `#f4c7a1` |
| Key, sword, laser core, gold fairy | `#f2c14e` |
| Chest wood | `#c4844a` |
| Zam's body | `#f2c14e` |
| Zam's mustache and plates | `#a0673a` |
| Zam's spoons | `#babec8` |
| Blue fairy and her bubble | `#6eb5ff` |
| Purple fairy, her ring, boss bubbles | `#7a5af5` |
| Hurt pip | `#e86b9a` |
| Gem | `#e86b9a` with a gold glint |

The cream band is the bottom 32 pixels, ink on `#fff6ea`, the 8×8 font at ×2. One line, 24 characters, the same fit as Tea. Ned's feet stop above it.

As built (2026-10-24), drawn in code with `games/common/gfx.c`, every figure in outlined toon shapes:

* The meadow has flowers, stones, and bushes down both sides; a cream path leads up to the chest. The gem pile sits in a gold dish at the top left, with the count beside it.
* Ned has a round silver helmet with a red plume, a blue cape that trails the way he walks, legs that step, and eyes that look the way he faces; facing the chest, you see the back of his head. The sword is gold with a brown guard and a glow at the tip. His three pips float over his head.
* The key bobs and sparkles. The chest has gold bands and a keyhole that pulses until the key is in his hand. Open, it glows.
* Zam has no ears: a tuft of gold fur on top, narrow eyes under brown brows, a mustache that is the widest thing on screen and curls at both ends, a brown vest of plates, and a silver spoon in each raised hand. The spoons tap and flash before a shot. Nine little lights over his head are the marks; they fill gold.
* Fairies have wings and leave a trail; the blue one carries her star. Bubbles have a shine and wobble. A laser stays on screen for a few frames, with a white core and a glow where it lands.
* A win throws gems and stars; the pile hops. A hurt flashes Ned and rings out purple.

The sound is the same table, played by `games/common/sfx.c` and capped at 3000 (`sfx_limit`), with a quiet walking tune on the path and a quicker one in the fight. The laser is a short falling note.

## Sounds

Synth only, two voices, the bed and one effect. Amplitude stays under 3000, in the same quiet range as Tea. A third note waits.

| Moment | Sound |
| :--- | :--- |
| Path, under everything | A quiet C5 E5, slow |
| Key in hand | A bright C6 |
| Chest opens | C5 E5 G5 C6 |
| Laser | A short G5 |
| Gold wrap | A bell, E6 |
| Blue pop into a star | E5 G5 |
| Purple ring growing | A soft rising hum |
| Hurt | A low pop |
| Big pop on Zam | G5 C6 |
| Win | C5 E5 G5 C6 |
| Fight restarts | G5 then E5 |
| Quit | A falling G5, E5 |

Holding the button retriggers no faster than about three times a second.

## The line you read

Same band as Tea. Here the line is also the guide, because a bubble has a color and you are telling him what the color means. It still never names a button. When the moment changes, the line changes on the same frame.

It rests on the current moment. A hit, a hurt, or a fairy borrows the band for about two seconds, then the resting line comes back. Idle blinks do not change it.

| Moment | The line |
| :--- | :--- |
| Path, no key | `The key is glowing.` |
| Path, walking | `He walks to the chest.` |
| Key in hand | `The key is his.` |
| Chest, no key | `The lock wants the key.` |
| The pop | `Pop! He threw the sword.` |
| Fight, facing Zam | `Gold one. He's the boss.` |
| Fight, facing away | `Aim up. He's the boss.` |
| Spoon flash | `A laser is coming.` |
| Gold wrap | `Gold fairy has him.` |
| Blue bubble on Ned | `A blue bubble. Catch it.` |
| Star on the ground | `Walk over the star.` |
| Star collected | `The star wrapped him.` |
| Purple ring growing | `Purple. Step out of it.` |
| Hurt | `That bubble got him.` |
| Fight restarts | `Pop. The sword stayed.` |
| Bare hit | `The sword nicked him.` |
| Big pop | `The big bubble popped.` |
| Win | `Treasure for the pile.` |
| Path again | `The key is back. Go on.` |
| Goodbye | `The gems will stay.` |

Every one of those fits in 24 characters.

## Reactions, listed

* Stick on the path: he walks, the cape trails, the key stays put until he touches it.
* Touch the key: it hops into his hand the same frame.
* Touch the chest with the key: the pop starts the same frame.
* Touch the chest without the key: the chest hops. The key is still glowing.
* Button: a bolt leaves him the same frame, the way he faces.
* Bolt on a wall: a splash on the wall.
* Bolt on bare Zam: both spoons flash, one mark, the small line.
* Bolt on a gold wrap: the wrap pops, three marks, the big line.
* Gold fairy arrives: Zam stops shooting, the wrap is obvious.
* Blue fairy arrives: a safe bubble, then a star.
* Walk over the star: it flies to Zam and wraps him.
* Purple ring: grows, and leaving it breaks it with a small pop.
* Boss bubble or a closed purple ring: one pip, a short knockback, he can move again immediately.
* Third pip: bow, sword still there, fight ready again.
* Ninth mark: bow, gem joins the pile, key returns.
* Quit: the falling notes, gems already saved if he had won any, process exits.

## What this game will not do

* No second verb. The sword is the laser. There is no separate swing on another button.
* No mode. Shoot is shoot before the chest and after it. The bolt gets longer because he is holding the sword.
* His own laser never wraps him and never bounces onto him.
* A bad fairy never wraps Zam into a heal, and a purple bubble is never a shield.
* No maze, no second room, no scrolling path, no locked door past this chest.
* No lying down, no scream, no boss who dies. He bows and comes back.
* A lost fight does not take the key away and does not take a gem away.
* No 3D, no video, no recorded music file.
* No second stick. Two people play by splitting the hands that are already on this panel.

## How we will know it works

`games/test.py` plays a headless pass of these:

* The path shows Ned and the key with no button.
* The stick moves him and the chest stays.
* Walking onto the key puts it in his hand the same frame.
* Walking onto the chest with the key starts the pop, and the sword is in his hand when the pop ends.
* `LOW` draws a laser the same frame, toward the way he faces.
* A laser on Zam lights a mark.
* A gold wrap, then a laser, counts as the big pop.
* A blue star collected wraps Zam.
* Three purple hurts restart the fight, leave the sword in his hand, and leave the gem count alone.
* Nine marks add a gem, and the next path has the key back.
* `TL` and `TR` also shoot.
* 1-player and 2-player quit.
* A button held from the launch does not fire a stream before a new press.
* A broken `chest.sav` opens with no gems.

The Yard gains a row only when we build it, under Tea. The blurb is "key and the spoons." Keep and Lamp stay where they are.

## For your review

His words are the toy. These are the choices around them:

1. **One room.** The key, the chest, and the fight are the same picture. The walk is a few seconds, then the duel.
2. **The stick walks. `LOW` shoots. `TL` and `TR` shoot too.** Before the sword the bolt is short. After it, the bolt crosses the room. Walking onto the key and the chest works even if nobody presses.
3. **Zam tosses him the sword as the chest opens.** He is the boss and the gift-giver in the same pop. Tall gold body, a long brown mustache past his shoulders, brown plates on his chest, a silver spoon in each hand.
4. **A laser always does something.** On a bare Zam it flashes the spoons. On a gold wrap it is the big pop. His own laser never bubbles him.
5. **Three fairies.** Gold wraps Zam. Blue wraps Ned, pops into a star, and the star wraps Zam. Purple wraps Ned, and that is the hurt. Zam's shots are the same purple, already flying.
6. **Three hurts restart the fight.** The sword stays, the chest stays open, the gems stay. The walk is not the thing he has to do over.
7. **A win adds one gem and sets the key back out.** He can walk it again. The pile is the save.
8. **You read the band, and you can hold the button while he holds the stick.** The lines name colors. They do not name buttons.
9. **The person is called Ned** until you want a different name in the lines.

If those match the game you want to stand next to, the next step is to build it.
