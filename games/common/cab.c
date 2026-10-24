#include "cab.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

#include "font8x8_basic.h"

#define QUIT_HOLD_MS 1000
#define QUIT_HOLD_FRAMES 60
#define AXIS_THRESHOLD 8192

SDL_Window *cab_window;
SDL_Renderer *cab_renderer;
int cab_w, cab_h;
void (*cab_event_hook)(const SDL_Event *e);

static Uint8 held[CAB_PLAYERS][CAB_NUM_BUTTONS], prev[CAB_PLAYERS][CAB_NUM_BUTTONS];
static Uint8 bot[CAB_NUM_BUTTONS], human[CAB_NUM_BUTTONS];
static float quit_progress;
static Uint8 axis_dir[CAB_PLAYERS][4], hat_dir[CAB_PLAYERS][4], key_dir[4];
static int joy_map[32];
static SDL_JoystickID joy_id[CAB_PLAYERS] = {-1, -1};
static SDL_Joystick *joy[CAB_PLAYERS];
static Uint32 combo_since, pace_next;
static int combo_frames, resume_script;
static SDL_Texture *font_tex;
static FILE *log_file;
static Uint32 log_synced;

static const char *names[CAB_NUM_BUTTONS] = {
    "UP", "DOWN", "LEFT", "RIGHT", "LOW", "TL", "C", "TR", "Y", "Z", "1P", "2P", "L2", "R2",
    "SELECT", "START", "MODE", "BL", "BR",
};

static SDL_Texture *scene;
static int rotate_fb;

#define SCRIPT_MAX 4096
enum { SC_DOWN, SC_UP, SC_SHOT, SC_QUIT };
struct sc_cmd {
    int frame, op, button;
    char path[192];
};
static struct sc_cmd sc_cmds[SCRIPT_MAX];
static int sc_n, sc_frame, sc_loaded;
static char sc_shot[192];
static char sc_title[64];

const char *cab_button_name(int b) { return b >= 0 && b < CAB_NUM_BUTTONS ? names[b] : "?"; }

void cab_map_joy_button(int sdl_button, int button)
{
    if (sdl_button >= 0 && sdl_button < 32)
        joy_map[sdl_button] = button;
}

void cab_load_mapping(const char *path)
{
    FILE *f = fopen(path, "r");
    char line[128], name[32];
    int n;
    if (!f)
        return;
    while (fgets(line, sizeof line, f))
        if (sscanf(line, "joy %d %31s", &n, name) == 2)
            for (int b = 0; b < CAB_NUM_BUTTONS; b++)
                if (!strcmp(name, names[b]))
                    cab_map_joy_button(n, b);
    fclose(f);
}

static void build_font(void)
{
    /* 128 glyphs in one 1024x8 texture, white on transparent; colour comes from SetTextureColorMod. */
    SDL_Surface *s = SDL_CreateRGBSurface(0, 128 * 8, 8, 32, 0xff000000, 0x00ff0000, 0x0000ff00, 0x000000ff);
    if (!s)
        return;
    for (int ch = 0; ch < 128; ch++)
        for (int y = 0; y < 8; y++)
            for (int x = 0; x < 8; x++) {
                Uint32 *px = (Uint32 *)((Uint8 *)s->pixels + y * s->pitch) + ch * 8 + x;
                *px = (font8x8_basic[ch][y] >> x) & 1 ? 0xffffffffu : 0;
            }
    font_tex = SDL_CreateTextureFromSurface(cab_renderer, s);
    SDL_SetTextureBlendMode(font_tex, SDL_BLENDMODE_BLEND);
    SDL_FreeSurface(s);
}

static void open_joysticks(void)
{
    for (int i = 0; i < SDL_NumJoysticks() && i < CAB_PLAYERS; i++)
        if (!joy[i] && (joy[i] = SDL_JoystickOpen(i)))
            joy_id[i] = SDL_JoystickInstanceID(joy[i]);
}

static void script_load(void);

int cab_rotate_on(void) { return rotate_fb; }

