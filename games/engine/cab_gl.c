/* OpenGL ES 2 for the cabinet's Mali-400 and for the PC simulator (Mesa GLES).
 * The game draws upright into an FBO. Present copies that onto the window,
 * rotated the same way cab_present rotates the SDL renderer. */
#include "cab.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GL_DEPTH_BUFFER_BIT 0x00000100
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_TEXTURE_2D 0x0DE1
#define GL_UNSIGNED_BYTE 0x1401
#define GL_FLOAT 0x1406
#define GL_RGBA 0x1908
#define GL_NEAREST 0x2600
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_FRAMEBUFFER 0x8D40
#define GL_RENDERBUFFER 0x8D41
#define GL_DEPTH_COMPONENT16 0x81A5
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_DEPTH_ATTACHMENT 0x8D00
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_INFO_LOG_LENGTH 0x8B84
#define GL_ARRAY_BUFFER 0x8892
#define GL_STATIC_DRAW 0x88E4
#define GL_TRIANGLE_STRIP 0x0005
#define GL_VENDOR 0x1F00
#define GL_RENDERER 0x1F01
#define GL_VERSION 0x1F02
#define GL_SHADING_LANGUAGE_VERSION 0x8B8C
#define GL_MAX_TEXTURE_SIZE 0x0D33
#define GL_MAX_VERTEX_ATTRIBS 0x8869
#define GL_MAX_VERTEX_UNIFORM_VECTORS 0x8DFB
#define GL_MAX_FRAGMENT_UNIFORM_VECTORS 0x8DFD
#define GL_MAX_VARYING_VECTORS 0x8DFC
#define GL_MAX_TEXTURE_IMAGE_UNITS 0x8872

typedef void (*GL_void_fn)(void);
typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef ptrdiff_t GLsizeiptr;
typedef unsigned char GLboolean;

static SDL_GLContext ctx;
static int active;
static GLuint fbo, color_tex, depth_rb, prog, vbo;

