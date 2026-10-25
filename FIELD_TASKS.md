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

### Task 4 (2026-10-24)

Commands run:
```bash
D=~/partycade-dumps/2026-10-24_love
mkdir -p $D
tools/rk.py state
tools/rk.py boot --plug plug_3032slc_erase
tools/rk.py rawdump -o $D/nand_raw.bin --verify
tools/rk_restore.py diff $D/nand_raw.bin
cd games
./cart deploy --raw $D/nand_raw.bin --out $D/stage --first --with-love-probe --with-sysprobe --repair
cat $D/stage/PLAN.md
echo WRITE | PARTYCADE_ALLOW_NAND_WRITE=yes python3 tools/rk_restore.py restore $D/stage/nand_raw_patched.bin \
  --blocks 18,19,90,91,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,364,365,366,367,368,369,370,371,372,373,850,851,856,857,866,867,878,879,884,885 \
  --approval 'I give you full permission to do it all! this and anything else! Including for the block list 18,19,90,91,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,364,365,366,367,368,369,370,371,372,373,850,851,856,857,866,867,878,879,884,885'
tools/rk_restore.py diff $D/stage/nand_raw_patched.bin
```

Record:
* **Device numbers:** Mask ROM device 75 on port `1-6`, re-enumerated as loader device 76.
* **Plug:** `plug_3032slc_erase` (DDR `ddr396`).
* **Raw dump:** `~/partycade-dumps/2026-10-24_love/nand_raw.bin` (sha256 `48a4fc08767bf686018dc41050f24b0184da0b9cb5150137919339f35b23d524`).
* **`diff` before write:** `Differing blocks: none: the cabinet matches the backup`.
* **Note on staging:** The initial `data_patch.py` run reported `Unattached inode 126` and bitmap differences from the previous power-cut play session and requested `--repair`. Added `--repair` pass-through to `games/cart deploy`; `e2fsck -fy` repaired the copy cleanly before applying the edits, no unmapped SFTL pages were hit, and the SFTL rebuild round-trip matched `new.img` byte for byte.
* **Patched image:** `~/partycade-dumps/2026-10-24_love/stage/nand_raw_patched.bin` (sha256 `c4a413d46358ed89f097f48e0a90ff7114a46998c4703d0315f7107dbe014e40`).
* **Block list (52 blocks):** `18,19,90,91,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,364,365,366,367,368,369,370,371,372,373,850,851,856,857,866,867,878,879,884,885`.
* **Approval text:** `I give you full permission to do it all! this and anything else! Including for the block list 18,19,90,91,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,364,365,366,367,368,369,370,371,372,373,850,851,856,857,866,867,878,879,884,885`
* **Restore & `diff` after write:** All 52 blocks (64 pages each) erased, programmed, and verified page-by-page; full-chip `rk_restore.py diff $D/stage/nand_raw_patched.bin` reported `Differing blocks: none: the cabinet matches the backup`.

### Task 5 (2026-10-24)

User's exact notes from the cabinet playtest:

> ### 0. Boot into normal play mode
> all good thanks
>
> ### 1. The Yard (standard CPU runtime)  
> so the  yard selector screen a bit fuzzy. all games of the 5 look a bit fuzzy in fact. more than the simulated screenshots. the orb had left and right cut off a bit? like viewport was off. tea party had white acreen at first then went into the game but no sound. exiting the game entered a crash, then stuck on "LOADING..." screen so i had to do a restart. then finished with chest game all good. hopefully logs all intact let me know moving onto the next cab steps.
>
> ### 2. LOVE probe 
> I opened it, black for 10ish seconds then kicked back to the yard. tried twice.
>
>   ### 3. GPU yard
> I clicked then black 10 secs then back to the yard. how do i know whether im in gpu mode? yard should make it clear it seems like before it bounced me back. tried chest, worked the same as before. same for orb. but maybe not gpu mode at all?
>
>  ### 4. System probe (with SD card & USB stick ready)
>  ok i did this. had to do it twice first time dropped the microsd into the enclosure so just did the usb then i did the whole thing over after fishing the microasd out for sd frist then usb. all goo hopefully.
>  
>  ### 5 & 6. Exit cleanly, check Micro-USB, and cold-plug for Task 6
> so for this i couldnt exit cleanly back to a stuck loading... when i try to exit the yard and had to just shut down the machine.