int cab_video_init(const char *title, int logical_w, int logical_h, int use_gl)
{
    Uint32 flags = SDL_WINDOW_FULLSCREEN_DESKTOP;
    int win_w = logical_w, win_h = logical_h;

    /* The menu calls init again when a game returns. SDL_Quit never delivers
     * the key-up, so this starts the deck from a clean state. */
    memset(held, 0, sizeof held);
    memset(prev, 0, sizeof prev);
    memset(key_dir, 0, sizeof key_dir);
    memset(axis_dir, 0, sizeof axis_dir);
    memset(hat_dir, 0, sizeof hat_dir);
    memset(bot, 0, sizeof bot);
    memset(human, 0, sizeof human);
    quit_progress = 0;
    combo_since = 0;
    combo_frames = 0;
    pace_next = 0;
    for (int i = 0; i < 32; i++)
        joy_map[i] = i + CAB_A < CAB_NUM_BUTTONS ? i + CAB_A : -1;
    /* The dummy driver cannot make a GL context. A menu started under dummy
     * still has to be able to launch a GL game, so switch before SDL_Init. */
    if (use_gl) {
        const char *drv = getenv("SDL_VIDEODRIVER");
        if (drv && !strcmp(drv, "dummy")) {
            setenv("SDL_VIDEODRIVER", "offscreen", 1);
            cab_log("GL: dummy video has no context, using offscreen");
        }
    }
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK | SDL_INIT_TIMER) != 0) {
        cab_log("SDL_Init: %s", SDL_GetError());
        return -1;
    }
    /* The cabinet mounts a 1024x768 framebuffer 90 degrees clockwise. Games draw upright
     * (the player's up). cab_present rotates that into the framebuffer. On the PC the
     * window is the upright view, unless CAB_RAW_FB=1, which shows the framebuffer itself. */
#ifdef CAB_CABINET
    rotate_fb = 1;
#else
    rotate_fb = getenv("CAB_RAW_FB") != NULL;
    if (!getenv("CAB_FULLSCREEN") && !rotate_fb) {
        int scale = 3;
        flags = SDL_WINDOW_RESIZABLE;
        if (getenv("CAB_SCALE"))
            scale = atoi(getenv("CAB_SCALE"));
        if (scale < 1)
            scale = 1;
        win_w *= scale;
        win_h *= scale;
    }
    if (rotate_fb) {
        flags = SDL_WINDOW_RESIZABLE;
        win_w = CAB_FB_W;
        win_h = CAB_FB_H;
    }
#endif
    if (use_gl) {
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
        flags |= SDL_WINDOW_OPENGL;
    }
    cab_window = SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, win_w, win_h, flags);
    if (!cab_window) {
        cab_log("SDL_CreateWindow: %s", SDL_GetError());
        return -1;
    }
    cab_w = logical_w;
    cab_h = logical_h;
    if (!use_gl) {
    cab_renderer = SDL_CreateRenderer(cab_window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!cab_renderer)
        cab_renderer = SDL_CreateRenderer(cab_window, -1, SDL_RENDERER_SOFTWARE);
    if (!cab_renderer) {
        cab_log("SDL_CreateRenderer: %s", SDL_GetError());
        return -1;
    }
    if (rotate_fb) {
        scene = SDL_CreateTexture(cab_renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET,
                                  logical_w, logical_h);
        if (!scene) {
            cab_log("SDL_CreateTexture: %s", SDL_GetError());
            return -1;
        }
        SDL_SetRenderTarget(cab_renderer, scene);
    } else {
        SDL_RenderSetLogicalSize(cab_renderer, logical_w, logical_h);
    }
    build_font();
    }
    SDL_ShowCursor(SDL_DISABLE);
    open_joysticks();
    snprintf(sc_title, sizeof sc_title, "%s", title ? title : "");
    script_load();
    return 0;
}

int cab_init(const char *title, int logical_w, int logical_h)
{
    return cab_video_init(title, logical_w, logical_h, 0);
}

