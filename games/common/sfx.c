/* sfx: the synth and the sequencer. See sfx.h. All state shared with the audio thread
 * is changed under SDL_LockAudio. */
#include "sfx.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define RATE 44100
#define NVOICE 16
#define MAXSTEPS 128

typedef struct {
    int on, wave;
    double phase;
    float hz, hz_end, vol, pan, duty, vib_hz, vib_depth;
    int len, pos, att, rel;
    Uint32 noise;
    float noise_hold;
    int noise_ctr, noise_period;
    int drum; /* 'K', 'S', 'H', 'C' */
    int track; /* 1 + the song track that owns it, 0 for an effect */
} voice;

static voice vs[NVOICE];
static float master = 0.35f;
static float peak = 30000.f;
static int ready;

/* Parsed song: per track, per step a midi note, -1 rest, -2 hold, -3 .. -6 a drum (K S H C). */
static const sfx_song *song;
static signed char steps[6][MAXSTEPS];
static int nsteps[6];
static int song_len, song_step, step_left, step_samples;
static float mus_vol = 1.f, mus_target = 1.f, mus_tempo = 1.f;
static int base_step;
static int track_voice[6];

float sfx_midi_hz(float midi) { return 440.f * powf(2.f, (midi - 69.f) / 12.f); }

static int alloc_voice(void)
{
    int best = 0, best_left = 1 << 30;
    for (int i = 0; i < NVOICE; i++) {
        int left;
        if (!vs[i].on)
            return i;
        left = vs[i].len - vs[i].pos;
        if (left < best_left) {
            best_left = left;
            best = i;
        }
    }
    return best;
}

static void start_voice(int i, const sfx_t *s, int drum)
{
    voice *v = &vs[i];
    memset(v, 0, sizeof *v);
    v->on = 1;
    v->wave = s->wave;
    v->hz = s->hz;
    v->hz_end = s->hz_end;
    v->vol = s->vol;
    v->pan = s->pan;
    v->duty = s->duty > 0 ? s->duty : 0.5f;
    v->vib_hz = s->vib_hz;
    v->vib_depth = s->vib_depth;
    v->len = (int)(s->dur * RATE);
    if (v->len < 64)
        v->len = 64;
    v->att = (int)(s->attack * RATE);
    if (v->att < 32)
        v->att = 32;
    v->rel = (int)(s->release * RATE);
    if (v->rel < 64)
        v->rel = 64;
    if (v->rel > v->len)
        v->rel = v->len;
    v->noise = 0x12345u + (Uint32)i * 7919u;
    v->noise_period = s->hz > 0 && s->wave == W_NOISE ? (int)(RATE / s->hz) : 1;
    if (v->noise_period < 1)
        v->noise_period = 1;
    v->drum = drum;
}

void sfx_play(const sfx_t *s)
{
    if (!ready)
        return;
    SDL_LockAudio();
    start_voice(alloc_voice(), s, 0);
    SDL_UnlockAudio();
}

void sfx_tone(int wave, float hz, float dur, float vol)
{
    sfx_t s = {wave, hz, 0, dur, vol, 0.004f, dur * 0.6f, 0.5f, 0, 0, 0};
    sfx_play(&s);
}

void sfx_note(int wave, int midi, float dur, float vol) { sfx_tone(wave, sfx_midi_hz((float)midi), dur, vol); }

void sfx_slide(int wave, float hz0, float hz1, float dur, float vol)
{
    sfx_t s = {wave, hz0, hz1, dur, vol, 0.004f, dur * 0.5f, 0.5f, 0, 0, 0};
    sfx_play(&s);
}

void sfx_noise(float dur, float vol, float hz)
{
    sfx_t s = {W_NOISE, hz, 0, dur, vol, 0.002f, dur * 0.9f, 0.5f, 0, 0, 0};
    sfx_play(&s);
}

/* Arpeggio: voices with a delayed start, made by a silent lead-in of pos < 0. */
void sfx_arp(int wave, const int *midi, int n, float step, float vol)
{
    if (!ready)
        return;
    if (n > 8)
        n = 8;
    SDL_LockAudio();
    for (int k = 0; k < n; k++) {
        sfx_t s = {wave, sfx_midi_hz((float)midi[k]), 0, step * 2.2f, vol, 0.004f, step * 1.6f, 0.5f, 0, 0, 0};
        int i = alloc_voice();
        start_voice(i, &s, 0);
        vs[i].pos = -(int)(k * step * RATE);
    }
    SDL_UnlockAudio();
}

