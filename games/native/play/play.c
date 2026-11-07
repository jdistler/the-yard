/* play: the Shelf's game player. A small libretro frontend on the cabinet runtime (engine/cab_gl.c).
 *
 *   play <system> <rom>          e.g. play nes "/mnt/sdcard/library/nes/Super Mario Bros.nes"
 *
 * Why not the stock RetroArch 1.7.4: its udev input reads arrow keys only from devices tagged
 * ID_INPUT_KEYBOARD, and the deck (uart-keys) is tagged a joystick whose stick sends KEY_UP..KEY_RIGHT,
 * so the stick would be dead; there is no uinput to fake one. This player reads the deck the way every
 * Yard game does (cab_poll), so it also gets the cabinet's own quit meter (1P+2P held a second), the
 * upright 768x1024 picture, and room on the tall glass for a marquee and a button legend.
 *
 * Picture: the core's frame is drawn nearest-neighbour at a whole-number scale into a scratch target,
 * then that is stretched (bilinear) to the full 768 width at the core's aspect ratio: crisp pixels with
 * no uneven columns (the Mali's fragment shaders are mediump, so the usual one-pass "sharp bilinear"
 * shader would wobble). Sound: the core's rate is resampled to 44100 with a small rate control that
 * holds the queue half full. Pacing: one core frame per vsync when the core runs at 59.5-60.5 Hz,
 * otherwise by the clock. Saves: battery RAM is written to <lib>/saves/<rom>.srm when it changes
 * (checked every 5 s) and on the way out.
 *
 * Library root is PLAY_LIB (default /mnt/sdcard/library); cores in <lib>/cores unless built in.
 */
#include "gfx.h"
#include "libretro.h"

#include <dlfcn.h>
#include <errno.h>
#include <math.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "play_sys.h"
#include "play_gl.h"

/* ------------------------------------------------------------------ the core */

static struct {
    void *so;
    void (*init)(void);
    void (*deinit)(void);
    void (*get_system_info)(struct retro_system_info *);
    void (*get_system_av_info)(struct retro_system_av_info *);
    void (*set_environment)(retro_environment_t);
    void (*set_video_refresh)(retro_video_refresh_t);
    void (*set_audio_sample)(retro_audio_sample_t);
    void (*set_audio_sample_batch)(retro_audio_sample_batch_t);
    void (*set_input_poll)(retro_input_poll_t);
    void (*set_input_state)(retro_input_state_t);
    void (*set_controller_port_device)(unsigned, unsigned);
    void (*run)(void);
    bool (*load_game)(const struct retro_game_info *);
    void (*unload_game)(void);
    void *(*get_memory_data)(unsigned);
    size_t (*get_memory_size)(unsigned);
    size_t (*serialize_size)(void);
    bool (*serialize)(void *, size_t);
    bool (*unserialize)(const void *, size_t);
} core;

static const struct play_sys *sys;
static char lib[512], sysdir[600], savedir[600], srm_path[1200], rom_title[256];
static struct retro_system_av_info av;
static enum retro_pixel_format pixfmt = RETRO_PIXEL_FORMAT_0RGB1555;
static int rotation; /* RETRO_ENVIRONMENT_SET_ROTATION, in quarter turns counter-clockwise */
static int frame_no;
static FILE *log_f;

static void plog(const char *fmt, ...)
{
    va_list ap;
    char buf[1024];
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    cab_log("play: %s", buf);
}

static void core_log(enum retro_log_level level, const char *fmt, ...)
{
    va_list ap;
    char buf[1024];
    int n;
    if (level < RETRO_LOG_INFO && !getenv("PLAY_DEBUG"))
        return;
    va_start(ap, fmt);
    n = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    while (n > 0 && n < (int)sizeof buf && (buf[n - 1] == '\n' || buf[n - 1] == '\r'))
        buf[--n] = 0;
    cab_log("core: %s", buf);
}

/* Core options: the system's defaults (play_sys.h), else whatever the core declared first. */
#define MAX_VARS 192
static struct {
    char key[96], val[160];
} vars[MAX_VARS];
static int nvars, vars_dirty;

