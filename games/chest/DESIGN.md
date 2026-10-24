# Chest: the key, the sword, and Zam

Built in `games/chest/chest.c`. The Yard lists it under Tea, blurb "the key, the chest, Zam," band 5+. `games/test.py` (run by `stress.sh`) plays the checks at the bottom.

Where it runs: the first build is on the cabinet, flashed to tile 10 on 2026-10-23. This note is version 2 (2026-10-24), played on the PC with `games/playtest.py` through the cabinet's framebuffer path and not flashed.

Audience is a five-year-old who can already steer in Mario Kart, in a short turn, with a grown-up beside him reading the line and ready to hold the button. He said: you are a person walking to a treasure chest, first you need the key, the key unlocks it, a gold boss pops out and gives you a sword because he is the boss, you shoot lasers at him, a laser that hits you puts a bubble around you, good fairies bubble him, some fairies bubble you and that means start over, some good fairies bubble you and then it pops and you collect it and it goes around him, and bad fairies bubble you and that is how you get hurt.

He loves Alakazam. Zam is drawn after him: a tall gold psychic with long pointed ears, a fox's face, a long drooping mustache, brown armor on his shoulders, chest, elbows, and knees, and a spoon in each hand. Zam's name, the rest of the game, and every line are ours. Alakazam and Pokémon belong to Nintendo, Creatures, and Game Freak. This drawing is a fan tribute for one family's cabinet. It is not licensed by them, and it is not covered by this repository's MIT license.

This is the walk-up band in [CONTROLS.md](../../CONTROLS.md). The stick walks. The lower button shoots. He can win with the stick alone. The button is how the win becomes his.

## What changed in version 2, and why

Version 1 followed the first draft. Played through the cabinet path a frame at a time, it had four problems a five-year-old would hit:

* **He missed for a reason he could not see.** The laser went the way he last walked. Step left to dodge a bubble, press, and the laser flew off to the left. The line said "Aim up," which he cannot read.
* **He was jammed against Zam.** The chest opened where he stood, so the fight began with Ned touching Zam's feet.
* **Zam stood still.** After the first fight there was nothing new to see. The pile was the only reason to play again.
* **Holding the button won.** Once aiming was fixed, a held button beat Zam in two seconds.

Version 2:

1. **The sword points at Zam by itself.** In the fight every shot flies at him, wherever Ned stands. The stick is for dodging bubbles, stepping out of purple rings, and walking onto stars. Before the sword, the short spark still goes the way he faces.
2. **Ned hops back** to the fighting line while Zam unfolds, and cannot walk closer than that line during the fight.
3. **Zam learns a trick for each gem**, up to three: a teleport, a shield (his Reflect), and three bubbles at once. Each is slow, shown before it happens, and named in the line. The first fight has none.
4. **A rhythm, so the button needs timing.** From the second fight: the spoons glow and the bubbles come (he is open), then the shield goes up (zaps bounce off in cyan and the line says to wait), then he teleports. Zam takes 9 zaps on the first fight and 3 more for each trick he knows. A tap fires at once, up to five a second. A held button repeats twice a second, so tapping at the right moment beats leaning on it.
5. **A different treasure for each win:** pink gem, blue gem, gold coin, green gem, purple gem, ring, crown, golden spoon, then around again. It arcs from Zam into a mound that grows at the top left, and the key hides somewhere new for the next round.

## The story, in one loop

One meadow. A person, a glowing key, a chest. He walks to the key and it jumps into his hand. He walks to the chest and the lock opens. Zam rises out of it, spoons raised, and throws him a sword, and Ned hops back. The sword's laser flies at Zam. Fairies drift in: gold ones wrap Zam so the next zap is a big pop, blue ones leave a star that wraps him, purple ones are the hurt. Three hurts restart the fight with the sword still in hand. Fill Zam's lights and he bows, bends his spoons for show, and treasure arcs onto the pile. The key is back, somewhere else.

## The promise

* The first success is the key, and it comes from walking.
* The sword arrives by itself when the chest opens.
* A press always shows a laser on that frame. In the fight it always flies at Zam.
* His own laser never wraps him, never bounces onto him, and never hurts him.
* Purple is the only hurt. He can see it coming: the spoons glow purple and a faint ring marks where he stands before a bubble leaves.
* Three hurts restart the fight. The sword stays. The pile stays.
* A turn with no button still ends: gold fairies wrap Zam and a wrap that pops on its own counts.
* Nothing sad happens while the cabinet is off.
* He never has to read. The cream band is the sentence you say. It names colors and moments, never buttons.

