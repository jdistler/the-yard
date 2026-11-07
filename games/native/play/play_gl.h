#ifndef PLAY_GL_H
#define PLAY_GL_H

#include "libretro.h"
#include "play_sys.h"

#include <stddef.h>

int play_gl_init(const struct play_sys *sys, const char *title, const struct retro_system_av_info *av);
/* Called from the core's video callback (same thread, the GL context is current). */
void play_gl_upload(const void *data, unsigned w, unsigned h, size_t pitch, enum retro_pixel_format fmt);
/* quit: the 1P+2P hold, 0..1. */
void play_gl_draw(const struct play_sys *sys, const char *title, const struct retro_system_av_info *av, int rotation,
                  float quit);
/* Text for the marquee's second line (a best score, a note). NULL clears it. */
void play_gl_note(const char *s);
void play_gl_shutdown(void);

#endif
