#!/usr/bin/env python3
"""The sounds holdwatch plays while a classic's exit button is held (games/love/home/holdwatch.c).

  home_sfx.py OUT_DIR     hold1..hold4.wav (soft blips, rising), holdgo.wav (a little arpeggio up)

44.1 kHz stereo 16-bit, the format the cabinet's dmix runs at (no resampling). The same voice as Home's
synth (sound.lua): a triangle with a short attack and a decay.
"""
import math
import os
import struct
import sys
import wave

RATE = 44100


def tone(notes, dur, vol=0.35):
    n = int(dur * RATE)
    acc = [0.0] * n
    for midi, start, length in notes:
        hz = 440 * 2 ** ((midi - 69) / 12)
        s0, ln = int(start * RATE), int(length * RATE)
        for i in range(ln):
            k = s0 + i
            if k >= n:
                break
            ph = (i * hz / RATE) % 1
            v = ph * 4 - 1 if ph < 0.5 else 3 - ph * 4
            env = min(1, i / 300) * (1 - i / ln) ** 1.8
            acc[k] += v * env * vol
    return acc


def save(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in samples:
            s = int(max(-1, min(1, v)) * 32767)
            frames += struct.pack("<hh", s, s)
        w.writeframes(bytes(frames))


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for i, midi in enumerate((72, 76, 79, 83), start=1):          # C5 E5 G5 B5: climbing toward home
        save(os.path.join(out, f"hold{i}.wav"), tone([(midi, 0, 0.09), (midi + 12, 0, 0.05)], 0.12))
    save(os.path.join(out, "holdgo.wav"),
         tone([(84, 0, 0.08), (88, 0.06, 0.08), (91, 0.12, 0.08), (96, 0.18, 0.3)], 0.5, 0.3))
    print(out)


if __name__ == "__main__":
    main()
