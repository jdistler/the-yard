/* tinyinit: the cabinet's first program, from a few-KB initramfs in the boot partition (the partition had
 * 14 KB free, too little for busybox). It mounts the stock system image, and, unless something says not to,
 * runs /userdata/boot/stage2.sh, a shell script on the data partition that can be changed over Wi-Fi, then
 * boots the stock system exactly as before (/sbin/init). stage2 runs as a child with a time limit
 * (STAGE2_SECONDS): whatever it does or however it fails, /sbin/init starts after it.
 *
 * Safety (games/boot/README.md):
 *   - no stage2.sh, or /userdata/boot/disabled, or 1-player + 2-player held (or both pressed) during the
 *     first seconds of the boot: stock boot;
 *   - /userdata/boot/tries counts boots that ran stage2; at TRIES_MAX it is not run again. Something healthy
 *     after the boot (stage2 starts it) writes 0 back;
 *   - any failure here ends in /sbin/init on the stock system image.
 * No libc: ARM EABI system calls by hand, so the whole initramfs fits in a few KB. Messages go to the kernel
 * log (dmesg), prefixed "yardinit:". */
#ifndef ROOT_DEV
#define ROOT_DEV "/dev/rkflash0p4"
#endif
#ifndef DATA_DEV
#define DATA_DEV "/dev/rkflash0p5"
#endif
#ifndef KEYS_DEV
#define KEYS_DEV "/dev/input/event0"
#endif
#ifndef KEY_A
#define KEY_A 0x136 /* 1-player */
#endif
#ifndef KEY_B
#define KEY_B 0x137 /* 2-player */
#endif
#define TRIES_MAX 3
#define STAGE2_SECONDS 30

typedef unsigned long ul;
#define SYS_exit 1
#define SYS_fork 2
#define SYS_kill 37
#define SYS_wait4 114
#define SYS_read 3
#define SYS_write 4
#define SYS_open 5
#define SYS_close 6
#define SYS_execve 11
#define SYS_chdir 12
#define SYS_mount 21
#define SYS_access 33
#define SYS_mkdir 39
#define SYS_umount2 52
#define SYS_ioctl 54
#define SYS_chroot 61
#define SYS_fsync 118
#define SYS_nanosleep 162

static long sc(long n, long a, long b, long c, long d, long e)
{
    register long r0 __asm__("r0") = a;
    register long r1 __asm__("r1") = b;
    register long r2 __asm__("r2") = c;
    register long r3 __asm__("r3") = d;
    register long r4 __asm__("r4") = e;
    register long r7 __asm__("r7") = n;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r7) : "memory");
    return r0;
}
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#define O_CREAT 0100
#define O_TRUNC 01000
#define MS_RDONLY 1
#define MS_MOVE 8192
#define MNT_DETACH 2


static int kmsg = -1;
static void say(const char *a, const char *b)
{
    char buf[200];
    ul n = 0;
    const char *p;
    for (p = "<5>yardinit: "; *p && n < sizeof buf - 2; p++) buf[n++] = *p;
    for (p = a; *p && n < sizeof buf - 2; p++) buf[n++] = *p;
    if (b) for (p = b; *p && n < sizeof buf - 2; p++) buf[n++] = *p;
    buf[n++] = '\n';
    if (kmsg < 0) kmsg = sc(SYS_open, (long)"/dev/kmsg", O_WRONLY, 0, 0, 0);
    if (kmsg >= 0) sc(SYS_write, kmsg, (long)buf, n, 0, 0);
}

static void nap_ms(long ms)
{
    long ts[2] = {0, 0};   /* no division: there is no libgcc here */
    while (ms >= 1000) { ms -= 1000; ts[0]++; }
    ts[1] = ms * 1000000;
    sc(SYS_nanosleep, (long)ts, 0, 0, 0, 0);
}

static int exists(const char *p) { return sc(SYS_access, (long)p, 0, 0, 0, 0) == 0; }

/* Safe mode: both keys held now (EVIOCGKEY), or both pressed during the next SAFE_MS. A button held since
 * before the input driver started may never be reported as down (QEMU's keyboard is reset when its driver
 * starts; the cabinet's key chip may do the same), so presses during the window count too. */
