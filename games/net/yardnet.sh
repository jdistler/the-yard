#!/bin/sh
# /data/Games/yardnet: a network and SSH on the cabinet, with nothing on the flash changed but /data.
#
# The yard supervisor starts it once per boot (the first time The Yard opens); it stays in the background
# until power-off. Every few seconds it:
#   * brings up any network port that appears and asks for an address with the stock udhcpc. A port is a
#     USB-Ethernet adapter on USB-A (the kernel has r8152, asix, ax88179, smsc95xx, cdc_ether, rndis_host;
#     captures/kernel/drivers.txt) or the TP-Link AC600 Wi-Fi adapter once wifi() has loaded its driver;
#   * Wi-Fi (wifi()): the stock kernel has no Wi-Fi, so /data/Games/wifi.tar.gz carries cfg80211.ko, the
#     RTL8821AU driver 8821au.ko and a static wpa_supplicant, all built for this exact kernel
#     (games/net/wifi/build.sh). They load only when the AC600 is plugged in and /data/Games/net/wifi.conf
#     (a wpa_supplicant config: the home network's name and key) exists. A guard file catches a load that
#     froze or rebooted the cabinet; after two of those it stops trying until a new wifi.tar.gz or a stick;
#   * a USB stick (stick()): a FAT stick with a folder yard/ is read once per insertion. yard/wifi.conf
#     becomes /data/Games/net/wifi.conf; yard/put.tar is unpacked into /data/Games (an update with no
#     Mask ROM); yard/run.sh runs (output in yard/run.log); then the logs are copied to yard/logs/ and the
#     stick is unmounted, with yard/done.txt written last. Only one USB-A port: swap stick and adapter;
#   * puts /data/Games/yardnet.keys (an authorized_keys file) into a RAM-only /root/.ssh, so the dropbear that the stock
#     system already runs lets that key in as root (the stock root password is unknown);
#   * keeps dropbear's host keys in /data/Games/net/hostkeys, so the cabinet's SSH identity survives a reboot.
# It writes what it sees to /data/Games/net.log and the current address to /data/Games/net-status.txt.
# Nothing here is permanent: power off and the cabinet is as before, apart from files under /data/Games.
# Expected, not yet run on the cabinet (FIELD_TASKS.md round 2).
# The paths can be moved for games/test.py, which runs this against a fake cabinet with --once.
G=${YARDNET_GAMES:-/data/Games}
SYS=${YARDNET_SYS:-/sys}
PROC=${YARDNET_PROC:-/proc}
T=${YARDNET_TMP:-/tmp}
NET=$G/net
KEYS=$G/yardnet.keys
LOG=$G/net.log
STATUS=$G/net-status.txt
PIDF=$T/yardnet.pid
WTGZ=$G/wifi.tar.gz
# Unpacked into RAM each boot: /data has about 1 MB free (round 2, 2026-10-26) and the bundle is 4 MB.
WDIR=$T/yardwifi
WCONF=$NET/wifi.conf

if [ "$1" != "--run" ] && [ "$1" != "--once" ]; then
  # One copy per boot, detached from The Yard so it outlives it.
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then exit 0; fi
  setsid "$0" --run </dev/null >/dev/null 2>&1 &
  exit 0
fi
echo $$ > "$PIDF"
mkdir -p "$NET"
# cart deploy --wifi-conf puts it beside the games (the deploy tool cannot make folders); keep it in net/.
[ -f "$G/wifi.conf" ] && mv -f "$G/wifi.conf" "$WCONF" && chmod 600 "$WCONF"
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 131072 ] && mv "$LOG" "$LOG.1"
log() { echo "$(cut -d' ' -f1 $PROC/uptime) $*" >> "$LOG"; }
log "yardnet start (pid $$)"

ssh_keys() {
  [ -s "$KEYS" ] || return
  if ! grep -q " /root tmpfs" $PROC/mounts; then
    mount -t tmpfs -o mode=0700,size=64k tmpfs /root && log "/root is now a RAM folder" || { log "could not mount /root"; return; }
  fi
  if ! cmp -s "$KEYS" /root/.ssh/authorized_keys 2>/dev/null; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    cp "$KEYS" /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
    log "authorized_keys installed ($(wc -l < /root/.ssh/authorized_keys) keys)"
  fi
}

