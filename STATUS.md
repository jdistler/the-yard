# Status: what is known, as of 2026-10-25 (after the first cabinet run of the cart runtime)

This is the single source of truth for the current state. If another doc disagrees with this one, this one wins. Update it at the end of every session.

## Pickup

Read this before the history below. Dig Dug II opens The Yard.

* **On the cabinet (verified, 2026-10-24 Take 2 write):** tile 10 runs `/data/Games/yard`, the Lua 5.4 cart runtime, with eight rows: Keep, Lamp, Orb, Tea, Chest, and three test rows (LOVE probe, GPU yard, System probe). Orb's picture and Tea's sound are fixed there. Written by the field agent: Take 1, 52 blocks on device 76; Take 2, 64 blocks on device 81. Both `diff`s after writing said none. Hashes and block lists: [FIELD_TASKS.md](FIELD_TASKS.md) Results and § Backups below.
* **Still wrong on the cabinet (fixed in this tree, not yet written):**
  * **Leaving The Yard can stick on "LOADING...".** The kernel's OOM killer took the stock menu `/usr/bin/game` (53 MB of the 118 MB) when memory ran out, and nothing restarts it (`inittab` has no respawn; `S50ui` starts it once). Take 1 ran out because of a 6 MiB graphics leak per launch, which the agent's supervisor fixed. Take 2 ran out because GPU yard kept LÖVE in memory while Orb ran. Fixed now (2026-10-25): the supervisor protects the stock menu (`oom_score_adj -1000`), makes our processes the ones picked, and starts the stock menu again on the way out if it is gone; GPU yard quits LÖVE before a native program runs. `yard.conf` with `stock_menu stop` frees its 53 MB while The Yard runs (opt-in, untested).
  * **GPU yard:** Lamp sluggish (a canvas switch per light; now one per frame), music lagging (each new note made in Lua, a sample at a time, with LuaJIT's compiler off; now written through FFI, a song rendered when it starts, and `jit.on()`), OpenAL's `mmap commit error` (now `mmap = false`), Orb with no deck or sound (now run after LÖVE quits).
  * **The next update would refuse to go in place.** `debugfs write` leaves every all-zero block of a file as a hole, so the padded files on the cabinet own fewer blocks than their size. `data_patch.py --put` now fills the holes (`fallocate`). The first deploy from this tree must be `cart deploy --reinstall`; later ones are in place again.
  * **`loveprobe.sh` would miss an update** of `yard.love` (it hashed only the first 64 KiB of `love.tar.gz`). It hashes the whole archive now.
* **No loader is attached** unless a field session left one. Check `tools/rk.py state`; a timeout means a cold plug.
* **Next: [FIELD_TASKS.md](FIELD_TASKS.md) round 2** (deploy this tree with `--reinstall --with-net`, the play test, the network test with a USB-Ethernet adapter, then the SD slot alone).
* **What the field run settled (2026-10-24, verified on this cabinet unless marked):**
  * **Memory:** 118,668 kB total. With the stock menu waiting, 37 MB is available when The Yard starts. The stock menu: 53 MB anonymous + 8.6 MB file-backed.
  * **CPU runtime frame times** (`captures/love/yard.log`, draw per frame): Keep 2.2–3.2 ms, menu 7.5–8 ms, Lamp 8.1–9.3 ms, Chest 9.9–16.5 ms, Tea 12.8–22.5 ms (Tea's later scenes go past the 16.7 ms frame).
  * **GPU (Mali-400 MP, GLES 2.0, via LÖVE at 768×1024):** a full-screen shader pass costs about 16 ms, 4000 sprites 39 ms, 500 sprites 19 ms, 300 shapes 22 ms; no MSAA on canvases, no highp in fragment shaders, ETC1 textures. LuaJIT: 563 ms interpreted, 164 ms with `jit.on()` (`captures/love/love-probe.txt`).
  * **The picture:** the 2D games look soft because a 240×320 frame is stretched 3.2× and the panel then scales 1024×768 to its own 1280×1024. GPU yard, drawing at 768×1024, looked "crystal clear" to the user.
  * **USB-A is already live.** The stock tree's `usb@10180000` (`okay`, `dr_mode = "host"`) serves the USB-A port: a TP-Link AC600 (`2357:011e`, Realtek RTL8821AU) enumerated there with the switch ON. So no `boot` change is needed for USB-A, and `enable_storage.py --which adb` (that controller to `otg`) would likely take USB-A away. `usb@101c0000` stays unexplained.
  * **No Wi-Fi in the kernel** (no `cfg80211`, `mac80211`, or Wi-Fi driver names in its strings), but **USB-Ethernet drivers are there** (`r8152`, `asix`, `ax88179`, `smsc95xx`, `cdc_ether`, `rndis_host`, by name only), **`dropbear` and `adbd` are running**, root has an unknown password, and `/proc/modules` exists, so **the kernel can load modules** (verified file; no module loaded). The kernel has no embedded config (`IKCONFIG` off). The agent's "`CONFIG_...=y`" lines were string matches, not config.
  * **Linux reads the flash as `/dev/rkflash0p1..5`**, and the first four match our offline rebuild byte for byte (`captures/sysprobe/`). `data` is ext2 at `/userdata`, read-write. So a file copied in over SSH lands through the kernel's own SFTL, with no Mask ROM.
  * **The microSD card was not seen** (`dwmmc@10214000` is `disabled`), as expected. A card was made per [SDCARD.md](SDCARD.md).
* **Tea and Chest version 2** (worked out with `games/playtest.py` on 2026-10-24) are the rules in those carts. Tea adds treats on the flight that decorate the party, three asks per cat, a song after the cheer, and a photo on the wall (`tea.sav` gains `photos N`; older saves load). In Chest the sword aims itself, Zam is drawn after Alakazam and learns a teleport, a shield, and a three-bubble fan with the first three gems, and each win adds a different treasure. Specs: [games/carts/tea/DESIGN.md](games/carts/tea/DESIGN.md), [games/carts/chest/DESIGN.md](games/carts/chest/DESIGN.md).
* **Deploy audit (2026-10-24).** The chain is sound and stays: `rawdump`, then `data_patch.py` (debugfs edits, e2fsck before and after, read-back), then `sftl_patch.py` (overwrites the current physical copy of each changed 4 KiB page; SFTL's map is untouched), then a rebuild round trip, then a same-session `diff`, then an approved `rk_restore.py restore`. Two findings:
  * **New files are a risk.** One written to blocks SFTL has never stored is refused by `sftl_patch.py` ("no physical copy"), and it is refused only late in staging. Every update after the first is therefore an in-place rewrite of fixed-size files: `data_patch.py --overwrite` writes into the blocks the file already owns, found with debugfs `bmap`. `blocks` would also list indirect blocks; a test caught that. The first install reuses the blocks freed by the old binaries.
  * **Five binaries are now three files.** The pack has a crc32 per file, and the runtime drops a damaged cart and keeps the rest.

  `games/cart deploy` drives all of it and writes `PLAN.md`. `rk_restore.py`'s write logic was not touched.
* **Do not restore the whole chip** from the morning master `2026-10-23_raw_plug3032slc/nand_raw.bin` (sha256 `024af9ed…429e`). That would remove The Yard. `data` has 24.40 MiB free (24983 blocks of 1024 bytes, 7565 inodes free). Saves are one line, `best N`, and each new file costs a whole 1024-byte block. See [GAMEDEV.md](GAMEDEV.md) § 7.
* **Controls:** one stick and five play buttons. The philosophy for new games is [CONTROLS.md](CONTROLS.md). The left hand stays on the stick, the lower button is the verb, and 1-player and 2-player are how you leave. Age changes density. It does not move the verbs. A four-year-old is the little band: any direction does the one useful thing, every right-hand button does the verb, and there is no fail state.
* **Chest is on the cabinet, under Tea.** Ned walks to a key, opens a chest, and Zam tosses him a sword. Zam is tall and gold, with a long mustache past his shoulders, brown plates, and a spoon in each hand. The stick walks. The lower button, and the two buttons beside it, shoot. Nine marks add a gem in `chest.sav`. Three purple hurts restart the fight and leave the sword and the gems. The Yard row is under Tea. Spec: [games/carts/chest/DESIGN.md](games/carts/chest/DESIGN.md).
* **Tea is on the cabinet, under Orb.** A unicorn flies to a castle and takes care of Pip, Moth, and Pearl. Nib joins on the third arrival. Any stick direction moves the ring. Any right-hand button does the care. Hearts refill each visit. Gifts stay in `tea.sav`. The line in the cream band is for a grown-up to read. Spec: [games/carts/tea/DESIGN.md](games/carts/tea/DESIGN.md). The Yard row is under Orb. Keep and Lamp did not move.
* **PC checks:** `games/stress.sh` runs `games/test.py`: 110 headless checks, all passing on 2026-10-25 (96, plus 14 for the GPU runtime, which run when `games/out/love-x86` is built). Besides the games, a `system` pass attacks the sandbox and checks the pack, the deploy tools on real ext2 images (in-place updates, padded files), the supervisor with a stand-in stock menu, the templates, and the cabinet's shell scripts. `games/cart check` is the gate for one cart. See [GAMEDEV.md](GAMEDEV.md) § 8.
* **Writes** use `plug_3032slc_erase`, one 4-sector page per command, count under 32. The 32-sector hang is `bytes >> 9` counting 528-byte sectors as 33, not a NAND busy poll. Compare 2048 data bytes plus the first 8 spare bytes of sector 0. The write function returns 0 even when the page did not program, so only a read-back counts. Never write block 1023. Reads of a stock chip can use `plug_3032slc`. Copy `~/partycade-dumps/` off this PC. That is still the user's job.

## Headline

* **The whole flash is backed up and verified.** `rk.py rawdump` read all 1024 physical NAND blocks (data plus spare). Two passes matched, and a live `rk_restore.py diff` found the cabinet still identical. `tools/sftl_rebuild.py` turns that raw image into the logical disk offline. Every partition is extracted; rootfs and data both pass their filesystem checks.
* **The game list is understood.** The menu program `/usr/bin/game` (rootfs, MiniGUI) has 12 entries compiled in. For a pick it runs `/data/start.sh <index> <smoothing> <speed>`, and that shell script maps the index to an emulator binary in `/data/Games/`. Details are in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md).
* **A recovery plan exists:** [RECOVERY.md](RECOVERY.md). `plug_3032slc_erase` erases and programs past block 8, one 4-sector page at a time. Block 91 was restored and matches the backup.
* **Block 91 was erased at 13:02, then fully restored at 14:30.** It is the stale half of pair 90/91. A full diff against the morning backup lists only the SFTL-sys pages in blocks 972 and 973. Those were left alone.
* **Read-back on device 62 (2026-10-23, patched loader, cold plug).** Comparing data plus the 8-byte Rockchip spare, the only blocks that differ from the backup are 91, 972, and 973. Block 91's data and spare metadata are 0xFF on every page, so the program command did not commit a page. The other spare bytes (sector 0 bytes 8–15, and all 16 spare bytes of the other three sectors) read back as one fixed pattern on every page of every block, including blocks that were never written. The backup has 0xFF there. That pattern is not stored flash content. `diff` and the restore verify ignore it.
* **Block 91 is restored.** Device 64, same loader as the page-0 test. All 64 pages were erased, programmed, and read back against the backup. A following diff does not list block 91.
* **Both failures are now explained from the stock plug, and the busy-poll story was wrong.** The write hook ops+0x14 is `0xbf3c`. At `0xbf62` it returns success for any sector ≥ 2048 and programs nothing. It also stores `0xff` over spare word 0 at `0xbfee`, so removing only the clip would program the wrong metadata. The 32-sector hang is `0xeef4`: progress is `bytes >> 9`, and 32 × 528 bytes counts as 33 sectors, so the status packet is never sent. Counts below 32 are exact. `plug_3032slc_erase` nops `0xbf62` and `0xbfee` as well as the erase clip. Wire sha256 `53574f36b7637f55701f6a0e9aae7aec991fc3c2d326e9e9899956cd4ee8df91`. Device 64 and, later, device 66 both ran that wire. `rk_restore.py` refuses a `WRITE_SECTOR` count of 32 or more.
* **The controls probe was on tile 10, then The Yard replaced it.** The probe log and the button map are in [GAMEDEV.md](GAMEDEV.md) § 2. The picture was 90° clockwise on a 1024×768 framebuffer; `cab_present` turns new games upright. Tile 10 now runs `yard`.

## Hardware state right now

The cabinet runs the Take 2 build (2026-10-24): The Yard with eight rows. To play: switch **ON**, power only, no Micro-USB. Leaving The Yard can still stick on "LOADING..." after GPU yard; power off and on (the fix is in this tree, not on the chip). To read or write: both plugs out, switch **OFF**, then Micro-USB, and boot a fresh loader.

> [!NOTE]
> Playing the cabinet normally writes to `data` (high scores, settings). After that, the raw backup no longer matches the chip exactly: `rk_restore.py diff` will report some `data` blocks, and restoring them would roll back high scores. That is expected. Take a fresh `rawdump` before any planned flash change.

## Verified facts

| Fact | Value | Evidence |
| :--- | :--- | :--- |
| Mask ROM entry | Switch **OFF** + cold plug (both plugs out first) | Every session; [INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md) |
| Mask ROM USB | `2207:301a`, high-speed, no strings, `bcdDevice 1.00`, iface `FF/06/05`, bulk `0x81`/`0x02` | lsusb on devices 38–58 |
| Download protocol | Vendor control `0x40`/`0x0C`, index `0x471` then `0x472`, RC4 (Rockchip key) + CRC-16/CCITT, 4096-byte chunks | Devices 51, 53–58 |
| DDR init | `rk3036_ddr_396MHz_v1.11.bin` works (Rockchip uses it for RK3032 too) | Every boot since device 51 |
| SoC | RK3032 | Plug chip info `3032`; device tree `rockchip,rk3032-dongle` |
| RAM | 128 MiB at `0x60000000` | Device tree |
| Flash | SPI NAND Winbond W25N01GV, ID `EF AA 21`: 1024 blocks × 64 pages × (2048 + 64 OOB) | READ_FLASH_ID, FLASH_INFO (256-sector blocks, 4-sector pages) |
| Logical disk | 220672 sectors (107.75 MiB) served by Rockchip SFTL 5.0.55 | READ_FLASH_INFO; rebuilt offline |
| SFTL physical layout | A 4 KiB logical page = page *n* of even block 2k + page *n* of block 2k+1. Odd half's spare: u32 LPA. Even half's spare: u16 type (`0xF095` = data), u16 pair index, u32 **write sequence** (newest copy wins) | `sftl_rebuild.py` output equals `READ_LBA` data on all 65536 comparable sectors; e2fsck clean |
| Partition table | GPT: `IDBlock` 0x40+0x380, `uboot` 0x400+0x400, `boot` 0x800+0x2400, `rootfs` 0x2c00+0x20000 (64 MiB), `data` 0x22c00+0xf000 (30 MiB) | [captures/partitions.json](captures/partitions.json) |
| Factory boot block | DDR init `V1.09 20171120`, Boot1 built Dec 23 2020, SFTL 5.0.55 | Strings in `IDBlock` |
| U-Boot | `U-Boot 2017.09-g97b7efa-dirty (May 11 2023)`, `board=evb_rk3036`, `bootdelay=0`; checks the **SD card first** (`rkimgtest mmc 1`) | [captures/uboot-env.txt](captures/uboot-env.txt) |
| Kernel | Linux 4.4.194, May 11 2023, cmdline `console=ttyS2,115200 rw root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait` | `boot` partition, device tree |
| Rootfs | SquashFS 4.0, 1998 inodes, Buildroot 2018.02-rc3, glibc 2.29, ARM EABI5 **hard-float** (`/lib/ld-linux-armhf.so.3`), BusyBox init | [captures/rootfs-listing.txt](captures/rootfs-listing.txt) |
| Graphics/audio libs | SDL2 2.0.7, SDL2_image, SDL2_mixer, MiniGUI 3.2 (`libminigui_ths`), libdrm + Rockchip DRM, Mali (`libmali`, GLES1/2, EGL), ALSA | `rootfs/usr/lib` |
| Boot to menu | `inittab` → `rcS` → `S50ui`. If `/sys/devices/platform/uart-keys/test_mode` is 1 it runs `PCBA_TEST` (factory test); otherwise it runs `/usr/bin/game` | [captures/stock-scripts/](captures/stock-scripts/) |
| Menu | `/usr/bin/game`: 12 entries compiled in, artwork `/usr/local/share/minigui/res/images/game_N.jpg`, `gameN_controls.jpg`, `gameN_settings.jpg`, settings in `/userdata/Games/*.cfg` | `strings` |
| Launch | `system("/data/start.sh %d %d %d")` = index, pixel smoothing (`SDL_RENDER_SCALE_QUALITY`), speed (`1` → `-fast`); `start.sh` runs `cd /data/Games && ./<binary> [variant] [-fast]` | [captures/stock-scripts/data_start.sh](captures/stock-scripts/data_start.sh) |
| `data` partition | ext2, 30 MiB, 113 files, 5.7 MB used, ~24 MB free. Mounted at `/data`, and `/userdata` is a symlink to it. Holds `start.sh`, `Games/` (8 emulator binaries, ROMs, `.cfg`, `.sav`, `.wav`, thumbnails), `parameter`, `spk_volume` | [captures/data-partition-listing.txt](captures/data-partition-listing.txt) |
| Emulators | One SDL2 binary per hardware family: `PacMan`, `SuperPacMan`, `PacLand`, `NS1`, `Galaga`, `Galaxian`, `Mappy`, `DigDug`. Variants are selected by an argument (`p`, `d`, `r`) | `start.sh`, `readelf` |
| Network/SSH | `dropbear -R` and `adbd` run at boot. No network port exists until one is plugged in: the RK3036 EMAC is `disabled` and there is no Wi-Fi in the kernel. `ifup`/`ip`/`udhcpc`/`wget`/`scp` are present | System probe `ps` and tool list, 2026-10-24 |
| USB-A | Served by `usb@10180000` (dwc2, `okay`, `dr_mode = "host"`): a TP-Link AC600 (`2357:011e`) enumerated as `usb 1-1`, high speed, with the switch ON. `usb@101c0000` is `disabled` and its wiring is unknown | System probe dmesg, 2026-10-24 |
| Memory | 118,668 kB total; 37 MB available when The Yard starts, the stock menu holding 53 MB anon + 8.6 MB file. No swap | `yard.log`, System probe, 2026-10-24 |
| Kernel modules | `/proc/modules` exists (empty), so loadable modules are supported; no `/lib/modules`. No embedded config | System probe; `captures/kernel/config.txt` |
| Flash in Linux | `/dev/rkflash0p1..5`, all `ro 0`; p1–p4 read byte-identical to `sftl_rebuild.py`'s partitions. `data` = p5, ext2, mounted at `/userdata` | `captures/sysprobe/partition-sums.txt` |
| GPU | Mali-400 MP, OpenGL ES 2.0, texture 4096, no canvas MSAA, no fragment highp, ETC1 | `captures/love/love-probe.txt` |
| **ADB is configured** (but see USB-A) | `/etc/init.d/.usb_config` contains `usb_adb_en`, `/usr/bin/adbd` exists, and `S50usbdevice` starts adbd and binds the first UDC. No UDC exists because OTG is forced to host. **A device tree with `dr_mode = "peripheral"` (or `"otg"`) should give a root ADB shell over the Micro-USB port.** Untested lead | rootfs, device tree |
| Controls | 1-player = joystick button 6, 2-player = 7. Right of the stick: top-left = 1, top-right = 3, lower = 0. Stick and volume are buttons 15–20. See [GAMEDEV.md](GAMEDEV.md) § 2 | Probe screen, user, 2026-10-23 |
| Screen mode | KMSDRM, opengles2, 1024×768 @ 60. The probe's landscape picture was rotated 90° clockwise on the panel. The panel label is BOE `DV170YGZ-N10`, 1280×1024 | Probe log; user; cabinet label |
| Serial console | Kernel console is `ttyS2`, but uart2 is `status = "disabled"` | Device tree |
| `sdfwupdate` | Nothing in rootfs or data mentions `sdfwupdate`, `fwupdate`, or `update.img`. The SD-update risk lives only in U-Boot's `rkimgtest` | grep, 2026-10-23 |

## Plug results on this board

| Plug (`rk.py` name) | File | Result |
| :--- | :--- | :--- |
| `plug_std` | `rk303x_usbplug_v2.57.bin` | Runs. Flash ID `EMMC`, size 0. Not useful. |
| `plug_slc` | `rk303x_usbplug_slc_v2.65.bin` | Runs, then the chip resets to Mask ROM. |
| `plug_slc264` | `rk303x_usbplug_slc_v2.64.bin` | Same as `plug_slc`. |
| `plug_3032` | `rk3032_usbplug_v2.61.bin` | Works. `READ_LBA` serves only LBA < `0x10000`; starting at ≥ `0x10000` returns `0xCC`. |
| `plug_3032slc` | `rk3032_usbplug_slc_v2.63.bin` | Works. Same `READ_LBA` 32 MiB limit, but **`READ_SECTOR` (raw physical) reads the whole chip**. Used for the master backup. **Use this one for reads.** It cannot erase or program past block 8. |
| `plug_3032slc_erase` | same file, four patches in RAM | The write loader. Nops the erase clip, the write clip, and the spare-word store. Wire sha256 `53574f36…df91`. **Use this one for restore.** |

## Backups

All outside the repo in `~/partycade-dumps/`. Its `README.txt` says what each file is. The full table with hashes is in [RECOVERY.md](RECOVERY.md) § 2.

* **Master:** `2026-10-23_raw_plug3032slc/nand_raw.bin`, sha256 `024af9ed…429e`. Plus `logical_rebuilt.img` (`94568231…d377`), the five partition images, `nand_native_2112.bin` for an external programmer, `rootfs/`, `data_fs/`, and `SHA256SUMS`.
* Older: `2026-10-23_plug3032/full_lba0_220672.img`, where only the first 32 MiB are real. It's kept as the independent cross-check for `sftl_rebuild.py`.
* **Probe install:** `2026-10-23_probe_tile10/nand_raw.bin` (sha256 `acfebb7a…143d`) is the chip just before the probe. `nand_raw_patched.bin` (sha256 `e92541b7…12f9`) is what was written. `BLOCKS.txt` lists 828, 829, 872, 873, 884, 885, 892, 893.
* **After the play test:** `2026-10-23_probe_played/nand_raw.bin` (sha256 `5d8f173c…a2ad`) plus `probe.log`.
* **Field round 1 (2026-10-24):** before Take 1 `2026-10-24_love/nand_raw.bin` (`48a4fc08…d524`; written image `stage/nand_raw_patched.bin` `c4a413d4…4e40`); after Take 1's play `2026-10-24_love_played/nand_raw.bin` (`7a54af20…3adf`; Take 2's written image `stage/nand_raw_patched.bin` `33dedaff…96f3`); after Take 2's play `2026-10-24_love_take2_played/nand_raw.bin` (`24e58c36…2831`). **The last is the newest picture of the chip,** and the place to undo Take 2's 64 blocks from is `2026-10-24_love_played/nand_raw.bin`.
* **User action pending:** copy `~/partycade-dumps/` somewhere off this PC.
* **What stays out of git, on purpose.** Raw dumps, partition images, `boot.img`, the extracted rootfs and `data`, the stock binaries and libraries, and ROMs: they are Arcade1Up's and Namco's, and `.gitignore` excludes `dumps/`, `*.img`, and `*.bin` for that reason. Nothing excluded should be committed. What a cloud session needs from them is facts, and `tools/device_facts.py` writes those as small text files under `captures/` (library ABIs, kernel config and drivers, GL strings). FIELD_TASKS.md task 1 runs it.

## Open questions, in priority order

1. **Does round 2 hold on the cabinet?** The stock menu never lost again, a clean return from The Yard and GPU yard, Lamp and the music smooth on the GPU, Orb from GPU yard with deck and sound ([FIELD_TASKS.md](FIELD_TASKS.md) round 2).
2. **A network without changing the kernel.** Does a USB-Ethernet adapter on USB-A come up (`r8152` for RTL8152/8153 adapters is the likeliest), and does `yardnet` give SSH as root with our key? If yes, games and updates can be copied in over the network, and Mask ROM is only for recovery.
3. **Wi-Fi.** The kernel has no Wi-Fi stack, but loads modules. Can `cfg80211` and an RTL8821AU driver (the user's TP-Link AC600) be built as modules that this kernel accepts? That needs its vermagic and whether it checks symbol versions (`captures/kernel/modules.txt`, after the next `device_facts.py` run), and Rockchip's 4.4.194 source. Otherwise a new kernel, a `boot` write. A Pi Zero 2 W as a USB network gadget (`cdc_ether`/`rndis_host`) is a Wi-Fi bridge that needs neither.
4. **The microSD slot.** One `boot` write: `enable_storage.py --which sd` only (not `usb`, not `adb`: see the USB-A fact). Then [SDCARD.md](SDCARD.md)'s card.
5. **The GPU runtime as the main one?** It is sharper. It needs round 2's numbers (Lamp, Tea, the menu at 60 fps?) and memory: LÖVE took about 40 MB beside a 53 MB stock menu. `stock_menu stop` would answer that.
6. What are the SFTL "special" pages (odd-half LPA `0xFFFFFFFD`, even-half magic `0x12345678`, about 6 per pair)? They don't affect restore, which copies them verbatim, but they matter for any future synthesis of SFTL state.
7. What is `PCBA_TEST`, and what sets `uart-keys/test_mode`? It's a factory test mode, possibly reachable with a button combination at power-on.
