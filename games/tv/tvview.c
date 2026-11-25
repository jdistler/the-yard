/* tvview.c: everything tvplay draws, included by tvplay.c (it shares tvplay's GL loader and globals).
 *
 * The panel is portrait (768 x 1024 upright) and nearly every channel is 16:9, so the picture takes the middle
 * 768 x 432 and leaves two 296-pixel bands. They are filled, not left black:
 *   - behind everything, the picture itself, zoomed to cover the screen, blurred and darkened (it moves and
 *     changes colour with the programme, as the ambient backdrops of phone video apps do);
 *   - in the top band, the channel: logo, name, playlist and group, and the clock;
 *   - in the bottom band, the guide: what is on now (times, progress), and what is next.
 * Before the first picture (connecting, or flipping through channels) the same bands are drawn around "TUNING
 * IN..." at once, so the channel's name is there the moment the stick is pushed.
 * Stick left/right: FIT (the whole picture) or ZOOM (cropped to 4:3: 768 x 576, a third bigger). Lower button:
 * the bands' text on or off. Both are remembered (TVPLAY_VIEW).
 *
 * The blur: a 36 x 48 colour image of the picture made by the CPU from the decoded frame (ambient_update),
 * stretched over the bands by the GPU.
 * Text: a glyph sheet of Home's font made by games/tv/mkfont.py (TVPLAY_FONT, gzipped).
 *
 * Environment (from tvloop): TVPLAY_NAME, TVPLAY_SUB (the line under the name), TVPLAY_LOGO (Home's logo file:
 * "RGBA", w, h, pixels), TVPLAY_EPG + TVPLAY_EPGID (the playlist's epg.tsv and this channel's id in it),
 * TVPLAY_VIEW (the remembered view), TVPLAY_FONT, TVPLAY_HINT=1 (show the controls for a few seconds),
 * TVPLAY_TUNING (instead of "TUNING IN...", e.g. "RECONNECTING..."). */
#include <zlib.h>

#define GL_TEXTURE_2D 0x0DE1
#define GL_TEXTURE1 0x84C1
#define GL_RGBA 0x1908
#define GL_ALPHA 0x1906
#define GL_UNSIGNED_BYTE 0x1401
#define GL_BLEND 0x0BE2
#define GL_SRC_ALPHA 0x0302
#define GL_ONE_MINUS_SRC_ALPHA 0x0303
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_UNPACK_ALIGNMENT 0x0CF5
#define GL_TRIANGLES 0x0004

static void (*glTexSubImage2D_)(GLenum, GLint, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, const void *);
static void (*glTexImage2D_)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
static void (*glEnable_)(GLenum);
static void (*glDisable_)(GLenum);
static void (*glBlendFunc_)(GLenum, GLenum);
static void (*glUniform2f_)(GLint, GLfloat, GLfloat);
static void (*glUniform4f_)(GLint, GLfloat, GLfloat, GLfloat, GLfloat);
static void (*glPixelStorei_)(GLenum, GLint);

/* TVPLAY_HOLD=dir: when dir/hold.req appears, the picture is held still for 0.6 s (no draws, no flips) and the
   request removed, so tools/cab.sh shot can copy the screen whole (a copy slower than two refreshes, while the
   screen flips 60 times a second, could join two frames that used the same buffer). */
static double hold_until;
static int holding(void)
{
    static const char *dir;
    static int checked;
    static double last;
    if (!checked) { checked = 1; dir = getenv("TVPLAY_HOLD"); }
    if (now() < hold_until) return 1;
    if (!dir || now() - last < 0.1) return 0;
    last = now();
    char req[512];
    snprintf(req, sizeof req, "%s/hold.req", dir);
    if (access(req, F_OK) != 0) return 0;
    unlink(req);
    hold_until = now() + 0.6;
    say("holding the picture 0.6 s");
    return 1;
}

#define VW 768                                    /* the upright screen */
#define VH 1024

/* ------------------------------------------------------------------ programs */
typedef struct { GLuint p; GLint m, o, col, d, tex; } Prog;
static Prog P_VID, P_TEX, P_TEXT, P_SOLID;
static float XM[4], XO[2];                        /* upright pixels -> clip space, for the current target */

