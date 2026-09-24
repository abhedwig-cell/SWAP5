#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl11c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl11_generate_decoupled_support.py "$BUILD/tables" > "$BUILD/table_summary.txt"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fbacktrace)
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
OUT="$BUILD/o3"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O3 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O3 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl11c_case_timing.f90 -o "$OUT/test.o"
gfortran -O3 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl11c_result.txt}"
: > "$RESULT"
for material in B01 B12 O05 O14; do
  for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
    read -r regime h0 hbot <<< "$spec"
    "$OUT/test" "$BUILD/tables/${material}_ret_dc.dat" "$BUILD/tables/${material}_k03_k.dat"       "$material" "$regime" "$h0" "$hbot" | tee -a "$RESULT"
  done
done

python3 - "$RESULT" <<'PY'
import re, statistics, sys
path=sys.argv[1]
vals=[]
for line in open(path):
    m=re.search(r'AHL11C_CASE_MEDIAN_RATIO\s+(\S+)\s+([0-9.]+)',line)
    if m:
        vals.append((m.group(1),float(m.group(2))))
if len(vals)!=12:
    raise SystemExit(f'expected 12 case medians, got {len(vals)}: {vals}')
ratios=[v for _,v in vals]
matrix=statistics.median(ratios)
worst=max(ratios)
print("AHL11C_CASE_MEDIANS",vals)
print(f"AHL11C_MATRIX_MEDIAN_RATIO {matrix:.6f}")
print(f"AHL11C_WORST_CASE_RATIO {worst:.6f}")
if matrix < 0.98 and worst <= 1.02:
    print("AHL11C_DECISION ADVANCE")
elif matrix > 1.02:
    print("AHL11C_DECISION REJECT")
else:
    print("AHL11C_DECISION EQUIVOCAL")
PY
