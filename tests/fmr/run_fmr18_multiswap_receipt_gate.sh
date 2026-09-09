#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr18-gate-c-$$"
FMR18_BASE="9f89d3dc9700378b80439e137ed64a95e5d575fa"
FMR05_QUAL="qualification/f-vq15-fmr05-serialized-multiswap"
FCI19_PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
FCI19_CANDIDATE_A="4a792636ef73d25c671c5e0953cefd11978cd0ec"
EXPECTED_FMR05_TEST_BLOB="51dc410308c1d0e6a8aa8c7ad26d08b87333d0a1"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() {
  echo "FMR18_GATE_C_FAIL $*" >&2
  exit 1
}

cat > "$BUILD/expected-source-delta.txt" <<'EOF'
src/runtime/mod_fmr_accepted_commit_receipt.f90
src/runtime/mod_fmr_serialized_multiswap_runtime.f90
EOF
git diff --name-only "$FMR18_BASE"..HEAD -- src | sort > "$BUILD/actual-source-delta.txt"
diff -u "$BUILD/expected-source-delta.txt" "$BUILD/actual-source-delta.txt" || fail "unexpected production source delta"
echo 'FMR18C_EXACT_TWO_FILE_SOURCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
receipt = Path('src/runtime/mod_fmr_accepted_commit_receipt.f90').read_text(encoding='utf-8').lower()
runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text(encoding='utf-8').lower()
for forbidden in ['wofost', 'snow_process', 'irrigation_process', 'root_water_uptake_process']:
    assert forbidden not in receipt, f'domain dependency in generic receipt: {forbidden}'
start = runtime.index('type, public :: fmr_serialized_column_result_t')
end = runtime.index('end type fmr_serialized_column_result_t', start)
assert 'receipt' not in runtime[start:end], 'receipt state leaked into every column result'
for required in [
    'receipt_column_ids', 'commit_receipts', 'fmr_commit_candidate_with_receipt',
    'fmr_commit_candidate(transaction_control', 'fmr_serial_dispatch_receipt_request_rejected',
    'receipt_request_valid', 'find_receipt_slot'
]:
    assert required in runtime, f'missing Gate C runtime token: {required}'
assert runtime.index('receipt_request_valid') < runtime.index('call backend%initialize'), 'receipt validation must precede backend init'
print('FMR18C_GENERIC_RUNTIME_BOUNDARY=PASS')
print('FMR18C_NO_PER_COLUMN_RECEIPT_STATE=PASS')
print('FMR18C_NO_RECEIPT_COMMIT_ROUTE_RETAINED=PASS')
print('FMR18C_RECEIPT_REQUEST_PREVALIDATION_PRECEDES_BACKEND=PASS')
PY

# Rehydrate the exact historical F-MR05 physical fixture source. Its old main
# contains admission expectations that were superseded by later root/snow work,
# so create a disposable Gate C main while retaining its exact setup and
# comparison helper bodies.
git show "$FMR05_QUAL:tests/fmr/test_fmr05_serialized_multiswap.f90" > "$BUILD/fmr05-original.f90"
[[ "$(git hash-object "$BUILD/fmr05-original.f90")" == "$EXPECTED_FMR05_TEST_BLOB" ]] || fail "historical F-MR05 fixture blob mismatch"
git show "$FMR05_QUAL:tests/fmr/mod_fmr04_fixed_top_provider.f90" > "$BUILD/mod_fmr04_fixed_top_provider.f90"
git show "$FCI19_PRESERVATION_HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90" > "$BUILD/fsi04_real_headcalc_stubs.f90"

python3 - "$BUILD/fmr05-original.f90" "$BUILD/fmr18-multiswap-receipt.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
first_call = src.index('  call execute_case(')
contains = src.index('\ncontains\n')
prefix = src[:first_call]
helpers = src[contains + len('\ncontains\n'):]

old_use = "  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t\n"
new_use = ("  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t\n"
           "  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t\n"
           "  use mod_fmr_serialized_multiswap_runtime, only: FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED\n")
assert prefix.count(old_use) == 1
prefix = prefix.replace(old_use, new_use, 1)

