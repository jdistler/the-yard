#!/usr/bin/env python3
"""tools/home_move.py SECTION MODULE PREFIX: move a section of Home's main.lua into its own module, verbatim
(HOME_REFACTOR.md CP4).

    tools/home_move.py "actions" actions A          the section headed `-- ---- actions` -> actions.lua, used as A.x
    tools/home_move.py "actions" actions A --check  only say what would move, and what refuses

The section's text moves unchanged. Main's top-level locals that the section uses ("imports") are mirrored in the
module as locals of the same names, filled by M.init(ctx), which main calls where the section was (every import
is declared above it, or the original code could not have used it). The section's own top-level names that main
uses after it ("exports") are set as M.name, and main's uses become PREFIX.name.

Refused, because a mirror would silently go stale: an import the section assigns to; an import main assigns to
after the section; an import only declared (no value yet) where the section was. Lift those into ST first
(tools/home_lift.py). Comments, strings and table keys are left alone. Run the gates after.
"""
import os
import re
import sys

MAIN = os.environ.get("HOME_MOVE_FILE") or os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "games", "love", "home", "main.lua")
LUA_WORDS = set("and break do else elseif end false for function goto if in local nil not or repeat return then "
                "true until while self".split())


def split_comment(line):
    q, i = None, 0
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


