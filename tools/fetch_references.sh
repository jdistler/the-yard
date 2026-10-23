#!/usr/bin/env bash
# Shallow-clone the upstream sources this project relies on into ./reference/.
# Safe to re-run: existing clones are left alone. Prints the commit of each clone.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reference
cd reference

clone() {
  local name=$1 url=$2
  if [ -d "$name/.git" ]; then
    echo "$name: already present"
  else
    git clone --depth 1 "$url" "$name"
  fi
}

# rkbin is several GB; fetch only the RK3036 loaders, their configs, and release notes.
if [ ! -d rkbin/.git ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/rockchip-linux/rkbin.git rkbin
  git -C rkbin sparse-checkout set RKBOOT bin/rk30 doc/release
else
  echo "rkbin: already present"
fi
# Rockchip's U-Boot fork (branch next-dev): only the parts about boot modes, hotkeys, and rockusb.
if [ ! -d u-boot/.git ]; then
  git clone --depth 1 --branch next-dev --filter=blob:none --sparse https://github.com/rockchip-linux/u-boot.git u-boot
  git -C u-boot sparse-checkout set --no-cone /arch/arm/mach-rockchip/ /arch/arm/include/asm/arch-rockchip/ \
    /cmd/rockusb.c /cmd/rkimgtest.c /drivers/usb/gadget/f_rockusb.c '/include/configs/rk3036*' '/include/configs/evb_rk3036*' '/configs/*rk3036*' '/configs/*rk3032*'
else
  echo "u-boot: already present"
fi
clone rkdeveloptool https://github.com/rockchip-linux/rkdeveloptool.git
clone xrock https://github.com/xboot/xrock.git
clone rkflashtool https://github.com/linux-rockchip/rkflashtool.git
# Rockchip kernel 4.4 SPI NAND + SFTL driver (spare layout, bad-block marks); single files, the tree is huge.
mkdir -p kernel-rkflash
for f in rk_sftl.h rk_sftl_arm_v7.S rkflash_blk.c rksfc_base.c flash.c sfc.c sfc_nand.c sfc_nand.h sfc_nand_mtd.c; do
  [ -f "kernel-rkflash/$f" ] || curl -sf -o "kernel-rkflash/$f" \
    "https://raw.githubusercontent.com/rockchip-linux/kernel/develop-4.4/drivers/rkflash/$f" || echo "kernel-rkflash/$f: not fetched"
done

echo
for r in rkbin u-boot rkdeveloptool xrock rkflashtool; do
  printf '%-14s %s %s\n' "$r" "$(git -C "$r" rev-parse --short HEAD)" "$(git -C "$r" log -1 --format=%cs)"
done
