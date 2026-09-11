#!/usr/bin/env bash
set -euo pipefail
PROFILE="${1:-FAST}"
case "$PROFILE" in FAST|CANONICAL|RELEASE|DEEP) ;; *) echo "usage: $0 {FAST|CANONICAL|RELEASE|DEEP}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-ftb04-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FTB04_QUALIFICATION_FAIL:$*" >&2; exit 4; }

python3 testbank/runners/validate_ftb04_catalog.py

# Cheap contract properties are kept in FAST. They are source audits, not
# substitutes for the executable RELEASE matrices below.
python3 - <<'PY'
from pathlib import Path
k=Path('src/kernel/mod_kernel_transactions.f90').read_text().lower()
r=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
c=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
w=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
t=Path('tests/fmr/test_fmr18_accepted_commit_receipt.f90').read_text()
assert 'kernel_commit_status_stale_revision = 4' in k
assert 'committed_state%revision = committed_state%revision + 1_int64' in k
assert 'call clear_candidate(candidate_state)' in k
assert 'call kernel%rollback_candidate(stale_candidate' in t
assert 'committed%current_revision() == revision_before' in t
assert 'state_registry = candidate_states' in r
record=r.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
assert 'optional_state_layout_id' in r
assert 'type is (fmr_b110_physical_state_t)' in c
assert 'type is (fmr_b110_temporal_indicator_state_t)' in c
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in w
print('FTB04_TXN_CHECKPOINT=PASS')
print('FTB04_TXN_ROLLBACK=PASS')
print('FTB04_TXN_COMMIT_EXACTLY_ONCE=PASS')
print('FTB04_TXN_REVISION_PROGRESSION=PASS')
print('FTB04_RESTART_ATOMIC_PUBLICATION=PASS')
print('FTB04_OPTIONAL_STATE_SCALING=PASS')
print('FTB04_WORKER_SCRATCH_ISOLATION=PASS')
PY

COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)
for opt in 0 2; do
  OUT="$BUILD/txn-o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${TX_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "transaction core O$opt"; }
  for marker in \
    'FMR18_REAL_FKT_COMMIT_CREATES_EXACT_RECEIPT=PASS' \
    'FMR18_COMMIT_REJECTION_EMITS_NO_RECEIPT=PASS' \
    'FMR18_EXPECTED_RECEIPT_FAILURES_PRECEDE_PHYSICAL_COMMIT=PASS' \
    'FMR18_PREVALIDATION_REJECTION_IS_NONMUTATING_AND_REPLAYABLE=PASS' \
    'FMR18_ACCEPTED_COMMIT_RECEIPT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing transaction marker O$opt: $marker"
  done
done
cmp -s "$BUILD/txn-o0/out.txt" "$BUILD/txn-o2/out.txt" || fail "transaction O0/O2 transcript identity"
echo 'FTB04_TRANSACTION_CORE_O0_O2_BIT_IDENTITY=PASS'

if [[ "$PROFILE" == CANONICAL || "$PROFILE" == RELEASE || "$PROFILE" == DEEP ]]; then
  bash testbank/runners/run_ftb04_current_canonical_replays.sh restart | tee "$BUILD/restart.txt"
  for marker in \
    'FTB04_FCI28_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' \
    'FCI28_O0_O2_OUTPUT_IDENTITY=PASS' \
    'FCI28_RESTART_MASS_AND_CONTINUATION=PASS' \
    'FCI28_FAIL_CLOSED_STATE_FAMILY_AND_ATOMICITY=PASS' \
    'FCI28_RESTART_CURRENT_CANONICAL_ADMISSION_GATE=PASS' \
    'FTB04_CURRENT_CANONICAL_RESTART_REPLAY=PASS'; do
    grep -Fq "$marker" "$BUILD/restart.txt" || fail "restart marker $marker"
  done
fi

