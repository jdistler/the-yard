#!/bin/sh
# /data/tv/bin/tvloop: plays the channel Home's guide chose, and the ones the viewer flips to (games/tv/PLAN.md).
# Home (games/love/home/tv.lua) wrote TV_TMP/play.tsv: "index<TAB>row name<TAB>logo directory" (index 1-based),
# then the row's channels as "playlist<TAB>stream_id<TAB>name<TAB>guide id<TAB>logo key". tvplay draws the name,
# logo and guide around the picture from what is passed here (games/tv/tvview.c). Its exit code says what next:
#   20 / 21  next / previous channel in the row (a channel that will not open is skipped, up to 6 in a row)
#   0        back to the guide          10  back to Home's menu
#   30 31 32 no picture, ended, unsupported: back to the guide, which says so
#   33       stalled while playing: the same channel is tuned again ("RECONNECTING..."), up to 3 times in a row
# The URL is made here from TV_DIR/account.conf (the password never leaves that file and this process).
# Ends by writing TV_TMP/return: "<code> <index>" for Home.
DIR=${TV_DIR:-/data/tv}
TMP=${TV_TMP:-/tmp/tv}
BIN=${TV_BIN:-$DIR/bin}
LIST=$TMP/play.tsv
LOG=$TMP/tvloop.log
[ -s "$LIST" ] || { echo "1 0" > "$TMP/return"; exit 1; }
N=$(($(wc -l < "$LIST") - 1))
IDX=$(head -n 1 "$LIST" | cut -f1)
GROUP=$(head -n 1 "$LIST" | cut -f2)
LOGOS=$(head -n 1 "$LIST" | cut -f3)
HINT=1
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
url_of() {
  # Line IDX+1 of the list: playlist and stream id -> SERVER/live/USER/PASS/ID.ts
  set -- $(sed -n "$(($1 + 1))p" "$LIST" | cut -f1,2)
  awk -F'\t' -v n="$1" -v id="$2" '$1 == n { printf "%s/live/%s/%s/%s.ts", $2, $3, $4, id; exit }' "$DIR/account.conf"
}
SKIPS=0
DIRN=0
RETUNES=0
TUNING=
while :; do
  URL=$(url_of "$IDX")
  LINE=$(sed -n "$((IDX + 1))p" "$LIST")
  PL=$(echo "$LINE" | cut -f1)
  NAME=$(echo "$LINE" | cut -f3)
  EPGID=$(echo "$LINE" | cut -f4)
  KEY=$(echo "$LINE" | cut -f5)
  log "play $IDX/$N $NAME"
  [ -n "$URL" ] || { RC=30; break; }
  T0=$(cut -d. -f1 /proc/uptime)
  LD_LIBRARY_PATH=/data/love/lib SDL_VIDEODRIVER=kmsdrm SDL_KMSDRM_PIPELINE=1 ALSA_CONFIG_PATH=/data/home/alsa.conf \
    TVPLAY_LOG=$TMP/tvplay.log TVPLAY_NAME="$NAME" TVPLAY_SUB="$PL · ${GROUP:+$GROUP · }$IDX of $N" \
    TVPLAY_LOGO="${KEY:+$LOGOS/$KEY.rgba}" TVPLAY_EPG="$TMP/$PL/epg.tsv" TVPLAY_EPGID="$EPGID" \
    TVPLAY_VIEW="$DIR/view" TVPLAY_FONT="$DIR/tvfont.gz" TVPLAY_HINT=$HINT TVPLAY_TUNING="$TUNING" \
    "$BIN/tvplay" "$URL" </dev/null >/dev/null 2>&1
  RC=$?
  HINT=0
  TUNING=
  log "tvplay $RC"
  STEP=1
  # A channel that played a good while before stalling gets its three tries again.
  [ $(($(cut -d. -f1 /proc/uptime) - T0)) -gt 90 ] && RETUNES=0
  case $RC in
    20) DIRN=1; SKIPS=0; RETUNES=0 ;;
    21) DIRN=-1; SKIPS=0; RETUNES=0 ;;
    33)
      if [ $RETUNES -lt 3 ]; then RETUNES=$((RETUNES + 1)); STEP=0; TUNING="RECONNECTING…"; else RC=31; break; fi ;;
    30|31)
      # Flipping channels: a dead one is passed over, as a TV would.
      if [ $DIRN -ne 0 ] && [ $SKIPS -lt 6 ]; then SKIPS=$((SKIPS + 1)); else break; fi ;;
    *) break ;;
  esac
  # The "changing channel" picture (Home painted it) instead of the last channel's "tuning in" one.
  [ -s "$TMP/zap.fb.gz" ] && zcat "$TMP/zap.fb.gz" > /dev/fb0 2>/dev/null
  [ $STEP = 1 ] && IDX=$((IDX + DIRN))
  [ $IDX -gt $N ] && IDX=1
  [ $IDX -lt 1 ] && IDX=$N
done
echo "$RC $IDX" > "$TMP/return"
