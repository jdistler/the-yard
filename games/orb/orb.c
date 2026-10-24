/* Orb: a lit room, and the well under it. OpenGL ES 2, the API the Mali-400 actually runs.
 * Upright 384x512, which is the panel scaled by exactly 2. The portrait picture is a shaft.
 * Idle, the room turns and the stick yaws it. The lower button drops you into the well:
 * one 128x128 repeating stone texture, a short tube the CPU slides forward and recycles,
 * fog from eye depth, gates you thread. The fragment shader is one texture fetch.
 * A crash writes orb.sav ("best N"). Hold 1-player and 2-player to quit.
 * A card (or CAB_EXT in the simulator) can hold a file named "label". Orb copies it to "orb-card".
 */
#include "cab.h"

#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#define W 384
#define H 512

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef ptrdiff_t GLsizeiptr;
typedef unsigned char GLboolean;

#define GL_DEPTH_TEST 0x0B71
#define GL_CULL_FACE 0x0B44
#define GL_DEPTH_BUFFER_BIT 0x00000100
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_TRIANGLES 0x0004
#define GL_FLOAT 0x1406
#define GL_ARRAY_BUFFER 0x8892
#define GL_STATIC_DRAW 0x88E4
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_TEXTURE_2D 0x0DE1
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_LINEAR 0x2601
#define GL_REPEAT 0x2901
#define GL_DYNAMIC_DRAW 0x88E8
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803

static void (*glEnable)(GLenum);
static void (*glDisable)(GLenum);
static void (*glClearColor)(float, float, float, float);
static void (*glClear)(unsigned);
static void (*glGenBuffers)(GLsizei, GLuint *);
static void (*glBindBuffer)(GLenum, GLuint);
static void (*glBufferData)(GLenum, GLsizeiptr, const void *, GLenum);
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
static void (*glGetProgramInfoLog)(GLuint, GLsizei, GLsizei *, char *);
static GLint (*glGetUniformLocation)(GLuint, const char *);
static void (*glUniformMatrix4fv)(GLint, GLsizei, GLboolean, const float *);
static void (*glUniform3f)(GLint, float, float, float);
static void (*glUniform1i)(GLint, GLint);
static void (*glGenTextures)(GLsizei, GLuint *);
static void (*glBindTexture)(GLenum, GLuint);
static void (*glTexImage2D)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
static void (*glTexParameteri)(GLenum, GLenum, GLint);

static int load(void)
{
#define LOAD(n)                                                      \
    do {                                                             \
        void *s = cab_gl_proc(#n);                                   \
        if (!s) {                                                    \
            cab_log("orb missing %s", #n);                           \
            return -1;                                               \
        }                                                            \
        memcpy(&n, &s, sizeof n);                                   \
    } while (0)
    LOAD(glEnable);
    LOAD(glDisable);
    LOAD(glClearColor);
    LOAD(glClear);
    LOAD(glGenBuffers);
    LOAD(glBindBuffer);
    LOAD(glBufferData);
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
    LOAD(glGetProgramInfoLog);
    LOAD(glGetUniformLocation);
    LOAD(glUniformMatrix4fv);
    LOAD(glUniform3f);
    LOAD(glUniform1i);
    LOAD(glGenTextures);
    LOAD(glBindTexture);
    LOAD(glTexImage2D);
    LOAD(glTexParameteri);
#undef LOAD
    return 0;
}

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

/* pos.xyz, normal.xyz, color.rgb */
static void face(float *d, int *n, float nx, float ny, float nz, float r, float g, float b, const float p[4][3])
{
    const int order[6] = {0, 1, 2, 0, 2, 3};
    for (int i = 0; i < 6; i++) {
        const float *v = p[order[i]];
        float *o = d + *n * 9;
        o[0] = v[0];
        o[1] = v[1];
        o[2] = v[2];
        o[3] = nx;
        o[4] = ny;
        o[5] = nz;
        o[6] = r;
        o[7] = g;
        o[8] = b;
        (*n)++;
    }
}

static void bind_mesh(GLuint id)
{
    glBindBuffer(GL_ARRAY_BUFFER, id);
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)0);
    glVertexAttribPointer(1, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)(3 * sizeof(float)));
    glVertexAttribPointer(2, 3, GL_FLOAT, 0, 9 * sizeof(float), (void *)(6 * sizeof(float)));
}

