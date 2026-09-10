#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe10-target-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

for opt in 0 2; do
  exe="$BUILD/probe-o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" \
    tests/fpe/test_fpe10_target_lifetime_probe.f90 -o "$exe"
  "$exe" > "$BUILD/out-o$opt.txt"
  grep -Fq 'FPE10_TARGET_LIFETIME_NESTED_VIEW=PASS' "$BUILD/out-o$opt.txt"
  grep -Fq 'FPE10_TARGET_LIFETIME_EXPLICIT_RELEASE=PASS' "$BUILD/out-o$opt.txt"
  grep -Fq 'FPE10_TARGET_LIFETIME_IMMUTABLE_TARGET=PASS' "$BUILD/out-o$opt.txt"
  grep -Fq 'FPE10_TARGET_LIFETIME_PROBE PASS' "$BUILD/out-o$opt.txt"
  echo "FPE10_TARGET_LIFETIME_O${opt}=PASS"
done
cmp -s "$BUILD/out-o0.txt" "$BUILD/out-o2.txt"
echo 'FPE10_TARGET_LIFETIME_O0_O2_IDENTITY=PASS'
cat "$BUILD/out-o0.txt"
