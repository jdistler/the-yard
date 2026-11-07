/* play's picture: the core frame, the marquee above it, the button legend below it, the quit meter.
 *
 * Pass 1 (only when the final scale is not a whole number): the frame, nearest-neighbour, at the
 * largest whole-number scale that fits, into a scratch texture. Pass 2: that (or the frame itself)
 * onto cab_gl's upright 768x1024 target, bilinear, at the core's aspect ratio and turned by the core's
 * rotation, so a vertical arcade board stands up and fills the tall glass. The bands are drawn only
 * when they change (the target keeps them), so a frame costs the game's own pixels plus the copy to
 * the panel.
 */
#include "play_gl.h"
#include "gfx.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef unsigned char GLboolean;

#define GL_BLEND 0x0BE2
#define GL_SCISSOR_TEST 0x0C11
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_TRIANGLE_STRIP 0x0005
#define GL_FLOAT 0x1406
#define GL_UNSIGNED_BYTE 0x1401
#define GL_UNSIGNED_SHORT_5_6_5 0x8363
#define GL_RGB 0x1907
#define GL_RGBA 0x1908
#define GL_TEXTURE_2D 0x0DE1
#define GL_TEXTURE0 0x84C0
#define GL_NEAREST 0x2600
#define GL_LINEAR 0x2601
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_FRAMEBUFFER 0x8D40
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_ARRAY_BUFFER 0x8892
#define GL_UNPACK_ALIGNMENT 0x0CF5
#define GL_SRC_ALPHA 0x0302
#define GL_ONE_MINUS_SRC_ALPHA 0x0303

static void (*glBindFramebuffer)(GLenum, GLuint);
static void (*glGenFramebuffers)(GLsizei, GLuint *);
static void (*glFramebufferTexture2D)(GLenum, GLenum, GLenum, GLuint, GLint);
static GLenum (*glCheckFramebufferStatus)(GLenum);
static void (*glViewport)(GLint, GLint, GLsizei, GLsizei);
static void (*glScissor)(GLint, GLint, GLsizei, GLsizei);
static void (*glClearColor)(float, float, float, float);
static void (*glClear)(unsigned);
static void (*glEnable)(GLenum);
static void (*glDisable)(GLenum);
static void (*glBlendFunc)(GLenum, GLenum);
static void (*glGenTextures)(GLsizei, GLuint *);
static void (*glBindTexture)(GLenum, GLuint);
static void (*glActiveTexture)(GLenum);
static void (*glTexImage2D)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
static void (*glTexSubImage2D)(GLenum, GLint, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, const void *);
static void (*glTexParameteri)(GLenum, GLenum, GLint);
static void (*glPixelStorei)(GLenum, GLint);
static void (*glBindBuffer)(GLenum, GLuint);
static void (*glEnableVertexAttribArray)(GLuint);
static void (*glVertexAttribPointer)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *);
static void (*glDrawArrays)(GLenum, GLint, GLsizei);
static void (*glUseProgram)(GLuint);
static GLuint (*glCreateShader)(GLenum);
static void (*glShaderSource)(GLuint, GLsizei, const char *const *, const GLint *);
static void (*glCompileShader)(GLuint);
static void (*glGetShaderiv)(GLuint, GLenum, GLint *);
static void (*glGetShaderInfoLog)(GLuint, GLsizei, GLsizei *, char *);
static GLuint (*glCreateProgram)(void);
static void (*glAttachShader)(GLuint, GLuint);
static void (*glBindAttribLocation)(GLuint, GLuint, const char *);
static void (*glLinkProgram)(GLuint);
static void (*glGetProgramiv)(GLuint, GLenum, GLint *);
static GLint (*glGetUniformLocation)(GLuint, const char *);
static void (*glUniform1i)(GLint, GLint);

