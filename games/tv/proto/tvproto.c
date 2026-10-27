/* tvproto: the TV player's core, as an experiment (games/tv/PLAN.md). A raw H.264/HEVC elementary stream is
 * decoded by the VPU (Rockchip MPP, into DRM buffers), each frame is imported into the GPU without a copy
 * (EGL_EXT_image_dma_buf_import, NV12, sampled through GL_OES_EGL_image_external), turned upright and
 * letterboxed for the portrait panel, and shown through our SDL (KMSDRM, GLES2).
 *   tvproto FILE h264|hevc [SECONDS] [skip|noskip] [FPS]   paced at FPS; "skip": drop non-reference pictures
 *                                                         when more than 40 ms behind
 * Prints decode/display rates, frames skipped, and the CPU time used. */
#include <SDL2/SDL.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include "rk_mpi.h"
#include "mpp_buffer.h"
#include "mpp_frame.h"
#include "mpp_packet.h"

/* EGL/GLES, by hand: no Khronos headers in the toolchain image. */
typedef void *EGLDisplay, *EGLImageKHR, *EGLContext, *EGLClientBuffer;
typedef int32_t EGLint;
typedef unsigned int GLuint, GLenum, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef char GLchar;
#define EGL_NO_CONTEXT ((EGLContext)0)
#define EGL_LINUX_DMA_BUF_EXT 0x3270
#define EGL_WIDTH 0x3057
#define EGL_HEIGHT 0x3056
#define EGL_LINUX_DRM_FOURCC_EXT 0x3271
#define EGL_DMA_BUF_PLANE0_FD_EXT 0x3272
#define EGL_DMA_BUF_PLANE0_OFFSET_EXT 0x3273
#define EGL_DMA_BUF_PLANE0_PITCH_EXT 0x3274
#define EGL_DMA_BUF_PLANE1_FD_EXT 0x3275
#define EGL_DMA_BUF_PLANE1_OFFSET_EXT 0x3276
#define EGL_DMA_BUF_PLANE1_PITCH_EXT 0x3277
#define EGL_YUV_COLOR_SPACE_HINT_EXT 0x327B
#define EGL_SAMPLE_RANGE_HINT_EXT 0x327C
#define EGL_ITU_REC709_EXT 0x327F
#define EGL_YUV_NARROW_RANGE_EXT 0x3283
#define EGL_NONE 0x3038
#define DRM_FORMAT_NV12 0x3231564e
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_LINEAR 0x2601
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_TRIANGLE_STRIP 0x0005
#define GL_FLOAT 0x1406
#define GL_COLOR_BUFFER_BIT 0x4000
#define GL_TEXTURE0 0x84C0

static EGLDisplay (*eglGetCurrentDisplay_)(void);
static EGLImageKHR (*eglCreateImageKHR_)(EGLDisplay, EGLContext, GLenum, EGLClientBuffer, const EGLint *);
static int (*eglDestroyImageKHR_)(EGLDisplay, EGLImageKHR);
static int (*eglGetError_)(void);
static void (*glEGLImageTargetTexture2DOES_)(GLenum, void *);
static void (*glGenTextures_)(GLsizei, GLuint *);
static void (*glBindTexture_)(GLenum, GLuint);
static void (*glTexParameteri_)(GLenum, GLenum, GLint);
static GLuint (*glCreateShader_)(GLenum);
static void (*glShaderSource_)(GLuint, GLsizei, const GLchar **, const GLint *);
static void (*glCompileShader_)(GLuint);
static void (*glGetShaderiv_)(GLuint, GLenum, GLint *);
static void (*glGetShaderInfoLog_)(GLuint, GLsizei, GLsizei *, GLchar *);
static GLuint (*glCreateProgram_)(void);
static void (*glAttachShader_)(GLuint, GLuint);
static void (*glLinkProgram_)(GLuint);
static void (*glUseProgram_)(GLuint);
static void (*glBindAttribLocation_)(GLuint, GLuint, const GLchar *);
static void (*glVertexAttribPointer_)(GLuint, GLint, GLenum, int, GLsizei, const void *);
static void (*glEnableVertexAttribArray_)(GLuint);
static void (*glDrawArrays_)(GLenum, GLint, GLsizei);
static void (*glClearColor_)(GLfloat, GLfloat, GLfloat, GLfloat);
static void (*glClear_)(GLbitfield);
static void (*glViewport_)(GLint, GLint, GLsizei, GLsizei);
static void (*glActiveTexture_)(GLenum);
static GLint (*glGetUniformLocation_)(GLuint, const GLchar *);
static void (*glUniform1i_)(GLint, GLint);

