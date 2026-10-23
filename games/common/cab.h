/* Partycade platform layer: one API for the PC and the cabinet.
 *
 * Cabinet facts this follows (GAMEDEV.md): SDL 2.0.7 on KMSDRM + opengles2, ALSA at 44.1 kHz,
 * controls arrive as SDL joystick events (and possibly keyboard events), the stock menu waits
 * until the game exits.
 */
#ifndef CAB_H
#define CAB_H

#include <SDL2/SDL.h>

enum cab_button {
    CAB_UP, CAB_DOWN, CAB_LEFT, CAB_RIGHT,
    /* Same order as the uart-keys codes BTN_A 0x130 .. BTN_THUMBR 0x13e. */
    CAB_A, CAB_B, CAB_C, CAB_X, CAB_Y, CAB_Z, CAB_L, CAB_R, CAB_L2, CAB_R2,
    CAB_SELECT, CAB_START, CAB_MODE, CAB_BL, CAB_BR,
    CAB_NUM_BUTTONS
};

#define CAB_PLAYERS 2

extern SDL_Window *cab_window;
extern SDL_Renderer *cab_renderer;
extern int cab_w, cab_h;                 /* logical size the game draws in */
extern void (*cab_event_hook)(const SDL_Event *e);

int cab_init(const char *title, int logical_w, int logical_h);
void cab_shutdown(void);

/* Call once per frame. Returns 0 when the game should exit (quit combo, Escape, window close). */
int cab_poll(void);
int cab_down(int player, int button);    /* held now */
int cab_pressed(int player, int button); /* went down this frame */
const char *cab_button_name(int button);

/* Map SDL joystick button N to a cab_button; default is N -> CAB_A + N. */
void cab_map_joy_button(int sdl_button, int button);
/* Optional file of lines "joy <sdl_button> <NAME>", e.g. "joy 3 START". Missing file is fine. */
void cab_load_mapping(const char *path);

/* Audio: callback fills `frames` stereo S16 frames at 44100 Hz. Runs on the audio thread. */
int cab_audio_open(void (*fill)(void *ud, Sint16 *out, int frames), void *ud);

/* 8x8 bitmap text in logical pixels. */
void cab_text(int x, int y, int scale, SDL_Color c, const char *fmt, ...);

/* Save the current frame (call before cab_present/SDL_RenderPresent) as a BMP. For headless checks:
 * every game saves one when CAB_SCREENSHOT=<path> is set, at frame CAB_SCREENSHOT_FRAME (default 10). */
int cab_screenshot(const char *path);
void cab_present(void);

/* Append a line to the log file (and stderr). The file is fsync'd at most once a second and on exit,
 * so quit with the combo before powering off. */
void cab_log_open(const char *path);
void cab_log(const char *fmt, ...);

#endif
