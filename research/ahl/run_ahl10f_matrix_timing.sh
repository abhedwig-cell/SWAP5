#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl10f-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl10d_build_relevance_bounded.py "$BUILD/tables" > "$BUILD/table_summary.json"

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
  research/ahl/mod_ahl09_dc_provider.f90
)
OUT="$BUILD/o3"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O3 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O3 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl10f_matrix_timing.f90 -o "$OUT/test.o"
gfortran -O3 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl10f_result.txt}"
: > "$RESULT"
for material in B01 B12 O05 O14; do
  for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
    read -r regime h0 hbot <<< "$spec"
    "$OUT/test" "$BUILD/tables/k03/${material}_dc.dat" "$material" "$regime" "$h0" "$hbot" | tee -a "$RESULT"
  done
done

python3 - "$RESULT" <<'PY'
import re, statistics, sys
path=sys.argv[1]
rows=[]
for line in open(path):
    m=re.search(r'AHL10F_CASE\s+(\S+)\s+(\S+)\s+([0-9.]+)', line)
    if m:
        rows.append((m.group(1),m.group(2),float(m.group(3))))
if len(rows)!=12:
    raise SystemExit(f'expected 12 case medians, found {len(rows)}')
ratios=[r for _,_,r in rows]
med=statistics.median(ratios)
neg=[f"{m}:{g}={r:.6f}" for m,g,r in rows if r>1.02]
pos=[f"{m}:{g}={r:.6f}" for m,g,r in rows if r<0.98]
eq=[f"{m}:{g}={r:.6f}" for m,g,r in rows if 0.98<=r<=1.02]
print("AHL10F_MATRIX_MEDIAN_RATIO",f"{med:.6f}")
print("AHL10F_SPEED_POSITIVE",",".join(pos))
print("AHL10F_EQUIVOCAL",",".join(eq))
print("AHL10F_SPEED_NEGATIVE",",".join(neg))
if med < 0.98 and not neg:
    print("AHL10F_BROAD_SPEED_CANDIDATE=PASS")
else:
    print("AHL10F_BROAD_SPEED_CANDIDATE=FAIL")
PY
