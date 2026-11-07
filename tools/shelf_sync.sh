#!/bin/bash
# tools/shelf_sync.sh [LIBRARY]: copy the Shelf's library (games, index.tsv, art/) from this PC onto the
# cabinet's card, only what is new or changed (name and size). Default LIBRARY ~/partycade-card/library.
# The player and cores are `games/cart push`. Run tools/shelf_index.py first when games were added.
# Big copies stall Home (it reads its pictures from the same card: 254 MB at once froze it for 30-45 s,
# 2026-11-07), so this refuses while a game or the Yard is running, and is best run when nobody is watching.
set -e
LIB=${1:-$HOME/partycade-card/library}
HOST=$($(dirname "$0")/cab.sh host)
SSH="ssh -i $HOME/yard_key_ecdsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$HOST"
$SSH 'grep -q " /mnt/sdcard " /proc/mounts' || { echo "no card mounted on the cabinet"; exit 1; }
BUSY=$($SSH 'pidof yard play >/dev/null && echo busy; pidof PacMan SuperPacMan PacLand NS1 Galaga Galaxian Mappy DigDug orb start.sh tvplay >/dev/null && echo busy; true')
case "$BUSY" in *busy*) echo "cabinet busy: not syncing"; exit 1;; esac
# What the card has: "md5  path" for every file under library/ (cores and bin are cart push's; saves are the
# players'). By content, not size: an edited scores.tsv can keep its size.
$SSH 'cd /mnt/sdcard/library 2>/dev/null && find . -type f ! -path "./cores/*" ! -path "./bin/*" ! -path "./saves/*" ! -name recent.tsv -exec md5sum {} +' \
  | sort -k2 > /tmp/shelf_have.txt || true
(cd "$LIB" && find . -type f ! -path "./cores/*" ! -path "./bin/*" ! -path "./saves/*" ! -name recent.tsv -exec md5sum {} + | sort -k2) > /tmp/shelf_want.txt
comm -13 <(sort /tmp/shelf_have.txt) <(sort /tmp/shelf_want.txt) | cut -c35- > /tmp/shelf_send.txt
N=$(wc -l < /tmp/shelf_send.txt)
if [ "$N" = 0 ]; then echo "card is up to date"; else
  echo "sending $N file(s)"
  (cd "$LIB" && tar -cf - -T /tmp/shelf_send.txt) | $SSH 'mkdir -p /mnt/sdcard/library && tar -C /mnt/sdcard/library -xf - && sync'
  echo done
fi
# Williams boards' settings memory, where the card has none yet (games/shelf/nvram; see its README line in
# games/shelf/README.md): blank, those boards stop on FACTORY SETTINGS RESTORED.
for nv in $(dirname "$0")/../games/shelf/nvram/*.nv; do
  n=$(basename "$nv")
  $SSH "[ -f /mnt/sdcard/library/saves/arcade/mame2000/nvram/$n ]" || \
    { cat "$nv" | $SSH "mkdir -p /mnt/sdcard/library/saves/arcade/mame2000/nvram && cat > /mnt/sdcard/library/saves/arcade/mame2000/nvram/$n"; echo "seeded $n"; }
done