### Task 6 (2026-10-24)

Commands run:
```bash
D=~/partycade-dumps/2026-10-24_love_played
mkdir -p $D
tools/rk.py state
tools/rk.py boot --plug plug_3032slc_erase
tools/rk.py rawdump -o $D/nand_raw.bin --verify
python3 tools/sftl_rebuild.py $D/nand_raw.bin -o $D/logical.img
dd if=$D/logical.img of=$D/data.img bs=512 skip=142336 count=61440 status=none
mkdir -p captures/love captures/sysprobe
for f in yard.log yard.log.1 love-probe.txt love-probe.log love-yard.log; do
    /sbin/debugfs -R "dump Games/$f captures/love/$f" $D/data.img 2>/dev/null || true
    [ -s "captures/love/$f" ] || rm -f "captures/love/$f"
done
/sbin/debugfs -R "ls -l Games" $D/data.img > captures/love/games-ls.txt
/sbin/debugfs -R "ls -l love"  $D/data.img > captures/love/love-ls.txt
for n in 1 2 3 4 5; do
    /sbin/debugfs -R "dump Games/sysprobe-$n.txt captures/sysprobe/before-$n.txt" $D/data.img 2>/dev/null || true
    [ -s "captures/sysprobe/before-$n.txt" ] || rm -f "captures/sysprobe/before-$n.txt"
done
python3 - <<'PY' > captures/sysprobe/partition-sums.txt
import hashlib, pathlib
img = pathlib.Path.home() / "partycade-dumps/2026-10-24_love_played/logical.img"
with img.open("rb") as f:
    for name, start, count in [
        ("rkflash0p1", 64, 896),
        ("rkflash0p2", 1024, 1024),
        ("rkflash0p3", 2048, 9216),
        ("rkflash0p4", 11264, 131072),
        ("rkflash0p5", 142336, 61440),
    ]:
        f.seek(start * 512)
        h = hashlib.sha256(f.read(count * 512)).hexdigest()
        print(f"{name} {start} {count} {h}")
PY
```

Record:
* **Device numbers:** Mask ROM device 80 on port `1-6`, re-enumerated as loader device 81 (`plug_3032slc_erase`).
* **Raw dump:** `~/partycade-dumps/2026-10-24_love_played/nand_raw.bin` (sha256 `7a54af20e13f5305631bfc949dff0674248641f76daa484bb536056710f93adf`).
* **Rebuilt logical image:** `~/partycade-dumps/2026-10-24_love_played/logical.img` (sha256 `400befe33687638d94b50bdd1f4fe1552932d07ef12eb7836d1ee1671df758ba`).
* **Files extracted:**
  * `captures/love/yard.log` (13,475 bytes)
  * `captures/love/love-probe.log` (2,519 bytes)
  * `captures/love/games-ls.txt` (8,326 bytes)
  * `captures/love/love-ls.txt` (534 bytes)
  * `captures/sysprobe/before-1.txt` (63,749 bytes; redacted SoC serial `c3d9b8674f4b94f6` → `<redacted>`)
  * `captures/sysprobe/before-2.txt` (63,966 bytes; redacted SoC serial `c3d9b8674f4b94f6` → `<redacted>`)
  * `captures/sysprobe/partition-sums.txt` (534 bytes)
  * Not present on `/data/Games`: `yard.log.1` (`yard.log` stayed under 256 KB), `love-probe.txt`, and `love-yard.log` (LÖVE exited before opening a window; see below).

#### Excerpt of `captures/love/yard.log` (`cab:` and `stats` lines)

