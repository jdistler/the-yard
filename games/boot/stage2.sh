#!/bin/sh
# /userdata/boot/stage2.sh: run by yardinit (games/boot/tinyinit.c) at every power-on, before the stock boot,
# as a child with a 30 s limit; whatever happens here, the stock /sbin/init starts after it. The system image
# is mounted at / (read-only), the data partition at /userdata (read-write); /dev is up, /proc is not.
# Everything here can be changed over Wi-Fi (games/cart push). To stop it: create /userdata/boot/disabled, or
# hold 1-player + 2-player at power-on. To keep stage2 but boot the stock menu: /userdata/boot/home-off.
B=/userdata/boot
LOG=$B/boot.log
kmsg() { echo "<5>stage2: $*" > /dev/kmsg; }
mount -t proc proc /proc 2>/dev/null   # for /proc/uptime here; the stock boot mounts it again, so it is undone below
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 65536 ] && mv "$LOG" "$LOG.1"
echo "stage2 v2 at $(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo ?) s (tries $(cat $B/tries 2>/dev/null))" >> "$LOG"
kmsg "v2, tries $(cat $B/tries 2>/dev/null)"

# boot/film (made by tools/cab.sh bootfilm, used once): film the screen for 40 s from here, 1/16 size, five
# frames a second, into /dev (RAM, ~2 MB); tools/cab.sh bootfilm collects it.
if [ -f $B/film ] && [ -x /userdata/tools/cabctl ]; then
  rm -f $B/film
  mkdir -p /dev/.partycade
  cp /userdata/tools/cabctl /dev/.partycade/cabctl
  ( /dev/.partycade/cabctl record 40 200 16 > /dev/.partycade/bootfilm.ppm 2>/dev/.partycade/bootfilm.err
    echo "exit $?" >> /dev/.partycade/bootfilm.err ) </dev/null &
fi

# Partycade Home at power-on (EXPERIENCE.md), unless boot/home-off exists or Home is not installed: our
# picture on the screen (it replaces U-Boot's "LOADING..." until Home's intro), and games/boot/S50ui bound
# over the stock /etc/init.d/S50ui, so the stock boot starts Home instead of the stock menu. The copy lives in
# /dev (RAM), not on the data partition, which tinyinit detaches after this script.
H=/userdata/home
if [ ! -f $B/home-off ] && [ -f $B/S50ui ] && [ -x $H/homeloop ] && [ -f $H/home.love ]; then
  [ -f $H/boot.fb.gz ] && gzip -dc $H/boot.fb.gz > /dev/fb0 2>/dev/null
  # Home's first start read LÖVE, its libraries and the Mali driver from flash: 2.6 s in LÖVE, against 0.6 s
  # warm (2026-10-27). Read them now, while the stock boot runs, so they are in memory when S50ui starts Home.
  ( cat /userdata/love/love.bin /userdata/love/lib/* /usr/lib/libmali-utgard-400-r7p0-wayland.so \
        $H/home.love $H/art/* > /dev/null 2>&1 ) </dev/null &
  mkdir -p /dev/.partycade && cp $B/S50ui /dev/.partycade/S50ui && chmod 755 /dev/.partycade/S50ui &&
    mount -o bind /dev/.partycade/S50ui /etc/init.d/S50ui &&
    { echo "Home at power-on: S50ui bound at $(cut -d' ' -f1 /proc/uptime) s" >> "$LOG"; kmsg "Home at power-on"; } ||
    { echo "could not bind S50ui: the stock menu" >> "$LOG"; kmsg "could not bind S50ui"; }
fi

# After the stock boot is up: Wi-Fi and SSH at once (without opening The Yard), then mark this boot healthy.
(
  kmsg "waiting for the stock boot to mount /userdata and start dropbear"
  i=0
  while [ $i -lt 120 ]; do
    grep -q " /userdata " /proc/mounts 2>/dev/null && pidof dropbear >/dev/null && break
    sleep 1
    i=$((i + 1))
  done
  if ! grep -q " /userdata " /proc/mounts 2>/dev/null; then kmsg "the stock boot did not mount /userdata in 120 s"; exit 0; fi
  [ -x /userdata/Games/yardnet ] && /userdata/Games/yardnet
  echo "system up after $i s; yardnet started" >> "$LOG"
  kmsg "system up after $i s; yardnet started"
  sleep 60
  echo 0 > $B/tries
  echo "healthy: tries reset at $(cut -d' ' -f1 /proc/uptime) s" >> "$LOG"
  sync
) </dev/null >/dev/null 2>&1 &
sync
umount /proc 2>/dev/null
exit 0
