#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr31-current-$$"
BASE="49863406a6112baa9956f9396b34e7188934e0d4"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR31_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "trusted dependency drift: $path expected=$expected actual=$actual"
}

# Exact current-canonical source authority and one-source production delta.
git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate not descended from current canonical authority'
printf '%s\n' "$RUNTIME" > "$BUILD/expected-src.txt"
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src.txt"
cmp -s "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || {
  cat "$BUILD/actual-src.txt" >&2
  fail 'production delta is not exactly serialized MultiSWAP runtime'
}
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
check_blob src/kernel/mod_kernel_transactions.f90 f1acff10dd99c308a00f434440d6a9ef14632f0d
echo 'FMR31_CURRENT_CANONICAL_SOURCE_LOCK=PASS'
echo 'FMR31_EXACT_ONE_PRODUCTION_SOURCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
import re
s = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text(encoding='utf-8').lower()
flat = ' '.join(s.split())
for required in (
    'logical :: actual_transpiration_available = .false.',
    'real(real64) :: actual_transpiration_amount = 0.0_real64',
    'call bind_committed_actual_transpiration(parameter_registry(parameter_index), forcing_registry(forcing_index),',
    'amount = sum(forcing%root_extraction_sink) * (t1 - t0)',
    'output%actual_transpiration_amount = amount',
    'output%actual_transpiration_available = .true.',
):
    assert required in flat, f'missing exact-forcing binding token: {required}'
for forbidden in (
    'fmr_prepare_root_uptake_attribution',
    'fmr_finalize_root_uptake_attribution',
    'mod_fmr_root_uptake_attribution_receipt',
):
    assert forbidden not in s, f'unsafe detached F-MR30 API dependency survived: {forbidden}'
# Binding must occur only after the did_commit rejection block. This is the
# core by-construction provenance property that closes F-VQ48 HN1.
commit_guard = s.index('if (.not. did_commit) then')
bind_call = s.index('call bind_committed_actual_transpiration(')
assert bind_call > commit_guard, 'attribution binding occurs before commit success is known'
# No second water-balance booking may be introduced by F-MR31.
base = __import__('subprocess').check_output(['git','show','49863406a6112baa9956f9396b34e7188934e0d4:src/runtime/mod_fmr_serialized_multiswap_runtime.f90'], text=True).lower()
for token in ('%mass%total_out', '%mass%total_in', '%mass%storage_change', '%mass%residual'):
    assert s.count(token) == base.count(token), f'F-MR31 changed generic mass-ledger references: {token}'
assert not re.search(r'actual_transpiration_amount\s*=.*mass%', s), 'attribution sourced from mass result instead of exact forcing'
print('FMR31_HN1_DETACHED_REPAIRING_API_ABSENT=PASS')
print('FMR31_POSTCOMMIT_EXACT_FORCING_BINDING_SHAPE=PASS')
print('FMR31_NO_GENERIC_MASS_LEDGER_DELTA=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# A compact independent-of-HeadCalc transaction oracle attacks forcing-handle,
# batch/order and rejected-column routing directly.
for opt in 0 2; do
  OUT="$BUILD/oracle-o$opt"
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
    tests/fmr/mod_fmr31_root_attribution_test_backend.f90 \
    src/runtime/mod_fmr_accepted_commit_receipt.f90; do
      obj="$OUT/$(basename "${src%.*}").o"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
      objects+=("$obj")
  done
  obj="$OUT/runtime.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$RUNTIME" -o "$obj"
  objects+=("$obj")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr31_exact_root_attribution_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "transaction oracle O$opt"; }
  for marker in \
    'FMR31_ATTRIBUTION_EQUALS_ALREADY_BOOKED_ROOT_MASS=PASS' \
    'FMR31_ACTIVE_ZERO_ROOT_ATTRIBUTION_AVAILABLE=PASS' \
    'FMR31_ROOT_INACTIVE_ATTRIBUTION_UNAVAILABLE=PASS' \
    'FMR31_NONCOMMITTED_ATTRIBUTION_UNAVAILABLE=PASS' \
    'FMR31_FORCING_HANDLE_BATCH_ORDER_IDENTITY=PASS' \
    'FMR31_A_B_A_RUNTIME_ATTRIBUTION_IDENTITY=PASS' \
    'FMR31_EXACT_COLUMN_FORCING_ASSOCIATION=PASS' \
    'FMR31_ROOT_ATTRIBUTION_BINDING_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing oracle O$opt marker $marker"; }
  done
  echo "FMR31_TRANSACTION_ORACLE_O${opt}=PASS"
done
cmp -s "$BUILD/oracle-o0/output.txt" "$BUILD/oracle-o2/output.txt" || {
  diff -u "$BUILD/oracle-o0/output.txt" "$BUILD/oracle-o2/output.txt" >&2 || true
  fail 'transaction oracle O0/O2 identity'
}
echo 'FMR31_TRANSACTION_ORACLE_O0_O2_IDENTITY=PASS'

# Real production-backend regression: reuse the already-qualified F-MR09
# balanced root-sink/SSDI fixture against the remediated current runtime. This
# proves the result-field extension does not break real HeadCalc root physics or
# the hard mass gate.
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  OUT="$BUILD/real-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${REAL_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    flags=("${COMMON[@]}")
    [[ "$src" == "$RUNTIME" ]] && flags=("${STRICT[@]}")
    gfortran "${flags[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr09_root_sink_runtime.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "real root runtime O$opt"; }
  grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_BALANCED_ROOT_SSDI_STATE_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/output.txt"
  echo "FMR31_REAL_ROOT_RUNTIME_O${opt}=PASS"
done
cmp -s "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" || {
  diff -u "$BUILD/real-o0/output.txt" "$BUILD/real-o2/output.txt" >&2 || true
  fail 'real root runtime O0/O2 identity'
}
echo 'FMR31_REAL_ROOT_RUNTIME_O0_O2_IDENTITY=PASS'
cat "$BUILD/oracle-o0/output.txt"
cat "$BUILD/real-o0/output.txt"
echo 'FMR31_OWNER_GATE=PASS'