void cab_shutdown(void)
{
    cab_gl_shutdown();
    SDL_CloseAudio();
    for (int i = 0; i < CAB_PLAYERS; i++)
        if (joy[i])
            SDL_JoystickClose(joy[i]);
    if (font_tex)
        SDL_DestroyTexture(font_tex);
    font_tex = NULL;
    if (scene)
        SDL_DestroyTexture(scene);
    scene = NULL;
    for (int i = 0; i < CAB_PLAYERS; i++)
        joy[i] = NULL;
    if (cab_renderer)
        SDL_DestroyRenderer(cab_renderer);
    if (cab_window)
        SDL_DestroyWindow(cab_window);
    cab_renderer = NULL;
    cab_window = NULL;
    SDL_Quit();
    if (log_file) {
        fflush(log_file);
        fsync(fileno(log_file));
        fclose(log_file);
        log_file = NULL;
    }
    sync();
}

static char *sc_trim(char *s)
{
    char *e;
    while (*s && isspace((unsigned char)*s))
        s++;
    if ((e = strchr(s, '#')))
        *e = 0;
    e = s + strlen(s);
    while (e > s && isspace((unsigned char)e[-1]))
        *--e = 0;
    return s;
}

static int sc_button(const char *s)
{
    for (int i = 0; i < CAB_NUM_BUTTONS; i++)
        if (!strcmp(names[i], s))
            return i;
    return -1;
}

/* Read once per process. A second cab_init (the yard relaunching itself) keeps the
 * frame counter, so the menu's script continues after the game it launched. */
static void script_load(void)
{
    const char *path = getenv("CAB_SCRIPT");
    FILE *f;
    char *text = NULL, *cursor;
    size_t len = 0, cap = 0;
    char line[320], section[64];
    int titled = 0, pass;
    if (sc_loaded) {
        /* The menu is back. The script may still be holding the button that
         * opened the game; that is not a new press. */
        resume_script = 1;
        return;
    }
    sc_loaded = 1;
    section[0] = 0;
    if (!path || !path[0])
        return;
    f = fopen(path, "r");
    if (!f) {
        cab_log("CAB_SCRIPT %s: %s", path, strerror(errno));
        return;
    }
    /* One read. A pipe cannot be rewound, so both passes walk this buffer. */
    for (;;) {
        char chunk[1024];
        size_t nread = fread(chunk, 1, sizeof chunk, f);
        char *grown;
        if (nread == 0)
            break;
        if (len + nread + 1 > cap) {
            cap = cap ? cap * 2 : 4096;
            while (cap < len + nread + 1)
                cap *= 2;
            grown = realloc(text, cap);
            if (!grown) {
                free(text);
                fclose(f);
                return;
            }
            text = grown;
        }
        memcpy(text + len, chunk, nread);
        len += nread;
    }
    fclose(f);
    if (!text)
        return;
    text[len] = 0;
    for (pass = 0; pass < 2; pass++) {
        section[0] = 0;
        for (cursor = text; *cursor; ) {
            char *nl = strchr(cursor, '\n');
            size_t n = nl ? (size_t)(nl - cursor) : strlen(cursor);
            char *s;
            int frame, got;
            char op[32], arg[192];
            if (n >= sizeof line)
                n = sizeof line - 1;
            memcpy(line, cursor, n);
            line[n] = 0;
            cursor = nl ? nl + 1 : cursor + n;
            s = sc_trim(line);
            if (!s[0])
                continue;
            if (!strncmp(s, "title=", 6)) {
                if (pass == 0)
                    titled = 1;
                snprintf(section, sizeof section, "%s", s + 6);
                sc_trim(section);
                continue;
            }
            if (pass == 0)
                continue;
            if (titled && strcmp(section, sc_title) && strcmp(section, "*"))
                continue;
            arg[0] = 0;
            got = sscanf(s, "%d %31s %191s", &frame, op, arg);
            if (got < 2)
                continue;
            if (sc_n >= SCRIPT_MAX) {
                cab_log("script truncated at %d commands", SCRIPT_MAX);
                break;
            }
            sc_cmds[sc_n].frame = frame;
            sc_cmds[sc_n].path[0] = 0;
            if (!strcmp(op, "down") || !strcmp(op, "up")) {
                int b = sc_button(arg);
                if (got < 3 || b < 0)
                    continue;
                sc_cmds[sc_n].op = op[0] == 'd' ? SC_DOWN : SC_UP;
                sc_cmds[sc_n].button = b;
            } else if (!strcmp(op, "shot")) {
                if (got < 3)
                    continue;
                sc_cmds[sc_n].op = SC_SHOT;
                snprintf(sc_cmds[sc_n].path, sizeof sc_cmds[sc_n].path, "%s", arg);
            } else if (!strcmp(op, "quit")) {
                sc_cmds[sc_n].op = SC_QUIT;
            } else {
                continue;
            }
            sc_n++;
        }
    }
    free(text);
    if (getenv("CAB_SCRIPT_LOG"))
        cab_log("script %s: %d commands from %s", sc_title, sc_n, path);
}

