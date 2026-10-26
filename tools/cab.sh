#!/bin/sh
# tools/cab.sh: the cabinet over Wi-Fi (ssh as root with ~/yard_key_ecdsa; see STATUS.md).
#   tools/cab.sh ssh [CMD...]          a shell, or one command
#   tools/cab.sh run CMD...            run CMD with the screen to itself: the stock menu is stopped first
#                                      (SIGKILL: it ignores SIGTERM) and started again after, as S50ui does
#   tools/cab.sh stop                  stop the stock menu and everything it started (no restart)
#   tools/cab.sh menu                  start the stock menu again if it is not running (screen back on)
# CAB_HOST overrides the address (DHCP: check the router if it moved).
# Why "run" exists (2026-10-26): a LÖVE test run while the stock menu was still up; when LÖVE exited it
# switched the video output off (VOP disabled, DPMS off), and the panel showed its colour test pattern
# until the stock menu was restarted.
H=${CAB_HOST:-192.168.1.225}
SSH="ssh -i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$H"
MENU='pidof game >/dev/null || { cd / && env -i PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/ XDG_CONFIG_HOME=/userdata/ MG_CFG_PATH=/etc setsid /usr/bin/game </dev/null >/dev/null 2>&1 & sleep 3; }; echo "video: $(cat /sys/class/drm/card0-HDMI-A-1/enabled)"'
# Everything the stock menu runs: itself (ignores SIGTERM), its intro video, and every start.sh with the game
# it started, which includes its idle attract demo (PacMan -fast). Killing only the menu left that demo
# drawing over our tests (2026-10-26: every cart stuck at 30 fps, the user saw Pac-Man over The Yard).
STOP='for s in $(pidof start.sh); do for d in /proc/[0-9]*; do [ "$(cut -d" " -f4 $d/stat 2>/dev/null)" = "$s" ] && kill -9 ${d#/proc/} 2>/dev/null; done; kill -9 $s; done; kill -9 $(pidof game) $(pidof ffplay) 2>/dev/null; sleep 1'
case "$1" in
  stop) exec $SSH "$STOP; ps | grep -E \"start.sh|game|ffplay|PacMan\" | grep -v grep; true" ;;
  ssh) shift; exec $SSH "$@" ;;
  menu) exec $SSH "$MENU" ;;
  run)
    shift
    if $SSH 'pidof yard >/dev/null'; then echo "The Yard is open on the cabinet (someone is playing): not taking the screen" >&2; exit 1; fi
    $SSH "$STOP; $*; rc=\$?; $MENU; exit \$rc" ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
