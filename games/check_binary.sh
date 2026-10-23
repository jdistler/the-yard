#!/usr/bin/env bash
# Check that an armhf binary will load on the cabinet: right ABI, every NEEDED library exists in the
# stock rootfs, and no glibc/libstdc++ symbol version newer than the cabinet's (glibc 2.29, GCC 6).
set -euo pipefail
B=$1
ROOTFS=${ROOTFS:-$HOME/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs}
fail=0

file -b "$B" | grep -q "ARM, EABI5" || { echo "$B: not an ARM EABI5 binary"; exit 1; }
readelf -A "$B" | grep -q "Tag_ABI_VFP_args: VFP registers" || { echo "$B: not hard-float"; fail=1; }

for lib in $(readelf -d "$B" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do
  if [ ! -e "$ROOTFS/lib/$lib" ] && [ ! -e "$ROOTFS/usr/lib/$lib" ]; then
    echo "$B: needs $lib, which the cabinet does not have"; fail=1
  fi
done

newest() { readelf -V "$B" | { grep -o "$1_[0-9.]*" || true; } | sed "s/$1_//" | sort -V | tail -n1; }
g=$(newest GLIBC); x=$(newest GLIBCXX)
if [ -n "$g" ] && [ "$(printf '%s\n2.29\n' "$g" | sort -V | tail -n1)" != "2.29" ]; then
  echo "$B: needs GLIBC_$g (cabinet has 2.29)"; fail=1
fi
if [ -n "$x" ] && [ "$(printf '%s\n3.4.22\n' "$x" | sort -V | tail -n1)" != "3.4.22" ]; then
  echo "$B: needs GLIBCXX_$x (cabinet has 3.4.22); link with -static-libstdc++"; fail=1
fi

[ $fail = 0 ] && echo "$B: OK for the cabinet (newest GLIBC ${g:-none}, $(stat -c %s "$B") bytes)"
exit $fail