static void script_apply(int *quit)
{
    int latest[CAB_NUM_BUTTONS];
    const char *maxs = getenv("CAB_MAX_FRAMES");
    for (int b = 0; b < CAB_NUM_BUTTONS; b++)
        latest[b] = -1;
    for (int i = 0; i < sc_n; i++) {
        if (sc_cmds[i].frame > sc_frame)
            continue;
        if (sc_cmds[i].op == SC_DOWN || sc_cmds[i].op == SC_UP) {
            int b = sc_cmds[i].button;
            /* Latest frame wins. The same frame uses the later line. */
            if (latest[b] < 0 || sc_cmds[i].frame >= sc_cmds[latest[b]].frame)
                latest[b] = i;
        } else if (sc_cmds[i].frame == sc_frame && sc_cmds[i].op == SC_SHOT) {
            snprintf(sc_shot, sizeof sc_shot, "%s", sc_cmds[i].path);
        } else if (sc_cmds[i].frame == sc_frame && sc_cmds[i].op == SC_QUIT) {
            *quit = 1;
        }
    }
    for (int b = 0; b < CAB_NUM_BUTTONS; b++)
        if (latest[b] >= 0)
            held[0][b] = sc_cmds[latest[b]].op == SC_DOWN;
    if (maxs && maxs[0] && sc_frame + 1 >= atoi(maxs))
        *quit = 1;
    sc_frame++;
}

static int player_of(SDL_JoystickID id)
{
    for (int i = 0; i < CAB_PLAYERS; i++)
        if (joy_id[i] == id)
            return i;
    return -1;
}

static int key_button(SDL_Scancode sc)
{
    switch (sc) {
    case SDL_SCANCODE_UP: return CAB_UP;
    case SDL_SCANCODE_DOWN: return CAB_DOWN;
    case SDL_SCANCODE_LEFT: return CAB_LEFT;
    case SDL_SCANCODE_RIGHT: return CAB_RIGHT;
    case SDL_SCANCODE_Z: return CAB_LOW; /* lower button, right of the stick */
    case SDL_SCANCODE_X: return CAB_TL;  /* top-left of that pair */
    case SDL_SCANCODE_C: return CAB_TR;  /* top-right of that pair */
    case SDL_SCANCODE_1: return CAB_1P;
    case SDL_SCANCODE_2: return CAB_2P;
    case SDL_SCANCODE_BACKSPACE: case SDL_SCANCODE_RSHIFT: return CAB_SELECT;
    case SDL_SCANCODE_RETURN: return CAB_START;
    case SDL_SCANCODE_TAB: return CAB_MODE;
    default: return -1;
    }
}

