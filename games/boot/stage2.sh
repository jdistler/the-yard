#!/bin/sh
# /userdata/boot/stage2.sh: run by yardinit (games/boot/tinyinit.c) at every power-on, before the stock boot,
# as a child with a 30 s limit; whatever happens here, the stock /sbin/init starts after it. The system image
# is mounted at / (read-only), the data partition at /userdata (read-write); /dev is up, /proc is not.
# Everything here can be changed over Wi-Fi (games/cart push). To stop it: create /userdata/boot/disabled, or
# hold 1-player + 2-player at power-on.
B=/userdata/boot
LOG=$B/boot.log
kmsg() { echo "<5>stage2: $*" > /dev/kmsg; }
mount -t proc proc /proc 2>/dev/null   # for /proc/uptime here; the stock boot mounts it again, so it is undone below
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 65536 ] && mv "$LOG" "$LOG.1"
echo "stage2 v1 at $(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo ?) s (tries $(cat $B/tries 2>/dev/null))" >> "$LOG"
kmsg "v1, tries $(cat $B/tries 2>/dev/null)"

# Overrides of stock files (bind mounts) will go here: the intro video, the menu, the idle screen.

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