extra_decl = '''  type(fmr_accepted_commit_receipt_t), allocatable :: receipts_a(:), receipts_a2(:), receipts_fail(:), receipts_invalid(:)\n  integer(int64), parameter :: requested_ids(3) = [505008_int64, 505001_int64, 505003_int64]\n  integer(int64), parameter :: failure_ids(2) = [505001_int64, 505004_int64]\n  integer(int64), parameter :: duplicate_ids(2) = [505001_int64, 505001_int64]\n  integer(int64), parameter :: unknown_ids(1) = [999999_int64]\n  integer :: bad_result_index\n\n'''

main = '''  ! B: uninstrumented reference route on the current composition tree.\n  call execute_case(8, 3, .false., 0, .false., baseline_results, baseline_diag, baseline_aggregate, &\n       baseline_states, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate C baseline dispatch')\n\n  ! A: same physical run with sparse receipts in deliberately non-dispatch order.\n  call execute_receipt_case(8, 3, .false., 0, .false., requested_ids, 0, trial_results, trial_diag, trial_aggregate, &\n       trial_states, receipts_a, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate C receipt dispatch')\n  call require(result_sets_identical(baseline_results, trial_results), 'receipt route result identity')\n  call require(state_sets_identical(baseline_states, trial_states), 'receipt route committed-state identity')\n  call require(same_bits(baseline_aggregate%aggregate_unrounded_mass_residual, &\n       trial_aggregate%aggregate_unrounded_mass_residual), 'receipt route aggregate mass identity')\n  call require(size(receipts_a) == size(requested_ids), 'sparse receipt output shape')\n  call validate_receipt(receipts_a(1), requested_ids(1), 0_int64, 1_int64, t0, t1)\n  call validate_receipt(receipts_a(2), requested_ids(2), 0_int64, 1_int64, t0, t1)\n  call validate_receipt(receipts_a(3), requested_ids(3), 0_int64, 1_int64, t0, t1)\n  write(*,'(A)') 'FMR18C_SPARSE_REQUESTED_RECEIPTS_EXACT=PASS'\n  write(*,'(A)') 'FMR18C_NO_RECEIPT_ROUTE_PHYSICAL_AND_MASS_IDENTITY=PASS'\n\n  ! B then A again: receipt instrumentation must not perturb deterministic replay.\n  call execute_case(8, 3, .false., 0, .false., single_results, single_diag, single_aggregate, &\n       single_states, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate C middle no-receipt dispatch')\n  call execute_receipt_case(8, 3, .false., 0, .false., requested_ids, 0, failure_results, failure_diag, failure_aggregate, &\n       failure_states, receipts_a2, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate C repeated receipt dispatch')\n  call require(result_sets_identical(trial_results, failure_results), 'A-B-A receipt result replay')\n  call require(state_sets_identical(trial_states, failure_states), 'A-B-A receipt state replay')\n  call require(receipt_sets_identical(receipts_a, receipts_a2), 'A-B-A receipt provenance replay')\n  write(*,'(A)') 'FMR18C_A_B_A_RECEIPT_REPLAY=PASS'\n\n  ! A requested column that fails routing must not receive a ready receipt; a\n  ! neighboring accepted requested column still receives exactly one.\n  call execute_receipt_case(8, 3, .false., 4, .false., failure_ids, 0, duplicate_results, duplicate_diag, &\n       duplicate_aggregate, duplicate_states, receipts_fail, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate C isolated routing failure dispatch')\n  call require(receipts_fail(1)%ready(), 'accepted requested neighbor receipt')\n  call require(.not. receipts_fail(2)%ready(), 'rejected requested column no receipt')\n  bad_result_index = result_index(duplicate_results, failure_ids(2))\n  call require(bad_result_index > 0, 'bad requested result found')\n  call require(.not. duplicate_results(bad_result_index)%committed, 'bad requested result not committed')\n  call require(duplicate_states(4)%current_revision() == 0_int64, 'bad requested state unchanged')\n  write(*,'(A)') 'FMR18C_REJECTED_REQUESTED_COLUMN_EMITS_NO_RECEIPT=PASS'\n\n  ! Every sparse request-shape error is rejected before any column mutation.\n  call execute_receipt_case(2, 2, .false., 0, .false., duplicate_ids, 0, duplicate_results, duplicate_diag, &\n       duplicate_aggregate, duplicate_states, receipts_invalid, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'duplicate receipt ids rejected')\n  call require(size(receipts_invalid) == 0, 'duplicate request no receipt allocation')\n  call require(all_revisions_zero(duplicate_states), 'duplicate receipt request no state mutation')\n\n  call execute_receipt_case(2, 2, .false., 0, .false., unknown_ids, 0, duplicate_results, duplicate_diag, &\n       duplicate_aggregate, duplicate_states, receipts_invalid, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'unknown receipt id rejected')\n  call require(all_revisions_zero(duplicate_states), 'unknown receipt request no state mutation')\n\n  call execute_receipt_case(2, 2, .false., 0, .false., requested_ids(1:1), 1, duplicate_results, duplicate_diag, &\n       duplicate_aggregate, duplicate_states, receipts_invalid, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'ids without output rejected')\n  call require(all_revisions_zero(duplicate_states), 'ids-only request no state mutation')\n\n  call execute_receipt_case(2, 2, .false., 0, .false., requested_ids(1:1), 2, duplicate_results, duplicate_diag, &\n       duplicate_aggregate, duplicate_states, receipts_invalid, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'output without ids rejected')\n  call require(all_revisions_zero(duplicate_states), 'output-only request no state mutation')\n  write(*,'(A)') 'FMR18C_INVALID_SPARSE_REQUESTS_FAIL_BEFORE_STATE_MUTATION=PASS'\n\n  write(*,'(A)') 'FMR18_MULTISWAP_RECEIPT_TEST PASS'\n\n'''

