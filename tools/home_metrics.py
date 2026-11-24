#!/usr/bin/env python3
"""tools/home_metrics.py: how close Home's main.lua is to LuaJIT's limits (HOME_REFACTOR.md).

LuaJIT refuses a function with more than 200 locals or 60 upvalues ("too many local variables" / "upvalues"),
so main.lua at those limits cannot grow. Read from `luajit -bl` (the bytecode listing): the register slots each
function uses (locals + temporaries, the main chunk's are its top-level locals), and the upvalues it reads.

    tools/home_metrics.py            a table; exit 1 when a limit is within the margin below
    tools/home_metrics.py --json     the numbers, for test.py
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.join(ROOT, "games", "love", "home")
LJ = os.path.join(ROOT, "games", "out", "love-x86")


def metrics(path=os.path.join(HOME, "main.lua")):
    out = subprocess.run([os.path.join(LJ, "luajit"), "-bl", path], capture_output=True, text=True,
                         env=dict(os.environ, LD_LIBRARY_PATH=os.path.join(LJ, "lib")))
    if out.returncode != 0:
        raise SystemExit(out.stderr)
    protos = re.split(r"(?m)^-- BYTECODE -- ", out.stdout)[1:]
    fns = []
    for p in protos:
        head = p.split("\n", 1)[0].strip()
        ups = set(re.findall(r"\bU(?:GET|SETV|SETS|SETN|SETP)\s+\d+\s+(\d+)", p))
        slots = [int(x) for x in re.findall(r"^\d{4}\s+(?:=>\s+)?[A-Z]+\s+(\d+)", p, re.M)]
        fns.append({"fn": head, "upvalues": len(ups), "slots": (max(slots) + 1) if slots else 0})
    main = [f for f in fns if re.search(r":0-\d+$", f["fn"])]
    rest = [f for f in fns if f not in main]
    lines = sum(1 for _ in open(path))
    # The main chunk's named locals (LuaJIT: 200): "local a, b" at column 0, outside any block.
    names = 0
    for line in open(path):
        m = re.match(r"^local function [A-Za-z_]", line)
        if m:
            names += 1
            continue
        m = re.match(r"^local ([A-Za-z_][\w, ]*?)\s*(=|$)", line)
        if m:
            names += len([n for n in m.group(1).split(",") if n.strip()])
    return {"lines": lines, "main_locals": names, "main_slots": main[0]["slots"] if main else 0,
            "max_upvalues": max(f["upvalues"] for f in rest), "max_upvalues_fn": max(rest, key=lambda f: f["upvalues"])["fn"],
            "max_slots": max(f["slots"] for f in rest), "functions": len(fns)}


def main():
    m = metrics()
    if "--json" in sys.argv:
        print(json.dumps(m))
        return
    print(f"main.lua: {m['lines']} lines, {m['functions']} functions")
    print(f"  main chunk locals {m['main_locals']} / 200 (named at the top level)")
    print(f"  main chunk slots {m['main_slots']} / 250 (locals and temporaries)")
    print(f"  most upvalues    {m['max_upvalues']} / 60 ({m['max_upvalues_fn']})")
    print(f"  most slots       {m['max_slots']} / 250 (any other function)")
    sys.exit(1 if m["main_locals"] > 190 or m["main_slots"] > 240 or m["max_upvalues"] > 56 else 0)


if __name__ == "__main__":
    main()
