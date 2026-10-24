#!/usr/bin/env bash
# ./build.sh pc | cab | all
# cab builds run in the partycade-armhf Docker image (games/toolchain/Dockerfile) and need the
# extracted stock rootfs for its libraries (ROOTFS, default below; it lives outside git).
set -euo pipefail
cd "$(dirname "$0")"
ROOTFS=${ROOTFS:-$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs}

pc() { make TARGET=pc; }
cab() {
  [ -f "$ROOTFS/usr/lib/libSDL2-2.0.so.0.7.0" ] || { echo "ROOTFS=$ROOTFS has no libSDL2 2.0.7"; exit 1; }
  docker image inspect partycade-armhf >/dev/null 2>&1 || docker build -t partycade-armhf toolchain
  docker run --rm -u "$(id -u):$(id -g)" -v "$PWD/..:/src" -v "$ROOTFS:/rootfs:ro" -w /src/games \
    partycade-armhf make TARGET=cab
  for b in out/cab/yard out/cab/orb out/cab/probe; do ./check_binary.sh "$b"; done
}

case ${1:-all} in
  pc) pc ;;
  cab) cab ;;
  all) pc; cab ;;
  *) echo "usage: $0 pc|cab|all"; exit 2 ;;
esac
