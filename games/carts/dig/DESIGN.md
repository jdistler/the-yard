# Dig: tunnels, critters, boulders, and buried gems

A cart: `games/carts/dig/` (`main.lua` has the rules, `pictures.lua` the drawing). The Yard lists it under Chest, blurb "dig tunnels, pop foes, find gems", band `5+`. `games/test.py` (run by `stress.sh`) plays the checks at the bottom.

Audience is a five-year-old who loves Dig Dug and colorful critters (and already plays Chest). Classic Dig Dug is punishing for young hands: tight grid corners, one-hit deaths, falling rocks that crush you, and awkward directional pumping. **Dig** keeps everything magical about Dig Dug—carving cozy tunnels through four colorful layers of earth, inflating goofy critters until they POP, dropping boulders on them for a mega bonk, and uncovering buried gems—while making it joyful, readable, and forgiving.

This is the walk-up band in [CONTROLS.md](../../../CONTROLS.md).

## The sentence

The stick digs and walks through the earth, and `LOW` (or `TL`/`TR`) puffs your pump!

## The promise

* **Smooth, snag-free digging:** pushing any direction gently centers him in the tunnel lane so he never gets stuck on a corner. Walking in dug tunnels is a bit faster than carving fresh dirt.
* **The pump aims itself:** pressing any right-hand button aims the air hose at the nearest critter within 2.5 tiles (showing golden target stars on who it will puff!), or puffs the way he faces if none is near.
* **3 puffs = POP!** One puff freezes and inflates the critter; two puffs makes it big and round; three puffs pops it into stars and a sparkling gem! Holding the button pumps steadily so he never has to frantically mash.
* **Boulders bonk critters, never the hero:** digging under a rock makes it wiggle for a full second ("Watch out! Rock rolling!"), then tumble down the tunnel. Any critter in its path gets a hilarious **BONK!**; if it rolls past Diggy, he hops safely aside.
* **Three hearts, soft restart:** touching a critter or dragon flame bounces it away and costs one heart (with generous blinking safety). Three hurts softly restart just that cave—his level and gem pile stay!
* **No reading required:** the cream band along the bottom narrates the story for a grown-up to read aloud.

## Who is underground

* **Diggy:** cheerful explorer in a red-and-white hard hat with a glowing headlamp and cozy blue suit.
* **Puff:** round rosy-orange critter wearing big round goggles (homage to Pooka). Bounces down tunnels and inflates like a balloon when puffed!
* **Char:** adorable little orange-coral dragon with a glowing tail flame (homage to Fygar & Charmander). Takes a big visible breath ("Char is puffing fire!") before breathing a short, slow puff of purple-orange fire.
* **Wobbly Boulders:** chunky grey rocks embedded in the earth that wiggle when undermined, then crash down to bonk critters below.
* **Buried Gems:** sparkling pink, blue, green, and gold jewels hidden in the dirt layers—dig into them to collect them!

## Saves (`dig.sav`)

* `best N`: highest cave level cleared (clamped `0..100000`).
* `gems N`: total gems collected across visits (clamped `0..100000`).

Written on every level clear. Missing or broken files open fresh at `0`.

## Controls

| Input | What it does |
| :--- | :--- |
| Stick (4-way) | Dig fresh earth or walk through tunnels (auto-centers in lanes) |
| `LOW`, `TL`, `TR` (press or hold) | Puff the air pump at the nearest critter (3 puffs = POP!); after level clear, start the next cave |
| `1P` + `2P` held | Quit (the cabinet rule) |