host_keys() {
  mkdir -p "$NET/hostkeys" /var/run/dropbear
  if ls "$NET"/hostkeys/dropbear_*_host_key >/dev/null 2>&1; then
    # Ours go in once per boot, before anyone connects; dropbear is restarted to read them.
    if [ ! -f $T/yardnet.hostkeys ]; then
      cp "$NET"/hostkeys/dropbear_*_host_key /var/run/dropbear/ && chmod 600 /var/run/dropbear/*
      /etc/init.d/S50dropbear restart >/dev/null 2>&1
      touch $T/yardnet.hostkeys
      log "dropbear restarted with the saved host keys"
    fi
  elif ls /var/run/dropbear/dropbear_*_host_key >/dev/null 2>&1; then
    # dropbear -R made keys at the first connection: keep them for every later boot.
    cp /var/run/dropbear/dropbear_*_host_key "$NET/hostkeys/" && sync
    touch $T/yardnet.hostkeys
    log "saved dropbear's host keys"
  fi
}

ports() {
  for d in $SYS/class/net/*; do
    i=${d##*/}
    [ "$i" = lo ] && continue
    if [ ! -f "$T/udhcpc.$i.pid" ] || ! kill -0 "$(cat "$T/udhcpc.$i.pid")" 2>/dev/null; then
      ifconfig "$i" up 2>/dev/null
      # -x hostname: the router lists the cabinet as "partycade" (DHCP option 12).
      udhcpc -i "$i" -b -S -x hostname:partycade -p "$T/udhcpc.$i.pid" -s /usr/share/udhcpc/default.script >/dev/null 2>&1
      log "port $i ($(cat "$d/address" 2>/dev/null)): asking for an address"
    fi
  done
}

# --- Wi-Fi ---------------------------------------------------------------------------------------------

ac600() {
  # The TP-Link AC600 family (2357:011e/011f/0120), or any other id the driver lists in usb-ids.txt.
  for u in $SYS/bus/usb/devices/*; do
    [ -f "$u/idVendor" ] || continue
    id="$(cat "$u/idVendor"):$(cat "$u/idProduct")"
    if [ -f "$WDIR/usb-ids.txt" ]; then grep -qi "^$id\$" "$WDIR/usb-ids.txt" && return 0
    else case "$id" in 2357:011[ef]|2357:0120) return 0 ;; esac; fi
  done
  return 1
}

wifi_unpack() {
  [ -f "$WTGZ" ] || return 1
  [ -f "$WDIR/.sha256" ] && return 0
  h=$(sha256sum "$WTGZ" | cut -d' ' -f1)
  # A different bundle from the last one tried: forget its failed starts.
  if [ "$(cat "$NET/wifi.sha256" 2>/dev/null)" != "$h" ]; then
    rm -f "$NET/wifi.crashes" "$NET/wifi.trying"; echo "$h" > "$NET/wifi.sha256"; sync
  fi
  rm -rf "$WDIR" && mkdir -p "$WDIR" || return 1
  # The stock busybox tar has no -z (round 2, 2026-10-26).
  if out=$(gzip -dc "$WTGZ" 2>&1 | tar -xf - -C "$WDIR" 2>&1) && [ -f "$WDIR/8821au.ko" ]; then
    chmod 755 "$WDIR/wpa_supplicant"; chmod 755 "$WDIR/wpa_cli" 2>/dev/null; echo "$h" > "$WDIR/.sha256"
    log "wifi: unpacked $WTGZ ($h) into $WDIR"
    return 0
  fi
  log "wifi: could not unpack $WTGZ: $out"
  rm -rf "$WDIR"; touch $T/yardnet.wifi.done   # once per boot, not every 5 s
  return 1
}

wlan() {
  for d in $SYS/class/net/*; do [ -d "$d/phy80211" ] || [ -d "$d/wireless" ] && { echo "${d##*/}"; return; }; done
}