int cab_poll(void)
{
    SDL_Event e;
    int quit = 0;

    memcpy(prev, held, sizeof held);
    /* held[0] carried last frame's bot buttons. Events and the script work on
     * the deck's own state; the bot is laid on top again below. */
    memcpy(held[0], human, sizeof human);
    while (SDL_PollEvent(&e)) {
        int p, b;
        if (cab_event_hook)
            cab_event_hook(&e);
        switch (e.type) {
        case SDL_QUIT:
            quit = 1;
            break;
        case SDL_KEYDOWN:
        case SDL_KEYUP:
            if (e.key.keysym.scancode == SDL_SCANCODE_ESCAPE)
                quit = 1;
            b = key_button(e.key.keysym.scancode);
            if (b >= 0 && b <= CAB_RIGHT)
                key_dir[b] = e.type == SDL_KEYDOWN;
            else if (b >= 0)
                held[0][b] = e.type == SDL_KEYDOWN;
            break;
        case SDL_JOYDEVICEADDED:
            open_joysticks();
            break;
        case SDL_JOYBUTTONDOWN:
        case SDL_JOYBUTTONUP:
            p = player_of(e.jbutton.which);
            if (p >= 0 && e.jbutton.button < 32 && (b = joy_map[e.jbutton.button]) >= 0)
                held[p][b] = e.jbutton.state == SDL_PRESSED;
            break;
        case SDL_JOYAXISMOTION:
            p = player_of(e.jaxis.which);
            if (p >= 0 && e.jaxis.axis < 2) {
                int lo = e.jaxis.axis ? CAB_UP : CAB_LEFT, hi = e.jaxis.axis ? CAB_DOWN : CAB_RIGHT;
                axis_dir[p][lo] = e.jaxis.value < -AXIS_THRESHOLD;
                axis_dir[p][hi] = e.jaxis.value > AXIS_THRESHOLD;
            }
            break;
        case SDL_JOYHATMOTION:
            p = player_of(e.jhat.which);
            if (p >= 0 && e.jhat.hat == 0) {
                hat_dir[p][CAB_UP] = !!(e.jhat.value & SDL_HAT_UP);
                hat_dir[p][CAB_DOWN] = !!(e.jhat.value & SDL_HAT_DOWN);
                hat_dir[p][CAB_LEFT] = !!(e.jhat.value & SDL_HAT_LEFT);
                hat_dir[p][CAB_RIGHT] = !!(e.jhat.value & SDL_HAT_RIGHT);
            }
            break;
        }
    }
    for (int p = 0; p < CAB_PLAYERS; p++)
        for (int d = CAB_UP; d <= CAB_RIGHT; d++)
            held[p][d] = axis_dir[p][d] || hat_dir[p][d] || (p == 0 && key_dir[d]);

    /* Scripted holds land before the quit combo, so 1P+2P counts on the frame
     * the script presses it. A script runs faster than the panel, so the hold
     * is 60 frames (one second at 60 Hz) instead of one second of wall clock. */
    script_apply(&quit);
    memcpy(human, held[0], sizeof human);
    for (int b = 0; b < CAB_NUM_BUTTONS; b++)
        if (bot[b])
            held[0][b] = 1;
    quit_progress = 0;
    if ((human[CAB_SELECT] && human[CAB_START]) || (human[CAB_1P] && human[CAB_2P])) {
        if (getenv("CAB_SCRIPT")) {
            if (++combo_frames >= QUIT_HOLD_FRAMES)
                quit = 1;
            quit_progress = (float)combo_frames / QUIT_HOLD_FRAMES;
        } else if (!combo_since)
            combo_since = SDL_GetTicks() | 1;
        else {
            Uint32 dt = SDL_GetTicks() - combo_since;
            if (dt >= QUIT_HOLD_MS)
                quit = 1;
            quit_progress = (float)dt / QUIT_HOLD_MS;
        }
    } else {
        combo_since = 0;
        combo_frames = 0;
    }
    if (log_file && SDL_GetTicks() - log_synced > 1000) {
        fflush(log_file);
        fsync(fileno(log_file));
        log_synced = SDL_GetTicks();
    }
    if (resume_script) {
        memcpy(prev, held, sizeof prev);
        resume_script = 0;
    }
    /* CAB_PACE=1 waits out a 60 Hz frame. The dummy driver reports vsync and
     * then returns immediately, which skips beeps and the wall-clock quit. */
    if (getenv("CAB_PACE")) {
        Uint32 now = SDL_GetTicks();
        if (!pace_next)
            pace_next = now;
        pace_next += 16;
        if ((Sint32)(pace_next - now) > 0)
            SDL_Delay(pace_next - now);
        else
            pace_next = now;
    }
    return !quit;
}