static void var_set(const char *key, const char *val)
{
    for (int i = 0; i < nvars; i++)
        if (!strcmp(vars[i].key, key)) {
            snprintf(vars[i].val, sizeof vars[i].val, "%s", val);
            return;
        }
    if (nvars < MAX_VARS) {
        snprintf(vars[nvars].key, sizeof vars[nvars].key, "%s", key);
        snprintf(vars[nvars].val, sizeof vars[nvars].val, "%s", val);
        nvars++;
    }
}

static const char *var_get(const char *key)
{
    for (int i = 0; i < nvars; i++)
        if (!strcmp(vars[i].key, key))
            return vars[i].val;
    return NULL;
}

/* Options the player forces (sys->opts, "key=value;key=value"), after the core's own defaults. */
static void apply_sys_opts(void)
{
    char buf[1024], *save = NULL;
    if (!sys->opts)
        return;
    snprintf(buf, sizeof buf, "%s", sys->opts);
    for (char *t = strtok_r(buf, ";", &save); t; t = strtok_r(NULL, ";", &save)) {
        char *eq = strchr(t, '=');
        if (!eq)
            continue;
        *eq = 0;
        var_set(t, eq + 1);
    }
}

/* "Description; first|second|third": the first value is the default. */
static void declare_var(const char *key, const char *value)
{
    char def[160];
    const char *semi = strchr(value, ';');
    const char *p = semi ? semi + 1 : value;
    int n = 0;
    while (*p == ' ')
        p++;
    while (p[n] && p[n] != '|' && n < (int)sizeof def - 1) {
        def[n] = p[n];
        n++;
    }
    def[n] = 0;
    if (!var_get(key))
        var_set(key, def);
}

static bool environment(unsigned cmd, void *data)
{
    switch (cmd & 0xffff) {
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        ((struct retro_log_callback *)data)->log = core_log;
        return true;
    case RETRO_ENVIRONMENT_GET_CAN_DUPE:
        *(bool *)data = true;
        return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
        enum retro_pixel_format f = *(enum retro_pixel_format *)data;
        if (f > RETRO_PIXEL_FORMAT_RGB565)
            return false;
        pixfmt = f;
        return true;
    }
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        *(const char **)data = sysdir;
        return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *(const char **)data = savedir;
        return true;
    case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
        *(const char **)data = sysdir;
        return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES: {
        const struct retro_variable *v = data;
        for (; v && v->key; v++)
            declare_var(v->key, v->value);
        apply_sys_opts();
        return true;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        struct retro_variable *v = data;
        v->value = var_get(v->key);
        return v->value != NULL;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        *(bool *)data = vars_dirty;
        vars_dirty = 0;
        return true;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
        *(unsigned *)data = 0; /* SET_VARIABLES only: the simplest form, which every core still speaks */
        return true;
    case RETRO_ENVIRONMENT_SET_ROTATION:
        rotation = *(const unsigned *)data & 3;
        return true;
    case RETRO_ENVIRONMENT_SET_GEOMETRY:
        av.geometry = *(const struct retro_game_geometry *)data;
        return true;
    case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        av = *(const struct retro_system_av_info *)data;
        return true;
    case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
        return true;
    case RETRO_ENVIRONMENT_GET_LANGUAGE:
        *(unsigned *)data = RETRO_LANGUAGE_ENGLISH;
        return true;
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
    case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
    case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
    case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO:
    case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
    case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
        return true;
    case RETRO_ENVIRONMENT_SET_MESSAGE:
        plog("message: %s", ((const struct retro_message *)data)->msg);
        return true;
    case RETRO_ENVIRONMENT_SHUTDOWN:
        plog("core asked to shut down");
        return true;
    case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE:
        *(int *)data = 3;
        return true;
    case RETRO_ENVIRONMENT_GET_FASTFORWARDING:
        *(bool *)data = false;
        return true;
    default:
        return false;
    }
}

/* ------------------------------------------------------------------ video */

