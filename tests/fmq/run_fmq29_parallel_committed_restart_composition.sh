#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fmq29-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ29_GATE_FAIL $*" >&2; exit 29; }
BASE=6318f04bd4d7dd8f9a587f03decaaea63d4f5f36
OWNER_CANDIDATE=1e27f2758d9dbed11350aec5a089662921826d21
OWNER_TREE=4410569d672f9dd3c57fa5468f8c0f6f1dea9e2c
OWNER_CLOSEOUT=eef9cfa2cdb6b272ae9c0dd1f4ad0c90153953f4
PARALLEL_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9

# Qualification is source-free and starts from the exact current canonical authority.
git merge-base --is-ancestor "$BASE" HEAD || fail 'qualification branch not descended from frozen canonical authority'
git diff --quiet "$BASE"..HEAD -- src reference || {
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail 'F-MQ29 modified production or reference source'
}
[[ "$(git rev-parse HEAD:src)" == 02aa1516a6f452d311ea03c195cbeaf271d3db28 ]] || fail 'src tree drift'
[[ "$(git rev-parse HEAD:reference)" == 9d08625217d7c0a7385df9da6a04183bcd9cb9e6 ]] || fail 'reference tree drift'
[[ "$(git rev-parse "$OWNER_CANDIDATE^{tree}")" == "$OWNER_TREE" ]] || fail 'owner candidate tree mismatch'
git merge-base --is-ancestor "$OWNER_CANDIDATE" "$OWNER_CLOSEOUT" || fail 'owner closeout not descendant of candidate'
git diff --quiet "$BASE".."$OWNER_CANDIDATE" -- src reference || fail 'owner candidate unexpectedly changes production/reference'
git diff --quiet "$BASE".."$OWNER_CLOSEOUT" -- src reference || fail 'owner closeout unexpectedly changes production/reference'

echo 'FMQ29_CANONICAL_SOURCE_AUTHORITY_LOCK=PASS'
echo 'FMQ29_OWNER_CANDIDATE_IMMUTABLE_LOCK=PASS'
echo 'FMQ29_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_committed_restart.f90 19ea410e0ed48e65b5d73887a8e1dba59c7c4f37
check_blob src/runtime/mod_fmr_restart_state_contract.f90 f1359f97d02408d8b700b0c93fe961a6ba46742c
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_runtime_core.f90 adc2b7514cc062c0cde4e71582ba8ed7776a7335
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
check_blob src/runtime/mod_canonical_contracts.f90 c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
check_blob tests/fmq/test_fmq27_restart_contract_requalification.f90 cb5e6973a8a5d207e6dffa657d2539224826072d

echo 'FMQ29_CURRENT_PRODUCTION_BLOB_LOCKS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
lock=json.loads(Path('integration/f-mq/F-MQ29_CANDIDATE_LOCK.json').read_text())
mat=json.loads(Path('integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json').read_text())
assert lock['qualification_base']['head']=='6318f04bd4d7dd8f9a587f03decaaea63d4f5f36'
assert lock['owner']['candidate']=='1e27f2758d9dbed11350aec5a089662921826d21'
assert lock['owner']['candidate_tree']=='4410569d672f9dd3c57fa5468f8c0f6f1dea9e2c'
assert lock['owner']['closeout']=='eef9cfa2cdb6b272ae9c0dd1f4ad0c90153953f4'
assert lock['candidate_source_semantics']['production_source_delta_from_canonical']==0
assert lock['production_modification_allowed'] is False
assert mat['source_authority']==lock['qualification_base']['head']
assert mat['held_out_composition_cases']==[
 {'n':3,'batch':2,'order':3},{'n':5,'batch':4,'order':2},{'n':9,'batch':4,'order':1},
 {'n':16,'batch':7,'order':3},{'n':23,'batch':10,'order':2},{'n':33,'batch':14,'order':1}]
assert mat['origin_routes']==['serialized','parallel_2','parallel_4']
assert mat['continuation_workers']==[2,4]
assert set(mat['cross_worker_routes'])=={'2_to_4','4_to_2'}
assert mat['restart_record_orders']==['reverse','odd_even_interleave']
assert mat['hard_mass_gate_cm']==1e-12
assert mat['independent_attack_basis']['owner_composition_fixture']=='EXCLUDED_FROM_QUALIFICATION_EVIDENCE'
print('FMQ29_PERSISTED_INDEPENDENT_MATRIX_LOCK=PASS')
PY

# Independently reconstruct the architecture seam from production source rather than owner conclusions.
python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
pool=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
serialized=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
record=restart.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record, forbidden
assert 'state_registry = candidate_states' in restart
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in pool
assert 'call canonicalize_publication(columns, results, diagnostics)' in pool
assert 'actual_transpiration_available' in serialized
print('FMQ29_RESTART_RECORD_COMPACT_NO_WORKER_SOLVER_SCRATCH=PASS')
print('FMQ29_RESTORE_PUBLICATION_IS_WHOLE_REGISTRY=PASS')
print('FMQ29_PARALLEL_WORKER_SCRATCH_REBUILT_PER_INVOCATION=PASS')
print('FMQ29_CANONICAL_PUBLICATION_SEAM=PASS')
print('FMQ29_FCI34_SERIALIZED_RESULT_CONTRACT_PRESENT=PASS')
PY

