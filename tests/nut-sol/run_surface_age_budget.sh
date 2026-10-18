#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
for opt in 0 2; do
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J "$build" -I "$build" \
    src/process/mod_b111_surface_age_budget.f90 \
    tests/nut-sol/test_surface_age_budget.f90 -o "$build/age-o$opt"
  "$build/age-o$opt" > "$build/out-o$opt"
  grep -Fq 'MC_SOL01_SURFACE_AGE_BUDGET=PASS' "$build/out-o$opt"
  echo "MC_SOL01_SURFACE_AGE_BUDGET_O${opt}=PASS"
done
cmp "$build/out-o0" "$build/out-o2"
echo 'MC_SOL01_SURFACE_AGE_BUDGET_O0_O2=PASS'
