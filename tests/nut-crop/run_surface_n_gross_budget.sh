#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
for opt in 0 2; do
  mkdir -p "$build/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
    -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
    -J "$build/o$opt" -I "$build/o$opt" \
    src/process/mod_b111_surface_n_gross_budget.f90 \
    tests/nut-crop/test_surface_n_gross_budget.f90 -o "$build/o$opt/test"
  "$build/o$opt/test" > "$build/o$opt/output"
  grep -Fq 'MC_NUT01_GROSS_NET_SURFACE_N_BUDGET=PASS' "$build/o$opt/output"
  echo "MC_NUT01_GROSS_NET_SURFACE_N_BUDGET_O$opt=PASS"
done
cmp "$build/o0/output" "$build/o2/output"