receipt_helper = '''  subroutine execute_receipt_case(n, batch_size, reverse_order, bad_index, duplicate_state, receipt_ids, request_mode, &\n                                  results, diagnostics, aggregate, states, receipts, dispatch_status)\n    integer, intent(in) :: n, batch_size, bad_index, request_mode\n    logical, intent(in) :: reverse_order, duplicate_state\n    integer(int64), intent(in) :: receipt_ids(:)\n    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)\n    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)\n    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate\n    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)\n    type(fmr_accepted_commit_receipt_t), allocatable, intent(out) :: receipts(:)\n    integer, intent(out) :: dispatch_status\n\n    type(fmr_logical_column_t), allocatable :: columns(:)\n    type(fmr_template_t) :: templates(2)\n    type(fmr_b110_physical_parameters_t) :: parameters(2)\n    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)\n    type(fmr_b110_physical_state_t) :: initial_state\n    type(fmr04_fixed_flux_top_provider_t), target :: top_provider\n    type(canonical_numerical_config_t) :: config\n    type(fmr_logical_column_t) :: tmp_column\n    real(real64) :: conductivity0\n    logical :: ok\n    integer :: i, left, right\n\n    call configure_templates(templates)\n    call configure_parameters(parameters(1), initial_state, conductivity0)\n    parameters(2) = parameters(1)\n    parameters(2)%parameter_set_id = 50502_int64\n    call configure_transaction(config)\n\n    allocate(columns(n), forcings(n), states(n))\n    do i = 1, n\n      columns(i)%column_id = 505000_int64 + int(i, int64)\n      if (mod(i,2) == 1) then\n        columns(i)%template_id = templates(1)%template_id\n      else\n        columns(i)%template_id = templates(2)%template_id\n      end if\n      columns(i)%parameter_ref = 1_int64\n      columns(i)%state_handle = int(i, int64)\n      columns(i)%forcing_handle = int(i, int64)\n      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE\n      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))\n      call fmr_new_b110_committed_state(states(i), columns(i)%column_id, initial_state, t0, ok)\n      call require(ok, 'Gate C committed-state initialization')\n    end do\n\n    if (bad_index >= 1 .and. bad_index <= n) columns(bad_index)%parameter_ref = 99_int64\n    if (duplicate_state .and. n >= 2) columns(2)%state_handle = columns(1)%state_handle\n    if (reverse_order) then\n      do left = 1, n/2\n        right = n + 1 - left\n        tmp_column = columns(left)\n        columns(left) = columns(right)\n        columns(right) = tmp_column\n      end do\n    end if\n\n    legacy_qdra = 12345.0_real64\n    legacy_qssdi = -54321.0_real64\n    legacy_qrot = 0.0_real64\n    swmacro = 0\n    melt = 0.0_real64\n\n    select case (request_mode)\n    case (0)\n      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &\n           t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status, &\n           receipt_column_ids=receipt_ids, commit_receipts=receipts)\n    case (1)\n      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &\n           t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status, receipt_column_ids=receipt_ids)\n      if (.not. allocated(receipts)) allocate(receipts(0))\n    case (2)\n      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &\n           t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status, commit_receipts=receipts)\n    case default\n      error stop 'FMR18 Gate C invalid test request mode'\n    end select\n  end subroutine execute_receipt_case\n\n  subroutine validate_receipt(receipt, lineage, origin_revision, committed_revision, expected_t0, expected_t1)\n    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt\n    integer(int64), intent(in) :: lineage, origin_revision, committed_revision\n    real(real64), intent(in) :: expected_t0, expected_t1\n    real(real64) :: actual_t0, actual_t1\n    logical :: available\n\n    call require(receipt%ready(), 'requested receipt ready')\n    call require(receipt%current_lineage_id() == lineage, 'receipt lineage identity')\n    call require(receipt%origin_revision() == origin_revision, 'receipt origin revision identity')\n    call require(receipt%committed_revision() == committed_revision, 'receipt committed revision identity')\n    call receipt%origin_interval(actual_t0, actual_t1, available)\n    call require(available .and. same_bits(actual_t0, expected_t0) .and. same_bits(actual_t1, expected_t1), &\n         'receipt interval identity')\n  end subroutine validate_receipt\n\n  logical function receipt_sets_identical(left, right) result(equal)\n    type(fmr_accepted_commit_receipt_t), intent(in) :: left(:), right(:)\n    integer :: i\n    real(real64) :: lt0, lt1, rt0, rt1\n    logical :: la, ra\n\n    equal = size(left) == size(right)\n    if (.not. equal) return\n    do i = 1, size(left)\n      if (left(i)%ready() .neqv. right(i)%ready()) then\n        equal = .false.; return\n      end if\n      if (.not. left(i)%ready()) cycle\n      if (left(i)%current_lineage_id() /= right(i)%current_lineage_id() .or. &\n          left(i)%origin_revision() /= right(i)%origin_revision() .or. &\n          left(i)%committed_revision() /= right(i)%committed_revision()) then\n        equal = .false.; return\n      end if\n      call left(i)%origin_interval(lt0, lt1, la)\n      call right(i)%origin_interval(rt0, rt1, ra)\n      if (.not. la .or. .not. ra .or. .not. same_bits(lt0,rt0) .or. .not. same_bits(lt1,rt1)) then\n        equal = .false.; return\n      end if\n    end do\n  end function receipt_sets_identical\n\n  logical function all_revisions_zero(states) result(ok)\n    type(kernel_committed_state_t), intent(in) :: states(:)\n    integer :: i\n    ok = .true.\n    do i = 1, size(states)\n      if (states(i)%current_revision() /= 0_int64) then\n        ok = .false.; return\n      end if\n    end do\n  end function all_revisions_zero\n\n'''

