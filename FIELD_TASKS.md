# Field tasks: work that needs the cabinet PC

Written 2026-10-24 by a cloud session that has no cabinet, no `~/partycade-dumps/`, and no rootfs. These tasks are for the agent on the PC the cabinet plugs into. Do them in order. Each one says what to run, what to look for, and what to write down. When a task is done, commit its results (never dumps or binaries) and tell the user to push, so the next cloud session can read them.

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

**Look for.** `captures/abi/INDEX.txt`, `captures/abi/*.txt`, `captures/kernel/version.txt`, `captures/kernel/config.txt`, `captures/kernel/drivers.txt`, `captures/gl/strings.txt`, `captures/sdl/strings.txt`. Open `captures/kernel/drivers.txt` and copy its WIFI and NET sections into your report. If `config.txt` says no config was found, write that down: the kernel was built without `IKCONFIG`, and the driver list from strings is all there is.

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

This puts the cart runtime, `orb`, the pack, the LÖVE bundle, and two new menu rows ("LOVE probe" and "GPU yard") into one plan.

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
./cart deploy --raw $D/nand_raw.bin --out $D/stage --first --with-love-probe
cat $D/stage/PLAN.md
```

* If it stops with **"no physical copy"**, the new files landed on pages SFTL has never written. Write down the output and stop task 4. Don't try other flags. The next cloud session will decide, and the fallback is the microSD card (task 7).
* If `--first` fails because the old games are already gone (a deploy was done since this file was written), write that down and stop.
* Otherwise `PLAN.md` lists the files and the blocks.

**4c. Ask the user.** Paste the file list and the block list from `PLAN.md`, and say:

> This writes these N blocks of the `data` partition: [list]. It replaces Keep, Lamp, Tea, and Chest's separate programs with one cart runtime, adds the LÖVE bundle (4 MB, unpacked by the cabinet on first run to 9 MB), and adds two test rows to The Yard. If anything goes wrong, those same blocks come back from `$D/nand_raw.bin` with `rk_restore.py restore`. Do you approve writing exactly these blocks?

Wait for a written yes that names or quotes the list. Then:

```bash
PARTYCADE_ALLOW_NAND_WRITE=yes python3 tools/rk_restore.py restore $D/stage/nand_raw_patched.bin \
  --blocks <the list> --approval '<the user's words>'
tools/rk_restore.py diff $D/stage/nand_raw_patched.bin      # must say none
```

Record: the device number, the plug, the block list, the approval text, and both `diff` results.

## Task 5: the user plays (cabinet on its own, no PC)

Tell the user: "Unplug the Micro-USB. Switch ON, then power. Open Dig Dug II (The Yard). Then:"

1. **The Yard**: the menu shows Keep, Lamp, Orb, Tea, Chest, LOVE probe, GPU yard. Play each of the five games for a minute. Note anything slow, wrong, or silent.
2. **LOVE probe**: the first time it takes up to a minute (it unpacks 9 MB). Then a test card cycles through its loads for about a minute. **When it says "press every button", press each button and push the stick in all four directions, one at a time, within ten seconds.** It quits on its own. Note what was on screen, whether the picture was the right way up, and whether you heard a beep.
3. **GPU yard**: the same menu on the GPU. Open Keep, Lamp, Tea, and Chest for a minute each; hold 1-player and 2-player to go back. Note smoothness compared with the normal Yard, and anything that looks different.
4. Hold 1-player and 2-player in the GPU menu to leave, then switch OFF **from the stock menu** (not mid-game), so the logs are flushed.

Write the user's notes into the report word for word.

## Task 6: read the results back (cabinet plugged in, read-only)

Cold plug again (as 4a), then:

```bash
D2=~/partycade-dumps/$(date +%F)_love_played
mkdir -p $D2
tools/rk.py state && tools/rk.py boot --plug plug_3032slc
tools/rk.py rawdump -o $D2/nand_raw.bin --verify
python3 tools/sftl_rebuild.py $D2/nand_raw.bin $D2/logical.img
dd if=$D2/logical.img of=$D2/data.img bs=512 skip=$((0x22c00)) count=$((0xf000))
mkdir -p captures/love
for f in love-probe.txt love-probe.log love-yard.log yard.log; do
  debugfs -R "dump /Games/$f captures/love/$f" $D2/data.img
done
debugfs -R "ls -l /Games" $D2/data.img > captures/love/games-ls.txt
debugfs -R "ls -l /love" $D2/data.img > captures/love/love-ls.txt
ls -l captures/love
```

Missing files are results too: write down which ones didn't exist. If `debugfs` says the filesystem is damaged (a power cut), add `-c` to read it anyway, and say so.

**Commit** `captures/love/*` (text only; check with `file captures/love/*`) and the report. Add a line to STATUS.md "Pickup" saying what is now on the cabinet, with the dump paths and sha256s of `$D/nand_raw.bin`, `$D/stage/nand_raw_patched.bin`, and `$D2/nand_raw.bin`. Append a dated section to BOOT_RESEARCH.md with device numbers and commands. Then ask the user to push.

## Task 7: the SD slot and ADB (a separate session, only after the user asks)

This is a write to the `boot` partition, which is riskier than a `data` write: a bad device tree means a cabinet that doesn't boot until those blocks are restored over USB. Don't start it on your own. When the user asks, follow [GAMEDEV.md](GAMEDEV.md) § 11 with `--which sd,adb`, and [RUNBOOK.md](RUNBOOK.md) Phase 4. Before asking for approval, explain that risk and the restore path in plain words.

---

## Results

(Add dated blocks here.)
