/* tvplay: plays one live channel on the cabinet (games/tv/PLAN.md).
 *
 *   tvplay URL            exit codes: 0 back to the list (2-player), 10 back to Home (hold 1P + 2P),
 *                         20 next channel (stick down), 21 previous channel (stick up),
 *                         30 no picture (could not open, or nothing to show in 12 s), 31 the stream ended,
 *                         32 a video format the VPU does not decode, 33 stalled (no new picture for 10 s
 *                         after playing: tvloop tunes the channel again)
 *
 * The stream (MPEG-TS over HTTPS, redirects followed) is demuxed by the cabinet's own libavformat. Video goes
 * to the VPU through Rockchip's MPP (H.264, HEVC, MPEG-2) into DRM buffers, which the GPU reads without a copy
 * (EGL dma-buf import, NV12) and draws upright and letterboxed for the portrait panel. Audio is decoded by
 * libavcodec, resampled to 44.1 kHz stereo and queued to SDL (ALSA, Home's dmix): its position is the clock.
 * A picture is shown when the clock reaches it; when the decoder falls behind, non-reference pictures are not
 * decoded (broadcast H.264/HEVC is 49-74 % non-reference: 1080p50/60 stays realtime at ~41-46 fps shown).
 * TVPLAY_LOG=path: a line every 5 s (shown, skipped, late, A/V, queues). */
#include <SDL2/SDL.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>
#include <math.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

#include "rk_mpi.h"
#include "mpp_buffer.h"
#include "mpp_frame.h"
#include "mpp_packet.h"

