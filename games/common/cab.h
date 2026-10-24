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
    /* Same slots as the uart-keys codes BTN_A 0x130 .. BTN_THUMBR 0x13e.
     * On this deck the wired ones are the panel buttons, not a gamepad:
     *   CAB_A lower button right of the stick, CAB_B top-left, CAB_X top-right,
     *   CAB_L 1-player, CAB_R 2-player.
     * The rest of the slots are advertised by the driver and not wired. */
    CAB_A, CAB_B, CAB_C, CAB_X, CAB_Y, CAB_Z, CAB_L, CAB_R, CAB_L2, CAB_R2,
    CAB_SELECT, CAB_START, CAB_MODE, CAB_BL, CAB_BR,
    CAB_NUM_BUTTONS
};

/* Names to use in games. Same values as the slots above. */
#define CAB_LOW CAB_A
#define CAB_TL  CAB_B
#define CAB_TR  CAB_X
#define CAB_1P  CAB_L
#define CAB_2P  CAB_R

/* Upright panel, after the framebuffer's 90-degree clockwise mount. */
#define CAB_PANEL_W 768
#define CAB_PANEL_H 1024
/* What KMSDRM actually modesets. */
#define CAB_FB_W 1024
#define CAB_FB_H 768

#define CAB_PLAYERS 2

extern SDL_Window *cab_window;
extern SDL_Renderer *cab_renderer;
extern int cab_w, cab_h;                 /* logical size the game draws in */
extern void (*cab_event_hook)(const SDL_Event *e);

int cab_init(const char *title, int logical_w, int logical_h);
/* Same window and input as cab_init, then an OpenGL ES 2 context and an upright
 * framebuffer the game draws into. cab_gl_bind selects that framebuffer.
 * cab_gl_present copies it onto the panel (rotated on the cabinet) and swaps.
 * Present also rebinds the blit program and the array buffer, and turns the
 * depth test off. A game sets its own program, buffers, and depth each frame. */
int cab_gl_init(const char *title, int logical_w, int logical_h);
void cab_gl_bind(void);
void cab_gl_present(void);
int cab_gl_active(void);
int cab_gl_screenshot(const char *path);
void cab_gl_shutdown(void);
void *cab_gl_proc(const char *name);
void cab_shutdown(void);

/* Shared by the renderer path and the GL path. */
int cab_video_init(const char *title, int logical_w, int logical_h, int use_gl);
int cab_rotate_on(void);
void cab_shot_if_due(void);

/* Call once per frame. Returns 0 when the game should exit (quit combo, Escape, window close). */
int cab_poll(void);
int cab_down(int player, int button);    /* held now */
/* How far the 1P+2P quit hold has come, 0..1. gfx_present draws a meter from it. */
float cab_quit_progress(void);
/* A game's own autopilot (attract mode, CAB_AUTOPLAY): these buttons are held on
 * player 0 from the next cab_poll on, through the same path as the deck. */
void cab_bot(int button, int down);
void cab_bot_clear(void);
/* Something other than the bot is holding a button or direction this frame. */
int cab_human_any(void);
/* A script is driving the deck (CAB_SCRIPT). Games skip wall-clock pacing then. */
int cab_scripted(void);
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

/* Save the current frame as a BMP. For headless checks:
 * CAB_SCREENSHOT=<path> saves one frame, at present CAB_SCREENSHOT_FRAME (default 10).
 * CAB_SCRIPT=<file> plays the deck on player 0. Lines are "title=<window title>",
 * "<frame> down NAME", "<frame> up NAME", "<frame> shot <path>", "<frame> quit".
 * NAME is UP, DOWN, LEFT, RIGHT, LOW, TL, TR, 1P, 2P, and the rest of cab_button_name.
 * A title= line applies until the next one; "*" matches every game. A file with no
 * title= line applies to whatever is running. Holds latch until up. If several
 * lines name one button, the latest frame wins and the same frame uses the later
 * line. quit ends on that frame, before the game draws it, so shot the previous
 * frame. While a script is loaded, holding 1P+2P or select+start for 60 frames
 * quits (one second at 60 Hz). Without a script the hold is one second of wall
 * clock. CAB_MAX_FRAMES=N ends the game even if the script never quits.
 * CAB_SHOTDIR=<dir> writes frame-NNNN.bmp every CAB_SHOT_EVERY presents (default 30).
 * CAB_PACE=1 waits out each frame to 60 Hz. The dummy driver claims vsync and
 * returns at once, so pacing is what makes a beep and the wall-clock quit land. */
int cab_screenshot(const char *path);
void cab_present(void);

/* Append a line to the log file (and stderr). The file is fsync'd at most once a second and on exit,
 * so quit with the combo before powering off. */
void cab_log_open(const char *path);
void cab_log(const char *fmt, ...);

/* One integer high score in "<name>.sav" in the current directory (the cabinet's /data/Games).
 * The file is the text line "best <n>". Refuses the stock emulators' names so a game cannot
 * overwrite Pac-Man and the rest. Missing file loads as 0. */
int cab_score_load(const char *name);
int cab_score_save(const char *name, int score);

/* start.sh passes "-fast" when the menu speed for this tile is on. */
int cab_fast(int argc, char **argv);

/* External storage: a microSD card or USB stick on the cabinet, or CAB_EXT (a
 * directory) in the simulator. NULL when nothing is there. Names are one file
 * component, [A-Za-z0-9_-], 1..32 characters, not a stock emulator name.
 * Reads are NUL-terminated when they fit. Writes are fsync'd and renamed. */
const char *cab_ext_root(void);
int cab_ext_read(const char *name, char *buf, int cap);
int cab_ext_write(const char *name, const void *data, int n);

#endif