wifi() {
  [ -f $T/yardnet.wifi.done ] && { wifi_watch; return; }
  ac600 || return
  wifi_unpack || return
  [ -s "$WCONF" ] || { [ -f $T/yardnet.wifi.noconf ] || log "wifi: adapter seen, but no $WCONF (put yard/wifi.conf on a stick)"; touch $T/yardnet.wifi.noconf; return; }
  n=$(cat "$NET/wifi.crashes" 2>/dev/null); n=${n:-0}
  if [ -f "$NET/wifi.trying" ]; then
    # Set before the last load and not cleared: that boot froze or reset during the load or the join.
    n=$((n + 1)); echo "$n" > "$NET/wifi.crashes"; rm -f "$NET/wifi.trying"; sync
    log "wifi: the last start did not finish (the cabinet froze or reset?): $n time(s)"
  fi
  if [ "$n" -ge 2 ]; then
    log "wifi: not trying again (two failed starts); a new wifi.tar.gz or a stick resets this"
    touch $T/yardnet.wifi.done; return
  fi
  touch "$NET/wifi.trying"; sync
  echo 0 > $PROC/sys/kernel/panic_on_oops 2>/dev/null
  log "wifi: loading the driver"
  for m in cfg80211 8821au; do
    if ! grep -q "^$m " $PROC/modules; then
      out=$(insmod "$WDIR/$m.ko" 2>&1) || { log "wifi: insmod $m failed: $out"; dmesg | tail -40 > "$NET/wifi-dmesg.txt"; rm -f "$NET/wifi.trying"; sync; touch $T/yardnet.wifi.done; return; }
      log "wifi: $m loaded"
    fi
    rm -f "$WDIR/$m.ko"   # in the kernel now; give the RAM back
  done
  t=0; w=""
  while [ $t -lt 15 ] && [ -z "$w" ]; do sleep 1; t=$((t + 1)); w=$(wlan); done
  dmesg | tail -80 > "$T/wifi-dmesg.txt"
  [ -n "$w" ] || dmesg | tail -80 > "$NET/wifi-dmesg.txt"
  [ -n "$w" ] || { log "wifi: no Wi-Fi interface appeared (see net/wifi-dmesg.txt)"; touch $T/yardnet.wifi.done; return; }
  ifconfig "$w" up
  mkdir -p /var/run/wpa_supplicant
  # (its log in RAM: it writes all the time, and on /data it was one of the two files a power cut left sharing a
  # block, found and repaired 2026-11-24, SYSTEM_AUDIT.md F2)
  # Roaming: with no background scan, wpa_supplicant keeps the first access point that let it in. 2026-11-25 the
  # cabinet sat 15 h on the outdoor AP at -76 dBm (5.5 Mbps, 70 % of pings lost: TV came in blocks) while the
  # office AP was at -54. bgscan scans every 30 s below -65 dBm (every 300 s above) and moves to a better one.
  # It runs from a copy in RAM with the line added (wifi.conf is the user's file); if that will not start, as is.
  RCONF=$T/wpa.run.conf
  # 2.4 GHz only (freq_list): the driver gives bgscan no signal monitoring, so it scans on a timer and wpa_supplicant
  # rates any 5 GHz AP above the office's 2.4 GHz one; from the cabinet's corner they fail or barely work (office
  # 5 GHz: authentication times out; outdoor: -74 dBm), and it hopped band five times an hour, a disconnect each,
  # one in the middle of a football game on TV (2026-11-25). Every AP has a 2.4 GHz radio; the office's gives
  # 26 Mbit/s here (a channel needs 4-8).
  if ! grep -q bgscan "$WCONF" && sed 's/^network={$/network={\n\tbgscan="simple:30:-65:300"\n\tfreq_list=2412 2417 2422 2427 2432 2437 2442 2447 2452 2457 2462/' "$WCONF" > "$RCONF" &&
      chmod 600 "$RCONF" && grep -q bgscan "$RCONF"; then :; else RCONF=$WCONF; fi
  "$WDIR/wpa_supplicant" -B -i "$w" -D nl80211 -c "$RCONF" -P $T/wpa_supplicant.pid -f "$T/wpa.log" -t
  rc=$?
  if [ $rc -ne 0 ] && [ "$RCONF" != "$WCONF" ]; then
    log "wifi: wpa_supplicant would not start with bgscan (rc $rc): without it"
    "$WDIR/wpa_supplicant" -B -i "$w" -D nl80211 -c "$WCONF" -P $T/wpa_supplicant.pid -f "$T/wpa.log" -t
    rc=$?
  fi
  log "wifi: $w up, wpa_supplicant started (rc $rc)"
  echo "$(cut -d' ' -f1 $PROC/uptime)" > $T/yardnet.wifi.since
  touch $T/yardnet.wifi.done
}

