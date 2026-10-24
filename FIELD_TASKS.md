# Field tasks: work that needs the cabinet PC

Written 2026-10-24 by a cloud session that has no cabinet, no `~/partycade-dumps/`, and no rootfs. These tasks are for the agent on the PC the cabinet plugs into. Do them in order. Each one says what to run, what to look for, and what to write down. When a task is done, commit its results (never dumps or binaries) and tell the user to push, so the next cloud session can read them.

## What these tasks must settle

The goal: games stored on a microSD card, and later a USB Wi-Fi adapter on the USB-A port for remote access and for changing the system from Linux itself, without the Micro-USB cable and Mask ROM. Each question below is answered by the task named, and the result goes in **Results**.

| Question | Answered by |
| :--- | :--- |
| Which Wi-Fi, USB, network, gadget, and flash drivers are built into the kernel? Can it load modules at all? Is there a kernel config to rebuild from? | 1 (from the dump), 5 (live: `/proc/config.gz`, `/proc/modules`) |
| How does the boot image hold the kernel and the device tree (to put a rebuilt kernel or tree back)? | 1 (`captures/kernel/bootimg.txt`) |
| How do the stock scripts bring up USB, ADB, udev mounts, the network, and dropbear? Does root have a password? | 1 (`captures/system/`) |
| Which device tree is live? Are the SD slot and USB-A really off now? | 5 (System probe), 6 |
| How does Linux see the flash: device names, partitions, read-only or not? Does what Linux reads match our partition images byte for byte? That is what decides whether a later update can be a plain write from Linux instead of a Mask ROM patch | 5, 6 (checksums) |
| Does the PC see anything on the Micro-USB port while the cabinet runs normally? | 5 |
| After the SD and USB-A nodes are turned on: does the machine still boot, does a card show up (polling, no detect pin), at what speed, with which filesystems and mount options? | 7 |
| Is USB-A wired and powered? What does a stick, then a Wi-Fi adapter, show up as (vendor and product IDs, driver bound or not, firmware requests)? | 7 |
| Does ADB give a root shell over Micro-USB with the switch ON? | 7 |

From those answers the next cloud session decides the Wi-Fi route: a driver already in the kernel plus firmware and `wpa_supplicant` on the card (no flash write beyond `data`), or a rebuilt kernel (one more `boot` write).

**What the tests leave behind.** Nothing on the cabinet needs a person to read a screen or copy numbers. Every test writes a file in `/data/Games`, the agent reads it out of a fresh dump (task 6) or pulls it over ADB (task 7), commits the text under `captures/`, and the next cloud session analyses it, the same way the controls probe's `probe.log` gave the button map.

| File on the cabinet | Written by | When | What it holds |
| :--- | :--- | :--- | :--- |
| `yard.log` (and `yard.log.1`, the older half, past 256 KB) | The cart runtime, every time it runs | Automatically, from the moment Dig Dug II opens The Yard | Each start's facts (screen mode, renderer, joystick name with its button, axis, and hat counts, audio, free memory), each game opened, frame times every 5 seconds, and every game's own log lines |
| `love-probe.txt`, `love-probe.log` | The LOVE probe row | When opened | GPU limits and formats, frame times, Lua speed, sound, every button the deck sent during "press every button" |
| `love-yard.log` | The GPU yard row | When opened | Each game opened, frame times, and the games' log lines, from the GPU runtime |
| `sysprobe-1.txt`, `-2.txt`, ... | The System probe row | When opened (each run adds a file) | Drivers, flash devices and checksums, USB and card devices, power, tools, and what appeared while things were plugged in |

**Things the user needs on hand by task 7:** a microSD card of 32 GB or less (SDHC), a USB stick, any USB Wi-Fi adapter they own (its chip gets identified; it need not work yet), and `adb` on the PC (`sudo apt install adb`, or the platform-tools zip).

Read [AGENTS.md](AGENTS.md), [STATUS.md](STATUS.md), [RUNBOOK.md](RUNBOOK.md), and [RECOVERY.md](RECOVERY.md) first. Every rule there still holds. The ones that matter most here:

* Tasks 1 to 3 never touch the cabinet. Do them with the cabinet unplugged.
* Task 4 reads the cabinet, then **stops and asks the user** to approve a written block list. Nothing is written without that approval, in writing, for that exact list.
* One download attempt per Mask ROM enumeration. On any USB error or timeout: stop, write it down, ask the user for a cold plug (both plugs out, switch OFF, then Micro-USB). Never retry, never reset.
* Dumps, `boot.img`, and the LÖVE bundle stay out of git. They go under `~/partycade-dumps/`.
* Say "verified" only for what you saw on this cabinet.

## How to report

For each task, add a short dated block to the end of this file, under **Results**: the date, the commands you ran, the output that matters (copy it, don't paraphrase), and anything that surprised you. If a step failed, paste the error and stop that task. Then:

```bash
git add FIELD_TASKS.md captures/
git commit -m "Field results: task N"
```

---

## Task 1: device facts from the dumps (no cabinet)

**Why.** The cloud session can't read the rootfs or the kernel; they're dumps and stay out of git. This writes small text facts about them that can be committed: library ABIs, the kernel config, the drivers built in, the GL strings. The Wi-Fi plan and the LÖVE build both depend on them.

```bash
cd ~/the-yard        # or wherever this repo is
D=~/partycade-dumps/2026-10-23_raw_plug3032slc
ls $D/rootfs/usr/lib/libSDL2-2.0.so.0.7.0 $D/boot.img      # both must exist
python3 tools/device_facts.py --rootfs $D/rootfs --kernel $D/boot.img --out captures
```

**Look for.** `captures/abi/INDEX.txt`, `captures/abi/*.txt`, `captures/kernel/version.txt`, `config.txt`, `drivers.txt`, `bootimg.txt`, `captures/gl/strings.txt`, `captures/sdl/strings.txt`, and `captures/system/` (init scripts, udev rules, network and dropbear settings, `shadow-state.txt`, `busybox-applets.txt`). The tool never copies a password hash or a dropbear key; check `captures/system/INDEX.txt` says so for any key file. Open `captures/kernel/drivers.txt` and copy its WIFI and NET sections into your report. Copy its FLASH and GADGET sections too, and the first ten lines of `bootimg.txt`. If `config.txt` says no config was found, write that down: the kernel was built without `IKCONFIG`, and the driver list from strings is all there is until the System probe reads `/proc/config.gz` (task 5).

**Check before committing.** `du -sh captures/abi captures/kernel captures/gl captures/sdl` should be a few MB at most, and every file text. If anything is binary or over 5 MB, don't commit it; report the size instead.

Then: `python3 games/love/check_abi.py games/out/love-arm` once task 2 has built the bundle. With `captures/abi/INDEX.txt` present it checks against the cabinet's real library list.

## Task 2: build LÖVE for the cabinet, and smoke-test it (no cabinet)

```bash
pip install --user ziglang==0.13.0          # the cross compiler; nothing else to install
games/love/build.sh arm                      # 10 to 20 minutes the first time; clones sources into ~/lovebuild
python3 games/love/check_abi.py games/out/love-arm
games/love/smoke.sh ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs
```

`build.sh` needs `git`, `make`, `cmake`, `ninja`, `autoconf`, `automake`, `libtool`, `pkg-config`, `zip`, and `readelf`. If one is missing, install it with the PC's package manager and run again; finished libraries are kept.

**Look for.** `check_abi.py` ends with `the bundle will load`. `smoke.sh` needs `qemu-arm-static` (GAMEDEV.md § 6 says it is in `~/.local/bin`) and should print `rootfs: <the dump's rootfs>` (not `/usr/arm-linux-gnueabihf`), nine `ok` lines, and `smoke ok`. Copy the whole output into the report. Its "3M sines" line is a qemu number, not a cabinet number.

If the smoke test fails, copy the error and stop: don't stage a bundle that fails here.

Also build the PC side and run the GPU tests, which need no cabinet:

```bash
games/love/build.sh x86
python3 games/test.py love                   # should end "12 passed, 0 failed"
```

## Task 3: the cart runtime for the cabinet (no cabinet)

```bash
cd games
./build.sh cab           # Docker image partycade-armhf; runs check_binary.sh on yard, orb, probe
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy YARD_PAK=out/yard.pak \
  qemu-arm-static -L ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs out/cab/yard --check keep
./cart check             # "all carts pass"
./stress.sh              # every check passes
```

Run `./cart pack` first if `out/yard.pak` is missing. **Look for:** `check_binary.sh` passes for all three, and the qemu run prints `ok: 300 frames`. If the Docker build fails (an earlier sandbox could not fetch its Debian packages), paste the error and stop: tasks 4 to 6 need `out/cab/yard`.

## Task 4: stage the update, then ask (cabinet plugged in, read-only until approval)

This puts the cart runtime, `orb`, the pack, the LÖVE bundle, and three new menu rows ("LOVE probe", "GPU yard", "System probe") into one plan. The System probe is a read-only shell script (`games/sysprobe/sysprobe.sh`; read it before staging) that records what the running Linux sees.

**4a. The user cold-plugs.** Tell them exactly this: "Unplug the cabinet's power and the Micro-USB cable. Put the back switch to OFF. Plug in only the Micro-USB cable to the PC." Then:

```bash
D=~/partycade-dumps/$(date +%F)_love
mkdir -p $D
tools/rk.py state                                   # expect mode=maskrom, fresh BootROM
tools/rk.py boot --plug plug_3032slc_erase          # once; on a timeout stop and ask for a cold plug
tools/rk.py rawdump -o $D/nand_raw.bin --verify
tools/rk_restore.py diff $D/nand_raw.bin            # must say none
```

**4b. Stage, offline.**

```bash
cd games
./cart deploy --raw $D/nand_raw.bin --out $D/stage --first --with-love-probe --with-sysprobe
cat $D/stage/PLAN.md
```

* If it stops with **"no physical copy"**, the new files landed on pages SFTL has never written. Write down the output, then try once without the big file: the same command without `--with-love-probe` (the cart runtime and the System probe only). If that stages, carry on with it and say so in the report; LÖVE then waits for the microSD card. If it also fails, stop task 4.
* If `--first` fails because the old games are already gone (a deploy was done since this file was written), write that down and stop.
* Otherwise `PLAN.md` lists the files and the blocks.

**4c. Ask the user.** Paste the file list and the block list from `PLAN.md`, and say:

> This writes these N blocks of the `data` partition: [list]. It replaces Keep, Lamp, Tea, and Chest's separate programs with one cart runtime, adds the LÖVE bundle (4 MB, unpacked by the cabinet on first run to 9 MB), and adds three test rows to The Yard: two for the GPU, and a System probe that only reads and writes a report file. If anything goes wrong, those same blocks come back from `$D/nand_raw.bin` with `rk_restore.py restore`. Do you approve writing exactly these blocks?

Wait for a written yes that names or quotes the list. Then:

```bash
PARTYCADE_ALLOW_NAND_WRITE=yes python3 tools/rk_restore.py restore $D/stage/nand_raw_patched.bin \
  --blocks <the list> --approval '<the user's words>'
tools/rk_restore.py diff $D/stage/nand_raw_patched.bin      # must say none
```

Record: the device number, the plug, the block list, the approval text, and both `diff` results.

## Task 5: the user plays and probes (cabinet on its own; the PC only watches USB)

Tell the user: "Unplug the Micro-USB. Switch ON, then power. Open Dig Dug II (The Yard). The list now scrolls: push the stick down past Chest for the new rows. Then:"

1. **The Yard**: Keep, Lamp, Orb, Tea, Chest, then LOVE probe, GPU yard, System probe (arrows at the right edge mean more rows). Play each of the five games for a minute. Note anything slow, wrong, or silent.
2. **LOVE probe**: the first time it takes up to a minute (it unpacks 9 MB). Then a test card cycles through its loads for about a minute. **When it says "press every button", press each button and push the stick in all four directions, one at a time, within ten seconds.** It quits on its own. Note what was on screen, whether the picture was the right way up, and whether you heard a beep.
3. **GPU yard**: the same menu on the GPU. Open Keep, Lamp, Tea, and Chest for a minute each; hold 1-player and 2-player to go back. Note smoothness compared with the normal Yard, and anything that looks different.
4. **System probe, with things to plug in.** Have the USB stick and the microSD card ready. Open System probe. The screen stays dark for about two minutes; that is normal. **About 30 seconds after opening it**, put the microSD card in the slot, wait 10 seconds, put the USB stick in the USB-A port, wait 10 seconds, then take both out. Then wait for the menu to come back. Nothing is expected to show up yet, because both ports are still switched off in the device tree; this run is the "before" picture.
5. **The Micro-USB port while it runs.** With the cabinet on and in the menu, plug the Micro-USB cable into the PC. The agent runs `lsusb` and `dmesg | tail -20` on the PC and records both. Expected: nothing, because the port is in host mode. Then unplug it.
6. Leave the GPU menu or the Yard with 1-player and 2-player, then switch OFF **from the stock menu** (not mid-game), so the logs are flushed.

Write the user's notes into the report word for word, with the rough time they plugged each thing in.

## Task 6: read the results back (cabinet plugged in, read-only)

Cold plug again (as 4a), then:

```bash
D2=~/partycade-dumps/$(date +%F)_love_played
mkdir -p $D2
tools/rk.py state && tools/rk.py boot --plug plug_3032slc
tools/rk.py rawdump -o $D2/nand_raw.bin --verify
python3 tools/sftl_rebuild.py $D2/nand_raw.bin $D2/logical.img
dd if=$D2/logical.img of=$D2/data.img bs=512 skip=$((0x22c00)) count=$((0xf000))
mkdir -p captures/love captures/sysprobe
for f in love-probe.txt love-probe.log love-yard.log yard.log yard.log.1; do
  debugfs -R "dump /Games/$f captures/love/$f" $D2/data.img
done
for n in 1 2 3 4 5; do debugfs -R "dump /Games/sysprobe-$n.txt captures/sysprobe/before-$n.txt" $D2/data.img; done
debugfs -R "ls -l /Games" $D2/data.img > captures/love/games-ls.txt
debugfs -R "ls -l /love" $D2/data.img > captures/love/love-ls.txt
# The partitions as our tools see them, to compare with the checksums Linux printed in the probe report.
python3 - $D2/logical.img > captures/sysprobe/partition-sums.txt <<'PY'
import hashlib, json, sys
img = open(sys.argv[1], "rb")
for p in json.load(open("captures/partitions.json"))["partitions"]:
    img.seek(p["offset"] * 512)
    print(f"{p['name']}: offset {p['offset']}, {p['sectors']} sectors, sha256 {hashlib.sha256(img.read(p['sectors'] * 512)).hexdigest()}")
PY
ls -l captures/love captures/sysprobe
```

Missing files are results too: write down which ones didn't exist. If `debugfs` says the filesystem is damaged (a power cut), add `-c` to read it anyway, and say so.

`yard.log` should start with `yard: pid ..., memory ...` and `cab: The Yard: video KMSDRM, display 1024x768 ...`, and have `stats <cart> frame ...` lines for each game played: those are the first frame times measured on the cabinet. Copy the `cab:` lines and a few `stats` lines per game into the report.

**Before committing the probe report,** read it and remove anything private: it has no passwords, but if a line shows a serial number of the user's own USB stick or card, replace it with `<serial>`. Commit `captures/love/*` and `captures/sysprobe/*` (text only; check with `file`) and the report. In the report, compare each `/dev/...` checksum in the probe's "checksums" section with `partition-sums.txt`, and say which partitions match.

Add a line to STATUS.md "Pickup" saying what is now on the cabinet, with the dump paths and sha256s of `$D/nand_raw.bin`, `$D/stage/nand_raw_patched.bin`, and `$D2/nand_raw.bin`. Append a dated section to BOOT_RESEARCH.md with device numbers and commands. Then ask the user to push, and stop: the next cloud session reads these before task 7.

## Task 7: turn on the SD slot, USB-A, and ADB, then test them (only when the user asks)

This writes the `boot` partition, which is riskier than a `data` write: if the new device tree is bad, the cabinet won't start its games until those same blocks are restored over Micro-USB in Mask ROM, as every write so far could be. Don't start it on your own. Before asking for approval, explain that risk and that restore path in plain words.

**7a. Stage the boot change** (cold plug as 4a, with `plug_3032slc_erase`). Follow [GAMEDEV.md](GAMEDEV.md) § 11 exactly, with `--which sd,usb,adb`. `enable_storage.py report` on the result must show `dwmmc@10214000` and `usb@101c0000` as `okay` and `usb@10180000` with `dr_mode` `otg`, and nothing else changed. `sftl_patch.py --part boot` prints the blocks. Get written approval for exactly that list, restore those blocks, and `diff` against the patched image: none. Record everything as in task 4.

**7b. Does it boot?** The user: Micro-USB out, switch ON, power. Does the stock menu appear, and does The Yard open? If not: power off, and go straight to restoring the same blocks from `$D/nand_raw.bin` (cold plug, `plug_3032slc_erase`, written approval for that restore). Write down exactly what the screen showed.

**7c. Prepare the card on the PC.** Find the card's device with `lsblk` before and after inserting it, and **check the size matches the card. A wrong device name here erases the PC's own disk.** Then, with `/dev/sdX` the card:

```bash
sudo parted -s /dev/sdX mklabel msdos mkpart primary fat32 1MiB 1GiB mkpart primary ext2 1GiB 2GiB
sudo mkfs.vfat -F 32 -n YARD /dev/sdX1
sudo mkfs.ext2 -L yardx /dev/sdX2
sudo mount /dev/sdX1 /mnt && echo hello-fat | sudo tee /mnt/hello.txt && sudo dd if=/dev/urandom of=/mnt/big.bin bs=1M count=64 && sha256sum /mnt/big.bin && sudo umount /mnt
sudo mount /dev/sdX2 /mnt && echo hello-ext2 | sudo tee /mnt/hello.txt && sudo umount /mnt
```

Record `big.bin`'s sha256. (The 64 MB file is for a read-speed number; the probe reads it with `dd`.) This two-partition card is a test layout on purpose: it shows what the udev rule does with two partitions and with each filesystem. The card the games will use is the one-partition ext2 card in [SDCARD.md](SDCARD.md), made in 7f.

**7d. The "after" probes.** Cabinet on, card **out**, nothing in USB-A. Open System probe and, about 30 seconds in:

1. put in the card; wait 15 s;
2. put in the USB stick; wait 15 s; take it out;
3. put in the Wi-Fi adapter; wait 20 s; leave it in.

Let the menu come back. Run System probe a second time with the card, the stick, and the adapter all in from the start, and plug nothing during it.

**7e. ADB.** Cabinet on, at the menu, switch ON. Micro-USB to the PC. On the PC:

```bash
lsusb; dmesg | tail -20
adb devices
adb shell id
adb shell cat /proc/partitions /proc/mounts
adb shell 'ls -l /mnt /media /udisk; cat /proc/mounts | grep -i -e mmc -e sd'
adb shell 'time dd if=/mnt/sdcard/big.bin of=/dev/null bs=1M' 2>&1   # use the card's mount point from the line above
adb shell 'dd if=/dev/zero of=/mnt/sdcard/w.bin bs=1M count=32 && sync && rm /mnt/sdcard/w.bin' 2>&1
adb shell 'for d in /sys/bus/usb/devices/*; do [ -e $d/idVendor ] && echo $d $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null); done'
adb pull /data/Games/ captures/sysprobe-after/   # then keep only the sysprobe-*.txt files
```

Only reads, apart from the 32 MB test file on the card, which it removes. Don't change anything else over ADB in this task, however easy it looks: no remounts, no writes to `/data` or any partition. If `adb devices` shows nothing, record `lsusb` and `dmesg` and carry on: task 6's way of reading the reports still works.

**7f. The real card.** Make the card exactly as [SDCARD.md](SDCARD.md) says (one ext2 partition, label `YARD`), and put one test cart on it: `cp -r games/carts/keep /mnt/yard/carts/cardkeep`, then change `title = "Keep"` to `title = "Card Keep"` in its `info.lua`. Card in, cabinet on, open The Yard: is there a "Card Keep" row, does it play, and does the menu say "card in"? Over ADB (if it worked): `adb shell 'mount | grep -i mmc; ls -l /mnt/sdcard /mnt/sdcard/yard/carts'`. Record what was seen, and update SDCARD.md's "How sure" column with it.

**7g. Read back and report.** If ADB worked, the probe reports are already pulled; otherwise read them back as in task 6 (as `after-N.txt`). Also note the Wi-Fi adapter's make and model as printed on it. Commit `captures/sysprobe/` and the report, and ask the user to push.

---

## Results

### Task 1 (2026-10-24)

Commands run:
```bash
cd ~/Projects/arcade1up-partycade
D=~/partycade-dumps/2026-10-23_raw_plug3032slc
ls $D/rootfs/usr/lib/libSDL2-2.0.so.0.7.0 $D/boot.img
python3 tools/device_facts.py --rootfs $D/rootfs --kernel $D/boot.img --out captures
du -sh captures/abi captures/kernel captures/gl captures/sdl captures/system
```

Output summary:
* `abi: 126 libraries -> captures/abi` (1.9M)
* `gl: 1 mali libraries; sdl: 1 -> captures/gl, captures/sdl` (12K, 8.0K)
* `system: 50 entries -> captures/system` (232K); `captures/system/INDEX.txt` confirms `lib/udev/mtd_probe: 5496 bytes, binary or a key, not copied` and `etc/shadow: password state only -> shadow-state.txt` (`root: set`, all others `locked`).
* `kernel: Linux version 4.4.194 (tyc@dell) (gcc version 6.3.1 20170404; config no -> captures/kernel` (20K). `captures/kernel/config.txt` says `# The image carries no config (no IKCFG_ST). drivers.txt is the string search instead.` The kernel was built without `IKCONFIG`.

`captures/kernel/bootimg.txt`:
```text
file boot.img: 4718592 bytes, sha256 a0ce5967ba5dba1b0316c83e806d814c8e12f169d5470cf72ffe8165db3fba90
first 16 bytes: 414e44524f49442190ab460000800010  b'ANDROID!'
android boot header: kernel 4631440 bytes at load 0x10008000, ramdisk 0 at 0x0, second 69120 at 0x10f00000, tags 0x10000100, page size 2048
cmdline: 
gzip stream at 0x6fb0: 4604837 bytes -> 12984320
device tree at 0x46be00: 24709 bytes rockchip,rk3032-dongle
```

`captures/kernel/drivers.txt` (WIFI, USB-NET, FLASH, GADGET sections):
```text
wifi     cfg80211             absent
wifi     mac80211             absent
wifi     nl80211              absent
wifi     rtl8xxxu             absent
wifi     rtl8192cu            absent
wifi     rtl8188eu            absent
wifi     r8188eu              absent
wifi     8188eu               absent
wifi     8192cu               absent
wifi     8812au               absent
wifi     8821cu               absent
wifi     rtw88                absent
wifi     rtl8187              absent
wifi     rt2800usb            absent
wifi     rt2x00               absent
wifi     mt7601u              absent
wifi     mt76x0u              absent
wifi     mt76x2u              absent
wifi     ath9k_htc            absent
wifi     carl9170             absent
wifi     brcmfmac             absent
wifi     zd1211rw             absent
wifi     ar5523               absent
wifi     rsi_usb              absent
wifi     wpa                  present
wifi     WEXT                 absent
wifi     cfg80211_scan        absent
wifi     ieee80211            absent
usb-net  usbnet               present
usb-net  cdc_ether            present
usb-net  rndis_host           present
usb-net  asix                 present
usb-net  ax88179              present
usb-net  r8152                present
usb-net  smsc95xx             present
usb-net  cdc_ncm              present
usb-net  g_ether              absent
usb-net  rndis                present
usb-net  usb_f_rndis          absent
usb-net  usb_f_ecm            absent
usb-net  usb_f_fs             absent
usb-net  configfs             present
usb-net  dwc2                 present
usb-net  ehci                 present
usb-net  ohci                 present
usb-net  usb-storage          present
usb-net  uas                  present
flash    rkflash              present
flash    rknand               absent
flash    rk_nand              absent
flash    sftl                 absent
flash    mtdblock             absent
flash    mtd                  present
flash    spinand              absent
flash    sfc                  present
flash    blkdev               present
flash    by-name              absent
gadget   usb_f_fs             absent
gadget   f_fs                 present
gadget   functionfs           present
gadget   android_usb          present
gadget   usb_f_adb            absent
gadget   adb                  present
gadget   usb_f_mass_storage   absent
gadget   usb_f_acm            absent
gadget   g_serial             absent
gadget   libcomposite         absent
gadget   udc-core             absent
gadget   dwc2_hsotg           present
gadget   otg                  present
```

Surprises / notable findings:
* Every Wi-Fi stack (`cfg80211`, `mac80211`, `nl80211`, `WEXT`, `ieee80211`) and every USB Wi-Fi driver is **absent** from the kernel strings, whereas USB Ethernet/RNDIS host drivers (`usbnet`, `cdc_ether`, `rndis_host`, `asix`, `ax88179`, `r8152`, `smsc95xx`, `cdc_ncm`) are **present**! That means a USB Ethernet dongle or USB RNDIS/CDC-Ether device (e.g. a phone in USB tethering mode or a tiny USB-Ethernet/Wi-Fi bridge) may work with the stock kernel without rebuilding `boot.img`, whereas a bare USB Wi-Fi adapter would require a kernel rebuild.
* `etc/init.d/S50usbdevice` uses configfs (`ffs.adb`, `rndis.gs0`, etc.) and reads `/etc/init.d/.usb_config` (`usb_adb_en`).
* `lib/udev/rules.d/61-sd-cards-auto-mount.rules` matches `KERNEL!="mmcblk*[0-9]"` and `ATTRS{type}!="SD"`, mounting `vfat` with `rw,uid=1000,gid=1000,dmask=022,fmask=133,noatime` and `ext2` with `users,exec,noatime` at `/mnt/sdcard`.

### Task 2 (2026-10-24)

Commands run:
```bash
pip install --user --break-system-packages ziglang==0.13.0
games/love/build.sh arm
python3 games/love/check_abi.py games/out/love-arm
games/love/smoke.sh ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs
games/love/build.sh x86
python3 games/test.py love
```

Surprise found and fixed in `games/love/build.sh`:
* The initial run of `smoke.sh` against the cabinet's real `rootfs` (`libc-2.29.so`) failed with `Error: [love "boot.lua"]:48: Failed to initialize filesystem: no error`. Tracing with `qemu-arm-static -strace` and a test C binary showed that Zig 0.13.0's bundled glibc headers have no ARM-specific `xstatver.h` and fall back to `sysdeps/unix/sysv/linux/xstatver.h` (`_STAT_VER = 0`), whereas 32-bit ARM glibc 2.29 requires `_STAT_VER_LINUX = 3` in `__xstat(ver, path, buf)` and returns `EINVAL` (`errno = 22`) for `ver = 0`. However, `__xstat64`/`__fxstat64`/`__lxstat64` in the cabinet's `libc-2.29.so` ignore the `ver` argument and succeed for all versions `0..3` (and avoid `EOVERFLOW` on 64-bit inodes). Adding `-D_FILE_OFFSET_BITS=64` to `CFLAGS` and `CXXFLAGS` in `games/love/build.sh` routes all `stat`/`fstat`/`lstat` calls through `__xstat64`/`__fxstat64`/`__lxstat64`.

Output of `check_abi.py`:
```text
ok   love.bin                     glibc 2.4    
ok   lib/libSDL2-2.0.so.0         glibc 2.28   
ok   lib/libfreetype.so.6         glibc 2.28   
ok   lib/liblove-11.5.so          glibc 2.28   
ok   lib/libluajit-5.1.so.2       glibc 2.7    
ok   lib/libmodplug.so.1          glibc 2.27   
ok   lib/libogg.so.0              glibc 2.4    
ok   lib/libopenal.so.1           glibc 2.27   
ok   lib/libtheoradec.so.1        glibc 2.4    
ok   lib/libvorbis.so.0.4.9       glibc 2.4    
ok   lib/libvorbisfile.so.3.3.8   glibc 2.4    
ok   lib/libz.so.1                glibc 2.4    
ok   opened at run time: libEGL.so.1 is on the cabinet
ok   opened at run time: libGLESv2.so.2 is on the cabinet
ok   opened at run time: libgbm.so.1 is on the cabinet
ok   opened at run time: libdrm.so.2 is on the cabinet
ok   opened at run time: libasound.so.2 is on the cabinet
ok   opened at run time: libudev.so.1 is on the cabinet
the bundle will load
```

Output of `smoke.sh`:
```text
qemu: /home/joseph/.local/bin/qemu-arm-static, rootfs: /home/joseph/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs
ok   version: 11.5.0, LuaJIT 2.1.1792588164 arm
ok   lua loop: 3M sines in 2864 ms
ok   a C++ exception comes back as a Lua error
ok   image data
ok   png encode
ok   sound data
ok   freetype
ok   zlib
ok   bit ops
smoke ok
```

Output of `games/love/build.sh x86` and `python3 games/test.py love`:
```text
9.5M	/home/joseph/Projects/arcade1up-partycade/games/out/love-x86
built /home/joseph/Projects/arcade1up-partycade/games/out/love-x86
== love: the GPU runtime against the C runtime
  ok   chest: the bot's game logs the same 105 lines on both runtimes
  ok   chest: the same save file on both runtimes
  ok   keep: the bot's game logs the same 8 lines on both runtimes
  ok   keep: the same save file on both runtimes
  ok   lamp: the bot's game logs the same 21 lines on both runtimes
  ok   lamp: the same save file on both runtimes
  ok   tea: the bot's game logs the same 60 lines on both runtimes
  ok   tea: the same save file on both runtimes
  ok   the menu runs, launches Lamp, and quits cleanly (exit 0)
  ok   Lamp draws a picture when the menu starts it
  ok   the menu draws again after Lamp quits
  ok   no error on the way
== 12 passed, 0 failed ==
```

### Task 3 (2026-10-24)

Commands run:
```bash
cd ~/Projects/arcade1up-partycade/games
./build.sh cab
./cart pack
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy YARD_PAK=out/yard.pak \
  qemu-arm-static -L ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs out/cab/yard --check keep
./cart check
./stress.sh
```

Note on `build.sh`:
* On a fresh git checkout `tools/bin2c.py` had a timestamp 15 ms newer than `engine/lib_lua.h`, causing `make TARGET=cab` inside the `partycade-armhf` Docker container (which has no `python3`) to attempt `python3 tools/bin2c.py`. Added `python3 tools/bin2c.py && touch engine/lib_lua.h engine/fonts/round_ttf.h` on the host side of `cab()` in `games/build.sh` before invoking Docker.

Output of `./build.sh cab`, `./cart pack`, and the `qemu-arm-static` smoke test:
```text
out/cab/yard: OK for the cabinet (newest GLIBC 2.27, 396824 bytes)
out/cab/orb: OK for the cabinet (newest GLIBC 2.27, 188964 bytes)
out/cab/probe: OK for the cabinet (newest GLIBC 2.27, 171124 bytes)
/home/joseph/Projects/arcade1up-partycade/games/out/yard.pak: 13 files, 121 KB used of the 4 MB slot
  the runtime reads: yard, keep, lamp, orb, tea, chest
yard: pid 2931285, memory 7224920 kB of 16148340 kB available
yard: start keep, 6 carts
stats keep frame 300 update 0.06ms draw 1.55ms peak 21.81ms lua 593KB images 300KB
ok: 300 frames, lua 593 KB, images 300 KB
```

Output of `./cart check` and `./stress.sh`:
* `./cart check`: all 5 carts (`chest`, `keep`, `lamp`, `tea`, `yard`) passed 30 s bot play and 30 s random mashing; ended with `all carts pass`.
* `./stress.sh`: all four passes (`quick`, `play`, `stress`, `system`, plus `love`) passed; ended with `== 97 passed, 0 failed ==`.