def code_only(text):
    """The text with comments and string contents blanked (same line structure)."""
    out = []
    for line in text.split("\n"):
        code, _ = split_comment(line)
        out.append(re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', code))
    return "\n".join(out)


def top_level_names(lines):
    """{name: line index} of `local` declarations at column 0 (and `local function`); comments ignored."""
    names = {}
    for i, l in enumerate(lines):
        l = split_comment(l)[0].rstrip()
        m = re.match(r"^local function (\w+)", l)
        if m:
            names[m.group(1)] = i
            continue
        m = re.match(r"^local ([\w, ]+?)\s*(=|$)", l)
        if m:
            for n in m.group(1).split(","):
                if n.strip():
                    names[n.strip()] = i
    return names


def main():
    argv = sys.argv[1:]
    sync = [argv[i + 1] for i, a in enumerate(argv) if a == "--sync"]
    args = [a for i, a in enumerate(argv) if not a.startswith("--") and (i == 0 or argv[i - 1] != "--sync")]
    check_only = "--check" in sys.argv
    section, modname, prefix = args
    src = open(MAIN).read()
    lines = src.split("\n")
    heads = [i for i, l in enumerate(lines) if re.match(r"^-- -{10,} ", l)]
    start = next(i for i in heads if re.sub(r"^-- -+ ", "", lines[i]) == section)
    end = next((i for i in heads if i > start), len(lines))
    body = lines[start + 1:end]
    before, after = lines[:start], lines[end:]
    main_names = top_level_names(lines)
    sec_names = top_level_names(body)
    above = {n: i for n, i in top_level_names(before).items()}
    body_code = code_only("\n".join(body))
    after_code = code_only("\n".join(after))
    words = set(re.findall(r"(?<![\w.])([A-Za-z_]\w*)", body_code))
    imports = sorted(n for n in words if n in above and n not in sec_names and n not in LUA_WORDS)
    exports = sorted(n for n in sec_names if re.search(rf"(?<![\w.]){n}(?!\w)", after_code))
    def assigns(n, code):
        """Does `code` assign to the variable n (not a table key `{n = ...}`)?"""
        assign = re.compile(rf"(?<![\w.]){n}\s*(,\s*[\w.]+\s*)*=(?!=)|(?<![\w.])[\w.]+\s*,\s*{n}\s*(,\s*[\w.]+\s*)*=(?!=)")
        prev = ""
        for line in code.split("\n"):
            for m in assign.finditer(line):
                b = line[:m.start()].rstrip()
                if b.endswith(("{", ",")) and not re.match(rf"^\s*[\w.]+\s*,", line[m.start():]) or \
                        (b == "" and prev.rstrip().endswith(("{", ","))):
                    continue                      # a table key
                if re.match(r"^\s*local\b", line):
                    continue                      # a new local of that name (a shadow), not the import
                if "," in m.group(0) and not (b == "" or re.search(r"\b(then|do|else|end)$|;$", b)):
                    continue                      # `a = a, b = b` inside a table, not `a, b = ...`
                return True
            if line.strip():
                prev = line
        return False

    problems = []
    for n in imports:
        if assigns(n, body_code):
            problems.append(f"{n}: the section assigns to it (lift it into ST first)")
        if assigns(n, after_code) and n not in sync:
            problems.append(f"{n}: main assigns to it after the section (lift it into ST first, or --sync it)")
        if n in sync and assigns(n, body_code):
            problems.append(f"{n}: --sync only works for a name the section reads, and it assigns to it")
        if re.match(rf"^local ([\w, ]*[ ,])?{n}\s*$", before[above[n]]) or \
                re.match(rf"^local [\w, ]+$", before[above[n]]):
            problems.append(f"{n}: only declared above the section, no value yet (lift it into ST first)")
    for n in exports:
        decl_line = sec_names[n]
        rest = "\n".join(l for i, l in enumerate(code_only("\n".join(body)).split("\n")) if i != decl_line)
        if not re.match(rf"^local function {n}\b", body[decl_line]) and assigns(n, rest):
            problems.append(f"{n}: exported, and the section reassigns it (main would keep a stale copy): lift it into ST first")
        if assigns(n, after_code):
            problems.append(f"{n}: exported, and main assigns to it after the section: lift it into ST first")
    print(f"section '{section}': {len(body)} lines; imports {imports}; exports {exports}; synced {sync}")
    if problems:
        sys.exit("refused:\n  " + "\n  ".join(problems))
    if check_only:
        return
    # the module
    mod = [f"-- {modname}.lua: main.lua's \"{section}\" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).",
           "-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this",
           "-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its",
           "-- top-level statements run in the same order as before.",
           "local M = {}"]
    if imports:
        mod.append("local " + ", ".join(imports))
    for n in sync:
        mod.append(f"function M.sync_{n}(v) {n} = v end   -- (main assigns {n}; it hands the new value over)")
    mod.append("")
    mod.append("return function(c)")
    for i in range(0, len(imports), 6):
        chunk = imports[i:i + 6]
        mod.append(", ".join(chunk) + " = " + ", ".join(f"c.{n}" for n in chunk))
    mod.append("")
    mod.extend(body)
    mod.append("")
    for n in exports:
        mod.append(f"M.{n} = {n}")
    mod.append("return M")
    mod.append("end")
    open(os.path.join(os.path.dirname(MAIN), modname + ".lua"), "w").write("\n".join(mod) + "\n")
    # main: the section becomes the require and the init, and the exports' uses become PREFIX.name
    pairs = [f"{n} = {n}" for n in imports]
    call = [f"local {prefix} = require(\"{modname}\")({{" + ", ".join(pairs[:4]) + ("," if len(pairs) > 4 else "")]
    for i in range(4, len(pairs), 6):
        call.append("  " + ", ".join(pairs[i:i + 6]) + ("," if i + 6 < len(pairs) else ""))
    call[-1] += "})"
    new_sec = [lines[start], "", f"-- {modname}.lua (HOME_REFACTOR.md CP4)"] + call + [""]
    pat = re.compile(r"(?<![\w.])(" + "|".join(map(re.escape, exports)) + r")(?![\w])") if exports else None
    out_after = []
    stack = []
    prev = ""
    for line in after:
        code, com = split_comment(line)
        if pat:
            def sub(m, code=code, prev=prev):
                b = code[:m.start()].rstrip()
                a = code[m.end():]
                st = list(stack)
                for ch in re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', code[:m.start()]):
                    if ch in "({[":
                        st.append(ch)
                    elif ch in ")}]" and st:
                        st.pop()
                pc = split_comment(prev)[0].rstrip()
                if re.match(r"\s*=(?!=)", a) and st and st[-1] == "{" and (
                        b.endswith(("{", ",")) or (b == "" and pc.endswith(("{", ",")))):
                    return m.group(0)
                return prefix + "." + m.group(1)
            parts = re.split(r'("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')', code)
            # (offsets matter for the bracket check: substitute per part with the line as context)
            res, off = [], 0
            for p in parts:
                if p[:1] in "\"'":
                    res.append(p)
                else:
                    res.append(pat.sub(lambda m, o=off: sub(type("M", (), {
                        "start": lambda s: m.start() + o, "end": lambda s: m.end() + o,
                        "group": lambda s, i=0: m.group(i)})()), p))
                off += len(p)
            code = "".join(res)
        for ch in re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', split_comment(line)[0]):
            if ch in "({[":
                stack.append(ch)
            elif ch in ")}]" and stack:
                stack.pop()
        out_after.append(code + com)
        for n in sync:
            if assigns(n, code_only(line)):
                ind = re.match(r"^\s*", line).group(0)
                out_after.append(f"{ind}{prefix}.sync_{n}({n})")
        prev = line
    open(MAIN, "w").write("\n".join(before + new_sec + out_after))
    print(f"moved to {modname}.lua; main uses {prefix}.x for {exports}")


if __name__ == "__main__":
    main()
