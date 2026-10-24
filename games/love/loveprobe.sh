#!/bin/sh
# /data/Games/loveprobe and /data/Games/loveyard (the same script, two names): LÖVE launchers, started by
# the Yard's "LOVE probe" and "GPU yard" rows. loveprobe runs the probe; loveyard runs the carts on LÖVE.
# On the first run (or a newer love.tar.gz) it unpacks the bundle to /data/love. Linux writes those files
# itself, through SFTL, so none of them had to be placed offline. Then it runs the probe, which writes
# /data/Games/love-probe.txt. Everything it prints goes to /data/Games/love-probe.log.
cd /data/Games || exit 1
LOG=/data/Games/love-probe.log
{
  echo "loveprobe start $(date) $(cat /proc/uptime)"
  if [ ! -x /data/love/run.sh ] || [ love.tar.gz -nt /data/love/.stamp ]; then
    echo "unpacking love.tar.gz"
    rm -rf /data/love && mkdir -p /data/love && gzip -dc love.tar.gz | tar -xf - -C /data/love && touch /data/love/.stamp
    echo "unpacked: $?"
  fi
  df /data
  free
  case "$(basename "$0")" in
    loveyard)
      YARD_PAK=/data/Games/yard.pak YARD_LOG=/data/Games/love-yard.log YARD_STATS=1 /data/love/run.sh /data/love/yard.love
      ;;
    *)
      PROBE_OUT=/data/Games/love-probe.txt /data/love/run.sh /data/love/probe.love
      ;;
  esac
  echo "love exited $?"
} >> "$LOG" 2>&1
sync
