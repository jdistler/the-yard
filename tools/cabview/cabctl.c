/* cabctl: see and drive the cabinet over SSH (tools/cabview/README.md).
 *   cabctl info                 what the display shows: CRTC, planes, their framebuffers
 *   cabctl grab [FB_ID]         the scanned-out framebuffer (or FB_ID) as a binary PPM on stdout
 *   cabctl press NAME [MS]      press and release a control (default 150 ms held)
 *   cabctl hold NAME... MS      hold several controls together for MS, then release all
 *   cabctl watch [SECONDS]      print the controls as they are pressed (real players or injected)
 *   cabctl record S MS DIV      a grab every MS ms for S seconds, each 1/DIV size, as PPMs on stdout (each with
 *                               "# t SECONDS fb ID master PID" in its header): transitions, as a film
 * Names: up down left right 1p 2p low tl tr volup voldown, or a code like 0x136.
 * The grab reads what the display controller scans out (DRM GETFB + dumb map, or PRIME), not what a program
 * thinks it drew, so a black screen grabs black. Static, no libdrm: the kernel's own uapi headers. */
#include <drm/drm.h>
#include <drm/drm_mode.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static int xioctl(int fd, unsigned long req, void *arg)
{
    int r;
    do r = ioctl(fd, req, arg); while (r == -1 && (errno == EINTR || errno == EAGAIN));
    return r;
}

static int card(void)
{
    int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("/dev/dri/card0"); exit(1); }
    return fd;
}

static int getfb(int fd, uint32_t id, struct drm_mode_fb_cmd *fb)
{
    memset(fb, 0, sizeof *fb);
    fb->fb_id = id;
    return xioctl(fd, DRM_IOCTL_MODE_GETFB, fb);
}

static void print_fb(int fd, uint32_t id)
{
    struct drm_mode_fb_cmd fb;
    if (!id) { printf(" fb none"); return; }
    if (getfb(fd, id, &fb)) { printf(" fb %u (GETFB: %s)", id, strerror(errno)); return; }
    printf(" fb %u %ux%u bpp %u depth %u pitch %u handle %u", id, fb.width, fb.height, fb.bpp, fb.depth,
           fb.pitch, fb.handle);
    if (fb.handle) { struct drm_gem_close c = { .handle = fb.handle }; xioctl(fd, DRM_IOCTL_GEM_CLOSE, &c); }
}

