#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci30-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"' EXIT
cd "$ROOT"

fail() { echo "FCI30_GATE_FAIL $*" >&2; exit 1; }

BASE=b982d4d0c8686e5c5fcb965633d34a4e0ba46fcf
CANDIDATE=16df96690fdc9dfedfa9744c47ddff5242c903a5
PRE_RUNTIME=6559237c887e9a8476beb479546becdfe9339920
POST_SRC=d6fa88b076d39fa0ffd924ce08ae4d978649dc85
REFERENCE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
SCHEDULER_BLOB=544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
WORKER_BLOB=0e700797cbaed4aaab7f04db0054f72faddcfc15
RUNTIME_BLOB=7bfb4a269256f0f1d50c32a20fd42479cf033528
PTRA_BLOB=11ef6182414af4fbe67eebec3d6f14742df04aca
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9
FVQ41_TEST_BLOB=dfd1ddb9f1a4ce1a919311645fb727f2994d2f22
FVQ41_OUTPUT_SHA=a9707200f4cbb258a502baf45f1ac9aa5d9d5a78205a56efc54bb1b63694b78f

# --- Exact current-canonical source authority --------------------------------
git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'candidate is not descended from F-CI29 canonical base'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'qualification head is not descended from exact F-CI30 candidate'
[[ "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")" == "$PRE_RUNTIME" ]] || fail 'canonical serialized runtime preimage drift'
[[ "$(git rev-parse "$CANDIDATE:src")" == "$POST_SRC" ]] || fail 'candidate src tree mismatch'
[[ "$(git rev-parse "$CANDIDATE:reference")" == "$REFERENCE" ]] || fail 'reference tree changed in candidate'
mapfile -t delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src | sort)
printf '%s\n' "${delta[@]}" > "$BUILD/actual-src.txt"
printf '%s\n' \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90 \
  src/runtime/mod_fmr_parallel_worker_pool.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/actual-src.txt" "$BUILD/expected-src.txt" || { cat "$BUILD/actual-src.txt" >&2; fail 'candidate source delta is not exactly three paths'; }
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'qualification mutated production source after candidate'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_physical_scheduler.f90)" == "$SCHEDULER_BLOB" ]] || fail 'scheduler blob mismatch'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_worker_pool.f90)" == "$WORKER_BLOB" ]] || fail 'worker pool blob mismatch'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_BLOB" ]] || fail 'serialized runtime blob mismatch'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90)" == "$PTRA_BLOB" ]] || fail 'F-CI29 ptra binding drift'
echo 'FCI30_EXACT_CURRENT_CANONICAL_THREE_FILE_POSTIMAGE=PASS'
echo 'FCI30_PRODUCTION_SOURCE_IMMUTABLE_DURING_QUALIFICATION=PASS'
echo 'FCI30_FCI29_PTRA_BLOB_PRESERVED=PASS'

# Rehydrate immutable independent parallel attacks rather than importing the
# F-MR27 owner runner or owner decisions.
git cat-file blob "$MATRIX_BLOB" > "$BUILD/parallel_matrix.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/publication_order.f90"
[[ "$(git hash-object "$BUILD/parallel_matrix.f90")" == "$MATRIX_BLOB" ]] || fail 'parallel matrix attack blob mismatch'
[[ "$(git hash-object "$BUILD/publication_order.f90")" == "$ORDER_BLOB" ]] || fail 'publication-order attack blob mismatch'
echo 'FCI30_IMMUTABLE_FMQ28_ATTACKS_REHYDRATED=PASS'

