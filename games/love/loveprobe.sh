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
# The exit code is LÖVE's last one (0: the player left), or 10 when GPU yard's "Classic yard" row asked for the
# C runtime's menu (The Yard's supervisor then shows it). It goes through a file: the block below is a pipe.
CODE_FILE=/tmp/yard-love-code
echo 0 > "$CODE_FILE"
{
  echo "loveprobe start $(date) $(cat /proc/uptime)"
  # The cabinet's clock starts at 1970 on every boot, so a timestamp can't say the archive changed. A
  # digest of the whole archive can (the GPU yard's own code is at its end, so the head alone is not enough).
  # Once unpacked, the archive is deleted (2026-10-26: /userdata was 96% full and it is 4 MB); later updates
  # come over Wi-Fi (cart push writes /data/love directly) or as a new love.tar.gz from a Mask ROM deploy.
  if [ -f love.tar.gz ]; then
    SUM=$(sha256sum love.tar.gz | cut -d' ' -f1)
    if [ ! -x /data/love/run.sh ] || [ "$(cat /data/love/.stamp 2>/dev/null)" != "$SUM" ]; then
      echo "unpacking love.tar.gz"
      rm -rf /data/love && mkdir -p /data/love && gzip -dc love.tar.gz | tar -xf - -C /data/love &&
        printf '%s\n' "$SUM" > /data/love/.stamp
      echo "unpacked: $?"
    fi
    [ -x /data/love/run.sh ] && [ "$(cat /data/love/.stamp 2>/dev/null)" = "$SUM" ] && rm -f love.tar.gz && sync &&
      echo "love.tar.gz removed (unpacked in /data/love)"
  fi
  if [ ! -x /data/love/run.sh ]; then
    echo "no LOVE in /data/love and no love.tar.gz"
    echo 127 > "$CODE_FILE"
  fi
  df /data
  free
  case "$(basename "$0")" in
    loveyard)
      [ -x /data/love/run.sh ] || exit 127
      while :; do
        rm -f "$REQ"
        YARD_LAUNCH_FILE=$REQ YARD_PAK=/data/Games/yard.pak YARD_LOG=/data/Games/love-yard.log YARD_STATS=1 \
          /data/love/run.sh /data/love/yard.love
        LCODE=$?
        echo "love exited $LCODE"
        echo $LCODE > "$CODE_FILE"
        [ -s "$REQ" ] || break
        WHAT=$(head -n 1 "$REQ")
        NAME=${WHAT#native:}
        case "$NAME" in
          ""|*[!a-z0-9_-]*) echo "bad launch request: $WHAT"; break ;;
          classic) echo "the classic yard asked for"; echo 10 > "$CODE_FILE"; break ;;
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
exit "$(cat "$CODE_FILE" 2>/dev/null || echo 0)"
