# Hardware Specifications & Teardown Analysis

## 1. Cabinet Identification
* **Model Number:** `PAC-D-308600`
* **Article / SKU:** `1740652` (Costco Wholesale / Retail item code)
* **Serial Number:** `BSBLF-0624-032314`
  * `BSBLF`: Product series prefix (Bandai Namco Classic series)
  * `0624`: Manufacturing month/year code (June 2024)
  * `032314`: Sequential cabinet production unit
* **Wood Quality Stamp:** `BI1062024` (Factory batch QA date: June 2024)
* **Manufacturer / Licensee:** Tastemakers, LLC (Arcade1Up) / Bandai Namco Entertainment Inc.

---

## 2. Display Assembly
* **Manufacturer:** BOE Technology Group
* **Model Number:** `DV170YGZ-N10`
* **Hardware Revision:** `B10`
* **Tracking Labels:**
  * `CD170B43-01 Lead-free`
  * `CD1240503344`
  * `BBVBMNN1DPBASB7719ZV`
  * `2420 DVAS245AW50003016 0`
* **Light Guide Date Code:** `2024.5.15` (PMMA Light Guide manufactured May 15, 2024)
* **UL Certification Number:** `E508729`
* **Technical Specifications:**
  * **Screen Size:** 17.0 inches diagonal
  * **Aspect Ratio:** 5:4 (Standard arcade ratio)
  * **Native Resolution:** 1280 × 1024 pixels
  * **Display Technology:** a-Si TFT-LCD, Normally White, Transmissive
  * **Color Support:** 16.7M colors (8-bit / 6-bit + Hi-FRC)
  * **Video Interface:** 30-pin LVDS (Low-Voltage Differential Signaling) connector

---

## 3. Control Deck Interface Board
* **PCB Marking:** `GB-CON-5 V02`
* **PCB Engineering Date:** `2021.04.26` (Board thickness: `T:1.6mm`)
* **Matrix Checkmarks:**
  * Model Selector: `308600` is checked with a silkscreen mark (matching `PAC-D-308600`).
  * Date Grid: Year `2024` is marked with an `X`; Month `2` is indexed.
* **Headers & Connectors:**
  * **Main Interconnect:** 12-pin IDC ribbon cable delivering power, ground, and multiplexed/direct button signals to the mainboard.
  * **Joystick / Microswitch Connectors:** JST-XH style headers:
    * `G1-X`, `G1-Z`, `G1-B`, `G1-A` (Player 1 Directional and Button lines)
  * **Power & Volume Switches:**
    * `POWER`: Power slide switch header
    * `S1`: 3-position Volume slide switch (Off / Low / High)
  * **Unpopulated Footprint:** `TRACK BALL` (Shared tooling with Centipede/Millipede boards).

---

## 4. Main Processing Board (Inside Metal Enclosure)
* **Platform Model:** Arcade1Up `GBX70-V01` (Generation 5a)
* **Chassis:** Galvanized steel EMI/RF shield screwed to the back of the LCD panel.
"Verified" items were read from this cabinet over USB on 2026-10-23 (see [STATUS.md](STATUS.md)). The rest are RK3036-family datasheet values, not measured here.

* **System-on-Chip (SoC):** Rockchip **RK3032**, verified. The loader chip info says `3032`, the device tree says `rockchip,rk3032-dongle`, and only the RK3032 USB plug drives its flash. The USB Mask ROM ID `2207:301a` is shared with the RK3036.
  * **CPU core:** dual-core ARM Cortex-A7 (datasheet; the device tree lists `cpu@f00` with an OPP table)
  * **Architecture:** ARMv7-A with NEON and VFPv4 (datasheet)
  * **GPU:** ARM Mali-400 (datasheet; `gpu@10090000` in the device tree)
  * **Memory:** **128 MiB** DDR at `0x60000000`, verified from the device tree. The 396 MHz RK3036 DDR init trains it.
  * **Storage:** **Winbond W25N01GV**, 1 Gbit (128 MiB) SPI NAND on the SoC's SFC controller, verified (flash ID `EF AA 21`). Rockchip SFTL presents 107.75 MiB of logical sectors. **No eMMC.**
  * **Video:** VOP + LVDS (`lvds-simple-panel`) driving the BOE panel through the internal ribbon harness.
  * **Audio:** RK3032 internal codec over I2S (`rockchip,rk3032-codec`).
  * **Inputs:** a `uart-keys` driver maps the control deck to Linux key codes (see [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md)).
