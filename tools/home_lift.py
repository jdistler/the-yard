#!/usr/bin/env python3
"""tools/home_lift.py NAME...: move top-level locals of Home's main.lua into the ST table (HOME_REFACTOR.md CP3).

Every use becomes ST.NAME; the declaration `local a, b = x, y` becomes `ST.a, ST.b = x, y` (a declaration that also
names other variables is refused, to be split by hand). Comments, strings and table keys (`{name = ...}`, also at
the start of a line in a multi-line constructor) are left alone. A NAME that is declared again inside a function, a
parameter, a loop variable, or already a field of ST is refused: renaming those would change which variable code
reads. Run the gates after (the tour, the Home tests, the metrics).
"""
import os
import re
import sys

MAIN = os.environ.get("HOME_LIFT_FILE") or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "games", "love", "home", "main.lua")


def split_comment(line):
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif line.startswith("--", i):
            return line[:i], line[i:]
        i += 1
    return line, ""


def main():
    names = sys.argv[1:]
    src = open(MAIN).read()
    lines = src.split("\n")
    bad = []
    for n in names:
        tops = [i for i, l in enumerate(lines) if re.match(rf"^local ([\w, ]*[ ,])?{n}( |,|$)", l)]
        if len(tops) != 1:
            bad.append(f"{n}: {len(tops)} top-level declarations")
            continue
        decl = re.match(r"^local ([\w, ]+?)\s*(=|$)", lines[tops[0]])
        declared = [x.strip() for x in decl.group(1).split(",")] if decl else []
        if any(x not in names for x in declared):
            bad.append(f"{n}: declared with {declared}: split it by hand")
        shadow = [i + 1 for i, l in enumerate(lines) if i != tops[0] and (
            re.match(rf"^\s+local ([\w, ]*[ ,])?{n}( |,|=|$)", l) or
            re.search(rf"function[^(]*\(([^)]*[ ,])?{n}[,)]", l) or re.search(rf"\bfor ([\w, ]*[ ,])?{n}( |,)", l))]
        if shadow:
            bad.append(f"{n}: shadowed at lines {shadow}")
        if re.search(rf"\bST\.{n}\b", src):
            bad.append(f"{n}: ST.{n} already exists")
    if bad:
        sys.exit("refused:\n  " + "\n  ".join(bad))
    pat = re.compile(r"(?<![\w.])(" + "|".join(map(re.escape, names)) + r")(?![\w])")
    out = []
    prev = ""
    stack = []   # the brackets open at the start of this line, across lines: "{" means `name =` is a table key
    for line in lines:
        code, com = split_comment(line)
        dm = re.match(r"^local ([\w, ]+?)(\s*=.*|\s*)$", code)
        if dm and all(x.strip() in names for x in dm.group(1).split(",")):
            targets = ", ".join("ST." + x.strip() for x in dm.group(1).split(","))
            if "=" not in dm.group(2):   # `local a` with no value: ST.a starts as nil already
                out.append(com.strip() and ("-- (" + targets + ") " + com) or "")
                prev = line
                continue
            out.append(targets + dm.group(2) + com)   # (the values are left as they are)
            prev = line
            continue

        def opener_at(pos):
            st = list(stack)
            for ch in re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', code[:pos]):
                if ch in "({[":
                    st.append(ch)
                elif ch in ")}]" and st:
                    st.pop()
            return st[-1] if st else None

        def sub(m):
            before = code[:m.start()].rstrip()
            after = code[m.end():]
            if re.match(r"\s*=(?!=)", after) and (before.endswith(("{", ",")) or before == "") \
                    and opener_at(m.start()) == "{":
                return m.group(0)              # a table key
            return "ST." + m.group(1)
        parts = re.split(r'("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')', code)
        offs, newp = 0, []
        for p in parts:
            if p[:1] in "\"'":
                newp.append(p)
            else:
                newp.append(pat.sub(lambda m, o=offs: sub(type("M", (), {"start": lambda self: m.start() + o,
                                                                          "end": lambda self: m.end() + o,
                                                                          "group": lambda self, i=0: m.group(i)})()), p))
            offs += len(p)
        out.append("".join(newp) + com)
        for ch in re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', code):
            if ch in "({[":
                stack.append(ch)
            elif ch in ")}]" and stack:
                stack.pop()
        prev = line
    open(MAIN, "w").write("\n".join(out))
    print(f"lifted into ST: {', '.join(names)}")


if __name__ == "__main__":
    main()
