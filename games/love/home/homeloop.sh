#!/bin/sh
# /data/home/homeloop: Partycade Home and what it launches, in a loop (games/love/home/main.lua).
#   homeloop            the front end (at power-on, from stage2); "stock" runs the original menu
#   homeloop preview    from a Yard row, to try Home: "stock" and "yard" come back to The Yard
# Home writes one request and quits, so each game has the whole machine; then Home starts again on its card.
# If Home itself fails twice in a row, the original menu takes over (or, in preview, The Yard).
H=/data/home
REQ=/tmp/home-req
# The welcome-back picture: Home renders it once per boot (it is 3 MB, in /tmp, which is RAM); it goes on the
# screen the moment a game ends, until Home's first frame (EXPERIENCE.md).
BACK=/tmp/home-back.fb
back_picture() { [ -s "$BACK" ] && cat "$BACK" > /dev/fb0 2>/dev/null; }
LOG=$H/home.log
mkdir -p "$H"
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 131072 ] && mv "$LOG" "$LOG.1"
MODE=${1:-boot}
FAILS=0
# At power-on, Home plays its intro once (its state file says "coming back from a game" otherwise).
INTRO=0
[ "$MODE" = boot ] && INTRO=1
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
stock() {
  log "the original menu"
  rm -f /tmp/.minigui_freeze   # left by a menu killed mid-game, it keeps a new one from drawing
  # Its 15 s intro video, skipped (as The Yard does): /dev/null over it until power-off.
  V=/usr/local/share/minigui/res/images/logo.mp4
  grep -q " $V " /proc/mounts || mount -o bind /dev/null "$V" 2>/dev/null
  cd / && exec env -i PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/ XDG_CONFIG_HOME=/userdata/ MG_CFG_PATH=/etc /usr/bin/game
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
  HOME_INTRO=$INTRO HOME_REQ=$REQ HOME_BACK=$BACK HOME_STATE=$H/state HOME_LOG=$LOG HOME_ART=$H/art HOME_GAMES=/data/Games HOME_MODE=$MODE \
    /data/love/run.sh $H/home.love
  CODE=$?
  INTRO=0
  if [ ! -s "$REQ" ]; then
    FAILS=$((FAILS + 1))
    log "Home quit without a choice (code $CODE), $FAILS time(s)"
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
    case "$WHAT" in classic|cart|native|yard) sleep 1.5 ;; esac
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
    yard)
      [ "$MODE" = preview ] && exit 0
      # The whole Yard, as Dig Dug II opens it (GPU yard first, its "Classic yard" row, Orb), but with no stock
      # menu to stop or start again (YARD_STOCK_MENU not a path: games/engine/runtime.c stock_menu).
      log "The Yard"
      ( cd /data/Games && YARD_STOCK_MENU=none ./yard ) ;;
    stock)
      [ "$MODE" = preview ] && exit 0
      stock ;;
    *) log "bad request: $WHAT" ;;
  esac
  RC=$?
  back_picture
  T1=$(cut -d. -f1 /proc/uptime)
  log "$WHAT returned $RC after $((T1 - T0)) s"
  # Home shows a note when a game did not start: an error within 5 s (a game's own exit code on a normal
  # quit is not trusted).
  if [ $RC -ne 0 ] && [ $((T1 - T0)) -lt 5 ]; then printf 'returned %s failed\n' "$WHAT" >> $H/state; fi
done
