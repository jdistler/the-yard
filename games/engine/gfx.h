/* gfx: a small software renderer for the 2D games, plus a few helpers every game wants.
 *
 * The game draws into one 32-bit ARGB frame at its logical size (240x320 or 384x512).
 * gfx_present uploads that frame to one streaming texture, the same way the stock
 * emulators do (GAMEDEV.md section 1), and cab_present rotates it for the panel.
 * Nothing here needs SDL newer than 2.0.7, SDL_ttf, or a picture file.
 *
 * Shapes are anti-aliased at their edges. Colors are 0xAARRGGBB; alpha below 255 blends.
 * Text is the 8x8 public-domain font, set proportionally, with an optional outline.
 */
#ifndef GFX_H
#define GFX_H

#include "cab.h"

typedef Uint32 gcol;

#define RGB(r, g, b) ((gcol)(0xff000000u | ((Uint32)(r) << 16) | ((Uint32)(g) << 8) | (Uint32)(b)))
#define RGBA(r, g, b, a) ((gcol)(((Uint32)(a) << 24) | ((Uint32)(r) << 16) | ((Uint32)(g) << 8) | (Uint32)(b)))
#define HEX(h) ((gcol)(0xff000000u | (Uint32)(h)))
#define HEXA(h, a) ((gcol)(((Uint32)(a) << 24) | ((Uint32)(h) & 0xffffffu)))
#define COL_R(c) ((int)(((c) >> 16) & 255))
#define COL_G(c) ((int)(((c) >> 8) & 255))
#define COL_B(c) ((int)((c) & 255))
#define COL_A(c) ((int)((c) >> 24))

typedef struct {
    Uint32 *px;
    int w, h;
} gsurf;

extern gsurf gfx_screen;
extern int gfx_frame; /* presents so far */

/* cab_init plus the frame and its texture. */
int gfx_init(const char *title, int w, int h);
/* Overlays (the quit meter), upload, copy, cab_present, and 60 Hz pacing when there is no vsync. */
void gfx_present(void);
/* Draw into another surface (NULL is the screen). Clip resets to the whole target. */
void gfx_target(gsurf *s);
gsurf *gfx_surf_new(int w, int h);
/* Copy a surface onto the target, opaque. Backgrounds that do not move are drawn once and blitted. */
void gfx_blit(const gsurf *s, int x, int y);
/* Sprite caches: clear a surface to transparent, draw a figure into it once, then
 * gfx_blit_key copies only the pixels that were drawn. */
void gfx_surf_clear(gsurf *s);
void gfx_blit_key(const gsurf *s, int x, int y);
void gfx_surf_free(gsurf *s);
void gfx_clip(int x, int y, int w, int h);
void gfx_noclip(void);
/* Every draw call is shifted by this. Games use it for a camera. */
void gfx_offset(int dx, int dy);
/* Screen shake in pixels. Decays on its own. */
void gfx_shake(float amount);
/* A flash over the whole frame that fades over n frames. */
void gfx_flash(gcol c, int frames);

/* Color helpers. */
gcol col_mix(gcol a, gcol b, float t);
gcol col_alpha(gcol c, int a);
gcol col_scale(gcol c, float k);
gcol col_hsv(float h, float s, float v);

/* Primitives. */
void gfx_clear(gcol c);
void gfx_pixel(int x, int y, gcol c);
void gfx_rect(int x, int y, int w, int h, gcol c);
void gfx_rect_add(int x, int y, int w, int h, gcol c);
void gfx_frame_rect(int x, int y, int w, int h, int t, gcol c);
void gfx_vgrad(int x, int y, int w, int h, gcol top, gcol bottom);
void gfx_hgrad(int x, int y, int w, int h, gcol left, gcol right);
void gfx_circle(float cx, float cy, float r, gcol c);
void gfx_ellipse(float cx, float cy, float rx, float ry, gcol c);
void gfx_ring(float cx, float cy, float r, float thick, gcol c);
void gfx_rrect(float x, float y, float w, float h, float r, gcol c);
void gfx_tri(float x0, float y0, float x1, float y1, float x2, float y2, gcol c);
void gfx_poly(const float *xy, int n, gcol c);
void gfx_line(float x0, float y0, float x1, float y1, float thick, gcol c);
/* Additive soft light: brightest in the middle, nothing at r. */
void gfx_glow(float cx, float cy, float r, gcol c);
/* Outlined versions: ink first, a t-pixel border, then the fill. */
void gfx_circle_o(float cx, float cy, float r, gcol fill, gcol ink, float t);
void gfx_ellipse_o(float cx, float cy, float rx, float ry, gcol fill, gcol ink, float t);
void gfx_rrect_o(float x, float y, float w, float h, float r, gcol fill, gcol ink, float t);
/* A five-point star and a heart, both centered. */
void gfx_star(float cx, float cy, float r, float rot, gcol c);
void gfx_heart(float cx, float cy, float s, gcol c);
/* Multiply the whole target toward black (k 0..1 kept). */
void gfx_dim(float k);

