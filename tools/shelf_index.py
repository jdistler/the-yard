#!/usr/bin/env python3
"""Index the Shelf's library for Home: titles, years, makers and box art, written onto the card.

    tools/shelf_index.py [LIBRARY]        default ~/partycade-card/library (the card's library/ as staged here)

Writes LIBRARY/index.tsv, one game a line:
    system  file  title  year  maker  art  tags  blurb  labels
and LIBRARY/art/<system>/<file stem>.png, each picture fitted to the browser's tile (ART_W x ART_H).

Titles: a console game's is its file name (the library uses clean names: "Super Mario World.sfc"); an
arcade set's is MAME 2000's own description of it, from that core's driver list (the version on the
cabinet's squashfs), with the region in brackets dropped. games/shelf/curation.tsv adds a year, a maker, a
one-line blurb, tags (party, two, solo, long) and per-game button names, by hand.

Art: libretro-thumbnails (https://github.com/libretro-thumbnails), boxarts for consoles and title screens for
arcade boards, matched by normalised name and region preference (USA, World, Europe, Japan; no betas, hacks
or prototypes). Downloads are cached in ~/partycade-build/thumbs. A game with no match gets no art (the
browser draws its title on a tile).
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
LIB = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/partycade-card/library")
CACHE = os.path.expanduser("~/partycade-build/thumbs")
MAME_SRC = os.path.expanduser("~/partycade-build/src/mame2000-libretro/src/drivers")
CURATION = os.path.join(REPO, "games", "shelf", "curation.tsv")
ART_W, ART_H = 180, 240

# system -> (extensions, thumbnails repo, picture kind)
SYSTEMS = {
    "nes": ((".nes",), "Nintendo_-_Nintendo_Entertainment_System", "Named_Boxarts"),
    "snes": ((".sfc", ".smc"), "Nintendo_-_Super_Nintendo_Entertainment_System", "Named_Boxarts"),
    "gb": ((".gb", ".gbc"), None, "Named_Boxarts"),  # by extension: Game Boy or Game Boy Color
    "gba": ((".gba",), "Nintendo_-_Game_Boy_Advance", "Named_Boxarts"),
    "genesis": ((".md", ".gen", ".bin", ".smd"), "Sega_-_Mega_Drive_-_Genesis", "Named_Boxarts"),
    "sms": ((".sms",), "Sega_-_Master_System_-_Mark_III", "Named_Boxarts"),
    "gg": ((".gg",), "Sega_-_Game_Gear", "Named_Boxarts"),
    "sg": ((".sg",), "Sega_-_SG-1000", "Named_Boxarts"),
    "pce": ((".pce",), "NEC_-_PC_Engine_-_TurboGrafx_16", "Named_Boxarts"),
    "ngp": ((".ngp", ".ngc"), "SNK_-_Neo_Geo_Pocket_Color", "Named_Boxarts"),
    "arcade": ((".zip",), "MAME", "Named_Titles"),
}
GB_REPOS = {".gb": "Nintendo_-_Game_Boy", ".gbc": "Nintendo_-_Game_Boy_Color"}
# Test programs on the card (samples/): not games, never listed.
HIDE = re.compile(r"240p|testsuite|suitesg|decktest", re.I)


def get(url, path):
    if os.path.exists(path):
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with urllib.request.urlopen(url, timeout=30) as r, open(path + ".tmp", "wb") as f:
            f.write(r.read())
        os.rename(path + ".tmp", path)
        return path
    except Exception as e:  # a missing picture is a tile with a title
        print(f"  fetch failed {url}: {e}", file=sys.stderr)
        return None


def tree(repo):
    path = os.path.join(CACHE, repo, "tree.json")
    if not get(f"https://api.github.com/repos/libretro-thumbnails/{repo}/git/trees/master?recursive=1", path):
        return []
    return [t["path"] for t in json.load(open(path))["tree"] if t["type"] == "blob"]


def norm(s):
    s = s.lower()
    s = re.sub(r"\(.*?\)|\[.*?\]", " ", s)
    # "&" is "_" in libretro-thumbnails' file names, and "and" in ours: drop all three.
    s = re.sub(r"&|_|\band\b", " ", s)
    s = re.sub(r"^the |, the\b", " ", s)
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s


BAD = re.compile(r"redux|translat|\((beta|proto|demo|sample|pirate|unl|hack|aftermarket|program)|\[[hbt]|\(rev|virtual console|"
                 r"playchoice|vs\.|collection|classic mini|switch online", re.I)
REGION = [("(usa", 0), ("(world", 1), ("(usa, europe", 0), ("(europe", 2), ("(japan", 3)]


def pick(title, names, exact=False):
    """The best thumbnail for a title among names ("Named_Boxarts/<name>.png"). exact: no prefix or substring
    matches (arcade: "Donkey Kong" must not find "Donkey Kong Junior")."""
    want = norm(title)
    best = None
    for n in names:
        stem = os.path.splitext(os.path.basename(n))[0]
        have = norm(stem)
        # Exact, else the title as the start of a longer one ("Castlevania III" -> "... - Dracula's Curse"),
        # else inside one ("Zelda Links Awakening" -> "Legend of Zelda, The - Link's Awakening").
        if have == want:
            tier = 0
        elif exact:
            continue
        elif len(want) >= 6 and have.startswith(want):
            tier = 1
        elif len(want) >= 8 and want in have:
            tier = 2
        else:
            continue
        region = 10
        for tag, rank in REGION:
            if tag in stem.lower():
                region = min(region, rank)
        score = tier * 100 + region
        if BAD.search(stem):
            score += 20
        if best is None or score < best[0] or (score == best[0] and len(stem) < len(best[1])):
            best = (score, n)
    return best and best[1]


def mame_games():
    """MAME 2000's sets: name -> (description, year, maker, rotation)."""
    out = {}
    pat = re.compile(r'^GAMEX?\(\s*([0-9?]+)\s*,\s*(\w+)\s*,\s*\w+\s*,\s*\w+\s*,\s*\w+\s*,\s*\w+\s*,\s*(\w+)\s*,'
                     r'\s*"([^"]*)"\s*,\s*"([^"]*)"')
    for fn in sorted(os.listdir(MAME_SRC)):
        if fn.endswith(".c"):
            for line in open(os.path.join(MAME_SRC, fn), errors="replace"):
                m = pat.match(line)
                if m:
                    year, name, rot, maker, desc = m.groups()
                    out[name] = (desc, year, maker, rot)
    return out