void sfx_master(float v) { master = v; }
void sfx_limit(int p) { peak = p < 100 ? 100.f : p > 32000 ? 32000.f : (float)p; }

static float wave_at(voice *v, float hz)
{
    float ph;
    v->phase += hz / RATE;
    if (v->phase >= 1.0)
        v->phase -= floor(v->phase);
    ph = (float)v->phase;
    switch (v->wave) {
    case W_SINE:
        return sinf(ph * 6.2831853f);
    case W_TRI:
        return ph < 0.5f ? ph * 4.f - 1.f : 3.f - ph * 4.f;
    case W_SQUARE:
        return ph < v->duty ? 0.6f : -0.6f;
    case W_SAW:
        return (ph * 2.f - 1.f) * 0.6f;
    default:
        return 0;
    }
}

static float noise_at(voice *v)
{
    if (--v->noise_ctr <= 0) {
        v->noise ^= v->noise << 13;
        v->noise ^= v->noise >> 17;
        v->noise ^= v->noise << 5;
        v->noise_hold = (float)(v->noise & 0xffff) / 32768.f - 1.f;
        v->noise_ctr = v->noise_period;
    }
    return v->noise_hold;
}

static float drum_at(voice *v)
{
    float t = (float)v->pos / RATE;
    switch (v->drum) {
    case 'K': {
        float hz = 50.f + 110.f * expf(-t * 30.f);
        return sinf((float)(v->phase += hz / RATE) * 6.2831853f) * 1.2f;
    }
    case 'S':
        return noise_at(v) * 0.7f + 0.4f * sinf((float)(v->phase += 190.0 / RATE) * 6.2831853f);
    case 'C':
        return noise_at(v) * (fmodf(t, 0.012f) < 0.006f || t > 0.03f ? 0.8f : 0.2f);
    default: /* hat */
        return noise_at(v) * 0.5f;
    }
}

static void parse_track(int t, const char *s)
{
    int n = 0;
    const char *p = s;
    static const int semis[7] = {9, 11, 0, 2, 4, 5, 7}; /* A B C D E F G */
    while (*p && n < MAXSTEPS) {
        while (*p == ' ' || *p == '|' || *p == '\n')
            p++;
        if (!*p)
            break;
        if (*p == '.') {
            steps[t][n++] = -1;
            p++;
        } else if (*p == '-') {
            steps[t][n++] = -2;
            p++;
        } else if ((*p == 'K' || *p == 'S' || *p == 'H' || *p == 'C') &&
                   !(*p == 'C' && (p[1] == '#' || p[1] == 'b' || (p[1] >= '0' && p[1] <= '9')))) {
            /* A drum letter. C followed by a digit or an accidental is the note C. */
            steps[t][n++] = (signed char)(*p == 'K' ? -3 : *p == 'S' ? -4 : *p == 'H' ? -5 : -6);
            p++;
        } else if (*p >= 'A' && *p <= 'G') {
            int semi = semis[*p - 'A'], oct = 4;
            p++;
            if (*p == '#')
                semi++, p++;
            else if (*p == 'b')
                semi--, p++;
            if (*p >= '0' && *p <= '9')
                oct = *p++ - '0';
            {
                int m = 12 * (oct + 1) + semi;
                steps[t][n++] = (signed char)(m < 0 ? 0 : m > 127 ? 127 : m);
            }
        } else
            p++;
    }
    nsteps[t] = n;
}

static void song_tick(void)
{
    for (int t = 0; t < song->ntracks; t++) {
        const sfx_track *tr = &song->tr[t];
        int len = nsteps[t];
        int st, vi;
        if (len <= 0)
            continue;
        st = steps[t][song_step % len];
        if (st == -2)
            continue;
        vi = track_voice[t];
        if (vi >= 0 && vs[vi].on && vs[vi].track == t + 1 && vs[vi].len > 0) {
            /* Release whatever this track was holding. */
            int left = vs[vi].len - vs[vi].pos;
            if (left > vs[vi].rel)
                vs[vi].len = vs[vi].pos + vs[vi].rel;
        }
        track_voice[t] = -1;
        if (st == -1)
            continue;
        {
            int hold = 1;
            sfx_t s;
            memset(&s, 0, sizeof s);
            while (hold < len && steps[t][(song_step + hold) % len] == -2)
                hold++;
            s.vol = tr->vol * mus_vol;
            s.pan = tr->pan;
            s.attack = tr->attack;
            s.release = tr->release > 0 ? tr->release : 0.05f;
            s.duty = tr->duty;
            if (st <= -3) {
                char d = st == -3 ? 'K' : st == -4 ? 'S' : st == -5 ? 'H' : 'C';
                s.wave = W_NOISE;
                s.dur = d == 'K' ? 0.22f : d == 'S' ? 0.16f : d == 'C' ? 0.12f : 0.05f;
                s.release = s.dur * 0.95f;
                s.hz = d == 'H' ? RATE : d == 'S' ? RATE / 2.f : RATE / 3.f;
                vi = alloc_voice();
                start_voice(vi, &s, d);
                vs[vi].track = t + 1;
            } else {
                s.wave = tr->wave;
                s.hz = sfx_midi_hz((float)(st + tr->transpose));
                s.dur = hold * (float)step_samples / RATE + s.release;
                vi = alloc_voice();
                start_voice(vi, &s, 0);
                vs[vi].track = t + 1;
            }
            track_voice[t] = vi;
        }
    }
    song_step++;
    if (song_len > 0 && song_step >= song_len * 64)
        song_step %= song_len;
}

