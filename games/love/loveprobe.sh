#!/bin/sh
# /data/Games/loveprobe and /data/Games/loveyard (the same script, two names): LÖVE launchers, started by
# the Yard's "LOVE probe" and "GPU yard" rows. loveprobe runs the probe; loveyard runs the carts on LÖVE.
# On the first run (or a changed love.tar.gz) it unpacks the bundle to /data/love. Linux writes those files
# itself, through SFTL, so none of them had to be placed offline. Everything it prints goes to
# /data/Games/love-probe.log.
cd /data/Games || exit 1
LOG=/data/Games/love-probe.log
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 262144 ] && mv "$LOG" "$LOG.1"
# The GPU yard asks for a native program (Orb) by writing its name here and quitting; this script runs it
# with the memory, the sound card, and the deck to itself, then starts LÖVE again.
REQ=/tmp/yard-love-launch
{
  echo "loveprobe start $(date) $(cat /proc/uptime)"
  # The cabinet's clock starts at 1970 on every boot, so a timestamp can't say the archive changed. A
  # digest of the whole archive can (the GPU yard's own code is at its end, so the head alone is not enough).
  SUM=$(sha256sum love.tar.gz | cut -d' ' -f1)
  if [ ! -x /data/love/run.sh ] || [ "$(cat /data/love/.stamp 2>/dev/null)" != "$SUM" ]; then
    echo "unpacking love.tar.gz"
    rm -rf /data/love && mkdir -p /data/love && gzip -dc love.tar.gz | tar -xf - -C /data/love &&
      printf '%s\n' "$SUM" > /data/love/.stamp
    echo "unpacked: $?"
  fi
  df /data
  free
  case "$(basename "$0")" in
    loveyard)
      while :; do
        rm -f "$REQ"
        YARD_LAUNCH_FILE=$REQ YARD_PAK=/data/Games/yard.pak YARD_LOG=/data/Games/love-yard.log YARD_STATS=1 \
          /data/love/run.sh /data/love/yard.love
        echo "love exited $?"
        [ -s "$REQ" ] || break
        WHAT=$(head -n 1 "$REQ")
        NAME=${WHAT#native:}
        case "$NAME" in
          ""|*[!a-z0-9_-]*) echo "bad launch request: $WHAT"; break ;;
        esac
        if [ -x "/data/Games/$NAME" ]; then
          echo "running $NAME"
          "/data/Games/$NAME"
          CODE=$?
          [ $CODE = 0 ] && HOW=ok || HOW=stumbled
        else
          HOW=missing
        fi
        echo "$NAME: $HOW"
        export YARD_RETURNED="$NAME $HOW"
        free
      done
      ;;
    *)
      PROBE_OUT=/data/Games/love-probe.txt /data/love/run.sh /data/love/probe.love
      echo "love exited $?"
      ;;
  esac
} >> "$LOG" 2>&1
sync
