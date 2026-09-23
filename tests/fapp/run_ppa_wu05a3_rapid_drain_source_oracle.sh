#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu05a3-rapid-composed-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

SOURCES=(src/process/mod_ppa_wu05a3_volundr.f90 src/process/mod_ppa_wu05a3_rapid_drain_kd.f90 \
  src/process/mod_ppa_wu05a3_drainable_storage.f90 src/process/mod_ppa_wu05a3_rapid_drain_flux.f90 \
  src/process/mod_ppa_wu05a3_rapid_drain_distribution.f90 src/process/mod_ppa_wu05a3_rapid_drain.f90 \
  tests/fapp/test_ppa_wu05a3_rapid_drain_source_oracle.f90)
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$OPT" \
    -J "$BUILD/o$OPT" "${SOURCES[@]}" -o "$BUILD/o$OPT/oracle"
  "$BUILD/o$OPT/oracle" > "$BUILD/o$OPT/output.txt"
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'PPA_WU05A3_RAPIDDRAIN_COMPOSED_O0_O2_IDENTITY=PASS'