/* The first CRTC with a valid mode and a framebuffer: what the HDMI output shows. */
static uint32_t scanout_fb(int fd, int verbose)
{
    struct drm_mode_card_res res = {0};
    uint32_t crtcs[8], conns[8], encs[8], fbs[8], found = 0;
    if (xioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res)) { perror("GETRESOURCES"); exit(1); }
    if (res.count_crtcs > 8 || res.count_connectors > 8 || res.count_encoders > 8 || res.count_fbs > 8) {
        fprintf(stderr, "too many objects\n"); exit(1);
    }
    res.crtc_id_ptr = (uintptr_t)crtcs; res.connector_id_ptr = (uintptr_t)conns;
    res.encoder_id_ptr = (uintptr_t)encs; res.fb_id_ptr = (uintptr_t)fbs;
    if (xioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res)) { perror("GETRESOURCES"); exit(1); }
    for (uint32_t i = 0; i < res.count_connectors; i++) {
        struct drm_mode_get_connector c = { .connector_id = conns[i] };
        if (xioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, &c)) continue;
        if (verbose) printf("connector %u type %u status %s encoder %u\n", c.connector_id, c.connector_type,
                            c.connection == 1 ? "connected" : c.connection == 2 ? "disconnected" : "unknown",
                            c.encoder_id);
    }
    for (uint32_t i = 0; i < res.count_crtcs; i++) {
        struct drm_mode_crtc c = { .crtc_id = crtcs[i] };
        if (xioctl(fd, DRM_IOCTL_MODE_GETCRTC, &c)) continue;
        if (verbose) {
            printf("crtc %u mode %s %ux%u at %u,%u", c.crtc_id, c.mode_valid ? c.mode.name : "(off)",
                   c.mode.hdisplay, c.mode.vdisplay, c.x, c.y);
            print_fb(fd, c.fb_id);
            printf("\n");
        }
        if (!found && c.mode_valid && c.fb_id) found = c.fb_id;
    }
    if (verbose) {
        struct drm_set_client_cap cap = { DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1 };
        xioctl(fd, DRM_IOCTL_SET_CLIENT_CAP, &cap);
        struct drm_mode_get_plane_res pr = {0};
        uint32_t planes[16];
        if (!xioctl(fd, DRM_IOCTL_MODE_GETPLANERESOURCES, &pr) && pr.count_planes <= 16) {
            pr.plane_id_ptr = (uintptr_t)planes;
            xioctl(fd, DRM_IOCTL_MODE_GETPLANERESOURCES, &pr);
            for (uint32_t i = 0; i < pr.count_planes; i++) {
                struct drm_mode_get_plane p = { .plane_id = planes[i] };
                if (xioctl(fd, DRM_IOCTL_MODE_GETPLANE, &p)) continue;
                printf("plane %u crtc %u", p.plane_id, p.crtc_id);
                print_fb(fd, p.fb_id);
                printf("\n");
            }
        }
        printf("fbs listed by the driver: %u", res.count_fbs);
        for (uint32_t i = 0; i < res.count_fbs; i++) printf(" %u", fbs[i]);
        printf("\n");
    }
    return found;
}

/* Map framebuffer `id` read-only; fills *fb. MAP_FAILED when it cannot. */
static void *map_fb(int fd, uint32_t id, struct drm_mode_fb_cmd *fb)
{
    if (getfb(fd, id, fb)) { fprintf(stderr, "grab: GETFB %u: %s\n", id, strerror(errno)); return MAP_FAILED; }
    if (!fb->handle) { fprintf(stderr, "grab: no handle for fb %u (not root?)\n", id); return MAP_FAILED; }
    if (fb->bpp != 32 && fb->bpp != 16) { fprintf(stderr, "grab: bpp %u not handled\n", fb->bpp); return MAP_FAILED; }
    size_t size = (size_t)fb->pitch * fb->height;
    void *map = MAP_FAILED;
    struct drm_mode_map_dumb md = { .handle = fb->handle };
    if (!xioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &md))
        map = mmap(0, size, PROT_READ, MAP_SHARED, fd, md.offset);
    if (map == MAP_FAILED) {
        struct drm_prime_handle ph = { .handle = fb->handle, .flags = DRM_CLOEXEC };
        if (!xioctl(fd, DRM_IOCTL_PRIME_HANDLE_TO_FD, &ph)) {
            map = mmap(0, size, PROT_READ, MAP_SHARED, ph.fd, 0);
            close(ph.fd);
        }
    }
    if (map == MAP_FAILED) fprintf(stderr, "grab: cannot map fb %u: %s\n", id, strerror(errno));
    struct drm_gem_close c = { .handle = fb->handle };
    xioctl(fd, DRM_IOCTL_GEM_CLOSE, &c); /* the mapping keeps the buffer */
    return map;
}

