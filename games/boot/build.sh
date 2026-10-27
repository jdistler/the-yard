#!/bin/sh
# tinyinit for the cabinet (out/tinyinit) and for the QEMU test (out/tinyinit-qemu: virtio disks, keys 1 and 2).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CC=${CC:-$HOME/wifibuild/gcc63/bin/arm-linux-gnueabihf-gcc}
mkdir -p "$HERE/out"
FLAGS="-Os -nostdlib -static -ffreestanding -fno-builtin -fno-stack-protector -fno-tree-loop-distribute-patterns -marm -march=armv7-a -Wl,-e,_start -Wl,--gc-sections -ffunction-sections -fdata-sections -Wall -Wextra -Wno-unused-parameter"
$CC $FLAGS -o "$HERE/out/tinyinit" "$HERE/tinyinit.c"
$CC $FLAGS -DROOT_DEV='"/dev/vda"' -DDATA_DEV='"/dev/vdb"' -DKEY_A=2 -DKEY_B=3 -o "$HERE/out/tinyinit-qemu" "$HERE/tinyinit.c"
$CC $FLAGS -DKEYTEST -o "$HERE/out/keytest" "$HERE/tinyinit.c"
${CC%gcc}strip "$HERE/out/tinyinit" "$HERE/out/tinyinit-qemu" "$HERE/out/keytest"
ls -l "$HERE/out/tinyinit" "$HERE/out/tinyinit-qemu"