static int load(void)
{
#define LOAD(n)                                   \
    do {                                          \
        void *s = cab_gl_proc(#n);                \
        if (!s) {                                 \
            cab_log("play: no %s", #n);           \
            return -1;                            \
        }                                         \
        memcpy(&n, &s, sizeof n);                 \
    } while (0)
    LOAD(glBindFramebuffer);
    LOAD(glGenFramebuffers);
    LOAD(glFramebufferTexture2D);
    LOAD(glCheckFramebufferStatus);
    LOAD(glViewport);
    LOAD(glScissor);
    LOAD(glClearColor);
    LOAD(glClear);
    LOAD(glEnable);
    LOAD(glDisable);
    LOAD(glBlendFunc);
    LOAD(glGenTextures);
    LOAD(glBindTexture);
    LOAD(glActiveTexture);
    LOAD(glTexImage2D);
    LOAD(glTexSubImage2D);
    LOAD(glTexParameteri);
    LOAD(glPixelStorei);
    LOAD(glBindBuffer);
    LOAD(glEnableVertexAttribArray);
    LOAD(glVertexAttribPointer);
    LOAD(glDrawArrays);
    LOAD(glUseProgram);
    LOAD(glCreateShader);
    LOAD(glShaderSource);
    LOAD(glCompileShader);
    LOAD(glGetShaderiv);
    LOAD(glGetShaderInfoLog);
    LOAD(glCreateProgram);
    LOAD(glAttachShader);
    LOAD(glBindAttribLocation);
    LOAD(glLinkProgram);
    LOAD(glGetProgramiv);
    LOAD(glGetUniformLocation);
    LOAD(glUniform1i);
#undef LOAD
    return 0;
}

#define VW CAB_PANEL_W /* 768 */
#define VH CAB_PANEL_H /* 1024 */

static const char *vs = "attribute vec2 a_pos; attribute vec2 a_uv; varying vec2 v_uv;\n"
                        "void main() { v_uv = a_uv; gl_Position = vec4(a_pos, 0.0, 1.0); }\n";
static const char *fs_rgb = "precision mediump float; varying vec2 v_uv; uniform sampler2D u_tex;\n"
                            "void main() { gl_FragColor = vec4(texture2D(u_tex, v_uv).rgb, 1.0); }\n";
/* XRGB8888 arrives as bytes B,G,R,X: uploaded as RGBA and swapped back here. */
static const char *fs_bgr = "precision mediump float; varying vec2 v_uv; uniform sampler2D u_tex;\n"
                            "void main() { gl_FragColor = vec4(texture2D(u_tex, v_uv).bgr, 1.0); }\n";
static const char *fs_rgba = "precision mediump float; varying vec2 v_uv; uniform sampler2D u_tex;\n"
                             "void main() { gl_FragColor = texture2D(u_tex, v_uv); }\n";

static GLuint p_rgb, p_bgr, p_rgba;
static int to_screen, screen_rot; /* drawing on the real framebuffer, which is turned on the cabinet */
static GLuint t_game, t_pre, f_pre, t_top, t_bot, t_quit;
static int tex_w, tex_h, pre_w, pre_h, game_fmt_32;
static unsigned frame_w, frame_h;
static Uint16 *conv;
static size_t conv_cap;
static gsurf *s_top, *s_bot, *s_quit;
static int top_h, bot_h, bands_dirty = 1;
static char note[128];
double play_t_upload, play_t_draw, play_t_present; /* seconds, summed; play.c logs and clears them */
static double now_s(void) { return SDL_GetPerformanceCounter() / (double)SDL_GetPerformanceFrequency(); }
static float last_quit = -1;

static GLuint shader(GLenum type, const char *src)
{
    GLuint s = glCreateShader(type);
    GLint ok = 0;
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        cab_log("play: shader: %s", log);
        return 0;
    }
    return s;
}

static GLuint program(const char *fs)
{
    GLuint p = glCreateProgram(), v = shader(GL_VERTEX_SHADER, vs), f = shader(GL_FRAGMENT_SHADER, fs);
    GLint ok = 0;
    if (!v || !f)
        return 0;
    glAttachShader(p, v);
    glAttachShader(p, f);
    glBindAttribLocation(p, 0, "a_pos");
    glBindAttribLocation(p, 1, "a_uv");
    glLinkProgram(p);
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok)
        return 0;
    glUseProgram(p);
    glUniform1i(glGetUniformLocation(p, "u_tex"), 0);
    return p;
}

static GLuint texture(int filter)
{
    GLuint t;
    glGenTextures(1, &t);
    glBindTexture(GL_TEXTURE_2D, t);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return t;
}

/* A quad from pixel rect (x, y, w, h) of a vw x vh target (y down), with corner UVs in the order
 * top-left, top-right, bottom-left, bottom-right. */
static void quad(float x, float y, float w, float h, int vw, int vh, const float uv[8])
{
    float x0 = x / vw * 2 - 1, x1 = (x + w) / vw * 2 - 1;
    float y0 = 1 - y / vh * 2, y1 = 1 - (y + h) / vh * 2;
    float pos[8] = {x0, y0, x1, y0, x0, y1, x1, y1};
    if (to_screen && screen_rot)
        /* Straight onto the landscape framebuffer: the top of the upright picture lands on the left
         * (the same -90 degree turn as cab_gl_present). Upright (u, v) -> screen (-v, u). */
        for (int i = 0; i < 8; i += 2) {
            float u = pos[i], v = pos[i + 1];
            pos[i] = -v;
            pos[i + 1] = u;
        }
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, pos);
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, uv);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