/* Toon figures: draw a figure's parts twice, toon_pass 0 then 1. Pass 0 paints every
 * part in toon_ink grown by toon_t, pass 1 paints the fills, so one outline wraps the
 * whole figure. Details that should not get an outline check toon_pass == 1. */
extern int toon_pass;
extern float toon_t;
extern gcol toon_ink;
void toon_circle(float cx, float cy, float r, gcol c);
void toon_ellipse(float cx, float cy, float rx, float ry, gcol c);
void toon_rrect(float x, float y, float w, float h, float r, gcol c);
void toon_line(float x0, float y0, float x1, float y1, float thick, gcol c);
void toon_tri(float x0, float y0, float x1, float y1, float x2, float y2, gcol c);
void toon_poly(const float *xy, int n, gcol c);

/* Pixel art. rows are strings of palette keys. '.' and ' ' are clear.
 * keys[i] picks pal[i]. Up to 64 x 64. */
typedef struct {
    int w, h;
    Uint32 *px;
} gsprite;
gsprite *gfx_sprite_make(const char *const *rows, int nrows, const char *keys, const gcol *pal);
/* flip: 1 mirrors left-right. tint: 0 for none, else every opaque pixel mixes toward it by its alpha. */
void gfx_sprite(const gsprite *s, int x, int y, int scale, int flip, gcol tint);

/* TrueType text (gfx_text.inc). Font 0 is the built-in round face. y is the top of the line.
 * align 0 left, 1 center, 2 right. An outline with alpha 0 draws none. Returns the width. */
int gfx_font_add(const unsigned char *ttf, int len);
float gfx_ttf(int font, int size, float x, float y, gcol c, gcol outline, int align, const char *s);
float gfx_ttf_width(int font, int size, const char *s);
int gfx_ttf_line(int font, int size);

/* Images (gfx_image.inc): PNG files, drawn with a part, an origin, a scale, a turn, an alpha. */
gsprite *gfx_image_load(const char *path);
gsprite *gfx_image_mem(const unsigned char *data, int len);
int gfx_image_size(const unsigned char *data, int len, int *w, int *h);
void gfx_sprite_free(gsprite *s);
void gfx_image_draw(const Uint32 *px, int iw, int ih, int sx, int sy, int sw, int sh, float x, float y, float kx,
                    float ky, float rot, float ox, float oy, int alpha, gcol tint);

/* Text. Proportional set of font8x8_basic. Scale is whole pixels. */
int gfx_text_w(int scale, const char *fmt, ...);
void gfx_text(int x, int y, int scale, gcol c, const char *fmt, ...);
/* Text with a one-pixel outline (or shadow when ink alpha is 0... use gfx_text_s). */
void gfx_text_o(int x, int y, int scale, gcol c, gcol ink, const char *fmt, ...);
/* Centered on cx, outlined. */
void gfx_text_c(int cx, int y, int scale, gcol c, gcol ink, const char *fmt, ...);
/* A drop shadow one scale-pixel down and right. */
void gfx_text_s(int x, int y, int scale, gcol c, gcol shadow, const char *fmt, ...);

/* Light (gfx_light.inc): begin a map over a box at an ambient level (0 dark, 1 lit), add
 * round lights, apply. apply darkens each pixel by its light and leans the dark toward tint. */
void gfx_light_begin(int x, int y, int w, int h, float ambient);
void gfx_light_add(float cx, float cy, float r, float k);
void gfx_light_fill(float k);
void gfx_light_apply(gcol tint);
/* Paint everything outside a circle: the iris wipe. Screen coordinates. */
void gfx_iris(float cx, float cy, float r, gcol c);

/* Particles: one shared pool. */
enum { PART_DOT, PART_GLOW, PART_STAR, PART_HEART, PART_SQUARE, PART_RING, PART_TEXT };
typedef struct {
    float x, y, vx, vy, grav, drag, size, grow, spin, rot;
    int life, max, kind;
    gcol c;
    char text[12];
} gpart;
gpart *part_spawn(float x, float y, float vx, float vy, int life, float size, gcol c, int kind);
/* n particles flung from (x, y) in all directions. */
void part_burst(float x, float y, int n, float speed, int life, float size, gcol c, int kind);
/* A floating label such as "+3". */
void part_text(float x, float y, gcol c, const char *s);
void part_update(void);
void part_draw(void);
void part_clear(void);
int part_count(void);

/* Small deterministic RNG. Seeded from CAB_SEED, or 1 under a script, or the clock. */
void rng_seed(Uint32 s);
void rng_seed_auto(void);
Uint32 rng_u32(void);
float rng_f(void);                 /* 0..1 */
float rng_range(float lo, float hi);
int rng_int(int lo, int hi);       /* inclusive */

/* Easing and small math. */
float clampf(float v, float lo, float hi);
float lerpf(float a, float b, float t);
float ease_out_cubic(float t);
float ease_in_out(float t);
float ease_out_back(float t);
float ease_out_elastic(float t);
float approach(float v, float target, float rate);

#endif
