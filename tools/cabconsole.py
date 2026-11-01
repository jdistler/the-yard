#!/usr/bin/env python3
"""The cabinet's U-Boot console (uart2, 3.3 V) through the microSD slot: the slot's DAT0/DAT1 pins are uart2's
TX/RX on the RK3032 (GPIO1_C2/C3, function 2), so a microSD test board in the slot and a USB-serial adapter
reach it with the shield on (BOOT_RESEARCH.md, 2026-11-01).

  tools/cabconsole.py [--port /dev/ttyUSB0] [--baud 115200] [--log FILE]

Every byte received is appended to FILE (default logs/console-<date>.log) with a timestamp per line, and printed.
To type into the console from another shell: echo -n 'text' > FILE.in (a FIFO this makes); '^C' and '^D' in
that text are sent as Ctrl+C / Ctrl+D. Run with the cabinet's power off; switch it on once this is listening.
"""
import argparse, os, select, sys, time

import serial

ap = argparse.ArgumentParser()
ap.add_argument("--port", default="/dev/ttyUSB0")
ap.add_argument("--baud", type=int, default=115200)
ap.add_argument("--log")
a = ap.parse_args()
here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = a.log or os.path.join(here, "logs", time.strftime("console-%Y%m%d-%H%M%S.log"))
os.makedirs(os.path.dirname(log), exist_ok=True)
fifo = log + ".in"
if not os.path.exists(fifo):
    os.mkfifo(fifo)
def connect():
    while True:
        try:
            return serial.Serial(a.port, a.baud, timeout=0)
        except (serial.SerialException, OSError):
            time.sleep(0.3)


s = connect()
fin = os.open(fifo, os.O_RDONLY | os.O_NONBLOCK)
out = open(log, "a", buffering=1)
print(f"listening on {a.port} at {a.baud}; log {log}; input {fifo}", flush=True)
line = b""
t0 = time.time()
while True:
    r, _, _ = select.select([s.fileno(), fin], [], [], 0.5)
    if not r and line:
        # A prompt ("=> ") has no newline: show it after a quiet half second.
        stamp = f"{time.time() - t0:8.3f} {line.decode('utf-8', 'replace')}"
        out.write(stamp + "\n")
        print(stamp, flush=True)
        line = b""
    if s.fileno() in r:
        try:
            data = s.read(4096)
        except (serial.SerialException, OSError):
            # The adapter went away (unplugged, bumped): wait for it and carry on.
            print("adapter disconnected; waiting for it", flush=True)
            s.close()
            time.sleep(0.5)
            s = connect()
            print("adapter back", flush=True)
            continue
        for b in data:
            if b in (10, 13):
                if line:
                    text = line.decode("utf-8", "replace")
                    stamp = f"{time.time() - t0:8.3f} {text}"
                    out.write(stamp + "\n")
                    print(stamp, flush=True)
                line = b""
            else:
                line += bytes([b])
    if fin in r:
        cmd = os.read(fin, 4096)
        if not cmd:
            os.close(fin)
            fin = os.open(fifo, os.O_RDONLY | os.O_NONBLOCK)
            continue
        cmd = cmd.replace(b"^C", b"\x03").replace(b"^D", b"\x04")
        s.write(cmd)
        out.write(f"{time.time() - t0:8.3f} >>> {cmd!r}\n")
