#!/bin/sh
# tools/show_cab.sh SHOW[:START|@SEG] SECONDS: play an idle show on the cabinet with Home's frame log, then give Home
# back. Prints two lines:
#   fps  "secs:fps" every 5 s (secs: Home's log clock; the show starts ~3 s in)
#   mem  "secs:rss:avail:gpu:shmem" every 5 s (MB): Home's resident memory, what's left for everything (free +
#        buffers + cached), the Mali driver's memory for Home (not in rss), shared memory. The cabinet has 115 MB.
# SPEC "auto": Home as it starts at power-on, no show forced (menu, attract, then AUTO's pick): a long session.
# Refuses while the cabinet is in use (a game, the yard, the TV). If Home dies (killed for memory, a crash), says so
# with the kernel's last words. Used by tools/show_review.py --cab.
set -e
SPEC=$1; SECS=$2
HOST=$($(dirname "$0")/cab.sh host)
SSH="ssh -i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$HOST"
BUSY=$($SSH 'pidof yard >/dev/null && echo busy; for p in $(pidof love.bin); do grep -q home.love /proc/$p/cmdline || echo busy; done; pidof PacMan SuperPacMan PacLand NS1 Galaga Galaxian Mappy DigDug orb start.sh game tvloop tvplay >/dev/null && echo busy; true')
case "$BUSY" in *busy*) echo "cabinet busy: not measuring"; exit 1;; esac
$SSH "for p in \$(pidof homeloop) \$(pidof love.bin); do kill -9 \$p; done; n=0; while pidof love.bin >/dev/null && [ \$n -lt 20 ]; do sleep 0.3; n=\$((n+1)); done
rm -rf /tmp/cs; mkdir -p /tmp/cs; cd /tmp/cs
dmesg -c >/dev/null 2>&1 || true
SHOWENV=\"HOME_SHOW=$SPEC\"; [ \"$SPEC\" = auto ] && SHOWENV=\"HOME_X=1\"
(TZ=CST6CDT,M3.2.0,M11.1.0 env \$SHOWENV HOME_SKIP_INTRO=1 HOME_STATE=/tmp/cs/state HOME_LOG=/tmp/cs/log HOME_FPS_EVERY=300 HOME_ART=/data/home/art HOME_GAMES=/data/Games HOME_REQ=/tmp/cs/req /data/love/run.sh /data/home/home.love >/tmp/cs/out 2>&1 &)
t=0
while [ \$t -lt $SECS ]; do
  sleep 5; t=\$((t + 5))
  p=\$(pidof love.bin | cut -d' ' -f1)
  r=0; [ -n \"\$p\" ] && r=\$(awk '/VmRSS/ {print int(\$2 / 1024)}' /proc/\$p/status 2>/dev/null)
  a=\$(free -m | awk '/Mem:/ {print \$4 + \$6 + \$7}')
  g=\$(awk -v p=\"\$p\" '\$2 == p {print int((\$3 + \$7) / 1048576)}' /sys/kernel/debug/mali/gpu_memory 2>/dev/null)
  sh=\$(awk '/^Shmem:/ {print int(\$2 / 1024)}' /proc/meminfo)
  echo \"\$t:\${r:-0}:\$a:\${g:-0}:\$sh\" >> /tmp/cs/mem
done
pidof love.bin >/dev/null || echo 'HOME DIED' > /tmp/cs/died
for p in \$(pidof love.bin); do kill -9 \$p; done; sleep 0.5
pidof homeloop >/dev/null || (setsid /data/home/homeloop </dev/null >/dev/null 2>&1 &)
grep rror /tmp/cs/log; true"
printf 'fps  '; $SSH "grep 'frames:' /tmp/cs/log" | sed -E 's/^([0-9]+)[.][0-9]+ frames: ([0-9.]+) fps.*/\1:\2/' | tr '\n' ' '; echo
printf 'mem  '; $SSH "cat /tmp/cs/mem" | tr '\n' ' '; echo
$SSH "[ -f /tmp/cs/died ] && { echo 'HOME DIED during the run:'; dmesg | grep -E 'Out of memory|Killed process' | tail -3; grep -v '^Post Color' /tmp/cs/out | tail -5; }; true"
