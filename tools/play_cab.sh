#!/bin/sh
# tools/play_cab.sh SYSTEM ROM SECONDS [ACTIONS]: run the Shelf's player (games/native/play) on the cabinet's
# glass with one game, then give Home back. ROM is relative to /mnt/sdcard/library.
# ACTIONS is a space-separated list run from this PC while the game plays, in order:
#   sN         sleep N seconds            shot:NAME   grab the screen (tools/cab.sh shot) to OUT/NAME.png
#   key:K      press a control (up down left right 1p 2p low tl tr)
#   quit       hold 1P+2P for 1.5 s (the player should leave by itself; checked)
# Default ACTIONS: "s3 key:1p sN shot:play" (Start, then a screenshot near the end). OUT is PLAY_OUT or
# /tmp/play_cab. Prints the player's log (its fps lines every 5 s, with where the time went).
# Refuses while the cabinet is in use (a game, the yard, the TV), like show_cab.sh.
set -e
SYS=$1; ROM=$2; SECS=${3:-20}
ACTIONS=${4:-"s3 key:1p s$((SECS - 5)) shot:play"}
OUT=${PLAY_OUT:-/tmp/play_cab}; mkdir -p "$OUT"
T=$(dirname "$0")
HOST=$($T/cab.sh host)
SSH="ssh -i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$HOST"
BUSY=$($SSH 'pidof yard play >/dev/null && echo busy; for p in $(pidof love.bin); do grep -q home.love /proc/$p/cmdline || echo busy; done; pidof PacMan SuperPacMan PacLand NS1 Galaga Galaxian Mappy DigDug orb start.sh game tvloop tvplay >/dev/null && echo busy; true')
case "$BUSY" in *busy*) echo "cabinet busy: not running"; exit 1;; esac
$SSH "for p in \$(pidof homeloop) \$(pidof love.bin); do kill -9 \$p; done; n=0; while pidof love.bin >/dev/null && [ \$n -lt 20 ]; do sleep 0.3; n=\$((n+1)); done
rm -rf /tmp/pc; mkdir -p /tmp/pc; cd /mnt/sdcard/library
dmesg -c >/dev/null 2>&1 || true
(PLAY_LIB=/mnt/sdcard/library PLAY_LOG=/tmp/pc/log ALSA_CONFIG_PATH=/data/home/alsa.conf ${PLAY_ENV:-} \
  setsid bin/play $SYS \"$ROM\" </dev/null >/tmp/pc/out 2>&1 &)"
trap '$SSH "pidof play >/dev/null && kill \$(pidof play); sleep 1; pidof homeloop >/dev/null || (setsid /data/home/homeloop </dev/null >/dev/null 2>&1 &)"' INT TERM
set +e
START=$(date +%s)
LEFT=0
for a in $ACTIONS; do
  case $a in
    shot:*) $T/cab.sh shot "$OUT/${a#shot:}.png" >/dev/null 2>&1 && echo "screenshot: $OUT/${a#shot:}.png" ;;
    key:*) $T/cab.sh key "${a#key:}" >/dev/null 2>&1 ;;
    quit) $T/cab.sh hold 1p 2p 1500 >/dev/null 2>&1; sleep 1
          $SSH 'pidof play >/dev/null' && echo "QUIT HOLD: player still running" || { echo "quit hold: player left"; LEFT=1; } ;;
    s[0-9]*) sleep "${a#s}" ;;
  esac
done
NOW=$(date +%s); [ $((NOW - START)) -lt "$SECS" ] && [ $LEFT = 0 ] && sleep $((SECS - (NOW - START)))
$SSH "p=\$(pidof play); [ -n \"\$p\" ] && awk '/VmRSS/ {print \"rss \" int(\$2 / 1024) \" MB\"}' /proc/\$p/status
free -m | awk '/Mem:/ {print \"available \" \$4 + \$6 + \$7 \" MB\"}'
[ -n \"\$p\" ] && kill \$p; n=0; while pidof play >/dev/null && [ \$n -lt 20 ]; do sleep 0.3; n=\$((n+1)); done
pidof play >/dev/null && { echo 'play did not quit on SIGTERM: killed'; kill -9 \$(pidof play); }
pidof homeloop >/dev/null || (setsid /data/home/homeloop </dev/null >/dev/null 2>&1 &)
grep -E 'play:|core:.*(rror|arn)' /tmp/pc/log | sed 's/^ *[0-9.]* //' | head -40
ls /mnt/sdcard/library/saves/$SYS 2>/dev/null | sed 's/^/save: /'
dmesg | grep -E 'Out of memory|Killed process|segfault' | tail -3; true"
