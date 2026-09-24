#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl14a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl14_floor_scaled_k.py "$BUILD/tables" > "$BUILD/table_summary.json"

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
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl14a_b01wet.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
set +e
"$OUT/test" "$BUILD/tables/B01_dc.dat" B01 wet -10 -7.5 > /tmp/ahl14a_result.txt 2>&1
rc=$?
set -e
cat /tmp/ahl14a_result.txt
# Expected F-AHL14 response-gate failure is allowed here; the diagnostic must
# have executed far enough to emit the accepted head envelope and node states.
grep -Fq 'AHL14A_HEAD_ENVELOPE' /tmp/ahl14a_result.txt
grep -Fq 'AHL14A_NODE' /tmp/ahl14a_result.txt
echo "AHL14A_DIAGNOSTIC_CAPTURE=PASS rc=$rc"