static void upload_surf(GLuint t, gsurf *s)
{
    /* gsurf is 0xAARRGGBB words: bytes B,G,R,A on a little-endian machine. Swap to RGBA. */
    static Uint32 *tmp;
    static int cap;
    int n = s->w * s->h;
    if (n > cap) {
        free(tmp);
        tmp = malloc(n * 4);
        cap = n;
    }
    for (int i = 0; i < n; i++) {
        Uint32 c = s->px[i];
        tmp[i] = (c & 0xff00ff00u) | ((c >> 16) & 0xff) | ((c & 0xff) << 16);
    }
    glBindTexture(GL_TEXTURE_2D, t);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, s->w, s->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, tmp);
}

/* ------------------------------------------------------------------ the bands */

extern char play_verbs[3][32];
extern int play_has_verbs;

static gcol accent_col(const struct play_sys *sys) { return HEX(sys->accent); }

static void fit_text(int size, float x, float y, gcol c, int align, int maxw, const char *s)
{
    while (size > 14 && gfx_ttf_width(0, size, s) > maxw)
        size -= 2;
    gfx_ttf(0, size, x, y, c, RGBA(0, 0, 0, 160), align, s);
}

static void draw_top(const struct play_sys *sys, const char *title)
{
    gcol a = accent_col(sys);
    gfx_target(s_top);
    gfx_vgrad(0, 0, VW, top_h, RGB(14, 12, 26), RGB(6, 5, 12));
    if (top_h < 60) {
        gfx_target(NULL);
        return;
    }
    gfx_rect(0, top_h - 4, VW, 4, a);
    fit_text(top_h > 150 ? 52 : 40, VW / 2, top_h * 0.22f, RGB(255, 246, 230), 1, VW - 48, title);
    gfx_ttf(0, 24, VW / 2, top_h * 0.22f + (top_h > 150 ? 66 : 50), col_mix(a, RGB(255, 255, 255), 0.35f), RGBA(0, 0, 0, 0), 1,
            note[0] ? note : sys->name);
    gfx_target(NULL);
}

/* The deck as it sits under the player's hands (GAMEDEV.md section 2): 1-player above 2-player at the
 * far left, the stick, then two buttons on a top row and the lower button beneath them, shifted left.
 * Each button wears the game's name for it. */
static void button(float cx, float cy, float r, gcol fill, const char *in, const char *beside)
{
    gfx_circle(cx, cy + 4, r, RGBA(0, 0, 0, 130));
    gfx_circle_o(cx, cy, r, fill, RGB(10, 8, 16), 3);
    gfx_circle(cx - r * 0.3f, cy - r * 0.35f, r * 0.33f, RGBA(255, 255, 255, 70));
    if (in && *in)
        gfx_ttf(0, (int)(r * 0.85f), cx, cy - r * 0.5f, RGB(255, 255, 255), RGBA(0, 0, 0, 220), 1, in);
    if (beside && *beside)
        gfx_ttf(0, 20, cx + r + 10, cy - 12, RGB(214, 208, 236), RGBA(0, 0, 0, 0), 0, beside);
}