static const void *last_frame;
static unsigned last_w, last_h;
static size_t last_pitch;
static Uint16 *conv;   /* 0RGB1555 -> RGB565, or a packed copy of RGB565 */
static Uint32 *conv32; /* XRGB8888 packed */

extern double play_t_upload, play_t_draw, play_t_present;
static double t_core;
static int bench; /* PLAY_BENCH=<seconds>: no screen, no sound; run the core flat out and report */
/* The bench's sound: a running sum of squares of what the core made (after its first 2 s). */
static double bench_sq;
static long bench_n, bench_frames_in;
static double bench_sound_level(void) { return bench_n ? sqrt(bench_sq / bench_n) : 0; }

static void video_refresh(const void *data, unsigned w, unsigned h, size_t pitch)
{
    if (!data || bench) /* dupe: keep the last frame on the texture */
        return;
    last_frame = data;
    last_w = w;
    last_h = h;
    last_pitch = pitch;
    play_gl_upload(data, w, h, pitch, pixfmt);
}

/* ------------------------------------------------------------------ sound */

#define RING (1 << 14) /* stereo frames, about 370 ms at 44100 */
static Sint16 ring[RING * 2];
static volatile unsigned ring_w, ring_r;
static double src_pos, src_ratio = 1.0, drc = 1.0;
static Sint16 prev_l, prev_r;
static int underruns;

static unsigned ring_fill(void) { return (ring_w - ring_r) & (RING - 1); }

static void audio_fill(void *ud, Sint16 *out, int frames)
{
    (void)ud;
    for (int i = 0; i < frames; i++) {
        if (ring_r == ring_w) {
            out[i * 2] = out[i * 2 + 1] = 0;
            if (i == 0)
                underruns++;
            continue;
        }
        out[i * 2] = ring[ring_r * 2];
        out[i * 2 + 1] = ring[ring_r * 2 + 1];
        ring_r = (ring_r + 1) & (RING - 1);
    }
}

/* Linear resampling from the core's rate to 44100, ratio nudged by drc. */
static size_t audio_batch(const int16_t *data, size_t frames)
{
    if (bench) {
        bench_frames_in += frames;
        if (bench_frames_in > av.timing.sample_rate * 2)
            for (size_t i = 0; i < frames * 2; i += 3) {
                bench_sq += (double)data[i] * data[i];
                bench_n++;
            }
        return frames;
    }
    double step = src_ratio * drc;
    for (size_t i = 0; i < frames; i++) {
        Sint16 l = data[i * 2], r = data[i * 2 + 1];
        while (src_pos < 1.0) {
            unsigned nw = (ring_w + 1) & (RING - 1);
            if (nw == ring_r)
                break; /* full: drop */
            ring[ring_w * 2] = (Sint16)(prev_l + (l - prev_l) * src_pos);
            ring[ring_w * 2 + 1] = (Sint16)(prev_r + (r - prev_r) * src_pos);
            ring_w = nw;
            src_pos += step;
        }
        src_pos -= 1.0;
        prev_l = l;
        prev_r = r;
    }
    return frames;
}

static void audio_sample(int16_t l, int16_t r)
{
    int16_t s[2] = {l, r};
    audio_batch(s, 1);
}

/* ------------------------------------------------------------------ input */

static unsigned pad;  /* RetroPad bits for port 0 */
static int coin_t;    /* arcade: frames left of the coin-then-start pulse */
/* PLAY_ADVANCE=<frame>: the board's "Advance" key (F2) held for 10 frames from that frame. Only for making a
 * Williams board's settings memory on the PC: blank, it stops on FACTORY SETTINGS RESTORED until an operator
 * presses Advance, a key the deck doesn't have. games/shelf/nvram/ keeps the result. */
static int advance_at = -1, advance_down;

static void input_poll(void) {}

static int16_t input_state(unsigned port, unsigned device, unsigned index, unsigned id)
{
    (void)index;
    if (device == RETRO_DEVICE_KEYBOARD)
        return id == RETROK_F2 && advance_down;
    if (port != 0 || (device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD)
        return 0;
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK)
        return (int16_t)pad;
    return id < 16 ? (pad >> id) & 1 : 0;
}

