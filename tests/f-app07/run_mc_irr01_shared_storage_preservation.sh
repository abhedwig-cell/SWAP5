#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-irr-storage-preservation-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
# Reuse immutable BOFEK00 scientific assertions on the current candidate.
# Historical admission runners require their old live HEAD and cannot qualify
# a later shared successor. No scientific assertion or tolerance is replaced.
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stubs.f90" --nodes 16 --dz-cm 10
for case in dynamic_top_correction frozen_wet_trajectory; do
  for opt in 0 2; do
    out="$BUILD/${case}-o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" \
      --stub "$BUILD/stubs.f90" --target "tests/verification/test_bofek00_${case}.f90" \
      --external-source src/legacy/b1_10_port/headcalc.f90 \
      --external-source src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 \
      --build "$out" --opt "$opt"
    OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/rom0_test" > "$BUILD/${case}-o${opt}.txt" 2>&1
  done
  cmp "$BUILD/${case}-o0.txt" "$BUILD/${case}-o2.txt"
  cat "$BUILD/${case}-o0.txt"
  echo "MC_IRR01_STORAGE_BOFEK_${case}_O0_O2=PASS"
done
# Reuse executable scientific assertions directly. Historical F-SI38/39
# admission scripts contain old exact source-shape/delta guards; this successor
# is governed by its own exact shared-source pin, without changing those guards.
for case in fsi25_reference_indicator_production_seam fsi39_b110_ksatexm; do
  for opt in 0 2; do
    out="$BUILD/${case}-o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" \
      --stub tests/fsi/fsi04_real_headcalc_stubs.f90 --target "tests/fsi/test_${case}.f90" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt "$opt"
    args=(); if [[ "$case" == fsi25_reference_indicator_production_seam ]]; then args=(-75.0 0.01); fi
    "$out/rom0_test" "${args[@]}" > "$BUILD/${case}-o${opt}.txt" 2>&1 || { cat "$BUILD/${case}-o${opt}.txt" >&2; exit 1; }
  done
  cmp "$BUILD/${case}-o0.txt" "$BUILD/${case}-o2.txt"
  cat "$BUILD/${case}-o0.txt"
  echo "MC_IRR01_STORAGE_${case}_O0_O2=PASS"
done
echo 'MC_IRR01_SHARED_STORAGE_SEMANTIC_PRESERVATION=PASS'