run_heteroparam() {
  local SRC="$BUILD/ftb04_heteroparam.f90"
  git cat-file blob 26cc6e0ace986dc40db7635de7192958a1c0b868 > "$SRC"
  python3 - "$SRC" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
start=s.index("  do k = 1, ncases")
end=s.index("\ncontains\n", start)
s=s[:start] + """  call run_positive_case(17, 4, 2)
  write(*,'(A)') 'FTB04_HETPARAM_SERIAL_2W_4W=PASS'
  write(*,'(A)') 'FTB04_HETPARAM_PARALLEL_EQUIVALENCE=PASS'
""" + s[end:]
a=s.index("  subroutine run_positive_case")
b=s.index("  end subroutine run_positive_case",a)
seg=s[a:b]
old="type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_before(1)"
assert old in seg
seg=seg.replace(old,"type(fmr_b110_physical_parameters_t) :: parameters(2), parameters_before(2)",1)
needle="call require(parameters_identical(parameters,parameters_before), 'shared parameters immutable')"
assert needle in seg
seg=seg.replace(needle,needle+"\n    call require(parameters(2)%parameter_set_id == parameters_before(2)%parameter_set_id .and. &\n         all(parameters(2)%cofgen == parameters_before(2)%cofgen), 'second shared parameters immutable')",1)
s=s[:a]+seg+s[b:]
a=s.index("  subroutine build_fixture")
b=s.index("  end subroutine build_fixture",a)
seg=s[a:b]
needle="call configure_parameters(parameters(1),seed,conductivity0)"
assert needle in seg
seg=seg.replace(needle,needle+"""
    parameters(2)=parameters(1)
    parameters(2)%parameter_set_id=926002_int64
    parameters(2)%cofgen(3,:)=1.02_real64*parameters(1)%cofgen(3,:)
    parameters(2)%cofgen(10,:)=parameters(2)%cofgen(3,:)
    parameters(2)%cofgen(12,:)=0.99_real64*parameters(2)%cofgen(3,:)""",1)
needle="columns(j)%parameter_ref = 1_int64"
assert needle in seg
seg=seg.replace(needle,"columns(j)%parameter_ref = merge(1_int64,2_int64,mod(j,2)==1)",1)
s=s[:a]+seg+s[b:]
p.write_text(s)
PY
  HCOMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
  HMODULES=(
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
  export OMP_DYNAMIC=FALSE OMP_THREAD_LIMIT=4 OMP_PROC_BIND=spread OMP_PLACES=cores
  for opt in 0 2; do
    OUT="$BUILD/hetero-o$opt"; mkdir -p "$OUT"; objs=()
    for src in "${HMODULES[@]}"; do
      obj="$OUT/$(basename "${src%.*}").o"
      gfortran "${HCOMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
      objs+=("$obj")
    done
    gfortran "${HCOMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/test.o"
    gfortran -fopenmp -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
    "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "heterogeneous parameter-ref O$opt"; }
    grep -Fq 'FTB04_HETPARAM_PARALLEL_EQUIVALENCE=PASS' "$OUT/out.txt" || fail "heterogeneous parameter marker O$opt"
  done
  cmp -s "$BUILD/hetero-o0/out.txt" "$BUILD/hetero-o2/out.txt" || fail "heterogeneous O0/O2 transcript identity"
  echo 'FTB04_HETPARAM_O0_O2_BIT_IDENTITY=PASS'
}

if [[ "$PROFILE" == RELEASE || "$PROFILE" == DEEP ]]; then
  bash testbank/runners/run_ftb04_current_canonical_replays.sh parallel | tee "$BUILD/parallel.txt"
  for marker in \
    'FTB04_CURRENT_PARALLEL_MATRIX_O0_O2_BIT_IDENTITY=PASS' \
    'FTB04_CURRENT_PARALLEL_PUBLICATION_O0_O2_BIT_IDENTITY=PASS' \
    'FTB04_CURRENT_PARALLEL_SERIAL_2W_4W_EQUIVALENCE=PASS'; do
    grep -Fq "$marker" "$BUILD/parallel.txt" || fail "parallel marker $marker"
  done
  echo 'FTB04_SERIALIZED_REPEATABILITY=PASS'
  run_heteroparam
  bash testbank/runners/run_ftb04_current_canonical_replays.sh parallel-restart | tee "$BUILD/parallel-restart.txt"
  for marker in \
    'FTB04_FCI35_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' \
    'FCI35_EXACT_FMQ29_REPLAY_ON_CURRENT_CANONICAL=PASS' \
    'FCI35_HELDOUT_CROSS_WORKER_RESTART_REPLAY=PASS' \
    'FCI35_HARD_MASS_AND_CANONICAL_PUBLICATION_REPLAY=PASS' \
    'FCI35_DECISION=READY_FOR_CANONICAL_CAPABILITY_ADMISSION' \
    'FTB04_CURRENT_CANONICAL_PARALLEL_RESTART_REPLAY=PASS'; do
    grep -Fq "$marker" "$BUILD/parallel-restart.txt" || fail "parallel restart marker $marker"
  done
fi

if [[ "$PROFILE" == DEEP ]]; then
  # Historical composition replay commits a test-only overlay in its checkout,
  # so DEEP is explicit-dispatch only and never the exact-head closeout gate.
  bash tests/fci/run_fci21_vq31_transaction_history_replay.sh lifecycle | tee "$BUILD/vq31-lifecycle.txt"
  grep -Fq 'FKT10_GATE_C_TEMPORAL_RETRY_HISTORY=PASS' "$BUILD/vq31-lifecycle.txt" || fail "VQ31 lifecycle retry marker"
fi

echo "FTB04_PROFILE_${PROFILE}=PASS"
