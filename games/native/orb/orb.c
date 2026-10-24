/* Orb: dive the glowing well. OpenGL ES 2, the API the Mali-400 runs.
 * Two-verb band (CONTROLS.md): the stick steers the orb, LOW dives (and dives again),
 * and holding LOW (or TL) while diving is a boost: faster, and every point counts double.
 *
 * Upright 384x512, the panel scaled by exactly 2. The title is a lit orb turning over a
 * grid; the stick yaws it. The well is a short tube the CPU slides toward the camera and
 * recycles, with one 128x128 generated texture whose alpha marks the glowing seams.
 * Gates pinch one side of the tube, or stand a pillar in the middle. Wisps are points.
 * The HUD is drawn in software (gfx) at 192x256 and laid over the frame as one texture.
 *
 * Shaders stay short and mediump: one texture fetch, a mix for fog, no loops, no discard.
 * orb.sav is "best N". A card (or CAB_EXT) file "label" is copied to "orb-card".
 */
#include "gfx.h"
#include "sfx.h"

#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#define W 384
#define H 512
#define HUD_W 192
#define HUD_H 256

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef ptrdiff_t GLsizeiptr;
typedef unsigned char GLboolean;

#define GL_DEPTH_TEST 0x0B71
#define GL_BLEND 0x0BE2
#define GL_DEPTH_BUFFER_BIT 0x00000100
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_TRIANGLES 0x0004
#define GL_FLOAT 0x1406
#define GL_ARRAY_BUFFER 0x8892
#define GL_STATIC_DRAW 0x88E4
#define GL_DYNAMIC_DRAW 0x88E8
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_TEXTURE_2D 0x0DE1
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_LINEAR 0x2601
#define GL_NEAREST 0x2600
#define GL_REPEAT 0x2901
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_SRC_ALPHA 0x0302
#define GL_ONE_MINUS_SRC_ALPHA 0x0303
#define GL_ONE 1

static void (*glEnable)(GLenum);
static void (*glDisable)(GLenum);
static void (*glClearColor)(float, float, float, float);
static void (*glClear)(unsigned);
static void (*glGenBuffers)(GLsizei, GLuint *);
static void (*glBindBuffer)(GLenum, GLuint);
static void (*glBufferData)(GLenum, GLsizeiptr, const void *, GLenum);
static void (*glEnableVertexAttribArray)(GLuint);
static void (*glDisableVertexAttribArray)(GLuint);
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
static void (*glGetProgramInfoLog)(GLuint, GLsizei, GLsizei *, char *);
static GLint (*glGetUniformLocation)(GLuint, const char *);
static void (*glUniformMatrix4fv)(GLint, GLsizei, GLboolean, const float *);
static void (*glUniform3f)(GLint, float, float, float);
static void (*glUniform1f)(GLint, float);
static void (*glUniform1i)(GLint, GLint);
static void (*glGenTextures)(GLsizei, GLuint *);
static void (*glBindTexture)(GLenum, GLuint);
static void (*glTexImage2D)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
static void (*glTexParameteri)(GLenum, GLenum, GLint);
static void (*glBlendFunc)(GLenum, GLenum);
static void (*glDepthMask)(GLboolean);