# Rehydrate only previously independent fixtures. The F-MR32 owner composition fixture is never read.
git cat-file blob "$PARALLEL_BLOB" > "$BUILD/parallel_independent.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/publication_independent.f90"
[[ "$(git hash-object "$BUILD/parallel_independent.f90")" == "$PARALLEL_BLOB" ]] || fail 'parallel fixture blob mismatch'
[[ "$(git hash-object "$BUILD/publication_independent.f90")" == "$ORDER_BLOB" ]] || fail 'publication fixture blob mismatch'
python3 tests/fmq/build_fmq29_parallel_restart_fixture.py "$BUILD/parallel_independent.f90" "$BUILD/composition_independent.f90"

grep -Fq 'FMQ29_HELDOUT_N' "$BUILD/composition_independent.f90" || fail 'generated composition marker absent'
if grep -Fq 'FMR32_' "$BUILD/composition_independent.f90"; then
  fail 'owner F-MR32 composition fixture leaked into independent test'
fi
echo 'FMQ29_OWNER_COMPOSITION_FIXTURE_EXCLUDED=PASS'
echo 'FMQ29_INDEPENDENT_COMPOSITION_FIXTURE_GENERATED=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
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
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  # Independent restart-contract attacks, including atomic late-record failures.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq27_restart_contract_requalification.f90 -o "$OUT/restart_negative.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/restart_negative.o" -o "$OUT/restart_negative"
  "$OUT/restart_negative" > "$OUT/restart_negative.txt" 2>&1 || { cat "$OUT/restart_negative.txt" >&2; fail "restart negative O$opt"; }
  for marker in \
    FMQ27_STATE_FAMILY_DISCRIMINATOR=PASS \
    FMQ27_MALFORMED_CONCRETE_STATE_REJECTED=PASS \
    FMQ27_LATE_RECORD_ATOMICITY=PASS \
    FMQ27_REGISTERED_WRONG_FAMILY_REJECTED=PASS \
    FMQ27_LATE_PROVENANCE_ATOMICITY=PASS \
    FMQ27_FULL_NEGATIVE_MATRIX=PASS \
    FMQ27_VALID_PRODUCTION_RESTORE=PASS; do
    grep -Fq "$marker" "$OUT/restart_negative.txt" || fail "restart marker $marker O$opt"
  done

  # Held-out composition. It also executes the immutable FMQ26 independent parallel matrix.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/composition_independent.f90" -o "$OUT/composition.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/composition.o" -o "$OUT/composition"
  "$OUT/composition" > "$OUT/composition.txt" 2>&1 || { cat "$OUT/composition.txt" >&2; fail "composition O$opt"; }

  for n in 3 5 9 16 23 33; do
    grep -Fq "FMQ29_HELDOUT_N${n}_" "$OUT/composition.txt" || fail "held-out n=$n O$opt"
  done
  for marker in \
    FMQ29_SERIALIZED_ORIGIN_TO_PARALLEL=PASS \
    FMQ29_PARALLEL_2_ORIGIN_TO_2_4=PASS \
    FMQ29_PARALLEL_4_ORIGIN_TO_2_4=PASS \
    FMQ29_CROSS_WORKER_2_TO_4=PASS \
    FMQ29_CROSS_WORKER_4_TO_2=PASS \
    FMQ29_REVERSE_AND_ODD_EVEN_RESTART_ORDER=PASS \
    FMQ29_EXACT_MIDPOINT_COMMITTED_STATE=PASS \
    FMQ29_FRESH_RECONSTRUCTED_TARGET=PASS \
    FMQ29_ENDPOINT_RESTART_IDENTITY=PASS \
    FMQ29_FCI34_PARALLEL_SCOPE_NOT_WIDENED=PASS \
    FMQ26_INPUT_ORDER_INDEPENDENCE=PASS \
    FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS \
    FMQ26_REJECTION_INTERIOR=PASS \
    FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS \
    FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS \
    FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS \
    FMQ26_HARD_MASS_ALL_CASES=PASS \
    FMQ26_WORKER_COUNT_INDEPENDENCE=PASS \
    FMQ26_DETERMINISTIC_REPLAY=PASS; do
    grep -Fq "$marker" "$OUT/composition.txt" || fail "composition/preservation marker $marker O$opt"
  done

  # Independent canonical publication-order sentinel.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/publication_independent.f90" -o "$OUT/publication.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/publication.o" -o "$OUT/publication"
  "$OUT/publication" > "$OUT/publication.txt" 2>&1 || { cat "$OUT/publication.txt" >&2; fail "publication O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/publication.txt" || fail "publication order O$opt"

  echo "FMQ29_O${opt}=PASS"
done

cmp -s "$BUILD/o0/restart_negative.txt" "$BUILD/o2/restart_negative.txt" || fail 'restart negative O0/O2 transcript mismatch'
cmp -s "$BUILD/o0/composition.txt" "$BUILD/o2/composition.txt" || fail 'composition O0/O2 transcript mismatch'
cmp -s "$BUILD/o0/publication.txt" "$BUILD/o2/publication.txt" || fail 'publication O0/O2 transcript mismatch'

echo 'FMQ29_RESTART_NEGATIVE_MATRIX=PASS_O0_O2'
echo 'FMQ29_HELDOUT_PARALLEL_RESTART_COMPOSITION=PASS_O0_O2'
echo 'FMQ29_PARALLEL_PRESERVATION=PASS_O0_O2'
echo 'FMQ29_CANONICAL_PUBLICATION_ORDER=PASS_O0_O2'
echo 'FMQ29_HARD_MASS_CONSERVATION=PASS_O0_O2'
echo 'FMQ29_O0_O2_SCIENTIFIC_OUTPUT_IDENTITY=PASS'
echo 'FMQ29_PRODUCTION_CHANGE=NONE'
echo 'FMQ29_DECISION=INDEPENDENT_COMPOSITION_GATE_PASS'