static int build_room(float *dst)
{
    int n = 0;
    /* A floor corner that clips through the near plane becomes a triangle
     * covering the cube, so the grid stays well in front of the camera. */
    const int side = 4;
    const float x0 = -1.2f, z0 = -0.9f, x1 = 1.2f, z1 = 0.9f, y = -0.62f;
    for (int iz = 0; iz < side; iz++) {
        for (int ix = 0; ix < side; ix++) {
            float xa = x0 + (x1 - x0) * ix / side;
            float xb = x0 + (x1 - x0) * (ix + 1) / side;
            float za = z0 + (z1 - z0) * iz / side;
            float zb = z0 + (z1 - z0) * (iz + 1) / side;
            float q[4][3] = {{xa, y, za}, {xb, y, za}, {xb, y, zb}, {xa, y, zb}};
            if ((ix + iz) & 1)
                face(dst, &n, 0, 1, 0, 0.07f, 0.09f, 0.16f, q);
            else
                face(dst, &n, 0, 1, 0, 0.16f, 0.20f, 0.34f, q);
        }
    }
    const float s = 0.45f;
    const float cube[6][4][3] = {
        {{-s, -s, s}, {s, -s, s}, {s, s, s}, {-s, s, s}},
        {{s, -s, -s}, {-s, -s, -s}, {-s, s, -s}, {s, s, -s}},
        {{-s, s, s}, {s, s, s}, {s, s, -s}, {-s, s, -s}},
        {{-s, -s, -s}, {s, -s, -s}, {s, -s, s}, {-s, -s, s}},
        {{s, -s, s}, {s, -s, -s}, {s, s, -s}, {s, s, s}},
        {{-s, -s, -s}, {-s, -s, s}, {-s, s, s}, {-s, s, -s}},
    };
    const float cn[6][3] = {{0, 0, 1}, {0, 0, -1}, {0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}};
    const float cc[6][3] = {{0.95f, 0.75f, 0.25f}, {0.85f, 0.35f, 0.25f}, {0.95f, 0.9f, 0.55f},
                            {0.4f, 0.3f, 0.15f}, {0.3f, 0.75f, 0.85f}, {0.45f, 0.4f, 0.85f}};
    for (int f = 0; f < 6; f++)
        face(dst, &n, cn[f][0], cn[f][1], cn[f][2], cc[f][0], cc[f][1], cc[f][2], cube[f]);
    return n;
}

static GLuint program(void)
{
    const char *vs =
        "attribute vec3 a_pos;\n"
        "attribute vec3 a_nrm;\n"
        "attribute vec3 a_col;\n"
        "uniform mat4 u_mvp;\n"
        "uniform mat4 u_rot;\n"
        "varying vec3 v_nrm;\n"
        "varying vec3 v_col;\n"
        "void main() {\n"
        "  gl_Position = u_mvp * vec4(a_pos, 1.0);\n"
        "  v_nrm = (u_rot * vec4(a_nrm, 0.0)).xyz;\n"
        "  v_col = a_col;\n"
        "}\n";
    const char *fs =
        "precision mediump float;\n"
        "varying vec3 v_nrm;\n"
        "varying vec3 v_col;\n"
        "uniform vec3 u_light;\n"
        "void main() {\n"
        "  float d = max(dot(normalize(v_nrm), normalize(u_light)), 0.0);\n"
        "  gl_FragColor = vec4(v_col * (0.42 + 0.58 * d), 1.0);\n"
        "}\n";
    GLuint v = glCreateShader(GL_VERTEX_SHADER);
    GLuint f = glCreateShader(GL_FRAGMENT_SHADER);
    GLuint p = glCreateProgram();
    GLint ok = 0;
    char log[400];
    glShaderSource(v, 1, &vs, NULL);
    glCompileShader(v);
    glGetShaderiv(v, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(v, sizeof log, NULL, log);
        cab_log("orb vs: %s", log);
        return 0;
    }
    ok = 0;
    glShaderSource(f, 1, &fs, NULL);
    glCompileShader(f);
    glGetShaderiv(f, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(f, sizeof log, NULL, log);
        cab_log("orb fs: %s", log);
        return 0;
    }
    glBindAttribLocation(p, 0, "a_pos");
    glBindAttribLocation(p, 1, "a_nrm");
    glBindAttribLocation(p, 2, "a_col");
    glAttachShader(p, v);
    glAttachShader(p, f);
    glLinkProgram(p);
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        glGetProgramInfoLog(p, sizeof log, NULL, log);
        cab_log("orb link: %s", log);
        return 0;
    }
    return p;
}

