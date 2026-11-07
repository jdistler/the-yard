#!/bin/sh
# /data/home/homeloop: Partycade Home and what it launches, in a loop (games/love/home/main.lua).
#   homeloop            the front end (at power-on, from stage2); "stock" runs the original menu
#   homeloop preview    from a Yard row, to try Home: "stock" and "yard" come back to The Yard
# Home writes one request and quits, so each game has the whole machine; then Home starts again on its card.
# If Home itself fails twice in a row, the original menu takes over (or, in preview, The Yard).
H=/data/home
REQ=/tmp/home-req
# One supervisor at a time: two (a test tool and a restart racing, 2026-11-06) start two Homes, which don't fit in
# memory together; the kernel killed one, homeloop fell back to the stock menu, and the cabinet thrashed to a halt.
PIDF=/tmp/homeloop.pid
if [ -f "$PIDF" ]; then
  OLD=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null && grep -q homeloop "/proc/$OLD/cmdline" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ > "$PIDF"
# The welcome-back picture: Home renders it once per boot (it is 3 MB, in /tmp, which is RAM); it goes on the
# screen the moment a game ends, until Home's first frame (EXPERIENCE.md).
BACK=/tmp/home-back.fb
back_picture() { [ -s "$BACK" ] && cat "$BACK" > /dev/fb0 2>/dev/null; }
# The log: on the SD card when one is in (/data is ~96% full, and the card is the cheap flash to wear), else
# /data/home; where it is goes into /tmp/home.logpath for the tools. Home trims it itself (HOME_LOG_MAX).
LOG=$H/home.log
LOG_MAX=131072
# (at power-on the card may still be mounting: a few seconds' grace when it is there but not yet mounted)
n=0
while [ -b /dev/mmcblk0p1 ] && ! grep -q " /mnt/sdcard " /proc/mounts && [ $n -lt 8 ]; do sleep 1; n=$((n + 1)); done
if grep -q " /mnt/sdcard " /proc/mounts && mkdir -p /mnt/sdcard/partycade/logs 2>/dev/null &&
   touch /mnt/sdcard/partycade/logs/home.log 2>/dev/null; then
  LOG=/mnt/sdcard/partycade/logs/home.log
  LOG_MAX=4194304
fi
echo "$LOG" > /tmp/home.logpath
mkdir -p "$H"
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt $LOG_MAX ] && mv "$LOG" "$LOG.1"
MODE=${1:-boot}
# Local time for Home's clock and TV guide: /data/tv/tz (a POSIX TZ string) or US Central.
TZ=$(cat /data/tv/tz 2>/dev/null || echo CST6CDT,M3.2.0,M11.1.0)
export TZ
FAILS=0
# At power-on, Home plays its intro once (its state file says "coming back from a game" otherwise).
INTRO=0
[ "$MODE" = boot ] && INTRO=1
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
# Swap on the SD card (made once: dd 128 MB, mkswap; SDCARD.md), only with swap.on beside it: OFF by default
# since 2026-11-02, when running out of memory with it froze the whole cabinet (the card swapping) instead of
# the kernel killing Home, which homeloop restarts. Once a boot, in the background, when the card is mounted.
SWAP=/mnt/sdcard/partycade/swap
if [ ! -e /tmp/home.swap ] && [ -e "$SWAP.on" ]; then
  touch /tmp/home.swap
  (
    n=0
    while ! grep -q " /mnt/sdcard " /proc/mounts && [ $n -lt 60 ]; do sleep 1; n=$((n + 1)); done
    if [ -f "$SWAP" ] && ! grep -q "^$SWAP " /proc/swaps; then
      echo 10 > /proc/sys/vm/swappiness
      if swapon "$SWAP" 2>/dev/null; then log "swap on: $SWAP"; else log "swap: could not turn it on"; fi
    fi
  ) &
