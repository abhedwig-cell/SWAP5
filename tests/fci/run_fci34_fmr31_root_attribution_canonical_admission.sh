#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci34-$$"
BASE="545e07c65338b9fe61b963468675c41f3e931816"
TARGET="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
OLD_BLOB="7bfb4a269256f0f1d50c32a20fd42479cf033528"
NEW_BLOB="fe5a06c9af59308cdad86c5126379f413591b0cd"
FMR31_COMMIT="21bb6745e8fcca47b924cdcb8f77245d5dea94c9"
FVQ50_CLOSEOUT="55ccc132b0405cf4ee13336f08730aa94b24ad19"
FVQ50_BACKEND_BLOB="8b896c87c96847d9602fc1591b4463a2ad56355e"
FVQ50_TEST_BLOB="73b188f56283d3af431429da891775d6c632c357"
FVQ21_CLOSEOUT="f7cdccf11d21c31494b328251b001d474170c0c7"
FVQ21_TEST_BLOB="38251f62c3a9617230171b69d29a233ce8165ce1"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FCI34_GATE_FAIL $*" >&2; exit 34; }

[[ "$(git rev-parse "$BASE:$TARGET")" == "$OLD_BLOB" ]] || fail 'canonical base runtime blob drift'
[[ "$(git rev-parse "HEAD:$TARGET")" == "$NEW_BLOB" ]] || fail 'branch runtime is not exact qualified F-MR31 blob'
[[ "$(git rev-parse "$FMR31_COMMIT:$TARGET")" == "$NEW_BLOB" ]] || fail 'F-MR31 production authority drift'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "$TARGET" ]] || {
  printf '%s\n' "${src_delta[@]}" >&2
  fail 'production delta is not exactly the admitted runtime path'
}
echo 'FCI34_EXACT_ONE_PRODUCTION_SOURCE_DELTA=PASS'
echo 'FCI34_EXACT_FMR31_RUNTIME_BLOB=PASS'

python3 - "$FVQ50_CLOSEOUT" <<'PY'
import json, subprocess, sys
closeout = sys.argv[1]
raw = subprocess.check_output(['git','show',f'{closeout}:integration/f-vq/F-VQ50_STATUS.json'], text=True)
s = json.loads(raw)
assert s['decision'] == 'QUALIFIED_REMEDIATED_EXACT_RUNTIME_FORCING_BOUND_ROOT_UPTAKE_ATTRIBUTION_WITHIN_FROZEN_SERIALIZED_SCOPE'
assert s['state']['QUALIFIED'] is True
assert s['state']['CANONICAL_ADMITTED'] is False
assert s['candidate']['production_blob'] == 'fe5a06c9af59308cdad86c5126379f413591b0cd'
print('FCI34_FVQ50_QUALIFICATION_AUTHORITY=PASS')
PY

python3 - <<'PY'
import json
p=json.load(open('integration/f-ci/F-CI34_ARCHITECTURE_AUDIT.json'))
assert p['overall']=='NO_ADVERSE_ARCHITECTURE_DELTA_WITHIN_FROZEN_SCOPE'
ids=[x['id'] for x in p['invariants']]
assert ids==list(range(1,31))
assert all(x['status'] in ('NO_ADVERSE_DELTA','SATISFIED','SATISFIED_WITHIN_SERIALIZED_SCOPE') for x in p['invariants'])
print('FCI34_ALL_30_ARCHITECTURE_INVARIANTS=PASS')
PY

