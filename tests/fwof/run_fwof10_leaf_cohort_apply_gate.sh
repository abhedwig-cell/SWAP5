#!/usr/bin/env bash
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
trap 'find "$work" -type f -delete; rmdir "$work"' EXIT

for opt in 0 2; do
  gfortran -O"$opt" -std=f2008 -Wall -Wextra -Werror -fcheck=all \
    "$repo/src/crop/mod_wofost73_reallocation.f90" \
    "$repo/src/crop/mod_wofost_reallocation_request_apply.f90" \
    "$repo/src/crop/mod_wofost_leaf_cohort_reallocation.f90" \
    "$repo/tests/fwof/test_fwof10_leaf_cohort_apply.f90" \
    -J"$work" -o "$work/fwof10_o$opt"
  "$work/fwof10_o$opt" > "$work/out_o$opt"
done

cmp "$work/out_o0" "$work/out_o2"
grep -q '^FWOF10_LEAF_COHORT_APPLY_PASS$' "$work/out_o0"