static void *gl(const char *name)
{
    void *p = SDL_GL_GetProcAddress(name);
    if (!p) { fprintf(stderr, "missing %s\n", name); exit(1); }
    return p;
}

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static GLuint shader(GLenum type, const char *src)
{
    GLuint s = glCreateShader_(type);
    GLint ok = 0;
    glShaderSource_(s, 1, &src, NULL);
    glCompileShader_(s);
    glGetShaderiv_(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[1024]; glGetShaderInfoLog_(s, sizeof log, NULL, log); fprintf(stderr, "shader: %s\n", log); exit(1); }
    return s;
}

/* An EGLImage per decoder buffer (MPP reuses a small pool), made on first sight. */
#define MAX_IMAGES 32
static struct { int fd; EGLImageKHR img; GLuint tex; } images[MAX_IMAGES];
static int nimages;

static GLuint texture_for(MppFrame f)
{
    MppBuffer b = mpp_frame_get_buffer(f);
    int fd = mpp_buffer_get_fd(b);
    for (int i = 0; i < nimages; i++)
        if (images[i].fd == fd) return images[i].tex;
    if (nimages == MAX_IMAGES) { fprintf(stderr, "too many buffers\n"); exit(1); }
    int w = mpp_frame_get_width(f), h = mpp_frame_get_height(f);
    int hs = mpp_frame_get_hor_stride(f), vs = mpp_frame_get_ver_stride(f);
    EGLint attr[] = {
        EGL_WIDTH, w, EGL_HEIGHT, h, EGL_LINUX_DRM_FOURCC_EXT, DRM_FORMAT_NV12,
        EGL_DMA_BUF_PLANE0_FD_EXT, fd, EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0, EGL_DMA_BUF_PLANE0_PITCH_EXT, hs,
        EGL_DMA_BUF_PLANE1_FD_EXT, fd, EGL_DMA_BUF_PLANE1_OFFSET_EXT, hs * vs, EGL_DMA_BUF_PLANE1_PITCH_EXT, hs,
        EGL_YUV_COLOR_SPACE_HINT_EXT, EGL_ITU_REC709_EXT, EGL_SAMPLE_RANGE_HINT_EXT, EGL_YUV_NARROW_RANGE_EXT,
        EGL_NONE};
    EGLImageKHR img = eglCreateImageKHR_(eglGetCurrentDisplay_(), EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attr);
    if (!img) {
        /* Try without the colour hints (not every driver takes them). */
        attr[18] = EGL_NONE;
        img = eglCreateImageKHR_(eglGetCurrentDisplay_(), EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attr);
    }
    if (!img) { fprintf(stderr, "eglCreateImageKHR failed: 0x%x (%dx%d stride %d/%d)\n", eglGetError_(), w, h, hs, vs); exit(1); }
    GLuint tex;
    glGenTextures_(1, &tex);
    glBindTexture_(GL_TEXTURE_EXTERNAL_OES, tex);
    glTexParameteri_(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri_(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glEGLImageTargetTexture2DOES_(GL_TEXTURE_EXTERNAL_OES, img);
    images[nimages].fd = fd;
    images[nimages].img = img;
    images[nimages].tex = tex;
    fprintf(stderr, "imported buffer fd %d as texture %u (%dx%d, strides %d/%d)\n", fd, tex, w, h, hs, vs);
    return images[nimages++].tex;
}

/* Is this access unit a non-reference picture? (the first slice's NAL header) */
static int nonref(const uint8_t *p, size_t n, int hevc)
{
    for (size_t i = 0; i + 4 < n; i++) {
        if (p[i] == 0 && p[i + 1] == 0 && p[i + 2] == 1) {
            uint8_t b = p[i + 3];
            if (!hevc) {
                int t = b & 31;
                if (t == 1 || t == 5) return ((b >> 5) & 3) == 0;
            } else {
                int t = (b >> 1) & 63;
                if (t <= 21) return t <= 14 && t % 2 == 0;
            }
        }
    }
    return 0;
}

/* Split an Annex-B stream into access units (pictures): a new one at each slice whose first_mb / first
 * slice segment flag says "first". Returns the length of the unit at p. */
static size_t next_unit(const uint8_t *p, size_t n, int hevc)
{
    int seen_slice = 0;
    for (size_t i = 0; i + 5 < n; i++) {
        if (p[i] == 0 && p[i + 1] == 0 && p[i + 2] == 1) {
            uint8_t b = p[i + 3];
            int first = 0, slice = 0, param = 0;
            if (!hevc) {
                int t = b & 31;
                slice = t == 1 || t == 5;
                first = slice && (p[i + 4] & 0x80);
                param = t == 6 || t == 7 || t == 8 || t == 9;
            } else {
                int t = (b >> 1) & 63;
                slice = t <= 21;
                first = slice && (p[i + 5] & 0x80);
                param = t >= 32 && t <= 40;
            }
            if (seen_slice && (first || param)) {
                size_t s = i;
                if (s > 0 && p[s - 1] == 0) s--;
                return s;
            }
            if (slice) seen_slice = 1;
        }
    }
    return n;
}

/* The decoder's state, shared by main and drain(). */
static MppCtx mctx;
static MppApi *mpi;
static MppBufferGroup grp;
static SDL_Window *win;
static int ww, wh;
static long decoded, shown;
static int qdepth;

static void drain(void)
{
    for (;;) {
            MppFrame frame = NULL;
            if (mpi->decode_get_frame(mctx, &frame) != MPP_OK || !frame) break;
            if (mpp_frame_get_info_change(frame)) {
                /* First frame: the decoder asks for its buffers; give it a DRM group. */
                if (!grp) mpp_buffer_group_get_internal(&grp, MPP_BUFFER_TYPE_DRM);
                mpi->control(mctx, MPP_DEC_SET_EXT_BUF_GROUP, grp);
                mpi->control(mctx, MPP_DEC_SET_INFO_CHANGE_READY, NULL);
                fprintf(stderr, "stream %dx%d\n", mpp_frame_get_width(frame), mpp_frame_get_height(frame));
            } else if (mpp_frame_get_buffer(frame)) {
                decoded++;
                qdepth = qdepth > 0 ? qdepth - 1 : 0;
                /* Upright and letterboxed: the panel shows the framebuffer turned 90 degrees. In the upright
                   view (768 wide, 1024 tall) a 16:9 picture is 768 x 432, centred. */
                int vw = mpp_frame_get_width(frame), vh = mpp_frame_get_height(frame);
                float uh = 768.0f * vh / vw;            /* picture height in the upright view */
                float half = uh / 1024.0f;              /* in clip space: the framebuffer's x is the upright y */
                /* Upright (u right, v down) is the framebuffer's (x = v, y = 767 - u) (measured with tools/cabview);
                   in clip space X = 2v/1024 - 1, Y = 2u/768 - 1. Corners: pos.x, pos.y, tex.s, tex.t. */
                float verts[] = {
                    -half, -1.0f, 0.0f, 0.0f,  /* upright top-left */
                    -half, 1.0f, 1.0f, 0.0f,   /* upright top-right */
                    half, -1.0f, 0.0f, 1.0f,   /* upright bottom-left */
                    half, 1.0f, 1.0f, 1.0f,    /* upright bottom-right */
                };
                glViewport_(0, 0, ww, wh);
                glClearColor_(0, 0, 0, 1);
                glClear_(GL_COLOR_BUFFER_BIT);
                glActiveTexture_(GL_TEXTURE0);
                glBindTexture_(GL_TEXTURE_EXTERNAL_OES, texture_for(frame));
                glVertexAttribPointer_(0, 2, GL_FLOAT, 0, 16, verts);
                glVertexAttribPointer_(1, 2, GL_FLOAT, 0, 16, verts + 2);
                glEnableVertexAttribArray_(0);
                glEnableVertexAttribArray_(1);
                glDrawArrays_(GL_TRIANGLE_STRIP, 0, 4);
                SDL_GL_SwapWindow(win);
                shown++;
            }
            mpp_frame_deinit(&frame);
        }
}

int main(int argc, char **argv)
{
    if (argc < 3) { fprintf(stderr, "usage: tvproto FILE h264|hevc [SECONDS] [skip]\n"); return 2; }
    int hevc = !strcmp(argv[2], "hevc");
    double secs = argc > 3 ? atof(argv[3]) : 15;
    int skip = argc > 4 && !strcmp(argv[4], "skip");
    FILE *fp = fopen(argv[1], "rb");
    struct stat st;
    if (!fp || stat(argv[1], &st)) { perror(argv[1]); return 1; }
    uint8_t *data = malloc(st.st_size);
    if (fread(data, 1, st.st_size, fp) != (size_t)st.st_size) return 1;
    fclose(fp);

    SDL_SetHint(SDL_HINT_VIDEO_EGL_ALLOW_TRANSPARENCY, "0");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) { fprintf(stderr, "SDL: %s\n", SDL_GetError()); return 1; }
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    win = SDL_CreateWindow("tv", 0, 0, 1024, 768, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP);
    SDL_GLContext ctx = win ? SDL_GL_CreateContext(win) : NULL;
    if (!ctx) { fprintf(stderr, "GL: %s\n", SDL_GetError()); return 1; }
    SDL_GL_SetSwapInterval(1);
    SDL_GL_GetDrawableSize(win, &ww, &wh);

    eglGetCurrentDisplay_ = gl("eglGetCurrentDisplay");
    eglCreateImageKHR_ = gl("eglCreateImageKHR");
    eglDestroyImageKHR_ = gl("eglDestroyImageKHR");
    eglGetError_ = gl("eglGetError");
    glEGLImageTargetTexture2DOES_ = gl("glEGLImageTargetTexture2DOES");
    glGenTextures_ = gl("glGenTextures"); glBindTexture_ = gl("glBindTexture"); glTexParameteri_ = gl("glTexParameteri");
    glCreateShader_ = gl("glCreateShader"); glShaderSource_ = gl("glShaderSource"); glCompileShader_ = gl("glCompileShader");
    glGetShaderiv_ = gl("glGetShaderiv"); glGetShaderInfoLog_ = gl("glGetShaderInfoLog");
    glCreateProgram_ = gl("glCreateProgram"); glAttachShader_ = gl("glAttachShader"); glLinkProgram_ = gl("glLinkProgram");
    glUseProgram_ = gl("glUseProgram"); glBindAttribLocation_ = gl("glBindAttribLocation");
    glVertexAttribPointer_ = gl("glVertexAttribPointer"); glEnableVertexAttribArray_ = gl("glEnableVertexAttribArray");
    glDrawArrays_ = gl("glDrawArrays"); glClearColor_ = gl("glClearColor"); glClear_ = gl("glClear");
    glViewport_ = gl("glViewport"); glActiveTexture_ = gl("glActiveTexture");
    glGetUniformLocation_ = gl("glGetUniformLocation"); glUniform1i_ = gl("glUniform1i");

    GLuint prog = glCreateProgram_();
    glAttachShader_(prog, shader(GL_VERTEX_SHADER,
        "attribute vec2 pos; attribute vec2 uv; varying vec2 v; void main() { v = uv; gl_Position = vec4(pos, 0.0, 1.0); }"));
    glAttachShader_(prog, shader(GL_FRAGMENT_SHADER,
        "#extension GL_OES_EGL_image_external : require\n"
        "precision mediump float; varying vec2 v; uniform samplerExternalOES tex;"
        "void main() { gl_FragColor = texture2D(tex, v); }"));
    glBindAttribLocation_(prog, 0, "pos");
    glBindAttribLocation_(prog, 1, "uv");
    glLinkProgram_(prog);
    glUseProgram_(prog);
    glUniform1i_(glGetUniformLocation_(prog, "tex"), 0);

    /* MPP: the decoder, writing into DRM buffers (dma-buf fds the GPU can import). */
    if (mpp_create(&mctx, &mpi) || mpp_init(mctx, MPP_CTX_DEC, hevc ? MPP_VIDEO_CodingHEVC : MPP_VIDEO_CodingAVC)) {
        fprintf(stderr, "mpp init failed\n");
        return 1;
    }
    MppDecCfg cfg = NULL;
    (void)cfg;

    double t0 = now(), last_show = 0;
    size_t off = 0;
    long sent = 0, skipped = 0, pics = 0;
    double fps = argc > 5 ? atof(argv[5]) : 50, last_report = 0;
    struct rusage ru0;
    getrusage(RUSAGE_SELF, &ru0);
    double fps_guess = 50;
    while (now() - t0 < secs) {
        /* Feed one picture (looping the file). */
        if (off >= (size_t)st.st_size) off = 0;
        size_t len = next_unit(data + off, st.st_size - off, hevc);
        /* Paced on the stream's clock: picture n is due at t0 + n / fps. Up to LEAD s early is fine (the decoder
           holds a few pictures); a non-reference picture more than LATE s behind is skipped (with "skip"). */
        double due = t0 + pics / fps;
        while (now() < due - 0.25) { drain(); SDL_Delay(1); }
        int behind = now() > due + 0.04;
        int drop = skip && behind && nonref(data + off, len, hevc);
        pics++;
        if (now() - last_report >= 1.0) {
            last_report = now();
            fprintf(stderr, "t %.0f: pictures %ld sent %ld decoded %ld shown %ld skipped %ld behind %.2f s\n",
                    now() - t0, pics, sent, decoded, shown, skipped, now() - due);
        }
        if (drop) {
            skipped++;
        } else {
            MppPacket pkt;
            mpp_packet_init(&pkt, data + off, len);
            while (mpi->decode_put_packet(mctx, pkt) != MPP_OK) { drain(); SDL_Delay(1); }
            mpp_packet_deinit(&pkt);
            sent++;
            qdepth++;
        }
        off += len;
        drain();
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) if (ev.type == SDL_QUIT) secs = 0;
    }
    (void)fps_guess; (void)last_show; (void)now;
    double el = now() - t0;
    struct rusage ru1;
    getrusage(RUSAGE_SELF, &ru1);
    double cpu = (ru1.ru_utime.tv_sec - ru0.ru_utime.tv_sec) + (ru1.ru_utime.tv_usec - ru0.ru_utime.tv_usec) / 1e6 +
                 (ru1.ru_stime.tv_sec - ru0.ru_stime.tv_sec) + (ru1.ru_stime.tv_usec - ru0.ru_stime.tv_usec) / 1e6;
    printf("%.1f s: pictures %ld (%.1f/s, stream %.2f fps), decoded %ld (%.1f/s), shown %ld (%.1f/s), skipped %ld (%.1f%%); CPU %.0f%% of one core\n",
           el, pics, pics / el, fps, decoded, decoded / el, shown, shown / el, skipped, 100.0 * skipped / (pics ? pics : 1), 100 * cpu / el);
    mpi->reset(mctx);
    mpp_destroy(mctx);
    SDL_Quit();
    return 0;
}
