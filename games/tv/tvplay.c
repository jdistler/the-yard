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
    fprintf(logf_, "%.2f ", now());               /* (the monotonic clock: /proc/uptime's, as Home's log) */
    vfprintf(logf_, fmt, ap);
    va_end(ap);
    fputc('\n', logf_);
    fflush(logf_);
}

/* ------------------------------------------------------------------ a channel's stream: the session */
/* Everything one channel's stream needs lives in a Session, shared by its threads. Changing channel starts a new
 * one in the same process (the screen, the GPU and the sound card stay open: no black between channels). The old
 * one's reader may be stuck in a network read for a while: it finishes on its own and the last of the two (the
 * player or its reader) frees the session. */
typedef struct PNode { AVPacket *pkt; struct PNode *next; } PNode;
typedef struct {
    PNode *first, *last;
    int n;
    int64_t bytes;
    SDL_mutex *mu;
    SDL_cond *cv;
} PQueue;

typedef struct Session {
    AVFormatContext *fmt;
    int vidx, aidx;
    double vtb, atb;                              /* time bases in seconds */
    PQueue vq, aq;
    volatile int quitting, demux_done;
    volatile double aq_newest;                    /* stream time of the newest audio packet read */
    volatile double demux_slowest;
    volatile long long demux_bytes, demux_pkts;
    volatile long corrupt_pkts, pts_jumps;        /* damaged packets (the demuxer's flag); video time jumps */
    volatile int restart_video;                   /* a jump in the stream: the decoder starts again at a keyframe */
    AVCodecContext *actx;
    SwrContext *swr;
    volatile double audio_end_pts;                /* stream time of the end of what is queued */
    volatile int audio_started, rebuffers;
    SDL_atomic_t refs;
} Session;

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
static AVPacket *pq_get(Session *s, PQueue *q, int wait_ms)
{
    AVPacket *p = NULL;
    SDL_LockMutex(q->mu);
    while (!q->first && !s->quitting && !s->demux_done && wait_ms != 0) {
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

static void pq_free(PQueue *q)
{
    while (q->first) {
        PNode *n = q->first;
        q->first = n->next;
        av_packet_free(&n->pkt);
        free(n);
    }
    SDL_DestroyCond(q->cv);
    SDL_DestroyMutex(q->mu);
}

static Session *session_new(void)
{
    Session *s = calloc(1, sizeof *s);
    s->vidx = s->aidx = -1;
    s->aq_newest = s->audio_end_pts = -1;
    pq_init(&s->vq);
    pq_init(&s->aq);
    SDL_AtomicSet(&s->refs, 1);
    return s;
}

static void session_release(Session *s)
{
    if (!SDL_AtomicDecRef(&s->refs)) return;
    pq_free(&s->vq);
    pq_free(&s->aq);
    if (s->fmt) avformat_close_input(&s->fmt);
    if (s->actx) avcodec_free_context(&s->actx);
    if (s->swr) swr_free(&s->swr);
    free(s);
}

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

static int demux_thread(void *arg)
{
    Session *s = arg;
    int logged = 0;
    double last_v = -1;
    for (;;) {
        if (s->quitting) break;
        /* Back-pressure: a few seconds of stream is plenty (and RAM is short). */
        if (s->vq.bytes + s->aq.bytes > 6 * 1024 * 1024) { SDL_Delay(10); continue; }
        AVPacket *pkt = av_packet_alloc();
        double tr = now();
        int r = av_read_frame(s->fmt, pkt);
        tr = now() - tr;
        if (tr > s->demux_slowest) s->demux_slowest = tr;
        if (r < 0) {
            av_packet_free(&pkt);
            if (!s->quitting) say("demux: end of stream (%d)", r);
            break;
        }
        s->demux_bytes += pkt->size;
        s->demux_pkts++;
        if (logged < 3) {
            logged++;
            say("packet: stream %d size %d pts %lld dts %lld", pkt->stream_index, pkt->size, (long long)pkt->pts,
                (long long)pkt->dts);
        }
        if (pkt->flags & AV_PKT_FLAG_CORRUPT) s->corrupt_pkts++;
        if (pkt->stream_index == s->vidx) {
            double t = pkt->dts != AV_NOPTS_VALUE ? pkt->dts * s->vtb : -1;
            if (t >= 0 && last_v >= 0 && (t < last_v - 0.5 || t > last_v + 1.0)) {
                s->pts_jumps++;
                s->restart_video = 1;
                say("video time jumps %.2f -> %.2f s: starting again at the next keyframe", last_v, t);
            }
            if (t >= 0) last_v = t;
            pq_put(&s->vq, pkt);
        } else if (pkt->stream_index == s->aidx) {
            if (pkt->pts != AV_NOPTS_VALUE) s->aq_newest = pkt->pts * s->atb;
            pq_put(&s->aq, pkt);
        } else av_packet_free(&pkt);
    }
    s->demux_done = 1;
    SDL_CondBroadcast(s->vq.cv);
    SDL_CondBroadcast(s->aq.cv);
    session_release(s);
    return 0;
}

/* ------------------------------------------------------------------ audio: the clock */
static SDL_AudioDeviceID adev;                    /* opened once, kept across channels */
#define OUT_RATE 44100
#define WAIT_MAX 4                                /* decoded frames waiting for their time */
#define KEEP_SHOWN 2                              /* pictures already replaced on the screen, kept two flips more */
/* Stream in hand before the picture starts. 3 s until 2026-11-25 (Skywave's); but the gate sends its backlog in
   a burst and the queue goes on filling to its 6 MB (~8 s) within a second of starting, so 1.5 s costs no
   cushion and starts every channel ~0.4 s sooner. */
#define PREBUFFER_S 1.5
#define REBUFFER_S 2.0                            /* and after running dry */
#define OUT_BYTES_PER_SEC (OUT_RATE * 4)

static double audio_clock(Session *s)
{
    if (!adev || s->audio_end_pts < 0) return -1;
    if (!s->audio_started && !s->rebuffers) return -1;  /* before the first start; when refilling, the clock holds */
    double queued = (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC;
    return s->audio_end_pts - queued - 0.09;       /* ~ALSA dmix and SDL buffers still to play */
}

/* The clock the pictures follow: the audio position, smoothed. The audio position moves in steps (it is read
   from what is still queued, which drains a sound-card period at a time, ~23 ms), and pictures timed by it on
   a 60 Hz screen came 1, 3, 2, 2, 1, 3 refreshes apart instead of 2, 2, 2 for a 30 fps channel (judder,
   measured 2026-11-25). Here the clock runs on the monotonic timer and is steered gently toward the audio
   (2 % of the difference each frame); a difference over 80 ms (a jump, a refill) resets it. */
static double sm_pts = -1, sm_wall;
static double picture_clock(Session *s)
{
    double raw = audio_clock(s);
    if (raw < 0 || !s->audio_started) { sm_pts = -1; return raw; }   /* before playing, or refilling: as is */
    double t = now();
    if (sm_pts < 0) { sm_pts = raw; sm_wall = t; return raw; }
    double c = sm_pts + (t - sm_wall);
    double d = raw - c;
    if (d > 0.08 || d < -0.08) { sm_pts = raw; sm_wall = t; return raw; }
    sm_pts += d * 0.02;
    return sm_pts + (t - sm_wall);
}

/* Start (and restart after running dry) only with enough stream in hand: live channels arrive at about their
   own rate, so without a cushion every network hiccup stalls the picture (2026-10-27: 36 fps shown of 60, the
   queues always empty). */
static void maybe_start(Session *s)
{
    if (s->audio_started || s->quitting) return;
    double ahead = s->audio_end_pts >= 0 && s->aq_newest >= 0 ? s->aq_newest - s->audio_end_pts : 0;
    ahead += (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC;
    if (ahead >= (s->rebuffers ? REBUFFER_S : PREBUFFER_S) || (s->demux_done && !s->aq.first)) {
        SDL_PauseAudioDevice(adev, 0);
        s->audio_started = 1;
        say("playing with %.1f s in hand%s", ahead, s->rebuffers ? " (after running dry)" : "");
    }
}

static int audio_thread(void *arg)
{
    Session *s = arg;
    AVFrame *fr = av_frame_alloc();
    uint8_t *out = NULL;
    int out_cap = 0;
    while (!s->quitting) {
        /* Ran dry (nothing queued, nothing read): stop the clock and fill up again. */
        if (s->audio_started && SDL_GetQueuedAudioSize(adev) == 0 && !s->aq.first && !s->demux_done) {
            SDL_PauseAudioDevice(adev, 1);
            s->audio_started = 0;
            s->rebuffers++;
            say("ran dry: filling up again (%d)", s->rebuffers);
        }
        /* Keep about half a second queued to the sound card; the rest waits as packets (the cushion). */
        if (SDL_GetQueuedAudioSize(adev) > OUT_BYTES_PER_SEC / 2) { maybe_start(s); SDL_Delay(10); continue; }
        AVPacket *pkt = pq_get(s, &s->aq, 50);
        if (!pkt) { if (s->demux_done && !s->aq.first) break; continue; }
        if (avcodec_send_packet(s->actx, pkt) == 0) {
            while (avcodec_receive_frame(s->actx, fr) == 0) {
                if (!s->swr) {
                    say("audio frame: %d Hz, %d channels, format %d, %d samples, pts %lld", fr->sample_rate, fr->channels,
                        fr->format, fr->nb_samples, (long long)fr->pts);
                    s->swr = swr_alloc_set_opts(NULL, AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, OUT_RATE,
                                                fr->channel_layout ? (int64_t)fr->channel_layout
                                                                   : av_get_default_channel_layout(fr->channels),
                                                fr->format, fr->sample_rate, 0, NULL);
                    if (!s->swr || swr_init(s->swr) < 0) { say("audio: no resampler"); if (s->swr) swr_free(&s->swr); break; }
                }
                int want = (int)av_rescale_rnd(swr_get_delay(s->swr, fr->sample_rate) + fr->nb_samples, OUT_RATE,
                                               fr->sample_rate, AV_ROUND_UP);
                if (want * 4 > out_cap) { out_cap = want * 4; out = realloc(out, out_cap); }
                uint8_t *planes[1] = {out};
                int got = swr_convert(s->swr, planes, want, (const uint8_t **)fr->extended_data, fr->nb_samples);
                if (got > 0 && !s->quitting) {
                    SDL_QueueAudio(adev, out, got * 4);
                    if (fr->pts != AV_NOPTS_VALUE)
                        s->audio_end_pts = fr->pts * s->atb + (double)fr->nb_samples / fr->sample_rate;
                }
            }
        }
        av_packet_free(&pkt);
        maybe_start(s);
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

/* May this picture go undecoded without harm to any other? (the first slice's NAL header in an Annex-B access
 * unit). H.264: nal_ref_idc 0. HEVC: a sub-layer non-reference picture (TRAIL_N, TSA_N, STSA_N, RADL_N, RASL_N)
 * is safe only in the highest temporal sub-layer: a lower one's can still be referenced by the pictures of the
 * layers above it (dropping those broke the picture into blocks until the next keyframe). So HEVC pictures are
 * dropped only once 60 have been seen (to know the highest layer) and only from that layer. */
static int hevc_max_tid = -1, hevc_seen;
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
                if (t <= 21) {
                    int tid = (p[i + 4] & 7) - 1;
                    if (tid > hevc_max_tid) hevc_max_tid = tid;
                    hevc_seen++;
                    return hevc_seen > 60 && t <= 14 && t % 2 == 0 && tid == hevc_max_tid;
                }
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

/* ------------------------------------------------------------------ the channel list */
/* TVPLAY_LIST (Home's play.tsv): "index<TAB>row name<TAB>logo directory", then a line per channel: "playlist<TAB>
 * stream id<TAB>name<TAB>guide id<TAB>logo key". The address comes from TVPLAY_ACCOUNT (account.conf: name, server,
 * user, password, tab-separated): the password stays in that file and this process, never on a command line. */
typedef struct { char pl[64], sid[32], name[160], epgid[160], key[160]; } Channel;
static Channel *chans;
static int nchans, chan_idx;                      /* 0-based */
static char group_name[160], logos_dir[512];

static void cut_tab(char *line, char **f, int nf)
{
    for (int i = 0; i < nf; i++) f[i] = (char *)"";
    char *p = line;
    for (int i = 0; i < nf && p; i++) {
        f[i] = p;
        p = strchr(p, '\t');
        if (p) *p++ = 0;
    }
    for (int i = 0; i < nf; i++) { char *e = strpbrk(f[i], "\r\n"); if (e) *e = 0; }
}

static int list_load(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    char *line = NULL;
    size_t cap = 0;
    int first = 1, start = 1;
    while (getline(&line, &cap, f) > 0) {
        char *fl[5];
        cut_tab(line, fl, 5);
        if (first) {
            first = 0;
            start = atoi(fl[0]);
            snprintf(group_name, sizeof group_name, "%s", fl[1]);
            snprintf(logos_dir, sizeof logos_dir, "%s", fl[2]);
            continue;
        }
        if (!*fl[0] || !*fl[1]) continue;
        chans = realloc(chans, (nchans + 1) * sizeof *chans);
        Channel *c = &chans[nchans++];
        snprintf(c->pl, sizeof c->pl, "%s", fl[0]);
        snprintf(c->sid, sizeof c->sid, "%s", fl[1]);
        snprintf(c->name, sizeof c->name, "%s", fl[2]);
        snprintf(c->epgid, sizeof c->epgid, "%s", fl[3]);
        snprintf(c->key, sizeof c->key, "%s", fl[4]);
    }
    free(line);
    fclose(f);
    chan_idx = start >= 1 && start <= nchans ? start - 1 : 0;
    return nchans;
}

static int channel_url(const Channel *c, char *url, size_t n)
{
    const char *path = getenv("TVPLAY_ACCOUNT");
    FILE *f = fopen(path ? path : "/data/tv/account.conf", "r");
    if (!f) return 0;
    char *line = NULL;
    size_t cap = 0;
    int ok = 0;
    while (!ok && getline(&line, &cap, f) > 0) {
        if (line[0] == '#') continue;
        char *fl[4];
        cut_tab(line, fl, 4);
        if (!strcmp(fl[0], c->pl) && *fl[1]) {
            snprintf(url, n, "%s/live/%s/%s/%s.ts", fl[1], fl[2], fl[3], c->sid);
            ok = 1;
        }
    }
    free(line);
    fclose(f);
    return ok;
}

/* The bands for channel i: name, the line under it, logo, guide. */
static void show_channel(int i)
{
    const Channel *c = &chans[i];
    char sub[400], logo[700], epg[700], pl[64];
    snprintf(pl, sizeof pl, "%s", c->pl);
    for (char *p = pl; *p; p++) if (*p == '_') *p = ' ';
    snprintf(sub, sizeof sub, "%s \xc2\xb7 %s%s%d of %d", pl, group_name, *group_name ? " \xc2\xb7 " : "", i + 1, nchans);
    snprintf(logo, sizeof logo, "%s/%s.rgba", logos_dir, c->key);
    const char *ed = getenv("TVPLAY_EPGDIR");
    snprintf(epg, sizeof epg, "%s/%s/epg.tsv", ed ? ed : "/tmp/tv", c->pl);
    view_set_channel(c->name, sub, *c->key ? logo : NULL, epg, c->epgid);
}

/* ------------------------------------------------------------------ one channel, played */
static MppFrame shown_ring[KEEP_SHOWN], on_screen;

/* Plays url until the viewer or the stream ends it. Returns the exit code (see the top of the file). */
static int play_channel(const char *url, const char *tuning)
{
    double t_start = now();
    Session *s = session_new();
    hevc = 0;
    hevc_max_tid = -1;
    hevc_seen = 0;
    sm_pts = -1;
    int code = -1;
    draw_tuning(0, tuning);

    AVDictionary *o = NULL;
    av_dict_set(&o, "rw_timeout", "8000000", 0);
    av_dict_set(&o, "reconnect", "1", 0);
    av_dict_set(&o, "reconnect_streamed", "1", 0);
    av_dict_set(&o, "reconnect_delay_max", "4", 0);
    av_dict_set(&o, "user_agent", "Partycade/1.0", 0);
    /* Options by name only: the cabinet's libavformat is Rockchip's FFmpeg 4.1 build, and writing fields of its
       structs from vanilla 4.1.11 headers (probesize, interrupt_callback) crashed find_stream_info. */
    {
        const char *ps = getenv("TVPLAY_PROBESIZE"), *ad = getenv("TVPLAY_ANALYZE");
        av_dict_set(&o, "probesize", ps ? ps : "600000", 0);
        av_dict_set(&o, "analyzeduration", ad ? ad : "800000", 0);
    }
    int r = avformat_open_input(&s->fmt, url, NULL, &o);
    av_dict_free(&o);
    double t_opened = now();
    if (r < 0) {
        char e[128];
        av_strerror(r, e, sizeof e);
        say("could not open the stream: %s", e);
        session_release(s);
        return 30;
    }
    /* (input while it connects: a flip or going back is not held up by a slow channel) */
    if ((code = handle_input()) >= 0) { session_release(s); return code; }
    if (avformat_find_stream_info(s->fmt, NULL) < 0) { say("no stream info"); session_release(s); return 30; }
    double t_probed = now();
    AVCodec *vdec = NULL, *adec = NULL;
    s->vidx = av_find_best_stream(s->fmt, AVMEDIA_TYPE_VIDEO, -1, -1, &vdec, 0);
    s->aidx = av_find_best_stream(s->fmt, AVMEDIA_TYPE_AUDIO, -1, s->vidx, &adec, 0);
    if (s->vidx < 0 || !vdec) { say("no video"); session_release(s); return 30; }
    AVCodecParameters *vp = stream_par(s->fmt->streams[s->vidx], vdec->id);
    if (!vp) { say("video parameters not found (library layout)"); session_release(s); return 32; }
    MppCodingType coding;
    if (vp->codec_id == AV_CODEC_ID_H264) coding = MPP_VIDEO_CodingAVC;
    else if (vp->codec_id == AV_CODEC_ID_HEVC) coding = MPP_VIDEO_CodingHEVC, hevc = 1;
    else if (vp->codec_id == AV_CODEC_ID_MPEG2VIDEO) coding = MPP_VIDEO_CodingMPEG2;
    else { say("video %s: not for the VPU", avcodec_get_name(vp->codec_id)); session_release(s); return 32; }
    s->vtb = av_q2d(s->fmt->streams[s->vidx]->time_base);
    double sar = 1;                               /* from the decoder's frames (the parameters' layout differs) */
    say("open %.2f s (connect %.2f, probe %.2f): video %s, audio %s", now() - t_start, t_opened - t_start,
        t_probed - t_opened, avcodec_get_name(vp->codec_id), s->aidx >= 0 && adec ? adec->name : "none");
    if (s->aidx >= 0) {
        AVCodecParameters *ap = adec ? stream_par(s->fmt->streams[s->aidx], adec->id) : NULL;
        AVCodec *ac = ap ? avcodec_find_decoder(ap->codec_id) : NULL;
        s->actx = ac ? avcodec_alloc_context3(ac) : NULL;
        if (!adev || !s->actx || avcodec_parameters_to_context(s->actx, ap) < 0 || avcodec_open2(s->actx, ac, NULL) < 0) {
            say("audio decoder failed: playing without sound");
            s->aidx = -1;
        } else {
            s->atb = av_q2d(s->fmt->streams[s->aidx]->time_base);
        }
    }
    if (mpp_create(&mctx, &mpi) || mpp_init(mctx, MPP_CTX_DEC, coding)) { say("MPP init failed"); session_release(s); return 32; }
    grp = NULL;

    SDL_AtomicIncRef(&s->refs);                   /* the reader's */
    SDL_Thread *dt = SDL_CreateThread(demux_thread, "demux", s);
    SDL_Thread *at = s->aidx >= 0 ? SDL_CreateThread(audio_thread, "audio", s) : NULL;

    /* The display queue: decoded frames waiting for their time, and the one on the screen (the GPU reads it). */
    MppFrame waiting[WAIT_MAX];
    int nwait = 0;
    double wall0 = -1, pts0 = 0;                  /* no audio: the clock is the wall clock from the first picture */
    long shown = 0, skipped = 0, late = 0, sent = 0, err_frames = 0, discard_frames = 0;
    long gap_hist[8] = {0};
    double prev_pic = 0, last_pts = 0, frame_dt = 0;
    if (!vid_taps_fixed) vid_taps = 1;
    /* Skipping: only while the decoder is really behind. Before 2026-11-25 a "lead" grew with every late frame
       and shrank only after 90 on time; on a 720p60 channel that the VPU decodes at 100 fps it reached 0.4 s and
       threw away a quarter of the pictures (45 shown a second; 60 with no skipping, measured on the cabinet). */
    double behind_until = 0;                      /* late frames recently: skip what would be late anyway */
    int late_recent = 0;
    double late_window = 0;
    static int noskip = -1;
    if (noskip < 0) noskip = getenv("TVPLAY_NOSKIP") != NULL;
    /* Start at a keyframe (the gate joins the stream mid-picture-group: what comes before the first keyframe
       decodes into blocks), and again after a jump in the stream. Bounded: a stream that never marks one plays. */
    int need_key = 1;
    long key_wait_pkts = 0, key_waits = 0, key_dropped = 0;
    double last_report = now(), first_pic = -1, last_tuning = 0, last_shown = 0, draw_sum = 0, draw_max = 0;
    long shown_at_report = 0;
    struct rusage ru0;
    getrusage(RUSAGE_SELF, &ru0);

    while (code < 0) {
        code = handle_input();
        if (code >= 0) break;
        double clock;
        if (s->aidx >= 0) clock = picture_clock(s);
        else clock = wall0 < 0 ? -1 : pts0 + (now() - wall0);

        if (s->restart_video) {
            s->restart_video = 0;
            mpi->reset(mctx);                     /* (its references are from before the jump) */
            for (int i = 0; i < nwait; i++) mpp_frame_deinit(&waiting[i]);
            nwait = 0;
            need_key = 1;
            key_waits++;
        }
        /* Feed the decoder. */
        for (int fed = 0; fed < 8; fed++) {
            AVPacket *pkt = pq_peek(&s->vq);
            if (!pkt) break;
            double pts = pkt->pts != AV_NOPTS_VALUE ? pkt->pts * s->vtb : (pkt->dts != AV_NOPTS_VALUE ? pkt->dts * s->vtb : -1);
            if (need_key) {
                if (pkt->flags & AV_PKT_FLAG_KEY || ++key_wait_pkts > 600) {
                    if (key_wait_pkts > 600) say("no keyframe in 600 pictures: playing on");
                    else if (key_dropped) say("started at a keyframe (%ld pictures before it dropped)", key_dropped);
                    need_key = 0;
                    key_wait_pkts = 0;
                } else {
                    pkt = pq_get(s, &s->vq, 0);
                    av_packet_free(&pkt);
                    key_dropped++;
                    continue;
                }
            }
            /* A picture that cannot be on time is not decoded if nothing refers to it: always when its time has
               passed, and up to 120 ms ahead while frames have been coming out late (the decoder behind). */
            double ahead = now() < behind_until ? 0.12 : 0.0;
            if (!noskip && clock >= 0 && pts >= 0 && pts < clock + ahead && nonref(pkt->data, pkt->size)) {
                pkt = pq_get(s, &s->vq, 0);
                av_packet_free(&pkt);
                skipped++;
                continue;
            }
            MppPacket mp;
            mpp_packet_init(&mp, pkt->data, pkt->size);
            mpp_packet_set_pts(mp, pts >= 0 ? (RK_S64)(pts * 1e6) : -1);
            MPP_RET mr = mpi->decode_put_packet(mctx, mp);
            mpp_packet_deinit(&mp);
            if (mr != MPP_OK) break;              /* full: try again after taking frames */
            pkt = pq_get(s, &s->vq, 0);
            av_packet_free(&pkt);
            sent++;
        }

        /* Take decoded frames. */
        while (nwait < WAIT_MAX) {
            MppFrame f = NULL;
            if (mpi->decode_get_frame(mctx, &f) != MPP_OK || !f) break;
            if (mpp_frame_get_info_change(f)) {
                if (!grp) mpp_buffer_group_get_internal(&grp, MPP_BUFFER_TYPE_DRM);
                int size = mpp_frame_get_buf_size(f);
                /* Reference pictures (H.264 level 4 at 1080p: 4; HEVC: 6) + those waiting + the one on the
                   screen + the one being decoded + the two kept after the screen. At 1080p each is ~4 MB, and
                   the cabinet has 118 MB in all. */
                mpp_buffer_group_limit_config(grp, size, (hevc ? 6 : 5) + WAIT_MAX + 2 + KEEP_SHOWN);
                mpi->control(mctx, MPP_DEC_SET_EXT_BUF_GROUP, grp);
                mpi->control(mctx, MPP_DEC_SET_INFO_CHANGE_READY, NULL);
                if (mpp_frame_get_width(f) > 1920 || mpp_frame_get_height(f) > 1088) {
                    say("video %dx%d: beyond the VPU", mpp_frame_get_width(f), mpp_frame_get_height(f));
                    code = 32;
                }
                {
                    MppFrameRational sr = mpp_frame_get_sar(f);
                    sar = sr.num > 0 && sr.den > 0 ? (double)sr.num / sr.den : 1;
                }
                say("stream %dx%d (stride %d x %d), frame buffers %d KB each", mpp_frame_get_width(f),
                    mpp_frame_get_height(f), mpp_frame_get_hor_stride(f), mpp_frame_get_ver_stride(f), size / 1024);
                mpp_frame_deinit(&f);
            } else if (mpp_frame_get_buffer(f) && !mpp_frame_get_errinfo(f) && !mpp_frame_get_discard(f)) {
                waiting[nwait++] = f;
            } else {
                if (mpp_frame_get_errinfo(f)) err_frames++;
                else if (mpp_frame_get_discard(f)) discard_frames++;
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
                /* three late frames within a second: the decoder is behind; skip for the next two seconds */
                if (now() - late_window > 1) { late_window = now(); late_recent = 0; }
                if (++late_recent >= 3) behind_until = now() + 2;
            }
            if (nwait > 0 && mpp_frame_get_pts(waiting[0]) / 1e6 <= clock + 0.008) show = 0;
        } else if (shown == 0 && s->aidx < 0 && nwait > 0) {
            show = 0;                             /* no sound: the first picture starts the clock */
        }
        if (show >= 0 && holding()) show = -1;   /* (a still picture for a screenshot; frames wait or go late) */
        if (show >= 0) {
            MppFrame f = waiting[0];
            if (wall0 < 0) { wall0 = now(); pts0 = mpp_frame_get_pts(f) / 1e6; }
            double td = now();
            draw(f, sar);
            td = now() - td;
            double tn = now();
            if (prev_pic > 0) { int b = (int)((tn - prev_pic) * 1000 / 8.33); if (b > 7) b = 7; gap_hist[b]++; }
            prev_pic = tn;
            draw_sum += td;
            if (td > draw_max) draw_max = td;
            last_shown = now();
            if (first_pic < 0) { first_pic = now(); view_first_picture(); say("first picture %.1f s after start", first_pic - t_start); }
            /* The filter for this channel's frame rate: from the time between its pictures (eased), and one read a
               pixel again whenever frames come out late. */
            {
                double pt = mpp_frame_get_pts(f) / 1e6;
                if (last_pts > 0 && pt > last_pts && pt - last_pts < 0.2)
                    frame_dt = frame_dt > 0 ? frame_dt + 0.05 * ((pt - last_pts) - frame_dt) : pt - last_pts;
                last_pts = pt;
                if (!vid_taps_fixed && shown > 30) {
                    int want = frame_dt > 0.028 && now() >= behind_until ? 4 : 1;
                    if (want != vid_taps) { vid_taps = want; say("picture filter: %d read%s a pixel (%.1f fps)", want, want > 1 ? "s" : "", 1 / frame_dt); }
                }
            }
            /* The picture replaced goes back to the decoder two flips later: the GPU draws a frame or more behind
               the CPU, and a buffer handed back at once could be decoded into while still being read. */
            if (shown_ring[KEEP_SHOWN - 1]) mpp_frame_deinit(&shown_ring[KEEP_SHOWN - 1]);
            memmove(shown_ring + 1, shown_ring, (KEEP_SHOWN - 1) * sizeof shown_ring[0]);
            shown_ring[0] = on_screen;
            on_screen = f;
            shown++;
            memmove(waiting, waiting + 1, (nwait - 1) * sizeof waiting[0]);
            nwait--;
        } else {
            if (first_pic < 0 && now() - last_tuning >= 0.05 && !holding()) { last_tuning = now(); draw_tuning(now() - t_start, tuning); }
            else SDL_Delay(2);
        }

        /* Nothing to show for 12 s: give up (a dead channel, or the panel's placeholder). */
        if (first_pic < 0 && now() - t_start > 12) { say("no picture in 12 s"); code = 30; }
        /* Stalled: the panel stopped sending, or came back with timestamps that no longer meet the sound's
           (2026-11-01: ESPN ran dry, then sat 30 s with A/V +22 s and 6 MB queued, showing nothing). */
        if (first_pic >= 0 && now() - last_shown > 10) { say("stalled: no picture for 10 s"); code = 33; }
        if (s->demux_done && !s->vq.first && nwait == 0 && first_pic >= 0) { say("the stream ended"); code = 31; }
        if (now() - last_report >= 5) {
            last_report = now();
            say("t %.0f: shown %ld skipped %ld late %ld sent %ld%s; decoder errors %ld discards %ld,"
                " damaged packets %ld, time jumps %ld; A/V %+.2f s; queues video %d (%lld KB) audio %d;"
                " read %lld KB in %lld packets, slowest read %.0f ms; audio queued %.2f s; draw %.1f ms (max %.0f)",
                now() - t_start, shown, skipped, late, sent, now() < behind_until ? " (behind)" : "", err_frames,
                discard_frames, s->corrupt_pkts, s->pts_jumps,
                nwait && clock >= 0 ? mpp_frame_get_pts(waiting[0]) / 1e6 - clock : 0.0, s->vq.n,
                (long long)s->vq.bytes / 1024, s->aq.n, s->demux_bytes / 1024, s->demux_pkts, s->demux_slowest * 1000,
                adev ? (double)SDL_GetQueuedAudioSize(adev) / OUT_BYTES_PER_SEC : 0.0,
                shown > shown_at_report ? 1000 * draw_sum / (shown - shown_at_report) : 0.0, 1000 * draw_max);
            say("  gaps between pictures (ms): <8 %ld, 8-17 %ld, 17-25 %ld, 25-33 %ld, 33-42 %ld, 42-50 %ld, 50-58 %ld, 58+ %ld",
                gap_hist[0], gap_hist[1], gap_hist[2], gap_hist[3], gap_hist[4], gap_hist[5], gap_hist[6], gap_hist[7]);
            memset(gap_hist, 0, sizeof gap_hist);
            shown_at_report = shown;
            draw_sum = draw_max = 0;
            s->demux_bytes = s->demux_pkts = 0;
            s->demux_slowest = 0;
        }
    }

    struct rusage ru1;
    getrusage(RUSAGE_SELF, &ru1);
    double el = now() - t_start;
    double cpu = (ru1.ru_utime.tv_sec - ru0.ru_utime.tv_sec) + (ru1.ru_utime.tv_usec - ru0.ru_utime.tv_usec) / 1e6 +
                 (ru1.ru_stime.tv_sec - ru0.ru_stime.tv_sec) + (ru1.ru_stime.tv_usec - ru0.ru_stime.tv_usec) / 1e6;
    say("exit %d after %.0f s: shown %ld (%.1f/s), skipped %ld, late %ld, restarts at a keyframe %ld; decoder errors %ld,"
        " damaged packets %ld; CPU %.0f%% of a core", code, el, shown, shown / (el > 0 ? el : 1), skipped, late,
        key_waits, err_frames, s->corrupt_pkts, 100 * cpu / (el > 0 ? el : 1));

    /* Wind the channel down: silence at once, the threads stopped, the decoder's pictures given back. The screen
       moves off the last picture before its buffer is freed (the caller draws the next channel's bands first, or
       the process ends). */
    s->quitting = 1;
    SDL_PauseAudioDevice(adev, 1);
    SDL_ClearQueuedAudio(adev);
    SDL_CondBroadcast(s->vq.cv);
    SDL_CondBroadcast(s->aq.cv);
    if (at) SDL_WaitThread(at, NULL);
    SDL_DetachThread(dt);                         /* (it may sit in a network read: it ends by itself) */
    for (int i = 0; i < nwait; i++) mpp_frame_deinit(&waiting[i]);
    session_release(s);
    return code;
}

/* The last channel's pictures and its decoder, released once nothing on the screen uses them. */
static void decoder_release(void)
{
    for (int i = 0; i < KEEP_SHOWN; i++) if (shown_ring[i]) mpp_frame_deinit(&shown_ring[i]);
    if (on_screen) mpp_frame_deinit(&on_screen);
    forget_images();
    if (mctx) { mpi->reset(mctx); mpp_destroy(mctx); mctx = NULL; mpi = NULL; }
    if (grp) { mpp_buffer_group_put(grp); grp = NULL; }
}

/* ------------------------------------------------------------------ main */
static void write_return(int code)
{
    const char *p = getenv("TVPLAY_RETURN");
    if (!p) return;
    FILE *f = fopen(p, "w");
    if (f) { fprintf(f, "%d %d\n", code, chan_idx + 1); fclose(f); }
}

int main(int argc, char **argv)
{
    const char *lp = getenv("TVPLAY_LOG");
    logf_ = lp ? fopen(lp, "a") : stderr;
    if (!logf_) logf_ = stderr;
    const char *list = getenv("TVPLAY_LIST");
    if (argc < 2 && !list) { fprintf(stderr, "usage: tvplay URL, or TVPLAY_LIST=play.tsv tvplay\n"); return 2; }
    if (list && !list_load(list)) { say("no channels in %s", list); return 30; }
    say("tvplay started");

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) != 0) { say("SDL: %s", SDL_GetError()); return 30; }
    for (int i = 0; i < SDL_NumJoysticks(); i++) SDL_JoystickOpen(i);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    /* The screen first: the channel's bands and "TUNING IN..." are up before the stream is asked for. */
    win = SDL_CreateWindow("tv", 0, 0, 1024, 768, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP);
    SDL_GLContext glc = win ? SDL_GL_CreateContext(win) : NULL;
    if (!glc) { say("GL: %s", SDL_GetError()); return 30; }
    SDL_GL_SetSwapInterval(1);
    SDL_GL_GetDrawableSize(win, &ww, &wh);
    gl_setup();
    if (list) show_channel(chan_idx);
    draw_tuning(0, NULL);
    say("screen up");
    {
        SDL_DisplayMode dm;
        if (SDL_GetCurrentDisplayMode(0, &dm) == 0) say("display %dx%d at %d Hz", dm.w, dm.h, dm.refresh_rate);
    }
    SDL_AudioSpec want = {0}, have;
    want.freq = OUT_RATE;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    adev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (!adev) say("audio device: %s: playing without sound", SDL_GetError());
    avformat_network_init();

    if (!list) {                                  /* one address, as before (tests) */
        int code = play_channel(argv[1], getenv("TVPLAY_TUNING"));
        fflush(logf_);
        _exit(code);
    }

    /* The channels: up/down flips here, in this process; a channel that will not open is passed over while
       flipping (up to 6 in a row); a stall is tuned again (up to 3 times, the count reset after 90 s playing). */
    int dir = 0, skips = 0, retunes = 0, code;
    const char *tuning = getenv("TVPLAY_TUNING");
    for (;;) {
        char url[1024];
        say("channel %d/%d %s", chan_idx + 1, nchans, chans[chan_idx].name);
        double t0 = now();
        code = channel_url(&chans[chan_idx], url, sizeof url) ? play_channel(url, tuning) : 30;
        tuning = NULL;
        if (now() - t0 > 90) retunes = 0;
        int next = chan_idx;
        if (code == 20 || code == 21) {
            dir = code == 20 ? 1 : -1;
            skips = 0;
            retunes = 0;
            next = (chan_idx + dir + nchans) % nchans;
        } else if (code == 33 && retunes < 3) {
            retunes++;
            tuning = "RECONNECTING\xe2\x80\xa6";
        } else if ((code == 30 || code == 31 || code == 32) && dir != 0 && skips < 6) {
            skips++;
            next = (chan_idx + dir + nchans) % nchans;
        } else {
            if (code == 33) code = 31;
            break;
        }
        chan_idx = next;
        /* The next channel's bands at once, over the last one's colours; then the old pictures can go. */
        show_channel(chan_idx);
        draw_tuning(0, tuning);
        draw_tuning(0, tuning);
        decoder_release();
    }
    write_return(code);
    say("leaving: %d at channel %d", code, chan_idx + 1);
    fflush(logf_);
    _exit(code);
}
