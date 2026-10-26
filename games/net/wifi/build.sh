#!/bin/bash
# Wi-Fi for the cabinet without touching its kernel: cfg80211.ko, the RTL8821AU driver (TP-Link AC600,
# 2357:011e) and a static wpa_supplicant, built so the stock 4.4.194 kernel loads them.
#
#   games/net/wifi/build.sh            -> games/out/wifi/{cfg80211.ko,8821au.ko,wpa_supplicant,usb-ids.txt}
#                                         and games/out/wifi/wifi.tar.gz (what cart deploy --with-wifi ships)
#
# How the match was found (BOOT_RESEARCH.md, 2026-10-26): Rockchip's develop-4.4 tree, the vendor's compiler
# (Linaro GCC 6.3-2017.05, from the kernel's version string), and kernel_defconfig here, tuned until
# tools/kernel_abi.py found 7009 of 7152 exported functions byte-identical to the cabinet's, the rest in
# drivers these modules never touch. Module.symvers is the cabinet's own export list (kernel_abi.py symvers).
# Nothing here is a vendor binary; the sources are public and pinned below. Work tree: $WIFIBUILD.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
GAMES=$(cd "$HERE/../.." && pwd)
ROOT=$(cd "$GAMES/.." && pwd)
W=${WIFIBUILD:-$HOME/wifibuild}
BOOT=${BOOT_IMG:-$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/boot.img}
OUT=$GAMES/out/wifi
KERNEL_REPO=https://github.com/rockchip-linux/kernel.git KERNEL_BRANCH=develop-4.4
KERNEL_COMMIT=9ead5f3cbd6e0abd0ac70002205993c953c227ea
GCC_REPO=https://github.com/rockchip-toybrick/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.git
GCC_COMMIT=353c55a8a41b0adf3f0dd64fc33c545777cf1075
DRV_REPO=https://github.com/morrownr/8821au-20210708.git
DRV_COMMIT=1a819991f5b75e64dfcf922b96a6681f367cbba0
WPA=wpa_supplicant-2.11 WPA_SHA=912ea06f74e30a8e36fbb68064d6cdff218d8d591db0fc5d75dee6c81ac7fc0a
NL=libnl-3.9.0 NL_SHA=aed507004d728a5cf11eab48ca4bf9e6e1874444e33939b9d3dfed25018ee9bb

mkdir -p "$W" "$OUT"
docker image inspect partycade-armhf >/dev/null 2>&1 || docker build -t partycade-armhf "$GAMES/toolchain"
docker image inspect partycade-kbuild >/dev/null 2>&1 || docker build -t partycade-kbuild "$HERE"
pin() {  # pin DIR REPO COMMIT [BRANCH]
  if [ ! -d "$W/$1/.git" ]; then git clone -q --depth 1 ${4:+-b $4} "$2" "$W/$1"; fi
  if [ "$(git -C "$W/$1" rev-parse HEAD)" != "$3" ]; then
    git -C "$W/$1" fetch -q --depth 1 origin "$3" && git -C "$W/$1" checkout -q "$3"
  fi
}
pin kernel "$KERNEL_REPO" "$KERNEL_COMMIT" "$KERNEL_BRANCH"
pin gcc63 "$GCC_REPO" "$GCC_COMMIT"
pin 8821au "$DRV_REPO" "$DRV_COMMIT"
git -C "$W/8821au" checkout -q -- . && git -C "$W/8821au" apply "$HERE/8821au.patch"
for t in "$WPA:$WPA_SHA:https://w1.fi/releases" "$NL:$NL_SHA:https://github.com/thom311/libnl/releases/download/libnl3_9_0"; do
  IFS=: read -r n sha url <<<"$t"; url="${t#*:*:}"
  [ -f "$W/$n.tar.gz" ] || curl -fsSL -o "$W/$n.tar.gz" "$url/$n.tar.gz"
  echo "$sha  $W/$n.tar.gz" | sha256sum -c --quiet
  [ -d "$W/$n" ] || tar -xzf "$W/$n.tar.gz" -C "$W"
