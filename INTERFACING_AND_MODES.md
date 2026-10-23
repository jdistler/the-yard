# Interfacing, Ports & Operating Modes

## 1. Port Layout & Electrical Characteristics

The mainboard is housed in a galvanized steel shield mounted to the back of the LCD. The top and side edges feature the following I/O:

```text
+--------------------------------------------------------------------------+
|  [DC 12V In] [Micro-USB]       [USB-A Host]    [Audio Out]       [Switch] |
|   (Barrel)      (OTG)           (Standard)      (Aux Pin)          (NC)   |
|                                                                          |
|                                                                          |
|  (Light) (Micro-SD)                                                      |
+--------------------------------------------------------------------------+
```

### Detailed Port Breakdown:
1. **DC 12V Barrel Jack (Left):**
   * Center-positive 12V DC input from the wall power adapter.
   * Powers the main board logic, audio power amplifier, and the 12V backlight inverter for the 17" BOE display.
2. **Micro-USB OTG Port:**
   * Directly connected to the Rockchip USB 2.0 OTG controller (`dwc2`).
   * **Electrical Note (5V Back-Feeding):** The 5V VBUS pin from the Micro-USB port connects to the internal 5V/3.3V power rails through a protection diode. Connecting a PC via USB will supply power to the CPU logic and status LEDs even without the 12V barrel plug attached.
   * *Limitation:* 5V USB cannot power the 17" LCD backlight or audio amp (12V is mandatory for display operation).
3. **USB-A Host Port (Center):**
   * Standard USB 2.0 host connector used for factory diagnostic scripts, external peripherals, or USB-based firmware patches.
4. **Auxiliary / Audio Output Port (Right):**
   * Stamped with a speaker/audio icon. Used for external amplified speaker connections or accessory power on specific cabinet revisions.
5. **Slide Switch (Far Right, Stamped "NC"):**
   * Two-position hardware boot/recovery mode switch. Directly controls the BootROM strap pin of the Rockchip SoC.
6. **Stamped Icons (Bottom Left):**
   * Light bulb icon: Marks the marquee LED connector area.
   * Micro-SD card icon: a microSD slot is present and empty (user, 2026-10-23). Whether U-Boot or Linux can see it is still open: the stock Linux device tree disables every MMC controller. See [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) § U-Boot.

---

## 2. Hardware Operating Modes

The board operates in two distinct states depending on the position of the slide switch upon power-up:

### State A: Normal Game Mode (Switch ON)
* **Screen State:** 17" BOE display turns on with sound; Pac-Man 12-in-1 frontend boots.
* **Boot Chain (verified from the flash dump):** BootROM → Rockchip boot block (DDR init + Boot1, on SPI NAND) → U-Boot 2017.09 → Linux 4.4.194 (`zImage`, Android boot image) → SquashFS rootfs → game launcher (not yet identified). Details are in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md).
* **USB Behavior:** The device tree sets the OTG controller to `dr_mode = "host"` (verified). A PC connected in this state sees no device, because the board is acting as a host.
* **Boot Logs:** U-Boot's console is uart2 at 115200. The kernel's console also points at `ttyS2`, but uart2 is `disabled` in the kernel device tree, so the UART pads may go quiet once Linux starts.

### State B: Mask ROM Mode (Switch OFF)
* **Switch position:** The two-position slide switch on the back of the metal shield, stamped "NC". **OFF** is Mask ROM. **ON** is normal game mode. The label describes the switch lever, not a separate power control. The control-deck `POWER` switch is a different part.
* **Screen State:** Pitch black. Backlight and audio remain uninitialized.
* **Boot Chain:** The CPU bypasses the internal flash memory and executes code exclusively from the internal read-only silicon BootROM.
* **USB Behavior:** The chip enumerates as an active USB slave device:
  ```text
  Bus 001 Device 038: ID 2207:301a Fuzhou Rockchip Electronics Company RK3036 in Mask ROM mode
  ```
  Verified 2026-10-23 on this OptiPlex: high-speed USB 2.0, `bcdDevice 1.00`, no manufacturer/product/serial strings, bus-powered 400 mA. The same ID appeared earlier that morning as device 37 on port `1-11`, then again at 10:23:31 as device 38 on port `1-6` after the procedure below.
* **USB Endpoints:**
  * Endpoint `0x81` (EP 1 IN) - Bulk Transfer, 512 bytes packet size
  * Endpoint `0x02` (EP 2 OUT) - Bulk Transfer, 512 bytes packet size
  * Interface 0 is vendor-specific: class `0xFF`, subclass `6`, protocol `5`.