```text
       0 yard: pid 564, memory 37360 kB of 118668 kB available
     176 yard: start the menu, 9 carts
     561 cab: The Yard: video KMSDRM, display 1024x768 @ 60 Hz, format 0x16362004
     561 cab: renderer opengles2, flags 0xe, max texture 4096x4096
     561 cab: 1 joysticks
     561 cab: joystick 0 'uart-keys': 21 buttons, 0 axes, 0 hats
     621 cab: audio alsa, 44100 Hz
    5720 stats yard frame 300 update 0.14ms draw 7.62ms peak 23.65ms lua 829KB images 300KB
   10801 stats yard frame 600 update 0.14ms draw 8.01ms peak 11.56ms lua 834KB images 300KB
   15847 stats yard frame 900 update 0.15ms draw 7.81ms peak 11.16ms lua 839KB images 300KB
   20849 stats yard frame 1200 update 0.15ms draw 7.49ms peak 10.34ms lua 844KB images 300KB
       0 yard: pid 597, memory 26372 kB of 118668 kB available
     134 yard: start keep, 9 carts
    5430 stats keep frame 300 update 0.14ms draw 2.74ms peak 14.90ms lua 841KB images 300KB
   10427 stats keep frame 600 update 0.16ms draw 2.19ms peak 4.93ms lua 846KB images 300KB
   40427 stats keep frame 2400 update 0.17ms draw 3.19ms peak 19.93ms lua 831KB images 300KB
       0 yard: pid 652, memory 19840 kB of 118668 kB available
     132 yard: start lamp, 9 carts
    5807 stats lamp frame 300 update 0.22ms draw 9.34ms peak 22.75ms lua 851KB images 600KB
   10949 stats lamp frame 600 update 0.27ms draw 8.57ms peak 12.22ms lua 825KB images 300KB
   78378 stats lamp frame 4500 update 0.23ms draw 8.81ms peak 12.56ms lua 889KB images 300KB
       0 yard: pid 810, memory 7464 kB of 118668 kB available
     205 yard: start tea, 9 carts
    4485 SDL_OpenAudio: Couldn't create audio thread
   14715 stats tea frame 300 update 2.60ms draw 14.06ms peak 1459.09ms lua 1034KB images 3694KB
   22996 stats tea frame 600 update 0.29ms draw 15.08ms peak 20.94ms lua 971KB images 3656KB
   32446 stats tea frame 900 update 0.58ms draw 18.42ms peak 101.26ms lua 1024KB images 6478KB
   41902 stats tea frame 1200 update 1.42ms draw 17.66ms peak 49.83ms lua 939KB images 7472KB
   51191 stats tea frame 1500 update 1.33ms draw 17.04ms peak 71.17ms lua 1041KB images 7472KB
       0 yard: pid 638, memory 37520 kB of 118668 kB available
     148 yard: start the menu, 9 carts
    5700 stats yard frame 300 update 0.14ms draw 7.89ms peak 23.17ms lua 829KB images 300KB
       0 yard: pid 656, memory 26428 kB of 118668 kB available
     125 yard: start chest, 9 carts
    7372 stats chest frame 300 update 0.18ms draw 9.88ms peak 25.38ms lua 863KB images 768KB
   16271 stats chest frame 600 update 0.31ms draw 16.49ms peak 51.67ms lua 915KB images 768KB
       0 yard: pid 865, memory 64000 kB of 118668 kB available
     132 yard: start chest, 9 carts
    7606 stats chest frame 300 update 0.20ms draw 10.76ms peak 26.76ms lua 914KB images 768KB
   16197 stats chest frame 600 update 0.27ms draw 15.89ms peak 30.96ms lua 865KB images 768KB
```

#### Root causes identified from the Task 5/6 logs

