#!/bin/sh
# Run the ARM LÖVE bundle under qemu-arm, with no screen and no cabinet:
#   games/love/smoke.sh [ROOTFS]
# ROOTFS is the cabinet's extracted rootfs (its glibc and libstdc++ are what the bundle will meet), by
# default ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs, or /usr/arm-linux-gnueabihf if that is
# missing. The last line is "smoke ok" when everything passed.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
B=$HERE/../out/love-arm
ROOTFS=${1:-$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs}
[ -d "$ROOTFS/lib" ] || { echo "no rootfs at $ROOTFS; using /usr/arm-linux-gnueabihf (not the cabinet's libraries)"; ROOTFS=/usr/arm-linux-gnueabihf; }
[ -x "$B/love.bin" ] || { echo "build it first: games/love/build.sh arm"; exit 1; }
QEMU=$(command -v qemu-arm-static || command -v qemu-arm)
T=$(mktemp -d)
(cd "$HERE/smoke" && zip -q -r -X "$T/smoke.love" .)
echo "qemu: $QEMU, rootfs: $ROOTFS"
LD_LIBRARY_PATH=$B/lib "$QEMU" -L "$ROOTFS" "$B/love.bin" "$T/smoke.love"
