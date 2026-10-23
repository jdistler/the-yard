# Cross toolchain for the Partycade: armhf, glibc 2.28 (the cabinet has 2.29), GCC 8.
# Debian 10 "buster" is archived, hence archive.debian.org.
FROM debian:buster-slim

RUN printf 'deb http://archive.debian.org/debian buster main\n' > /etc/apt/sources.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      gcc-arm-linux-gnueabihf libc6-dev-armhf-cross make ca-certificates curl xz-utils file binutils \
 && rm -rf /var/lib/apt/lists/*

# SDL 2.0.7 headers, configured for armhf, so games can only use API the cabinet has.
RUN curl -fsSL https://github.com/libsdl-org/SDL/releases/download/release-2.0.7/SDL2-2.0.7.tar.gz -o /tmp/sdl.tgz \
 || curl -fsSL https://www.libsdl.org/release/SDL2-2.0.7.tar.gz -o /tmp/sdl.tgz; \
    cd /tmp && tar xzf sdl.tgz && cd SDL2-2.0.7 \
 && ./configure --host=arm-linux-gnueabihf --prefix=/opt/sdl2 --disable-video-x11 --disable-video-wayland >/dev/null \
 && mkdir -p /opt/sdl2/include/SDL2 && cp include/*.h /opt/sdl2/include/SDL2/ \
 && rm -rf /tmp/SDL2-2.0.7 /tmp/sdl.tgz

WORKDIR /src
