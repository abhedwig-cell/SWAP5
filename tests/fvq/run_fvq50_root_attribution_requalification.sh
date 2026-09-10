#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq50-$$"
BASE="49863406a6112baa9956f9396b34e7188934e0d4"
CANDIDATE="21bb6745e8fcca47b924cdcb8f77245d5dea94c9"
RUNTIME_PATH="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
RUNTIME_BLOB="fe5a06c9af59308cdad86c5126379f413591b0cd"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ50_GATE_FAIL $*" >&2; exit 50; }

# Qualification branch must remain clean production-wise and descend exactly
# from current canonical source authority. Candidate source is build-local only.
git merge-base --is-ancestor "$BASE" HEAD || fail 'qualification branch not descended from canonical source authority'
if [[ -n "$(git diff --name-only "$BASE"..HEAD -- src)" ]]; then
  git diff --name-only "$BASE"..HEAD -- src >&2
  fail 'qualification branch contains production src delta'
fi
[[ "$(git rev-parse "$CANDIDATE:$RUNTIME_PATH")" == "$RUNTIME_BLOB" ]] || fail 'pinned F-MR31 candidate blob drift'
RUNTIME="$BUILD/mod_fmr_serialized_multiswap_runtime.f90"
git show "$CANDIDATE:$RUNTIME_PATH" > "$RUNTIME"
[[ "$(git hash-object "$RUNTIME")" == "$RUNTIME_BLOB" ]] || fail 'materialized candidate blob mismatch'
echo 'FVQ50_CLEAN_CANONICAL_QUALIFICATION_BRANCH=PASS'
echo 'FVQ50_EXACT_PINNED_FMR31_CANDIDATE_BLOB=PASS'

# Independent static reconstruction of the former HN1 seam. Do not consult or
# compile the F-MR31 owner oracle here.
python3 - "$RUNTIME" <<'PY'
from pathlib import Path
import re, subprocess, sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8').lower()
flat = ' '.join(s.split())
required = [
    'logical :: actual_transpiration_available = .false.',
    'real(real64) :: actual_transpiration_amount = 0.0_real64',
    'forcing_index = int(column%forcing_handle)',
    'forcing_registry(forcing_index)',
    'call bind_committed_actual_transpiration(parameter_registry(parameter_index), forcing_registry(forcing_index),',
    'amount = sum(forcing%root_extraction_sink) * (t1 - t0)',
]
for token in required:
    assert token in flat, f'missing candidate provenance token: {token}'
for token in ('fmr_prepare_root_uptake_attribution','fmr_finalize_root_uptake_attribution','mod_fmr_root_uptake_attribution_receipt'):
    assert token not in s, f'detached F-MR30 repair seam survived: {token}'
trial = s.index('call backend%run_trial(')
bind = s.index('call bind_committed_actual_transpiration(')
commit_fail_guard = s.index('if (.not. did_commit) then')
assert trial < commit_fail_guard < bind, 'attribution is not structurally postcommit'
# The physical trial and attribution must both reference the same resolved local forcing_index.
trial_window = s[trial:s.index('output%kernel_status',trial)]
assert 'forcing_registry(forcing_index)' in trial_window, 'trial does not use exact resolved forcing_index'
base = subprocess.check_output(['git','show','49863406a6112baa9956f9396b34e7188934e0d4:src/runtime/mod_fmr_serialized_multiswap_runtime.f90'], text=True).lower()
for token in ('%mass%total_out','%mass%total_in','%mass%storage_change','%mass%residual'):
    assert s.count(token) == base.count(token), f'generic mass-ledger reference count changed: {token}'
assert not re.search(r'actual_transpiration_amount\s*=.*mass%',s), 'attribution appears derived from generic mass result'
print('FVQ50_FORMER_HN1_DETACHED_REPAIR_PATH_ABSENT=PASS')
print('FVQ50_SAME_RESOLVED_FORCING_INDEX_BY_CONSTRUCTION=PASS')
print('FVQ50_POSTCOMMIT_PUBLICATION_SHAPE=PASS')
print('FVQ50_NO_GENERIC_MASS_LEDGER_SOURCE_DELTA=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# Qualification-local independent transaction oracle.
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
    tests/fvq/mod_fvq50_independent_runtime_backend.f90 \
    src/runtime/mod_fmr_accepted_commit_receipt.f90; do
      obj="$OUT/$(basename "${src%.*}").o"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
      objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$RUNTIME" -o "$OUT/runtime.o"
  objects+=("$OUT/runtime.o")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq50_independent_root_attribution_requalification.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "independent oracle O$opt"; }
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
      grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing independent O$opt marker $marker"; }
  done
  echo "FVQ50_INDEPENDENT_ORACLE_O${opt}=PASS"
done
cmp -s "$BUILD/independent-o0/output.txt" "$BUILD/independent-o2/output.txt" || {
  diff -u "$BUILD/independent-o0/output.txt" "$BUILD/independent-o2/output.txt" >&2 || true
  fail 'independent O0/O2 output identity'
}
echo 'FVQ50_INDEPENDENT_O0_O2_IDENTITY=PASS'

# Independent replay of the prior F-VQ21 real-physics HeadCalc root-sink oracle
# against current canonical dependencies, substituting only the exact candidate runtime.
FVQ21_CLOSEOUT="f7cdccf11d21c31494b328251b001d474170c0c7"
FVQ21_TEST_PATH="tests/fmr/test_fmr09_root_sink_runtime.f90"
FVQ21_TEST_BLOB="38251f62c3a9617230171b69d29a233ce8165ce1"
[[ "$(git rev-parse "$FVQ21_CLOSEOUT:$FVQ21_TEST_PATH")" == "$FVQ21_TEST_BLOB" ]] || fail 'F-VQ21 root oracle blob drift'
REAL_TEST="$BUILD/test_fmr09_root_sink_runtime.f90"
git show "$FVQ21_CLOSEOUT:$FVQ21_TEST_PATH" > "$REAL_TEST"
echo 'FVQ50_FVQ21_REAL_ROOT_ORACLE_SOURCE_LOCK=PASS'

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
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$RUNTIME" -o "$OUT/runtime.o"
  objects+=("$OUT/runtime.o")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$REAL_TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "real root oracle O$opt"; }
  grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_BALANCED_ROOT_SSDI_STATE_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/output.txt"
  echo "FVQ50_REAL_ROOT_ORACLE_O${opt}=PASS"
done
cmp -s "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" || {
  diff -u "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" >&2 || true
  fail 'real root O0/O2 output identity'
}
echo 'FVQ50_REAL_ROOT_O0_O2_IDENTITY=PASS'

cat "$BUILD/independent-o0/output.txt"
cat "$BUILD/real-o0/output.txt"
echo 'FVQ50_DECISION=QUALIFIED_REMEDIATED_EXACT_RUNTIME_FORCING_BOUND_ROOT_UPTAKE_ATTRIBUTION_WITHIN_FROZEN_SERIALIZED_SCOPE'