def curation():
    out = {}
    if os.path.exists(CURATION):
        for line in open(CURATION):
            if line.startswith("#") or not line.strip():
                continue
            f = line.rstrip("\n").split("\t")
            f += [""] * (8 - len(f))
            sysid, stem, year, maker, tags, blurb, labels, alias = f[:8]
            out[(sysid, stem)] = {"year": year, "maker": maker, "tags": tags, "blurb": blurb, "labels": labels,
                                  "alias": alias}
    return out


def fit_art(src, dst):
    im = Image.open(src).convert("RGB")
    im.thumbnail((ART_W, ART_H), Image.LANCZOS)
    canvas = Image.new("RGB", (im.width, im.height))
    canvas.paste(im)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    canvas.save(dst, optimize=True)


def main():
    mame = mame_games() if os.path.isdir(MAME_SRC) else {}
    cur = curation()
    trees = {}
    rows = []
    missing = []
    for sysid, (exts, repo, kind) in SYSTEMS.items():
        d = os.path.join(LIB, sysid)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d), key=str.lower):
            stem, ext = os.path.splitext(fn)
            if ext.lower() not in exts or fn.startswith(".") or HIDE.search(fn):
                continue
            year = maker = ""
            c = cur.get((sysid, stem), {})
            if "hide" in c.get("tags", "").split():
                continue
            if sysid == "arcade":
                desc, year, maker, _ = mame.get(stem, (stem, "", "", ""))
                title = re.sub(r"\s*\(.*?\)\s*", " ", desc).strip()
                lookup = desc
            else:
                title = stem.replace("_", " ")
                lookup = title
            r = GB_REPOS[ext.lower()] if sysid == "gb" else repo
            if r not in trees:
                trees[r] = [n for n in tree(r) if n.startswith(kind + "/")]
            names = trees[r]
            hit = pick(c["alias"], names) if c.get("alias") else None
            hit = hit or pick(lookup, names, exact=sysid == "arcade")
            art = ""
            if hit:
                url = f"https://raw.githubusercontent.com/libretro-thumbnails/{r}/master/" + urllib.parse.quote(hit)
                src = get(url, os.path.join(CACHE, r, hit))
                if src:
                    art = f"art/{sysid}/{stem}.png"
                    fit_art(src, os.path.join(LIB, art))
            else:
                missing.append(f"{sysid}/{fn}")
            rows.append([sysid, fn, title, c.get("year") or year, c.get("maker") or maker, art, c.get("tags", ""),
                         c.get("blurb", ""), c.get("labels", "")])
    with open(os.path.join(LIB, "index.tsv"), "w") as f:
        f.write("# system\tfile\ttitle\tyear\tmaker\tart\ttags\tblurb\tlabels  (tools/shelf_index.py)\n")
        for r in rows:
            f.write("\t".join(x.replace("\t", " ") for x in r) + "\n")
    print(f"{len(rows)} games, {len(rows) - len(missing)} with art -> {LIB}/index.tsv")
    for m in missing:
        print("  no art:", m)


if __name__ == "__main__":
    main()