static void draw_bottom(const struct play_sys *sys)
{
    gcol a = accent_col(sys), lit = col_mix(a, RGB(255, 255, 255), 0.25f), off = RGB(46, 42, 58);
    float cy, top, low, k;
    gfx_target(s_bot);
    gfx_vgrad(0, 0, VW, bot_h, RGB(6, 5, 12), RGB(16, 12, 30));
    if (bot_h < 120) {
        gfx_target(NULL);
        return;
    }
    gfx_rect(0, 0, VW, 4, a);
    /* Sized to the band: a square Game Boy picture leaves about 200 px, a 4:3 one about 270. */
    k = (bot_h - 40) / 230.f;
    if (k > 1) k = 1;
    if (k < 0.55f) k = 0.55f;
    cy = (bot_h - 34) * 0.5f + 4;
    top = cy - 40 * k;
    low = cy + 42 * k;
    /* 1P over 2P */
    button(64, top, 24 * k, RGB(232, 232, 238), "1P", sys->coin_start ? "play" : "start");
    button(64, low, 24 * k, RGB(232, 232, 238), "2P", sys->coin_start ? "coin" : "select");
    /* Stick */
    gfx_ellipse(250, cy + 34 * k, 52 * k, 18 * k, RGB(28, 24, 40));
    gfx_line(250, cy + 34 * k, 250, cy - 14 * k, 12 * k, RGB(70, 66, 82));
    gfx_circle_o(250, cy - 22 * k, 28 * k, RGB(214, 40, 40), RGB(10, 8, 16), 3);
    /* Top-left, top-right, and the lower button shifted left */
    /* A button this game does nothing with is dark; each live one says what it does (index.tsv's names,
     * else the system's letters) above the top row and beside the lower button. */
    {
        float bx[3] = {450 - 40 * k, 450, 450 + 110 * k}, by[3] = {low, top, top};
        for (int i = 0; i < 3; i++) {
            int live = sys->btn[i] >= 0 && (!play_has_verbs || play_verbs[i][0]);
            gcol fill = !live ? off : i == 0 ? col_mix(a, RGB(255, 255, 255), 0.4f) : lit;
            button(bx[i], by[i], 36 * k, fill, sys->label[i], NULL);
            if (live && play_has_verbs) {
                if (i == 0)
                    gfx_ttf(0, 22, bx[i] + 36 * k + 14, by[i] - 13, RGB(255, 236, 190), RGBA(0, 0, 0, 0), 0, play_verbs[i]);
                else
                    gfx_ttf(0, 18, bx[i], by[i] - 36 * k - 26, RGB(255, 236, 190), RGBA(0, 0, 0, 0), 1, play_verbs[i]);
            }
        }
    }
    gfx_ttf(0, 20, VW / 2, bot_h - 30, RGB(150, 144, 178), RGBA(0, 0, 0, 0), 1, "hold 1P + 2P to leave");
    gfx_target(NULL);
}

static void draw_quit(float q)
{
    int w = s_quit->w, h = s_quit->h;
    gfx_target(s_quit);
    gfx_surf_clear(s_quit);
    gfx_rrect(0, 0, w, h, 16, RGBA(8, 6, 16, 230));
    gfx_rrect(6, 6, w - 12, h - 12, 12, RGBA(40, 34, 64, 245));
    gfx_rrect(16, h - 30, (w - 32) * q, 16, 6, RGB(255, 200, 90));
    gfx_ttf(0, 30, w / 2, 14, RGB(255, 246, 234), RGBA(0, 0, 0, 0), 1, "leaving...");
    gfx_target(NULL);
}

/* ------------------------------------------------------------------ layout */

/* The game's rectangle on the 768x1024 target. */
static void layout(const struct retro_system_av_info *av, int rotation, float *x, float *y, float *w, float *h)
{
    float aspect = av->geometry.aspect_ratio > 0 ? av->geometry.aspect_ratio
                                                 : (float)av->geometry.base_width / av->geometry.base_height;
    if (rotation & 1)
        aspect = 1 / aspect;
    *w = VW;
    *h = VW / aspect;
    if (*h > VH) {
        *h = VH;
        *w = VH * aspect;
    }
    *x = (VW - *w) / 2;
    /* A little above the middle: the marquee is shorter than the legend. */
    *y = floorf((VH - *h) * 0.4f);
}

int play_gl_init(const struct play_sys *sys, const char *title, const struct retro_system_av_info *av)
{
    float x, y, w, h;
    (void)title;
    if (cab_gl_init("play", VW, VH) != 0 || load() != 0)
        return -1;
    if (!(p_rgb = program(fs_rgb)) || !(p_bgr = program(fs_bgr)) || !(p_rgba = program(fs_rgba)))
        return -1;
    tex_w = av->geometry.max_width;
    tex_h = av->geometry.max_height;
    t_game = texture(GL_NEAREST);
    t_pre = texture(GL_LINEAR);
    t_top = texture(GL_NEAREST);
    t_bot = texture(GL_NEAREST);
    t_quit = texture(GL_LINEAR);
    glGenFramebuffers(1, &f_pre);
    layout(av, 0, &x, &y, &w, &h);
    top_h = (int)y;
    bot_h = VH - (int)(y + h);
    /* The rotated layout can be taller; bands are sized again on the first draw. */
    s_top = gfx_surf_new(VW, top_h > 1 ? top_h : 1);
    s_bot = gfx_surf_new(VW, bot_h > 1 ? bot_h : 1);
    s_quit = gfx_surf_new(480, 110);
    (void)sys;
    return 0;
}