int cab_down(int player, int button) { return held[player][button]; }
float cab_quit_progress(void) { return quit_progress > 1 ? 1 : quit_progress; }
void cab_bot(int button, int down)
{
    if (button >= 0 && button < CAB_NUM_BUTTONS)
        bot[button] = down ? 1 : 0;
}
void cab_bot_clear(void) { memset(bot, 0, sizeof bot); }
int cab_human_any(void)
{
    for (int b = 0; b < CAB_NUM_BUTTONS; b++)
        if (human[b])
            return 1;
    return 0;
}
int cab_scripted(void) { return sc_n > 0 || (getenv("CAB_SCRIPT") && getenv("CAB_SCRIPT")[0]); }
int cab_pressed(int player, int button) { return held[player][button] && !prev[player][button]; }

static void (*audio_fill)(void *, Sint16 *, int);

static void audio_cb(void *ud, Uint8 *stream, int len)
{
    audio_fill(ud, (Sint16 *)stream, len / 4);
}

int cab_audio_open(void (*fill)(void *ud, Sint16 *out, int frames), void *ud)
{
    SDL_AudioSpec want;
    SDL_zero(want);
    want.freq = 44100;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = audio_cb;
    want.userdata = ud;
    audio_fill = fill;
    if (SDL_OpenAudio(&want, NULL) != 0) {
        cab_log("SDL_OpenAudio: %s", SDL_GetError());
        return -1;
    }
    SDL_PauseAudio(0);
    return 0;
}

void cab_text(int x, int y, int scale, SDL_Color c, const char *fmt, ...)
{
    char buf[256];
    va_list ap;
    if (!font_tex)
        return;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    SDL_SetTextureColorMod(font_tex, c.r, c.g, c.b);
    SDL_SetTextureAlphaMod(font_tex, c.a);
    for (const unsigned char *s = (const unsigned char *)buf; *s; s++, x += 8 * scale) {
        SDL_Rect src = {(*s & 0x7f) * 8, 0, 8, 8}, dst = {x, y, 8 * scale, 8 * scale};
        SDL_RenderCopy(cab_renderer, font_tex, &src, &dst);
    }
}

int cab_screenshot(const char *path)
{
    int w, h, rc;
    if (cab_gl_active())
        return cab_gl_screenshot(path);
    SDL_Surface *s;
    SDL_GetRendererOutputSize(cab_renderer, &w, &h);
    s = SDL_CreateRGBSurface(0, w, h, 32, 0x00ff0000, 0x0000ff00, 0x000000ff, 0);
    if (!s)
        return -1;
    rc = SDL_RenderReadPixels(cab_renderer, NULL, SDL_PIXELFORMAT_ARGB8888, s->pixels, s->pitch);
    if (rc == 0)
        rc = SDL_SaveBMP(s, path);
    SDL_FreeSurface(s);
    return rc;
}

void cab_shot_if_due(void)
{
    static int frame;
    const char *shot = getenv("CAB_SCREENSHOT");
    const char *at = getenv("CAB_SCREENSHOT_FRAME");
    const char *dir = getenv("CAB_SHOTDIR");
    if (sc_shot[0]) {
        cab_screenshot(sc_shot);
        sc_shot[0] = 0;
    }
    if (shot && ++frame == (at ? atoi(at) : 10))
        cab_screenshot(shot);
    else if (!shot)
        frame++;
    if (dir && dir[0]) {
        int every = 30;
        const char *ev = getenv("CAB_SHOT_EVERY");
        char path[512];
        if (ev && atoi(ev) > 0)
            every = atoi(ev);
        if (frame % every == 0) {
            snprintf(path, sizeof path, "%s/frame-%04d.bmp", dir, frame);
            cab_screenshot(path);
        }
    }
}