/* The well is a portrait tunnel. A few hundred vertices, rebuilt each frame, slide
 * toward the camera and wrap. The fragment shader stays one fetch, a multiply, and fog.
 * That is the shape a single Mali-400 pixel processor can light at 384x512. */
#define DIVE_MAX 1600
#define WELL_SIDES 8
#define WELL_RINGS 16
#define WELL_STEP 2.4f
#define WELL_SPEED 0.24f
#define WELL_STEER 0.055f
#define GATE 8.f

static float dive_v[DIVE_MAX * 8];
static int dive_n;
static volatile float tone_hz;
static volatile int tone_left;

static void beep(float hz)
{
    tone_hz = hz;
    tone_left = 44100 / 16;
}

static void fill_audio(void *ud, Sint16 *out, int frames)
{
    static double phase;
    (void)ud;
    for (int i = 0; i < frames; i++) {
        Sint16 s = 0;
        if (tone_left > 0) {
            s = (Sint16)(4200.0 * sin(phase));
            phase += 2.0 * 3.1415926535 * (double)tone_hz / 44100.0;
            tone_left--;
        }
        out[i * 2] = out[i * 2 + 1] = s;
    }
}

static void dv(float x, float y, float z, float u, float v, float r, float g, float b)
{
    float *o;
    if (dive_n >= DIVE_MAX)
        return;
    o = dive_v + dive_n * 8;
    o[0] = x;
    o[1] = y;
    o[2] = z;
    o[3] = u;
    o[4] = v;
    o[5] = r;
    o[6] = g;
    o[7] = b;
    dive_n++;
}

static void dquad(const float a[3], const float b[3], const float c[3], const float d[3], float u0, float v0,
                  float u1, float v1, float r, float g, float bl)
{
    dv(a[0], a[1], a[2], u0, v0, r, g, bl);
    dv(b[0], b[1], b[2], u1, v0, r, g, bl);
    dv(c[0], c[1], c[2], u1, v1, r, g, bl);
    dv(a[0], a[1], a[2], u0, v0, r, g, bl);
    dv(c[0], c[1], c[2], u1, v1, r, g, bl);
    dv(d[0], d[1], d[2], u0, v1, r, g, bl);
}

/* Segment 0 is the mouth. Then right, up, left, down, and on the fifth a pillar. */
static int gate_blocks(int seg, float x, float y)
{
    int k;
    if (seg <= 0)
        return 0;
    k = seg % 5;
    if (k == 1)
        return x > 0.58f;
    if (k == 2)
        return y > 0.58f;
    if (k == 3)
        return x < -0.58f;
    if (k == 4)
        return y < -0.58f;
    return x * x + y * y < 0.30f * 0.30f;
}

static void make_stone(unsigned char *px)
{
    for (int y = 0; y < 128; y++) {
        for (int x = 0; x < 128; x++) {
            int lx = x & 31, ly = y & 31;
            int n = ((x * 13 + y * 7) ^ (x >> 2)) & 31;
            int mortar = lx < 2 || ly < 2;
            int rivet = lx > 13 && lx < 18 && ly > 13 && ly < 18;
            int r, g, b;
            unsigned char *p = px + (y * 128 + x) * 4;
            if (mortar) {
                r = 232;
                g = 186;
                b = 78;
            } else if (rivet) {
                r = 255;
                g = 214;
                b = 120;
            } else {
                r = 48 + n;
                g = 40 + n / 2;
                b = 78 + n;
            }
            if ((((x >> 5) + (y >> 5)) & 3) == 0 && lx > 6 && lx < 10) {
                r = 70;
                g = 150;
                b = 180;
            }
            p[0] = (unsigned char)r;
            p[1] = (unsigned char)g;
            p[2] = (unsigned char)b;
            p[3] = 255;
        }
    }
}

