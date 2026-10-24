#!/usr/bin/env bash
# The edges, then the short and the normal passes: the quit chord in every game, held
# buttons across a launch, broken and impossible saves, records that must not drop, the
# attract demos, -fast, the card, the yard's wrap and a missing game. See test.py.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 test.py all