#define SAFE_MS 1500
static int keys_held(void)
{
    unsigned char bits[96];
    long fd, r, i, t;
    int a = 0, b = 0, sa = 0, sb = 0;
    for (i = 0; i < 20 && !exists(KEYS_DEV); i++) nap_ms(50);
    fd = sc(SYS_open, (long)KEYS_DEV, O_RDONLY | 04000 /* O_NONBLOCK */, 0, 0, 0);
    if (fd < 0) return 0;
    for (t = 0; t <= SAFE_MS; t += 50) {
        for (i = 0; i < (long)sizeof bits; i++) bits[i] = 0;
        /* EVIOCGKEY(len) = _IOC(_IOC_READ, 'E', 0x18, len) */
        r = sc(SYS_ioctl, fd, (long)(0x80000000ul | ((ul)sizeof bits << 16) | ('E' << 8) | 0x18), (long)bits, 0, 0);
        if (r >= 0) {
            a = (bits[KEY_A / 8] >> (KEY_A % 8)) & 1;
            b = (bits[KEY_B / 8] >> (KEY_B % 8)) & 1;
            sa |= a;
            sb |= b;
            if (a && b) break;
        }
        {
            /* struct input_event on this 32-bit kernel: 8 bytes of time, u16 type, u16 code, s32 value */
            unsigned char ev[16 * 8];
            long n = sc(SYS_read, fd, (long)ev, sizeof ev, 0, 0);
            for (i = 0; n > 0 && i + 16 <= n; i += 16) {
                unsigned type = ev[i + 8] | (ev[i + 9] << 8), code = ev[i + 10] | (ev[i + 11] << 8);
                long value = ev[i + 12] | (ev[i + 13] << 8);
                if (type == 1 && value) { if (code == KEY_A) sa = 1; if (code == KEY_B) sb = 1; }
            }
        }
        if (sa && sb) break;
        nap_ms(50);
    }
    sc(SYS_close, fd, 0, 0, 0, 0);
    return (a && b) || (sa && sb);
}

static int read_tries(const char *path)
{
    char c[4] = {0, 0, 0, 0};
    long fd = sc(SYS_open, (long)path, O_RDONLY, 0, 0, 0);
    if (fd < 0) return 0;
    sc(SYS_read, fd, (long)c, 3, 0, 0);
    sc(SYS_close, fd, 0, 0, 0, 0);
    return (c[0] >= '0' && c[0] <= '9') ? c[0] - '0' : TRIES_MAX; /* unreadable: treat as used up */
}

static int write_tries(const char *path, int n)
{
    char c[2] = {(char)('0' + n), '\n'};
    long fd = sc(SYS_open, (long)path, O_WRONLY | O_CREAT | O_TRUNC, 0644, 0, 0);
    if (fd < 0) return -1;
    if (sc(SYS_write, fd, (long)c, 2, 0, 0) != 2) { sc(SYS_close, fd, 0, 0, 0, 0); return -1; }
    sc(SYS_fsync, fd, 0, 0, 0, 0);
    sc(SYS_close, fd, 0, 0, 0, 0);
    return 0;
}

static char *const envp[] = {"HOME=/", "TERM=linux", "PATH=/sbin:/usr/sbin:/bin:/usr/bin", 0};

