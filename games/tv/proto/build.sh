#!/bin/sh
# Build tvproto for the cabinet: MPP static (~/mppbuild, see games/tv/PLAN.md), our SDL (games/out/love-arm).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAMES=$(cd "$HERE/../.." && pwd)
MPP=$HOME/mppbuild
docker run --rm -u "$(id -u):$(id -g)" -v "$HERE:/w" -v "$MPP:/mpp" -v "$GAMES/out/love-arm/lib:/sdllib" \
  -v "$HOME/lovebuild/src/SDL/include:/sdlinc/SDL2" -v "$HOME/lovebuild/build-arm/SDL/include-config-release/SDL2:/sdlcfg" -w /w partycade-mpp \
  arm-linux-gnueabihf-g++ -O2 -Wall -x c tvproto.c -x none -o tvproto \
    -I/sdlcfg -I/sdlinc -I/mpp/mpp/inc -I/mpp/mpp/osal/inc \
    /mpp/build-arm/mpp/librockchip_mpp.a -L/sdllib -l:libSDL2-2.0.so.0 -static-libstdc++ -static-libgcc -lpthread -ldl -lm
echo "$HERE/tvproto"
