# Safari: a journey of three habitats, three gyms, and a picture book

Cart `games/carts/safari/`: `main.lua` rules, `pictures.lua` drawing, `songs.lua` music. Follows ADVENTURE.md ("Safari") and CASTLE.md's rules. Walk-up band (CONTROLS.md), controls unchanged: stick walks/dodges; LOW/TR toss an orb (gym: the buddy's move); TL swaps buddy with 2+ friends. New: a press next to Hoot's post opens the Field Book (stick left/right turns pages, any button closes).

## Story
Three Star Orbs fell and woke the monsters. Hoot, an owl ranger (our own), needs a Junior Ranger helper. The story screen (about 7 s, any button skips; returning players see only Hoot's welcome) shows it in pictures. Hoot's goal is always one picture in the HUD (and a line on the cream band): toss an orb, find a friend in a habitat (with an arrow toward it), beat a leader, look for a sparkly friend, win again for a gold star, find a sparkly X, then "Star Ranger".

## The journey
* Habitats: Sunny Meadow (Sparky, Sprout, Snooze), Spark Cave (Ember, Mystic, Giggle), Crystal Pond (Splash, Skywing). A caught friend no longer respawns as a wild target: it lives at home in its habitat, waves hello, and follows you (up to three buddies trail behind, the active one first). The only wild visitors are friends not yet met, and rare sparkly ones. A habitat whose friends are all found earns a stamp.
* Gyms: one per habitat (Captain Clover, Miss Glint, Skipper Ripple; aces Snooze, Giggle, Skywing), open to anyone with a buddy as before. The first win is the badge, rematches (up to three stars) are slightly longer and faster. First gym is as hard as the old first gym. Leaders react (cheer, ouch, worry, bow); your friends cheer from the stands.
* Sparkly coats: each friend has a rare second coat (one visit in 12 for an unmet friend, 1 in 14 for a met one without it, 1 in 60 once found; a long dry spell raises it). Shown with orbiting stars; a shiny follows you instead of the normal coat.
* Field Book: overview (stickers, silhouettes for seen, "?" for unmet, habitat stamps, badges and stars, goal) and one page per friend (both coats, home, move, voice, a line). A page opens when a new friend or coat is caught.
* Trainer cap changes colour with gyms won (red, sky, leaf, gold).

## Music (songs.lua, 8 bars of 16 steps, 6 tracks)
Habitat tracks: 1 hook, 2 bass, 3 pad, 4/5/6 the voices of that habitat's three friends (Pond's third is the tide). The hook and bass grow with the party; a friend's voice is silent until you walk near it in the wild (a teaser), then stays once it is yours (louder for your buddy). While an orb wobbles the lead drops out (suspense). Walking plays a tune in the habitat key in your buddy's timbre; the catch is a chord on the beat then a twinkle; wobbles climb the chord. Gym songs are in three sections (`music.play{keep=true}`): strong leader (bass, drums, thin hook), half (full hook, stabs), nearly beaten (all parts, driving, tempo x1.14); each hit is the next note of a rising run; being hurt drops the lead. Also the fanfare per gym key, a music-box book song, the story. Game logic never reads `music.step()`.

## Save (`safari.sav`)
Kept: `caught`, `badges` (gym wins), `best`, `dex` (bitmask). New, clamped: `shiny`, `seen` (bitmasks), `star1..star3` (0..3; an old save's badges become first stars), `zone`, `buddy`, `visits`. Saved at catches, wins, zone changes, and quit.

## Log lines
`safari caught N`, `goal K`, `story new|back`, `zone Z`, `seen X`, `sparkle X`, `orb`, `catch X`, `shiny X`, `stamp Z`, `berry`, `gym`, `gym section N`, `whew`, `badge N`, `star G N`, `book`.

## Pictures and memory
One 384x512 scene layer for ever (habitats, gyms, story), repainted in place on a scene change (no `rnd`, integer hashes). Everything else is live toon drawing; options tables are reused, nothing allocated per frame. Images stay at 768 KB.
