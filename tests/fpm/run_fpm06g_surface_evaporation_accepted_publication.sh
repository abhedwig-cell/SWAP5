#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
FVQ56=0cdbc193976c73bef208a82547b3c9ea81c4102c
SOURCE=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
BINDING=src/runtime/mod_fmr_process_hydraulic_view_binding.f90
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90
BUILD="${RUNNER_TEMP:-/tmp}/fpm06g-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FPM06G_GATE_FAIL $*" >&2; exit 1; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
need_commit "$BASE"
need_commit "$FVQ56"
test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'branch does not descend from current F-CI42P authority'

mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "$SOURCE" > "$BUILD/expected-src-delta.txt"
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta.txt"
cmp -s "$BUILD/expected-src-delta.txt" "$BUILD/src-delta.txt" || { cat "$BUILD/src-delta.txt" >&2; fail 'production delta is not exactly one publication module'; }
[[ "$(git rev-parse HEAD:$BINDING)" == "67b346251ba21be62c6ed3077f2c71ddd2c8dd02" ]] || fail 'F-CI42 hydraulic-view binding blob drift'
[[ "$(git rev-parse HEAD:$MATERIALIZER)" == "bc40bc6b121f56071d2b811195759f86130defeb" ]] || fail 'F-CI42 materializer blob drift'
[[ "$(git rev-parse HEAD:$PROCESS)" == "a213af4deec2fe854d79120899827852a57237d1" ]] || fail 'restricted process blob drift'
echo 'FPM06G_EXACT_ONE_SOURCE_PRODUCTION_DELTA=PASS'
echo 'FPM06G_FROZEN_SURFACE_EVAPORATION_AUTHORITIES=PASS'

python3 - "$SOURCE" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
code = '\n'.join(line.split('!',1)[0] for line in text.splitlines()).lower()
for forbidden in ('canonical_mass_accounting', 'mass_in', 'mass_out', 'total_in', 'total_out',
                  'accepted_total_in', 'accepted_total_out', 'storage_change', 'top_flux', 'bottom_flux'):
    if forbidden in code:
        raise SystemExit(f'mass-authority surface found: {forbidden}')
for forbidden in ('headcalc', 'modflow', '.swp', 'midnight', 'day_of', 'month_of', 'year_of'):
    if forbidden in code:
        raise SystemExit(f'forbidden dependency/assumption: {forbidden}')
if re.search(r'^\s*(allocate|deallocate)\s*\(', code, flags=re.M):
    raise SystemExit('publication seam must be allocation-free')
for pattern in (r'\bread\s*\(', r'\bwrite\s*\(', r'\bopen\s*\(', r'\bclose\s*\('):
    if re.search(pattern, code):
        raise SystemExit(f'forbidden I/O surface: {pattern}')
if 'kernel_candidate_state_t' not in code or 'fmr_accepted_commit_receipt_t' not in code:
    raise SystemExit('missing candidate/accepted-receipt provenance binding')
if 'surface_evaporation_result_t' not in code:
    raise SystemExit('missing exact qualified process-result dependency')
if re.search(r'evaporation[^\n]*\*[^\n]*(t1|t0)|(t1|t0)[^\n]*\*[^\n]*evaporation', code):
    raise SystemExit('surface-evaporation rate appears integrated against generic kernel time')
print('FPM06G_ATTRIBUTION_ONLY_NO_MASS_LEDGER_MUTATION=PASS')
print('FPM06G_ALLOCATION_FREE_PUBLICATION_SEAM=PASS')
print('FPM06G_NO_IO_OR_SOLVER_INTERNAL_DEPENDENCY=PASS')
print('FPM06G_NO_GENERIC_TIME_RATE_INTEGRATION=PASS')
PY

COMMON=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
UNIT_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  tests/fpm/mod_fpm06g_publication_test_backend.f90
)
for opt in 0 2; do
  OUT="$BUILD/unit-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${UNIT_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr_surface_evaporation_accepted_publication.o"
  gfortran "${STRICT[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$SOURCE" -o "$obj"
  objects+=("$obj")
  gfortran "${STRICT[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fpm/test_fpm06g_surface_evaporation_accepted_publication.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "focused oracle O$opt"; }
  for marker in \
    FPM06G_INVALID_RESULT_FAIL_CLOSED=PASS \
    FPM06G_DRY_AND_PONDED_PREPARATION=PASS \
    FPM06G_PRECOMMIT_PUBLICATION_REJECTED=PASS \
    FPM06G_LINEAGE_MISMATCH_FAIL_CLOSED=PASS \
    FPM06G_REVISION_MISMATCH_FAIL_CLOSED=PASS \
    FPM06G_TIME_MISMATCH_FAIL_CLOSED=PASS \
    FPM06G_ACCEPTED_DRY_PUBLICATION=PASS \
    FPM06G_GENERIC_TIME_RATE_NOT_INTEGRATED=PASS \
    FPM06G_ACCEPTED_PONDED_PUBLICATION=PASS \
    FPM06G_NO_DUPLICATE_MASS_BOOKING=PASS \
    'FPM06G_ACCEPTED_PUBLICATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing O$opt marker $marker"; }
  done
done
cmp -s "$BUILD/unit-o0/out.txt" "$BUILD/unit-o2/out.txt" || { diff -u "$BUILD/unit-o0/out.txt" "$BUILD/unit-o2/out.txt" >&2 || true; fail 'O0/O2 focused oracle drift'; }
echo 'FPM06G_O0_O2_PUBLICATION_ORACLE_IDENTITY=PASS'

# Re-run the exact independent F-VQ56 materialization oracle against the current
# candidate source tree. This protects the already-admitted upstream behavior
# while F-PM06G adds only an orthogonal postcommit metadata seam.
git show ${FVQ56}:tests/fvq/test_fvq56_surface_evaporation_runtime_materialization_independent.f90 > "$BUILD/fvq56.f90"
sed -i 's/test_fvq56_surface_evaporation_runtime_materialization_independent/fpm06g_fvq56/g' "$BUILD/fvq56.f90"
FVQ_MODULES=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)
for opt in 0 2; do
  OUT="$BUILD/fvq-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${FVQ_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$BUILD/fvq56.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "F-VQ56 replay O$opt"; }
done
cmp -s "$BUILD/fvq-o0/out.txt" "$BUILD/fvq-o2/out.txt" || fail 'F-VQ56 O0/O2 output drift'
grep -Fxq 'FVQ56_COMMITTED_STATE_IMMUTABLE=PASS' "$BUILD/fvq-o0/out.txt" || fail 'F-VQ56 committed-state marker missing'
grep -Fxq 'FVQ56_REAL_B110_DRY_INTEGRATION=PASS' "$BUILD/fvq-o0/out.txt" || fail 'F-VQ56 dry marker missing'
grep -Fxq 'FVQ56_REAL_B110_PONDED_INTEGRATION=PASS' "$BUILD/fvq-o0/out.txt" || fail 'F-VQ56 ponded marker missing'
grep -Fxq 'FVQ56_NO_AUTHORITATIVE_MASS_BOOKING=PASS' "$BUILD/fvq-o0/out.txt" || fail 'F-VQ56 mass marker missing'
grep -Fxq 'FVQ56_INDEPENDENT_RUNTIME_ORACLE=PASS' "$BUILD/fvq-o0/out.txt" || fail 'F-VQ56 final marker missing'
echo 'FPM06G_FVQ56_UPSTREAM_ORACLE_O0_O2=PASS'
echo 'FPM06G_OWNER_QUALIFICATION_GATE PASS'
