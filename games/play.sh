#!/usr/bin/env bash
# One session of every game, played by its built-in player or a script of the deck's
# buttons, then the saves and the pictures are checked. Pictures land in out/play/.
# Headless. No cabinet, no flash. See test.py.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 test.py play
