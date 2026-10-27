#!/usr/bin/env python3
"""Boot tinyinit in QEMU (vexpress-a15, Cortex-A15: the stock binaries use Cortex-A7 instructions an A9 lacks) on copies of the cabinet's own system image and data partition, and
check every path: no stage2, stage2, a failing stage2, a stage2 that hangs, the try counter, "disabled", the
safe-mode keys (QEMU keys 1 and 2), and a data partition that will not mount.

  games/boot/qemu_test.py [--work DIR] [--kernel zImage --dtb dtb]

Needs qemu-system-arm, debugfs, a vexpress kernel with initrd, devtmpfs, squashfs, ext2, virtio-mmio
(~/kernel-work/kvexp, see README.md), out/initramfs-qemu.cpio, and the dumps:
  ROOT_IMG (default ~/kernel-work/qemu-test/root.img), a copy of the cabinet's rootfs partition;
  DATA_IMG (default ~/kernel-work/qemu-test/data-base.img), a copy of its data partition.
"""
import argparse, os, shutil, socket, subprocess, sys, tempfile, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
K = os.path.expanduser("~/kernel-work/kvexp/arch/arm/boot")
passes, fails = 0, []


def check(ok, what):
    global passes
    print(("  ok   " if ok else "  FAIL ") + what, flush=True)
    if ok:
        passes += 1
    else:
        fails.append(what)


def debugfs(img, *cmds):
    f = tempfile.NamedTemporaryFile("w", delete=False)
    f.write("\n".join(cmds) + "\n")
    f.close()
    r = subprocess.run(["debugfs", "-w", "-f", f.name, img], capture_output=True, text=True)
    os.unlink(f.name)
    return r.stdout + r.stderr


def cat(img, path):
    r = subprocess.run(["debugfs", "-R", f"cat {path}", img], capture_output=True, text=True)
    return r.stdout


