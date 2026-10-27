/* avprobe: open a stream with the cabinet's libavformat and list it (a link/ABI check for tvplay). */
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <libavformat/avformat.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <signal.h>
#include <execinfo.h>
#include <ucontext.h>
#include <unistd.h>
static void on_segv(int sig, siginfo_t *si, void *uc_)
{
    ucontext_t *uc = uc_;
    char buf[256];
    int n = snprintf(buf, sizeof buf, "SEGV at %p pc %lx lr %lx\n", si->si_addr,
                     (unsigned long)uc->uc_mcontext.arm_pc, (unsigned long)uc->uc_mcontext.arm_lr);
    write(2, buf, n);
    int fd = open("/proc/self/maps", 0);
    while ((n = read(fd, buf, sizeof buf)) > 0) write(2, buf, n);
    _exit(139);
}
int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    struct sigaction sa = {0};
    sa.sa_sigaction = on_segv;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    AVFormatContext *f = NULL;
    AVDictionary *o = NULL;
    printf("avformat %u avcodec %u\n", avformat_version(), avcodec_version());
    fflush(stdout);
    avformat_network_init();
    if (getenv("OPT_RECONNECT")) { av_dict_set(&o, "reconnect", "1", 0); av_dict_set(&o, "reconnect_streamed", "1", 0); av_dict_set(&o, "reconnect_delay_max", "4", 0); }
    if (getenv("OPT_TIMEOUT")) av_dict_set(&o, "rw_timeout", "8000000", 0);
    if (getenv("OPT_UA")) av_dict_set(&o, "user_agent", "Partycade/1.0", 0);
    if (getenv("OPT_PROBE")) { av_dict_set(&o, "probesize", "2000000", 0); av_dict_set(&o, "analyzeduration", "2000000", 0); }
    if (avformat_open_input(&f, argv[1], NULL, &o) < 0) { printf("open failed\n"); return 1; }
    printf("opened, %u streams before probing\n", f->nb_streams);
    fflush(stdout);
    int r = avformat_find_stream_info(f, NULL);
    printf("find_stream_info %d, %u streams\n", r, f->nb_streams);
    {
        int pfd[2];
        pipe(pfd);
        fcntl(pfd[1], F_SETFL, O_NONBLOCK);
        char sink[64];
        #define READABLE(p) (write(pfd[1], (void *)(p), 8) == 8 ? (read(pfd[0], sink, 8), 1) : 0)
        printf("headers: offsetof(AVStream, codecpar) %u, time_base %u, sizeof %u\n", (unsigned)offsetof(AVStream, codecpar),
               (unsigned)offsetof(AVStream, time_base), (unsigned)sizeof(AVStream));
        for (unsigned i = 0; i < f->nb_streams; i++) {
            uint32_t *w = (uint32_t *)f->streams[i];
            printf(" stream %u at %p: index %u id %u\n", i, (void *)w, w[0], w[1]);
            for (unsigned k = 0; k < 120; k++) {
                uint32_t v = w[k];
                if ((v & 3) || v < 0x1000 || !READABLE(v)) continue;
                int *cp = (int *)(uintptr_t)v;
                if ((cp[0] == 0 || cp[0] == 1) && cp[1] > 0 && cp[1] < 0x20000)
                    printf("   offset %3u -> type %d codec %d %s\n", k * 4, cp[0], cp[1], avcodec_get_name(cp[1]));
            }
        }
    }
    if (getenv("READ_SECONDS")) {
        double secs = atof(getenv("READ_SECONDS"));
        struct timespec a, b;
        clock_gettime(CLOCK_MONOTONIC, &a);
        long long bytes = 0, pkts = 0;
        double slowest = 0, el = 0, first_t = -1, last_t = -1;
        AVPacket *pkt = av_packet_alloc();
        while (el < secs) {
            struct timespec r0, r1;
            clock_gettime(CLOCK_MONOTONIC, &r0);
            if (av_read_frame(f, pkt) < 0) break;
            clock_gettime(CLOCK_MONOTONIC, &r1);
            double d = (r1.tv_sec - r0.tv_sec) + (r1.tv_nsec - r0.tv_nsec) / 1e9;
            if (d > slowest) slowest = d;
            bytes += pkt->size;
            pkts++;
            if (pkt->stream_index == 0 && pkt->pts != AV_NOPTS_VALUE) {
                double t = pkt->pts * av_q2d(f->streams[0]->time_base);
                if (first_t < 0) first_t = t;
                last_t = t;
            }
            av_packet_unref(pkt);
            clock_gettime(CLOCK_MONOTONIC, &b);
            el = (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
        }
        printf("read %.0f s: %lld KB (%.1f Mbps), %lld packets, slowest read %.0f ms; content %.1f s = %.2fx realtime\n", el,
               bytes / 1024, bytes * 8 / el / 1e6, pkts, slowest * 1000, last_t - first_t, (last_t - first_t) / el);
        return 0;
    }
    for (unsigned i = 0; i < 0; i++)
        printf(" %u: %s %s %dx%d\n", i, av_get_media_type_string(f->streams[i]->codecpar->codec_type),
               avcodec_get_name(f->streams[i]->codecpar->codec_id), f->streams[i]->codecpar->width, f->streams[i]->codecpar->height);
    return 0;
}
