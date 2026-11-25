/* fliptest: how the cabinet's display takes a new picture, with no GPU, SDL or LÖVE in the way (2026-11-25, the
 * TV's tearing). Eight frames of bars sliding down (the panel's tear direction) are painted once into dumb
 * buffers; then the screen is moved through them a frame at a time, in a given way:
 *
 *   fliptest MODE SECONDS
 *     1  page flip (DRM_IOCTL_MODE_PAGE_FLIP, as SDL does), issued at a random moment of the frame
 *     2  set-CRTC (blocking: the driver writes the address in the call) right after the frame start, from a
 *        real-time thread; the call itself waits for the next frame start, which paces it at 60 Hz
 *     3  set-CRTC like 2, but issued at a random moment of the frame (does the moment matter?)
 *
 * A block of MODE squares in the middle says which is running. Prints how many frames it showed.
 * Static, no libdrm: the kernel's own uapi headers (as cabctl). */
#include <drm/drm.h>
#include <drm/drm_mode.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static int fd;
static int xioctl(unsigned long req, void *arg)
{
    int r;
    do r = ioctl(fd, req, arg); while (r == -1 && (errno == EINTR || errno == EAGAIN));
    return r;
}
static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

#define NB 8
static uint32_t fbs[NB], crtc_id, conn_id;
static struct drm_mode_modeinfo mode;

static void wait_vblank(void)
{
    union drm_wait_vblank vb;
    memset(&vb, 0, sizeof vb);
    vb.request.type = _DRM_VBLANK_RELATIVE;
    vb.request.sequence = 1;
    xioctl(DRM_IOCTL_WAIT_VBLANK, &vb);
}

static void set_crtc(uint32_t fb)
{
    struct drm_mode_crtc c;
    memset(&c, 0, sizeof c);
    c.crtc_id = crtc_id;
    c.fb_id = fb;
    c.set_connectors_ptr = (uintptr_t)&conn_id;
    c.count_connectors = 1;
    c.mode = mode;
    c.mode_valid = 1;
    if (xioctl(DRM_IOCTL_MODE_SETCRTC, &c)) perror("setcrtc");
}

static void page_flip(uint32_t fb)
{
    struct drm_mode_crtc_page_flip f;
    memset(&f, 0, sizeof f);
    f.crtc_id = crtc_id;
    f.fb_id = fb;
    f.flags = DRM_MODE_PAGE_FLIP_EVENT;
    if (xioctl(DRM_IOCTL_MODE_PAGE_FLIP, &f)) { perror("pageflip"); return; }
    char buf[1024];
    if (read(fd, buf, sizeof buf) < 0) perror("read event");   /* the flip's completion event */
}

int main(int argc, char **argv)
{
    int m = argc > 1 ? atoi(argv[1]) : 2;
    double secs = argc > 2 ? atof(argv[2]) : 20;
    fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("card0"); return 1; }
    xioctl(DRM_IOCTL_SET_MASTER, NULL);
    /* the connected connector, its crtc, its mode */
    struct drm_mode_card_res res = {0};
    uint32_t crtcs[8], conns[8], encs[8], fbids[8];
    xioctl(DRM_IOCTL_MODE_GETRESOURCES, &res);
    res.crtc_id_ptr = (uintptr_t)crtcs; res.connector_id_ptr = (uintptr_t)conns;
    res.encoder_id_ptr = (uintptr_t)encs; res.fb_id_ptr = (uintptr_t)fbids;
    if (res.count_fbs > 8) res.count_fbs = 8;
    xioctl(DRM_IOCTL_MODE_GETRESOURCES, &res);
    for (unsigned i = 0; i < res.count_connectors && !conn_id; i++) {
        struct drm_mode_get_connector c = {0};
        struct drm_mode_modeinfo modes[32];
        c.connector_id = conns[i];
        xioctl(DRM_IOCTL_MODE_GETCONNECTOR, &c);
        if (c.connection != 1 || !c.count_modes) continue;
        if (c.count_modes > 32) c.count_modes = 32;
        c.modes_ptr = (uintptr_t)modes; c.count_props = 0; c.count_encoders = 0;
        xioctl(DRM_IOCTL_MODE_GETCONNECTOR, &c);
        mode = modes[0];
        conn_id = conns[i];
    }
    crtc_id = crtcs[0];
    printf("mode %s %dx%d, clock %d kHz, htotal %d vtotal %d (vblank %d lines = %.2f ms), %d Hz\n", mode.name,
           mode.hdisplay, mode.vdisplay, mode.clock, mode.htotal, mode.vtotal, mode.vtotal - mode.vdisplay,
           (mode.vtotal - mode.vdisplay) * mode.htotal / (double)mode.clock, mode.vrefresh);
    int W = mode.hdisplay, H = mode.vdisplay;
    /* eight frames: in the panel's upright view the bars slide down; on the framebuffer that is a column band
       moving along x (the panel is the framebuffer turned) */
    for (int k = 0; k < NB; k++) {
        struct drm_mode_create_dumb cd = {0};
        cd.width = W; cd.height = H; cd.bpp = 32;
        if (xioctl(DRM_IOCTL_MODE_CREATE_DUMB, &cd)) { perror("dumb"); return 1; }
        struct drm_mode_fb_cmd fc = {0};
        fc.width = W; fc.height = H; fc.bpp = 32; fc.depth = 24; fc.pitch = cd.pitch; fc.handle = cd.handle;
        if (xioctl(DRM_IOCTL_MODE_ADDFB, &fc)) { perror("addfb"); return 1; }
        fbs[k] = fc.fb_id;
        struct drm_mode_map_dumb md = {0};
        md.handle = cd.handle;
        xioctl(DRM_IOCTL_MODE_MAP_DUMB, &md);
        uint32_t *px = mmap(0, cd.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, md.offset);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++) {
                int band = ((x + k * 16) % 128) < 28;   /* 16 px a frame: eight frames make the period */
                uint32_t c = band ? 0xffffff : 0x1e1e24;
                /* the mode's number as squares in the middle */
                if (y > H / 2 - 40 && y < H / 2 + 40) {
                    int cx = x - (W / 2 - m * 60);
                    if (cx >= 0 && cx < m * 120 && cx % 120 < 90) c = 0xffd24d;
                }
                px[y * (cd.pitch / 4) + x] = c;
            }
        munmap(px, cd.size);
    }
    set_crtc(fbs[0]);
    if (m == 2 || m == 3) {
        struct sched_param sp = {.sched_priority = 50};
        if (sched_setscheduler(0, SCHED_FIFO, &sp)) perror("realtime (running without)");
    }
    srand(time(NULL));
    double t0 = now();
    long n = 0;
    wait_vblank();
    while (now() - t0 < secs) {
        uint32_t fb = fbs[++n % NB];
        if (m == 1) {
            usleep(rand() % 12000);
            page_flip(fb);
        } else if (m == 2) {
            set_crtc(fb);               /* (returns at the next frame start: the next call is right after it) */
        } else {
            wait_vblank();
            usleep(rand() % 12000);
            set_crtc(fb);
        }
    }
    printf("mode %d: %ld frames in %.1f s (%.1f a second)\n", m, n, now() - t0, n / (now() - t0));
    return 0;
}
