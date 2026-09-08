#!/usr/bin/env bash
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
trap 'find "$work" -type f -delete; rmdir "$work"' EXIT
for opt in 0 2; do
  gfortran -O"$opt" -std=f2008 -Wall -Wextra -Werror -fcheck=all \
    "$repo/src/crop/mod_wofost73_reallocation.f90" \
    "$repo/src/crop/mod_wofost_stem_reallocation_composition.f90" \
    "$repo/tests/fwof/test_fwof05_stem_reallocation_composition.f90" \
    -J"$work" -o "$work/fwof05_o$opt"
  "$work/fwof05_o$opt" > "$work/out_o$opt"
done
cmp "$work/out_o0" "$work/out_o2"
grep -q '^FWOF05_STEM_REALLOCATION_COMPOSITION_PASS$' "$work/out_o0"