static int load(void)
{
#define LOAD(n)                                                      \
    do {                                                             \
        void *s = cab_gl_proc(#n);                                   \
        if (!s) {                                                    \
            cab_log("orb missing %s", #n);                           \
            return -1;                                               \
        }                                                            \
        memcpy(&n, &s, sizeof n);                                    \
    } while (0)
    LOAD(glEnable);
    LOAD(glDisable);
    LOAD(glClearColor);
    LOAD(glClear);
    LOAD(glGenBuffers);
    LOAD(glBindBuffer);
    LOAD(glBufferData);
    LOAD(glEnableVertexAttribArray);
    LOAD(glDisableVertexAttribArray);
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
    LOAD(glGetProgramInfoLog);
    LOAD(glGetUniformLocation);
    LOAD(glUniformMatrix4fv);
    LOAD(glUniform3f);
    LOAD(glUniform1f);
    LOAD(glUniform1i);
    LOAD(glGenTextures);
    LOAD(glBindTexture);
    LOAD(glTexImage2D);
    LOAD(glTexParameteri);
    LOAD(glBlendFunc);
    LOAD(glDepthMask);
#undef LOAD
    return 0;
}

/* ------------------------------------------------------------------ matrices */

static void ident(float *m)
{
    memset(m, 0, 16 * sizeof(float));
    m[0] = m[5] = m[10] = m[15] = 1;
}

static void mul(float *o, const float *a, const float *b)
{
    float r[16];
    for (int c = 0; c < 4; c++)
        for (int row = 0; row < 4; row++)
            r[c * 4 + row] = a[row] * b[c * 4] + a[4 + row] * b[c * 4 + 1] + a[8 + row] * b[c * 4 + 2] +
                             a[12 + row] * b[c * 4 + 3];
    memcpy(o, r, sizeof r);
}

static void perspective(float *m, float fovy, float aspect, float n, float f)
{
    float t = 1.f / tanf(fovy * 0.5f);
    memset(m, 0, 16 * sizeof(float));
    m[0] = t / aspect;
    m[5] = t;
    m[10] = (f + n) / (n - f);
    m[11] = -1;
    m[14] = (2 * f * n) / (n - f);
}

static void translate(float *m, float x, float y, float z)
{
    ident(m);
    m[12] = x;
    m[13] = y;
    m[14] = z;
}

static void rotate_y(float *m, float a)
{
    ident(m);
    m[0] = cosf(a);
    m[2] = -sinf(a);
    m[8] = sinf(a);
    m[10] = cosf(a);
}

static void rotate_x(float *m, float a)
{
    ident(m);
    m[5] = cosf(a);
    m[6] = sinf(a);
    m[9] = -sinf(a);
    m[10] = cosf(a);
}

static void rotate_z(float *m, float a)
{
    ident(m);
    m[0] = cosf(a);
    m[1] = sinf(a);
    m[4] = -sinf(a);
    m[5] = cosf(a);
}

/* ------------------------------------------------------------------ shaders */

static GLuint build(const char *vs, const char *fs, const char *const *attrs, int nattr, const char *name)
{
    GLuint v = glCreateShader(GL_VERTEX_SHADER), f = glCreateShader(GL_FRAGMENT_SHADER), p = glCreateProgram();
    GLint ok = 0;
    char log[512];
    glShaderSource(v, 1, &vs, NULL);
    glCompileShader(v);
    glGetShaderiv(v, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(v, sizeof log, NULL, log);
        cab_log("orb %s vs: %s", name, log);
        return 0;
    }
    glShaderSource(f, 1, &fs, NULL);
    glCompileShader(f);
    glGetShaderiv(f, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(f, sizeof log, NULL, log);
        cab_log("orb %s fs: %s", name, log);
        return 0;
    }
    for (int i = 0; i < nattr; i++)
        glBindAttribLocation(p, (GLuint)i, attrs[i]);
    glAttachShader(p, v);
    glAttachShader(p, f);
    glLinkProgram(p);
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        glGetProgramInfoLog(p, sizeof log, NULL, log);
        cab_log("orb %s link: %s", name, log);
        return 0;
    }
    return p;
}

/* Lit: the title orb and its floor. Lambert, a rim light, and glowing bands on the orb. */
static const char *lit_vs =
    "attribute vec3 a_pos;\n"
    "attribute vec3 a_nrm;\n"
    "attribute vec3 a_col;\n"
    "uniform mat4 u_mvp;\n"
    "uniform mat4 u_rot;\n"
    "varying vec3 v_nrm;\n"
    "varying vec3 v_col;\n"
    "varying float v_band;\n"
    "void main() {\n"
    "  gl_Position = u_mvp * vec4(a_pos, 1.0);\n"
    "  v_nrm = (u_rot * vec4(a_nrm, 0.0)).xyz;\n"
    "  v_col = a_col;\n"
    "  v_band = a_pos.y;\n"
    "}\n";
static const char *lit_fs =
    "precision mediump float;\n"
    "varying vec3 v_nrm;\n"
    "varying vec3 v_col;\n"
    "varying float v_band;\n"
    "uniform vec3 u_light;\n"
    "uniform vec3 u_glow;\n"
    "uniform float u_time;\n"
    "void main() {\n"
    "  vec3 n = normalize(v_nrm);\n"
    "  float d = max(dot(n, u_light), 0.0);\n"
    "  float rim = 1.0 - abs(n.z);\n"
    "  float band = max(0.0, 1.0 - abs(fract(v_band * 2.5 - u_time) - 0.5) * 8.0);\n"
    "  vec3 c = v_col * (0.25 + 0.75 * d) + u_glow * (rim * rim * 0.9 + band * 0.6);\n"
    "  gl_FragColor = vec4(c, 1.0);\n"
    "}\n";

/* The well: texture times vertex color, the texture's alpha is the glowing seam, then fog. */
static const char *well_vs =
    "attribute vec3 a_pos;\n"
    "attribute vec2 a_uv;\n"
    "attribute vec3 a_col;\n"
    "uniform mat4 u_mvp;\n"
    "varying vec2 v_uv;\n"
    "varying vec3 v_col;\n"
    "varying float v_fog;\n"
    "void main() {\n"
    "  gl_Position = u_mvp * vec4(a_pos, 1.0);\n"
    "  v_uv = a_uv;\n"
    "  v_col = a_col;\n"
    "  v_fog = clamp((-a_pos.z - 5.0) / 26.0, 0.0, 1.0);\n"
    "}\n";
static const char *well_fs =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "varying vec3 v_col;\n"
    "varying float v_fog;\n"
    "uniform sampler2D u_tex;\n"
    "uniform vec3 u_fogc;\n"
    "uniform vec3 u_glow;\n"
    "uniform vec3 u_hit;\n"
    "void main() {\n"
    "  vec4 t = texture2D(u_tex, v_uv);\n"
    "  vec3 rgb = t.rgb * v_col + u_glow * t.a;\n"
    "  rgb = mix(rgb, u_fogc, v_fog);\n"
    "  gl_FragColor = vec4(rgb + u_hit, 1.0);\n"
    "}\n";

/* Glow: additive soft dots for the orb, wisps, and sparks. uv runs -1..1 across the quad. */
static const char *glow_vs =
    "attribute vec3 a_pos;\n"
    "attribute vec2 a_uv;\n"
    "attribute vec3 a_col;\n"
    "uniform mat4 u_mvp;\n"
    "varying vec2 v_uv;\n"
    "varying vec3 v_col;\n"
    "void main() {\n"
    "  gl_Position = u_mvp * vec4(a_pos, 1.0);\n"
    "  v_uv = a_uv;\n"
    "  v_col = a_col;\n"
    "}\n";
static const char *glow_fs =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "varying vec3 v_col;\n"
    "void main() {\n"
    "  float a = max(0.0, 1.0 - dot(v_uv, v_uv));\n"
    "  gl_FragColor = vec4(v_col * a * a, 1.0);\n"
    "}\n";

/* HUD: the gfx surface is ARGB in memory, which reads back as BGRA. */
static const char *hud_vs =
    "attribute vec3 a_pos;\n"
    "attribute vec2 a_uv;\n"
    "varying vec2 v_uv;\n"
    "void main() {\n"
    "  gl_Position = vec4(a_pos, 1.0);\n"
    "  v_uv = a_uv;\n"
    "}\n";
static const char *hud_fs =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "uniform sampler2D u_tex;\n"
    "void main() { gl_FragColor = texture2D(u_tex, v_uv).bgra; }\n";

/* ------------------------------------------------------------------ meshes */

/* 8 floats: pos3, uv2 (or normal xy for lit), col3. The lit mesh uses 9: pos3 nrm3 col3. */
#define VMAX 6000
static float vbuf[VMAX * 8];
static int vn;

static void v8(float x, float y, float z, float u, float v, float r, float g, float b)
{
    float *o;
    if (vn >= VMAX)
        return;
    o = vbuf + vn * 8;
    o[0] = x, o[1] = y, o[2] = z, o[3] = u, o[4] = v, o[5] = r, o[6] = g, o[7] = b;
    vn++;
}

static void quad8(const float a[3], const float b[3], const float c[3], const float d[3], float u0, float v0, float u1,
                  float v1, float r, float g, float bl)
{
    v8(a[0], a[1], a[2], u0, v0, r, g, bl);
    v8(b[0], b[1], b[2], u1, v0, r, g, bl);
    v8(c[0], c[1], c[2], u1, v1, r, g, bl);
    v8(a[0], a[1], a[2], u0, v0, r, g, bl);
    v8(c[0], c[1], c[2], u1, v1, r, g, bl);
    v8(d[0], d[1], d[2], u0, v1, r, g, bl);
}

/* A camera-facing square in view space (the well's camera never turns). */
static void dot8(float x, float y, float z, float s, float r, float g, float b)
{
    float a[3] = {x - s, y - s, z}, bb[3] = {x + s, y - s, z}, c[3] = {x + s, y + s, z}, d[3] = {x - s, y + s, z};
    quad8(a, bb, c, d, -1, -1, 1, 1, r, g, b);
}

static float lit_v[9 * 4000];
static int lit_n, orb_first, orb_count;

static void lv(float x, float y, float z, float nx, float ny, float nz, float r, float g, float b)
{
    float *o = lit_v + lit_n * 9;
    o[0] = x, o[1] = y, o[2] = z, o[3] = nx, o[4] = ny, o[5] = nz, o[6] = r, o[7] = g, o[8] = b;
    lit_n++;
}

static void build_title(void)
{
    const int seg = 24, ring = 14;
    const float rad = 0.5f;
    lit_n = 0;
    /* A floor of tiles, fading out at the edges. */
    for (int iz = 0; iz < 8; iz++)
        for (int ix = 0; ix < 8; ix++) {
            float x0 = -2.f + ix * 0.5f, x1 = x0 + 0.5f, z0 = -2.f + iz * 0.5f, z1 = z0 + 0.5f, y = -0.78f;
            float fade = 1.f - (fabsf(x0 + 0.25f) + fabsf(z0 + 0.25f)) / 3.f;
            float k = ((ix + iz) & 1) ? 0.10f : 0.18f;
            float r = k * fade, g = k * 1.1f * fade, b = (k * 2.f + 0.04f) * fade;
            if (fade < 0)
                r = g = b = 0;
            lv(x0, y, z0, 0, 1, 0, r, g, b);
            lv(x1, y, z0, 0, 1, 0, r, g, b);
            lv(x1, y, z1, 0, 1, 0, r, g, b);
            lv(x0, y, z0, 0, 1, 0, r, g, b);
            lv(x1, y, z1, 0, 1, 0, r, g, b);
            lv(x0, y, z1, 0, 1, 0, r, g, b);
        }
    orb_first = lit_n;
    for (int j = 0; j < ring; j++) {
        float t0 = (float)j / ring * 3.14159f, t1 = (float)(j + 1) / ring * 3.14159f;
        for (int i = 0; i < seg; i++) {
            float p0 = (float)i / seg * 6.28318f, p1 = (float)(i + 1) / seg * 6.28318f;
            float q[4][3] = {{sinf(t0) * cosf(p0), cosf(t0), sinf(t0) * sinf(p0)},
                             {sinf(t0) * cosf(p1), cosf(t0), sinf(t0) * sinf(p1)},
                             {sinf(t1) * cosf(p1), cosf(t1), sinf(t1) * sinf(p1)},
                             {sinf(t1) * cosf(p0), cosf(t1), sinf(t1) * sinf(p0)}};
            const int ord[6] = {0, 1, 2, 0, 2, 3};
            float cr = 0.42f + 0.12f * cosf(t0 * 2), cg = 0.30f, cb = 0.95f;
            for (int k = 0; k < 6; k++) {
                const float *v = q[ord[k]];
                lv(v[0] * rad, v[1] * rad, v[2] * rad, v[0], v[1], v[2], cr, cg, cb);
            }
        }
    }
    orb_count = lit_n - orb_first;
}

/* ------------------------------------------------------------------ the well */

#define WELL_SIDES 12
#define WELL_RINGS 18
#define WELL_STEP 2.2f
#define GATE 8.f
#define NEAR_Z -0.55f

static int fast, autoplay, demo;

static Uint32 hash(Uint32 x)
{
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

static Uint32 run_seed = 1;

/* Gate kind for segment seg: 0 none, 1 right, 2 up, 3 left, 4 down, 5 pillar, 6 a ring (only the middle is open). */
static int gate_kind(int seg)
{
    Uint32 h;
    if (seg <= 0)
        return 0;
    if (seg <= 4)
        return seg; /* the first four teach the four sides */
    h = hash((Uint32)seg * 2654435761u ^ run_seed);
    if (seg < 10)
        return 1 + (int)(h % 5);
    return 1 + (int)(h % 6);
}

static int gate_blocks(int seg, float x, float y)
{
    switch (gate_kind(seg)) {
    case 1: return x > 0.5f;
    case 2: return y > 0.5f;
    case 3: return x < -0.5f;
    case 4: return y < -0.5f;
    case 5: return x * x + y * y < 0.32f * 0.32f;
    case 6: return x * x + y * y > 0.42f * 0.42f;
    default: return 0;
    }
}

static float wall_rad(int kind, float c, float s)
{
    float pinch = 0;
    if (kind == 6)
        return 0.62f;
    if (kind == 1)
        pinch = c;
    else if (kind == 3)
        pinch = -c;
    else if (kind == 2)
        pinch = s;
    else if (kind == 4)
        pinch = -s;
    if (pinch < 0.15f)
        return 1.15f;
    pinch = clampf((pinch - 0.15f) / 0.85f, 0, 1);
    return 1.15f + (0.5f - 1.15f) * pinch;
}

static float cap_z(float z) { return z > NEAR_Z ? NEAR_Z : z; }

static void build_well(float travel)
{
    float scroll = fmodf(travel, WELL_STEP);
    if (scroll < 0)
        scroll += WELL_STEP;
    for (int i = 0; i < WELL_RINGS; i++) {
        float z1 = -0.9f - (float)i * WELL_STEP + scroll, z0 = z1 - WELL_STEP;
        float d0 = travel - z0, d1 = travel - z1;
        int s0 = (int)(d0 / GATE), s1 = (int)(d1 / GATE);
        /* A ring is a gate when its depth sits in the last 1.5 units before a gate line. */
        int k0 = fmodf(d0, GATE) > GATE - 1.6f ? gate_kind(s0 + 1) : 0;
        int k1 = fmodf(d1, GATE) > GATE - 1.6f ? gate_kind(s1 + 1) : 0;
        float shade = clampf(0.7f + 0.5f * (1.f + z1 / 26.f), 0.5f, 1.2f);
        if (z0 > NEAR_Z)
            continue;
        z1 = cap_z(z1);
        z0 = cap_z(z0);
        for (int s = 0; s < WELL_SIDES; s++) {
            float a0 = (float)s / WELL_SIDES * 6.2831853f + 0.2618f, a1 = (float)(s + 1) / WELL_SIDES * 6.2831853f + 0.2618f;
            float c0 = cosf(a0), sn0 = sinf(a0), c1 = cosf(a1), sn1 = sinf(a1);
            float r0 = wall_rad(k0, c0, sn0), r1 = wall_rad(k0, c1, sn1), r2 = wall_rad(k1, c1, sn1), r3 = wall_rad(k1, c0, sn0);
            float q0[3] = {c0 * r0, sn0 * r0, z0}, q1[3] = {c1 * r1, sn1 * r1, z0};
            float q2[3] = {c1 * r2, sn1 * r2, z1}, q3[3] = {c0 * r3, sn0 * r3, z1};
            float inset = (r0 + r1 + r2 + r3) * 0.25f;
            float warn = inset < 1.1f ? clampf((1.15f - inset) * 2.2f, 0, 1) : 0;
            float r = shade * (1 + warn * 1.6f), g = shade * (1 - warn * 0.4f), b = shade * (1 - warn * 0.7f);
            quad8(q0, q1, q2, q3, (float)s / 3.f, d0 * 0.12f, (float)(s + 1) / 3.f, d1 * 0.12f, r, g, b);
        }
    }
    /* Pillars stand in the middle of kind-5 gates. */
    for (int ahead = 0; ahead <= 4; ahead++) {
        int seg = (int)(travel / GATE) + ahead;
        float gz = -(seg * GATE - travel), h = 0.3f, z0, z1;
        if (gate_kind(seg) != 5)
            continue;
        z0 = gz - 1.2f;
        z1 = gz + 0.1f;
        if (z1 > NEAR_Z || z0 < -40.f)
            continue;
        {
            float a[4][3] = {{-h, -h, z0}, {h, -h, z0}, {h, h, z0}, {-h, h, z0}};
            float b[4][3] = {{-h, -h, z1}, {h, -h, z1}, {h, h, z1}, {-h, h, z1}};
            for (int k = 0; k < 4; k++)
                quad8(a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k], 0.1f, 0.1f, 0.3f, 0.3f, 2.2f, 0.9f, 0.5f);
            quad8(b[0], b[1], b[2], b[3], 0.1f, 0.1f, 0.3f, 0.3f, 2.4f, 1.1f, 0.6f);
        }
    }
}

static void make_panels(unsigned char *px)
{
    for (int y = 0; y < 128; y++)
        for (int x = 0; x < 128; x++) {
            int lx = x & 31, ly = y & 31;
            int seam = lx < 2 || ly < 2;
            int bevel = lx < 4 || ly < 4 || lx > 29 || ly > 29;
            int light = (lx > 13 && lx < 18 && ly > 13 && ly < 18) && (((x >> 5) + (y >> 5)) & 1);
            int n = ((x * 7 + y * 13) ^ (x >> 3) ^ (y << 1)) & 15;
            unsigned char *p = px + (y * 128 + x) * 4;
            int r = 26 + n, g = 22 + n, b = 54 + n * 2;
            if (bevel) {
                r += 18;
                g += 16;
                b += 30;
            }
            p[0] = (unsigned char)r;
            p[1] = (unsigned char)g;
            p[2] = (unsigned char)b;
            p[3] = seam ? 255 : light ? 200 : 0;
        }
}

/* ------------------------------------------------------------------ game state */

enum { S_TITLE, S_DIVE, S_CRASH };
static int state, best, saved_best, score, wisps, combo, frame, crash_t, idle_t, boosting, new_best;
static float travel, px, py, vx, vy, speed, yaw, roll, boost_vis, flash;
static float wisp_d[4], wisp_x[4], wisp_y[4];
static int wisp_on[4];
static float trail[12][2];

static const sfx_song tune = {
    124, 4, 4,
    {
        {"A4 . C5 . E5 . A5 . G5 . E5 . C5 . D5 . F4 . A4 . D5 . F5 . E5 . D5 . A4 . B4 . ", W_SAW, 0.05f, 0.08f, 0.004f, 0, 0, -0.25f},
        {"A2 . A2 A3 A2 . A2 A3 F2 . F2 F3 F2 . F2 F3 D2 . D2 D3 D2 . D2 D3 E2 . E2 E3 E2 . E2 E3 ", W_SQUARE, 0.12f, 0.05f, 0.003f, 0, 0.3f, 0},
        {"K . H . S . H . K K H . S . H H ", W_NOISE, 0.10f, 0.04f, 0, 0, 0, 0.2f},
        {"E5 - - - - - - - C5 - - - - - - - A4 - - - - - - - B4 - - - - - - - ", W_TRI, 0.05f, 0.4f, 0.2f, 12, 0, 0.3f},
    }};
static const sfx_song idle_tune = {
    70, 2, 2,
    {
        {"A4 - E5 - C5 - B4 - A4 - E5 - D5 - C5 - ", W_SINE, 0.10f, 0.6f, 0.1f, 0, 0, -0.2f},
        {"A2 - - - - - - - F2 - - - - - - - ", W_TRI, 0.14f, 0.6f, 0.1f, 0, 0, 0.2f},
    }};

static void place_wisp(int i, float d)
{
    float a = rng_range(0, 6.28f), r = rng_range(0, 0.6f);
    int seg = (int)(d / GATE);
    wisp_d[i] = d;
    wisp_x[i] = cosf(a) * r;
    wisp_y[i] = sinf(a) * r;
    /* Keep it out of the next gate's wall so a wisp never baits a crash. */
    for (int k = 0; k < 8 && (gate_blocks(seg + 1, wisp_x[i], wisp_y[i]) || gate_blocks(seg, wisp_x[i], wisp_y[i])); k++) {
        wisp_x[i] *= 0.5f;
        wisp_y[i] *= 0.5f;
        if (gate_kind(seg + 1) == 5 || gate_kind(seg) == 5)
            wisp_x[i] = 0.62f;
    }
    /* A pillar beside a ring leaves no safe spot that fits both; skip this wisp. */
    wisp_on[i] = !gate_blocks(seg + 1, wisp_x[i], wisp_y[i]) && !gate_blocks(seg, wisp_x[i], wisp_y[i]);
}

static void begin_dive(void)
{
    state = S_DIVE;
    travel = 0;
    px = py = vx = vy = 0;
    score = wisps = combo = 0;
    speed = fast ? 0.30f : 0.22f;
    new_best = 0;
    run_seed = rng_u32() | 1;
    for (int i = 0; i < 4; i++)
        place_wisp(i, 6.f + i * 7.f);
    for (int i = 0; i < 12; i++)
        trail[i][0] = trail[i][1] = 0;
    music_play(&tune);
    music_tempo(1.f);
    sfx_slide(W_SINE, 200, 900, 0.5f, 0.35f);
    cab_log("orb dive");
}

static void crash(void)
{
    state = S_CRASH;
    crash_t = 0;
    flash = 1;
    if (score < 1)
        score = 1;
    if (score > best && demo <= 0) {
        best = score;
        new_best = 1;
    }
    if (best > saved_best && demo <= 0) {
        if (cab_score_save("orb", best) == 0)
            saved_best = best;
    }
    music_stop();
    sfx_noise(0.6f, 0.5f, 4000);
    sfx_slide(W_SQUARE, 400, 40, 0.7f, 0.35f);
    cab_log("dive crash %d", score);
}

/* ------------------------------------------------------------------ the built-in pilot */

static void bot(void)
{
    float tx = 0, ty = 0;
    int seg = (int)(travel / GATE) + 1;
    int k = gate_kind(seg);
    cab_bot_clear();
    if (state == S_TITLE) {
        if (frame % 60 == 30)
            cab_bot(CAB_LOW, 1);
        return;
    }
    if (state == S_CRASH) {
        if (crash_t > 50 && crash_t % 30 == 0)
            cab_bot(CAB_LOW, 1);
        return;
    }
    for (int i = 0; i < 4; i++)
        if (wisp_on[i] && wisp_d[i] - travel < 5 && wisp_d[i] > travel) {
            tx = wisp_x[i];
            ty = wisp_y[i];
        }
    if (k == 1)
        tx = fminf(tx, -0.2f);
    else if (k == 3)
        tx = fmaxf(tx, 0.2f);
    else if (k == 2)
        ty = fminf(ty, -0.2f);
    else if (k == 4)
        ty = fmaxf(ty, 0.2f);
    else if (k == 5 && tx * tx + ty * ty < 0.5f * 0.5f) {
        tx = 0.6f;
        ty = 0;
    } else if (k == 6) {
        tx *= 0.3f;
        ty *= 0.3f;
    }
    if (tx < px - 0.04f)
        cab_bot(CAB_LEFT, 1);
    if (tx > px + 0.04f)
        cab_bot(CAB_RIGHT, 1);
    if (ty < py - 0.04f)
        cab_bot(CAB_DOWN, 1);
    if (ty > py + 0.04f)
        cab_bot(CAB_UP, 1);
    if (travel > 40 && (frame / 120) % 3 == 0)
        cab_bot(CAB_TL, 1);
}

/* ------------------------------------------------------------------ HUD */

static gsurf *hud;
static const gcol INK = HEX(0x0a0820), CREAM = HEX(0xfff6ea), GOLD = HEX(0xffd257), CYAN = HEX(0x7fe8ff);

static void draw_hud(void)
{
    gfx_target(hud);
    memset(hud->px, 0, sizeof(Uint32) * HUD_W * HUD_H);
    if (state == S_TITLE) {
        float bob = sinf(frame * 0.05f) * 2;
        gfx_text_c(HUD_W / 2, (int)(14 + bob), 4, HEX(0xc8a8ff), INK, "Orb");
        gfx_text_c(HUD_W / 2, 50, 1, CYAN, INK, "dive the glowing well");
        gfx_text_c(HUD_W / 2, 196, 1, CREAM, INK, "stick steers");
        gfx_text_c(HUD_W / 2, 207, 1, CREAM, INK, "hold button: boost x2");
        if ((frame / 30) % 2)
            gfx_text_c(HUD_W / 2, 222, 1, GOLD, INK, "press to dive");
        if (best > 0)
            gfx_text_c(HUD_W / 2, 64, 1, GOLD, INK, "best %d", best);
        gfx_text_c(HUD_W / 2, HUD_H - 10, 1, HEXA(0x9090c0, 220), INK, "hold 1P+2P to leave");
    } else {
        gfx_text_o(4, 4, 2, CREAM, INK, "%d", score);
        gfx_text_o(4, 22, 1, CYAN, INK, "wisps %d", wisps);
        gfx_text_o(HUD_W - 4 - gfx_text_w(1, "best %d", best), 4, 1, GOLD, INK, "best %d", best);
        if (combo > 1)
            gfx_text_o(HUD_W - 4 - gfx_text_w(1, "chain x%d", combo), 14, 1, CYAN, INK, "chain x%d", combo);
        /* Speed bar along the bottom; it glows while boosting. */
        gfx_rrect(40, HUD_H - 10, HUD_W - 80, 5, 2, HEXA(0x202040, 200));
        gfx_rrect(40, HUD_H - 10, (HUD_W - 80) * clampf((speed - 0.18f) / 0.42f, 0.05f, 1), 5, 2,
                  boosting ? HEX(0xffa040) : CYAN);
        if (boosting)
            gfx_text_c(HUD_W / 2, HUD_H - 22, 1, HEX(0xffc070), INK, "BOOST x2");
        if (demo > 0)
            gfx_text_c(HUD_W / 2, 40, 1, CREAM, INK, "demo - press to play");
        if (state == S_CRASH) {
            float k = ease_out_back(clampf(crash_t / 25.f, 0, 1));
            gfx_rrect(24, 70, HUD_W - 48, 92 * k + 1, 10, HEXA(0x100820, 200));
            if (k > 0.6f) {
                gfx_text_c(HUD_W / 2, 78, 3, HEX(0xff7080), INK, "crash");
                gfx_text_c(HUD_W / 2, 106, 2, CREAM, INK, "%d", score);
                gfx_text_c(HUD_W / 2, 126, 1, GOLD, INK, new_best ? "a new best!" : "best %d", best);
                if (crash_t > 45 && (frame / 30) % 2)
                    gfx_text_c(HUD_W / 2, 144, 1, CREAM, INK, "press to dive again");
            }
        }
    }
    if (cab_quit_progress() > 0) {
        gfx_rrect(30, HUD_H / 2 - 16, HUD_W - 60, 30, 8, HEX(0x281e48));
        gfx_rrect(36, HUD_H / 2 + 4, (HUD_W - 72) * cab_quit_progress(), 5, 2, GOLD);
        gfx_text_c(HUD_W / 2, HUD_H / 2 - 10, 1, CREAM, INK, "leaving...");
    }
    gfx_target(NULL);
}

/* ------------------------------------------------------------------ main */

static void bind8(GLuint buf)
{
    glBindBuffer(GL_ARRAY_BUFFER, buf);
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 8 * sizeof(float), (void *)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 8 * sizeof(float), (void *)(3 * sizeof(float)));
    glVertexAttribPointer(2, 3, GL_FLOAT, 0, 8 * sizeof(float), (void *)(5 * sizeof(float)));
}