static float cap_z(float z)
{
    /* A vertex in front of this plane clips into a triangle that covers the well. */
    return z > -0.55f ? -0.55f : z;
}

/* Pinch one side of a ring. Radius is per vertex so neighboring faces share an edge
 * and the shaft never opens a hole. */
static float wall_rad(int kind, float c, float s)
{
    float pinch = 0;
    if (kind == 1)
        pinch = c;
    else if (kind == 3)
        pinch = -c;
    else if (kind == 2)
        pinch = s;
    else if (kind == 4)
        pinch = -s;
    if (pinch < 0.2f)
        return 1.15f;
    if (pinch > 1.f)
        pinch = 1.f;
    pinch = (pinch - 0.2f) / 0.8f;
    return 1.15f + (0.56f - 1.15f) * pinch;
}

static void build_well(float px, float py, float travel, float wisp_at)
{
    float scroll = fmodf(travel, WELL_STEP);
    dive_n = 0;
    if (scroll < 0)
        scroll += WELL_STEP;
    /* The shaft stays centered. px and py move the ship, not the world, so a
     * hard steer still fills the portrait frame. */
    for (int i = 0; i < WELL_RINGS; i++) {
        float z1 = -0.9f - (float)i * WELL_STEP + scroll;
        float z0 = z1 - WELL_STEP;
        float dist, shade;
        int k0, k1;
        if (z0 > -0.55f)
            continue;
        /* Kind comes from the unclamped depth so the ring ahead and the ring
         * behind agree on the radius of the edge they share. */
        k0 = (int)((travel + (-z0)) / GATE);
        k1 = (int)((travel + (-z1)) / GATE);
        k0 = k0 > 0 ? k0 % 5 : 0;
        k1 = k1 > 0 ? k1 % 5 : 0;
        dist = travel + (-z1);
        z1 = cap_z(z1);
        z0 = cap_z(z0);
        shade = 0.8f + 0.55f * (1.f + z1 / 22.f);
        if (shade < 0.55f)
            shade = 0.55f;
        if (shade > 1.15f)
            shade = 1.15f;
        for (int s = 0; s < WELL_SIDES; s++) {
            float a0 = (float)s / WELL_SIDES * 6.2831853f;
            float a1 = (float)(s + 1) / WELL_SIDES * 6.2831853f;
            float c0 = cosf(a0), s0 = sinf(a0), c1 = cosf(a1), s1 = sinf(a1);
            float r0 = wall_rad(k0, c0, s0);
            float r1 = wall_rad(k0, c1, s1);
            float r2 = wall_rad(k1, c1, s1);
            float r3 = wall_rad(k1, c0, s0);
            float q0[3] = {c0 * r0, s0 * r0, z0};
            float q1[3] = {c1 * r1, s1 * r1, z0};
            float q2[3] = {c1 * r2, s1 * r2, z1};
            float q3[3] = {c0 * r3, s0 * r3, z1};
            float u0 = (float)s / WELL_SIDES;
            float u1 = (float)(s + 1) / WELL_SIDES;
            dquad(q0, q1, q2, q3, u0, (dist + WELL_STEP) * 0.11f, u1, dist * 0.11f, shade, shade * 0.95f, shade);
        }
    }
    for (int ahead = 1; ahead <= 6; ahead++) {
        int seg = (int)(travel / GATE) + ahead;
        float gz, z0, z1, h = 0.30f;
        if (seg < 5 || (seg % 5) != 0)
            continue;
        gz = -(seg * GATE - travel);
        z0 = cap_z(gz - 1.1f);
        z1 = cap_z(gz + 0.15f);
        if (z0 < -32.f || (z0 <= -0.55f && z1 <= -0.55f && gz > -0.4f))
            continue;
        if (z1 > -0.55f)
            continue;
        {
            float tv = -gz * 0.11f;
            float box[4][3] = {{-h, -h, z0}, {h, -h, z0}, {h, h, z0}, {-h, h, z0}};
            float far[4][3] = {{-h, -h, z1}, {h, -h, z1}, {h, h, z1}, {-h, h, z1}};
            dquad(box[0], box[1], far[1], far[0], 0.2f, tv, 0.45f, tv + 0.2f, 1.15f, 0.72f, 0.28f);
            dquad(box[1], box[2], far[2], far[1], 0.2f, tv, 0.45f, tv + 0.2f, 1.15f, 0.72f, 0.28f);
            dquad(box[2], box[3], far[3], far[2], 0.2f, tv, 0.45f, tv + 0.2f, 0.9f, 0.55f, 0.22f);
            dquad(box[3], box[0], far[0], far[3], 0.2f, tv, 0.45f, tv + 0.2f, 0.9f, 0.55f, 0.22f);
        }
    }
    {
        float wz = -(wisp_at - travel);
        float s = 0.13f;
        /* Keep it down the shaft. A wisp on the near plane covers the ship. */
        if (wz < -2.4f && wz > -22.f) {
            float q0[3] = {-s, -s, wz};
            float q1[3] = {s, -s, wz};
            float q2[3] = {s, s, wz};
            float q3[3] = {-s, s, wz};
            dquad(q0, q1, q2, q3, 0.45f, 0.45f, 0.55f, 0.55f, 1.6f, 1.35f, 0.55f);
        }
    }
    {
        /* Far enough down the shaft that a full steer still leaves the chevron
         * on the portrait frame, in front of the gate it is about to meet. */
        float z = -2.55f, w = 0.11f, h = 0.16f;
        dv(px, py + h, z, 0.02f, 0.02f, 2.2f, 1.7f, 0.55f);
        dv(px - w, py - h * 0.35f, z, 0.02f, 0.02f, 1.6f, 0.95f, 0.3f);
        dv(px + w, py - h * 0.35f, z, 0.02f, 0.02f, 1.6f, 0.95f, 0.3f);
    }
}