static void fill(void *ud, Sint16 *out, int frames)
{
    (void)ud;
    for (int i = 0; i < frames; i++) {
        float l = 0, r = 0;
        if (song) {
            if (--step_left <= 0) {
                step_left = step_samples;
                song_tick();
            }
        }
        mus_vol += (mus_target - mus_vol) * 0.00005f;
        for (int k = 0; k < NVOICE; k++) {
            voice *v = &vs[k];
            float s, env, hz;
            if (!v->on)
                continue;
            if (v->pos < 0) {
                v->pos++;
                continue;
            }
            if (v->pos >= v->len) {
                v->on = 0;
                continue;
            }
            hz = v->hz;
            if (v->hz_end > 0)
                hz = v->hz * powf(v->hz_end / v->hz, (float)v->pos / v->len);
            if (v->vib_depth > 0)
                hz *= powf(2.f, v->vib_depth / 12.f * sinf(6.2831853f * v->vib_hz * v->pos / RATE));
            if (v->drum)
                s = drum_at(v);
            else if (v->wave == W_NOISE)
                s = noise_at(v);
            else
                s = wave_at(v, hz);
            env = 1.f;
            if (v->pos < v->att)
                env = (float)v->pos / v->att;
            if (v->len - v->pos < v->rel) {
                float k2 = (float)(v->len - v->pos) / v->rel;
                env *= k2 * k2;
            }
            s *= env * v->vol;
            l += s * (v->pan > 0 ? 1.f - v->pan : 1.f);
            r += s * (v->pan < 0 ? 1.f + v->pan : 1.f);
            v->pos++;
        }
        l *= master;
        r *= master;
        /* Soft clip so a pile of voices bends instead of cracking. */
        l = l / (1.f + fabsf(l)) * 30000.f;
        r = r / (1.f + fabsf(r)) * 30000.f;
        out[2 * i] = (Sint16)(l > peak ? peak : l < -peak ? -peak : l);
        out[2 * i + 1] = (Sint16)(r > peak ? peak : r < -peak ? -peak : r);
    }
}

int sfx_init(void)
{
    memset(vs, 0, sizeof vs);
    song = NULL;
    for (int t = 0; t < 6; t++)
        track_voice[t] = -1;
    if (cab_audio_open(fill, NULL) != 0)
        return -1;
    ready = 1;
    return 0;
}

void music_play(const sfx_song *s)
{
    if (!ready)
        return;
    SDL_LockAudio();
    song = NULL;
    song_len = 0;
    if (s) {
        for (int t = 0; t < s->ntracks && t < 6; t++) {
            parse_track(t, s->tr[t].notes);
            if (nsteps[t] > song_len)
                song_len = nsteps[t];
            track_voice[t] = -1;
        }
        base_step = (int)(RATE * 60.f / (s->bpm * (s->steps_per_beat > 0 ? s->steps_per_beat : 4)));
        if (base_step < 100)
            base_step = 100;
        step_samples = (int)(base_step / mus_tempo);
        song_step = 0;
        step_left = 1;
        song = s;
    }
    SDL_UnlockAudio();
}

void music_stop(void) { music_play(NULL); }
void music_volume(float v) { mus_target = v; }
void music_tempo(float k)
{
    if (k < 0.25f)
        k = 0.25f;
    SDL_LockAudio();
    mus_tempo = k;
    if (base_step)
        step_samples = (int)(base_step / k);
    SDL_UnlockAudio();
}
int music_step(void) { return song ? song_step : 0; }
const sfx_song *music_current(void) { return song; }