static Prog make_prog(const char *fs)
{
    /* Positions in upright pixels; m and o turn them to clip space (rotated for the panel, or not for a texture). */
    const char *vs = "attribute vec2 pos; attribute vec2 uv; varying vec2 v; uniform vec4 m; uniform vec2 o;"
                     "void main() { v = uv; gl_Position = vec4(m.x * pos.x + m.y * pos.y + o.x,"
                     " m.z * pos.x + m.w * pos.y + o.y, 0.0, 1.0); }";
    Prog P;
    P.p = glCreateProgram_();
    const char *src[2] = {vs, fs};
    GLenum kinds[2] = {GL_VERTEX_SHADER, GL_FRAGMENT_SHADER};
    for (int i = 0; i < 2; i++) {
        GLuint s = glCreateShader_(kinds[i]);
        GLint ok = 0;
        glShaderSource_(s, 1, &src[i], NULL);
        glCompileShader_(s);
        glGetShaderiv_(s, GL_COMPILE_STATUS, &ok);
        if (!ok) { char log[512]; glGetShaderInfoLog_(s, sizeof log, NULL, log); say("shader: %s", log); exit(32); }
        glAttachShader_(P.p, s);
    }
    glBindAttribLocation_(P.p, 0, "pos");
    glBindAttribLocation_(P.p, 1, "uv");
    glLinkProgram_(P.p);
    glUseProgram_(P.p);
    P.m = glGetUniformLocation_(P.p, "m");
    P.o = glGetUniformLocation_(P.p, "o");
    P.col = glGetUniformLocation_(P.p, "col");
    P.d = glGetUniformLocation_(P.p, "d");
    P.tex = glGetUniformLocation_(P.p, "tex");
    return P;
}

static void use(Prog *P, float r, float g, float b, float a)
{
    glUseProgram_(P->p);
    glUniform4f_(P->m, XM[0], XM[1], XM[2], XM[3]);
    glUniform2f_(P->o, XO[0], XO[1]);
    glUniform4f_(P->col, r, g, b, a);
}

static void target_screen(void)
{
    glViewport_(0, 0, ww, wh);
    /* Upright (u right, v down) is the framebuffer's (x = v, y = 767 - u): clip X = 2v/1024 - 1, Y = 2u/768 - 1. */
    XM[0] = 0; XM[1] = 2.0f / VH; XM[2] = 2.0f / VW; XM[3] = 0;
    XO[0] = -1; XO[1] = -1;
}

static void quad(float x0, float y0, float x1, float y1, float s0, float t0, float s1, float t1)
{
    float v[16] = {x0, y0, s0, t0, x1, y0, s1, t0, x0, y1, s0, t1, x1, y1, s1, t1};
    glVertexAttribPointer_(0, 2, GL_FLOAT, 0, 16, v);
    glVertexAttribPointer_(1, 2, GL_FLOAT, 0, 16, v + 2);
    glDrawArrays_(GL_TRIANGLE_STRIP, 0, 4);
}

static void rect(float x0, float y0, float x1, float y1, float r, float g, float b, float a)
{
    use(&P_SOLID, r, g, b, a);
    quad(x0, y0, x1, y1, 0, 0, 0, 0);
}

