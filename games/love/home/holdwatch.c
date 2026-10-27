/* holdwatch: sound for the stock games' exit hold. A classic leaves when 1-player is held for 5 s, and the stock
 * emulator shows nothing while it is held (the user: "oftentimes feels like nothing is happening"). homeloop
 * runs this beside each classic: while 1-player alone is held, a tick at 1, 2, 3 and 4 s, each higher, and a
 * chime at 5 s. Letting go, or 2-player too (the stock reset), stops it. Sounds are played with aplay through
 * ALSA's dmix (homeloop's ALSA_CONFIG_PATH), mixed over the game's own sound.
 *   holdwatch SFX_DIR          SFX_DIR/hold1.wav .. hold4.wav, holdgo.wav; runs until killed
 *   holdwatch --back SFX_DIR   beside the stock menu (Home's "Original menu"): 1-player + 2-player held 3 s while
 *                              the menu is on its own screen (no start.sh running: not in a game, where that is
 *                              the stock reset) ticks, chimes and exits 0, and homeloop brings Home back */
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#define KEY_1P 0x136
#define KEY_2P 0x137

static char dir[256];

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static void play(const char *name)
{
    char path[320];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    if (fork() == 0) {
        int fd = open("/dev/null", O_RDWR);
        if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); }
        execl("/usr/bin/aplay", "aplay", "-q", path, (char *)NULL);
        _exit(127);
    }
}

/* A stock game is running: the stock menu runs games through /data/start.sh. */
static int in_game(void)
{
    DIR *d = opendir("/proc");
    struct dirent *e;
    char p[64], comm[32];
    int found = 0;
    if (!d) return 0;
    while (!found && (e = readdir(d))) {
        FILE *f;
        if (e->d_name[0] < '1' || e->d_name[0] > '9') continue;
        snprintf(p, sizeof p, "/proc/%.20s/comm", e->d_name);
        if (!(f = fopen(p, "r"))) continue;
        if (fgets(comm, sizeof comm, f) && !strncmp(comm, "start.sh", 8)) found = 1;
        fclose(f);
    }
    closedir(d);
    return found;
}

static int back_mode(void)
{
    int fd = open("/dev/input/event0", O_RDONLY), d1 = 0, d2 = 0, stage = 0;
    double t0 = 0;
    static const double at[] = {1.0, 2.0, 3.0};
    static const char *const snd[] = {"hold1.wav", "hold3.wav", "holdgo.wav"};
    if (fd < 0) return 1;
    for (;;) {
        fd_set rs;
        struct timeval tv = {0, 50000};
        FD_ZERO(&rs);
        FD_SET(fd, &rs);
        if (select(fd + 1, &rs, NULL, NULL, &tv) > 0) {
            struct input_event ev;
            if (read(fd, &ev, sizeof ev) != sizeof ev) return 1;
            if (ev.type == EV_KEY && ev.value != 2) {
                int was = d1 && d2;
                if (ev.code == KEY_1P) d1 = ev.value;
                if (ev.code == KEY_2P) d2 = ev.value;
                if (d1 && d2 && !was) { t0 = now(); stage = in_game() ? 3 : 0; }
            }
        }
        if (!(d1 && d2)) stage = 0;
        else if (stage < 3 && now() - t0 >= at[stage]) {
            play(snd[stage]);
            if (++stage == 3) { usleep(300000); return 0; }
        }
    }
}

/* The classic's exit hold: 1-player alone. */
static int exit_mode(int argc, char **argv)
{
    int fd, down1 = 0, down2 = 0, stage = 0;
    double t0 = 0;
    static const double at[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    static const char *const snd[] = {"hold1.wav", "hold2.wav", "hold3.wav", "hold4.wav", "holdgo.wav"};
    if (argc != 2) { fprintf(stderr, "usage: holdwatch SFX_DIR\n"); return 2; }
    snprintf(dir, sizeof dir, "%s", argv[1]);
    signal(SIGCHLD, SIG_IGN);                  /* aplay children reap themselves */
    signal(SIGUSR1, SIG_IGN);
    signal(SIGUSR2, SIG_IGN);
    fd = open("/dev/input/event0", O_RDONLY);
    if (fd < 0) { perror("/dev/input/event0"); return 1; }
    for (;;) {
        fd_set rs;
        struct timeval tv = {0, 50000};
        FD_ZERO(&rs);
        FD_SET(fd, &rs);
        if (select(fd + 1, &rs, NULL, NULL, &tv) > 0) {
            struct input_event ev;
            if (read(fd, &ev, sizeof ev) != sizeof ev) return 1;
            if (ev.type == EV_KEY && ev.value != 2) {
                if (ev.code == KEY_1P) {
                    down1 = ev.value;
                    if (down1) { t0 = now(); stage = 0; }
                }
                if (ev.code == KEY_2P) down2 = ev.value;
            }
        }
        if (down1 && !down2 && stage < 5 && now() - t0 >= at[stage]) {
            play(snd[stage]);
            stage++;
        }
        if (!down1 || down2) stage = down1 ? 5 : 0;   /* with 2-player too: the reset, not the exit: no sound */
    }
}

int main(int argc, char **argv)
{
    if (argc == 3 && !strcmp(argv[1], "--back")) {
        snprintf(dir, sizeof dir, "%s", argv[2]);
        signal(SIGCHLD, SIG_IGN);
        signal(SIGUSR1, SIG_IGN);
        signal(SIGUSR2, SIG_IGN);
        return back_mode();
    }
    return exit_mode(argc, argv);
}