void play_gl_note(const char *s)
{
    snprintf(note, sizeof note, "%s", s ? s : "");
    bands_dirty = 1;
}

static void upload_inner(const void *data, unsigned w, unsigned h, size_t pitch, enum retro_pixel_format fmt);
void play_gl_upload(const void *data, unsigned w, unsigned h, size_t pitch, enum retro_pixel_format fmt)
{
    double t0 = now_s();
    upload_inner(data, w, h, pitch, fmt);
    play_t_upload += now_s() - t0;
}

static void upload_inner(const void *data, unsigned w, unsigned h, size_t pitch, enum retro_pixel_format fmt)
{
    int is32 = fmt == RETRO_PIXEL_FORMAT_XRGB8888;
    if ((int)w > tex_w || (int)h > tex_h || is32 != game_fmt_32 || !frame_w) {
        if ((int)w > tex_w) tex_w = w;
        if ((int)h > tex_h) tex_h = h;
        game_fmt_32 = is32;
        glBindTexture(GL_TEXTURE_2D, t_game);
        if (is32)
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tex_w, tex_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        else
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, tex_w, tex_h, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, NULL);
    }
    frame_w = w;
    frame_h = h;
    glBindTexture(GL_TEXTURE_2D, t_game);
    if (is32) {
        /* Rows are uploaded packed: GLES 2 has no row length. */
        if (pitch == w * 4) {
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, data);
        } else {
            for (unsigned r = 0; r < h; r++)
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, r, w, 1, GL_RGBA, GL_UNSIGNED_BYTE, (const char *)data + r * pitch);
        }
        return;
    }
    if (conv_cap < (size_t)w * h) {
        free(conv);
        conv_cap = (size_t)w * h;
        conv = malloc(conv_cap * 2);
    }
    if (fmt == RETRO_PIXEL_FORMAT_RGB565) {
        if (pitch == w * 2) {
            glPixelStorei(GL_UNPACK_ALIGNMENT, 2);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, data);
            return;
        }
        for (unsigned r = 0; r < h; r++)
            memcpy(conv + r * w, (const char *)data + r * pitch, w * 2);
    } else {
        for (unsigned r = 0; r < h; r++) {
            const Uint16 *s = (const Uint16 *)((const char *)data + r * pitch);
            Uint16 *d = conv + r * w;
            for (unsigned c = 0; c < w; c++) {
                Uint16 p = s[c];
                d[c] = (Uint16)(((p & 0x7c00) << 1) | ((p & 0x03e0) << 1) | ((p >> 4) & 0x20) | (p & 0x1f));
            }
        }
    }
    glPixelStorei(GL_UNPACK_ALIGNMENT, 2);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, conv);
}