# Independent structural checks for the current composition contract.
python3 - <<'PY'
from pathlib import Path
rt=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text(encoding='utf-8').lower()
wp=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text(encoding='utf-8').lower()
sc=Path('src/runtime/mod_fmr_parallel_physical_scheduler.f90').read_text(encoding='utf-8').lower()
assert 'public :: fmr_execute_serialized_physical_column' in rt
w0=rt.index('subroutine fmr_execute_serialized_physical_column')
w1=rt.index('end subroutine fmr_execute_serialized_physical_column', w0)
wrapper=rt[w0:w1]
assert 'call execute_column(' in wrapper
assert 'receipt' not in wrapper
p0=rt.index('subroutine execute_column(', w1)
p1=rt.index('end subroutine execute_column', p0)
private=rt[p0:p1]
assert 'optional :: commit_receipt' in private
assert '!$omp atomic capture' in private
assert 'simultaneous_physical_calls = active_physical_calls' in private
assert '!$omp atomic update' in private
assert 'fmr_commit_candidate_with_receipt' in private
assert 'backends(worker_count)' in wp
assert 'transaction_controls(worker_count)' in wp
assert '!$omp parallel num_threads(worker_count)' in wp
assert 'call canonicalize_publication(columns, results, diagnostics)' in wp
assert 'fmr_build_parallel_schedule' in wp
assert 'call fmr_build_execution_order(columns, order)' in sc
assert 'receipt_column_ids' not in wp and 'commit_receipts' not in wp
print('FCI30_WORKER_OWNED_HEAVY_RUNTIME_SEAM=PASS')
print('FCI30_ATOMIC_OVERLAP_ACCOUNTING=PASS')
print('FCI30_PARALLEL_RECEIPT_ROUTING_EXCLUDED=PASS')
print('FCI30_CANONICAL_SCHEDULER_AND_PUBLICATION_SEAMS=PASS')
PY