static GLuint well_program(void)
{
    const char *vs =
        "precision mediump float;\n"
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
        "  v_fog = clamp((-a_pos.z - 6.0) / 26.0, 0.0, 1.0);\n"
        "}\n";
    const char *fs =
        "precision mediump float;\n"
        "varying vec2 v_uv;\n"
        "varying vec3 v_col;\n"
        "varying float v_fog;\n"
        "uniform sampler2D u_tex;\n"
        "uniform vec3 u_fogc;\n"
        "uniform vec3 u_hit;\n"
        "void main() {\n"
        "  vec3 rgb = texture2D(u_tex, v_uv).rgb * v_col;\n"
        "  rgb = mix(rgb, u_fogc, v_fog);\n"
        "  gl_FragColor = vec4(rgb + u_hit, 1.0);\n"
        "}\n";
    GLuint v = glCreateShader(GL_VERTEX_SHADER);
    GLuint f = glCreateShader(GL_FRAGMENT_SHADER);
    GLuint p = glCreateProgram();
    GLint ok = 0;
    char log[400];
    glShaderSource(v, 1, &vs, NULL);
    glCompileShader(v);
    glGetShaderiv(v, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(v, sizeof log, NULL, log);
        cab_log("orb well vs: %s", log);
        return 0;
    }
    ok = 0;
    glShaderSource(f, 1, &fs, NULL);
    glCompileShader(f);
    glGetShaderiv(f, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(f, sizeof log, NULL, log);
        cab_log("orb well fs: %s", log);
        return 0;
    }
    glBindAttribLocation(p, 0, "a_pos");
    glBindAttribLocation(p, 1, "a_uv");
    glBindAttribLocation(p, 2, "a_col");
    glAttachShader(p, v);
    glAttachShader(p, f);
    glLinkProgram(p);
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        glGetProgramInfoLog(p, sizeof log, NULL, log);
        cab_log("orb well link: %s", log);
        return 0;
    }
    return p;
}

