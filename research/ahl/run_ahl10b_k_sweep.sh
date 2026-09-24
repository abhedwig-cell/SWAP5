#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl10b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl10b_generate_k_sweep.py "$BUILD/tables" | tee "$BUILD/table_summary.json"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  research/ahl/mod_ahl09_dc_provider.f90
)
OUT="$BUILD/o2"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl10_matrix.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl10b_result.txt}"
: > "$RESULT"
for variant in k3 k1 k03 k01; do
  echo "AHL10B_VARIANT $variant" | tee -a "$RESULT"
  fail=0
  for material in B01 B12 O05 O14; do
    for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
      read -r regime h0 hbot <<< "$spec"
      set +e
      "$OUT/test" "$BUILD/tables/$variant/${material}_dc.dat" "$material" "$regime" "$h0" "$hbot" 2>&1 | tee -a "$RESULT"
      rc=${PIPESTATUS[0]}
      set -e
      if [[ "$rc" -ne 0 ]]; then
        echo "AHL10B_CASE_STATUS $variant ${material}:${regime} FAIL rc=$rc" | tee -a "$RESULT"
        fail=1
      else
        echo "AHL10B_CASE_STATUS $variant ${material}:${regime} PASS" | tee -a "$RESULT"
      fi
    done
  done
  if [[ "$fail" -eq 0 ]]; then
    echo "AHL10B_VARIANT_STATUS $variant PASS_12_OF_12" | tee -a "$RESULT"
  else
    echo "AHL10B_VARIANT_STATUS $variant FAIL" | tee -a "$RESULT"
  fi
done
echo "AHL10B_SWEEP=COMPLETE" | tee -a "$RESULT"
