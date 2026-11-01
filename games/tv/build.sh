#!/bin/sh
# Build tvplay for the cabinet (games/tv/PLAN.md). Needs:
#   ~/mppbuild: Rockchip MPP built for armhf (build-arm/mpp/librockchip_mpp.a) and FFmpeg 4.1.11's headers
#   (the cabinet's libraries are FFmpeg 4.1: avcodec 58.35, avformat 58.20), with libavutil/avconfig.h written
#   by hand (little-endian, fast unaligned);
#   the system image dump (its /usr/lib: the cabinet's own libav*, linked against, not shipped);
#   our SDL (games/out/love-arm, from games/love/build.sh) and the partycade-mpp Docker image.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAMES=$(cd "$HERE/.." && pwd)
MPP=$HOME/mppbuild
# MPP built with only the H.264, HEVC and MPEG-2 decoders (the rest cost 400 KB on a /data with 3 MB free):
# cmake ... -DBUILD_TEST=OFF -DENABLE_{AV1D,AVS2D,AVSD,H263D,H264E,H265E,JPEGD,JPEGE,MPEG4D,VP8D,VP8E,VP9D,VPROC}=OFF
#   -ffunction-sections -fdata-sections, in ~/mppbuild/build-arm-slim
MPPLIB=${MPPLIB:-build-arm-slim}
ROOTFS=${ROOTFS:-$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs}
mkdir -p "$GAMES/out/cab"
docker run --rm -u "$(id -u):$(id -g)" -v "$HERE:/w" -v "$MPP:/mpp" -v "$GAMES/out:/out" -v "$ROOTFS/usr/lib:/cablib:ro" \
  -v "$HOME/lovebuild/src/SDL/include:/sdlinc/SDL2:ro" -v "$HOME/lovebuild/build-arm/SDL/include-config-release/SDL2:/sdlcfg:ro" \
  -w /w partycade-mpp \
  arm-linux-gnueabihf-g++ -O2 -Wall -x c tvplay.c -x none -o /out/cab/tvplay \
    -I/sdlcfg -I/sdlinc -I/mpp/ffmpeg-4.1.11 -I/mpp/mpp/inc -I/mpp/mpp/osal/inc -I/mpp/zinc \
    /mpp/${MPPLIB:-build-arm-slim}/mpp/librockchip_mpp.a -L/out/love-arm/lib -l:libSDL2-2.0.so.0 \
    -L/cablib -l:libavformat.so.58 -l:libavcodec.so.58 -l:libavutil.so.56 -l:libswresample.so.3 -l:libz.so.1 \
    -Wl,--gc-sections -s -Wl,--gc-sections -s -Wl,--allow-shlib-undefined -Wl,-rpath-link,/cablib -static-libstdc++ -static-libgcc -lpthread -ldl -lm
# tvnet: the guide's fetcher (HTTPS through the cabinet's libavformat; logos through libavcodec + libswscale).
# (zlib.h: any 1.x header, in ~/mppbuild/zinc; the cabinet has libz 1.2.11.)
docker run --rm -u "$(id -u):$(id -g)" -v "$HERE:/w" -v "$MPP:/mpp" -v "$GAMES/out:/out" -v "$ROOTFS/usr/lib:/cablib:ro" \
  -w /w partycade-mpp \
  arm-linux-gnueabihf-gcc -O2 -Wall tvnet.c -o /out/cab/tvnet -I/mpp/ffmpeg-4.1.11 -I/mpp/zinc \
    -L/cablib -l:libavformat.so.58 -l:libavcodec.so.58 -l:libavutil.so.56 -l:libswscale.so.5 -l:libz.so.1 \
    -Wl,--allow-shlib-undefined -Wl,-rpath-link,/cablib -s
# tvplay's glyph sheet (Home's font; games/tv/mkfont.py, Python with Pillow).
python3 "$HERE/mkfont.py" "$GAMES/out/cab/tvfont.gz" >/dev/null
echo "$GAMES/out/cab/tvplay $GAMES/out/cab/tvnet $GAMES/out/cab/tvfont.gz"