static void bind_well(GLuint id)
{
    glBindBuffer(GL_ARRAY_BUFFER, id);
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 8 * sizeof(float), (void *)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 8 * sizeof(float), (void *)(3 * sizeof(float)));
    glVertexAttribPointer(2, 3, GL_FLOAT, 0, 8 * sizeof(float), (void *)(5 * sizeof(float)));
}

int main(int argc, char **argv)
{
    float room[160 * 9];
    float bars[12 * 9];
    int verts, bar_verts = 0;
    GLuint prog, buf = 0, bar_buf = 0;
    GLint u_mvp, u_rot, u_light;
    int frame = 0;
    int fast = cab_fast(argc, argv);
    float yaw = 0;
    char label[64];
    if (cab_gl_init("Orb", W, H) != 0)
        return 1;
    if (load() != 0)
        return 1;
    if (cab_ext_read("label", label, sizeof label) > 0)
        cab_ext_write("orb-card", label, (int)strlen(label));
    verts = build_room(room);
    {
        const float top[4][3] = {{-1, 0.90f, 0}, {1, 0.90f, 0}, {1, 1, 0}, {-1, 1, 0}};
        const float bot[4][3] = {{-1, -1, 0}, {1, -1, 0}, {1, -0.90f, 0}, {-1, -0.90f, 0}};
        face(bars, &bar_verts, 0, 0, 1, 0.86f, 0.16f, 0.16f, top);
        face(bars, &bar_verts, 0, 0, 1, 0.16f, 0.31f, 0.86f, bot);
    }
    prog = program();
    if (!prog)
        return 1;
    glGenBuffers(1, &buf);
    glBindBuffer(GL_ARRAY_BUFFER, buf);
    glBufferData(GL_ARRAY_BUFFER, verts * 9 * sizeof(float), room, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);
    u_mvp = glGetUniformLocation(prog, "u_mvp");
    u_rot = glGetUniformLocation(prog, "u_rot");
    u_light = glGetUniformLocation(prog, "u_light");
    glGenBuffers(1, &bar_buf);
    glBindBuffer(GL_ARRAY_BUFFER, bar_buf);
    glBufferData(GL_ARRAY_BUFFER, bar_verts * 9 * sizeof(float), bars, GL_STATIC_DRAW);
    glEnable(GL_DEPTH_TEST);
    cab_log("orb triangles %d", verts / 3);
    static unsigned char stone_px[128 * 128 * 4];
    GLuint well = well_program();
    GLuint stone = 0, well_buf = 0;
    GLint w_mvp, w_fog, w_hit, w_tex;
    int diving = 0, crash_left = 0, wisps = 0, best;
    float travel = 0, px = 0, py = 0, wisp_at = 5.f;
    if (!well)
        return 1;
    best = cab_score_load("orb");
    make_stone(stone_px);
    glGenTextures(1, &stone);
    glBindTexture(GL_TEXTURE_2D, stone);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 128, 128, 0, GL_RGBA, GL_UNSIGNED_BYTE, stone_px);
    glGenBuffers(1, &well_buf);
    w_mvp = glGetUniformLocation(well, "u_mvp");
    w_fog = glGetUniformLocation(well, "u_fogc");
    w_hit = glGetUniformLocation(well, "u_hit");
    w_tex = glGetUniformLocation(well, "u_tex");
    glUseProgram(well);
    glUniform1i(w_tex, 0);
    cab_audio_open(fill_audio, NULL);
    cab_log("orb well ready");
    while (cab_poll()) {
        float proj[16], view[16], rot[16], model[16], mv[16], mvp[16];
        cab_gl_bind();
        /* cab_gl_present rebinds the blit program and turns depth off, so each
         * frame sets its own program, buffer, texture, and depth. */
        glEnable(GL_DEPTH_TEST);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        if (!diving && cab_pressed(0, CAB_LOW)) {
            diving = 1;
            travel = px = py = 0;
            wisps = 0;
            wisp_at = 5.f;
            crash_left = 0;
        }
        if (diving) {
            float rate = fast ? 1.6f : 1.f;
            if (crash_left > 0) {
                crash_left--;
                if (crash_left == 0) {
                    travel = px = py = 0;
                    wisps = 0;
                    wisp_at = 5.f;
                }
            } else {
                if (cab_down(0, CAB_LEFT))
                    px -= WELL_STEER * rate;
                if (cab_down(0, CAB_RIGHT))
                    px += WELL_STEER * rate;
                if (cab_down(0, CAB_UP))
                    py += WELL_STEER * rate;
                if (cab_down(0, CAB_DOWN))
                    py -= WELL_STEER * rate;
                if (px > 0.82f)
                    px = 0.82f;
                if (px < -0.82f)
                    px = -0.82f;
                if (py > 0.82f)
                    py = 0.82f;
                if (py < -0.82f)
                    py = -0.82f;
                travel += WELL_SPEED * rate;
                while (travel >= wisp_at) {
                    if (px * px + py * py < 0.34f * 0.34f) {
                        wisps++;
                        beep(760);
                    }
                    wisp_at += 11.f;
                }
                if (gate_blocks((int)(travel / GATE), px, py)) {
                    int score = (int)(travel * 10.f) + wisps * 20;
                    if (score < 1)
                        score = 1;
                    if (score > best && cab_score_save("orb", score) == 0)
                        best = score;
                    cab_log("dive crash %d", score);
                    beep(130);
                    crash_left = 36;
                }
            }
            build_well(px, py, travel, wisp_at);
            glClearColor(0.02f, 0.025f, 0.05f, 1);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            glUseProgram(well);
            glBindTexture(GL_TEXTURE_2D, stone);
            bind_well(well_buf);
            glBufferData(GL_ARRAY_BUFFER, dive_n * 8 * sizeof(float), dive_v, GL_DYNAMIC_DRAW);
            perspective(proj, 1.05f, (float)W / (float)H, 0.08f, 48.f);
            glUniformMatrix4fv(w_mvp, 1, 0, proj);
            if (crash_left > 0) {
                glUniform3f(w_fog, 0.28f, 0.03f, 0.04f);
                glUniform3f(w_hit, 0.28f, 0.02f, 0.03f);
            } else {
                glUniform3f(w_fog, 0.02f, 0.025f, 0.05f);
                glUniform3f(w_hit, 0, 0, 0);
            }
            glDrawArrays(GL_TRIANGLES, 0, dive_n);
        } else {
            float angle;
            if (cab_down(0, CAB_LEFT))
                yaw -= 0.03f;
            if (cab_down(0, CAB_RIGHT))
                yaw += 0.03f;
            angle = frame * 0.05f + yaw;
            glUseProgram(prog);
            bind_mesh(buf);
            glClearColor(0.03f, 0.04f, 0.10f, 1);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            perspective(proj, 0.9f, (float)W / (float)H, 0.1f, 20.f);
            translate(view, 0, 0.05f, -2.4f);
            rotate_y(rot, angle);
            ident(model);
            mul(mv, rot, model);
            mul(model, view, mv);
            mul(mvp, proj, model);
            glUniformMatrix4fv(u_mvp, 1, 0, mvp);
            glUniformMatrix4fv(u_rot, 1, 0, rot);
            glUniform3f(u_light, 0.4f, 0.8f, 0.45f);
            glDrawArrays(GL_TRIANGLES, 0, verts);
            glDisable(GL_DEPTH_TEST);
            ident(mvp);
            ident(rot);
            glUniformMatrix4fv(u_mvp, 1, 0, mvp);
            glUniformMatrix4fv(u_rot, 1, 0, rot);
            glUniform3f(u_light, 0, 0, 1);
            bind_mesh(bar_buf);
            glDrawArrays(GL_TRIANGLES, 0, bar_verts);
        }
        cab_gl_present();
        frame++;
        if (SDL_GL_GetSwapInterval() != 1)
            SDL_Delay(16);
    }
    cab_shutdown();
    return 0;
}
