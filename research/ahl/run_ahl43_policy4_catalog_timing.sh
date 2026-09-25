#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl43-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 research/ahl/ahl11e_build_full_catalog_1e4.py "$BUILD/tables" > "$BUILD/catalog_summary.json"

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
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD"   -c research/ahl/test_ahl43_policy4_catalog_timing.f90 -o "$BUILD/test.o"
gfortran -O3 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="${1:-/tmp/ahl43_result.txt}"
: > "$RESULT"
for prefix in B O; do
  for i in $(seq -w 1 18); do
    m="${prefix}${i}"
    "$BUILD/test" "$BUILD/tables/${m}_dc.dat" "$m" mid -75 -50 | tee -a "$RESULT"
  done
done

python3 - "$RESULT" <<'PY'
import re, statistics, sys
rows={}
for line in open(sys.argv[1]):
    m=re.search(r'FAHL43_MEDIAN_RATIO\s+(\S+)\s+([0-9.]+)',line)
    if m:
        rows[m.group(1)]=float(m.group(2))
if len(rows)!=36:
    raise SystemExit(f'F-AHL43 expected 36 medians, found {len(rows)}')
vals=list(rows.values())
positive={k:v for k,v in rows.items() if v<0.98}
equiv={k:v for k,v in rows.items() if 0.98<=v<=1.02}
negative={k:v for k,v in rows.items() if v>1.02}
med=statistics.median(vals)
print('FAHL43_CATALOG_MEDIAN_RATIO',f'{med:.6f}')
print('FAHL43_POSITIVE_COUNT',len(positive))
print('FAHL43_EQUIVOCAL_COUNT',len(equiv))
print('FAHL43_NEGATIVE_COUNT',len(negative))
print('FAHL43_NEGATIVE',','.join(f'{k}={v:.6f}' for k,v in sorted(negative.items())))
ok=(len(positive)>=30 and len(negative)<=3 and med<0.98)
print('FAHL43_BROAD_POLICY4_SPEED=' + ('PASS' if ok else 'FAIL'))
if not ok:
    raise SystemExit(1)
PY