static int grab(uint32_t want)
{
    int fd = card();
    struct drm_mode_fb_cmd fb;
    uint8_t *raw = NULL;
    uint32_t id = 0;
    int tries = 0, whole = 0;
    /* The buffer on screen is copied (uncached memory, one pass, ~10 ms), then converted. A flip during the copy
     * mixes two frames: the buffer just left becomes the next render target. So a copy counts only if the same
     * buffer is still on screen after it; else the one now on screen is taken, up to 8 times. FB_ID given: that
     * buffer, once. */
    while (!whole && tries < 8) {
        tries++;
        id = want ? want : scanout_fb(fd, 0);
        if (!id) { fprintf(stderr, "grab: the display shows no framebuffer (CRTC off)\n"); return 2; }
        void *map = map_fb(fd, id, &fb);
        if (map == MAP_FAILED) return 1;
        size_t size = (size_t)fb.pitch * fb.height;
        free(raw);
        if (!(raw = malloc(size))) return 1;
        memcpy(raw, map, size);
        munmap(map, size);
        whole = want || scanout_fb(fd, 0) == id;
    }
    uint8_t *row = malloc((size_t)fb.width * 3);
    if (!row) return 1;
    printf("P6\n# fb %u bpp %u tries %d%s\n%u %u\n255\n", id, fb.bpp, tries, whole ? "" : " (may be torn)",
           fb.width, fb.height);
    for (uint32_t y = 0; y < fb.height; y++) {
        uint8_t *s = raw + (size_t)y * fb.pitch;
        for (uint32_t x = 0; x < fb.width; x++) {
            uint8_t *d = row + x * 3;
            if (fb.bpp == 32) { d[0] = s[x * 4 + 2]; d[1] = s[x * 4 + 1]; d[2] = s[x * 4]; }
            else {
                uint16_t v = s[x * 2] | s[x * 2 + 1] << 8;
                d[0] = (v >> 11 & 31) * 255 / 31; d[1] = (v >> 5 & 63) * 255 / 63; d[2] = (v & 31) * 255 / 31;
            }
        }
        fwrite(row, 3, fb.width, stdout);
    }
    fflush(stdout);
    return 0;
}

/* The pid holding the display (DRM master), from debugfs; 0 if none. */
static int drm_master_pid(void)
{
    FILE *f = fopen("/sys/kernel/debug/dri/0/clients", "r");
    char line[256], cmd[64];
    int pid = 0, p, dev;
    char master;
    if (!f) return 0;
    while (fgets(line, sizeof line, f))
        if (sscanf(line, " %63s %d %d %c", cmd, &p, &dev, &master) == 4 && master == 'y') pid = p;
    fclose(f);
    return pid;
}

static int record(int secs, int ms, int div)
{
    int fd = card();
    struct timespec t0, now;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    if (div < 1) div = 1;
    for (;;) {
        clock_gettime(CLOCK_MONOTONIC, &now);
        double el = (now.tv_sec - t0.tv_sec) + (now.tv_nsec - t0.tv_nsec) / 1e9;
        if (el >= secs) break;
        uint32_t id = scanout_fb(fd, 0);
        struct drm_mode_fb_cmd fb;
        void *map = id ? map_fb(fd, id, &fb) : MAP_FAILED;
        uint32_t w = 1024 / div, h = 768 / div;
        uint8_t *row = malloc((size_t)w * 3);
        printf("P6\n# t %.3f fb %u master %d\n%u %u\n255\n", el, id, drm_master_pid(), w, h);
        for (uint32_t y = 0; y < h; y++) {
            for (uint32_t x = 0; x < w; x++) {
                uint8_t *d = row + x * 3;
                if (map == MAP_FAILED || fb.bpp != 32) { d[0] = d[1] = d[2] = 0; continue; }
                uint8_t *sp = (uint8_t *)map + (size_t)(y * div) * fb.pitch + (size_t)(x * div) * 4;
                d[0] = sp[2]; d[1] = sp[1]; d[2] = sp[0];
            }
            fwrite(row, 3, w, stdout);
        }
        fflush(stdout);
        free(row);
        if (map != MAP_FAILED) munmap(map, (size_t)fb.pitch * fb.height);
        struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
        nanosleep(&ts, 0);
    }
    return 0;
}

static const struct { const char *name; int code; } names[] = {
    {"up", KEY_UP}, {"down", KEY_DOWN}, {"left", KEY_LEFT}, {"right", KEY_RIGHT},
    {"1p", 0x136}, {"2p", 0x137}, {"low", 0x130}, {"tl", 0x131}, {"tr", 0x133},
    {"volup", KEY_VOLUMEUP}, {"voldown", KEY_VOLUMEDOWN},
};

