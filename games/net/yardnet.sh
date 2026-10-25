#!/bin/sh
# /data/Games/yardnet: a wired network and SSH on the cabinet, with nothing on the flash changed but /data.
#
# The yard supervisor starts it once per boot (the first time The Yard opens); it stays in the background
# until power-off. Every few seconds it:
#   * brings up any network port that appears (a USB-Ethernet adapter on USB-A: the kernel has r8152,
#     asix, ax88179, smsc95xx, cdc_ether, and rndis_host; captures/kernel/drivers.txt) and asks for an
#     address with the stock udhcpc;
#   * puts /data/Games/yardnet.keys (an authorized_keys file) into a RAM-only /root/.ssh, so the dropbear that the stock
#     system already runs lets that key in as root (the stock root password is unknown);
#   * keeps dropbear's host keys in /data/Games/net/hostkeys, so the cabinet's SSH identity survives a reboot.
# It writes what it sees to /data/Games/net.log and the current address to /data/Games/net-status.txt.
# Nothing here is permanent: power off and the cabinet is exactly as before.
# Expected, not yet run on the cabinet (FIELD_TASKS.md round 2).
NET=/data/Games/net
KEYS=/data/Games/yardnet.keys
LOG=/data/Games/net.log
STATUS=/data/Games/net-status.txt
PIDF=/tmp/yardnet.pid

if [ "$1" != "--run" ]; then
  # One copy per boot, detached from The Yard so it outlives it.
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then exit 0; fi
  setsid "$0" --run </dev/null >/dev/null 2>&1 &
  exit 0
fi
echo $$ > "$PIDF"
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 131072 ] && mv "$LOG" "$LOG.1"
log() { echo "$(cut -d' ' -f1 /proc/uptime) $*" >> "$LOG"; }
log "yardnet start (pid $$)"

ssh_keys() {
  [ -s "$KEYS" ] || return
  if ! grep -q " /root tmpfs" /proc/mounts; then
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
    if [ ! -f /tmp/yardnet.hostkeys ]; then
      cp "$NET"/hostkeys/dropbear_*_host_key /var/run/dropbear/ && chmod 600 /var/run/dropbear/*
      /etc/init.d/S50dropbear restart >/dev/null 2>&1
      touch /tmp/yardnet.hostkeys
      log "dropbear restarted with the saved host keys"
    fi
  elif ls /var/run/dropbear/dropbear_*_host_key >/dev/null 2>&1; then
    # dropbear -R made keys at the first connection: keep them for every later boot.
    cp /var/run/dropbear/dropbear_*_host_key "$NET/hostkeys/" && sync
    touch /tmp/yardnet.hostkeys
    log "saved dropbear's host keys"
  fi
}

ports() {
  for d in /sys/class/net/*; do
    i=${d##*/}
    [ "$i" = lo ] && continue
    if [ ! -f "/tmp/udhcpc.$i.pid" ] || ! kill -0 "$(cat "/tmp/udhcpc.$i.pid")" 2>/dev/null; then
      ifconfig "$i" up 2>/dev/null
      udhcpc -i "$i" -b -S -p "/tmp/udhcpc.$i.pid" -s /usr/share/udhcpc/default.script >/dev/null 2>&1
      log "port $i ($(cat "$d/address" 2>/dev/null)): asking for an address"
    fi
  done
}

last=""
while :; do
  ssh_keys
  host_keys
  ports
  now=""
  for d in /sys/class/net/*; do
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
  sleep 5
done
