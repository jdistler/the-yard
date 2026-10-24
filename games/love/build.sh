#!/usr/bin/env bash
# Build LÖVE 11.5 and everything it needs, for the cabinet (arm) or this PC (x86), from pinned sources.
#
#   games/love/build.sh arm     -> games/out/love-arm/   (Cortex-A7, hard float, glibc <= 2.28)
#   games/love/build.sh x86     -> games/out/love-x86/   (for running and testing on a Linux PC)
#
# The recipe, and why each part is the way it is:
#   * zig cc is the C and C++ compiler. It targets an exact glibc (2.28, under the cabinet's 2.29) without a
#     sysroot or Docker, so the binaries ask for no symbol the cabinet lacks. check_abi.py proves it.
#   * SDL 2.30 is built in, not the cabinet's 2.0.7, with KMSDRM (direct to the screen, as the stock games
#     do), OpenGL ES 2, and ALSA. It opens libEGL, libGLESv2, libgbm, libdrm, libasound, and libudev itself
#     at run time (the *_SHARED options). Nothing here links against the cabinet's vendor libraries, so no
#     copy of them is needed to build, and the cabinet's own Mali driver is what draws.
#   * LuaJIT 2.1 is the Lua. Its build runs a helper program on the build machine, so that helper is
#     built for 32-bit x86 (zig makes that too, static with musl, so no 32-bit loader is needed), to match
#     the 32-bit ARM target.
#   * OpenAL Soft (ALSA, opened at run time), libogg, libvorbis, libmodplug, FreeType, zlib: shared
#     libraries beside love, found through the run.sh launcher's LD_LIBRARY_PATH.
#   * Theora is built (LÖVE's graphics code refers to its video module even when video is off).
#   * Left out: MP3 (mpg123) and the network libraries. Nothing here needs them.
#   * Every library is stripped. The bundle goes on an ext2 card partition or in /data (CARTS.md, LOVE.md).
set -euo pipefail
T=${1:-arm}
HERE=$(cd "$(dirname "$0")" && pwd)
GAMES=$(dirname "$HERE")
W=${LOVE_WORK:-$HOME/lovebuild}
SRC=$W/src
OUT=$GAMES/out/love-$T
PREFIX=$W/prefix-$T
B=$W/build-$T
JOBS=$(nproc)

case $T in
  arm) ZT=arm-linux-gnueabihf.2.28; ZCPU="-mcpu=cortex_a7"; HOSTZT=x86-linux-musl; HOST=arm-linux-gnueabihf ;;
  x86) ZT=x86_64-linux-gnu.2.28; ZCPU=""; HOSTZT=x86_64-linux-musl; HOST=x86_64-linux-gnu ;;
  *) echo "usage: $0 arm|x86"; exit 2 ;;
esac

# --- sources, pinned ----------------------------------------------------------------------------------------
fetch() { # url dir tag
  [ -d "$SRC/$2" ] || git clone -q --depth 1 --branch "$3" "$1" "$SRC/$2"
}
mkdir -p "$SRC"
fetch https://github.com/love2d/love.git love 11.5
fetch https://github.com/libsdl-org/SDL.git SDL release-2.30.9
fetch https://github.com/LuaJIT/LuaJIT.git luajit v2.1
fetch https://github.com/kcat/openal-soft.git openal 1.23.1
fetch https://github.com/xiph/ogg.git ogg v1.3.5
fetch https://github.com/xiph/vorbis.git vorbis v1.3.7
fetch https://github.com/Konstanty/libmodplug.git modplug master
fetch https://github.com/xiph/theora.git theora v1.1.1
fetch https://github.com/freetype/freetype.git freetype VER-2-13-2
fetch https://github.com/madler/zlib.git zlib v1.3.1
# DRM, GBM, EGL, GLES, ALSA, and udev headers are in games/love/include (headers only; nothing links
# against them; see the README there).
HDR=$HERE/include