static int code_of(const char *s)
{
    for (size_t i = 0; i < sizeof names / sizeof *names; i++)
        if (!strcmp(s, names[i].name)) return names[i].code;
    char *end;
    long v = strtol(s, &end, 0);
    if (*s && !*end && v > 0 && v < KEY_MAX) return (int)v;
    fprintf(stderr, "unknown control %s\n", s);
    exit(1);
}

static const char *name_of(int code)
{
    static char buf[16];
    for (size_t i = 0; i < sizeof names / sizeof *names; i++) if (names[i].code == code) return names[i].name;
    snprintf(buf, sizeof buf, "0x%x", code);
    return buf;
}

static void emit(int fd, int type, int code, int value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof ev);
    gettimeofday(&ev.time, 0);
    ev.type = type; ev.code = code; ev.value = value;
    if (write(fd, &ev, sizeof ev) != sizeof ev) { perror("inject"); exit(1); }
}

static void msleep(int ms) { struct timespec t = { ms / 1000, (ms % 1000) * 1000000L }; nanosleep(&t, 0); }

static int hold(int n, char **keys, int ms)
{
    int fd = open("/dev/input/event0", O_WRONLY);
    if (fd < 0) { perror("/dev/input/event0"); return 1; }
    int codes[16];
    if (n > 16) n = 16;
    for (int i = 0; i < n; i++) codes[i] = code_of(keys[i]);
    for (int i = 0; i < n; i++) emit(fd, EV_KEY, codes[i], 1);
    emit(fd, EV_SYN, SYN_REPORT, 0);
    msleep(ms);
    for (int i = 0; i < n; i++) emit(fd, EV_KEY, codes[i], 0);
    emit(fd, EV_SYN, SYN_REPORT, 0);
    close(fd);
    return 0;
}

static int watch(int secs)
{
    int fd = open("/dev/input/event0", O_RDONLY);
    if (fd < 0) { perror("/dev/input/event0"); return 1; }
    struct timespec t0; clock_gettime(CLOCK_MONOTONIC, &t0);
    struct input_event ev;
    for (;;) {
        struct timespec now; clock_gettime(CLOCK_MONOTONIC, &now);
        double el = (now.tv_sec - t0.tv_sec) + (now.tv_nsec - t0.tv_nsec) / 1e9;
        if (secs > 0 && el >= secs) break;
        fd_set rs; FD_ZERO(&rs); FD_SET(fd, &rs);
        struct timeval tv = { 0, 200000 };
        if (select(fd + 1, &rs, 0, 0, &tv) <= 0) continue;
        if (read(fd, &ev, sizeof ev) != sizeof ev) break;
        if (ev.type != EV_KEY) continue;
        printf("%8.3f %s %s\n", el, name_of(ev.code), ev.value == 1 ? "down" : ev.value == 0 ? "up" : "repeat");
        fflush(stdout);
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc >= 2 && !strcmp(argv[1], "info")) { int fd = card(); scanout_fb(fd, 1); return 0; }
    if (argc >= 2 && !strcmp(argv[1], "grab")) return grab(argc > 2 ? strtoul(argv[2], 0, 0) : 0);
    if (argc >= 3 && !strcmp(argv[1], "press")) return hold(1, argv + 2, argc > 3 ? atoi(argv[3]) : 150);
    if (argc >= 4 && !strcmp(argv[1], "hold")) return hold(argc - 3, argv + 2, atoi(argv[argc - 1]));
    if (argc >= 2 && !strcmp(argv[1], "watch")) return watch(argc > 2 ? atoi(argv[2]) : 0);
    if (argc >= 5 && !strcmp(argv[1], "record")) return record(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]));
    fprintf(stderr, "usage: cabctl info | grab [FB] | press NAME [MS] | hold NAME... MS | watch [S] | record S MS DIV\n");
    return 1;
}
