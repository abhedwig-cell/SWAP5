#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr27-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fmr27-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fmr27-fci28-replay-$$.sh' EXIT
cd "$ROOT"

fail() { echo "FMR27_GATE_FAIL $*" >&2; exit 1; }
BASE=06658d0b83206008dcaefba3b8d7e5c7f0c77538
CANDIDATE=d9085be7bd14f4aae8aa6e9ce1731c61bbf45e7a
PRE_SRC=3fe4ccff367479e54ab5db106e5faf8b480d8ec0
POST_SRC=7d990c6e3fcb596f33a9528be8ff45224e72f356
REFERENCE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
SCHEDULER_BLOB=544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
WORKER_BLOB=0e700797cbaed4aaab7f04db0054f72faddcfc15
RUNTIME_BLOB=1540203a2e9007586f1015dfaec6a5859c31dfe0
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9

# Exact source-bound candidate and immutable production postimage.
git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'candidate not descended from current canonical'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'owner test head not descended from candidate'
[[ "$(git rev-parse "$BASE:src")" == "$PRE_SRC" ]] || fail 'pre src tree drift'
[[ "$(git rev-parse "$CANDIDATE:src")" == "$POST_SRC" ]] || fail 'post src tree drift'
[[ "$(git rev-parse HEAD:reference)" == "$REFERENCE" ]] || fail 'reference tree drift'
mapfile -t delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src | sort)
printf '%s\n' "${delta[@]}" > "$BUILD/actual-src.txt"
printf '%s\n' \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90 \
  src/runtime/mod_fmr_parallel_worker_pool.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/actual-src.txt" "$BUILD/expected-src.txt" || { cat "$BUILD/actual-src.txt" >&2; fail 'candidate source delta'; }
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'production source changed after candidate'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_physical_scheduler.f90)" == "$SCHEDULER_BLOB" ]] || fail 'scheduler blob'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_worker_pool.f90)" == "$WORKER_BLOB" ]] || fail 'worker pool blob'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_BLOB" ]] || fail 'serialized runtime wrapper blob'
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr27_parallel_v1_matrix.f90)" == "$MATRIX_BLOB" ]] || fail 'matrix attack blob'
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr27_canonical_publication_order.f90)" == "$ORDER_BLOB" ]] || fail 'order attack blob'
echo 'FMR27_EXACT_THREE_FILE_SOURCE_DELTA=PASS'
echo 'FMR27_PRODUCTION_POSTIMAGE_IMMUTABLE=PASS'
echo 'FMR27_FROZEN_PARALLEL_ATTACK_BLOBS=PASS'

# Contract-level compatibility: one public no-receipt wrapper, one private
# receipt-aware executor, no receipt argument added to the parallel API.
python3 - <<'PY'
from pathlib import Path
rt=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text(encoding='utf-8').lower()
wp=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text(encoding='utf-8').lower()
assert 'public :: fmr_execute_serialized_physical_column' in rt
start=rt.index('subroutine fmr_execute_serialized_physical_column')
end=rt.index('end subroutine fmr_execute_serialized_physical_column', start)
wrapper=rt[start:end]
assert 'call execute_column(' in wrapper
assert 'commit_receipt' not in wrapper
private_start=rt.index('subroutine execute_column(', end)
private_end=rt.index('end subroutine execute_column', private_start)
private=rt[private_start:private_end]
assert 'optional :: commit_receipt' in private
assert 'fmr_commit_candidate_with_receipt' in private
assert 'receipt_column_ids' in rt and 'commit_receipts' in rt
pool_start=wp.index('subroutine fmr_run_parallel_physical_multiswap')
pool_sig=wp[pool_start:wp.index('\n', wp.index('runtime_diagnostics', pool_start))]
assert 'receipt' not in pool_sig
assert 'fmr_execute_serialized_physical_column' in wp
print('FMR27_NO_RECEIPT_WORKER_WRAPPER=PASS')
print('FMR27_FMR18_RECEIPT_EXECUTOR_REMAINS_PRIVATE_AND_OPTIONAL=PASS')
print('FMR27_PARALLEL_RECEIPT_ROUTING_NOT_ADDED=PASS')
PY