out = prefix + extra_decl + main + 'contains\n\n' + receipt_helper + helpers
Path(sys.argv[2]).write_text(out, encoding='utf-8')
PY

echo 'FMR18C_FMR05_FIXTURE_REHYDRATED_AND_CURRENT_ADMISSION_MAIN_BUILT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/fsi04_real_headcalc_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  "$BUILD/mod_fmr04_fixed_top_provider.f90"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmr18-multiswap-receipt.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "Gate C O$opt executable"; }
  for marker in \
    'FMR18C_SPARSE_REQUESTED_RECEIPTS_EXACT=PASS' \
    'FMR18C_NO_RECEIPT_ROUTE_PHYSICAL_AND_MASS_IDENTITY=PASS' \
    'FMR18C_A_B_A_RECEIPT_REPLAY=PASS' \
    'FMR18C_REJECTED_REQUESTED_COLUMN_EMITS_NO_RECEIPT=PASS' \
    'FMR18C_INVALID_SPARSE_REQUESTS_FAIL_BEFORE_STATE_MUTATION=PASS' \
    'FMR18_MULTISWAP_RECEIPT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "FMR18C_O${opt}=PASS"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail "Gate C O0/O2 output mismatch"
echo 'FMR18C_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

# The accepted-window crop oracle itself is independent of Gate C but must keep
# its exact transcript on this composition tree.
for opt in 0 2; do
  OUT="$BUILD/fwo$opt"
  mkdir -p "$OUT"
  gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    src/crop/mod_wofost_actual_biomass_state.f90 \
    src/crop/mod_wofost_crop_owner_state.f90 \
    src/crop/mod_wofost_one_day_structural_evolution.f90 \
    src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 \
    tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
