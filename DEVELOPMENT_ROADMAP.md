# Custom Software Development & System Roadmap

The open questions below were answered on 2026-10-23. The ABI is ARM hard-float, glibc 2.29. The menu is MiniGUI, and the games are SDL2 on KMSDRM at 1024×768. Dig Dug II opens The Yard. [STATUS.md](STATUS.md) wins wherever this file still says something is unknown or unsolved. The rest is the earlier plan, including paths that were not taken. The way games are made now is [CARTS.md](CARTS.md).

This document outlines technical specifications and workflows for developing and running custom software, games, and homebrew on this arcade hardware.

## 0. Platform facts that are verified (2026-10-23)

These replace the generic guesses further down wherever they disagree.

* **SoC/RAM:** RK3032, 128 MiB. Keep games small, with no desktop stack.
* **OS:** Linux 4.4.194 built with Linaro GCC 6.3 (2017.05), rootfs SquashFS (read-only). The libc and float ABI aren't known yet; check `rootfs/bin/busybox` and `rootfs/lib` once the full rootfs is read (RUNBOOK Phase 2). Match that ABI before compiling anything.
* **Display:** VOP + `lvds-simple-panel`. Whether the stock launcher uses `/dev/fb0` or DRM is unknown until Phase 2.
* **Input:** evdev from the `uart-keys` driver. The joystick is `KEY_UP/DOWN/LEFT/RIGHT`, the buttons are `BTN_A` (`0x130`) through `BTN_THUMBR` (`0x13e`), and the volume keys are `KEY_VOLUMEUP/DOWN`.
* **Audio:** ALSA card `rockchip,rk3032-codec`.
* **Getting code onto the cabinet:** not solved yet. The options and their risks are in [RUNBOOK.md](RUNBOOK.md) Phase 3. The recommended first path is an SD card, which needs no flash writes.

---

## 1. Native Embedded Development (Targeting the RK3032 SoC)

If targeting the onboard Rockchip processor directly:

### A. Toolchain Setup
* **Target Architecture:** ARMv7-A (32-bit Cortex-A7)
* **Instruction Features:** Thumb-2, NEON SIMD, VFPv4-D16/D32
* **Cross-Compiler:** `arm-linux-gnueabihf-gcc` / `arm-linux-gnueabihf-g++` (assumes hard-float glibc; confirm against the stock rootfs first, see §0)

```bash
# Install cross-compilation toolchain on Ubuntu / Debian:
sudo apt install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf
```

### B. Compilation Flags
When building binaries for the RK3032 (Cortex-A7):
```bash
arm-linux-gnueabihf-gcc -O2 \
    -march=armv7-a \
    -mcpu=cortex-a7 \
    -mfpu=neon-vfpv4 \
    -mfloat-abi=hard \
    -o custom_game main.c
```

### C. Graphics & Video Output (Direct Framebuffer & DRM/KMS)
Because minimal embedded systems do not run desktop display servers (X11 or Wayland), custom games interface directly with the kernel's display subsystem:
1. **Linux Framebuffer (`/dev/fb0`):**
   * Simplest direct memory-mapped access.
   * Double-buffering handled via `FBIOPAN_DISPLAY` ioctls.
2. **DRM / KMS (Direct Rendering Manager / Kernel Mode Setting):**
   * Provides modern page-flipping, hardware vsync sync, and accelerated buffer allocation via Dumb Buffers or GBM.
3. **SDL2 with KMSDRM Backend:**
   * When compiling SDL2 for embedded Linux (`--enable-video-kmsdrm`), games can run full-screen natively at 60 FPS without a window manager.

### D. Display Panel Timings (BOE `DV170YGZ-N10`)
* **Horizontal Resolution:** 1280 pixels
* **Vertical Resolution:** 1024 pixels
* **Aspect Ratio:** 5:4
* **Frame Rate:** 60 Hz
* **Pixel Clock:** ~108 MHz
* **Interface:** Single-channel 30-pin LVDS, 8-bit color depth (or 6-bit + FRC).

---

## 2. Sample Framebuffer Test Program

Below is a minimal C test pattern demonstrating direct drawing to `/dev/fb0` on a 1280x1024 embedded Linux target:

```c
#include <fcntl.h>
#include <linux/fb.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

int main() {
    int fb_fd = open("/dev/fb0", O_RDWR);
    if (fb_fd < 0) {
        perror("Error opening /dev/fb0");
        return 1;
    }

    struct fb_var_screeninfo vinfo;
    if (ioctl(fb_fd, FBIOGET_VSCREENINFO, &vinfo) < 0) {
        perror("Error reading variable screen info");
        close(fb_fd);
        return 1;
    }

    printf("Display Resolution: %dx%d, %d bpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel);

    long screensize = vinfo.xres * vinfo.yres * (vinfo.bits_per_pixel / 8);
    char *fbp = (char *)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fb_fd, 0);

    if (fbp == MAP_FAILED) {
        perror("Error mapping framebuffer");
        close(fb_fd);
        return 1;
    }

    // Fill screen with solid color (32bpp BGRA format)
    for (int y = 0; y < vinfo.yres; y++) {
        for (int x = 0; x < vinfo.xres; x++) {
            long location = (x + vinfo.xoffset) * (vinfo.bits_per_pixel / 8) +
                            (y + vinfo.yoffset) * vinfo.xres * (vinfo.bits_per_pixel / 8);
            *((unsigned int *)(fbp + location)) = 0xFF00FF00; // Bright Green
        }
    }

    munmap(fbp, screensize);
    close(fb_fd);
    return 0;
}
```

---

## 3. Alternative Hardware Conversion Path (Recommended for Full Arcade Development)

If the goal is to develop a rich, full-featured multi-game arcade system without being limited by the stock PCB's small flash storage and closed firmware:

```text
[ Arcade Cabinet Frame & Art ]
              |
              +--> [ BOE DV170YGZ-N10 LCD Panel ] <--- LVDS Cable <--- [ Universal LVDS-to-HDMI Controller ]
              |                                                                     ^
              |                                                                     | HDMI Cable
              |                                                                     v
              +--> [ Controls & GB-CON-5 ] ---> [ Zero-Delay USB Encoder ] ---> [ Raspberry Pi 4/5 or Mini PC ]
```

### Components Required:
1. **Universal LVDS-to-HDMI Controller Board:**
   * Model: Standard **M.NT68676.2A** or compatible board flashed with firmware for the `DV170YGZ-N10` panel (1280x1024 30-pin LVDS, 5V or 12V panel power jumper).
   * Cost: ~$20.
   * Connects directly to the existing LCD ribbon cable and provides full-size HDMI in, plus standard 12V barrel power.
2. **Zero-Delay USB Arcade Encoder:**
   * Cost: ~$8–$10.
   * Adapts the microswitches and joystick from the control deck directly into a plug-and-play USB HID gamepad.
3. **Single-Board Computer (SBC):**
   * Raspberry Pi 4 / 5 or compact Intel N100 Mini PC running:
     * **Batocera Linux** (arcade-optimized Linux OS with native vertical display rotation support).
     * **RetroPie** or **Recalbox**.
     * Custom native SDL2/Raylib games.
4. **Advantages:**
   * Full open documentation and standard Linux package management.
   * Expandable storage (Micro-SD, USB 3.0, NVMe).
   * Native vertical arcade rotation (5:4 aspect ratio perfectly scales classic vertical games like Pac-Man, Galaga, Donkey Kong, etc.).