/* ------------------------------------------------------------------ EGL / GLES by hand */
typedef void *EGLDisplay, *EGLImageKHR, *EGLContext, *EGLClientBuffer;
typedef int32_t EGLint;
typedef unsigned int GLuint, GLenum, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef char GLchar;
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
static void (*glDeleteTextures_)(GLsizei, const GLuint *);
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
    if (!p) { fprintf(stderr, "tvplay: missing %s\n", name); exit(32); }
    return p;
}

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static FILE *logf_;
static void say(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void say(const char *fmt, ...)
{
    va_list ap;
    if (!logf_) return;
    va_start(ap, fmt);
    vfprintf(logf_, fmt, ap);
    va_end(ap);
    fputc('\n', logf_);
    fflush(logf_);
}

/* ------------------------------------------------------------------ packet queues */
typedef struct PNode { AVPacket *pkt; struct PNode *next; } PNode;
typedef struct {
    PNode *first, *last;
    int n;
    int64_t bytes;
    SDL_mutex *mu;
    SDL_cond *cv;
} PQueue;

static volatile int quitting, demux_done;

static void pq_init(PQueue *q) { memset(q, 0, sizeof *q); q->mu = SDL_CreateMutex(); q->cv = SDL_CreateCond(); }

static void pq_put(PQueue *q, AVPacket *pkt)
{
    PNode *n = malloc(sizeof *n);
    n->pkt = pkt;
    n->next = NULL;
    SDL_LockMutex(q->mu);
    if (q->last) q->last->next = n; else q->first = n;
    q->last = n;
    q->n++;
    q->bytes += pkt->size;
    SDL_CondSignal(q->cv);
    SDL_UnlockMutex(q->mu);
}

/* wait_ms < 0: wait until a packet or the end. Returns NULL when there is none. */
static AVPacket *pq_get(PQueue *q, int wait_ms)
{
    AVPacket *p = NULL;
    SDL_LockMutex(q->mu);
    while (!q->first && !quitting && !demux_done && wait_ms != 0) {
        if (wait_ms < 0) SDL_CondWait(q->cv, q->mu);
        else { SDL_CondWaitTimeout(q->cv, q->mu, wait_ms); break; }
    }
    if (q->first) {
        PNode *n = q->first;
        q->first = n->next;
        if (!q->first) q->last = NULL;
        q->n--;
        q->bytes -= n->pkt->size;
        p = n->pkt;
        free(n);
    }
    SDL_UnlockMutex(q->mu);
    return p;
}

static AVPacket *pq_peek(PQueue *q)
{
    AVPacket *p;
    SDL_LockMutex(q->mu);
    p = q->first ? q->first->pkt : NULL;
    SDL_UnlockMutex(q->mu);
    return p;
}

/* ------------------------------------------------------------------ the stream */

/* The cabinet's libavformat is Rockchip's build of FFmpeg 4.1.3, and its AVStream is not the vanilla layout:
 * codecpar is 8 bytes further on (184, not 176; measured 2026-10-27 with games/tv/proto/avprobe.c). So the
 * parameters are found at run time, at the header's offset or 8 past it, and accepted only where they agree with
 * the codec the library reports through its own API (av_find_best_stream's decoder). */
/* Can these bytes be read? (a pipe makes the kernel read them: EFAULT instead of a crash) */
static int readable(const void *p, size_t n)
{
    static int fds[2] = {-1, -1};
    char sink[64];
    if (fds[0] < 0 && pipe(fds) != 0) return 0;
    if (n > sizeof sink) n = sizeof sink;
    if (write(fds[1], p, n) != (ssize_t)n) return 0;
    return read(fds[0], sink, n) == (ssize_t)n;
}

static AVCodecParameters *stream_par(AVStream *st, enum AVCodecID want)
{
    static const int offs[] = {(int)offsetof(AVStream, codecpar) + 8, (int)offsetof(AVStream, codecpar)};
    for (unsigned i = 0; i < sizeof offs / sizeof *offs; i++) {
        AVCodecParameters *p = *(AVCodecParameters **)((char *)st + offs[i]);
        if (p && !((uintptr_t)p & 3) && readable(p, 8) && p->codec_id == want) return p;
    }
    return NULL;
}
static AVFormatContext *fmt;
static int vidx = -1, aidx = -1;
static PQueue vq, aq;
static double vtb, atb;                          /* time bases in seconds */


static volatile double aq_newest = -1;            /* stream time of the newest audio packet read */
static volatile double demux_slowest;
static volatile long long demux_bytes, demux_pkts;
static int demux_thread(void *arg)
{
    (void)arg;
    for (;;) {
        if (quitting) break;
        /* Back-pressure: a few seconds of stream is plenty (and RAM is short). */
        if (vq.bytes + aq.bytes > 6 * 1024 * 1024) { SDL_Delay(10); continue; }
        AVPacket *pkt = av_packet_alloc();
        double tr = now();
        int r = av_read_frame(fmt, pkt);
        tr = now() - tr;
        if (tr > demux_slowest) demux_slowest = tr;
        if (r >= 0) { demux_bytes += pkt->size; demux_pkts++; }
        if (r < 0) {
            av_packet_free(&pkt);
            say("demux: end of stream (%d)", r);
            break;
        }
        static int logged;
        if (logged < 3) {
            logged++;
            say("packet: stream %d size %d pts %lld dts %lld", pkt->stream_index, pkt->size, (long long)pkt->pts,
                (long long)pkt->dts);
        }
        if (pkt->stream_index == vidx) pq_put(&vq, pkt);
        else if (pkt->stream_index == aidx) {
            if (pkt->pts != AV_NOPTS_VALUE) aq_newest = pkt->pts * atb;
            pq_put(&aq, pkt);
        }
        else av_packet_free(&pkt);
    }
    demux_done = 1;
    SDL_CondBroadcast(vq.cv);
    SDL_CondBroadcast(aq.cv);
    return 0;
}

/* ------------------------------------------------------------------ audio: the clock */
static SDL_AudioDeviceID adev;
static AVCodecContext *actx;
static SwrContext *swr;
static volatile double audio_end_pts = -1;       /* stream time of the end of what is queued */
static volatile int audio_started;
#define OUT_RATE 44100
#define WAIT_MAX 4                                /* decoded frames waiting for their time */
#define PREBUFFER_S 3.0                           /* stream in hand before the picture starts (Skywave: 3 s) */
#define REBUFFER_S 2.0                            /* and after running dry */
static volatile int rebuffers;
#define OUT_BYTES_PER_SEC (OUT_RATE * 4)

static double audio_clock(void)
{
    if (!adev || audio_end_pts < 0) return -1;
    if (!audio_started && !rebuffers) return -1;      /* before the first start; when refilling, the clock holds */
    double queued = (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC;
    return audio_end_pts - queued - 0.09;          /* ~ALSA dmix and SDL buffers still to play */
}

/* Start (and restart after running dry) only with enough stream in hand: live channels arrive at about their
   own rate, so without a cushion every network hiccup stalls the picture (2026-10-27: 36 fps shown of 60, the
   queues always empty). */
static void maybe_start(void)
{
    if (audio_started) return;
    double ahead = audio_end_pts >= 0 && aq_newest >= 0 ? aq_newest - audio_end_pts : 0;
    ahead += (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC;
    if (ahead >= (rebuffers ? REBUFFER_S : PREBUFFER_S) || (demux_done && !aq.first)) {
        SDL_PauseAudioDevice(adev, 0);
        audio_started = 1;
        say("playing with %.1f s in hand%s", ahead, rebuffers ? " (after running dry)" : "");
    }
}

static int audio_thread(void *arg)
{
    (void)arg;
    AVFrame *fr = av_frame_alloc();
    uint8_t *out = NULL;
    int out_cap = 0;
    while (!quitting) {
        /* Ran dry (nothing queued, nothing read): stop the clock and fill up again. */
        if (audio_started && SDL_GetQueuedAudioSize(adev) == 0 && !aq.first && !demux_done) {
            SDL_PauseAudioDevice(adev, 1);
            audio_started = 0;
            rebuffers++;
            say("ran dry: filling up again (%d)", rebuffers);
        }
        /* Keep about half a second queued to the sound card; the rest waits as packets (the cushion). */
        if (adev && SDL_GetQueuedAudioSize(adev) > OUT_BYTES_PER_SEC / 2) { maybe_start(); SDL_Delay(10); continue; }
        AVPacket *pkt = pq_get(&aq, 50);
        if (!pkt) { if (demux_done && !aq.first) break; continue; }
        if (avcodec_send_packet(actx, pkt) == 0) {
            while (avcodec_receive_frame(actx, fr) == 0) {
                if (!swr) {
                    say("audio frame: %d Hz, %d channels, format %d, %d samples, pts %lld", fr->sample_rate, fr->channels,
                        fr->format, fr->nb_samples, (long long)fr->pts);
                    swr = swr_alloc_set_opts(NULL, AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, OUT_RATE,
                                             fr->channel_layout ? (int64_t)fr->channel_layout
                                                                : av_get_default_channel_layout(fr->channels),
                                             fr->format, fr->sample_rate, 0, NULL);
                    if (!swr || swr_init(swr) < 0) { say("audio: no resampler"); swr = NULL; break; }
                }
                int want = (int)av_rescale_rnd(swr_get_delay(swr, fr->sample_rate) + fr->nb_samples, OUT_RATE,
                                               fr->sample_rate, AV_ROUND_UP);
                if (want * 4 > out_cap) { out_cap = want * 4; out = realloc(out, out_cap); }
                uint8_t *planes[1] = {out};
                int got = swr_convert(swr, planes, want, (const uint8_t **)fr->extended_data, fr->nb_samples);
                if (got > 0) {
                    SDL_QueueAudio(adev, out, got * 4);
                    if (fr->pts != AV_NOPTS_VALUE)
                        audio_end_pts = fr->pts * atb + (double)fr->nb_samples / fr->sample_rate;
                }
            }
        }
        av_packet_free(&pkt);
        maybe_start();
    }
    av_frame_free(&fr);
    free(out);
    return 0;
}

/* ------------------------------------------------------------------ video */
static MppCtx mctx;
static MppApi *mpi;
static MppBufferGroup grp;
static int hevc;
static SDL_Window *win;
static int ww, wh;

#define MAX_IMAGES 40
static struct { int fd; EGLImageKHR img; GLuint tex; } images[MAX_IMAGES];
static int nimages;

static void forget_images(void)
{
    for (int i = 0; i < nimages; i++) {
        glDeleteTextures_(1, &images[i].tex);
        eglDestroyImageKHR_(eglGetCurrentDisplay_(), images[i].img);
    }
    nimages = 0;
}

static GLuint texture_for(MppFrame f)
{
    MppBuffer b = mpp_frame_get_buffer(f);
    int fd = mpp_buffer_get_fd(b);
    for (int i = 0; i < nimages; i++)
        if (images[i].fd == fd) return images[i].tex;
    if (nimages == MAX_IMAGES) forget_images();
    int w = mpp_frame_get_width(f), h = mpp_frame_get_height(f);
    int hs = mpp_frame_get_hor_stride(f), vs = mpp_frame_get_ver_stride(f);
    EGLint attr[] = {
        EGL_WIDTH, w, EGL_HEIGHT, h, EGL_LINUX_DRM_FOURCC_EXT, DRM_FORMAT_NV12,
        EGL_DMA_BUF_PLANE0_FD_EXT, fd, EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0, EGL_DMA_BUF_PLANE0_PITCH_EXT, hs,
        EGL_DMA_BUF_PLANE1_FD_EXT, fd, EGL_DMA_BUF_PLANE1_OFFSET_EXT, hs * vs, EGL_DMA_BUF_PLANE1_PITCH_EXT, hs,
        EGL_YUV_COLOR_SPACE_HINT_EXT, EGL_ITU_REC709_EXT, EGL_SAMPLE_RANGE_HINT_EXT, EGL_YUV_NARROW_RANGE_EXT,
        EGL_NONE};
    EGLImageKHR img = eglCreateImageKHR_(eglGetCurrentDisplay_(), NULL, EGL_LINUX_DMA_BUF_EXT, NULL, attr);
    if (!img) {
        attr[18] = EGL_NONE;
        img = eglCreateImageKHR_(eglGetCurrentDisplay_(), NULL, EGL_LINUX_DMA_BUF_EXT, NULL, attr);
    }
    if (!img) { say("video: EGL import failed 0x%x", eglGetError_()); return 0; }
    GLuint tex;
    glGenTextures_(1, &tex);
    glBindTexture_(GL_TEXTURE_EXTERNAL_OES, tex);
    glTexParameteri_(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri_(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glEGLImageTargetTexture2DOES_(GL_TEXTURE_EXTERNAL_OES, img);
    images[nimages].fd = fd;
    images[nimages].img = img;
    images[nimages].tex = tex;
    return images[nimages++].tex;
}

/* Non-reference picture? (the first slice's NAL header in an Annex-B access unit) */
static int nonref(const uint8_t *p, int n)
{
    for (int i = 0; i + 4 < n; i++) {
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

/* SDL joystick buttons on the deck (games/love/yard/input.lua, 0-based): lower 0, 1P 6, 2P 7, up 15, down 18. */
enum { B_LOW = 0, B_1P = 6, B_2P = 7, B_UP = 15, B_LEFT = 16, B_RIGHT = 17, B_DOWN = 18 };

#include "tvview.c"

static void gl_setup(void)
{
    eglGetCurrentDisplay_ = gl("eglGetCurrentDisplay");
    eglCreateImageKHR_ = gl("eglCreateImageKHR");
    eglDestroyImageKHR_ = gl("eglDestroyImageKHR");
    eglGetError_ = gl("eglGetError");
    glEGLImageTargetTexture2DOES_ = gl("glEGLImageTargetTexture2DOES");
    glGenTextures_ = gl("glGenTextures"); glDeleteTextures_ = gl("glDeleteTextures");
    glBindTexture_ = gl("glBindTexture"); glTexParameteri_ = gl("glTexParameteri");
    glCreateShader_ = gl("glCreateShader"); glShaderSource_ = gl("glShaderSource"); glCompileShader_ = gl("glCompileShader");
    glGetShaderiv_ = gl("glGetShaderiv"); glGetShaderInfoLog_ = gl("glGetShaderInfoLog");
    glCreateProgram_ = gl("glCreateProgram"); glAttachShader_ = gl("glAttachShader"); glLinkProgram_ = gl("glLinkProgram");
    glUseProgram_ = gl("glUseProgram"); glBindAttribLocation_ = gl("glBindAttribLocation");
    glVertexAttribPointer_ = gl("glVertexAttribPointer"); glEnableVertexAttribArray_ = gl("glEnableVertexAttribArray");
    glDrawArrays_ = gl("glDrawArrays"); glClearColor_ = gl("glClearColor"); glClear_ = gl("glClear");
    glViewport_ = gl("glViewport"); glActiveTexture_ = gl("glActiveTexture");
    glGetUniformLocation_ = gl("glGetUniformLocation"); glUniform1i_ = gl("glUniform1i");
    view_init();
}

/* ------------------------------------------------------------------ input */
static int down1p, down2p, both_seen;
static double both_since;

/* Returns an exit code, or -1 to keep playing. */
static int handle_input(void)
{
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
        int b = -1, pressed = 0;
        if (ev.type == SDL_QUIT) return 0;
        if (ev.type == SDL_JOYBUTTONDOWN || ev.type == SDL_JOYBUTTONUP) {
            b = ev.jbutton.button;
            pressed = ev.type == SDL_JOYBUTTONDOWN;
        } else if (ev.type == SDL_KEYDOWN || ev.type == SDL_KEYUP) {
            SDL_Keycode k = ev.key.keysym.sym;
            pressed = ev.type == SDL_KEYDOWN;
            if (ev.key.repeat) continue;
            b = k == SDLK_1 ? B_1P : k == SDLK_2 ? B_2P : k == SDLK_UP ? B_UP : k == SDLK_DOWN ? B_DOWN
                : k == SDLK_ESCAPE ? B_2P : k == SDLK_LEFT ? B_LEFT : k == SDLK_RIGHT ? B_RIGHT : k == SDLK_SPACE ? B_LOW : -1;
        }
        if (b == B_1P) down1p = pressed;
        if (b == B_2P) {
            down2p = pressed;
            /* 2-player alone, let go: back to the list. */
            if (!pressed && !both_seen) return 0;
        }
        if (down1p && down2p && !both_seen) { both_seen = 1; both_since = now(); }
        if (!down1p && !down2p) both_seen = 0;
        if (pressed) view_button(b);
        if (pressed && b == B_DOWN) return 20;
        if (pressed && b == B_UP) return 21;
    }
    if (both_seen && down1p && down2p && now() - both_since >= 1.0) return 10;
    return -1;
}

/* ------------------------------------------------------------------ main */
int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: tvplay URL\n"); return 2; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: main\n");
    const char *lp = getenv("TVPLAY_LOG");
    logf_ = lp ? fopen(lp, "a") : stderr;
    double t_start = now();

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) != 0) { say("SDL: %s", SDL_GetError()); return 30; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "for (int i = 0; i < SDL_NumJoy");
    for (int i = 0; i < SDL_NumJoysticks(); i++) SDL_JoystickOpen(i);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    /* The screen first: the channel's bands and "TUNING IN..." are up before the stream is asked for. */
    win = SDL_CreateWindow("tv", 0, 0, 1024, 768, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP);
    SDL_GLContext glc = win ? SDL_GL_CreateContext(win) : NULL;
    if (!glc) { say("GL: %s", SDL_GetError()); return 30; }
    SDL_GL_SetSwapInterval(1);
    SDL_GL_GetDrawableSize(win, &ww, &wh);
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "gl_setup();");
    gl_setup();
    draw_tuning(0);

    /* Open the stream. */
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "avformat_network_init();");
    avformat_network_init();
    AVDictionary *o = NULL;
    av_dict_set(&o, "rw_timeout", "8000000", 0);
    av_dict_set(&o, "reconnect", "1", 0);
    av_dict_set(&o, "reconnect_streamed", "1", 0);
    av_dict_set(&o, "reconnect_delay_max", "4", 0);
    av_dict_set(&o, "user_agent", "Partycade/1.0", 0);
    /* Options by name only: the cabinet's libavformat is Rockchip's FFmpeg 4.1 build, and writing fields of its
       structs from vanilla 4.1.11 headers (probesize, interrupt_callback) crashed find_stream_info. */
    av_dict_set(&o, "probesize", "600000", 0);
    av_dict_set(&o, "analyzeduration", "800000", 0);
    fmt = NULL;
    if (avformat_open_input(&fmt, argv[1], NULL, &o) < 0) { say("could not open the stream"); return 30; }
    av_dict_free(&o);
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "if (avformat_find_stream_info(");
    if (avformat_find_stream_info(fmt, NULL) < 0) { say("no stream info"); return 30; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "AVCodec *vdec = NULL, *adec ");
    AVCodec *vdec = NULL, *adec = NULL;
    vidx = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, &vdec, 0);
    aidx = av_find_best_stream(fmt, AVMEDIA_TYPE_AUDIO, -1, vidx, &adec, 0);
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "if (vidx < 0 || !vdec)");
    if (vidx < 0 || !vdec) { say("no video"); return 30; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "AVCodecParameters *vp = stre");
    AVCodecParameters *vp = stream_par(fmt->streams[vidx], vdec->id);
    if (!vp) { say("video parameters not found (library layout)"); return 32; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "MppCodingType coding;");
    MppCodingType coding;
    if (vp->codec_id == AV_CODEC_ID_H264) coding = MPP_VIDEO_CodingAVC;
    else if (vp->codec_id == AV_CODEC_ID_HEVC) coding = MPP_VIDEO_CodingHEVC, hevc = 1;
    else if (vp->codec_id == AV_CODEC_ID_MPEG2VIDEO) coding = MPP_VIDEO_CodingMPEG2;
    else { say("video %s: not for the VPU", avcodec_get_name(vp->codec_id)); return 32; }
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "vtb = av_q2d(");
    vtb = av_q2d(fmt->streams[vidx]->time_base);
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "double sar =");
    double sar = 1;                               /* from the decoder's frames (the parameters' layout differs) */
    if (getenv("TVPLAY_TRACE")) fprintf(stderr, "trace: before %s\n", "say(open .1f s");
    say("open %.1f s: video %s, audio %s", now() - t_start, avcodec_get_name(vp->codec_id),
        aidx >= 0 && adec ? adec->name : "none");


    if (aidx >= 0) {
        AVCodecParameters *ap = adec ? stream_par(fmt->streams[aidx], adec->id) : NULL;
        AVCodec *ac = ap ? avcodec_find_decoder(ap->codec_id) : NULL;
        actx = ac ? avcodec_alloc_context3(ac) : NULL;
        if (!actx || avcodec_parameters_to_context(actx, ap) < 0 || avcodec_open2(actx, ac, NULL) < 0) {
            say("audio decoder failed: playing without sound");
            aidx = -1;
        } else {
            atb = av_q2d(fmt->streams[aidx]->time_base);
            SDL_AudioSpec want = {0}, have;
            want.freq = OUT_RATE;
            want.format = AUDIO_S16SYS;
            want.channels = 2;
            want.samples = 1024;
            adev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
            if (!adev) { say("audio device: %s: playing without sound", SDL_GetError()); aidx = -1; }
        }
    }

    if (mpp_create(&mctx, &mpi) || mpp_init(mctx, MPP_CTX_DEC, coding)) { say("MPP init failed"); return 32; }

    pq_init(&vq);
    pq_init(&aq);
    SDL_Thread *dt = SDL_CreateThread(demux_thread, "demux", NULL);
    SDL_Thread *at = aidx >= 0 ? SDL_CreateThread(audio_thread, "audio", NULL) : NULL;

    /* The display queue: decoded frames waiting for their time, and the one on the screen (the GPU reads it). */
    MppFrame waiting[WAIT_MAX];
    int nwait = 0;
    MppFrame on_screen = NULL;
    double wall0 = -1, pts0 = 0;                  /* no audio: the clock is the wall clock from the first picture */
    long shown = 0, skipped = 0, late = 0, sent = 0;
    double lead = 0.0;                            /* see the decoder feed below */
    int on_time = 0;
    double last_report = now(), first_pic = -1, last_tuning = 0, last_shown = 0, draw_sum = 0, draw_max = 0;
    long shown_at_report = 0;
    int code = -1;
    struct rusage ru0;
    getrusage(RUSAGE_SELF, &ru0);

    while (code < 0) {
        code = handle_input();
        if (code >= 0) break;
        double clock;
        if (aidx >= 0) clock = audio_clock();
        else clock = wall0 < 0 ? -1 : pts0 + (now() - wall0);

        /* Feed the decoder: a picture whose time has passed (the decoder is behind) is skipped if nothing refers to it. */
        for (int fed = 0; fed < 4; fed++) {
            AVPacket *pkt = pq_peek(&vq);
            if (!pkt) break;
            double pts = pkt->pts != AV_NOPTS_VALUE ? pkt->pts * vtb : (pkt->dts != AV_NOPTS_VALUE ? pkt->dts * vtb : -1);
            /* "lead": how far ahead of the clock a picture must be to be worth decoding. It grows when decoded
               frames come out too late to show (the decoder's own latency, ~100 ms at 1080p) and eases off when
               all is on time, so the decoder's time goes to pictures that will be seen. */
            if (clock >= 0 && pts >= 0 && pts < clock + lead && nonref(pkt->data, pkt->size)) {
                pkt = pq_get(&vq, 0);
                av_packet_free(&pkt);
                skipped++;
                continue;
            }
            MppPacket mp;
            mpp_packet_init(&mp, pkt->data, pkt->size);
            mpp_packet_set_pts(mp, pts >= 0 ? (RK_S64)(pts * 1e6) : -1);
            MPP_RET r = mpi->decode_put_packet(mctx, mp);
            mpp_packet_deinit(&mp);
            if (r != MPP_OK) break;               /* full: try again after taking frames */
            pkt = pq_get(&vq, 0);
            av_packet_free(&pkt);
            sent++;
        }

        /* Take decoded frames. */
        while (nwait < WAIT_MAX) {
            MppFrame f = NULL;
            if (mpi->decode_get_frame(mctx, &f) != MPP_OK || !f) break;
            if (mpp_frame_get_info_change(f)) {
                if (!grp) mpp_buffer_group_get_internal(&grp, MPP_BUFFER_TYPE_DRM);
                /* Enough for the reference pictures plus a few waiting: the buffers are RAM (118 MB in all). */
                int size = mpp_frame_get_buf_size(f);
                /* Reference pictures (H.264 level 4 at 1080p: 4; HEVC: 6) + those waiting + the one on the
                   screen + the one being decoded. At 1080p each is ~4 MB, and the cabinet has 118 MB in all. */
                mpp_buffer_group_limit_config(grp, size, (hevc ? 6 : 5) + WAIT_MAX + 2);
                mpi->control(mctx, MPP_DEC_SET_EXT_BUF_GROUP, grp);
                mpi->control(mctx, MPP_DEC_SET_INFO_CHANGE_READY, NULL);
                forget_images();
                if (mpp_frame_get_width(f) > 1920 || mpp_frame_get_height(f) > 1088) {
                    say("video %dx%d: beyond the VPU", mpp_frame_get_width(f), mpp_frame_get_height(f));
                    code = 32;
                }
                {
                    MppFrameRational r = mpp_frame_get_sar(f);
                    sar = r.num > 0 && r.den > 0 ? (double)r.num / r.den : 1;
                }
                say("stream %dx%d (stride %d x %d), frame buffers %d KB each", mpp_frame_get_width(f),
                    mpp_frame_get_height(f), mpp_frame_get_hor_stride(f), mpp_frame_get_ver_stride(f), size / 1024);
                mpp_frame_deinit(&f);
            } else if (mpp_frame_get_buffer(f) && !mpp_frame_get_errinfo(f) && !mpp_frame_get_discard(f)) {
                waiting[nwait++] = f;
            } else {
                mpp_frame_deinit(&f);
            }
        }

        /* Frames more than 50 ms late are dropped unseen; then the oldest one whose time has come is shown (one
           per screen refresh: showing the newest of two due frames dropped a frame every few). */
        int show = -1;
        if (clock >= 0) {
            while (nwait > 1 && mpp_frame_get_pts(waiting[0]) / 1e6 < clock - 0.05 &&
                   mpp_frame_get_pts(waiting[1]) / 1e6 <= clock + 0.008) {
                mpp_frame_deinit(&waiting[0]);
                memmove(waiting, waiting + 1, (nwait - 1) * sizeof waiting[0]);
                nwait--;
                late++;
                lead = lead + 0.02 > 0.4 ? 0.4 : lead + 0.02;
                on_time = 0;
            }
            if (nwait > 0 && mpp_frame_get_pts(waiting[0]) / 1e6 <= clock + 0.008) show = 0;
        } else if (shown == 0 && aidx < 0 && nwait > 0) {
            show = 0;                             /* no sound: the first picture starts the clock */
        }
        if (show >= 0) {
            for (int i = 0; i < show; i++) { mpp_frame_deinit(&waiting[i]); late++; }
            MppFrame f = waiting[show];
            if (wall0 < 0) { wall0 = now(); pts0 = mpp_frame_get_pts(f) / 1e6; }
            double td = now();
            draw(f, sar);
            td = now() - td;
            draw_sum += td;
            if (td > draw_max) draw_max = td;
            if (++on_time >= 90) { on_time = 0; lead = lead - 0.01 < -0.04 ? -0.04 : lead - 0.01; }
            last_shown = now();
            if (first_pic < 0) { first_pic = now(); view_first_picture(); say("first picture %.1f s after start", first_pic - t_start); }
            if (on_screen) mpp_frame_deinit(&on_screen);
            on_screen = f;
            shown++;
            memmove(waiting, waiting + show + 1, (nwait - show - 1) * sizeof waiting[0]);
            nwait -= show + 1;
        } else {
            if (first_pic < 0 && now() - last_tuning >= 0.05) { last_tuning = now(); draw_tuning(now() - t_start); }
            else SDL_Delay(2);
        }

        /* Nothing to show for 12 s: give up (a dead channel, or the panel's placeholder). */
        if (first_pic < 0 && now() - t_start > 12) { say("no picture in 12 s"); code = 30; }
        /* Stalled: the panel stopped sending, or came back with timestamps that no longer meet the sound's
           (2026-11-01: ESPN ran dry, then sat 30 s with A/V +22 s and 6 MB queued, showing nothing). */
        if (first_pic >= 0 && now() - last_shown > 10) { say("stalled: no picture for 10 s"); code = 33; }
        if (demux_done && !vq.first && nwait == 0 && first_pic >= 0) { say("the stream ended"); code = 31; }
        if (now() - last_report >= 5) {
            last_report = now();
            say("t %.0f: shown %ld skipped %ld late %ld sent %ld lead %.2f; A/V %+.2f s; queues video %d (%lld KB) audio %d;"
                " read %lld KB in %lld packets, slowest read %.0f ms; audio queued %.2f s; draw %.1f ms (max %.0f)",
                now() - t_start, shown, skipped, late, sent, lead,
                nwait && clock >= 0 ? mpp_frame_get_pts(waiting[0]) / 1e6 - clock : 0.0, vq.n,
                (long long)vq.bytes / 1024, aq.n, demux_bytes / 1024, demux_pkts, demux_slowest * 1000,
                adev ? (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC : 0.0,
                shown > shown_at_report ? 1000 * draw_sum / (shown - shown_at_report) : 0.0, 1000 * draw_max);
            shown_at_report = shown;
            draw_sum = draw_max = 0;
            demux_bytes = demux_pkts = 0;
            demux_slowest = 0;
        }
    }

    struct rusage ru1;
    getrusage(RUSAGE_SELF, &ru1);
    double el = now() - t_start;
    double cpu = (ru1.ru_utime.tv_sec - ru0.ru_utime.tv_sec) + (ru1.ru_utime.tv_usec - ru0.ru_utime.tv_usec) / 1e6 +
                 (ru1.ru_stime.tv_sec - ru0.ru_stime.tv_sec) + (ru1.ru_stime.tv_usec - ru0.ru_stime.tv_usec) / 1e6;
    say("exit %d after %.0f s: shown %ld (%.1f/s), skipped %ld, late %ld; CPU %.0f%% of a core", code, el, shown,
        shown / (el > 0 ? el : 1), skipped, late, 100 * cpu / (el > 0 ? el : 1));
    quitting = 1;
    SDL_CondBroadcast(vq.cv);
    SDL_CondBroadcast(aq.cv);
    if (adev) SDL_PauseAudioDevice(adev, 1);
    /* Leave quickly: the next program wants the screen; the kernel frees the rest. */
    (void)dt; (void)at;
    fflush(logf_);
    _exit(code);
}