void play_gl_draw(const struct play_sys *sys, const char *title, const struct retro_system_av_info *av, int rotation,
                  float quit)
{
    float x, y, w, h, u1, v1;
    float uv[8];
    int scale, src_w, src_h, whole;
    GLuint src;
    double t0 = now_s(), t1;
    if (!frame_w)
        return;
    layout(av, rotation, &x, &y, &w, &h);
    /* The frame's own size on screen, before rotation. */
    src_w = (rotation & 1) ? (int)h : (int)w;
    src_h = (rotation & 1) ? (int)w : (int)h;
    scale = src_w / (int)frame_w;
    if (src_h / (int)frame_h < scale)
        scale = src_h / (int)frame_h;
    if (scale < 1)
        scale = 1;
    whole = (int)frame_w * scale == src_w && (int)frame_h * scale == src_h;

    u1 = (float)frame_w / tex_w;
    v1 = (float)frame_h / tex_h;
    src = t_game;
    if (!whole && scale > 1) {
        /* Pass 1: whole-number nearest scale into the scratch texture. */
        int pw = frame_w * scale, ph = frame_h * scale;
        float id[8] = {0, 0, u1, 0, 0, v1, u1, v1};
        if (pw != pre_w || ph != pre_h) {
            glBindTexture(GL_TEXTURE_2D, t_pre);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, pw, ph, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, NULL);
            glBindFramebuffer(GL_FRAMEBUFFER, f_pre);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t_pre, 0);
            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
                cab_log("play: scratch target %dx%d incomplete", pw, ph);
            pre_w = pw;
            pre_h = ph;
        }
        glBindFramebuffer(GL_FRAMEBUFFER, f_pre);
        glViewport(0, 0, pw, ph);
        /* A clear first, always: the Mali renders in tiles, and a target that is not cleared is read
         * back from memory into every tile before drawing. */
        glClear(GL_COLOR_BUFFER_BIT);
        glDisable(GL_BLEND);
        glUseProgram(game_fmt_32 ? p_bgr : p_rgb);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, t_game);
        /* Drawn upside down into the texture so pass 2 reads it the same way as the frame. */
        quad(0, 0, pw, ph, pw, ph, (float[8]){0, v1, u1, v1, 0, 0, u1, 0});
        (void)id;
        src = t_pre;
        u1 = v1 = 1;
    }

    /* Pass 2 onto the screen itself, no intermediate target: every pixel is drawn once a frame. A frame
     * through cab_gl's upright target cost two more full-screen passes (its clear and the turned copy),
     * and on this Mali that held Super Mario World to 35-40 fps (2026-11-07). */
    {
        int ow = 0, oh = 0;
        SDL_GL_GetDrawableSize(cab_window, &ow, &oh);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, ow, oh);
        to_screen = 1;
        screen_rot = cab_rotate_on();
    }
    glDisable(GL_BLEND);
    if ((int)y != top_h || VH - (int)(y + h) != bot_h) {
        top_h = (int)y;
        bot_h = VH - (int)(y + h);
        gfx_surf_free(s_top);
        gfx_surf_free(s_bot);
        s_top = gfx_surf_new(VW, top_h > 1 ? top_h : 1);
        s_bot = gfx_surf_new(VW, bot_h > 1 ? bot_h : 1);
        bands_dirty = 1;
    }
    if (bands_dirty) {
        draw_top(sys, title);
        draw_bottom(sys);
        upload_surf(t_top, s_top);
        upload_surf(t_bot, s_bot);
        bands_dirty = 0;
    }
    {
        float full[8] = {0, 0, 1, 0, 0, 1, 1, 1};
        glUseProgram(p_rgba);
        glActiveTexture(GL_TEXTURE0);
        /* Always cleared (black beside a pillarboxed board, and no tile reload). */
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        if (top_h > 0) {
            glBindTexture(GL_TEXTURE_2D, t_top);
            quad(0, 0, VW, top_h, VW, VH, full);
        }
        if (bot_h > 0) {
            glBindTexture(GL_TEXTURE_2D, t_bot);
            quad(0, VH - bot_h, VW, bot_h, VW, VH, full);
        }
    }

    /* The picture, turned by the core's rotation (quarter turns counter-clockwise). */
    {
        float tl[2] = {0, 0}, tr[2] = {u1, 0}, bl[2] = {0, v1}, br[2] = {u1, v1};
        float *c[4];
        int r = rotation & 3;
        float *order[4] = {tl, tr, br, bl}; /* clockwise around the frame */
        /* Screen corner k (TL, TR, BR, BL clockwise) shows frame corner k + r. */
        for (int k = 0; k < 4; k++)
            c[k] = order[(k + r) & 3];
        uv[0] = c[0][0]; uv[1] = c[0][1];
        uv[2] = c[1][0]; uv[3] = c[1][1];
        uv[4] = c[3][0]; uv[5] = c[3][1];
        uv[6] = c[2][0]; uv[7] = c[2][1];
    }
    glUseProgram(src == t_game && game_fmt_32 ? p_bgr : p_rgb);
    glBindTexture(GL_TEXTURE_2D, src);
    if (src == t_game) {
        /* Whole-number scale (or none possible): nearest is exact. */
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, whole ? GL_NEAREST : GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, whole ? GL_NEAREST : GL_LINEAR);
    }
    quad(x, y, w, h, VW, VH, uv);

    /* The quit meter, over the middle of the game while 1P+2P are held. */
    if (quit > 0) {
        float full[8] = {0, 0, 1, 0, 0, 1, 1, 1};
        if (fabsf(quit - last_quit) > 0.02f) {
            draw_quit(quit);
            upload_surf(t_quit, s_quit);
            last_quit = quit;
        }
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glUseProgram(p_rgba);
        glBindTexture(GL_TEXTURE_2D, t_quit);
        quad((VW - s_quit->w) / 2, VH / 2 - s_quit->h / 2, s_quit->w, s_quit->h, VW, VH, full);
        glDisable(GL_BLEND);
    } else
        last_quit = -1;
    to_screen = 0;
    t1 = now_s();
    play_t_draw += t1 - t0;
    cab_shot_if_due();
    SDL_GL_SwapWindow(cab_window);
    play_t_present += now_s() - t1;
}

void play_gl_shutdown(void) { cab_gl_shutdown(); }