static void (*glBindFramebuffer)(GLenum, GLuint);
static void (*glBindRenderbuffer)(GLenum, GLuint);
static void (*glBindBuffer)(GLenum, GLuint);
static void (*glBindTexture)(GLenum, GLuint);
static void (*glViewport)(GLint, GLint, GLsizei, GLsizei);
static void (*glClearColor)(float, float, float, float);
static void (*glClear)(unsigned);
static void (*glGenFramebuffers)(GLsizei, GLuint *);
static void (*glGenRenderbuffers)(GLsizei, GLuint *);
static void (*glGenTextures)(GLsizei, GLuint *);
static void (*glGenBuffers)(GLsizei, GLuint *);
static void (*glDeleteFramebuffers)(GLsizei, const GLuint *);
static void (*glDeleteRenderbuffers)(GLsizei, const GLuint *);
static void (*glDeleteTextures)(GLsizei, const GLuint *);
static void (*glDeleteBuffers)(GLsizei, const GLuint *);
static void (*glFramebufferTexture2D)(GLenum, GLenum, GLenum, GLuint, GLint);
static void (*glFramebufferRenderbuffer)(GLenum, GLenum, GLenum, GLuint);
static void (*glRenderbufferStorage)(GLenum, GLenum, GLsizei, GLsizei);
static GLenum (*glCheckFramebufferStatus)(GLenum);
static void (*glTexImage2D)(GLenum, GLint, int, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
static void (*glTexParameteri)(GLenum, GLenum, GLint);
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
static void (*glDeleteShader)(GLuint);
static GLuint (*glCreateProgram)(void);
static void (*glAttachShader)(GLuint, GLuint);
static void (*glLinkProgram)(GLuint);
static void (*glGetProgramiv)(GLuint, GLenum, GLint *);
static void (*glGetProgramInfoLog)(GLuint, GLsizei, GLsizei *, char *);
static void (*glDeleteProgram)(GLuint);
static GLint (*glGetAttribLocation)(GLuint, const char *);
static GLint (*glGetUniformLocation)(GLuint, const char *);
static void (*glUniform1i)(GLint, GLint);
static void (*glReadPixels)(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);
static void (*glDisable)(GLenum);
static const unsigned char *(*glGetString)(GLenum);
static void (*glGetIntegerv)(GLenum, GLint *);

static int load_procs(void)
{
#define LOAD(name)                                                          \
    do {                                                                    \
        void *sym = SDL_GL_GetProcAddress(#name);                           \
        if (!sym) {                                                         \
            cab_log("OpenGL ES is missing %s", #name);                      \
            return -1;                                                      \
        }                                                                   \
        memcpy(&name, &sym, sizeof name);                                  \
    } while (0)
    LOAD(glBindFramebuffer);
    LOAD(glBindRenderbuffer);
    LOAD(glBindBuffer);
    LOAD(glBindTexture);
    LOAD(glViewport);
    LOAD(glClearColor);
    LOAD(glClear);
    LOAD(glGenFramebuffers);
    LOAD(glGenRenderbuffers);
    LOAD(glGenTextures);
    LOAD(glGenBuffers);
    LOAD(glDeleteFramebuffers);
    LOAD(glDeleteRenderbuffers);
    LOAD(glDeleteTextures);
    LOAD(glDeleteBuffers);
    LOAD(glFramebufferTexture2D);
    LOAD(glFramebufferRenderbuffer);
    LOAD(glRenderbufferStorage);
    LOAD(glCheckFramebufferStatus);
    LOAD(glTexImage2D);
    LOAD(glTexParameteri);
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
    LOAD(glDeleteShader);
    LOAD(glCreateProgram);
    LOAD(glAttachShader);
    LOAD(glLinkProgram);
    LOAD(glGetProgramiv);
    LOAD(glGetProgramInfoLog);
    LOAD(glDeleteProgram);
    LOAD(glGetAttribLocation);
    LOAD(glGetUniformLocation);
    LOAD(glUniform1i);
    LOAD(glReadPixels);
    LOAD(glDisable);
    LOAD(glGetString);
    LOAD(glGetIntegerv);
#undef LOAD
    return 0;
}

static GLuint compile_shader(GLenum type, const char *src)
{
    GLuint s = glCreateShader(type);
    GLint ok = 0;
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        cab_log("shader: %s", log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}

static int build_blit(void)
{
    const char *vs =
        "attribute vec2 a_pos;\n"
        "attribute vec2 a_uv;\n"
        "varying vec2 v_uv;\n"
        "void main() {\n"
        "  gl_Position = vec4(a_pos, 0.0, 1.0);\n"
        "  v_uv = a_uv;\n"
        "}\n";
    const char *fs =
        "precision mediump float;\n"
        "varying vec2 v_uv;\n"
        "uniform sampler2D u_tex;\n"
        "void main() { gl_FragColor = texture2D(u_tex, v_uv); }\n";
    GLuint v = compile_shader(GL_VERTEX_SHADER, vs);
    GLuint f = compile_shader(GL_FRAGMENT_SHADER, fs);
    GLint ok = 0;
    if (!v || !f)
        return -1;
    prog = glCreateProgram();
    glAttachShader(prog, v);
    glAttachShader(prog, f);
    glLinkProgram(prog);
    glDeleteShader(v);
    glDeleteShader(f);
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetProgramInfoLog(prog, sizeof log, NULL, log);
        cab_log("link: %s", log);
        return -1;
    }
    return 0;
}

static void log_limits(void)
{
    GLint n = 0;
    cab_log("GL %s", glGetString(GL_VERSION));
    cab_log("GL renderer %s", glGetString(GL_RENDERER));
    cab_log("GLSL %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &n);
    cab_log("GL max texture %d", n);
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &n);
    cab_log("GL max vertex attribs %d", n);
    glGetIntegerv(GL_MAX_VERTEX_UNIFORM_VECTORS, &n);
    cab_log("GL max vertex uniform vectors %d", n);
    glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_VECTORS, &n);
    cab_log("GL max fragment uniform vectors %d", n);
    glGetIntegerv(GL_MAX_VARYING_VECTORS, &n);
    cab_log("GL max varying vectors %d", n);
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &n);
    cab_log("GL max texture image units %d", n);
}

int cab_gl_active(void) { return active; }

void *cab_gl_proc(const char *name) { return SDL_GL_GetProcAddress(name); }

int cab_gl_init(const char *title, int logical_w, int logical_h)
{
    GLenum status;
    if (cab_video_init(title, logical_w, logical_h, 1) != 0)
        return -1;
    ctx = SDL_GL_CreateContext(cab_window);
    if (!ctx) {
        cab_log("SDL_GL_CreateContext: %s", SDL_GetError());
        cab_shutdown();
        return -1;
    }
    if (load_procs() != 0 || build_blit() != 0) {
        cab_shutdown();
        return -1;
    }
    glGenTextures(1, &color_tex);
    glBindTexture(GL_TEXTURE_2D, color_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, logical_w, logical_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glGenRenderbuffers(1, &depth_rb);
    glBindRenderbuffer(GL_RENDERBUFFER, depth_rb);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, logical_w, logical_h);
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color_tex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth_rb);
    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        cab_log("FBO incomplete 0x%x", status);
        cab_shutdown();
        return -1;
    }
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, 4 * 4 * sizeof(float), NULL, GL_STATIC_DRAW);
    active = 1;
    log_limits();
    SDL_GL_SetSwapInterval(1);
    return 0;
}

