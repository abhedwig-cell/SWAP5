#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu05b2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$OPT" \
    -J "$BUILD/o$OPT" \
    src/process/mod_ppa_wu05b2_frost_effect.f90 \
    tests/fapp/test_ppa_wu05b2_frost_effect.f90 \
    -o "$BUILD/o$OPT/ppa-wu05b2"
  "$BUILD/o$OPT/ppa-wu05b2" > "$BUILD/o$OPT/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'PPA_WU05B2_O0_O2_IDENTITY=PASS'
