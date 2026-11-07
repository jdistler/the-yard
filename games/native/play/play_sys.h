/* The Shelf's systems: which core, how the deck's three play buttons reach it, and the legend.
 *
 * btn[0..2] are the RetroPad ids for the lower button, top-left and top-right (-1: unused). 1-player is
 * Start and 2-player is Select on every system (CONTROLS.md: they start a turn); on arcade boards
 * 1-player is a coin and then Start, and 2-player a coin. Mappings were read from each core's source
 * (its input descriptors), 2026-11-07:
 *   PicoDrive and Genesis Plus GX, Mega Drive: RetroPad Y=A, B=B, A=C.   Master System / Game Gear: B=1, A=2.
 *   Genesis, Master System and Game Gear use PicoDrive (built here): 281 fps on Sonic 2 on the cabinet's CPU
 *   against Genesis Plus GX's 122 (the core on the squashfs), whose gameplay frames ran 13 ms and dropped
 *   the picture to 41 fps (2026-11-07). SG-1000 stays on Genesis Plus GX.
 *   FCEUmm: A=A, B=B.   Gambatte: A=A, B=B.   gpSP: A=A, B=B, R=R, L=L.   snes9x: the SNES pad as printed.
 *   Beetle PCE Fast: A=I, B=II.   Beetle NGP: B=A, A=B, Start=Option.   MAME 2000: B=1, A=2, Y=3.
 * Which physical button gets which game button: the lower button (the verb under the index finger) gets
 * the button the system's games use most (jump, fire); top-left the second; top-right the third.
 */
#ifndef PLAY_SYS_H
#define PLAY_SYS_H

#include "libretro.h"

#define RP(x) RETRO_DEVICE_ID_JOYPAD_##x

struct play_sys {
    const char *id, *name;
    const char *core; /* file in <lib>/cores, or an absolute path */
    int btn[3];
    const char *label[3]; /* printed under each button in the legend */
    int coin_start;
    const char *opts; /* core options, "key=value;..." */
    unsigned accent;  /* 0xRRGGBB: the system's colour on its card and marquee */
};

static const struct play_sys play_systems[] = {
    {"nes", "NES", "fceumm_libretro.so", {RP(A), RP(B), -1}, {"A", "B", ""}, 0,
     "fceumm_overscan_v=enabled;fceumm_palette=default", 0xd83a3a},
    {"snes", "Super Nintendo", "snes9x2005_libretro.so", {RP(B), RP(Y), RP(A)}, {"B", "Y", "A"}, 0, NULL, 0x7b5cd6},
    {"gb", "Game Boy", "gambatte_libretro.so", {RP(A), RP(B), -1}, {"A", "B", ""}, 0,
     "gambatte_gb_colorization=internal;gambatte_gb_internal_palette=GB - DMG", 0x8bac0f},
    {"gba", "Game Boy Advance", "gpsp_libretro.so", {RP(A), RP(B), RP(R)}, {"A", "B", "R"}, 0, NULL, 0x5a4fcf},
    {"genesis", "Genesis", "picodrive_libretro.so", {RP(B), RP(Y), RP(A)},
     {"B", "A", "C"}, 0, NULL, 0x2b6cd4},
    {"sms", "Master System", "picodrive_libretro.so", {RP(B), RP(A), -1}, {"1", "2", ""}, 0,
     NULL, 0xd8322e},
    {"gg", "Game Gear", "picodrive_libretro.so", {RP(B), RP(A), -1}, {"1", "2", ""}, 0, NULL,
     0x3b3b3b},
    {"sg", "SG-1000", "/usr/lib/libretro/genesis_plus_gx_libretro.so", {RP(B), RP(A), -1}, {"1", "2", ""}, 0, NULL,
     0x9a9a9a},
    {"pce", "PC Engine", "mednafen_pce_fast_libretro.so", {RP(A), RP(B), -1}, {"I", "II", ""}, 0, NULL, 0xe0e0e0},
    {"ngp", "Neo Geo Pocket", "mednafen_ngp_libretro.so", {RP(B), RP(A), RP(START)}, {"A", "B", "OPT"}, 0,
     "ngp_language=english", 0x1e64c8},
    {"arcade", "Arcade", "/usr/lib/libretro/mame2000_libretro.so", {RP(B), RP(A), RP(Y)}, {"1", "2", "3"}, 1,
     "mame2000-skip_disclaimer=enabled;mame2000-skip_warnings=enabled;mame2000-hiscore=enabled", 0xf0b030},
    {"arcade03", "Arcade", "/usr/lib/libretro/mame2003_libretro.so", {RP(B), RP(A), RP(Y)}, {"1", "2", "3"}, 1,
     "mame2003_skip_disclaimer=enabled;mame2003_skip_warnings=enabled", 0xf0b030},
};

static inline const struct play_sys *play_sys_find(const char *id)
{
    for (unsigned i = 0; i < sizeof play_systems / sizeof play_systems[0]; i++)
        if (!__builtin_strcmp(play_systems[i].id, id))
            return &play_systems[i];
    return 0;
}

#endif