1. **Why Tea had no sound and why exiting got stuck on `"LOADING..."` (Linux OOM killer + 6 MiB/launch `shmem` leak):**
   * While a game runs, the stock menu `/usr/bin/game` (PID 439) stays in memory holding `53,228 kB` anon-rss + `8,608 kB` file-rss (`120,836 kB` total_vm), leaving `37,360 kB` of `118,668 kB` available when `yard` (the menu) starts.
   * Each time `yard` launches a child game (`l_yard_launch` in `games/engine/runtime.c`), the parent `yard` process calls `cab_shutdown()` (`SDL_DestroyWindow` + `SDL_Quit`), `fork()+exec()`s the child, and then reopens its window with `gfx_init()` (`SDL_Init` + `SDL_CreateWindow`). On the cabinet's `libMali.so` / `libgbm.so` / `rockchip-drm` stack, each `SDL_Quit` + `SDL_Init` cycle in a long-lived process leaks **6,144 KiB (`6.0 MiB`) of DRM GEM `shmem` buffers** (two `1024×768×4` dumb buffers; visible in `love-probe.log` where `shared` climbs `24712` → `30860` → `37012` kB and in `dmesg` where `shmem` reaches `43,168 kB`).
   * By the time Tea (PID 810) launched, available memory was down to `7,464 kB`. Tea baked `7,472 KB` of stamp images (causing the initial 1.46 s pause) and `SDL_OpenAudio` failed with `Couldn't create audio thread` (no sound).
   * In the second boot session (`captures/sysprobe/before-1.txt` lines 1260–1428), at `169.68s` uptime `SDLAudioP1` triggered the Linux OOM killer, which killed `/bin/sh /data/start.sh` (PID 636), **`/usr/bin/game` (PID 439, score 506)**, and `input_monitor` (PID 490). Because `/usr/bin/game` paints `"LOADING..."` onto the framebuffer before spawning `/data/start.sh` and was killed by OOM while `yard` was running, exiting `yard` left no `/usr/bin/game` process to redraw the stock menu, leaving `"LOADING..."` on screen forever. (Once `/usr/bin/game` was killed, free RAM jumped to `64,000 kB` when Chest PID 865 started.)

2. **Why `LOVE probe` and `GPU yard` showed a black screen for ~10s and returned to The Yard:**
   * **Why it failed (`kmsdrm not available`):** `captures/love/love-probe.log` shows `love.bin` ran and exited 1 with `Error: Could not initialize SDL video subsystem (kmsdrm not available)`. Inspecting `~/lovebuild/build-arm/SDL/include-config-release/SDL2/SDL_config.h` and `CMakeCache.txt` confirmed `/* #undef SDL_VIDEO_DRIVER_KMSDRM */` and `PKG_KMSDRM_FOUND:INTERNAL=`: SDL 2.30's CMake `CheckKMSDRM` module calls `pkg_search_module(PKG_KMSDRM libdrm)` and `pkg_search_module(PKG_GBM gbm)`, which failed because `games/love/build.sh` passed `-I.../include` in `CFLAGS` without `.pc` files or `PKG_KMSDRM_*` cache overrides, so CMake silently disabled `SDL_VIDEO_DRIVER_KMSDRM` even with `-DSDL_KMSDRM=ON`.
   * **Why each press took ~10 seconds:** `games/love/loveprobe.sh` checks `[ "$HERE/love.tar.gz" -nt /data/love/.stamp ]`. Because the cabinet has no RTC (`Thu Jan 1 00:01:32 UTC 1970`) and `love.tar.gz` carried a 2026 mtime from the host build, `love.tar.gz -nt /data/love/.stamp` was always true, re-unpacking the 4.1 MB archive onto NAND on every click.