void cab_present(void)
{
    if (scene) {
        int ow = 0, oh = 0, uw, uh, dw, dh;
        double s;
        SDL_Rect dst;
        SDL_SetRenderTarget(cab_renderer, NULL);
        SDL_GetRendererOutputSize(cab_renderer, &ow, &oh);
        if (ow < 16 || oh < 16) {
            ow = CAB_FB_W;
            oh = CAB_FB_H;
        }
        /* Landscape framebuffer: the upright panel is the two axes swapped. */
        uw = oh < ow ? oh : ow;
        uh = oh < ow ? ow : oh;
        s = (double)uw / cab_w;
        if ((double)uh / cab_h < s)
            s = (double)uh / cab_h;
        dw = (int)(cab_w * s);
        dh = (int)(cab_h * s);
        dst.x = (ow - dw) / 2;
        dst.y = (oh - dh) / 2;
        dst.w = dw;
        dst.h = dh;
        SDL_SetRenderDrawColor(cab_renderer, 0, 0, 0, 255);
        SDL_RenderClear(cab_renderer);
        /* -90 degrees puts the top of the upright image on the left of the framebuffer,
         * which the panel's clockwise mount shows at the top. */
        SDL_RenderCopyEx(cab_renderer, scene, NULL, &dst, -90, NULL, SDL_FLIP_NONE);
        cab_shot_if_due();
        SDL_RenderPresent(cab_renderer);
        SDL_SetRenderTarget(cab_renderer, scene);
        return;
    }
    cab_shot_if_due();
    SDL_RenderPresent(cab_renderer);
}

void cab_log_open(const char *path)
{
    log_file = fopen(path, "a");
}

/* ext2 has no journal. The file fsync makes the bytes durable; the directory
 * fsync makes the rename survive a power cut. */
static void fsync_parent(const char *file)
{
    char dir[512];
    char *slash;
    int fd;
    size_t n = strlen(file);
    if (n >= sizeof dir)
        return;
    memcpy(dir, file, n + 1);
    slash = strrchr(dir, '/');
    if (!slash)
        memcpy(dir, ".", 2);
    else if (slash == dir)
        slash[1] = 0;
    else
        *slash = 0;
    fd = open(dir, O_RDONLY | O_DIRECTORY);
    if (fd < 0)
        return;
    fsync(fd);
    close(fd);
}

static int score_path(char *out, size_t n, const char *name)
{
    static const char *stock[] = {
        "PacMan", "PacManFast", "PacManPlus", "PacManPlusFast", "SuperPacMan", "PacandPal",
        "PacLand", "DigDug", "DigDugII", "Galaga", "Galaxian", "Mappy", "PacMania", "Rompers",
        "NS1", "NS86", "probe", NULL
    };
    size_t len;
    if (!name || !(len = strlen(name)) || len > 32)
        return 0;
    for (size_t i = 0; i < len; i++) {
        char c = name[i];
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-'))
            return 0;
    }
    for (int i = 0; stock[i]; i++)
        if (!strcmp(name, stock[i])) {
            cab_log("refusing to use the stock save name %s", name);
            return 0;
        }
    snprintf(out, n, "%s.sav", name);
    return 1;
}

int cab_score_load(const char *name)
{
    char path[64];
    int v = 0;
    FILE *f;
    if (!score_path(path, sizeof path, name))
        return 0;
    f = fopen(path, "r");
    if (!f)
        return 0;
    /* A value that does not fit in a signed int comes back negative or huge.
     * Either one would freeze the record, so it loads as a missing file. */
    if (fscanf(f, "best %d", &v) != 1 || v < 0 || v > 1000000)
        v = 0;
    fclose(f);
    return v;
}

int cab_score_save(const char *name, int score)
{
    char path[64], tmp[80];
    FILE *f;
    if (score < 0 || !score_path(path, sizeof path, name))
        return -1;
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    f = fopen(tmp, "w");
    if (!f)
        return -1;
    fprintf(f, "best %d\n", score);
    if (fflush(f) != 0 || fsync(fileno(f)) != 0) {
        fclose(f);
        unlink(tmp);
        return -1;
    }
    if (fclose(f) != 0) {
        unlink(tmp);
        return -1;
    }
    if (rename(tmp, path) != 0)
        return -1;
    fsync_parent(path);
    return 0;
}

static int ext_name_ok(const char *name)
{
    static const char *stock[] = {
        "PacMan", "PacManFast", "PacManPlus", "PacManPlusFast", "SuperPacMan", "PacandPal",
        "PacLand", "DigDug", "DigDugII", "Galaga", "Galaxian", "Mappy", "PacMania", "Rompers",
        "NS1", "NS86", "probe", NULL
    };
    size_t len;
    if (!name || !(len = strlen(name)) || len > 32)
        return 0;
    for (size_t i = 0; i < len; i++) {
        char c = name[i];
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-'))
            return 0;
    }
    for (int i = 0; stock[i]; i++)
        if (!strcmp(name, stock[i]))
            return 0;
    return 1;
}