void cab_gl_bind(void)
{
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glViewport(0, 0, cab_w, cab_h);
}

static void ndc(float px, float py, int ow, int oh, float *x, float *y)
{
    *x = (px / (float)ow) * 2.f - 1.f;
    *y = 1.f - (py / (float)oh) * 2.f;
}

void cab_gl_present(void)
{
    int ow = 0, oh = 0, uw, uh, dw, dh;
    float s, verts[16];
    GLint loc_pos, loc_uv;
    SDL_Rect dst;
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    SDL_GL_GetDrawableSize(cab_window, &ow, &oh);
    if (ow < 16 || oh < 16) {
        ow = cab_rotate_on() ? CAB_FB_W : cab_w;
        oh = cab_rotate_on() ? CAB_FB_H : cab_h;
    }
    glViewport(0, 0, ow, oh);
    glDisable(0x0B71); /* depth test */
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    if (cab_rotate_on()) {
        uw = oh < ow ? oh : ow;
        uh = oh < ow ? ow : oh;
        s = (float)uw / (float)cab_w;
        if ((float)uh / (float)cab_h < s)
            s = (float)uh / (float)cab_h;
        /* In the landscape framebuffer (ow x oh), the rotated quad's width along X is the
         * upright height (cab_h * s) and its height along Y is the upright width (cab_w * s). */
        dw = (int)(cab_h * s);
        dh = (int)(cab_w * s);
        dst.x = (ow - dw) / 2;
        dst.y = (oh - dh) / 2;
        dst.w = dw;
        dst.h = dh;
        /* -90 degrees: the top of the upright image lands on the left. */
        ndc((float)dst.x, (float)(dst.y + dst.h), ow, oh, &verts[0], &verts[1]);
        verts[2] = 0;
        verts[3] = 1; /* output BL <- upright top-left */
        ndc((float)(dst.x + dst.w), (float)(dst.y + dst.h), ow, oh, &verts[4], &verts[5]);
        verts[6] = 0;
        verts[7] = 0; /* output BR <- upright bottom-left */
        ndc((float)dst.x, (float)dst.y, ow, oh, &verts[8], &verts[9]);
        verts[10] = 1;
        verts[11] = 1; /* output TL <- upright top-right */
        ndc((float)(dst.x + dst.w), (float)dst.y, ow, oh, &verts[12], &verts[13]);
        verts[14] = 1;
        verts[15] = 0; /* output TR <- upright bottom-right */
    } else {
        verts[0] = -1;
        verts[1] = -1;
        verts[2] = 0;
        verts[3] = 0;
        verts[4] = 1;
        verts[5] = -1;
        verts[6] = 1;
        verts[7] = 0;
        verts[8] = -1;
        verts[9] = 1;
        verts[10] = 0;
        verts[11] = 1;
        verts[12] = 1;
        verts[13] = 1;
        verts[14] = 1;
        verts[15] = 1;
    }
    glUseProgram(prog);
    glUniform1i(glGetUniformLocation(prog, "u_tex"), 0);
    glBindTexture(GL_TEXTURE_2D, color_tex);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof verts, verts, GL_STATIC_DRAW);
    loc_pos = glGetAttribLocation(prog, "a_pos");
    loc_uv = glGetAttribLocation(prog, "a_uv");
    glEnableVertexAttribArray((GLuint)loc_pos);
    glEnableVertexAttribArray((GLuint)loc_uv);
    glVertexAttribPointer((GLuint)loc_pos, 2, GL_FLOAT, 0, 4 * sizeof(float), (void *)0);
    glVertexAttribPointer((GLuint)loc_uv, 2, GL_FLOAT, 0, 4 * sizeof(float), (void *)(2 * sizeof(float)));
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    cab_shot_if_due();
    SDL_GL_SwapWindow(cab_window);
}

