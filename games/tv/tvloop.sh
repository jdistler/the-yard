#!/bin/sh
# /data/tv/bin/tvloop: plays the channel Home's guide chose, and the ones the viewer flips to (games/tv/PLAN.md).
# Home (games/love/home/tv.lua) wrote TV_TMP/play.tsv: the chosen index (1-based), then the row's channels as
# "playlist<TAB>stream_id<TAB>name". tvplay's exit code says what next:
#   20 / 21  next / previous channel in the row (a channel that will not open is skipped, up to 6 in a row)
#   0        back to the guide          10  back to Home's menu
#   30 31 32 no picture, ended, unsupported: back to the guide, which says so
# The URL is made here from TV_DIR/account.conf (the password never leaves that file and this process).
# Ends by writing TV_TMP/return: "<code> <index>" for Home.
DIR=${TV_DIR:-/data/tv}
TMP=${TV_TMP:-/tmp/tv}
BIN=${TV_BIN:-$DIR/bin}
LIST=$TMP/play.tsv
LOG=$TMP/tvloop.log
[ -s "$LIST" ] || { echo "1 0" > "$TMP/return"; exit 1; }
N=$(($(wc -l < "$LIST") - 1))
IDX=$(head -n 1 "$LIST")
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
url_of() {
  # Line IDX+1 of the list: playlist and stream id -> SERVER/live/USER/PASS/ID.ts
  set -- $(sed -n "$(($1 + 1))p" "$LIST" | cut -f1,2)
  awk -F'\t' -v n="$1" -v id="$2" '$1 == n { printf "%s/live/%s/%s/%s.ts", $2, $3, $4, id; exit }' "$DIR/account.conf"
}
SKIPS=0
DIRN=0
while :; do
  URL=$(url_of "$IDX")
  NAME=$(sed -n "$((IDX + 1))p" "$LIST" | cut -f3)
  log "play $IDX/$N $NAME"
  [ -n "$URL" ] || { RC=30; break; }
  LD_LIBRARY_PATH=/data/love/lib SDL_VIDEODRIVER=kmsdrm SDL_KMSDRM_PIPELINE=1 ALSA_CONFIG_PATH=/data/home/alsa.conf \
    TVPLAY_LOG=$TMP/tvplay.log "$BIN/tvplay" "$URL" </dev/null >/dev/null 2>&1
  RC=$?
  log "tvplay $RC"
  case $RC in
    20) DIRN=1; SKIPS=0 ;;
    21) DIRN=-1; SKIPS=0 ;;
    30|31)
      # Flipping channels: a dead one is passed over, as a TV would.
      if [ $DIRN -ne 0 ] && [ $SKIPS -lt 6 ]; then SKIPS=$((SKIPS + 1)); else break; fi ;;
    *) break ;;
  esac
  # The "changing channel" picture (Home painted it) instead of the last channel's "tuning in" one.
  [ -s "$TMP/zap.fb.gz" ] && zcat "$TMP/zap.fb.gz" > /dev/fb0 2>/dev/null
  IDX=$((IDX + DIRN))
  [ $IDX -gt $N ] && IDX=1
  [ $IDX -lt 1 ] && IDX=$N
done
echo "$RC $IDX" > "$TMP/return"