wifi_watch() {
  # The link, once a minute, in RAM (for tvloop's log and for looking): the access point, band, signal, speed.
  # A move between access points goes in net.log.
  if [ -x "$WDIR/wpa_cli" ]; then
    lt=$(cut -d. -f1 $PROC/uptime)
    if [ $((lt - ${WLINK_T:-0})) -ge 60 ]; then
      WLINK_T=$lt
      st=$("$WDIR/wpa_cli" -i "$(wlan)" status 2>/dev/null); sp=$("$WDIR/wpa_cli" -i "$(wlan)" signal_poll 2>/dev/null)
      b=$(echo "$st" | sed -n 's/^bssid=//p')
      echo "$lt bssid=$b $(echo "$sp" | grep -E '^(RSSI|LINKSPEED|FREQUENCY)=' | tr '\n' ' ')" > $T/wifi.link
      [ -n "$b" ] && [ -n "$WLINK_B" ] && [ "$b" != "$WLINK_B" ] && log "wifi: moved to $(cat $T/wifi.link)"
      [ -n "$b" ] && WLINK_B=$b
    fi
  fi
  # The guard file stays until Wi-Fi has an address, or 90 s have passed without the cabinet freezing.
  [ -f "$NET/wifi.trying" ] || return
  w=$(wlan); s=$(cut -d. -f1 $T/yardnet.wifi.since 2>/dev/null); now=$(cut -d. -f1 $PROC/uptime)
  if { [ -n "$w" ] && ip -4 addr show dev "$w" 2>/dev/null | grep -q "inet "; } || [ $((now - ${s:-0})) -gt 90 ]; then
    rm -f "$NET/wifi.trying" "$NET/wifi.crashes"; dmesg | tail -80 > "$T/wifi-dmesg.txt"; sync
    log "wifi: start finished cleanly"
  fi
}

# --- USB stick -----------------------------------------------------------------------------------------

stick() {
  dev=""
  for b in $SYS/block/sd?; do [ -e "$b" ] && { dev=${b##*/}; break; }; done
  if [ -z "$dev" ]; then rm -f $T/yardnet.stick; return; fi
  [ -f $T/yardnet.stick ] && return
  touch $T/yardnet.stick
  sleep 2
  part=/dev/${dev}1; [ -b "$part" ] || part=/dev/$dev
  M=$T/stick; mkdir -p "$M"
  mount -t vfat -o rw,noatime "$part" "$M" 2>/dev/null || mount "$part" "$M" 2>/dev/null || { log "stick: could not mount $part"; return; }
  S=$M/yard
  if [ -d "$S" ]; then
    log "stick: $part has yard/"
    if [ -s "$S/wifi.conf" ]; then
      cp "$S/wifi.conf" "$WCONF.new" && chmod 600 "$WCONF.new" && mv -f "$WCONF.new" "$WCONF" && log "stick: wifi.conf installed"
      rm -f $T/yardnet.wifi.noconf
    fi
    rm -f "$NET/wifi.crashes" "$NET/wifi.trying"
    [ -f $T/yardnet.wifi.done ] && ! grep -q "^8821au " $PROC/modules && rm -f $T/yardnet.wifi.done
    if [ -f "$S/put.tar" ]; then
      out=$(tar -xvf "$S/put.tar" -C $G 2>&1); log "stick: put.tar (rc $?): $(echo $out)"
    fi
    if [ -f "$S/run.sh" ]; then
      sh "$S/run.sh" > "$S/run.log" 2>&1; log "stick: run.sh (rc $?)"
    fi
    sync
    mkdir -p "$S/logs"
    cp $G/*.log $G/*.txt "$S/logs/" 2>/dev/null
    for f in "$NET"/*.txt "$NET"/*.log; do [ -f "$f" ] && cp "$f" "$S/logs/net-${f##*/}"; done
    dmesg > "$S/logs/dmesg.txt"
    { uptime; free; cat $PROC/modules; lsusb; ifconfig -a; ip addr; ls -la $G $G/net; df; } > "$S/logs/state.txt" 2>&1
    date > "$S/done.txt"; cat $PROC/uptime >> "$S/done.txt"
  fi
  sync
  umount "$M" && log "stick: done, safe to pull" || log "stick: could not unmount"
}

last=""
while :; do
  stick
  wifi
  ssh_keys
  host_keys
  ports
  now=""
  for d in $SYS/class/net/*; do
    i=${d##*/}
    [ "$i" = lo ] && continue
    a=$(ip -4 addr show dev "$i" 2>/dev/null | awk '/inet /{print $2; exit}')
    [ -n "$a" ] && now="$now$i $a "
  done
  if [ "$now" != "$last" ]; then
    log "addresses: ${now:-none}"
    printf '%s\n' "${now:-none}" > "$STATUS"
    sync
    last=$now
  fi
  [ "$1" = "--once" ] && exit 0
  sleep 5
done