int cab_gl_screenshot(const char *path)
{
    int w, h, stride, y;
    unsigned char *px;
    FILE *f;
    unsigned char hdr[54];
    SDL_GL_GetDrawableSize(cab_window, &w, &h);
    if (w < 1 || h < 1)
        return -1;
    px = malloc((size_t)w * h * 4);
    if (!px)
        return -1;
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, px);
    stride = (w * 3 + 3) & ~3;
    memset(hdr, 0, sizeof hdr);
    hdr[0] = 'B';
    hdr[1] = 'M';
    {
        unsigned size = 54u + (unsigned)stride * h;
        hdr[2] = size & 255;
        hdr[3] = (size >> 8) & 255;
        hdr[4] = (size >> 16) & 255;
        hdr[5] = (size >> 24) & 255;
    }
    hdr[10] = 54;
    hdr[14] = 40;
    hdr[18] = w & 255;
    hdr[19] = (w >> 8) & 255;
    hdr[20] = (w >> 16) & 255;
    hdr[21] = (w >> 24) & 255;
    hdr[22] = h & 255;
    hdr[23] = (h >> 8) & 255;
    hdr[24] = (h >> 16) & 255;
    hdr[25] = (h >> 24) & 255;
    hdr[26] = 1;
    hdr[28] = 24;
    f = fopen(path, "wb");
    if (!f) {
        free(px);
        return -1;
    }
    fwrite(hdr, 1, 54, f);
    {
        unsigned char *row = malloc((size_t)stride);
        int x;
        if (!row) {
            fclose(f);
            free(px);
            return -1;
        }
        for (y = 0; y < h; y++) {
            memset(row, 0, (size_t)stride);
            for (x = 0; x < w; x++) {
                unsigned char *s = px + ((size_t)y * w + x) * 4;
                row[x * 3 + 0] = s[2];
                row[x * 3 + 1] = s[1];
                row[x * 3 + 2] = s[0];
            }
            fwrite(row, 1, (size_t)stride, f);
        }
        free(row);
    }
    fclose(f);
    free(px);
    return 0;
}

void cab_gl_shutdown(void)
{
    if (!ctx && !active)
        return;
    if (ctx && cab_window)
        SDL_GL_MakeCurrent(cab_window, ctx);
    if (glDeleteFramebuffers && fbo)
        glDeleteFramebuffers(1, &fbo);
    if (glDeleteTextures && color_tex)
        glDeleteTextures(1, &color_tex);
    if (glDeleteRenderbuffers && depth_rb)
        glDeleteRenderbuffers(1, &depth_rb);
    if (glDeleteBuffers && vbo)
        glDeleteBuffers(1, &vbo);
    if (glDeleteProgram && prog)
        glDeleteProgram(prog);
    fbo = color_tex = depth_rb = vbo = prog = 0;
    if (ctx)
        SDL_GL_DeleteContext(ctx);
    ctx = NULL;
    active = 0;
}
