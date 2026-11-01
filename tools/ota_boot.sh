#!/bin/sh
# tools/ota_boot.sh: write the cabinet's boot partition over Wi-Fi (games/boot/README.md). Never the system
# image (it is in use); the boot partition is idle once the kernel runs.
#   tools/ota_boot.sh write NEW.img EXPECTED_NOW_SHA256 [STAGE2]   write NEW.img to /dev/rkflash0p3, verify, reboot
#   NOREBOOT=1 tools/ota_boot.sh write ...                      the same, but leave the reboot to a power-cycle
#   tools/ota_boot.sh restore                                      put the stock boot image back (sha a0ce5967...)
# Refuses unless the partition holds EXPECTED_NOW_SHA256 right now, The Yard is not running, and the copy in
# the cabinet's RAM checks out. After writing: drop caches, read the partition back, compare, then reboot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
STOCK=$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/boot.img
STOCK_SHA=a0ce5967ba5dba1b0316c83e806d814c8e12f169d5470cf72ffe8165db3fba90
H=$("$HERE/cab.sh" host)
O="-i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
case "$1" in
  write) IMG=$2; WANT_NOW=$3; STAGE2=$4 ;;
  restore) IMG=$STOCK; WANT_NOW=any; STAGE2= ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
NEW=$(sha256sum "$IMG" | cut -d' ' -f1)
[ "$(stat -c %s "$IMG")" = 4718592 ] || { echo "$IMG is not 4718592 bytes"; exit 1; }
# U-Boot refuses an image whose header ID or rk-kernel.dtb hash is stale, and the cabinet then stops at U-Boot's
# prompt with a dark screen (2026-10-27). Check the image as U-Boot will before anything is copied.
python3 "$HERE/bootimg.py" verify "$IMG" || { echo "$IMG fails U-Boot's checks: not written"; exit 1; }
NOW=$(ssh $O root@$H 'pidof yard love.bin >/dev/null && echo BUSY; sha256sum /dev/rkflash0p3 | cut -d" " -f1')
case "$NOW" in *BUSY*) echo "The Yard is running on the cabinet: not now"; exit 1 ;; esac
echo "boot partition now: $NOW"
[ "$NOW" = "$NEW" ] && { echo "already that image"; exit 0; }
[ "$WANT_NOW" = any ] || [ "$NOW" = "$WANT_NOW" ] || { echo "expected $WANT_NOW there: refusing"; exit 1; }
scp -O -q $O "$IMG" root@$H:/tmp/boot-new.img
if [ -n "$STAGE2" ]; then
  ssh $O root@$H 'mkdir -p /userdata/boot'
  scp -O -q $O "$STAGE2" root@$H:/userdata/boot/stage2.sh.new
  ssh $O root@$H 'chmod 755 /userdata/boot/stage2.sh.new && mv -f /userdata/boot/stage2.sh.new /userdata/boot/stage2.sh && echo 0 > /userdata/boot/tries && sync'
fi
ssh $O root@$H "set -e
  [ \"\$(sha256sum /tmp/boot-new.img | cut -d' ' -f1)\" = $NEW ] || { echo 'copy in RAM does not match'; exit 1; }
  dd if=/tmp/boot-new.img of=/dev/rkflash0p3 bs=65536 conv=fsync 2>/dev/null
  sync; echo 3 > /proc/sys/vm/drop_caches
  GOT=\$(sha256sum /dev/rkflash0p3 | cut -d' ' -f1)
  echo \"boot partition after the write: \$GOT\"
  [ \"\$GOT\" = $NEW ] || { echo 'READ-BACK MISMATCH: not rebooting'; exit 1; }
  rm -f /tmp/boot-new.img"
if [ -n "$NOREBOOT" ]; then
  echo "written and verified ($NEW). Not rebooting (NOREBOOT): switch the cabinet off and on when ready."
  exit 0
fi
echo "written and verified ($NEW). Rebooting the cabinet."
ssh $O root@$H 'sync; (sleep 1; reboot) >/dev/null 2>&1 &' || true
