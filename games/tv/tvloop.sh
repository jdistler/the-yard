#!/bin/sh
# /data/tv/bin/tvloop: plays the channel Home's guide chose, and the ones the viewer flips to (games/tv/PLAN.md).
# Home (games/love/home/tv.lua) wrote TV_TMP/play.tsv: "index<TAB>row name<TAB>logo directory" (index 1-based),
# then the row's channels as "playlist<TAB>stream_id<TAB>name<TAB>guide id<TAB>logo key".
# Since 2026-11-25 tvplay plays the whole row itself: stick up/down changes channel in the same process (no black
# and no "changing channel" picture between channels; dead channels passed over; a stall tuned again up to 3
# times). It reads the address from TV_DIR/account.conf (the password is never on a command line) and writes
# TV_TMP/return: "<code> <index>" for Home (0 back to the guide, 10 back to Home's menu, 30 31 32 no picture,
# ended, unsupported). This script only starts it, logs, and answers for it if it dies.
DIR=${TV_DIR:-/data/tv}
TMP=${TV_TMP:-/tmp/tv}
BIN=${TV_BIN:-$DIR/bin}
LIST=$TMP/play.tsv
# The logs on the SD card when it is in (they said nothing after a reboot in /tmp, which is RAM: 2026-11-25 the
# blocky picture of the night before could not be looked into), trimmed at 1 MB; else in TMP.
LOGD=$TMP
[ -z "$TV_TMP" ] && [ -d /mnt/sdcard/partycade/logs ] && LOGD=/mnt/sdcard/partycade/logs
LOG=$LOGD/tvloop.log
PLOG=$LOGD/tvplay.log
for f in "$LOG" "$PLOG"; do [ -f "$f" ] && [ "$(wc -c < "$f")" -gt 1048576 ] && mv "$f" "$f.1"; done
[ -s "$LIST" ] || { echo "1 0" > "$TMP/return"; exit 1; }
IDX=$(head -n 1 "$LIST" | cut -f1)
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
log "play from $IDX: $(sed -n "$((IDX + 1))p" "$LIST" | cut -f3) (available $(awk '/MemAvailable/ {print $2}' /proc/meminfo) kB; wifi $(cut -d' ' -f2- /tmp/wifi.link 2>/dev/null))"
rm -f "$TMP/return"
LD_LIBRARY_PATH=/data/love/lib SDL_VIDEODRIVER=kmsdrm SDL_KMSDRM_PIPELINE=1 ALSA_CONFIG_PATH=/data/home/alsa.conf \
  TVPLAY_LOG=$PLOG TVPLAY_LIST="$LIST" TVPLAY_ACCOUNT="$DIR/account.conf" TVPLAY_EPGDIR="$TMP" \
  TVPLAY_VIEW="$DIR/view" TVPLAY_FONT="$DIR/tvfont.gz" TVPLAY_HINT=1 TVPLAY_RETURN="$TMP/return" \
  "$BIN/tvplay" </dev/null >/dev/null 2>&1
RC=$?
log "tvplay $RC: $(cat "$TMP/return" 2>/dev/null) (available $(awk '/MemAvailable/ {print $2}' /proc/meminfo) kB)"
# (died without answering, a crash: back to the guide on the channel it started with, which says so)
[ -s "$TMP/return" ] || echo "30 $IDX" > "$TMP/return"