/* The deck to RetroPad bits, through the system's map. While 1P and 2P are both down (the quit
 * hold) neither reaches the game, so leaving does not also press Start and Select. */
extern int game_btn[3]; /* the game's own buttons, from the index (read_index) */
/* Held now, or pressed and let go since the last frame (cab_tapped): no tap is lost. */
static int deck(int b) { return cab_down(0, b) || cab_tapped(0, b); }

static void read_deck(void)
{
    unsigned p = 0;
    int both = cab_down(0, CAB_1P) && cab_down(0, CAB_2P);
    if (deck(CAB_UP)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_UP;
    if (deck(CAB_DOWN)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_DOWN;
    if (deck(CAB_LEFT)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_LEFT;
    if (deck(CAB_RIGHT)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_RIGHT;
    for (int i = 0; i < 3; i++) {
        static const int decks[3] = {CAB_LOW, CAB_TL, CAB_TR};
        int b = game_btn[i] != -2 ? game_btn[i] : sys->btn[i];
        if (b >= 0 && deck(decks[i]))
            p |= 1u << b;
    }
    if (!both) {
        if (sys->coin_start) {
            /* Arcade: 1P is "play": a coin, then Start, so nobody hunts for a coin button. 2P is a coin. */
            /* The coin for 6 frames, then a third of a second for the board to count it (1943 ignored a Start
             * pressed as the coin was let go), then Start for 8 frames. */
            if (cab_pressed(0, CAB_1P))
                coin_t = 40;
            if (coin_t > 34) p |= 1u << RETRO_DEVICE_ID_JOYPAD_SELECT;
            else if (coin_t > 6 && coin_t <= 14) p |= 1u << RETRO_DEVICE_ID_JOYPAD_START;
            if (coin_t > 0) coin_t--;
            if (cab_down(0, CAB_2P)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_SELECT;
        } else {
            if (cab_down(0, CAB_1P)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_START;
            if (cab_down(0, CAB_2P)) p |= 1u << RETRO_DEVICE_ID_JOYPAD_SELECT;
        }
    }
    pad = p;
}

/* ------------------------------------------------------------------ saves */

/* Suspend and resume (consoles only; an arcade board always starts fresh, so its scores mean something):
 * leaving with the 1P+2P hold keeps the game's whole state in saves/<system>/<rom>.state, and the next launch
 * goes on from there. /tmp/shelf.fresh (written by Home's browser for "start over") skips it once. */
static char state_path[1200];

static void state_resume(void)
{
    FILE *f;
    long n;
    void *buf;
    if (sys->coin_start || !state_path[0])
        return;
    if (!access("/tmp/shelf.fresh", F_OK)) {
        unlink("/tmp/shelf.fresh");
        plog("starting over (no resume)");
        return;
    }
    if (!(f = fopen(state_path, "rb")))
        return;
    fseek(f, 0, SEEK_END);
    n = ftell(f);
    fseek(f, 0, SEEK_SET);
    buf = malloc(n > 0 ? n : 1);
    if (buf && fread(buf, 1, n, f) == (size_t)n) {
        core.run(); /* (some cores take a state only after their first frame) */
        plog(core.unserialize(buf, n) ? "resumed (%ld bytes)" : "resume refused (%ld bytes)", n);
    }
    free(buf);
    fclose(f);
}

static void state_suspend(void)
{
    size_t n;
    void *buf;
    if (sys->coin_start || !state_path[0] || !(n = core.serialize_size()))
        return;
    if ((buf = malloc(n)) && core.serialize(buf, n)) {
        extern int write_state_file(const char *, const void *, size_t);
        if (write_state_file(state_path, buf, n) == 0)
            plog("suspended (%zu bytes)", n);
    }
    free(buf);
}

static unsigned char *srm_copy;
static size_t srm_size;

static int write_file(const char *path, const void *data, size_t n);
int write_state_file(const char *path, const void *data, size_t n) { return write_file(path, data, n); }

static int write_file(const char *path, const void *data, size_t n)
{
    char tmp[1300];
    FILE *f;
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    if (!(f = fopen(tmp, "wb")))
        return -1;
    if (fwrite(data, 1, n, f) != n) {
        fclose(f);
        return -1;
    }
    fflush(f);
    fsync(fileno(f));
    fclose(f);
    return rename(tmp, path);
}

static void srm_load(void)
{
    void *mem = core.get_memory_data ? core.get_memory_data(RETRO_MEMORY_SAVE_RAM) : NULL;
    size_t n = core.get_memory_size ? core.get_memory_size(RETRO_MEMORY_SAVE_RAM) : 0;
    FILE *f;
    if (!mem || !n)
        return;
    srm_size = n;
    srm_copy = malloc(n);
    if ((f = fopen(srm_path, "rb"))) {
        size_t got = fread(mem, 1, n, f);
        fclose(f);
        plog("save loaded: %zu of %zu bytes", got, n);
    }
    if (srm_copy)
        memcpy(srm_copy, mem, n);
}

static void srm_flush(const char *why)
{
    void *mem = core.get_memory_data ? core.get_memory_data(RETRO_MEMORY_SAVE_RAM) : NULL;
    if (!mem || !srm_copy || !srm_size || !memcmp(mem, srm_copy, srm_size))
        return;
    if (write_file(srm_path, mem, srm_size) == 0) {
        memcpy(srm_copy, mem, srm_size);
        plog("save written (%s): %zu bytes", why, srm_size);
    } else
        plog("save failed: %s: %s", srm_path, strerror(errno));
}

/* ------------------------------------------------------------------ the library's index */

/* The game's line in <lib>/index.tsv (tools/shelf_index.py): its proper title and what its buttons do.
 * system, file, title, year, maker, art, tags, blurb, labels ("FIRE|LOOP|"). */
char play_verbs[3][32];
int game_btn[3] = {-2, -2, -2}; /* -2: the system's own (play_sys.h) */
int play_has_verbs;

static void read_index(const char *rom)
{
    char path[700], line[2048];
    const char *base = strrchr(rom, '/') ? strrchr(rom, '/') + 1 : rom;
    FILE *f;
    snprintf(path, sizeof path, "%s/index.tsv", lib);
    if (!(f = fopen(path, "r")))
        return;
    while (fgets(line, sizeof line, f)) {
        char *field[10] = {0}, *p = line;
        int n = 0;
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == '#')
            continue;
        while (n < 10) {
            field[n++] = p;
            if (!(p = strchr(p, '\t')))
                break;
            *p++ = 0;
        }
        if (n < 3 || strcmp(field[0], sys->id) || strcmp(field[1], base))
            continue;
        if (field[2][0])
            snprintf(rom_title, sizeof rom_title, "%s", field[2]);
        if (n >= 11 && field[10][0]) {
            /* This game's own buttons ("B|A|R"): RetroPad names for the lower, top-left and top-right. */
            static const char *names[16] = {"B", "Y", "SELECT", "START", "UP", "DOWN", "LEFT", "RIGHT",
                                            "A", "X", "L", "R", "L2", "R2", "L3", "R3"};
            char *v = field[10];
            for (int i = 0; i < 3 && v; i++) {
                char *bar = strchr(v, '|');
                if (bar)
                    *bar = 0;
                for (int k = 0; k < 16; k++)
                    if (!strcmp(v, names[k]))
                        game_btn[i] = k;
                v = bar ? bar + 1 : NULL;
            }
        }
        if (n >= 9 && field[8][0]) {
            char *v = field[8];
            for (int i = 0; i < 3 && v; i++) {
                char *bar = strchr(v, '|');
                if (bar)
                    *bar = 0;
                snprintf(play_verbs[i], sizeof play_verbs[i], "%s", v);
                v = bar ? bar + 1 : NULL;
            }
            play_has_verbs = 1;
        }
        break;
    }
    fclose(f);
}

/* ------------------------------------------------------------------ main */

static int load_core(const char *path)
{
    if (!(core.so = dlopen(path, RTLD_NOW | RTLD_LOCAL))) {
        plog("dlopen %s: %s", path, dlerror());
        return -1;
    }
#define SYM(field, name)                                         \
    do {                                                         \
        void *s = dlsym(core.so, name);                          \
        if (!s) {                                                \
            plog("%s has no %s", path, name);                    \
            return -1;                                           \
        }                                                        \
        memcpy(&core.field, &s, sizeof s);                       \
    } while (0)
    SYM(init, "retro_init");
    SYM(deinit, "retro_deinit");
    SYM(get_system_info, "retro_get_system_info");
    SYM(get_system_av_info, "retro_get_system_av_info");
    SYM(set_environment, "retro_set_environment");
    SYM(set_video_refresh, "retro_set_video_refresh");
    SYM(set_audio_sample, "retro_set_audio_sample");
    SYM(set_audio_sample_batch, "retro_set_audio_sample_batch");
    SYM(set_input_poll, "retro_set_input_poll");
    SYM(set_input_state, "retro_set_input_state");
    SYM(set_controller_port_device, "retro_set_controller_port_device");
    SYM(run, "retro_run");
    SYM(load_game, "retro_load_game");
    SYM(unload_game, "retro_unload_game");
    SYM(get_memory_data, "retro_get_memory_data");
    SYM(get_memory_size, "retro_get_memory_size");
    SYM(serialize_size, "retro_serialize_size");
    SYM(serialize, "retro_serialize");
    SYM(unserialize, "retro_unserialize");
#undef SYM
    return 0;
}

static void mkdirs(const char *path)
{
    char p[700];
    snprintf(p, sizeof p, "%s", path);
    for (char *s = p + 1; *s; s++)
        if (*s == '/') {
            *s = 0;
            mkdir(p, 0755);
            *s = '/';
        }
    mkdir(p, 0755);
}

/* "Super Mario Bros. 3 (USA).nes" -> "Super Mario Bros. 3" */
static void title_from_path(const char *rom, char *out, size_t cap)
{
    const char *b = strrchr(rom, '/');
    char *dot, *paren;
    snprintf(out, cap, "%s", b ? b + 1 : rom);
    if ((dot = strrchr(out, '.')))
        *dot = 0;
    if ((paren = strstr(out, " (")))
        *paren = 0;
    for (char *c = out; *c; c++)
        if (*c == '_')
            *c = ' ';
}

int main(int argc, char **argv)
{
    struct retro_system_info info;
    struct retro_game_info game = {0};
    char core_path[700], base[512];
    const char *rom;
    void *rom_data = NULL;
    double fps, acc = 0;
    int vsync_lock, quit_code = 0;
    Uint32 last_tick, save_tick, stat_tick, last_tick_prev;
    int stat_frames = 0, stat_slow = 0;

    if (argc < 3) {
        fprintf(stderr, "usage: play <system> <rom>\n");
        return 2;
    }
    if (!(sys = play_sys_find(argv[1]))) {
        fprintf(stderr, "play: unknown system %s\n", argv[1]);
        return 2;
    }
    rom = argv[2];
    snprintf(lib, sizeof lib, "%s", getenv("PLAY_LIB") ? getenv("PLAY_LIB") : "/mnt/sdcard/library");
    if (getenv("PLAY_LOG"))
        cab_log_open(getenv("PLAY_LOG"));
    snprintf(sysdir, sizeof sysdir, "%s/system", lib);
    snprintf(savedir, sizeof savedir, "%s/saves/%s", lib, sys->id);
    mkdirs(sysdir);
    mkdirs(savedir);
    {
        const char *b = strrchr(rom, '/');
        char *dot;
        snprintf(base, sizeof base, "%s", b ? b + 1 : rom);
        if ((dot = strrchr(base, '.')))
            *dot = 0;
        snprintf(srm_path, sizeof srm_path, "%s/%s.srm", savedir, base);
        snprintf(state_path, sizeof state_path, "%s/%s.state", savedir, base);
    }
    title_from_path(rom, rom_title, sizeof rom_title);
    read_index(rom);

    if (getenv("PLAY_CORE"))
        snprintf(core_path, sizeof core_path, "%s", getenv("PLAY_CORE"));
    else if (getenv("PLAY_CORES_DIR")) {
        /* Tests on the PC: every core, the squashfs's too, from one directory of x86 builds. */
        const char *b = strrchr(sys->core, '/');
        snprintf(core_path, sizeof core_path, "%s/%s", getenv("PLAY_CORES_DIR"), b ? b + 1 : sys->core);
    }
    else if (sys->core[0] == '/')
        snprintf(core_path, sizeof core_path, "%s", sys->core);
    else
        snprintf(core_path, sizeof core_path, "%s/cores/%s", lib, sys->core);
    if (load_core(core_path) != 0)
        return 3;

    core.set_environment(environment);
    core.init();
    core.set_video_refresh(video_refresh);
    core.set_audio_sample(audio_sample);
    core.set_audio_sample_batch(audio_batch);
    core.set_input_poll(input_poll);
    core.set_input_state(input_state);
    core.get_system_info(&info);
    plog("%s %s (%s), %s", info.library_name, info.library_version, sys->id, rom);

    game.path = rom;
    if (!info.need_fullpath) {
        FILE *f = fopen(rom, "rb");
        long n;
        if (!f) {
            plog("cannot open %s", rom);
            return 4;
        }
        fseek(f, 0, SEEK_END);
        n = ftell(f);
        fseek(f, 0, SEEK_SET);
        rom_data = malloc(n > 0 ? n : 1);
        if (!rom_data || fread(rom_data, 1, n, f) != (size_t)n) {
            fclose(f);
            plog("cannot read %s", rom);
            return 4;
        }
        fclose(f);
        game.data = rom_data;
        game.size = n;
    }
    if (!core.load_game(&game)) {
        plog("the core refused %s", rom);
        core.deinit();
        return 5;
    }
    core.set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    core.get_system_av_info(&av);
    fps = av.timing.fps > 1 ? av.timing.fps : 60;
    src_ratio = av.timing.sample_rate > 1 ? av.timing.sample_rate / 44100.0 : 1.0;
    plog("%ux%u (max %ux%u) aspect %.3f, %.3f fps, %.0f Hz, rotation %d", av.geometry.base_width,
         av.geometry.base_height, av.geometry.max_width, av.geometry.max_height, av.geometry.aspect_ratio, fps,
         av.timing.sample_rate, rotation);
    srm_load();
    if (getenv("PLAY_ADVANCE"))
        advance_at = atoi(getenv("PLAY_ADVANCE"));

    if (getenv("PLAY_BENCH")) {
        /* Emulation speed alone, with nothing else drawn: can this core keep up on this CPU? Holds
         * Start now and then so a title screen gives way to play. */
        double secs = atof(getenv("PLAY_BENCH")), t0, t1, worst = 0;
        int n = 0;
        char line[128];
        FILE *st;
        long rss = 0;
        bench = 1;
        t0 = SDL_GetTicks() / 1000.0;
        do {
            Uint32 a = SDL_GetTicks();
            /* Every 3 s: a coin (arcade) and Start; between, the stick right and the lower button tapped. */
            {
                int k = n % 180;
                pad = 0;
                if (sys->coin_start && k < 6) pad |= 1u << RETRO_DEVICE_ID_JOYPAD_SELECT;
                else if (k >= 26 && k < 34) pad |= 1u << RETRO_DEVICE_ID_JOYPAD_START;
                else if (k > 30) pad |= (1u << RETRO_DEVICE_ID_JOYPAD_RIGHT) | (n % 16 < 8 ? 1u << sys->btn[0] : 0);
            }
            advance_down = advance_at >= 0 && n >= advance_at && n < advance_at + 10;
            core.run();
            n++;
            if (n > 60 && (SDL_GetTicks() - a) / 1000.0 > worst)
                worst = (SDL_GetTicks() - a) / 1000.0;
            t1 = SDL_GetTicks() / 1000.0;
        } while (t1 - t0 < secs);
        if ((st = fopen("/proc/self/status", "r"))) {
            while (fgets(line, sizeof line, st))
                if (!strncmp(line, "VmRSS:", 6))
                    rss = atol(line + 6);
            fclose(st);
        }
        printf("bench %s: %.1f frames/s (needs %.1f), worst frame %.1f ms, rss %ld MB, sound %.0f\n", sys->id,
               n / (t1 - t0), fps, worst * 1000, rss / 1024, bench_sound_level());
        /* (no srm_flush: a benchmark's mashing must not become anyone's save; MAME's own .hi/.nv are written
         * by the core as the game unloads) */
        core.unload_game();
        core.deinit();
        return 0;
    }

    if (play_gl_init(sys, rom_title, &av) != 0)
        return 6;
    /* A cushion of silence (about 46 ms) so the first slow frame does not starve the sound. */
    ring_w = 2048;
    cab_audio_open(audio_fill, NULL);
    state_resume(); /* (after the screen exists: the frame it runs first is drawn) */
    SDL_PauseAudio(0);

    vsync_lock = fabs(fps - 60.0) < 0.6 && !getenv("PLAY_CLOCK");
    last_tick = save_tick = stat_tick = last_tick_prev = SDL_GetTicks();
    while (cab_poll()) {
        Uint32 now = SDL_GetTicks();
        int runs = 1;
        read_deck();
        advance_down = advance_at >= 0 && frame_no >= advance_at && frame_no < advance_at + 10;
        if (!vsync_lock || cab_scripted() || SDL_GL_GetSwapInterval() != 1) {
            acc += (now - last_tick) / 1000.0;
            if (acc > 0.1)
                acc = 0.1;
            runs = (int)(acc * fps);
            if (cab_scripted())
                runs = 1;
            acc -= runs / fps;
            if (runs > 3)
                runs = 3;
        }
        last_tick = now;
        {
            Uint64 c0 = SDL_GetPerformanceCounter();
            for (int i = 0; i < runs; i++) {
                core.run();
                frame_no++;
            }
            t_core += (SDL_GetPerformanceCounter() - c0) / (double)SDL_GetPerformanceFrequency();
        }
        /* Rate control: hold the sound queue near 2048 frames (46 ms). The step is source samples per output
         * sample, so a low queue takes a smaller step (more output); at most half a percent either way. */
        {
            double fill = ring_fill() / 2048.0;
            drc = 1.0 + 0.005 * (fill - 1.0);
            if (drc < 0.995) drc = 0.995;
            if (drc > 1.005) drc = 1.005;
        }
        play_gl_draw(sys, rom_title, &av, rotation, cab_quit_progress());
        if (!vsync_lock && SDL_GL_GetSwapInterval() != 1 && !cab_scripted()) {
            Uint32 spent = SDL_GetTicks() - now;
            if (spent < 16)
                SDL_Delay(16 - spent);
        }
        /* Every 5 s: presents, slow ones, the sound queue. */
        stat_frames++;
        if (now - last_tick_prev > 22)
            stat_slow++;
        last_tick_prev = now;
        if (now - stat_tick >= 5000) {
            plog("%.1f fps, %d slow, sound queue %u, underruns %d, core frames %d; ms a frame: core %.1f (upload %.1f) "
                 "draw %.1f present %.1f",
                 stat_frames * 1000.0 / (now - stat_tick), stat_slow, ring_fill(), underruns, frame_no,
                 (t_core - play_t_upload) * 1000 / stat_frames, play_t_upload * 1000 / stat_frames,
                 play_t_draw * 1000 / stat_frames, play_t_present * 1000 / stat_frames);
            t_core = play_t_upload = play_t_draw = play_t_present = 0;
            stat_tick = now;
            stat_frames = stat_slow = 0;
        }
        if (now - save_tick > 5000) {
            srm_flush("timer");
            save_tick = now;
        }
    }
    SDL_PauseAudio(1);
    srm_flush("quit");
    state_suspend();
    plog("left after %d frames, %d audio underruns", frame_no, underruns);
    core.unload_game();
    core.deinit();
    free(rom_data);
    (void)conv;
    (void)conv32;
    (void)log_f;
    (void)last_frame;
    play_gl_shutdown();
    cab_shutdown();
    return quit_code;
}
