#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compiler="${FC:-gfortran}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for opt in O0 O2; do
  mkdir -p "$tmp/$opt"
  "$compiler" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow "-$opt" \
    -J "$tmp/$opt" "$root/src/process/mod_ppa_wu05d3_walsum_compensation.f90" \
    "$root/tests/fapp/test_ppa_wu05d3_walsum_compensation.f90" -o "$tmp/$opt/test.exe"
  "$tmp/$opt/test.exe" > "$tmp/$opt.out"
done

cmp "$tmp/O0.out" "$tmp/O2.out"
cat "$tmp/O2.out"
echo 'PPA_WU05D3_O0_O2_IDENTITY=PASS'