## Who is in the room

| | Looks like | Does |
| :--- | :--- | :--- |
| **Ned** | A small person, round silver helmet with a red plume, blue cape, simple face | Walks. Faces the way he walked; in the fight, his sword points at Zam |
| **The key** | A gold key taller than his helmet, bobbing and sparkling | Sits somewhere in the meadow (a new spot each round). Walking into it puts it in his hand |
| **The chest** | Wood and gold, keyhole pulsing until he has the key | With the key, walking into it opens it. Without, it hops |
| **Zam** | See above: gold, long ears, fox face, long mustache, brown armor, two spoons. He hovers | The boss. Bubbles from the spoons. Teleports, shields, sprays as he learns. Bows when he loses and when Ned does |
| **Gold fairy** | Round, gold, two wings | Flies to Zam and wraps him. While wrapped he cannot shield or shoot |
| **Blue fairy** | Round, blue, holding a star | Wraps Ned in a safe blue bubble that pops into a star. Walking over the star wraps Zam |
| **Purple fairy** | Round, purple, empty hands | Wraps Ned in a ring that grows. Walking out breaks it. If it closes, that is a hurt |

## Controls

One sentence: the stick walks, and `LOW` shoots.

| Input | On the path | In the fight |
| :--- | :--- | :--- |
| Stick | Walks. He faces the way he last walked. Opposing directions cancel. The game is finishable with pure up, down, left, right | Walks between the fighting line and the bottom. For dodging, stars, and leaving purple rings |
| `LOW` press | A short gold spark the way he faces; it can also tap the key or the lock | A laser at Zam. Up to five a second |
| `LOW` held | Repeats twice a second, after a press made in this game | Same |
| `TL`, `TR` | The same as `LOW` | The same as `LOW` |
| `1P` + `2P` held | Quit | Quit |

A button held from the Yard does not fire until it is released and pressed again.

You can split the hands: he keeps the stick, you hold `LOW`. With the sword aiming itself, the person on the button only chooses when.

## The four beats

### The path

The key and the chest are on screen from the first frame. The first round's key is a few steps up and left; later rounds put it at one of four other spots around the meadow. Walking onto the chest without the key makes it hop.

### The pop

One second. The lid flies up, Zam rises with a psychic glow, the sword arcs into Ned's hand, and Ned hops back to the fighting line. A press during the pop still shoots.

### The fight

Zam hovers over the chest, or at a spot to its left or right after a teleport. Nine little lights under him (more on later fights) are his marks.

* **First fight:** every two and a half seconds the spoons glow purple for half a second, then one slow bubble drifts toward where Ned stood when the glow began.
* **After one gem:** every five seconds, a bubble, then a teleport: he narrows to a line, sparkles, and reappears at another spot. A laser fired while he is gone flies past.
* **After two gems:** the same, plus his shield (Reflect): cyan panels in front of him for a second and a half. Zaps stop at the panels and splash cyan. The line says "His shield is up. Wait."
* **After three gems:** every other bubble is a fan of three.

The fairies keep their first-draft schedule: gold at about 1 and 8 seconds, blue at about 4, purple after his first shot or at about 9. A gold wrap breaks the shield and stops bubbles while it holds.

| Event | Result |
| :--- | :--- |
| Laser on bare Zam | 1 mark. He flinches white and wobbles |
| Laser on a gold wrap | 3 marks. The big pop: stars, a shake, dizzy stars over his head |
| Gold wrap runs out with no shot | 1 mark |
| Laser on the shield, or while he is teleporting | No mark. A splash where it stopped |
| Blue star collected | A gold wrap on Zam |
| Purple ring closes, or a bubble touches Ned | 1 pip, a short knockback. Three pips restart the fight |
| All of Zam's lights | Win |

Lights to fill: 9 on the first fight, then 12, 15, and 18.

### The bow

Win: Zam bows, bends both spoons, and the treasure arcs onto the pile. About two and a half seconds. Then the chest is shut, the key is somewhere new, and the line says "The key is back. Go on."

Hurt three times: Zam bows, the pips empty, the lights reset, and after a second the fight goes on with the sword still in hand.

## The pile

