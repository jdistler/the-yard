#!/bin/sh
# tools/cabview/build.sh: build cabctl (static armhf) in the partycade-armhf image (games/toolchain).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
docker image inspect partycade-armhf >/dev/null 2>&1 || docker build -t partycade-armhf "$HERE/../../games/toolchain"
mkdir -p "$HERE/out"
docker run --rm -u "$(id -u):$(id -g)" -v "$HERE:/w" -w /w partycade-armhf \
  arm-linux-gnueabihf-gcc -O2 -static -Wall -Wextra -o out/cabctl cabctl.c