[[ "$(git rev-parse "$FVQ50_CLOSEOUT:tests/fvq/mod_fvq50_independent_runtime_backend.f90")" == "$FVQ50_BACKEND_BLOB" ]] || fail 'F-VQ50 backend blob drift'
[[ "$(git rev-parse "$FVQ50_CLOSEOUT:tests/fvq/test_fvq50_independent_root_attribution_requalification.f90")" == "$FVQ50_TEST_BLOB" ]] || fail 'F-VQ50 oracle blob drift'
git show "$FVQ50_CLOSEOUT:tests/fvq/mod_fvq50_independent_runtime_backend.f90" > "$BUILD/mod_fvq50_independent_runtime_backend.f90"
git show "$FVQ50_CLOSEOUT:tests/fvq/test_fvq50_independent_root_attribution_requalification.f90" > "$BUILD/test_fvq50_independent_root_attribution_requalification.f90"
echo 'FCI34_FVQ50_INDEPENDENT_ORACLE_SOURCE_LOCK=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/independent-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    src/runtime/mod_fmr_runtime_core.f90 \
    src/runtime/mod_fmr_checkpoint_orchestrator.f90 \
    src/solver/mod_soil_water_solver_contract.f90 \
    tests/fmr/mod_fmr04_fixed_top_provider.f90 \
    "$BUILD/mod_fvq50_independent_runtime_backend.f90" \
    src/runtime/mod_fmr_accepted_commit_receipt.f90; do
      obj="$OUT/$(basename "${src%.*}").o"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
      objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TARGET" -o "$OUT/runtime.o"
  objects+=("$OUT/runtime.o")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fvq50_independent_root_attribution_requalification.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-VQ50 replay O$opt"; }
  for marker in \
    'FVQ50_ATTRIBUTION_NOT_DERIVED_FROM_TOTAL_MASS_OUT=PASS' \
    'FVQ50_ACTIVE_ZERO_ATTRIBUTION_AVAILABLE=PASS' \
    'FVQ50_ROOT_INACTIVE_ATTRIBUTION_UNAVAILABLE=PASS' \
    'FVQ50_NONCOMMITTED_ATTRIBUTION_UNAVAILABLE=PASS' \
    'FVQ50_NO_SECOND_MASS_BOOKING=PASS' \
    'FVQ50_HARD_MASS_BALANCE=PASS' \
    'FVQ50_A_B_A_REPLAY=PASS' \
    'FVQ50_BY_VALUE_POSTRUN_FORCING_TAMPER_RESISTANCE=PASS' \
    'FVQ50_EXACT_FORCING_HANDLE_ASSOCIATION=PASS' \
    'FVQ50_INDEPENDENT_ROOT_ATTRIBUTION_REQUALIFICATION PASS'; do
      grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing F-VQ50 O$opt marker $marker"; }
  done
  echo "FCI34_FVQ50_REPLAY_O${opt}=PASS"
done
cmp -s "$BUILD/independent-o0/output.txt" "$BUILD/independent-o2/output.txt" || {
  diff -u "$BUILD/independent-o0/output.txt" "$BUILD/independent-o2/output.txt" >&2 || true
  fail 'F-VQ50 O0/O2 output identity'
}
echo 'FCI34_FVQ50_O0_O2_IDENTITY=PASS'

[[ "$(git rev-parse "$FVQ21_CLOSEOUT:tests/fmr/test_fmr09_root_sink_runtime.f90")" == "$FVQ21_TEST_BLOB" ]] || fail 'F-VQ21 root oracle drift'
git show "$FVQ21_CLOSEOUT:tests/fmr/test_fmr09_root_sink_runtime.f90" > "$BUILD/test_fmr09_root_sink_runtime.f90"
echo 'FCI34_FVQ21_REAL_ROOT_ORACLE_SOURCE_LOCK=PASS'

REAL_SRC=(
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  OUT="$BUILD/real-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${REAL_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TARGET" -o "$OUT/runtime.o"
  objects+=("$OUT/runtime.o")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fmr09_root_sink_runtime.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "real root replay O$opt"; }
  grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_BALANCED_ROOT_SSDI_STATE_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/output.txt"
  echo "FCI34_REAL_ROOT_REPLAY_O${opt}=PASS"
done
cmp -s "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" || {
  diff -u "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" >&2 || true
  fail 'real root O0/O2 output identity'
}
echo 'FCI34_REAL_ROOT_O0_O2_IDENTITY=PASS'

cat "$BUILD/independent-o0/output.txt"
cat "$BUILD/real-o0/output.txt"
echo 'FCI34_PREPROMOTION_CANONICAL_ADMISSION_GATE=PASS'
