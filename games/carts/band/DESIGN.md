# Band: the Starlight Stage

She conducts five friends and the song is built from what she does (CASTLE.md, "Band").

## A turn
1. **Setlist board.** A card per song. Learned songs have a gold star, the next unlearned one says NEW, the
   rest are padlocked. The stick moves the choice, any button starts. The chosen song's pad plays as a preview.
2. **Wake the friends.** The stick moves the spotlight round the stage (left/right: round the ring
   Pip, Unicorn, Pearl, Nib, Moth; up/down: across rows). A press wakes a sleeper: their track comes in
   (`music.track`), a fan takes a seat, their lamp lights. A press on a friend already playing is a solo
   (`music.cue`: a note of the chord under the next step, so mashing is always in key and on the grid).
   Doing nothing: a sleepy friend wakes by themselves every 5.5 s. Mashing one friend: after six solos the
   spotlight points at a sleepy one.
3. **Chorus.** When all five play, `music.play{keep = true}` swings the verse into the chorus (same chords,
   same length, same tempo, so it can switch at any step). The rig swings, the audience dances, a rainbow
   bar fills for 10 s (600 frames, counted in frames, never read from the music).
4. **Finish.** Stinger chord in the song's key, bows, confetti, a banner; a new song learned if it was the
   next one; new fans. Back to the board.

## Tracks (1-based, as in `music.track`)
1 pad (always) - 2 Unicorn harp melody - 3 Pip drums - 4 Moth bass - 5 Pearl bells - 6 Nib claps and shaker.
`songs.lua` holds the chords and the hand-written melodies; bass, pad, bells and drums are expanded from
per-bar patterns, so they follow the chord and any subset sounds right.

| Song | Feel | Chords |
| :--- | :--- | :--- |
| Moon Lullaby | 76 bpm, rocking, tri harp, music-box bells | F Dm Bb C |
| Parade March | 112 bpm, oom-pah, square trumpet, snare rolls | C F G C |
| Disco Kitty | 116 bpm, octave bass, 16th hats, saw lead | Am7 Dm7 G7 Cmaj7 |
| Twirly Waltz | 132 bpm, 3/4, eight bars | D Bm G A7, D G A7 D |

## Drawn in time
Drawing reads `music.step()` (and only drawing): each track's token under the step says whether it just
played, so Pip's kick drum swells on K, snare and crash flash on S and C, Moth's string shakes on his notes,
Pearl's bar for the note lights, Nib's tambourine shakes, the harp string for the melody note glows.
Everyone bounces on the beat; the audience hops in the chorus.

## Persistence (band.sav)
`songs` encores, `tunes` songs learned (0..4, Tea plays the newest), `fans` audience (seats show up to 40),
`last` the last song played. Read from other carts: `tea.photos` (frames on the stage wall, up to 4),
`garden.gardens` (a flower arch round the window from 3). A rare visitor, the owl on the rail, comes on
some visits (one `rnd` in `init`).

## Log lines
`band songs N`, `band song ID`, `band wake NAME`, `band solo NAME` (first per song), `band chorus`,
`band encore N`, `band learned N`, `band fans N`, `band fan N`, `band visitor owl`.