static GLuint new_texture(int w, int h, GLenum format, const void *pixels)
{
    GLuint t;
    glGenTextures_(1, &t);
    glActiveTexture_(GL_TEXTURE1);
    glBindTexture_(GL_TEXTURE_2D, t);
    glPixelStorei_(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D_(GL_TEXTURE_2D, 0, format, w, h, 0, format, GL_UNSIGNED_BYTE, pixels);
    glTexParameteri_(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri_(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri_(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri_(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glActiveTexture_(GL_TEXTURE0);
    return t;
}

static void bind2d(GLuint t)
{
    glActiveTexture_(GL_TEXTURE1);
    glBindTexture_(GL_TEXTURE_2D, t);
    glActiveTexture_(GL_TEXTURE0);
}

/* ------------------------------------------------------------------ text */
typedef struct { uint16_t x, y; uint8_t w, h; int8_t xo, yo; uint8_t adv, ok; } Glyph;
typedef struct { int px, lh, asc; Glyph g[256]; Glyph ex[8]; int excp[8], nex; } Font;
static Font fonts[6];
static int nfonts, AW = 1, AH = 1;
static GLuint atlas;

static void font_load(const char *path)
{
    gzFile z = gzopen(path, "rb");
    if (!z) { say("font: cannot open %s", path); return; }
    size_t cap = 1 << 20, n = 0;
    unsigned char *b = malloc(cap);
    int r;
    while ((r = gzread(z, b + n, (unsigned)(cap - n))) > 0) {
        n += r;
        if (n == cap) { cap *= 2; b = realloc(b, cap); }
    }
    gzclose(z);
#define U16(p) ((p)[0] | (p)[1] << 8)
    if (n < 10 || memcmp(b, "TVF1", 4)) { say("font: not a glyph sheet"); free(b); return; }
    AW = U16(b + 4); AH = U16(b + 6);
    int ns = U16(b + 8);
    size_t p = 10;
    for (int s = 0; s < ns && s < 6; s++) {
        Font *F = &fonts[nfonts++];
        memset(F, 0, sizeof *F);
        F->px = U16(b + p); F->lh = U16(b + p + 2); F->asc = U16(b + p + 4);
        int ng = U16(b + p + 6);
        p += 8;
        for (int i = 0; i < ng; i++, p += 12) {
            int cp = U16(b + p);
            Glyph g = {U16(b + p + 2), U16(b + p + 4), b[p + 6], b[p + 7], (int8_t)b[p + 8], (int8_t)b[p + 9], b[p + 10], 1};
            if (cp < 256) F->g[cp] = g;
            else if (F->nex < 8) { F->excp[F->nex] = cp; F->ex[F->nex++] = g; }
        }
    }
    if (p + (size_t)AW * AH <= n) atlas = new_texture(AW, AH, GL_ALPHA, b + p);
    else { say("font: short sheet"); nfonts = 0; }
    free(b);
}

static Font *font(int px)
{
    for (int i = 0; i < nfonts; i++) if (fonts[i].px == px) return &fonts[i];
    return nfonts ? &fonts[0] : NULL;
}

static const Glyph *glyph(Font *F, int cp)
{
    if (cp >= 0 && cp < 256) return F->g[cp].ok ? &F->g[cp] : NULL;
    for (int i = 0; i < F->nex; i++) if (F->excp[i] == cp) return &F->ex[i];
    return NULL;
}

/* The next character of UTF-8 text (0 at the end; a broken byte comes back as 0xFFFD). */
static int next_cp(const char **s)
{
    const unsigned char *p = (const unsigned char *)*s;
    int c = *p;
    if (!c) return 0;
    int n = c < 0x80 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 0;
    if (!n) { *s += 1; return 0xFFFD; }
    int cp = n == 1 ? c : c & (0x3F >> (n - 1));
    for (int i = 1; i < n; i++) {
        if ((p[i] & 0xC0) != 0x80) { *s += i; return 0xFFFD; }
        cp = cp << 6 | (p[i] & 0x3F);
    }
    *s += n;
    return cp;
}

static float text_width(Font *F, const char *s)
{
    float w = 0;
    int c;
    while ((c = next_cp(&s))) { const Glyph *g = glyph(F, c); if (g) w += g->adv; }
    return w;
}

static float tv_buf[6 * 4 * 160];

/* Draws s with its top at y (shadowed), cut to maxw with an ellipsis; returns its width. */
static float text_ex(Font *F, float x, float y, const char *s, float maxw, float r, float g, float b, float a, int shadow)
{
    if (!F || !atlas) return 0;
    float full = text_width(F, s);
    const Glyph *ell = glyph(F, 0x2026);
    float limit = full > maxw && ell ? maxw - ell->adv : 1e9;
    int n = 0, c;
    float pen = x, base = y + F->asc;
    const char *q = s;
    for (;;) {
        c = next_cp(&q);
        int last = 0;
        if (!c) break;
        const Glyph *gl = glyph(F, c);
        if (!gl) continue;
        if (pen - x + gl->adv > limit) { gl = ell; last = 1; }
        if (n >= 160) break;
        if (gl->w) {
            float x0 = pen + gl->xo, y0 = base + gl->yo, x1 = x0 + gl->w, y1 = y0 + gl->h;
            float s0 = (float)gl->x / AW, t0 = (float)gl->y / AH, s1 = (float)(gl->x + gl->w) / AW,
                  t1 = (float)(gl->y + gl->h) / AH;
            float *v = tv_buf + n * 24;
            float q6[24] = {x0, y0, s0, t0, x1, y0, s1, t0, x0, y1, s0, t1,
                            x1, y0, s1, t0, x1, y1, s1, t1, x0, y1, s0, t1};
            memcpy(v, q6, sizeof q6);
            n++;
        }
        pen += gl->adv;
        if (last) break;
    }
    if (!n) return pen - x;
    bind2d(atlas);
    glVertexAttribPointer_(0, 2, GL_FLOAT, 0, 16, tv_buf);
    glVertexAttribPointer_(1, 2, GL_FLOAT, 0, 16, tv_buf + 2);
    if (shadow) {
        float sm[4] = {XM[0], XM[1], XM[2], XM[3]}, so[2] = {XO[0], XO[1]};
        XO[0] += 2 * (XM[0] + XM[1]); XO[1] += 2 * (XM[2] + XM[3]);   /* 2 px right and down */
        use(&P_TEXT, 0, 0, 0, 0.6f * a);
        glDrawArrays_(GL_TRIANGLES, 0, n * 6);
        memcpy(XM, sm, sizeof sm); memcpy(XO, so, sizeof so);
    }
    use(&P_TEXT, r, g, b, a);
    glDrawArrays_(GL_TRIANGLES, 0, n * 6);
    return pen - x;
}

static float text(Font *F, float x, float y, const char *s, float maxw, float r, float g, float b, float a)
{
    return text_ex(F, x, y, s, maxw, r, g, b, a, 1);
}

static void text_right(Font *F, float xr, float y, const char *s, float r, float g, float b, float a)
{
    if (F) text(F, xr - text_width(F, s), y, s, 1e9, r, g, b, a);
}

static void text_center(Font *F, float cx, float y, const char *s, float r, float g, float b, float a)
{
    if (F) { float w = text_width(F, s); if (w > VW - 40) w = VW - 40; text(F, cx - w / 2, y, s, VW - 40, r, g, b, a); }
}

/* Programme titles as the panels send them: superscript tags (ᴴᴰ, ᴸᶦᵛᵉ) spelt out, characters the font lacks
   dropped, spaces tidied (Home's tv.lua clean() does the same for the guide). */
static void clean_text(const char *in, char *out, size_t cap)
{
    static const char *super[][2] = {{"ᵁᴴᴰ", "UHD"}, {"ᶠᴴᴰ", "FHD"}, {"ᴴᴰᴿ", "HDR"}, {"ᴴᴰ", "HD"}, {"ᴿᴬᵂ", "RAW"},
                                     {"ᴸᶦᵛᵉ", "LIVE"}, {"ˢᴰ", "SD"}, {"⁴ᴷ", "4K"}, {"ᵂᴱᴮ", "WEB"}, {"ᴺᵉʷ", "NEW"},
                                     {"ᴿᵉᵖˡᵃʸ", "REPLAY"}};
    size_t o = 0;
    const char *s = in;
    while (*s && o + 8 < cap) {
        int hit = 0;
        for (unsigned i = 0; i < sizeof super / sizeof *super; i++) {
            size_t l = strlen(super[i][0]);
            if (!strncmp(s, super[i][0], l)) {
                if (o && out[o - 1] != ' ') out[o++] = ' ';
                size_t m = strlen(super[i][1]);
                if (o + m + 1 < cap) { memcpy(out + o, super[i][1], m); o += m; }
                s += l;
                hit = 1;
                break;
            }
        }
        if (hit) continue;
        const char *start = s;
        int c = next_cp(&s);
        int keep = (c >= 32 && c < 127) || (c >= 0xA0 && c < 0x100) || c == 0x2013 || c == 0x2014 || c == 0x2026;
        if (c == '\t' || c == '\n') keep = 0;
        if (keep) {
            size_t l = s - start;
            if (c == ' ' && (o == 0 || out[o - 1] == ' ')) continue;
            memcpy(out + o, start, l);
            o += l;
        } else if (o && out[o - 1] != ' ') {
            out[o++] = ' ';
        }
    }
    while (o && out[o - 1] == ' ') o--;
    out[o] = 0;
}

/* ------------------------------------------------------------------ what is on */
typedef struct { long t0, t1; char title[192]; } Show;
static Show shows[48];
static int nshows;

static void epg_load(const char *path, const char *id)
{
    if (!path || !id || !*id) return;
    FILE *f = fopen(path, "r");
    if (!f) return;
    size_t idl = strlen(id);
    char *line = NULL;
    size_t cap = 0;
    while (getline(&line, &cap, f) > 0 && nshows < 48) {
        if (strncmp(line, id, idl) || line[idl] != '\t') continue;
        char *p = line + idl + 1, *e;
        long t0 = strtol(p, &e, 10);
        if (*e != '\t') continue;
        long t1 = strtol(e + 1, &e, 10);
        if (*e != '\t') continue;
        char *title = e + 1, *end = strchr(title, '\t');
        if (end) *end = 0;
        char *nl = strchr(title, '\n');
        if (nl) *nl = 0;
        shows[nshows].t0 = t0;
        shows[nshows].t1 = t1;
        clean_text(title, shows[nshows].title, sizeof shows[nshows].title);
        nshows++;
    }
    free(line);
    fclose(f);
}

static void hm(long t, char *buf, size_t n, int ampm)
{
    time_t tt = t;
    struct tm lt;
    localtime_r(&tt, &lt);
    int h = lt.tm_hour % 12;
    snprintf(buf, n, ampm ? "%d:%02d %s" : "%d:%02d", h ? h : 12, lt.tm_min, lt.tm_hour < 12 ? "AM" : "PM");
}

/* ------------------------------------------------------------------ the view */
static char ch_name[256], ch_sub[256];
static GLuint logo_tex;
static int logo_w, logo_h;
static int view_fill, view_info = 1;
static int plain;               /* TVPLAY_PLAIN=1 or /tmp/tv/plain: the picture alone (for measuring) */
static const char *view_path;
static double hint_until;
static GLuint amb;
static int amb_have;
#define AW_ 36                                    /* the backdrop's colours: 36 x 48, from the decoded frame */
#define AH_ 48
static float amb_acc[AH_][AW_][3];
static unsigned char amb_px[AH_][AW_][4];
#define CORAL 1.0f, 0.42f, 0.42f

static void logo_load(const char *path)
{
    if (!path || !*path) return;
    FILE *f = fopen(path, "rb");
    if (!f) return;
    unsigned char h[8];
    if (fread(h, 1, 8, f) == 8 && !memcmp(h, "RGBA", 4)) {
        int w = h[4] | h[5] << 8, hh = h[6] | h[7] << 8;
        if (w > 0 && hh > 0 && w <= 512 && hh <= 512) {
            unsigned char *px = malloc((size_t)w * hh * 4);
            if (fread(px, 1, (size_t)w * hh * 4, f) == (size_t)w * hh * 4) {
                logo_tex = new_texture(w, hh, GL_RGBA, px);
                logo_w = w;
                logo_h = hh;
            }
            free(px);
        }
    }
    fclose(f);
}

/* Another channel's bands (flipping happens in this process now): its name, the line under it, logo, guide. */
static void view_set_channel(const char *name, const char *sub, const char *logo, const char *epg, const char *epgid)
{
    clean_text(name ? name : "", ch_name, sizeof ch_name);
    clean_text(sub ? sub : "", ch_sub, sizeof ch_sub);
    if (logo_tex) { glDeleteTextures_(1, &logo_tex); logo_tex = 0; logo_w = logo_h = 0; }
    logo_load(logo);
    nshows = 0;
    epg_load(epg, epgid);
}

static void view_save(void)
{
    if (!view_path) return;
    FILE *f = fopen(view_path, "w");
    if (f) { fprintf(f, "%d %d\n", view_fill, view_info); fclose(f); }
}

static void view_init(void)
{
    glTexImage2D_ = gl("glTexImage2D");
    glTexSubImage2D_ = gl("glTexSubImage2D");
    glEnable_ = gl("glEnable");
    glDisable_ = gl("glDisable");
    glBlendFunc_ = gl("glBlendFunc");
    glUniform2f_ = gl("glUniform2f");
    glUniform4f_ = gl("glUniform4f");
    glPixelStorei_ = gl("glPixelStorei");

    const char *ext = "#extension GL_OES_EGL_image_external : require\n"
                      "precision mediump float; varying vec2 v; uniform samplerExternalOES tex; uniform vec4 col;";
    char fs[1024];
    snprintf(fs, sizeof fs, "%s void main() { gl_FragColor = texture2D(tex, v) * col; }", ext);
    P_VID = make_prog(fs);
    /* One texture read a pixel: the GPU (one Mali-400 core) has ~16 ms of fragments a frame, and four reads over
       the bands alone took 10 of them (2026-11-01). */
    P_TEX = make_prog("precision mediump float; varying vec2 v; uniform sampler2D tex; uniform vec4 col;"
                      "void main() { gl_FragColor = texture2D(tex, v) * col; }");
    P_TEXT = make_prog("precision mediump float; varying vec2 v; uniform sampler2D tex; uniform vec4 col;"
                       "void main() { gl_FragColor = vec4(col.rgb, col.a * texture2D(tex, v).a); }");
    P_SOLID = make_prog("precision mediump float; varying vec2 v; uniform vec4 col; void main() { gl_FragColor = col; }");
    glUseProgram_(P_VID.p); glUniform1i_(P_VID.tex, 0);
    glUseProgram_(P_TEX.p); glUniform1i_(P_TEX.tex, 1);
    glUseProgram_(P_TEXT.p); glUniform1i_(P_TEXT.tex, 1);
    glEnableVertexAttribArray_(0);
    glEnableVertexAttribArray_(1);
    glBlendFunc_(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    amb = new_texture(AW_, AH_, GL_RGBA, NULL);

    const char *e;
    font_load((e = getenv("TVPLAY_FONT")) ? e : "/data/tv/tvfont.gz");
    clean_text((e = getenv("TVPLAY_NAME")) ? e : "", ch_name, sizeof ch_name);
    clean_text((e = getenv("TVPLAY_SUB")) ? e : "", ch_sub, sizeof ch_sub);
    logo_load(getenv("TVPLAY_LOGO"));
    epg_load(getenv("TVPLAY_EPG"), getenv("TVPLAY_EPGID"));
    view_path = getenv("TVPLAY_VIEW");
    if (view_path) {
        FILE *f = fopen(view_path, "r");
        if (f) { if (fscanf(f, "%d %d", &view_fill, &view_info) != 2) view_fill = 0, view_info = 1; fclose(f); }
    }
    plain = ((e = getenv("TVPLAY_PLAIN")) && *e == '1') || access("/tmp/tv/plain", F_OK) == 0;
    if ((e = getenv("TVPLAY_HINT")) && *e == '1') hint_until = 1e18;   /* until 7 s after the first picture */
    say("view: font %s, logo %dx%d, %d shows, %s%s", nfonts ? "yes" : "no", logo_w, logo_h, nshows,
        view_fill ? "zoom" : "fit", view_info ? "" : ", info off");
}

/* The picture's height on the screen for a display aspect, in this view. */
static float picture_height(double dar)
{
    double target = view_fill && dar > 4.0 / 3 ? 4.0 / 3 : dar;
    float ph = (float)(VW / target);
    return ph > VH ? VH : ph;
}

static void draw_logo(float x, float y, float bw, float bh)
{
    if (!logo_tex) return;
    float k = bw / logo_w < bh / logo_h ? bw / logo_w : bh / logo_h;
    if (k > 1.5f) k = 1.5f;
    float w = logo_w * k, h = logo_h * k;
    float x0 = x + (bw - w) / 2, y0 = y + (bh - h) / 2;
    bind2d(logo_tex);
    use(&P_TEX, 1, 1, 1, 1);
    quad(x0, y0, x0 + w, y0 + h, 0, 0, 1, 1);
}

static void draw_bands(float ph)
{
    float B = (VH - ph) / 2, Y = B + ph;
    Font *big = font(46), *mid = font(34), *med = font(28), *sm = font(22);
    long t = (long)time(NULL);
    int clock_ok = t > 1700000000;
    char buf[64], buf2[64], line[320];
    glEnable_(GL_BLEND);

    /* Top band: the channel. */
    if (clock_ok) { hm(t, buf, sizeof buf, 1); text_right(med, VW - 28, 22, buf, 0.92f, 0.9f, 1, 0.8f); }
    float yb = B - 24 - 84, x = 28;
    if (yb < 60) yb = 60;
    if (logo_tex) {
        rect(26, yb - 2, 26 + 140, yb + 86, 1, 1, 1, 0.07f);
        draw_logo(32, yb + 4, 128, 76);
        x = 26 + 140 + 22;
    }
    text(big, x, yb - 6, ch_name, VW - 28 - x, 1, 1, 1, 1);
    text(sm, x, yb + 54, ch_sub, VW - 28 - x, 0.8f, 0.76f, 0.95f, 0.95f);

    /* Bottom band: what is on. */
    /* Now: of the shows running, the one that started last (panels' guides overlap: a 3:30-6:00 game and a
       4:00-6:00 one). Next: the first to start once it ends. */
    int cur = -1, nxt = -1;
    if (clock_ok) {
        for (int i = 0; i < nshows; i++)
            if (shows[i].t0 <= t && t < shows[i].t1 && (cur < 0 || shows[i].t0 > shows[cur].t0)) cur = i;
        if (cur >= 0)
            for (int i = 0; i < nshows; i++)
                if (shows[i].t0 >= shows[cur].t1 && (nxt < 0 || shows[i].t0 < shows[nxt].t0)) nxt = i;
    }
    float y = Y + 22;
    if (cur >= 0) {
        Show *s = &shows[cur];
        float w = text(sm, 28, y, "NOW", 100, CORAL, 1);
        hm(s->t0, buf, sizeof buf, 0);
        hm(s->t1, buf2, sizeof buf2, 1);
        snprintf(line, sizeof line, "%s \xe2\x80\x93 %s", buf, buf2);
        text(sm, 28 + w + 14, y, line, 400, 0.85f, 0.82f, 0.95f, 0.9f);
        long left = (s->t1 - t + 59) / 60;
        if (left >= 60) snprintf(line, sizeof line, "%ld H %02ld MIN LEFT", left / 60, left % 60);
        else snprintf(line, sizeof line, "%ld MIN LEFT", left);
        text_right(sm, VW - 28, y, line, 0.85f, 0.82f, 0.95f, 0.75f);
        y += 30;
        text(mid, 28, y, s->title, VW - 56, 1, 1, 1, 1);
        y += 50;
        float frac = (float)(t - s->t0) / (float)(s->t1 - s->t0 > 0 ? s->t1 - s->t0 : 1);
        rect(28, y, VW - 28, y + 6, 1, 1, 1, 0.16f);
        rect(28, y, 28 + (VW - 56) * frac, y + 6, CORAL, 0.95f);
        y += 22;
        if (nxt >= 0) {
            Show *n = &shows[nxt];
            w = text(sm, 28, y + 4, "NEXT", 100, 1.0f, 0.62f, 0.62f, 0.9f);
            hm(n->t0, buf, sizeof buf, 1);
            snprintf(line, sizeof line, "%s   %s", buf, n->title);
            text(med, 28 + w + 14, y, line, VW - 56 - w - 14, 0.88f, 0.86f, 0.96f, 0.9f);
        }
    } else if (nshows == 0) {
        text(med, 28, y + 6, "No guide information for this channel", VW - 56, 0.8f, 0.76f, 0.95f, 0.6f);
    }
    if (now() < hint_until)
        text_center(sm, VW / 2, VH - 40, "STICK UP/DOWN  channel     LEFT/RIGHT  size     LOWER  info     2P  guide",
                    0.92f, 0.9f, 1, 0.85f);
    glDisable_(GL_BLEND);
}

/* The ambient backdrop, refreshed from the decoded picture by the CPU: 2 x 2 points of each of 36 x 48 cells of
   the picture zoomed to cover the screen (NV12 -> RGB, BT.709), each refresh blended over the last at 35 % so it
   does not flicker. The GPU route (the picture drawn into small textures and blurred) cost 10 ms a frame on the
   single Mali-400 core and half a 720p60 channel's frames (2026-11-01); this is ~7000 reads every 4th frame. */
static void ambient_update(MppFrame f, double dar)
{
    MppBuffer b = mpp_frame_get_buffer(f);
    const unsigned char *Y = b ? mpp_buffer_get_ptr(b) : NULL;
    if (!Y) return;
    int w = mpp_frame_get_width(f), h = mpp_frame_get_height(f);
    int hs = mpp_frame_get_hor_stride(f), vs = mpp_frame_get_ver_stride(f);
    const unsigned char *UV = Y + (size_t)hs * vs;
    double c = (double)VW / VH / dar / 1.12, tv = 1 / 1.12;   /* cover the screen, 12 % closer */
    if (c > 1) c = 1;
    double x0 = w * (0.5 - c / 2), cw = w * c / AW_, y0 = h * (0.5 - tv / 2), ch = h * tv / AH_;
    float k = amb_have ? 0.35f : 1;
    for (int gy = 0; gy < AH_; gy++)
        for (int gx = 0; gx < AW_; gx++) {
            float r = 0, g = 0, bl = 0;
            for (int sy = 0; sy < 2; sy++)
                for (int sx = 0; sx < 2; sx++) {
                    int x = (int)(x0 + cw * (gx + 0.25 + 0.5 * sx)), y = (int)(y0 + ch * (gy + 0.25 + 0.5 * sy));
                    if (x >= w) x = w - 1;
                    if (y >= h) y = h - 1;
                    float yy = 1.164f * (Y[(size_t)y * hs + x] - 16);
                    const unsigned char *uv = UV + (size_t)(y / 2) * hs + (x & ~1);
                    float u = uv[0] - 128.0f, v = uv[1] - 128.0f;
                    r += yy + 1.793f * v;
                    g += yy - 0.213f * u - 0.533f * v;
                    bl += yy + 2.112f * u;
                }
            float *a = amb_acc[gy][gx];
            a[0] += k * (r / 4 - a[0]);
            a[1] += k * (g / 4 - a[1]);
            a[2] += k * (bl / 4 - a[2]);
        }
    /* Blurred before it is stretched: the GPU's bilinear stretch of 36 x 48 cells over 768 x 1024 left each cell's
       edges visible, a grid of soft rectangles behind the bands (2026-11-25, on the cabinet's screen). Three passes
       of [1 2 1] each way (~a Gaussian of 1.2 cells) here cost ~0.2 ms; the same on the GPU cost frames. */
    static float t1[AH_][AW_][3], t2[AH_][AW_][3];
    memcpy(t1, amb_acc, sizeof t1);
    for (int pass = 0; pass < 3; pass++) {
        for (int y = 0; y < AH_; y++)
            for (int x = 0; x < AW_; x++) {
                int xl = x > 0 ? x - 1 : x, xr = x < AW_ - 1 ? x + 1 : x;
                for (int i = 0; i < 3; i++) t2[y][x][i] = (t1[y][xl][i] + 2 * t1[y][x][i] + t1[y][xr][i]) * 0.25f;
            }
        for (int y = 0; y < AH_; y++)
            for (int x = 0; x < AW_; x++) {
                int yu = y > 0 ? y - 1 : y, yd = y < AH_ - 1 ? y + 1 : y;
                for (int i = 0; i < 3; i++) t1[y][x][i] = (t2[yu][x][i] + 2 * t2[y][x][i] + t2[yd][x][i]) * 0.25f;
            }
    }
    for (int y = 0; y < AH_; y++)
        for (int x = 0; x < AW_; x++) {
            for (int i = 0; i < 3; i++) {
                float v = t1[y][x][i];
                amb_px[y][x][i] = v < 0 ? 0 : v > 255 ? 255 : (unsigned char)(v + 0.5f);
            }
            amb_px[y][x][3] = 255;
        }
    bind2d(amb);
    glActiveTexture_(GL_TEXTURE1);
    glTexSubImage2D_(GL_TEXTURE_2D, 0, 0, 0, AW_, AH_, GL_RGBA, GL_UNSIGNED_BYTE, amb_px);
    glActiveTexture_(GL_TEXTURE0);
    amb_have = 1;
}

/* Only the bands, one bilinear tap a pixel: the GPU is a single Mali-400 core, and the whole screen with four
   taps cost a 720p60 channel half its frames (2026-11-01: 25 shown a second of 60). */
static void ambient_draw(float y0, float ph)
{
    if (!amb_have || plain) return;
    bind2d(amb);
    use(&P_TEX, 0.42f, 0.40f, 0.46f, 1);
    quad(0, 0, VW, y0, 0, 0, 1, y0 / VH);
    quad(0, y0 + ph, VW, VH, 0, (y0 + ph) / VH, 1, 1);
}

static long frames_drawn;

static void view_first_picture(void)
{
    if (hint_until > 0) hint_until = now() + 7;
}

static void draw(MppFrame f, double sar)
{
    int vw = mpp_frame_get_width(f), vh = mpp_frame_get_height(f);
    double dar = (double)vw * (sar > 0 ? sar : 1) / vh;
    float ph = picture_height(dar);
    double crop = (double)VW / ph / dar;           /* the share of the picture's width shown */
    if (crop > 1) crop = 1;
    GLuint tex = texture_for(f);
    if (tex && !plain && frames_drawn++ % 4 == 0) ambient_update(f, dar);
    float y0 = (VH - ph) / 2;
    target_screen();
    glClearColor_(0, 0, 0, 1);
    glClear_(GL_COLOR_BUFFER_BIT);
    ambient_draw(y0, ph);
    if (tex) {
        /* A soft edge: the backdrop darkened a little more right along the picture. */
        if (!plain) {
            glEnable_(GL_BLEND);
            rect(0, y0 - 10, VW, y0, 0, 0, 0, 0.35f);
            rect(0, y0 + ph, VW, y0 + ph + 10, 0, 0, 0, 0.35f);
            glDisable_(GL_BLEND);
        }
        glActiveTexture_(GL_TEXTURE0);
        glBindTexture_(GL_TEXTURE_EXTERNAL_OES, tex);
        use(&P_VID, 1, 1, 1, 1);
        quad(0, y0, VW, y0 + ph, (float)(0.5 - crop / 2), 0, (float)(0.5 + crop / 2), 1);
    }
    if (view_info && !plain) draw_bands(ph);
    SDL_GL_SwapWindow(win);
}

/* Before the first picture: the bands around "TUNING IN..." (or what), on Home's colours; after a channel, over
   that channel's colours, dimmed, so changing channel stays in the same room. */
static void draw_tuning(double since, const char *what)
{
    float ph = picture_height(16.0 / 9);
    float y0 = (VH - ph) / 2;
    target_screen();
    glClearColor_(0.055f, 0.02f, 0.10f, 1);
    glClear_(GL_COLOR_BUFFER_BIT);
    if (amb_have && !plain) {
        bind2d(amb);
        use(&P_TEX, 0.30f, 0.28f, 0.34f, 1);
        quad(0, 0, VW, VH, 0, 0, 1, 1);
    }
    glEnable_(GL_BLEND);
    rect(0, y0, VW, y0 + ph, 0, 0, 0, 0.45f);
    rect(0, y0, VW, y0 + 2, CORAL, 0.5f);
    rect(0, y0 + ph - 2, VW, y0 + ph, CORAL, 0.5f);
    float pulse = 0.6f + 0.4f * (float)(0.5 + 0.5 * sin(since * 5));
    Font *mid = font(34);
    text_center(mid, VW / 2, y0 + ph / 2 - 24, what && *what ? what : "TUNING IN\xe2\x80\xa6", CORAL, pulse);
    glDisable_(GL_BLEND);
    draw_bands(ph);
    SDL_GL_SwapWindow(win);
}

/* The view's buttons: 1 when the picture should be drawn again. */
static int view_button(int b)
{
    if (b == B_LEFT || b == B_RIGHT) { view_fill = !view_fill; view_save(); return 1; }
    if (b == B_LOW) { view_info = !view_info; view_save(); return 1; }
    return 0;
}
