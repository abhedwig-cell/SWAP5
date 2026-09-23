#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compiler="${FC:-gfortran}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for opt in O0 O2; do
  mkdir -p "$tmp/$opt"
  "$compiler" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow "-$opt" \
    -J "$tmp/$opt" "$root/src/adapter/mod_ppa_low04_gwl_exponential_flux.f90" \
    "$root/tests/fapp/test_ppa_low04_gwl_exponential_flux.f90" -o "$tmp/$opt/test.exe"
  "$tmp/$opt/test.exe" > "$tmp/$opt.out"
done

cmp "$tmp/O0.out" "$tmp/O2.out"
cat "$tmp/O2.out"
echo 'PPA_LOW04_GWL_O0_O2_IDENTITY=PASS'