def boot(a, data, until, seconds=90, keys=False, after=1.5):
    """Boot once; return the console text when `until` appears (or on timeout)."""
    mon = tempfile.mktemp(prefix="qmon")
    cmd = ["qemu-system-arm", "-M", "vexpress-a15", "-cpu", "cortex-a15", "-m", "256", "-nographic", "-no-reboot",
           "-kernel", a.kernel, "-dtb", a.dtb, "-initrd", os.path.join(HERE, "out", "initramfs-qemu.cpio"),
           "-append", "console=ttyAMA0 rw rootwait",
           # virtio-mmio disks enumerate last-first: the second -device is vda (the system image).
           "-drive", f"if=none,file={data},format=raw,id=d", "-device", "virtio-blk-device,drive=d",
           "-drive", f"if=none,file={a.root},format=raw,id=r,readonly=on", "-device", "virtio-blk-device,drive=r",
           "-monitor", f"unix:{mon},server,nowait"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    out = []
    if keys:
        def press():
            for _ in range(100):
                if os.path.exists(mon):
                    break
                time.sleep(0.05)
            s = socket.socket(socket.AF_UNIX)
            s.connect(mon)
            # A player presses 1 and 2 again and again while it boots (a press before the keyboard driver starts
            # is lost: the driver resets the keyboard).
            try:
                for _ in range(60):
                    s.sendall(b"sendkey 1-2 300\n")
                    time.sleep(0.5)
            except OSError:
                pass        # the VM was stopped
            s.close()
        threading.Thread(target=press, daemon=True).start()
    t0 = time.time()
    os.set_blocking(p.stdout.fileno(), False)
    buf = b""
    while time.time() - t0 < seconds and p.poll() is None:
        try:
            chunk = p.stdout.read()
        except Exception:
            chunk = None
        if chunk:
            buf += chunk
            if until.encode() in buf:
                time.sleep(after)
                try:
                    buf += p.stdout.read() or b""
                except Exception:
                    pass
                break
        else:
            time.sleep(0.1)
    p.kill()
    p.wait()
    if os.path.exists(mon):
        os.unlink(mon)
    return buf.decode("latin1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=tempfile.mkdtemp(prefix="tinyinit-"))
    ap.add_argument("--kernel", default=os.path.join(K, "zImage"))
    ap.add_argument("--dtb", default=os.path.join(K, "dts", "vexpress-v2p-ca15-tc1.dtb"))
    ap.add_argument("--root", default=os.environ.get("ROOT_IMG", os.path.expanduser("~/kernel-work/qemu-test/root.img")))
    ap.add_argument("--data", default=os.environ.get("DATA_IMG", os.path.expanduser("~/kernel-work/qemu-test/data-base.img")))
    a = ap.parse_args()
    data = os.path.join(a.work, "data.img")
    STOCK = "Starting dropbear"       # printed by the stock rcS: the stock system is running

    def fresh(stage2=None, tries=None, disabled=False):
        shutil.copy(a.data, data)
        cmds = ["mkdir boot"]
        if stage2 is not None:
            s = os.path.join(a.work, "stage2.sh")
            open(s, "w").write(stage2)
            cmds.append(f"write {s} boot/stage2.sh")
        if tries is not None:
            t = os.path.join(a.work, "tries")
            open(t, "w").write(f"{tries}\n")
            cmds.append(f"write {t} boot/tries")
        if disabled:
            open(os.path.join(a.work, "x"), "w").write("")
            cmds.append(f"write {os.path.join(a.work, 'x')} boot/disabled")
        debugfs(data, *cmds)

    good = ('echo "<5>stage2-test: ran, pid $$, tries $(cat /userdata/boot/tries)" > /dev/kmsg\n'
            'echo stage2 > /userdata/boot/ran\nsync\n')
    print("== no stage2: the stock boot", flush=True)
    fresh()
    out = boot(a, data, STOCK)
    check("yardinit: the stock boot" in out and STOCK in out and "Kernel panic" not in out,
          "without stage2.sh the stock system boots")
    print("== stage2", flush=True)
    fresh(good)
    out = boot(a, data, STOCK)
    check("stage2-test: ran" in out and "yardinit: stage2 done" in out and STOCK in out,
          "stage2.sh runs (as a child, not pid 1), then the stock system boots")
    check(cat(data, "boot/tries").strip() == "1" and cat(data, "boot/ran").strip() == "stage2",
          "the try is counted, and stage2 could write to the data partition")
    print("== a failing stage2", flush=True)
    fresh("exit 3\n")
    out = boot(a, data, STOCK)
    check("stage2 failed (the boot goes on)" in out and STOCK in out and "Kernel panic" not in out,
          "a stage2 that fails cannot stop the boot")
    print("== a stage2 that hangs", flush=True)
    fresh("echo \"<5>stage2-test: hanging\" > /dev/kmsg\nwhile :; do sleep 1; done\n")
    out = boot(a, data, STOCK, seconds=120)
    check("stage2 took too long: stopped" in out and STOCK in out, "a stage2 that hangs is stopped after the limit")
    print("== the try counter", flush=True)
    fresh(good, tries=3)
    out = boot(a, data, STOCK)
    check("stage2 skipped" in out and "stage2-test: ran" not in out and STOCK in out,
          "after 3 counted tries stage2 is skipped")
    print("== disabled", flush=True)
    fresh(good, disabled=True)
    out = boot(a, data, STOCK)
    check("stage2-test: ran" not in out and "yardinit: the stock boot" in out, "boot/disabled skips stage2")
    print("== safe-mode keys", flush=True)
    fresh(good)
    out = boot(a, data, STOCK, keys=True)
    check("held: the stock boot" in out and "stage2-test: ran" not in out and STOCK in out,
          "holding the two keys at power-on skips stage2")
    print("== a data partition that does not mount", flush=True)
    open(data, "wb").write(b"\0" * (1 << 20))
    out = boot(a, data, STOCK)
    check("could not mount the data partition" in out and STOCK in out,
          "a broken data partition still boots the stock system")
    print("== the real stage2.sh", flush=True)
    fresh(open(os.path.join(HERE, "stage2.sh")).read())
    out = boot(a, data, STOCK, after=5)
    log = cat(data, "boot/boot.log")
    check("yardinit: stage2 done" in out and STOCK in out and "stage2 v2 at" in log and "at ? s" not in log
          and "stage2: waiting for the stock boot" in out,
          "games/boot/stage2.sh runs, logs, leaves its waiting job, and the stock system boots")
    # The rest (yardnet, the health mark) needs the stock boot to mount /userdata, which it does by partition
    # name (udev, the cabinet's flash): not in QEMU. Verified on the cabinet's first boot instead.

    def with_home(off=False):
        fresh(open(os.path.join(HERE, "stage2.sh")).read())
        games = os.path.dirname(HERE)
        files = {"boot/S50ui": os.path.join(HERE, "S50ui"),
                 "home/homeloop": os.path.join(games, "love", "home", "homeloop.sh")}
        love = os.path.join(a.work, "home.love")
        open(love, "w").write("stand-in")
        files["home/home.love"] = love
        cmds = ["mkdir home"]
        for dst, src in files.items():
            cmds.append(f"write {src} {dst}")
            if dst != "home/home.love":
                cmds.append(f"set_inode_field {dst} mode 0100755")
        if off:
            open(os.path.join(a.work, "x"), "w").write("")
            cmds.append(f"write {os.path.join(a.work, 'x')} boot/home-off")
        debugfs(data, *cmds)

    print("== Home at power-on (stage2 v2 binds S50ui)", flush=True)
    with_home()
    out = boot(a, data, "Starting ui", after=4)
    log = cat(data, "boot/boot.log")
    check("Home at power-on" in out and "Starting ui (Partycade Home)" in out and "S50ui bound" in log,
          "stage2 binds games/boot/S50ui over the stock one, and the stock rcS runs it")
    check("Kernel panic" not in out and STOCK in out, "the rest of the stock boot is unchanged")
    print("== Home switched off (boot/home-off)", flush=True)
    with_home(off=True)
    out = boot(a, data, "Starting ui", after=3)
    check("Starting ui: " in out and "Partycade Home" not in out and "stage2 v2 at" in cat(data, "boot/boot.log"),
          "with boot/home-off, stage2 still runs and the stock S50ui starts the stock menu")
    print("== safe-mode keys with Home installed", flush=True)
    with_home()
    out = boot(a, data, "Starting ui", keys=True, after=3)
    check("held: the stock boot" in out and "Partycade Home" not in out and "Starting ui: " in out,
          "holding the two keys at power-on gives the stock menu, Home or not")
    print(f"== {passes} passed, {len(fails)} failed ==")
    for f in fails:
        print("  FAIL", f)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