done
# Rockchip's gcc-wrapper.py wants a "python"; the image has one, the shebang may say python2.
sed -i '1s|^#!/usr/bin/env python$|#!/usr/bin/env python3|' "$W/kernel/scripts/gcc-wrapper.py"
python3 "$ROOT/tools/kernel_abi.py" symvers "$BOOT" "$W/cabinet.symvers"
cp "$HERE/kernel_defconfig" "$W/kernel/arch/arm/configs/partycade_defconfig"
cp "$HERE/wpa_supplicant.config" "$W/$WPA/wpa_supplicant/.config"

docker run --rm -u "$(id -u):$(id -g)" -v "$W:/w" partycade-kbuild bash -euo pipefail -c "
X='ARCH=arm CROSS_COMPILE=/w/gcc63/bin/arm-linux-gnueabihf-'
cd /w/kernel
make -s \$X partycade_defconfig
[ -f vmlinux ] || make -s \$X -j\$(nproc) vmlinux   # only for tools/kernel_abi.py code; modules do not need it
make -s \$X modules_prepare
cp /w/cabinet.symvers Module.symvers
make -s \$X M=net/wireless modules
cd /w/8821au && make -s -C /w/kernel M=/w/8821au \$X KBUILD_EXTRA_SYMBOLS=/w/kernel/net/wireless/Module.symvers CONFIG_RTL8821AU=m -j\$(nproc) modules
cd /w/$NL && { [ -f /w/sysroot/lib/libnl-genl-3.a ] || { ./configure -q --host=arm-linux-gnueabihf --prefix=/w/sysroot --enable-static --disable-shared --disable-cli --disable-debug && make -s -j\$(nproc) && make -s install; }; }
cd /w/$WPA/wpa_supplicant && CC=arm-linux-gnueabihf-gcc PKG_CONFIG=false CFLAGS='-Os -I/w/sysroot/include/libnl3' LDFLAGS='-static -L/w/sysroot/lib' make -s -j\$(nproc) LIBS='-lnl-genl-3 -lnl-3 -lpthread -lm' wpa_supplicant
" 2>&1 | grep -v -E "warning: Using '(getgrnam|getaddrinfo|getproto)" || true
for f in kernel/net/wireless/cfg80211.ko 8821au/8821au.ko "$WPA/wpa_supplicant/wpa_supplicant"; do
  [ -f "$W/$f" ] || { echo "missing $W/$f" >&2; exit 1; }
  cp "$W/$f" "$OUT/"
done
"$W/gcc63/bin/arm-linux-gnueabihf-strip" --strip-debug "$OUT/cfg80211.ko" "$OUT/8821au.ko"
"$W/gcc63/bin/arm-linux-gnueabihf-strip" "$OUT/wpa_supplicant"
# Every symbol a module needs must be one the cabinet exports, or cfg80211's own.
for m in cfg80211 8821au; do
  if "$W/gcc63/bin/arm-linux-gnueabihf-nm" -u "$OUT/$m.ko" | awk '{print $2}' \
     | grep -v -x -F -f <(cut -f2 "$W/cabinet.symvers"; "$W/gcc63/bin/arm-linux-gnueabihf-nm" "$OUT/cfg80211.ko" | awk '$2 ~ /[TDRB]/ {print $3}') \
     | grep -v '^__this_module$' | grep . ; then echo "$m.ko needs symbols the cabinet does not export" >&2; exit 1; fi
  [ "$(strings "$OUT/$m.ko" | grep -c '^vermagic=4.4.194 SMP mod_unload ARMv7 p2v8 $')" = 1 ] || { echo "$m.ko: wrong vermagic" >&2; exit 1; }
done
strings "$OUT/8821au.ko" | sed -n 's/^alias=usb:v\([0-9A-F]\{4\}\)p\([0-9A-F]\{4\}\).*/\1:\2/p' | tr 'A-F' 'a-f' | sort -u > "$OUT/usb-ids.txt"
grep -qx 2357:011e "$OUT/usb-ids.txt"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$OUT" -cf - cfg80211.ko 8821au.ko wpa_supplicant usb-ids.txt | gzip -n -9 > "$OUT/wifi.tar.gz"
ls -l "$OUT"
echo "built $OUT/wifi.tar.gz"