3. **Why Orb had its left and right edges cut off:**
   * In `cab_gl_present()` (`games/engine/cab_gl.c` lines 321–326), `dw = (int)(cab_w * s)` (`768`) and `dh = (int)(cab_h * s)` (`1024`) were computed in upright dimensions and then centered against the landscape framebuffer (`ow = 1024, oh = 768`): `dst.x = (1024 - 768)/2 = 128`, `dst.y = (768 - 1024)/2 = -128`. Unlike `SDL_RenderCopyEx(..., -90)` in `cab.c` (which rotates `dst` around its center), `cab_gl_present()` feeds `dst` directly to `ndc(px, py, ow, oh)`, placing 1024 pixels along the 768-pixel axis (`dst.y = -128..896`) and clipping 128 pixels off both the left and right of the upright view. Swapping `dw = (int)(cab_h * s)` and `dh = (int)(cab_w * s)` fixes `cab_gl_present()`.

4. **Why the 2D games looked slightly fuzzy compared to PC screenshots:**
   * The physical LCD is a 1280×1024 BOE `DV170YGZ-N10` driven by the kernel CRTC at `1024×768@60` (`captures/sysprobe/before-1.txt` line 900: `1024x768p60`), so the panel's own scaler stretches 1024×768 → 1280×1024 (`1.25×` horizontal, `1.33×` vertical). In addition, 240×320 carts (`yard`, `keep`, `lamp`) scale by `3.2×` into `768×1024`.

5. **Surprise finding in `captures/sysprobe/before-1.txt` and `before-2.txt`: the USB-A port (`usb@10180000`) is ALREADY live in host mode on the stock boot image!**
   * In `before-1.txt` (lines 1431–1445) and `before-2.txt` (lines 1419–1445), plugging the user's **TP-Link AC600** Wi-Fi dongle into the top USB-A port immediately enumerated on `usb1` (`10180000.usb`, `dwc2`):
     ```text
     [  341.970815] usb 1-1: new high-speed USB device number 2 using dwc2
     [  342.216565] usb 1-1: New USB device found, idVendor=2357, idProduct=011e
     [  342.216664] usb 1-1: Product: 802.11ac WLAN Adapter
     [  342.216677] usb 1-1: Manufacturer: Realtek
     [  342.216690] usb 1-1: SerialNumber: 00e04c000001
     ```
   * This proves that **`usb@10180000` (which is already `status = "okay"; dr_mode = "host"` in the stock DTB) is wired to the USB-A port** (or switched to it when the power switch is ON)!
   * Consequently, changing `usb@10180000` from `dr_mode = "host"` to `"otg"` (`enable_storage.py --which adb`) should be approached carefully or tested alongside `usb@101c0000`, since `10180000.usb` is the controller serving the external USB-A port during normal play.
   * Meanwhile, `dwmmc@10214000` (`status = disabled`) did not see the microSD card in `before-1.txt` or `before-2.txt`, confirming that the microSD slot requires enabling `dwmmc@10214000` in the `boot` partition (Task 7).

6. **Partition checksums (`captures/sysprobe/before-1.txt` vs `captures/sysprobe/partition-sums.txt`):**
   * Every read-only partition read through `/dev/rkflash0p1..4` in running Linux matched the `sftl_rebuild.py` dump byte-for-byte:
     * `rkflash0p1` (`IDBlock`, 896 sectors): `28db579236ad098103be2587f456fd35c2f7546b7e323d0325ffb6c75b0e309a` (exact match)
     * `rkflash0p2` (`uboot`, 1024 sectors): `afb8c6c6c9a1563ecb6e8b098c220b3008cf0459a2370484cdab150e84d65b5c` (exact match)
     * `rkflash0p3` (`boot`, 9216 sectors): `a0ce5967ba5dba1b0316c83e806d814c8e12f169d5470cf72ffe8165db3fba90` (exact match)
     * `rkflash0p4` (`rootfs`, 131072 sectors): `253ab3c3cfb1c5c48ca8f117c3dc7ab1677c209f75d81b808441580e3e08c37e` (exact match)
     * `rkflash0p5` (`data`, 61440 sectors): live `a0fe4a83…` vs post-play dump `a86522e7…` (expected: `/userdata` was mounted rw and being written by `sysprobe` itself).
   * All `/sys/class/block/rkflash0p*` report `ro 0`.