# --- the compiler -------------------------------------------------------------------------------------------
ZIG=${ZIG:-"python3 -m ziglang"}
mkdir -p "$W/bin-$T"
cat > "$W/bin-$T/cc" <<EOF
#!/bin/sh
exec $ZIG cc -target $ZT $ZCPU "\$@"
EOF
cat > "$W/bin-$T/c++" <<EOF
#!/bin/sh
exec $ZIG c++ -target $ZT $ZCPU "\$@"
EOF
cat > "$W/bin-$T/hostcc" <<EOF
#!/bin/sh
exec $ZIG cc -target $HOSTZT "\$@"
EOF
for t in ar ranlib; do printf '#!/bin/sh\nexec %s %s "$@"\n' "$ZIG" "$t" > "$W/bin-$T/$t"; done
chmod +x "$W"/bin-$T/*
export CC=$W/bin-$T/cc CXX=$W/bin-$T/c++ OBJCXX=$W/bin-$T/c++ AR=$W/bin-$T/ar RANLIB=$W/bin-$T/ranlib
export PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig
# -D_FILE_OFFSET_BITS=64 uses __xstat64/__fxstat64/__lxstat64 (whose glibc 2.29 ARM implementation ignores
# the version argument, whereas 32-bit __xstat rejects the _STAT_VER=0 that zig's generic xstatver.h passes
# instead of ARM's _STAT_VER_LINUX=3) and avoids EOVERFLOW on 64-bit host inodes under qemu-arm.
export CFLAGS="-O2 -fPIC -D_FILE_OFFSET_BITS=64 -I$PREFIX/include" CXXFLAGS="-O2 -fPIC -D_FILE_OFFSET_BITS=64 -I$PREFIX/include" LDFLAGS="-L$PREFIX/lib"
mkdir -p "$PREFIX" "$B"

cm() { # name srcdir [cmake args...]
  local n=$1 s=$2; shift 2
  [ -f "$B/$n.done" ] && return
  echo "== $n"
  cmake -S "$s" -B "$B/$n" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_AR="$AR" -DCMAKE_RANLIB="$RANLIB" \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR="${T/x86/x86_64}" -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX" -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
    -DBUILD_SHARED_LIBS=ON "$@" > "$B/$n.log" 2>&1 || { tail -30 "$B/$n.log"; exit 1; }
  ninja -C "$B/$n" install >> "$B/$n.log" 2>&1 || { tail -30 "$B/$n.log"; exit 1; }
  touch "$B/$n.done"
}

cm zlib "$SRC/zlib" -DZLIB_BUILD_EXAMPLES=OFF
cm ogg "$SRC/ogg" -DINSTALL_DOCS=OFF
cm vorbis "$SRC/vorbis"
cm freetype "$SRC/freetype" -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON \
  -DFT_REQUIRE_ZLIB=ON
cm modplug "$SRC/modplug"
cm openal "$SRC/openal" -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_INSTALL_EXAMPLES=OFF \
  -DALSOFT_BACKEND_PULSEAUDIO=OFF -DALSOFT_BACKEND_PIPEWIRE=OFF -DALSOFT_BACKEND_JACK=OFF -DALSOFT_BACKEND_OSS=OFF \
  -DALSOFT_BACKEND_SNDIO=OFF -DALSOFT_BACKEND_PORTAUDIO=OFF -DALSOFT_REQUIRE_ALSA=ON -DALSOFT_DLOPEN=ON \
  -DALSOFT_EMBED_HRTF_DATA=OFF -DALSA_INCLUDE_DIR="$HDR" -DALSA_LIBRARY=asound
cm SDL "$SRC/SDL" -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF -DSDL_X11=OFF -DSDL_WAYLAND=OFF \
  -DSDL_KMSDRM=ON -DSDL_KMSDRM_SHARED=ON -DSDL_OPENGL=OFF -DSDL_OPENGLES=ON -DSDL_VULKAN=OFF -DSDL_OFFSCREEN=ON \
  -DSDL_ALSA=ON -DSDL_ALSA_SHARED=ON -DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_JACK=OFF -DSDL_SNDIO=OFF \
  -DSDL_OSS=OFF -DSDL_LIBUDEV=ON -DSDL_DBUS=OFF -DSDL_IBUS=OFF -DSDL_RPATH=OFF -DSDL_HIDAPI=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS -I$HDR -I$HDR/libdrm" -DSDL_LOADSO=ON \
  -DSDL_KMSDRM_SHARED=ON -DSDL_ALSA_SHARED=ON -DSDL_DIRECTFB=OFF -DSDL_RPI=OFF -DSDL_VIVANTE=OFF -DSDL_SYSTEM_ICONV=OFF

if [ ! -f "$B/theora.done" ]; then
  echo "== theora"
  rm -rf "$B/theora" && cp -r "$SRC/theora" "$B/theora"
  (cd "$B/theora" && ./autogen.sh --help > "$B/theora.log" 2>&1;
    ./configure --host=$HOST --prefix="$PREFIX" --disable-examples --disable-encode --disable-oggtest \
      --disable-vorbistest --disable-sdltest --disable-spec --disable-doc --disable-static \
      OGG_CFLAGS="-I$PREFIX/include" OGG_LIBS="-L$PREFIX/lib -logg" LDFLAGS="$LDFLAGS -Wl,--undefined-version" >> "$B/theora.log" 2>&1 &&
    sed -i 's/-shared -nostdlib/-shared/g' libtool &&
    make -j"$JOBS" >> "$B/theora.log" 2>&1 && make install >> "$B/theora.log" 2>&1) || { tail -30 "$B/theora.log"; exit 1; }
  touch "$B/theora.done"
fi

if [ ! -f "$B/luajit.done" ]; then
  echo "== luajit"
  rm -rf "$B/luajit" && cp -r "$SRC/luajit" "$B/luajit"
  # On ARM: the four libgcc-named float helpers (rtshim.c), and LuaJIT's own unwinder instead of libgcc's
  # __gnu_unwind_frame, which zig does not have. Errors still unwind Lua frames; C++ frames are not crossed.
  LJX=""; LJLIBS=""
  if [ "$T" = arm ]; then
    "$CC" -O2 -fPIC -c "$HERE/rtshim.c" -o "$B/rtshim.o"
    LJX="-DLUAJIT_NO_UNWIND"; LJLIBS="$B/rtshim.o"
  else
    LJLIBS="-lunwind"   # zig's libunwind has the _Unwind_* calls LuaJIT makes; libgcc_s is not linked
  fi
  LJ="HOST_CC=$W/bin-$T/hostcc STATIC_CC=$CC TARGET_LD=$CC TARGET_STRIP=true TARGET_SYS=Linux BUILDMODE=dynamic"
  make -C "$B/luajit" -j"$JOBS" amalg $LJ DYNAMIC_CC="$CC -fPIC" TARGET_AR="$AR rcus" PREFIX="$PREFIX" \
    XCFLAGS="$LJX" TARGET_LIBS="$LJLIBS" > "$B/luajit.log" 2>&1 || { tail -30 "$B/luajit.log"; exit 1; }
  make -C "$B/luajit" install $LJ DYNAMIC_CC="$CC -fPIC" TARGET_AR="$AR rcus" PREFIX="$PREFIX" \
    XCFLAGS="$LJX" TARGET_LIBS="$LJLIBS" >> "$B/luajit.log" 2>&1
  touch "$B/luajit.done"
fi

if [ ! -f "$B/love.done" ]; then
  echo "== love"
  rm -rf "$B/love" && cp -r "$SRC/love" "$B/love"
  mkdir -p "$PREFIX/share/aclocal" && cp "$SRC/SDL/sdl2.m4" "$PREFIX/share/aclocal/"
  (cd "$B/love" && ACLOCAL_PATH="$PREFIX/share/aclocal" platform/unix/automagic > "$B/love.log" 2>&1 &&
    ./configure --host=$HOST --prefix="$PREFIX" --with-lua=luajit --disable-mpg123 \
      --disable-library-enet --disable-library-luasocket \
      lua_CFLAGS="-I$PREFIX/include/luajit-2.1" lua_LIBS="-L$PREFIX/lib -lluajit-5.1" \
      CPPFLAGS="-I$PREFIX/include -I$HDR" >> "$B/love.log" 2>&1 &&
    # libtool links C++ libraries with -nostdlib and then names the runtime it found for g++; with zig it
    # finds none, which would leave liblove without its C++ runtime and without libc. Let zig link them.
    sed -i 's/-shared -nostdlib/-shared/g' libtool &&
    make -j"$JOBS" >> "$B/love.log" 2>&1 && make install >> "$B/love.log" 2>&1) || { tail -40 "$B/love.log"; exit 1; }
  touch "$B/love.done"
fi

# --- the bundle ---------------------------------------------------------------------------------------------
rm -rf "$OUT" && mkdir -p "$OUT/lib"
cp -L "$PREFIX/bin/love" "$OUT/love.bin"
# The PC build also carries the luajit interpreter: `cart check` parses every cart with it (Lua 5.1 syntax).
[ "$T" = x86 ] && cp -L "$PREFIX/bin/luajit" "$OUT/luajit"
for l in liblove-11.5.so libSDL2-2.0.so.0 libluajit-5.1.so.2 libopenal.so.1 libvorbisfile.so.3 libvorbis.so.0 \
         libogg.so.0 libmodplug.so.1 libfreetype.so.6 libz.so.1 libtheoradec.so.1; do
  f=$(find "$PREFIX/lib" -maxdepth 1 -name "$l*" | sort | head -1)
  [ -n "$f" ] || { echo "missing $l"; exit 1; }
  # File each library under its SONAME, the name everything that needs it asks for.
  so=$(readelf -d "$f" | sed -n 's/.*soname: \[\(.*\)\]/\1/p')
  cp -L "$f" "$OUT/lib/${so:-$l}"
done
# Strip into a new file: zig objcopy writing over its own input leaves it empty. Keep the original if the
# stripped copy comes out empty or fails.
for f in "$OUT/love.bin" "$OUT"/luajit "$OUT"/lib/*; do
  [ -f "$f" ] || continue
  if $ZIG objcopy --strip-all "$f" "$f.strip" 2>/dev/null && [ -s "$f.strip" ]; then
    chmod --reference="$f" "$f.strip" && mv "$f.strip" "$f"
  else
    rm -f "$f.strip"
  fi
done
cat > "$OUT/run.sh" <<'EOF'
#!/bin/sh
# Start LÖVE from this folder: run.sh GAME.love|GAMEDIR [args]. The cabinet's own Mali, DRM and ALSA
# libraries are found by SDL in /usr/lib; ours come first from ./lib.
D=$(cd "$(dirname "$0")" && pwd)
export LD_LIBRARY_PATH="$D/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-kmsdrm}
export LOVE_GRAPHICS_USE_OPENGLES=1
exec "$D/love.bin" "$@"
EOF
chmod +x "$OUT/run.sh"
du -sh "$OUT"
echo "built $OUT"
