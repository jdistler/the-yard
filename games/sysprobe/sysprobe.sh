#!/bin/sh
# /data/Games/sysprobe: the Yard's "System probe" row (FIELD_TASKS.md). It runs with no screen for about
# two minutes, then the menu comes back. It records what the running Linux sees, and what changes while
# someone plugs things in, into /data/Games/sysprobe-N.txt (N counts up, so every run is kept).
#
# Read-only, apart from that one report file: it changes no setting, mounts nothing, loads nothing, and
# writes nothing to any partition. Reading the boot and rootfs partitions to checksum them is a plain read.
#
# The questions it answers: is the microSD slot alive, and what happens when a card goes in? Is USB-A alive
# and powered, and what does a stick or a Wi-Fi adapter show up as? Which drivers, firmware, and network
# tools are there? How does Linux see the flash (could a partition be updated from Linux, without Mask ROM)?
# Is ADB or dropbear running? Which device tree is live?
cd /data/Games 2>/dev/null || cd /tmp
N=1
while [ -e "sysprobe-$N.txt" ]; do N=$((N + 1)); done
OUT=$PWD/sysprobe-$N.txt
WATCH=${SYSPROBE_WATCH:-90}

sec() { echo; echo "===== $*"; }
show() { for f in "$@"; do [ -e "$f" ] && { echo "--- $f"; cat "$f" 2>&1; }; done; }
run() { echo "--- \$ $*"; "$@" 2>&1; }
attrs() { # DIR NAME...: one line of the attributes a sysfs device has
  d=$1; shift; line=""
  for a in "$@"; do [ -r "$d/$a" ] && line="$line $a=$(cat "$d/$a" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"; done
  echo "$d:$line"
}
usb_list() {
  for d in /sys/bus/usb/devices/*; do
    [ -e "$d/idVendor" ] && attrs "$d" idVendor idProduct manufacturer product serial speed bMaxPower bDeviceClass version
    case "$d" in *:*) drv=$(readlink "$d/driver" 2>/dev/null); attrs "$d" bInterfaceClass bInterfaceSubClass bInterfaceProtocol | sed "s|\$| driver=${drv##*/}|";; esac
  done
}
mmc_list() {
  for h in /sys/class/mmc_host/*; do
    [ -e "$h" ] || continue
    echo "host $h -> $(readlink -f "$h")"
    for c in "$h"/mmc*; do [ -e "$c/type" ] && attrs "$c" type name manfid oemid date serial cid csd scr ocr; done
  done
  for b in /sys/block/mmcblk* /sys/block/sd*; do [ -e "$b" ] && attrs "$b" size ro removable; done
}
snapshot() { # one line per thing that can appear when a device is plugged in
  { usb_list; mmc_list; cat /proc/partitions; ls /sys/class/net; ls /dev; mount; } 2>/dev/null | sort
}

{
echo "sysprobe run $N, $(date), uptime $(cat /proc/uptime)"
echo "watching for ${WATCH} s at the end: plug and unplug the card, the stick, and the Wi-Fi adapter then"

sec "kernel and board"
show /proc/version /proc/cmdline /proc/cpuinfo /proc/meminfo /proc/filesystems /proc/devices /proc/misc
run uname -a
run cat /proc/modules
run ls /lib/modules
sec "kernel config (only if CONFIG_IKCONFIG_PROC)"
[ -r /proc/config.gz ] && zcat /proc/config.gz 2>&1 || echo "no /proc/config.gz"

sec "the live device tree: status of the nodes that matter"
for n in dwmmc@10214000 dwmmc@10218000 dwmmc@1021c000 usb@10180000 usb@101c0000 eth@10200000 serial@20068000 serial@20064000 serial@20060000; do
  for base in /proc/device-tree /sys/firmware/devicetree/base; do
    if [ -d "$base/$n" ]; then
      echo "$n: status=$(cat "$base/$n/status" 2>/dev/null | tr -d '\0') dr_mode=$(cat "$base/$n/dr_mode" 2>/dev/null | tr -d '\0')"
      break
    fi
  done
done
show /proc/device-tree/model /proc/device-tree/compatible | tr -d '\0'; echo
run ls /proc/device-tree

sec "flash as Linux sees it"
show /proc/partitions /proc/mtd
run ls -l /dev/block/by-name /dev/block/platform /dev/rkflash* /dev/mtd* /dev/mmcblk* /dev/sd* /dev/nand*
run ls -l /dev/block
run mount
run df
run cat /proc/swaps
for p in $(awk 'NR>2 {print $4}' /proc/partitions); do
  echo "--- /sys/class/block/$p: $(cat /sys/class/block/$p/size 2>/dev/null) sectors, start $(cat /sys/class/block/$p/start 2>/dev/null), ro $(cat /sys/class/block/$p/ro 2>/dev/null), name $(grep PARTNAME /sys/class/block/$p/uevent 2>/dev/null)"
done
sec "checksums of the small partitions, read through Linux (compare with the dump's partition images)"
for p in $(awk 'NR>2 && $3 < 70000 {print $4}' /proc/partitions); do
  case $p in mmcblk*|sd*|loop*|ram*|zram*) continue;; esac
  sum=$( (sha256sum "/dev/$p" || md5sum "/dev/$p") 2>/dev/null | cut -d' ' -f1)
  echo "/dev/$p $(cat /sys/class/block/$p/size 2>/dev/null) sectors: $sum"
done

sec "USB"
usb_list
show /sys/class/udc/*/uevent /sys/class/udc/*/state /sys/class/udc/*/current_speed
run ls -l /sys/class/udc /sys/bus/usb/drivers /sys/kernel/config
show /sys/bus/platform/devices/10180000.usb/dr_mode /sys/bus/platform/devices/101c0000.usb/dr_mode
run ls /sys/bus/platform/devices
run ls -l /sys/bus/platform/drivers

sec "microSD"
mmc_list
run ls -l /sys/bus/mmc/drivers /sys/bus/platform/drivers/dwmmc_rockchip

sec "power"
for r in /sys/class/regulator/*; do [ -e "$r/name" ] && attrs "$r" name state microvolts num_users type; done
show /sys/kernel/debug/gpio

sec "network, Wi-Fi, firmware"
run ls -l /sys/class/net /sys/class/ieee80211 /sys/class/rfkill
for i in /sys/class/net/*; do [ -e "$i" ] && attrs "$i" address operstate type carrier; done
show /proc/net/dev /proc/net/wireless /etc/resolv.conf
run ls -lR /lib/firmware /etc/firmware /vendor/firmware
for t in ip ifconfig iw iwconfig iwlist wpa_supplicant wpa_cli hostapd udhcpc dhcpcd dropbear dropbearkey dbclient sshd \
         adbd telnetd nc wget curl tftp ftpd httpd rsync tar gzip xz unzip mkfs.vfat mkfs.ext2 mke2fs e2fsck fsck.fat \
         blkid fdisk sfdisk parted mount.exfat ntfs-3g insmod modprobe flash_erase nandwrite dd sha256sum md5sum; do
  w=$(command -v $t 2>/dev/null); echo "$t: ${w:-absent}"
done
run busybox --list

sec "processes and services"
run ps
show /etc/init.d/.usb_config
run ls -l /etc/init.d /etc/dropbear /var/run /tmp

sec "input and sound"
show /proc/bus/input/devices /proc/asound/cards /proc/asound/pcm

sec "dmesg (whole ring)"
run dmesg

sec "watching ${WATCH} s: what appears and disappears"
before=/tmp/sysprobe.before; after=/tmp/sysprobe.after
snapshot > $before
dmesg > /tmp/sysprobe.dmesg0 2>/dev/null
t=0
while [ $t -lt "$WATCH" ]; do
  sleep 2; t=$((t + 2))
  snapshot > $after
  if ! cmp -s $before $after; then
    echo "--- at ${t} s:"
    if command -v diff >/dev/null; then diff -u $before $after | grep '^[-+][^-+]'; else echo "(no diff) now:"; cat $after; fi
    cp $after $before
  fi
done
echo "--- dmesg lines added while watching:"
dmesg 2>/dev/null > /tmp/sysprobe.dmesg1
if command -v diff >/dev/null; then
  diff -u /tmp/sysprobe.dmesg0 /tmp/sysprobe.dmesg1 | grep '^+[^+]' || echo "(none)"
else
  tail -n 80 /tmp/sysprobe.dmesg1
fi
sec "the end of the watch"
mmc_list
usb_list
run mount
rm -f $before $after /tmp/sysprobe.dmesg0 /tmp/sysprobe.dmesg1
echo "sysprobe done $(date)"
} > "$OUT" 2>&1
sync
