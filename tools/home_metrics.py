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
    # Globals main.lua writes (GSET): LÖVE's callbacks and the few meant to be shared; anything else is a local
    # that lost its declaration (a refactor slip: the code reads one variable and writes another).
    gsets = sorted(set(re.findall(r'GSET\s+\d+\s+\d+\s+;\s+"(\w+)"', out.stdout)))
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
    return {"lines": lines, "main_locals": names, "globals": gsets, "module_globals": module_globals(), "main_slots": main[0]["slots"] if main else 0,
            "max_upvalues": max(f["upvalues"] for f in rest), "max_upvalues_fn": max(rest, key=lambda f: f["upvalues"])["fn"],
            "max_slots": max(f["slots"] for f in rest), "functions": len(fns)}


# The modules made by the refactor (HOME_REFACTOR.md): they may touch only Lua's and LÖVE's globals. Anything else
# is a name main.lua passes in that the module forgot to mirror (a nil at run time, or a stray global).
MODULES = ["draw", "input", "pictures", "actions", "catalog", "idle", "menu", "homestate", "cards", "ticks", "diag", "scenes"]
STD = set("assert collectgarbage error getmetatable ipairs next pairs pcall print rawequal rawget rawlen rawset "
          "require select setmetatable tonumber tostring type unpack xpcall setfenv getfenv loadstring load "
          "io math os string table coroutine debug jit bit love home_note arg _G".split())


def module_globals():
    bad = {}
    for m in MODULES:
        path = os.path.join(HOME, m + ".lua")
        if not os.path.exists(path):
            continue
        out = subprocess.run([os.path.join(LJ, "luajit"), "-bl", path], capture_output=True, text=True,
                             env=dict(os.environ, LD_LIBRARY_PATH=os.path.join(LJ, "lib"))).stdout
        names = set(re.findall(r'G(?:GET|SET)\s+\d+\s+\d+\s+;\s+"(\w+)"', out))
        extra = sorted(names - STD)
        if extra:
            bad[m] = extra
    return bad


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
    print(f"  globals written  {', '.join(m['globals']) or 'none'}")
    print(f"  modules' stray globals {m['module_globals'] or 'none'}")
    sys.exit(1 if m["main_locals"] > 190 or m["main_slots"] > 240 or m["max_upvalues"] > 56 else 0)


if __name__ == "__main__":
    main()