done
cmp "$BUILD/fwo0/out.txt" "$BUILD/fwo2/out.txt" || fail "F-WOF34 O0/O2 mismatch"
FWO_SHA="$(sha256sum "$BUILD/fwo0/out.txt" | awk '{print $1}')"
[[ "$FWO_SHA" == "$EXPECTED_FWO34_OUTPUT_SHA" ]] || fail "F-WOF34 transcript changed $FWO_SHA"
echo "FMR18C_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS SHA256=$FWO_SHA"

# Reexecute F-CI19 composition preservation on the current tree. Adapt only the
# disposable source-identity boundary to admit the already-qualified four F-WOF
# donors plus the two explicit F-MR18 files, and add the receipt module to any
# current MultiSWAP compile sequence. Historical gates themselves remain intact.
git archive "$FCI19_PRESERVATION_HEAD" tests tools integration/f-kt | tar -x -C "$ROOT"
FCI19_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
FCI19_V2="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh"
python3 - "$FCI19_BASE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
allowed='''cat > "$BUILD/fmr18c-allowed-source-delta.txt" <<'EOF'\nsrc/crop/mod_wofost_actual_biomass_state.f90\nsrc/crop/mod_wofost_crop_owner_state.f90\nsrc/crop/mod_wofost_one_day_structural_evolution.f90\nsrc/runtime/mod_fmr_accepted_commit_receipt.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_wofost_accepted_window_lineage.f90\nEOF\ngit diff --name-only "$CANDIDATE"..HEAD -- src reference | sort > "$BUILD/fmr18c-actual-source-delta.txt"\ndiff -u "$BUILD/fmr18c-allowed-source-delta.txt" "$BUILD/fmr18c-actual-source-delta.txt" || fail "F-MR18 Gate C source delta exceeds qualified closure"'''
for old, marker in [
 ('git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "Candidate A production/reference source changed"', 'FMR18C_FCI19_EXACT_SOURCE_DELTA=PASS'),
 ('git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "production/reference source drift during qualification"', 'FMR18C_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS')
]:
    if old not in s: raise SystemExit(f'missing F-CI19 source identity anchor: {old}')
    s=s.replace(old, allowed+f"\necho '{marker}'", 1)
needle='  src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
if needle in s:
    s=s.replace(needle, '  src/runtime/mod_fmr_accepted_commit_receipt.f90\n'+needle)
p.write_text(s, encoding='utf-8')
PY
bash "$FCI19_V2" > "$BUILD/fci19.out" 2>&1 || { cat "$BUILD/fci19.out" >&2; fail "F-CI19 preservation replay"; }
grep -Fq 'FCI19_GATE PASS_CANDIDATE_A_COMPOSITION_PRESERVATION' "$BUILD/fci19.out"
grep -Fq 'FCI19_HARD_MASS_PRESERVATION=PASS' "$BUILD/fci19.out"
grep -Fq 'FCI19_ROLLBACK_REPLAY_PRESERVATION=PASS' "$BUILD/fci19.out"
grep -Fq 'FCI19_O0_O2_PRESERVATION=PASS' "$BUILD/fci19.out"
grep -Fq 'FMR18C_FCI19_EXACT_SOURCE_DELTA=PASS' "$BUILD/fci19.out"
grep -Fq 'FMR18C_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS' "$BUILD/fci19.out"
echo 'FMR18C_FCI19_SEMANTIC_PRESERVATION=PASS'

echo 'FMR18_MULTISWAP_RECEIPT_GATE PASS'
