# Wi-Fi for the cabinet (TP-Link AC600 on USB-A), without changing its kernel

The stock kernel (4.4.194, built May 2023 by the vendor) has no Wi-Fi at all: no `cfg80211`, no
`mac80211`, no wireless extensions. It does load modules (`/proc/modules` exists, `CONFIG_MODVERSIONS`
off, vermagic `4.4.194 SMP mod_unload ARMv7 p2v8`). So the plan is three files in `/data`, loaded by
`yardnet` when the adapter is plugged in:

| File | What it is |
| :--- | :--- |
| `cfg80211.ko` | Linux's Wi-Fi configuration layer (nl80211), from the same Rockchip tree, built as a module. Its wireless-extensions compat (`CFG80211_WEXT`) is off, because that would change `struct net`. |
| `8821au.ko` | The RTL8811AU/RTL8821AU driver ([morrownr/8821au-20210708](https://github.com/morrownr/8821au-20210708)), which lists the AC600 (`2357:011e`). Its firmware is compiled in. `8821au.patch` turns off monitor mode, P2P, TDLS, the bridge extension, and reading PHY tables from files. |
| `wpa_supplicant` | 2.11, static, nl80211 only, built-in crypto (WPA2-PSK; no EAP, no WPS, no SAE). |

`yardnet` (`../yardnet.sh`) loads them in that order, starts `wpa_supplicant` with
`/data/Games/net/wifi.conf`, and the existing DHCP loop picks up `wlan0`. A guard file
(`net/wifi.trying`) catches a start that froze or reset the cabinet; after two, it stops trying until a
new `wifi.tar.gz` or a USB stick arrives.

## Why the modules should load (and what was wrong before)

A module shares struct layouts with the kernel it loads into. The cabinet kernel's config is unknown and
its source is a vendor fork, so:

1. **The vendor's compiler.** The kernel says `gcc version 6.3.1 20170404 (Linaro GCC 6.3-2017.05)`.
   `build.sh` uses exactly that toolchain.
2. **The config, tuned against the binary.** `tools/kernel_abi.py exports` compares exported symbol
   names (which features are on); `tools/kernel_abi.py code` compares the machine code of every exported
   function. With `kernel_defconfig`, 7009 of 7152 exported functions are identical word for word; the
   rest are in drivers these modules never touch (EHCI internals, 8250 serial, HID, Mali `kbase`,
   Rockchip thermal). Getting there found what the first attempt's config (field session, 2026-10-24)
   had wrong: the cabinet kernel has **no network/user/PID namespaces, no IPv6, no LSM security hooks,
   no cgroups, no advanced IPv4 routing**, and **has keyrings**. Measured under both configs:
   `net_device`, `sk_buff`, `task_struct.comm/pid` and `usb_device` keep their offsets (alignment
   absorbs the missing `nd_net`), but `struct sock` moves (`sk_rcvbuf` 0xbc in the matched config, 0xdc in that one:
   IPv6) and so does netlink's `struct genl_info` (`user_ptr` 0x18 vs 0x1c: namespaces). `cfg80211`
   uses both, so that config could not carry it. (That attempt avoided cfg80211 with a hand-written
   wireless-extensions tunnel inside the driver, which still needed a patched or shimmed
   `wpa_supplicant`; superseded, never tested.)
3. **The cabinet's own export list.** `Module.symvers` is written from the kernel image
   (`tools/kernel_abi.py symvers`): all 7558 exports. The first attempt's list missed 74 (every exported
   variable in `.bss`, such as `kmalloc_caches`).

`build.sh` also refuses a module that needs a symbol the cabinet does not export, or has the wrong vermagic.

What is still unverified: everything, on the cabinet. Expected risks, in order: the driver's USB probe on
the dwc2 host controller; `cfg80211` regulatory (world domain without CRDA: 2.4 GHz channels 1–11 active,
5 GHz mostly passive scan); memory (about 3 MB of module code).

## Build

```bash
games/net/wifi/build.sh        # -> games/out/wifi/wifi.tar.gz (about 1.6 MB); work tree ~/wifibuild
```

## The network settings

Make the file on the PC (the key is stored as a hash, not the password):

```bash
wpa_passphrase "HOME-SSID" > wifi.conf      # then type the password
```

Either stage it with `cart deploy ... --wifi-conf wifi.conf`, or copy it to a USB stick as
`yard/wifi.conf` (see `../yardnet.sh`, stick()).