#ifdef KEYTEST
/* keytest (build.sh): only the safe-mode check, on the running cabinet, to try it with real or injected keys. */
void _start_c(void)
{
    int r = keys_held();
    sc(SYS_write, 1, (long)(r ? "safe\n" : "normal\n"), r ? 5 : 7, 0, 0);
    sc(SYS_exit, 0, 0, 0, 0, 0);
}
#else
void _start_c(void)
{
    int i, stage2 = 0, data = 0;
    sc(SYS_mkdir, (long)"/dev", 0755, 0, 0, 0);
    sc(SYS_mount, (long)"devtmpfs", (long)"/dev", (long)"devtmpfs", 0, 0);
    say("start", 0);
    /* The flash driver can come up after init starts (the stock cmdline says rootwait). */
    for (i = 0; i < 300 && !exists(ROOT_DEV); i++) nap_ms(100);
    sc(SYS_mkdir, (long)"/newroot", 0755, 0, 0, 0);
    for (i = 0; i < 50; i++) {
        if (sc(SYS_mount, (long)ROOT_DEV, (long)"/newroot", (long)"squashfs", MS_RDONLY, 0) == 0) break;
        nap_ms(200);
    }
    if (i == 50) {
        say("could not mount the system image ", ROOT_DEV);
        for (;;) nap_ms(10000);
    }
    if (keys_held()) {
        say("1-player + 2-player held: the stock boot", 0);
    } else if (sc(SYS_mount, (long)DATA_DEV, (long)"/newroot/userdata", (long)"ext2", 0, 0) == 0) {
        data = 1;
        if (exists("/newroot/userdata/boot/stage2.sh") && !exists("/newroot/userdata/boot/disabled")) {
            int n = read_tries("/newroot/userdata/boot/tries");
            if (n >= TRIES_MAX) {
                say("stage2 skipped: the last boots did not finish (boot/tries); the stock boot", 0);
            } else if (write_tries("/newroot/userdata/boot/tries", n + 1) == 0) {
                stage2 = 1;
            } else {
                say("could not count the try; the stock boot", 0);
            }
        }
    } else {
        say("could not mount the data partition; the stock boot", 0);
    }
    if (data && !stage2) {
        sc(SYS_umount2, (long)"/newroot/userdata", 0, 0, 0, 0);
    }
    /* switch_root: /dev comes along, the system image becomes / (the few KB of initramfs stay behind). */
    sc(SYS_mount, (long)"/dev", (long)"/newroot/dev", 0, MS_MOVE, 0);
    if (sc(SYS_chdir, (long)"/newroot", 0, 0, 0, 0) == 0 && sc(SYS_mount, (long)".", (long)"/", 0, MS_MOVE, 0) == 0 &&
        sc(SYS_chroot, (long)".", 0, 0, 0, 0) == 0) {
        sc(SYS_chdir, (long)"/", 0, 0, 0, 0);
        if (stage2) {
            long pid = sc(SYS_fork, 0, 0, 0, 0, 0);
            if (pid == 0) {
                char *const argv[] = {"sh", "/userdata/boot/stage2.sh", 0};
                sc(SYS_execve, (long)"/bin/sh", (long)argv, (long)envp, 0, 0);
                sc(SYS_exit, 127, 0, 0, 0, 0);
            }
            if (pid > 0) {
                int st = 0, t;
                say("stage2 running", 0);
                /* wait4(pid, &st, WNOHANG) every 100 ms; past the limit it is killed. */
                for (t = 0; t < STAGE2_SECONDS * 10; t++) {
                    if (sc(SYS_wait4, pid, (long)&st, 1, 0, 0) == pid) break;
                    nap_ms(100);
                }
                if (t == STAGE2_SECONDS * 10) {
                    say("stage2 took too long: stopped", 0);
                    sc(SYS_kill, pid, 9, 0, 0, 0);
                    sc(SYS_wait4, pid, (long)&st, 0, 0, 0);
                } else {
                    say(st == 0 ? "stage2 done" : "stage2 failed (the boot goes on)", 0);
                }
            } else {
                say("could not start stage2", 0);
            }
            /* The stock boot mounts the data partition itself. */
            sc(SYS_umount2, (long)"/userdata", MNT_DETACH, 0, 0, 0);
        } else {
            say("the stock boot", 0);
        }
        {
            char *const argv[] = {"init", 0};
            sc(SYS_execve, (long)"/sbin/init", (long)argv, (long)envp, 0, 0);
        }
    }
    say("could not start /sbin/init", 0);
    for (;;) nap_ms(10000);
}

#endif

/* The entry point: a stack is set up by the kernel; call into C and never return. */
__asm__(".global _start\n_start:\n  bl _start_c\n1: b 1b\n");

/* The compiler may call these for struct and array copies. */
void *memcpy(void *d, const void *s, ul n) { char *a = d; const char *b = s; while (n--) *a++ = *b++; return d; }
void *memset(void *d, int c, ul n) { char *a = d; while (n--) *a++ = (char)c; return d; }
