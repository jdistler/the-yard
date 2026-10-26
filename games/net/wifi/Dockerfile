# Kernel-module build image: the game toolchain image plus what kbuild needs on the host side.
# The modules themselves are compiled with Linaro GCC 6.3-2017.05, the compiler of the cabinet's kernel
# (build.sh fetches it); this image's GCC 8 only builds kbuild's host tools.
FROM partycade-armhf
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends gcc libc6-dev bc bison flex libssl-dev kmod python3 git \
 && ln -sf /usr/bin/python3 /usr/bin/python \
 && rm -rf /var/lib/apt/lists/*
