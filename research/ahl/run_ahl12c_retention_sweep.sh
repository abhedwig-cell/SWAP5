#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl12c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl12c_generate_retention_sweep.py "$BUILD/tables" | tee /tmp/ahl12c_tables.txt
PYTHONPATH=research/ahl python3 research/ahl/ahl11_generate_decoupled_support.py "$BUILD/tables" > /tmp/ahl12c_k_tables.txt

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
  research/ahl/mod_ahl11_decoupled_provider.f90
)
OUT="$BUILD/o2"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl12_prescribed_qbot_matrix.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl12c_result.txt}"
: > "$RESULT"
declare -A rc=()
for v in theta3 theta1; do
  set +e
  "$OUT/test" "$BUILD/tables/B01_${v}_ret_dc.dat" "$BUILD/tables/B01_k03_k.dat" B01 "$v" -10 2>&1 | tee -a "$RESULT"
  rc[$v]=${PIPESTATUS[0]}
  set -e
  echo "AHL12C_STATUS ${v} rc=${rc[$v]}" | tee -a "$RESULT"
done

if [[ "${rc[theta3]}" -eq 0 ]]; then
  echo "AHL12C_SELECTED=theta3" | tee -a "$RESULT"
elif [[ "${rc[theta1]}" -eq 0 ]]; then
  echo "AHL12C_SELECTED=theta1" | tee -a "$RESULT"
else
  echo "AHL12C_NO_PROSPECTIVE_VARIANT_PASSED" | tee -a "$RESULT"
  exit 1
fi