static void bind9(GLuint buf)
{
    glBindBuffer(GL_ARRAY_BUFFER, buf);
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)0);
    glVertexAttribPointer(1, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)(3 * sizeof(float)));
    glVertexAttribPointer(2, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)(6 * sizeof(float)));
}

int main(int argc, char **argv)
{
    static unsigned char panels[128 * 128 * 4];
    const char *a_lit[] = {"a_pos", "a_nrm", "a_col"}, *a_uv[] = {"a_pos", "a_uv", "a_col"};
    GLuint p_lit, p_well, p_glow, p_hud, tex_panel, tex_hud, b_lit, b_dyn, b_hud;
    GLint lu_mvp, lu_rot, lu_light, lu_glow, lu_time, wu_mvp, wu_fog, wu_glow, wu_hit, wu_tex, gu_mvp, hu_tex;
    char label[64];
    fast = cab_fast(argc, argv);
    autoplay = getenv("CAB_AUTOPLAY") != NULL;
    if (cab_gl_init("Orb", W, H) != 0)
        return 1;
    if (load() != 0)
        return 1;
    sfx_init();
    sfx_master(0.4f);
    rng_seed_auto();
    if (cab_ext_read("label", label, sizeof label) > 0)
        cab_ext_write("orb-card", label, (int)strlen(label));
    best = saved_best = cab_score_load("orb");
    hud = gfx_surf_new(HUD_W, HUD_H);
    p_lit = build(lit_vs, lit_fs, a_lit, 3, "lit");
    p_well = build(well_vs, well_fs, a_uv, 3, "well");
    p_glow = build(glow_vs, glow_fs, a_uv, 3, "glow");
    p_hud = build(hud_vs, hud_fs, a_uv, 2, "hud");
    if (!p_lit || !p_well || !p_glow || !p_hud || !hud)
        return 1;
    lu_mvp = glGetUniformLocation(p_lit, "u_mvp");
    lu_rot = glGetUniformLocation(p_lit, "u_rot");
    lu_light = glGetUniformLocation(p_lit, "u_light");
    lu_glow = glGetUniformLocation(p_lit, "u_glow");
    lu_time = glGetUniformLocation(p_lit, "u_time");
    wu_mvp = glGetUniformLocation(p_well, "u_mvp");
    wu_fog = glGetUniformLocation(p_well, "u_fogc");
    wu_glow = glGetUniformLocation(p_well, "u_glow");
    wu_hit = glGetUniformLocation(p_well, "u_hit");
    wu_tex = glGetUniformLocation(p_well, "u_tex");
    gu_mvp = glGetUniformLocation(p_glow, "u_mvp");
    hu_tex = glGetUniformLocation(p_hud, "u_tex");
    build_title();
    glGenBuffers(1, &b_lit);
    glBindBuffer(GL_ARRAY_BUFFER, b_lit);
    glBufferData(GL_ARRAY_BUFFER, lit_n * 9 * sizeof(float), lit_v, GL_STATIC_DRAW);
    glGenBuffers(1, &b_dyn);
    glGenBuffers(1, &b_hud);
    {
        float q[] = {-1, -1, 0, 0, 1, 0, 0, 0, 1, -1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0,
                     -1, -1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, -1, 1, 0, 0, 0, 0, 0, 0};
        glBindBuffer(GL_ARRAY_BUFFER, b_hud);
        glBufferData(GL_ARRAY_BUFFER, sizeof q, q, GL_STATIC_DRAW);
    }
    make_panels(panels);
    glGenTextures(1, &tex_panel);
    glBindTexture(GL_TEXTURE_2D, tex_panel);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 128, 128, 0, GL_RGBA, GL_UNSIGNED_BYTE, panels);
    glGenTextures(1, &tex_hud);
    glBindTexture(GL_TEXTURE_2D, tex_hud);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);
    cab_log("orb triangles %d", lit_n / 3);
    cab_log("orb well ready");
    state = S_TITLE;
    music_play(&idle_tune);
    if (autoplay)
        demo = -1;
    while (cab_poll()) {
        float proj[16], m1[16], m2[16], mvp[16], rot[16];
        int any = cab_human_any();
        int press = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        if (demo > 0 && any) {
            demo = 0;
            cab_bot_clear();
            state = S_TITLE;
            idle_t = 0;
            music_play(&idle_tune);
            press = 0;
        }
        if (demo)
            bot();
        /* ---------------- update */
        if (state == S_TITLE) {
            idle_t = any ? 0 : idle_t + 1;
            if (cab_down(0, CAB_LEFT))
                yaw -= 0.04f;
            if (cab_down(0, CAB_RIGHT))
                yaw += 0.04f;
            if (press)
                begin_dive();
            else if (idle_t > 600 && !demo) {
                demo = 1;
                cab_log("orb demo");
                begin_dive();
            }
        } else if (state == S_DIVE) {
            float accel = 0.012f, maxv = 0.06f, top;
            int dx = cab_down(0, CAB_RIGHT) - cab_down(0, CAB_LEFT), dy = cab_down(0, CAB_UP) - cab_down(0, CAB_DOWN);
            boosting = cab_down(0, CAB_LOW) || cab_down(0, CAB_TL);
            if (fast)
                maxv *= 1.4f;
            vx = dx ? clampf(vx + dx * accel, -maxv, maxv) : vx * 0.8f;
            vy = dy ? clampf(vy + dy * accel, -maxv, maxv) : vy * 0.8f;
            px = clampf(px + vx, -0.82f, 0.82f);
            py = clampf(py + vy, -0.82f, 0.82f);
            top = (fast ? 0.30f : 0.22f) + travel * 0.0009f;
            if (top > 0.5f)
                top = 0.5f;
            speed = approach(speed, boosting ? top * 1.6f : top, 0.05f);
            boost_vis = approach(boost_vis, boosting ? 1.f : 0.f, 0.1f);
            music_tempo(1.f + boost_vis * 0.25f);
            {
                int before = (int)(travel / GATE);
                travel += speed;
                score += (int)(speed * 10 * (boosting ? 2 : 1) + 0.5f);
                if ((int)(travel / GATE) != before) {
                    int seg = (int)(travel / GATE);
                    if (gate_blocks(seg, px, py))
                        crash();
                    else if (gate_kind(seg)) {
                        sfx_tone(W_SQUARE, 330 + (seg % 5) * 60, 0.08f, 0.15f);
                        score += boosting ? 40 : 20;
                    }
                }
            }
            for (int i = 0; i < 4 && state == S_DIVE; i++) {
                if (wisp_d[i] > travel)
                    continue;
                if (!wisp_on[i]) {
                    /* A skipped wisp is not a miss; the chain goes on. */
                } else if ((wisp_x[i] - px) * (wisp_x[i] - px) + (wisp_y[i] - py) * (wisp_y[i] - py) < 0.24f * 0.24f) {
                    static const int pent[] = {76, 79, 81, 84, 88, 91};
                    wisps++;
                    combo++;
                    score += 50 * combo * (boosting ? 2 : 1);
                    sfx_note(W_TRI, pent[combo % 6], 0.2f, 0.35f);
                    flash = 0.25f;
                } else
                    combo = 0;
                place_wisp(i, travel + 22.f + rng_range(0, 8));
            }
            for (int i = 11; i > 0; i--) {
                trail[i][0] = trail[i - 1][0];
                trail[i][1] = trail[i - 1][1];
            }
            trail[0][0] = px;
            trail[0][1] = py;
            roll = approach(roll, -vx * 3.f, 0.15f);
        } else {
            crash_t++;
            boosting = 0;
            boost_vis *= 0.9f;
            if (crash_t > 45 && press)
                begin_dive();
            else if (crash_t > 300 || (demo > 0 && crash_t > 150)) {
                if (demo > 0) {
                    demo = 0;
                    cab_bot_clear();
                }
                state = S_TITLE;
                idle_t = 0;
                music_play(&idle_tune);
            }
        }
        flash *= 0.88f;
        /* ---------------- draw */
        cab_gl_bind();
        glEnable(GL_DEPTH_TEST);
        glDepthMask(1);
        glDisable(GL_BLEND);
        if (state == S_TITLE) {
            float angle = frame * 0.02f + yaw;
            glClearColor(0.02f, 0.02f, 0.07f, 1);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glUseProgram(p_lit);
            bind9(b_lit);
            perspective(proj, 0.9f, (float)W / H, 0.1f, 30.f);
            translate(m1, 0, -0.05f, -2.6f);
            {
                float tilt[16], spin[16], v[16];
                rotate_x(tilt, 0.28f);
                mul(v, m1, tilt);
                /* Floor: still. */
                mul(mvp, proj, v);
                ident(rot);
                glUniformMatrix4fv(lu_mvp, 1, 0, mvp);
                glUniformMatrix4fv(lu_rot, 1, 0, rot);
                glUniform3f(lu_light, 0.3f, 0.9f, 0.3f);
                glUniform3f(lu_glow, 0.1f, 0.12f, 0.35f);
                glUniform1f(lu_time, frame * 0.01f);
                glDrawArrays(GL_TRIANGLES, 0, orb_first);
                /* The orb: bobbing and turning, the stick yaws it. */
                rotate_y(spin, angle);
                translate(m2, 0, 0.05f + sinf(frame * 0.04f) * 0.06f, 0);
                mul(m2, m2, spin);
                mul(v, v, m2);
                mul(mvp, proj, v);
                glUniformMatrix4fv(lu_mvp, 1, 0, mvp);
                glUniformMatrix4fv(lu_rot, 1, 0, spin);
                glUniform3f(lu_light, 0.45f, 0.75f, 0.5f);
                glUniform3f(lu_glow, 0.55f, 0.75f, 1.0f);
                glDrawArrays(GL_TRIANGLES, orb_first, orb_count);
            }
            /* Stars and a halo, additive. */
            vn = 0;
            for (int i = 0; i < 40; i++) {
                float sx = (float)((i * 37) % 23) / 11.f - 1.f, sy = (float)((i * 53) % 19) / 9.f - 0.2f;
                float tw = 0.4f + 0.4f * sinf(frame * 0.05f + i);
                dot8(sx * 3.f, sy * 2.f, -6.f, 0.04f, tw, tw, tw * 1.2f);
            }
            dot8(0, 0.05f + sinf(frame * 0.04f) * 0.06f, -2.7f, 1.0f, 0.18f, 0.12f, 0.4f);
            glUseProgram(p_glow);
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);
            glDepthMask(0);
            glUniformMatrix4fv(gu_mvp, 1, 0, proj);
            bind8(b_dyn);
            glBufferData(GL_ARRAY_BUFFER, vn * 8 * sizeof(float), vbuf, GL_DYNAMIC_DRAW);
            glDrawArrays(GL_TRIANGLES, 0, vn);
        } else {
            float hue = travel * 0.01f;
            gcol g = col_hsv(hue, 0.7f, 1.f);
            float gr = COL_R(g) / 255.f, gg = COL_G(g) / 255.f, gb = COL_B(g) / 255.f;
            float fov = 1.05f + boost_vis * 0.25f;
            float rz[16];
            glClearColor(0.01f, 0.01f, 0.03f, 1);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            perspective(proj, fov, (float)W / H, 0.08f, 48.f);
            rotate_z(rz, roll);
            mul(mvp, proj, rz);
            vn = 0;
            build_well(travel);
            glUseProgram(p_well);
            glUniform1i(wu_tex, 0);
            glBindTexture(GL_TEXTURE_2D, tex_panel);
            glUniformMatrix4fv(wu_mvp, 1, 0, mvp);
            glUniform3f(wu_fog, 0.01f + gr * 0.04f, 0.01f + gg * 0.04f, 0.03f + gb * 0.06f);
            glUniform3f(wu_glow, gr * 1.2f, gg * 1.2f, gb * 1.2f);
            if (state == S_CRASH)
                glUniform3f(wu_hit, 0.3f * (1 - clampf(crash_t / 40.f, 0, 0.7f)), 0.02f, 0.04f);
            else
                glUniform3f(wu_hit, flash * 0.3f, flash * 0.3f, flash * 0.4f);
            bind8(b_dyn);
            glBufferData(GL_ARRAY_BUFFER, vn * 8 * sizeof(float), vbuf, GL_DYNAMIC_DRAW);
            glDrawArrays(GL_TRIANGLES, 0, vn);
            /* Wisps, the orb, its trail, and speed streaks: additive glows. */
            vn = 0;
            for (int i = 0; i < 4; i++) {
                float z = -(wisp_d[i] - travel);
                if (!wisp_on[i] || z > -1.2f || z < -30.f)
                    continue;
                dot8(wisp_x[i], wisp_y[i], z, 0.22f, 0.5f, 0.9f, 1.0f);
                dot8(wisp_x[i], wisp_y[i], z, 0.08f, 1.f, 1.f, 1.f);
            }
            if (state == S_DIVE) {
                for (int i = 11; i > 0; i -= 2) {
                    float k = 1.f - i / 12.f;
                    dot8(trail[i][0], trail[i][1], -2.55f - i * 0.25f, 0.12f * k, 0.6f * k, 0.4f * k, 1.0f * k);
                }
                dot8(px, py, -2.55f, 0.32f, 0.45f, 0.3f, 0.9f);
                dot8(px, py, -2.55f, 0.13f, 1.0f, 0.95f, 1.0f);
                if (boost_vis > 0.1f)
                    for (int i = 0; i < 10; i++) {
                        float a = i * 0.628f + frame * 0.07f, r = 0.9f;
                        float z = -2.f - fmodf(frame * 0.6f + i * 3.f, 20.f);
                        dot8(cosf(a) * r, sinf(a) * r, z, 0.05f, boost_vis, boost_vis * 0.6f, 0.2f * boost_vis);
                    }
            } else if (crash_t < 40) {
                for (int i = 0; i < 16; i++) {
                    float a = i * 0.3927f, d = crash_t * 0.03f;
                    float k = 1.f - crash_t / 40.f;
                    dot8(px + cosf(a) * d, py + sinf(a) * d, -2.55f, 0.08f, k, 0.4f * k, 0.3f * k);
                }
            }
            glUseProgram(p_glow);
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE);
            glDepthMask(0);
            glUniformMatrix4fv(gu_mvp, 1, 0, mvp);
            bind8(b_dyn);
            glBufferData(GL_ARRAY_BUFFER, vn * 8 * sizeof(float), vbuf, GL_DYNAMIC_DRAW);
            glDrawArrays(GL_TRIANGLES, 0, vn);
        }
        /* HUD over everything. */
        draw_hud();
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glUseProgram(p_hud);
        glUniform1i(hu_tex, 0);
        glBindTexture(GL_TEXTURE_2D, tex_hud);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, HUD_W, HUD_H, 0, GL_RGBA, GL_UNSIGNED_BYTE, hud->px);
        bind8(b_hud);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glDisable(GL_BLEND);
        glDepthMask(1);
        cab_gl_present();
        frame++;
        if (SDL_GL_GetSwapInterval() != 1 && !cab_scripted())
            SDL_Delay(16);
    }
    if (best > saved_best && demo <= 0)
        cab_score_save("orb", best);
    cab_shutdown();
    return 0;
}
