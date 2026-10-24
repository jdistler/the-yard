# How a game uses this deck

This is the control philosophy for every game we write for the Partycade. [GAMEDEV.md](GAMEDEV.md) § 2 is the wiring. This file is what a designer does with it. If a new game wants a mapping this file forbids, the game is wrong and the file stays.

The machine is a countertop party cabinet with one stick and five play buttons. People walk up, play a turn, and hand it over. The hands are the design. Age changes how dense the challenge is. Age does not move the verbs to different buttons.

## The sentence

The left hand stays on the stick for the whole turn. The right hand's home is the lower button, the one shifted toward the stick. That button is the game's verb. The other two buttons on the right are extra words, used in order of how far the finger travels. The two buttons on the left of the stick are how you leave, never how you play. A press answers on the same frame, in the picture and in the sound, on the thing the player is watching.

## The deck, as hands

Measured layout, from the player's side of the panel:

```
[1P]                 [TL] [TR]
[2P]   [STICK]       [LOW]
```

`LOW` sits under the gap, shifted left, closer to the stick than `TR` is. Names are the ones in `cab.h`.

| Control | Hand that owns it during play | What it is for |
| :--- | :--- | :--- |
| Stick, four directions | Left hand, the whole turn | Move the body, or aim. One of those for the whole game |
| `CAB_LOW` | Right index, the short reach | The verb. Catch, place, jump, confirm, dive |
| `CAB_TL` | Right hand, one rock upward | The second word, once the verb is already felt |
| `CAB_TR` | Right hand, the long reach | The rare or committed word |
| `CAB_1P`, `CAB_2P` | A hand that has let go of play | Start a turn, pass the cabinet, quit |
| Volume, power | Nobody, in our games | The cabinet owns them |

There is one stick and one cluster. A second person does not have a second deck. `2P` is a button beside the stick, not a second player.

Four directions are the contract. Whether this stick closes two switches at once has not been measured, so a game is finishable with pure up, down, left, and right. Opposing directions cancel. Holding a direction is a level, not a stream of new presses. A one-shot verb listens for the edge (`cab_pressed`), so a button still held from the menu does not fire again on the first frame of the game.

Holding 1-player and 2-player is quit. `cab_poll` already does this, after a second on the cabinet and after 60 frames in a script. No verb lives on that chord.

## Reach decides the verb

Arcade panels are built so the finger nearest the stick takes the action you hit without looking, and buttons farther away take actions you choose. On a fixed panel the same rule runs backward: we put the frequent verb on the button the hand already covers.

Fitts's observation, applied here, is that a closer and larger target is the one you hit. We cannot enlarge the buttons. We can refuse to put the mash on the far one.

So:

1. If the game has one verb, it is `LOW`. `TL` and `TR` may also do that same verb, so a young hand mashing the cluster still plays. They never do a second, secret thing.
2. If the game has two verbs, they are `LOW` and `TL`. `TR` stays quiet or repeats `LOW`.
3. If the game has three verbs, `TR` is the one you decide to press, the spend or the shout. It is never the button a panicked moment requires.
4. `1P` and `2P` stay out of the verb list. Reaching them means the left hand has left the stick, or the right hand has crossed the panel.

A button means the same thing on the title, in the round, and on the result. The title is the toy. The stick on the title either plays the toy or does nothing. It does not slide a hidden body into a bad position.

## What age changes

The Partycade's crowd is mixed, and a turn is short. When a game does not name an audience, it ships as a walk-up game. A harder game says so in its first comment and in the Yard line, and it still uses the same button places.

Bilateral coordination of the arms is still improving at 8, and it keeps improving through the teens. It has not finished by 12. Symmetric two-hand actions come in earlier than asymmetric ones, where each hand does a different precise thing on the same beat. A young player can hold the stick or press the button. Asking both hands for a timed trick is a different game.