### Entering Mask ROM Mode (verified 2026-10-23)
> [!IMPORTANT]
> The Rockchip BootROM only samples the boot mode pins during a **cold reset from 0 Volts**.
> The Micro-USB cable back-powers the CPU with 5V, so flipping the slide switch while the USB cable is plugged in does **not** change the operating state. With the switch left in **ON**, this PC sees no USB device at all: the OTG port comes up as a host, and a host does not enumerate here.

Do this in order. Both plugs have to be out before the switch moves.

1. Unplug the 12V barrel plug.
2. Unplug the Micro-USB cable.
3. Move the slide switch on the back of the metal shield to **OFF**.
4. Plug in the 12V barrel plug.
5. Plug in the Micro-USB cable.

The screen stays dark. Within about a second of the USB plug seating, the host should show `2207:301a`. If it does not, both plugs were not actually out when the switch moved, or the cable has no data wires. Pull both plugs, pause a few seconds so the board capacitors can drop to 0V, and repeat from step 3.

**Host cable and port used for the verified connection:**

* This machine: the USB-A port labeled **SS**, blue interior (USB 3.x SuperSpeed). The Rockchip came up on xHCI port `1-6`.
* Cable: USB-C to USB-A, with the USB-A end in that SS port. The cabinet side is the Micro-USB OTG jack on the metal shield.
* The blue SS port does not change the mode. The RK3032 BootROM (it reports itself with the RK3036 USB ID) is USB 2.0 only and uses the USB 2.0 D+/D− pair inside the SuperSpeed connector. It still enumerates at high-speed, 480 Mbps, with 512-byte bulk packets. Any data-capable port on this machine is fine; the SS label is not required. A charge-only cable produces the same silence as the switch being left ON.

> [!IMPORTANT]
> A USB bus reset from the PC does **not** revive this BootROM. On 2026-10-23, `libusb` port resets were answered at first, and then the chip stopped answering setup packets (`device descriptor read/64, error -110`) until the cable and barrel were both removed. Recovery is the same five steps above. Leave the switch **OFF** while doing it.

---

## 3. Communication & Interfacing

### A. USB Mask ROM Interface

Use `tools/rk.py` ([tools/README.md](tools/README.md)) rather than ad-hoc scripts. It handles the RC4-encrypted DDR and USB-plug download, the read-only bulk commands, and the safety checks.

What happens on the wire:

1. The BootROM (`2207:301a`, no USB strings) only accepts control-pipe downloads: vendor request `0x40`/`0x0C`, index `0x471` (DDR init into SRAM), then `0x472` (USB plug into DRAM). Bulk endpoints don't answer at this stage. A bulk command returns `EPROTO`, which is normal.
2. After the plug starts, the device disconnects and re-enumerates with strings `RockChip` / `USB-MSC` / `rockchip`, still `2207:301a`. Now the bulk endpoints speak Rockchip's CBW/CSW command protocol (chip info, flash info, read LBA).
3. On this board the working plug is `rk3032_usbplug_v2.61.bin` (`rk.py` name `plug_3032`).

Never issue a USB port reset, `SET_CONFIGURATION` loops, or retries after a timeout against the BootROM. It wedges until a cold plug. See [RUNBOOK.md](RUNBOOK.md) § Hard rules.

### B. Hardware UART (Serial Console)
For real-time diagnostic output during the normal boot sequence:
* **Location:** Three circular test pads labeled `TX`, `RX`, and `GND` located on the PCB inside the metal shielding box.
* **Logic Level:** **3.3V TTL** (Do not connect 5V UART signals directly to avoid damaging the SoC).
* **Baud Rate:** **115,200** 8N1 is expected. The U-Boot env has `baudrate=115200` and the kernel cmdline has `console=ttyS2,115200`. Rockchip's 1.5 Mbaud default doesn't apply to this build. Not yet verified on the pads.
* **What it gives you:** U-Boot output, plus the U-Boot hotkeys (Ctrl+C for a shell, Ctrl+D for rockusb download mode), which are useful for checking whether U-Boot sees the SD slot (`mmc list`; see [RUNBOOK.md](RUNBOOK.md) Phase 4). They are no longer needed for reading the flash, because `rk.py rawdump` reads all of it over USB. The kernel may print nothing, since uart2 is disabled in its device tree.
* **Access:** the pads are inside the metal shield, behind the cover, which hasn't been removed as of 2026-10-23.
* **Wiring:**
  * USB-UART Adapter `GND` → Board `GND`
  * USB-UART Adapter `RX`  → Board `TX`
  * USB-UART Adapter `TX`  → Board `RX`
  * *(Leave VCC disconnected).*
