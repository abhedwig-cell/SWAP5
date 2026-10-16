#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
for opt in O0 O2; do
  gfortran -"$opt" -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
    -J"$work" -I"$work" -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$root/src/crop/mod_b111_nfixation_policy.f90" \
    "$root/tests/fwof/pp02/test_b111_nfixation_policy.f90" \
    -o "$work/test_nfix"
  "$work/test_nfix" > "$work/$opt.txt"
  cat "$work/$opt.txt"
done
cmp "$work/O0.txt" "$work/O2.txt"
for opt in O0 O2; do
  for driver in nitrogen_driver nitrogen_edges; do
    gfortran -"$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
      -J"$work" -I"$work" "$root/src/crop/mod_wofost81_nitrogen.f90" \
      "$root/tests/fwof/pp02/test_wofost81_$driver.f90" -o "$work/$driver"
    if [[ "$driver" == nitrogen_driver ]]; then
      python3 -B "$root/tests/fwof/pp02/check_wofost81_nitrogen.py" "$work/$driver" > "$work/$opt-$driver.txt"
    else
      "$work/$driver" > "$work/$opt-$driver.txt"
    fi
    cat "$work/$opt-$driver.txt"
  done
done
for driver in nitrogen_driver nitrogen_edges; do
  cmp "$work/O0-$driver.txt" "$work/O2-$driver.txt"
done
echo 'NFIX_UNCHANGED_WOFOST81_OWNERS_O0_O2=PASS'
python3 -B "$root/tools/audits/probe_swap431_b111_nfix_policy.py"