fi
stock() {
  log "the original menu"
  rm -f /tmp/.minigui_freeze   # left by a menu killed mid-game, it keeps a new one from drawing
  # Its 15 s intro video, skipped (as The Yard does): /dev/null over it until power-off.
  V=/usr/local/share/minigui/res/images/logo.mp4
  grep -q " $V " /proc/mounts || mount -o bind /dev/null "$V" 2>/dev/null
  if [ "$MODE" != boot ] || [ ! -x $H/holdwatch ]; then
    cd / && exec env -i PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/ XDG_CONFIG_HOME=/userdata/ MG_CFG_PATH=/etc /usr/bin/game
  fi
  # From Home at power-on: the menu runs beside holdwatch --back, and 1-player + 2-player held 3 s on its own
  # screen (not in a game: there that is the stock reset) brings Home back. Its sound goes through dmix too, so
  # the ticks can play over it.
  ( cd / && exec env -i PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/ XDG_CONFIG_HOME=/userdata/ MG_CFG_PATH=/etc \
      ALSA_CONFIG_PATH=$H/alsa.conf /usr/bin/game ) </dev/null >/dev/null 2>&1 &
  MENU=$!
  ALSA_CONFIG_PATH=$H/alsa.conf $H/holdwatch --back $H/sfx </dev/null >/dev/null 2>&1
  log "back to Home from the original menu"
  for s in $(pidof start.sh); do
    for d in /proc/[0-9]*; do [ "$(cut -d' ' -f4 $d/stat 2>/dev/null)" = "$s" ] && kill -9 ${d#/proc/} 2>/dev/null; done
    kill -9 $s 2>/dev/null
  done
  kill -9 $MENU $(pidof game) $(pidof ffplay) 2>/dev/null
  rm -f /tmp/.minigui_freeze
  back_picture
}

# A stock game, as the stock menu's start.sh runs it (index, smoothing 0|1, speed 0|1). Index 10 is Dig Dug II:
# start.sh's tile 10 now opens The Yard, so the emulator is run directly here.
classic() {
  case "$1" in
    0) G="PacMan"; rm -f /data/Games/PacManFast.cfg; cp -f /data/Games/PacMan.cfg /data/Games/PacManFast.cfg ;;
    1) G="SuperPacMan p" ;;
    2) G="SuperPacMan" ;;
    3) G="PacMan p"; rm -f /data/Games/PacManPlusFast.cfg; cp -f /data/Games/PacManPlus.cfg /data/Games/PacManPlusFast.cfg ;;
    4) G="PacLand" ;;
    5) G="NS1" ;;
    6) G="Galaga" ;;
    7) G="Galaxian" ;;
    8) G="Mappy" ;;
    9) G="DigDug" ;;
    10) G="Mappy d" ;;
    11) G="NS1 r" ;;
    *) return 127 ;;
  esac
  F=; [ "$3" = 1 ] && F=-fast
  log "classic $1: $G $F (smoothing $2)"
  # The game's sound through ALSA's dmix (alsa.conf), so holdwatch's ticks can sound over it while 1-player is
  # held for the stock exit (5 s, nothing on the screen). /data/home/no-mix: the stock sound path, no ticks.
  MIX=
  if [ ! -f $H/no-mix ] && [ -f $H/alsa.conf ] && [ -x $H/holdwatch ]; then
    MIX=$H/alsa.conf
    ALSA_CONFIG_PATH=$MIX $H/holdwatch $H/sfx </dev/null >/dev/null 2>&1 &
    WATCH=$!
  fi
  ( cd /data/Games || exit 127
    [ -n "$MIX" ] && export ALSA_CONFIG_PATH=$MIX
    XDG_CONFIG_HOME=/data XDG_RUNTIME_DIR=/data SDL_RENDER_SCALE_QUALITY="$2" ./$G $F )
  RCG=$?
  [ -n "$MIX" ] && kill $WATCH 2>/dev/null
  return $RCG
}
while :; do
  rm -f "$REQ"
  log "home: starting LOVE"
  STARTED=$(cut -d. -f1 /proc/uptime)
  HOME_INTRO=$INTRO HOME_REQ=$REQ HOME_BACK=$BACK HOME_STATE=$H/state HOME_LOG=$LOG HOME_LOG_MAX=$LOG_MAX HOME_ART=$H/art HOME_GAMES=/data/Games HOME_MODE=$MODE \
    /data/love/run.sh $H/home.love
  CODE=$?
  INTRO=0
  if [ ! -s "$REQ" ]; then
    # (a Home that ran a while and then died, killed for memory say, is restarted: only Home failing as it
    # starts, twice running, means it's broken and the original menu should take over. 2026-11-06: two
    # out-of-memory kills, each after 15 minutes of shows, put the cabinet on the stock menu for the night)
    RAN=$(( $(cut -d. -f1 /proc/uptime) - STARTED ))
    if [ $RAN -gt 120 ]; then FAILS=0; fi
    FAILS=$((FAILS + 1))
    log "Home quit without a choice (code $CODE) after ${RAN} s, $FAILS time(s)"
    [ "$MODE" = preview ] && exit 0
    [ $FAILS -ge 2 ] && stock
    continue
  fi
  FAILS=0
  set -- $(head -n 1 "$REQ")
  WHAT=$1
  T0=$(cut -d. -f1 /proc/uptime)
  # The first launch of each game after power-on keeps its "get ready" picture (Home put it in /dev/fb0: how to
  # come back, which the stock games never say) up for 1.5 s; later launches go straight in. Pac-Man covered it
  # with its own black screen after half a second (filmed, 2026-10-27).
  SEEN=/tmp/home-seen
  if ! grep -qx "$WHAT $2" "$SEEN" 2>/dev/null; then
    echo "$WHAT $2" >> "$SEEN"
    case "$WHAT" in classic|cart|native|yard|shelf) sleep 1.5 ;; esac   # (tv: its "tuning in" stays up while it connects)
  fi
  case "$WHAT" in
    classic) classic "$2" "$3" "$4" ;;
    cart)
      case "$2" in ""|*[!a-z0-9_-]*) log "bad cart: $2"; continue ;; esac
      log "cart $2"
      ( cd /data/Games && YARD_PAK=/data/Games/yard.pak YARD_LOG=/data/Games/love-yard.log \
          /data/love/run.sh /data/love/yard.love "$2" ) ;;
    native)
      case "$2" in ""|*[!a-z0-9_-]*) log "bad native: $2"; continue ;; esac
      log "native $2"
      ( cd /data/Games && "./$2" ) ;;
    shelf)
      # The Shelf (games/native/play, games/love/home/shelf.lua): "shelf <system> <file>", the file in the
      # card's library/<system>/. Home wrote /tmp/shelf.ret to come back on that game; a quick failure is
      # added to it, so the browser can say so.
      SLIB=/mnt/sdcard/library
      SFILE=$(head -n 1 "$REQ" | cut -d' ' -f3-)
      case "$2" in ""|*[!a-z0-9]*) log "bad shelf system: $2"; continue ;; esac
      case "$SFILE" in ""|*/*|.*) log "bad shelf file: $SFILE"; continue ;; esac
      if [ ! -x $SLIB/bin/play ] || [ ! -f "$SLIB/$2/$SFILE" ]; then
        log "shelf: missing $2/$SFILE"
        [ -f /tmp/shelf.ret ] && printf '%s\tfailed\n' "$(head -n 1 /tmp/shelf.ret)" > /tmp/shelf.ret
        continue
      fi
      log "shelf $2 $SFILE"
      ( cd $SLIB && PLAY_LIB=$SLIB PLAY_LOG=/tmp/play.log ALSA_CONFIG_PATH=$H/alsa.conf \
          bin/play "$2" "$SLIB/$2/$SFILE" )
      SRC=$?
      if [ $SRC -ne 0 ] && [ $(( $(cut -d. -f1 /proc/uptime) - T0 )) -lt 5 ] && [ -f /tmp/shelf.ret ]; then
        printf '%s\tfailed\n' "$(head -n 1 /tmp/shelf.ret)" > /tmp/shelf.ret
      fi
      (exit $SRC) ;;
    tv)
      # Live TV (games/tv): the channel the guide chose, and the ones flipped to; Home comes back on it.
      log "tv"
      /data/tv/bin/tvloop ;;
    yard)
      [ "$MODE" = preview ] && exit 0
      # The whole Yard, as Dig Dug II opens it (GPU yard first, its "Classic yard" row, Orb), but with no stock
      # menu to stop or start again (YARD_STOCK_MENU not a path: games/engine/runtime.c stock_menu).
      log "The Yard"
      ( cd /data/Games && YARD_STOCK_MENU=none ./yard ) ;;
    stock)
      [ "$MODE" = preview ] && exit 0
      stock
      continue ;;
    *) log "bad request: $WHAT" ;;
  esac
  RC=$?
  back_picture
  T1=$(cut -d. -f1 /proc/uptime)
  # How long it was played, for Home's FAVORITES (favs.lua credits it to what Home launched, then drops it).
  case "$WHAT" in classic|cart|native|yard|shelf) printf 'ran %s\n' $((T1 - T0)) >> $H/state ;; esac
  log "$WHAT returned $RC after $((T1 - T0)) s"
  # Home shows a note when a game did not start: an error within 5 s (a game's own exit code on a normal
  # quit is not trusted).
  if [ $RC -ne 0 ] && [ $((T1 - T0)) -lt 5 ] && [ "$WHAT" != tv ]; then printf 'returned %s failed\n' "$WHAT" >> $H/state; fi
done
