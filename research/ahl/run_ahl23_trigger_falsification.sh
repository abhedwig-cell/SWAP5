#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl23-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl15_wet_local_k.py "$BUILD/tables" > "$BUILD/table_summary.json"

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
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl21b_wet_dt_envelope.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl23_result.txt}"; : > "$RESULT"
cases=(
  "B01 dry -500 0.060"
  "B01 dry -500 0.065"
  "O05 dry -500 0.060"
  "O05 dry -500 0.065"
)
mismatch=0
for spec in "${cases[@]}"; do
  read -r material regime h0 dt <<< "$spec"
  metric_json=$(PYTHONPATH=research/ahl python3 research/ahl/ahl23_trigger_metric.py "$BUILD/tables/${material}_dc.dat" "$material" "$h0" "$dt")
  metric=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["metric"])' "$metric_json")
  trigger=$(python3 -c 'import json,sys; print("TRUE" if json.loads(sys.argv[1])["trigger"] else "FALSE")' "$metric_json")
  set +e
  output=$("$OUT/test" "$BUILD/tables/${material}_dc.dat" "$material" "$regime" "$h0" 0.0 0.99 "$dt" 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then path="PASS"; else path="FAIL"; fi
  predicted="PASS"; [[ "$trigger" == "TRUE" ]] && predicted="FAIL"
  match="YES"; [[ "$predicted" != "$path" ]] && { match="NO"; mismatch=1; }
  echo "AHL23_CASE material=$material h=$h0 dt=$dt metric=$metric trigger=$trigger predicted_path=$predicted observed_path=$path match=$match rc=$rc" | tee -a "$RESULT"
done
if [[ "$mismatch" -eq 0 ]]; then
  echo "AHL23_TRIGGER=PASS" | tee -a "$RESULT"
else
  echo "AHL23_TRIGGER=FALSIFIED" | tee -a "$RESULT"
  exit 1
fi