static int ext_is_mount(const char *path)
{
    struct stat here, parent;
    char buf[256], *slash;
    if (stat(path, &here) != 0 || !S_ISDIR(here.st_mode))
        return 0;
    snprintf(buf, sizeof buf, "%s", path);
    slash = strrchr(buf, '/');
    if (!slash || slash == buf)
        return 0;
    *slash = 0;
    if (stat(buf, &parent) != 0)
        return 0;
    return here.st_dev != parent.st_dev;
}

#ifdef CAB_CABINET
static void ext_try_mount(void)
{
    static int tried;
    const char *devs[] = {"/dev/mmcblk0p1", "/dev/mmcblk0", "/dev/sda1", NULL};
    if (tried || ext_is_mount("/mnt/sdcard") || ext_is_mount("/tmp/stick"))
        return;
    tried = 1;
    mkdir("/tmp/stick", 0755);
    for (int i = 0; devs[i]; i++) {
        if (access(devs[i], F_OK) != 0)
            continue;
        if (mount(devs[i], "/tmp/stick", "vfat", MS_NOATIME, NULL) == 0 ||
            mount(devs[i], "/tmp/stick", "ext2", MS_NOATIME, NULL) == 0 ||
            mount(devs[i], "/tmp/stick", "exfat", MS_NOATIME, NULL) == 0) {
            cab_log("mounted %s on /tmp/stick", devs[i]);
            return;
        }
    }
}
#endif

const char *cab_ext_root(void)
{
    static int once;
    const char *env = getenv("CAB_EXT");
    struct stat st;
    if (!once) {
#ifdef CAB_CABINET
        ext_try_mount();
#endif
        once = 1;
    }
    /* CAB_EXT is the simulator's card: a plain directory, not a mount. */
    if (env && env[0] && stat(env, &st) == 0 && S_ISDIR(st.st_mode))
        return env;
    if (ext_is_mount("/mnt/sdcard"))
        return "/mnt/sdcard";
    if (ext_is_mount("/tmp/stick"))
        return "/tmp/stick";
    return NULL;
}

static int ext_path(char *out, size_t n, const char *name)
{
    const char *root = cab_ext_root();
    if (!root || !ext_name_ok(name))
        return 0;
    size_t rl = strlen(root), nl = strlen(name);
    if (rl + 1 + nl + 1 > n)
        return 0;
    memcpy(out, root, rl);
    out[rl] = '/';
    memcpy(out + rl + 1, name, nl + 1);
    return 1;
}

int cab_ext_read(const char *name, char *buf, int cap)
{
    char path[512];
    FILE *f;
    int n;
    if (!buf || cap < 2 || !ext_path(path, sizeof path, name))
        return -1;
    f = fopen(path, "r");
    if (!f)
        return -1;
    n = (int)fread(buf, 1, (size_t)cap - 1, f);
    fclose(f);
    buf[n] = 0;
    return n;
}

int cab_ext_write(const char *name, const void *data, int len)
{
    char path[512], tmp[540];
    FILE *f;
    if (len < 0 || !data || !ext_path(path, sizeof path, name))
        return -1;
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    f = fopen(tmp, "w");
    if (!f)
        return -1;
    if (fwrite(data, 1, (size_t)len, f) != (size_t)len || fflush(f) != 0 || fsync(fileno(f)) != 0) {
        fclose(f);
        unlink(tmp);
        return -1;
    }
    if (fclose(f) != 0) {
        unlink(tmp);
        return -1;
    }
    if (rename(tmp, path) != 0)
        return -1;
    fsync_parent(path);
    return 0;
}

int cab_fast(int argc, char **argv)
{
    for (int i = 1; i < argc; i++)
        if (argv[i] && !strcmp(argv[i], "-fast"))
            return 1;
    return 0;
}

void cab_log(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    if (log_file) {
        fprintf(log_file, "%8u ", SDL_GetTicks());
        va_start(ap, fmt);
        vfprintf(log_file, fmt, ap);
        va_end(ap);
        fputc('\n', log_file);
    }
}