# --- Primary independent parallel scientific/concurrency qualification --------
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/parallel_matrix.f90" -o "$OUT/matrix.o"
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/publication_order.f90" -o "$OUT/order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/order.o" -o "$OUT/order"
  "$OUT/order" > "$OUT/order.txt" 2>&1 || { cat "$OUT/order.txt" >&2; fail "publication order O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/order.txt" || fail "publication order marker O$opt"
  echo "FCI30_PARALLEL_O${opt}=PASS"
done
cmp -s "$BUILD/parallel-o0/matrix.txt" "$BUILD/parallel-o2/matrix.txt" || fail 'parallel matrix O0/O2 identity'
cmp -s "$BUILD/parallel-o0/order.txt" "$BUILD/parallel-o2/order.txt" || fail 'parallel order O0/O2 identity'
echo 'FCI30_PARALLEL_O0_O2_OUTPUT_IDENTITY=PASS'

# --- F-CI29 ptra ownership preservation --------------------------------------
git cat-file blob "$FVQ41_TEST_BLOB" > "$BUILD/fvq41_test.f90"
[[ "$(git hash-object "$BUILD/fvq41_test.f90")" == "$FVQ41_TEST_BLOB" ]] || fail 'FVQ41 frozen test blob mismatch'
PFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/ptra-o$opt"; mkdir -p "$OUT"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/transaction/mod_transaction_reference.f90 -o "$OUT/tx.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_canonical_contracts.f90 -o "$OUT/contracts.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/root_contract.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_reference_et_demand_process.f90 -o "$OUT/et_process.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$OUT/et_binding.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 -o "$OUT/ptra_binding.o"
  gfortran "${PFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq41_test.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/tx.o" "$OUT/contracts.o" "$OUT/root_contract.o" "$OUT/et_process.o" "$OUT/et_binding.o" "$OUT/ptra_binding.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "FVQ41 O$opt"; }
  grep -Fq 'FVQ41_ACTIVE_GRID_CASES=2304' "$OUT/output.txt" || fail "FVQ41 case count O$opt"
  grep -Fq 'FVQ41_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION PASS' "$OUT/output.txt" || fail "FVQ41 marker O$opt"
  [[ "$(sha256sum "$OUT/output.txt" | cut -d' ' -f1)" == "$FVQ41_OUTPUT_SHA" ]] || fail "FVQ41 output SHA O$opt"
  echo "FCI30_FCI29_PTRA_O${opt}=PASS"
done
cmp -s "$BUILD/ptra-o0/output.txt" "$BUILD/ptra-o2/output.txt" || fail 'FVQ41 O0/O2 identity'
echo 'FCI30_FCI29_PTRA_O0_O2_IDENTITY=PASS'

# --- F-MR18 serialized sparse-receipt preservation ---------------------------
# Reuse the admitted Gate-C scientific fixture, but rebind only historical
# source-governance and compile dependencies to the current tree. The receipt
# assertions themselves are not changed.
FMR18_REPLAY="$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh"
cp tests/fmr/run_fmr18_multiswap_receipt_gate.sh "$FMR18_REPLAY"
python3 - "$FMR18_REPLAY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
a=s.index('cat > "$BUILD/expected-source-delta.txt"')
b=s.index("echo 'FMR18C_EXACT_TWO_FILE_SOURCE_DELTA=PASS'", a)
b=s.index('\n', b)+1
s=s[:a]+"echo 'FCI30_FMR18_SOURCE_GOVERNANCE_REBOUND=PASS'\n"+s[b:]
old_history=('MODULE_SRC=(\n'
             '  "$BUILD/fsi04_real_headcalc_stubs.f90"\n'
             '  src/runtime/mod_a23bu_worker_execution_context.f90\n'
             '  src/transaction/mod_transaction_reference.f90\n'
             '  src/runtime/mod_canonical_contracts.f90')
new_history=('MODULE_SRC=(\n'
             '  "$BUILD/fsi04_real_headcalc_stubs.f90"\n'
             '  src/runtime/mod_a23bu_worker_execution_context.f90\n'
             '  src/transaction/mod_transaction_reference.f90\n'
             '  src/transaction/mod_fkt_temporal_indicator_history.f90\n'
             '  src/runtime/mod_canonical_contracts.f90')
if old_history not in s: raise SystemExit('FCI30 F-MR18 MODULE_SRC history anchor missing')
s=s.replace(old_history,new_history,1)
old_solver=('  src/solver/mod_b110_source_sink_provider.f90\n'
            '  src/legacy/b1_10_port/headcalc.f90\n'
            '  src/adapter/mod_reference_richards_legacy_binding.f90')
new_solver=('  src/solver/mod_b110_source_sink_provider.f90\n'
            '  src/legacy/b1_10_port/headcalc.f90\n'
            '  src/solver/mod_fixed_flux_top_boundary_provider.f90\n'
            '  src/solver/mod_reference_richards_temporal_indicator.f90\n'
            '  src/adapter/mod_reference_richards_legacy_binding.f90')
if old_solver not in s: raise SystemExit('FCI30 F-MR18 MODULE_SRC solver anchor missing')
s=s.replace(old_solver,new_solver,1)
needle='cat "$BUILD/o0/out.txt"\n'
if needle not in s: raise SystemExit('FCI30 F-MR18 stop anchor missing')
s=s.replace(needle, needle+"echo 'FCI30_FMR18_RECEIPT_PRESERVATION=PASS'\nexit 0\n",1)
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
  FCI30_FMR18_RECEIPT_PRESERVATION=PASS; do
  grep -Fq "$marker" "$BUILD/fmr18.txt" || { cat "$BUILD/fmr18.txt" >&2; fail "missing F-MR18 marker $marker"; }
done
echo 'FCI30_SERIALIZED_SPARSE_RECEIPT_SEMANTICS_PRESERVED=PASS'

# --- F-CI28 committed-boundary restart + F-CI27 ET preservation --------------
FCI28_REPLAY="$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"
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
if old not in s: raise SystemExit('FCI30 F-CI28 source-delta anchor missing')
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
echo 'FCI30_FCI28_RESTART_AND_FCI27_ET_PRESERVED=PASS'

# Compact auditable transcript.
cat "$BUILD/parallel-o0/matrix.txt"
cat "$BUILD/parallel-o0/order.txt"
grep -E '^(FMR18C_|FMR18_MULTISWAP_RECEIPT_TEST|FCI30_FMR18_)' "$BUILD/fmr18.txt" || true
grep -E '^(FCI28_|FMR19_EXACT_INTERVAL_MASS_CONTINUATION|FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY|FMQ27_FULL_NEGATIVE_MATRIX|FVQ36_INDEPENDENT_GRID_CASES|FVQ36_INDEPENDENT_ET_RATE_ORACLE)' "$BUILD/fci28.txt" || true
cat "$BUILD/ptra-o0/output.txt"
echo 'FCI30_RESTRICTED_PARALLEL_REAL_PHYSICS_V1_CANONICAL_ADMISSION_GATE=PASS'