`chest.sav` is one line, `gems N`, written when a win adds one. Below 0 or nonsense opens as 0; above 100000 stays at 100000. A lost fight writes nothing. Quitting writes nothing new.

The pile draws up to fifteen treasures in a mound (five, four, three, two, one), each win's item in order: pink gem, blue gem, gold coin, green gem, purple gem, ring, crown, golden spoon. Past fifteen a star sparkles over it and the number beside it keeps counting. `N` also sets Zam's tricks (0 to 3).

## Pictures

384×512, drawn in code with `games/common/gfx.c`, every figure in outlined toon shapes. The meadow, bushes, and path are painted once and copied each frame.

| | Hex |
| :--- | :--- |
| Cream band, path | `#fff6ea` |
| Ink outlines | `#3a2a44` |
| Ned's cape | `#3a6ea5` |
| Skin | `#f4c7a1` |
| Zam's fur, key, sword, gold fairy | `#f2c14e` |
| Zam's armor and mustache | `#8a5a32` |
| Spoons | `#babec8` |
| Shield | `#7fe8ff` |
| Blue fairy | `#6eb5ff` |
| Purple fairy, rings, bubbles | `#7a5af5` |
| Pips, pink gem | `#e86b9a` |

## Sounds

Synth only, capped at 3000 of 32767 (`sfx_limit`). A quiet walking tune on the path, a quicker one in the fight.

| Moment | Sound |
| :--- | :--- |
| Key | C6 |
| Chest opens | C5 E5 G5 C6 |
| Spark | A short high blip |
| Laser | A short falling square |
| Mark | A quick drop |
| Big pop | G5 C6 |
| Shield | Two bells, E6 and B6 |
| Laser on the shield | A high ding |
| Teleport | A rising sweep |
| Spoons glow | E5 (or D5 before three bubbles) |
| Gold wrap | E6 |
| Blue pop into a star | E5 G5 |
| Purple ring growing | A soft rising hum |
| Hurt | A low slide |
| Win | C5 E5 G5 C6 E6 |
| The treasure lands | A high chime |
| Fight restarts | G5 then E5 |
| Quit | A falling G5, E5 |

## The line you read

| Moment | The line |
| :--- | :--- |
| Path, no key | `The key is glowing.` |
| Path, walking | `He walks to the key.` |
| Key in hand | `The key is his.`, then `Now walk to the chest.` |
| Chest, no key | `The lock wants the key.` |
| The pop | `Pop! He threw the sword.` |
| Fight, before his first shot | `The sword can zap him.` |
| Fight, otherwise | `Gold one. He's the boss.` |
| Spoons glow | `A bubble is coming.` |
| Spoons glow, three | `Three bubbles! Step away.` |
| Teleport | `Zam jumped! Find him.` |
| Shield | `His shield is up. Wait.` |
| Gold wrap | `Gold fairy has him.` |
| Blue bubble on Ned | `A blue bubble. Catch it.` |
| Star on the ground | `Walk over the star.` |
| Star collected | `The star wrapped him.` |
| Purple ring | `Purple. Step out of it.` |
| Hurt | `That bubble got him.` |
| Fight restarts | `Pop. The sword stayed.` |
| Bare hit | `The sword zapped him.` |
| Big pop | `The big bubble popped.` |
| Win | `Treasure for the pile.` |
| Path again | `The key is back. Go on.` |
| Goodbye | `The gems will stay.` |

## What this game will not do

* No second verb. No mode: the button shoots before and after the chest.
* His own laser never wraps him and never bounces onto him. The shield stops a laser; it never returns it.
* A bad fairy never wraps Zam into a heal.
* No maze, no scrolling, no second room.
* No boss who dies. He bows and comes back.
* A lost fight does not take the key or a gem away.
* No 3D, no video, no recorded music.

## How we know it works

`games/test.py` (`stress.sh`):

* Autoplay goes key, chest, sword, and wins gems; the pile keeps every win.
* A held button waits for a new press; `TL` and `TR` shoot.
* A broken save opens with no gems.
* Walking to the key and chest by hand, then stepping sideways and pressing, still marks Zam: the sword aims itself.
* The first fight has no tricks. With two gems he teleports and raises a shield that stops zaps. With three, three bubbles at once.
* 1P and 2P quit.

And by hand with `games/playtest.py`: the first fight, a level-one teleport, a level-three fight start to finish with the bow, the treasure's arc, and the key's new spot.
