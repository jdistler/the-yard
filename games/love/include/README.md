# Headers for building LÖVE for the cabinet

Headers only, so `games/love/build.sh` needs no distribution packages. SDL and OpenAL open these libraries at
run time on the cabinet (the cabinet's own copies: Mali EGL/GLES, libgbm, libdrm, ALSA, udev); nothing links
against them. Taken from Ubuntu 24.04's `-dev` packages:

| Headers | From | License |
| :--- | :--- | :--- |
| `libdrm/`, `xf86drm.h`, `xf86drmMode.h` | libdrm 2.4.125 | MIT |
| `gbm.h` | Mesa 25.2 | MIT |
| `EGL/`, `GLES/`, `GLES2/`, `KHR/` | Khronos (libglvnd 1.7.0 packages) | Apache 2.0 / MIT (Khronos) |
| `alsa/`, `asoundlib.h`, `sys/` | alsa-lib 1.2.11 | LGPL 2.1 |
| `libudev.h` | systemd 255 | LGPL 2.1 |
