#include "cab.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "font8x8_basic.h"

#define QUIT_HOLD_MS 1000
#define AXIS_THRESHOLD 8192

SDL_Window *cab_window;
SDL_Renderer *cab_renderer;
int cab_w, cab_h;
void (*cab_event_hook)(const SDL_Event *e);

static Uint8 held[CAB_PLAYERS][CAB_NUM_BUTTONS], prev[CAB_PLAYERS][CAB_NUM_BUTTONS];
static Uint8 axis_dir[CAB_PLAYERS][4], hat_dir[CAB_PLAYERS][4], key_dir[4];
static int joy_map[32];
static SDL_JoystickID joy_id[CAB_PLAYERS] = {-1, -1};
static SDL_Joystick *joy[CAB_PLAYERS];
static Uint32 combo_since;
static SDL_Texture *font_tex;
static FILE *log_file;
static Uint32 log_synced;

static const char *names[CAB_NUM_BUTTONS] = {
    "UP", "DOWN", "LEFT", "RIGHT", "A", "B", "C", "X", "Y", "Z", "L", "R", "L2", "R2",
    "SELECT", "START", "MODE", "BL", "BR",
};

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

int cab_init(const char *title, int logical_w, int logical_h)
{
    Uint32 flags = SDL_WINDOW_FULLSCREEN_DESKTOP;
    int win_w = logical_w, win_h = logical_h;

    for (int i = 0; i < 32; i++)
        joy_map[i] = i + CAB_A < CAB_NUM_BUTTONS ? i + CAB_A : -1;
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK | SDL_INIT_TIMER) != 0) {
        cab_log("SDL_Init: %s", SDL_GetError());
        return -1;
    }
#ifndef CAB_CABINET
    if (!getenv("CAB_FULLSCREEN")) {
        flags = SDL_WINDOW_RESIZABLE;
        win_w *= 3;
        win_h *= 3;
    }
#endif
    cab_window = SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, win_w, win_h, flags);
    if (!cab_window) {
        cab_log("SDL_CreateWindow: %s", SDL_GetError());
        return -1;
    }
    cab_renderer = SDL_CreateRenderer(cab_window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!cab_renderer)
        cab_renderer = SDL_CreateRenderer(cab_window, -1, SDL_RENDERER_SOFTWARE);
    if (!cab_renderer) {
        cab_log("SDL_CreateRenderer: %s", SDL_GetError());
        return -1;
    }
    SDL_RenderSetLogicalSize(cab_renderer, logical_w, logical_h);
    SDL_ShowCursor(SDL_DISABLE);
    cab_w = logical_w;
    cab_h = logical_h;
    build_font();
    open_joysticks();
    return 0;
}

void cab_shutdown(void)
{
    SDL_CloseAudio();
    for (int i = 0; i < CAB_PLAYERS; i++)
        if (joy[i])
            SDL_JoystickClose(joy[i]);
    if (font_tex)
        SDL_DestroyTexture(font_tex);
    if (cab_renderer)
        SDL_DestroyRenderer(cab_renderer);
    if (cab_window)
        SDL_DestroyWindow(cab_window);
    SDL_Quit();
    if (log_file) {
        fflush(log_file);
        fsync(fileno(log_file));
        fclose(log_file);
        log_file = NULL;
    }
    sync();
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
    case SDL_SCANCODE_Z: return CAB_A;
    case SDL_SCANCODE_X: return CAB_B;
    case SDL_SCANCODE_C: return CAB_C;
    case SDL_SCANCODE_A: return CAB_X;
    case SDL_SCANCODE_S: return CAB_Y;
    case SDL_SCANCODE_D: return CAB_Z;
    case SDL_SCANCODE_Q: return CAB_L;
    case SDL_SCANCODE_W: return CAB_R;
    case SDL_SCANCODE_1: return CAB_L2;
    case SDL_SCANCODE_2: return CAB_R2;
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

    if (held[0][CAB_SELECT] && held[0][CAB_START]) {
        if (!combo_since)
            combo_since = SDL_GetTicks() | 1;
        else if (SDL_GetTicks() - combo_since >= QUIT_HOLD_MS)
            quit = 1;
    } else {
        combo_since = 0;
    }
    if (log_file && SDL_GetTicks() - log_synced > 1000) {
        fflush(log_file);
        fsync(fileno(log_file));
        log_synced = SDL_GetTicks();
    }
    return !quit;
}

int cab_down(int player, int button) { return held[player][button]; }
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

void cab_present(void)
{
    static int frame;
    const char *shot = getenv("CAB_SCREENSHOT");
    const char *at = getenv("CAB_SCREENSHOT_FRAME");
    if (shot && ++frame == (at ? atoi(at) : 10))
        cab_screenshot(shot);
    SDL_RenderPresent(cab_renderer);
}

void cab_log_open(const char *path)
{
    log_file = fopen(path, "a");
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
