#!/bin/sh
# tools/cab.sh: the cabinet over Wi-Fi (ssh as root with ~/yard_key_ecdsa; see STATUS.md).
#   tools/cab.sh ssh [CMD...]          a shell, or one command
#   tools/cab.sh run CMD...            run CMD with the screen to itself: the stock menu is stopped first
#                                      (SIGKILL: it ignores SIGTERM) and started again after, as S50ui does
#   tools/cab.sh stop                  stop the stock menu and everything it started (no restart)
#   tools/cab.sh menu                  start the stock menu again if it is not running (screen back on)
#   tools/cab.sh host                  print the cabinet's address
# CAB_HOST overrides the address; otherwise it is found (see find_host).
# Why "run" exists (2026-10-26): a LÖVE test run while the stock menu was still up; when LÖVE exited it
# switched the video output off (VOP disabled, DPMS off), and the panel showed its colour test pattern
# until the stock menu was restarted.
OPTS="-i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
CACHE=$HOME/.cache/partycade-host
# The address: CAB_HOST, else the last one that worked, else the network is searched for a host that takes our
# key (the cabinet asks DHCP for the name "partycade", so the router lists it too).
find_host() {
  for h in ${CAB_HOST:-} $(cat "$CACHE" 2>/dev/null) 192.168.1.225; do
    ssh -n $OPTS -o ConnectTimeout=4 root@$h true 2>/dev/null && { echo $h; return 0; }
  done
  net=$(ip -4 route | awk '/ src / && !/docker|br-|tailscale/ {print $1; exit}')
  for h in $(nmap -p22 --open -n -T4 "$net" -oG - 2>/dev/null | awk '/22\/open/{print $2}'); do
    ssh -n $OPTS -o ConnectTimeout=4 root@$h true 2>/dev/null && { echo $h; return 0; }
  done
  return 1
}
H=$(find_host) || { echo "cabinet not found on the network (Wi-Fi starts when The Yard is opened after a boot)" >&2; exit 3; }
mkdir -p "$(dirname "$CACHE")" && echo "$H" > "$CACHE"
SSH="ssh $OPTS -o ConnectTimeout=8 root@$H"
MENU='pidof game >/dev/null || { cd / && env -i PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/ XDG_CONFIG_HOME=/userdata/ MG_CFG_PATH=/etc setsid /usr/bin/game </dev/null >/dev/null 2>&1 & sleep 3; }; echo "video: $(cat /sys/class/drm/card0-HDMI-A-1/enabled)"'
# Everything the stock menu runs: itself (ignores SIGTERM), its intro video, and every start.sh with the game
# it started, which includes its idle attract demo (PacMan -fast). Killing only the menu left that demo
# drawing over our tests (2026-10-26: every cart stuck at 30 fps, the user saw Pac-Man over The Yard).
STOP='for s in $(pidof start.sh); do for d in /proc/[0-9]*; do [ "$(cut -d" " -f4 $d/stat 2>/dev/null)" = "$s" ] && kill -9 ${d#/proc/} 2>/dev/null; done; kill -9 $s; done; kill -9 $(pidof game) $(pidof ffplay) 2>/dev/null; sleep 1'
case "$1" in
  host) echo "$H" ;;
  stop) exec $SSH "$STOP; ps | grep -E \"start.sh|game|ffplay|PacMan\" | grep -v grep; true" ;;
  ssh) shift; exec $SSH "$@" ;;
  menu) exec $SSH "$MENU" ;;
  run)
    shift
    if $SSH 'pidof yard >/dev/null'; then echo "The Yard is open on the cabinet (someone is playing): not taking the screen" >&2; exit 1; fi
    $SSH "$STOP; $*; rc=\$?; $MENU; exit \$rc" ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