| | Walk-up, the default | Two-verb, about 8 and up | Three-verb, teens and adults |
| :--- | :--- | :--- | :--- |
| Verbs | One. `LOW`, and the other right-hand buttons may do it too | `LOW` and `TL` | `LOW`, `TL`, and a committed `TR` |
| Stick and button together | The button works alone. Holding a direction can aim it. The round is finishable if the two hands never have to be precise on the same frame | A chord may enrich the verb. The button alone still does something sensible | Chords, holds, and cancels are fair game |
| Timing | A wide window, many frames, a big target | A window the player can see coming | Tight timing is allowed. The tell is still visible |
| Failure | Soft, immediate, and readable. The run continues or restarts in a second | A round can end. The reason is on screen | A round can end hard. The reason is still on screen |
| Words | Playable with no text. The 8×8 font may label a score | A short blurb is enough | A blurb is enough. No manual |
| Length of a turn | A round resolves inside a minute or two, so the cabinet can be handed over | A few minutes | As long as the toy stays the same toy |
| Feedback | Picture, sound, and the body doing the thing, all large enough to read from a step away | Same, with a second sound for the second verb | Same. Subtlety is in the timing, not in a quiet success |

Toddlers are below this panel. A joystick study of children 17 to 35 months found they shove forward first, whatever the target, and that the youngest take many seconds to connect direction to result. This deck is a bartop with small buttons. The young floor for a walk-up game is about school age.

A four-year-old is a further loosening, the little band. Any stick direction does the one useful thing, every right-hand button does the verb, and a turn has no fail state. The first game in that band is the tea party, specified in [games/tea/DESIGN.md](games/tea/DESIGN.md). The button places stay the same.

Age never changes these:

* The stick is move or aim for the whole game.
* `LOW` is home.
* `1P` and `2P` are how you leave.
* A press answers on the frame it happens.
* Mastery is in space and timing. Remembering which mode the buttons are in is not a skill we sell.

## Hand response

Nintendo's word for this is *tegotae*, hand response: the press and the world's answer are one gesture. Steve Swink's version is that real-time control is driving, not a conversation. The correction has to be visible in the same moment as the intent, and the result has to be predictable, or the hand never trusts the toy. Miyamoto's teams made the block move in an empty room until the movement itself was the fun, and only then built the game around it. Will Wright's description of that habit is a shovel, which you pick up and use, rather than a piano, which you study.

On this cabinet that means:

* The simulation answers on the frame of the edge. Sixty frames a second is the budget. If the verb lands later, the windup is on screen this frame: a squash, a flash, a note.
* The answer is on the body the player is watching. A corner glyph is a score, not the feedback.
* Every verb has a picture and a sound. The room is social and the speaker is the second screen. A distinct pitch per verb. The synth callback is enough.
* A hold shows a held state: a lean, a charge, a light that stays on. A release shows the release.
* Facing shows the stick. A digital stick does not glow. The character does.
* A miss explains itself in the same motion that punishes it. The player sees the gap they fell through.
* Motion stays slow enough to steer. A body that crosses the screen in a few frames cannot be corrected, and an unpredictable correction feels like a broken button.
* The first success comes inside the first few seconds, in the space, from the player's own press. That first success is the lesson. Swink calls the moment traction. A party guest who does not get it puts the turn down.

Polish is the extra motion that sells the answer: the squash, the spark, the little drop in pitch. It rides on top of a result that was already correct. It is not a substitute for the result.

## Rules

A new game is checked against this list before it grows past a toy in an empty room.

1. Name the band in the first comment and in the Yard line: walk-up, two-verb, or three-verb.
2. Write one sentence of the form "the stick does ___, `LOW` does ___." If the sentence needs a mode, the design is two games.
3. Play the toy with nothing else in the room until the movement is pleasant. Then add the goal.
4. Put the frequent verb on `LOW`. Add `TL` only after that verb has been felt. Add `TR` only for a choice the player makes on purpose.
5. Keep one meaning per button for the whole session, including the title.
6. Listen for the edge on a one-shot verb. A held button sustains, and the sustain is visible.
7. Answer on the same frame, on the body, with a picture and a sound.
8. Make the round finishable on four directions. Treat a diagonal, if the stick ever reports one, as a gift.
9. Leave `1P` and `2P` for leaving. The quit chord stays free.
10. Leave volume and power alone.
11. Teach with the first success. A walk-up game is playable with the sound on and no reading.
12. For the walk-up band, `TL` and `TR` may repeat `LOW` and must not punish.
13. For the two-verb band, `LOW` alone still does something. The chord is extra.
14. End a turn in a state the next person can start from: a title, a score of one number, the stick at rest.
15. Prove it in `stress.sh`: the verb fires from stick and `LOW`, the frame of the press shows the answer, and a button held across the launch does not fire twice.

