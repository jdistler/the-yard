#!/usr/bin/env bash
# Short PC self-test: each game's self-test, the yard launching a game, and the panel
# rotation of the 2D and the OpenGL ES paths. Headless. No cabinet, no flash. See test.py.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 test.py quick
