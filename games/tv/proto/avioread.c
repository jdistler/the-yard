/* avioread URL SECONDS [BUFKB]: raw bytes through libavformat's AVIO (no demuxer): the network layer's rate. */
#include <libavformat/avformat.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv)
{
    AVIOContext *io = NULL;
    double secs = atof(argv[2]);
    int bk = argc > 3 ? atoi(argv[3]) : 32;
    avformat_network_init();
    AVDictionary *o = NULL;
    if (getenv("UA")) av_dict_set(&o, "user_agent", getenv("UA"), 0);
    if (getenv("NORANGE")) av_dict_set(&o, "seekable", "0", 0);
    if (getenv("NOICY")) av_dict_set(&o, "icy", "0", 0);
    if (avio_open2(&io, argv[1], AVIO_FLAG_READ, NULL, &o) < 0) { printf("open failed\n"); return 1; }
    unsigned char *buf = malloc(bk * 1024);
    long long total = 0;
    double t0 = now(), slow = 0;
    while (now() - t0 < secs) {
        double a = now();
        int n = avio_read(io, buf, bk * 1024);
        if (now() - a > slow) slow = now() - a;
        if (n <= 0) break;
        total += n;
    }
    double el = now() - t0;
    printf("avio %d KB reads: %.1f Mbps over %.0f s, slowest read %.0f ms\n", bk, total * 8 / el / 1e6, el, slow * 1000);
    return 0;
}