# Re-run the exact F-MQ28 scientific/concurrency attacks against the evolved
# current-canonical backend and transaction stack.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
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
)
export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores
for opt in 0 2; do
  OUT="$BUILD/parallel-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr27_parallel_v1_matrix.f90 -o "$OUT/matrix.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/matrix.o" -o "$OUT/matrix"
  "$OUT/matrix" > "$OUT/matrix.txt" 2>&1 || { cat "$OUT/matrix.txt" >&2; fail "parallel matrix O$opt"; }
  while read -r n b o; do
    grep -Fq "FMQ26_POSITIVE_N${n}_B${b}_O${o}=PASS" "$OUT/matrix.txt" || fail "positive n=$n b=$b order=$o O$opt"
  done <<'CASES'
2 1 0
2 2 1
7 2 2
7 3 3
7 7 0
8 3 1
8 5 2
17 4 3
17 9 0
31 7 1
31 16 2
32 8 3
32 9 0
32 17 1
CASES
  for marker in \
    FMQ26_INPUT_ORDER_INDEPENDENCE=PASS \
    FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS \
    FMQ26_REJECTION_INTERIOR=PASS \
    FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS \
    FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS \
    FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS \
    FMQ26_HARD_MASS_ALL_CASES=PASS \
    FMQ26_WORKER_COUNT_INDEPENDENCE=PASS \
    FMQ26_DETERMINISTIC_REPLAY=PASS \
    'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/matrix.txt" || fail "missing matrix marker O$opt: $marker"
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr27_canonical_publication_order.f90 -o "$OUT/order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/order.o" -o "$OUT/order"
  "$OUT/order" > "$OUT/order.txt" 2>&1 || { cat "$OUT/order.txt" >&2; fail "publication order O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/order.txt" || fail "publication order marker O$opt"
  echo "FMR27_PARALLEL_O${opt}=PASS"
done
cmp -s "$BUILD/parallel-o0/matrix.txt" "$BUILD/parallel-o2/matrix.txt" || fail 'parallel matrix O0/O2 identity'
cmp -s "$BUILD/parallel-o0/order.txt" "$BUILD/parallel-o2/order.txt" || fail 'parallel order O0/O2 identity'
echo 'FMR27_PARALLEL_O0_O2_OUTPUT_IDENTITY=PASS'

# Disposable F-MR18 Gate-C semantic replay. Remove only its historical
# candidate-delta and downstream F-CI19/F-WOF governance sections; its receipt
# fixture construction and O0/O2 scientific checks remain unchanged.
FMR18_REPLAY="$ROOT/tests/fmr/.fmr27-fmr18-replay-$$.sh"
cp tests/fmr/run_fmr18_multiswap_receipt_gate.sh "$FMR18_REPLAY"
python3 - "$FMR18_REPLAY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
a=s.index('cat > "$BUILD/expected-source-delta.txt"')
b=s.index("echo 'FMR18C_EXACT_TWO_FILE_SOURCE_DELTA=PASS'", a)
b=s.index('\n', b)+1
s=s[:a]+"echo 'FMR27_FMR18_SOURCE_GOVERNANCE_REBOUND=PASS'\n"+s[b:]
needle='cat "$BUILD/o0/out.txt"\n'
assert needle in s
s=s.replace(needle, needle+"echo 'FMR27_FMR18_RECEIPT_PRESERVATION=PASS'\nexit 0\n",1)
p.write_text(s,encoding='utf-8')
PY
bash "$FMR18_REPLAY" > "$BUILD/fmr18.txt" 2>&1 || { cat "$BUILD/fmr18.txt" >&2; fail 'F-MR18 receipt preservation'; }
for marker in \
  FMR18C_SPARSE_REQUESTED_RECEIPTS_EXACT=PASS \
  FMR18C_NO_RECEIPT_ROUTE_PHYSICAL_AND_MASS_IDENTITY=PASS \
  FMR18C_A_B_A_RECEIPT_REPLAY=PASS \
  FMR18C_REJECTED_REQUESTED_COLUMN_EMITS_NO_RECEIPT=PASS \
  FMR18C_INVALID_SPARSE_REQUESTS_FAIL_BEFORE_STATE_MUTATION=PASS \
  FMR18C_O0_O2_OUTPUT_IDENTITY=PASS \
  'FMR18_MULTISWAP_RECEIPT_TEST PASS' \
  FMR27_FMR18_RECEIPT_PRESERVATION=PASS; do
  grep -Fq "$marker" "$BUILD/fmr18.txt" || { cat "$BUILD/fmr18.txt" >&2; fail "missing F-MR18 marker $marker"; }
done
echo 'FMR27_SERIALIZED_SPARSE_RECEIPT_SEMANTICS_PRESERVED=PASS'

# Disposable F-CI28 scientific replay rebound to this exact current-canonical
# three-file candidate. The restart/ET attack bodies and blob locks remain the
# admitted F-CI28 ones; only its historical candidate-delta expectation changes.
FCI28_REPLAY="$ROOT/tests/fci/.fmr27-fci28-replay-$$.sh"
cp tests/fci/run_fci28_restart_current_canonical_admission.sh "$FCI28_REPLAY"
python3 - "$FCI28_REPLAY" "$BASE" "$CANDIDATE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); base=sys.argv[2]; candidate=sys.argv[3]
s=p.read_text(encoding='utf-8')
s=s.replace('CANONICAL_BASE=0aa4f7ca88a1cd2f3cf7333a35946c4415d9258d',f'CANONICAL_BASE={base}',1)
s=s.replace('CANDIDATE=594f3e2acd80ff5c2caeb596ae52688adf0d3bd7',f'CANDIDATE={candidate}',1)
old="printf '%s\\n' src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 | sort > \"$BUILD/expected-src.txt\""
new="printf '%s\\n' src/runtime/mod_fmr_parallel_physical_scheduler.f90 src/runtime/mod_fmr_parallel_worker_pool.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90 | sort > \"$BUILD/expected-src.txt\""
assert old in s
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
bash "$FCI28_REPLAY" > "$BUILD/fci28.txt" 2>&1 || { cat "$BUILD/fci28.txt" >&2; fail 'F-CI28 restart/ET preservation'; }
for marker in \
  FCI28_RESTART_MASS_AND_CONTINUATION=PASS \
  FCI28_FAIL_CLOSED_STATE_FAMILY_AND_ATOMICITY=PASS \
  FCI28_FCI27_ET_RUNTIME_PRESERVATION=PASS \
  FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS \
  FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS \
  FMQ27_FULL_NEGATIVE_MATRIX=PASS \
  FVQ36_INDEPENDENT_GRID_CASES=13824 \
  FVQ36_INDEPENDENT_ET_RATE_ORACLE=PASS \
  'FCI28_RESTART_CURRENT_CANONICAL_ADMISSION_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/fci28.txt" || { cat "$BUILD/fci28.txt" >&2; fail "missing F-CI28 marker $marker"; }
done
echo 'FMR27_FCI28_RESTART_AND_FCI27_ET_PRESERVED=PASS'

cat "$BUILD/parallel-o0/matrix.txt"
cat "$BUILD/parallel-o0/order.txt"
grep -E '^(FMR18C_|FMR18_MULTISWAP_RECEIPT_TEST|FMR27_FMR18_)' "$BUILD/fmr18.txt" || true
grep -E '^(FCI28_|FMR19_EXACT_INTERVAL_MASS_CONTINUATION|FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY|FMQ27_FULL_NEGATIVE_MATRIX|FVQ36_INDEPENDENT_GRID_CASES|FVQ36_INDEPENDENT_ET_RATE_ORACLE)' "$BUILD/fci28.txt" || true
echo 'FMR27_CURRENT_CANONICAL_PARALLEL_OWNER_GATE=PASS'