## Shapes that fit the panel

* **The body and the verb.** Stick moves. `LOW` acts in the facing direction. Keep is this, with one button and a wide catch.
* **The stick is the verb.** Being in the right place is the act. Lamp is this. `LOW` only restarts. This is the kindest walk-up shape, because one hand can play it.
* **The world comes to you.** Stick steers, the lane or the well scrolls. `LOW` confirms entry or the one shot. Orb's dive is this. Entering the well is a one-time commitment, which is a fair use of a button. A button that swaps the stick's meaning every few seconds is a different, worse thing.
* **The menu.** Stick picks a row. `LOW` confirms. The Yard is this. Confirmation is the same button as the verb inside the game you just left, so the hand does not relearn.
* **Pass the cabinet.** A round ends, a score shows, the next person presses `LOW`. `1P` and `2P` can mean "this turn is mine" before the round, because the stick is still free.
* **Split hands, the party shape.** One person holds the stick. The other holds `LOW` and, in a two-verb game, `TL`. The panel is already divided that way. This is the simultaneous two-human game this deck can host. Two people each trying to move and act is a game for a machine with two sticks.

## How hard a game is allowed to be

Difficulty lives in the space, the timing, and the read of the next second. A three-verb game for adults can be severe. The mapping stays boring. The player who has learned `LOW` on Keep should feel the same finger do the main thing in every later game. That shared home is how a cabinet of many games stays one toy.

A game that needs a sixth gameplay button, a second stick, an analog throw, or a gesture is a game for a different object. We make a smaller game that this deck can say completely.

## Where this comes from

* The deck itself, measured 2026-10-23 and written up in [GAMEDEV.md](GAMEDEV.md) § 2. Button places, the quit chord, and the single joystick are facts. The finger story is the standard arcade reading of those places: the column nearest the stick belongs to the index, and start buttons sit off to the side so the playing hand can stay down. Panel practice is summarized at [slagcoin's layout notes](https://www.slagcoin.com/joystick/layout.html).
* Fitts, via the practical form used in control layout: the frequent action goes on the short reach. A clear writeup is the accessibility tiers in [Designing Game Controls](https://gamedesignframework.net/designing-game-controls/).
* Steve Swink, *Game Feel*: real-time control, predictable result, immediate feedback, traction. The essay form is [Principles of Virtual Sensation](https://www.gamedeveloper.com/design/principles-of-virtual-sensation).
* Shigeru Miyamoto and Bill Trinen on *tegotae*, the hand's answer, and on building the moving body before the game. [Nintendo Life, 2016](https://www.nintendolife.com/news/2016/07/shigeru_miyamoto_and_bill_trinen_explain_some_of_the_key_principles_that_define_nintendo_games). Will Wright's shovel remark is in Nick Paumgarten's New Yorker profile, 20 December 2010.
* Nico Disseldorp on *Untitled Goose Game*: one clear thing per button, combinable, and clearer controls made people play in a way the room could watch. That is the party requirement.
* Age and the hands. Bilateral aiming is still maturing at 8 and keeps improving through adolescence (Barral and Debû, *Developmental Neuropsychology*, 2006, on 5-, 8-, and 11-year-olds; Serrien and colleagues, *Journal of Motor Behavior*, 2024, ages 7–17; a 2024 augmented-reality reaching study of 133 children, ages 6–17, found symmetric reaches ahead of asymmetric ones, with gains slowing and still continuing after 12). Toddlers on a joystick shove forward first (Kather and colleagues, *PLOS ONE* / PMC11658599, ages 17–35 months). Those results are why a chord is a later band, and why this bartop does not aim at toddlers.
