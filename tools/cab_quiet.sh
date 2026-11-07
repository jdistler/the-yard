#!/bin/sh
# tools/cab_quiet.sh on|off: a dark, silent cabinet for testing while someone is nearby.
#   on   Home and homeloop stopped, the screen black (zeros into /dev/fb0; there is no backlight control, and
#        turning the video output off shows the panel's bright test pattern instead), the speaker muted.
#        The volume before is kept in /tmp/quiet.vol.
#   off  the volume put back, Home started again.
# Tests that need the screen still take it while they run (tools/play_cab.sh); run them with PLAY_ENV=PLAY_DARK=1
# to keep the picture black.
HOST=$($(dirname "$0")/cab.sh host)
SSH="ssh -i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$HOST"
case "$1" in
  on) $SSH '[ -f /tmp/quiet.vol ] || amixer sget Headphone | sed -n "s/.*: \([0-9]*\) \[.*/\1/p" | head -1 > /tmp/quiet.vol
            amixer -q sset Headphone 0 mute
            for p in $(pidof homeloop) $(pidof love.bin); do kill -9 $p; done; sleep 1
            dd if=/dev/zero of=/dev/fb0 bs=65536 2>/dev/null; echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
            echo "quiet: volume was $(cat /tmp/quiet.vol), now muted; Home stopped; screen black"' ;;
  off) $SSH 'v=$(cat /tmp/quiet.vol 2>/dev/null); amixer -q sset Headphone ${v:-2} unmute; rm -f /tmp/quiet.vol
             pidof homeloop >/dev/null || (setsid /data/home/homeloop </dev/null >/dev/null 2>&1 &)
             echo "awake: volume ${v:-2}, Home started"' ;;
  *) echo "usage: $0 on|off"; exit 2 ;;
esac
