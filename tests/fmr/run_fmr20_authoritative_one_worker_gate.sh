#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr20-auth-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=110440d28ff2b585763ad8fd4eedb88e7d112eeb
BASE_REF=refs/remotes/origin/work/f-mr19-restricted-multiswap-process-restart
fail() { echo "FMR20_AUTH_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:f5cf46b4eb40e68704bc0dfcdb18bf0746504889 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:7a60f8b8d18672098fed1c6890a95aac738ed21d \
  src/adapter/mod_b110_serialized_context_binding.f90:e21c964eac48d5feb91388cfd06a646c4002a497 \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:e14733162da96399c8a247e5500b1d9e1ba95875 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:97c3c94fc8189ea9b98e8cb5cf44295bacb47e46 \
  tests/fmr/test_fmr20_authoritative_one_worker_identity.f90:d21c727427dc42c84cd4fcd90c4399001fcc5b5a; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FMR20_AUTH_G01_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags --depth=1 origin \
  work/f-mr19-restricted-multiswap-process-restart:"$BASE_REF"
[[ "$(git rev-parse "$BASE_REF")" == "$BASE" ]] || fail 'live MR19 base drift'
git diff --name-only "$BASE_REF" HEAD -- src > "$BUILD/src.changed"
printf '%s\n' \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/legacy/b1_10_port/headcalc.f90 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90 \
  src/runtime/mod_fmr_parallel_worker_pool.f90 > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'unexpected production source scope relative to MR19 closeout'
}
echo 'FMR20_AUTH_G02_BOUNDED_STAGE1_SOURCE_SCOPE=PASS'

python3 - <<'PY'
from pathlib import Path
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
sched = Path('src/runtime/mod_fmr_parallel_physical_scheduler.f90').read_text().lower()
head = Path('src/legacy/b1_10_port/headcalc.f90').read_text()
binding = Path('src/adapter/mod_reference_richards_legacy_binding.f90').read_text()

assert 'worker_count /= 1' in pool
assert pool.index('worker_count /= 1') < pool.index('call fmr_run_serialized_physical_multiswap')
for token in ('!$omp','omp_lib','call headcalc(','use variables','use mod_grid','use mod_snow'):
    assert token not in pool, token
    assert token not in sched, token
assert 'fmr_build_execution_order' in sched
assert 'mod(pos - 1, worker_count) + 1' in sched
print('FMR20_AUTH_G03_MULTIWORKER_FAILS_BEFORE_PHYSICS=PASS')
print('FMR20_AUTH_G04_NO_DIRECT_LEGACY_OR_OPENMP_DEPENDENCY=PASS')

assert 'legacy_fldtmin => fldtmin' in head
assert 'legacy_fldaystart => fldaystart' in head
assert 'at_min_dt = legacy_fldtmin' in head
assert 'at_min_dt = ctx%control%at_min_dt' in head
assert 'day_start_event = legacy_fldaystart' in head
assert 'day_start_event = ctx%time%day_start_event' in head
assert 'if (at_min_dt) MaxIt1 = 2*MaxIt' in head
assert 'if (at_min_dt .AND. state%numbit > MaxIt) then' in head
assert 'if (.NOT.at_min_dt) then' in head
assert 'if (day_start_event) then' in head
assert 'if (legacy_state_binding) legacy_fldtmin = .FALSE.' in head
for forbidden in ('if (fldtmin)', 'if (.NOT.fldtmin)', 'if (fldaystart)'):
    assert forbidden not in head, forbidden
assert 'a23bu_seed_timestep_control' in binding
assert 'call a23bu_seed_timestep_control(ws%legacy_worker, request%step_duration' in binding
assert 'fldtmin' not in binding
assert 'legacy-min-dt-deferred' not in binding
print('FMR20_AUTH_G05_CANONICAL_MIN_DT_DAY_EVENT_WORKER_LOCAL=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr20_authoritative_one_worker_identity.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    FMR20_AUTH_SCHEDULER_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_RESULT_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_DIAGNOSTIC_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_AGGREGATE_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_RUNTIME_DIAGNOSTIC_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_COMMITTED_STATE_TIME_IDENTITY=PASS \
    FMR20_AUTH_ONE_WORKER_HARD_MASS_GATE=PASS \
    FMR20_AUTH_MULTIWORKER_NOT_ADMITTED=PASS \
    FMR20_AUTH_MULTIWORKER_ZERO_PHYSICAL_SOLVES=PASS \
    FMR20_AUTH_MULTIWORKER_STATE_TIME_NONMUTATION=PASS \
    FMR20_AUTH_ZERO_WORKER_FAIL_CLOSED=PASS \
    'FMR20_AUTHORITATIVE_ONE_WORKER_IDENTITY_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker: $marker"
  done
  echo "FMR20_AUTH_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FMR20_AUTH_G06_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR20_AUTHORITATIVE_ONE_WORKER_GATE=PASS'
