/* sfx: a small synth for the cabinet's 44.1 kHz stereo ALSA output.
 *
 * Sixteen voices, five waves, an attack/release envelope, a pitch slide, and vibrato.
 * A step sequencer plays looping songs written as text, one string per track:
 *
 *   "C4 - E4 G4 . . C5 -"     a note per step; "-" holds, "." rests
 *   "K . H . S . H ."         drum tracks: K kick, S snare, H hat, C clap
 *
 * Everything is generated in the audio callback. No sample files.
 * The cabinet's volume buttons still own loudness; sfx_master only sets each game's mix.
 */
#ifndef SFX_H
#define SFX_H

#include "cab.h"

enum { W_SINE, W_TRI, W_SQUARE, W_SAW, W_NOISE, W_DRUM };

typedef struct {
    int wave;
    float hz, hz_end;  /* slide toward hz_end over the note (0 = no slide) */
    float dur;         /* seconds, including release */
    float vol;         /* 0..1 */
    float attack;      /* seconds */
    float release;     /* seconds at the end */
    float duty;        /* square: 0.5 default */
    float vib_hz, vib_depth; /* depth in semitones */
    float pan;         /* -1 left .. 1 right */
} sfx_t;

int sfx_init(void);
void sfx_master(float v);
/* The loudest sample allowed, out of 32767 (default 30000). Tea and Chest keep under 3000. */
void sfx_limit(int peak);
void sfx_play(const sfx_t *s);
/* Shorthands. midi 60 is C4. */
float sfx_midi_hz(float midi);
void sfx_tone(int wave, float hz, float dur, float vol);
void sfx_note(int wave, int midi, float dur, float vol);
void sfx_slide(int wave, float hz0, float hz1, float dur, float vol);
void sfx_noise(float dur, float vol, float hz);
/* Up to 8 midi notes in a row, step seconds apart. */
void sfx_arp(int wave, const int *midi, int n, float step, float vol);

typedef struct {
    const char *notes;
    int wave;
    float vol;
    float release; /* seconds */
    float attack;
    int transpose;
    float duty;
    float pan;
} sfx_track;

typedef struct {
    float bpm;
    int steps_per_beat;
    int ntracks;
    sfx_track tr[6];
} sfx_song;

void music_play(const sfx_song *s);
void music_stop(void);
void music_volume(float v);   /* 0..1, eases */
void music_tempo(float k);    /* 1 is the song's own speed */
int music_step(void);         /* current step, for animation in time with the song */
const sfx_song *music_current(void);

#endif
