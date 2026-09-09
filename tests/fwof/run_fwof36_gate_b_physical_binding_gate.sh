#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof36-gate-b-physical-$$"
FMR18_CLOSEOUT="ebf051bbf7e57f77d115287a9ba02fc987a255bc"
FMR05_QUAL="origin/qualification/f-vq15-fmr05-serialized-multiswap"
FCI19_PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
EXPECTED_FMR05_TEST_BLOB="51dc410308c1d0e6a8aa8c7ad26d08b87333d0a1"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() {
  echo "FWOF36_GATE_B_FAIL $*" >&2
  exit 1
}

cat > "$BUILD/expected-source-delta.txt" <<'EOF'
src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
src/runtime/mod_fmr_wofost_physical_trial_binding.f90
EOF
git diff --name-only "$FMR18_CLOSEOUT"..HEAD -- src | sort > "$BUILD/actual-source-delta.txt"
diff -u "$BUILD/expected-source-delta.txt" "$BUILD/actual-source-delta.txt" || fail "unexpected Gate B production source delta"
echo 'FWOF36_GATE_B_EXACT_TWO_FILE_SOURCE_DELTA=PASS'

# Rehydrate the exact qualified F-MR05 physical fixture. Gate B changes only the
# disposable main and two fixture switches: root extraction is enabled and a
# small deterministic nonzero root sink is physically supplied to Richards.
git show "$FMR05_QUAL:tests/fmr/test_fmr05_serialized_multiswap.f90" > "$BUILD/fmr05-original.f90"
[[ "$(git hash-object "$BUILD/fmr05-original.f90")" == "$EXPECTED_FMR05_TEST_BLOB" ]] || fail "historical F-MR05 fixture blob mismatch"
git show "$FMR05_QUAL:tests/fmr/mod_fmr04_fixed_top_provider.f90" > "$BUILD/mod_fmr04_fixed_top_provider.f90"
git show "$FCI19_PRESERVATION_HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90" > "$BUILD/fsi04_real_headcalc_stubs.f90"

python3 - "$BUILD/fmr05-original.f90" "$BUILD/fwof36-gate-b.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
first_call = src.index('  call execute_case(')
contains = src.index('\ncontains\n')
prefix = src[:first_call]
helpers = src[contains + len('\ncontains\n'):]

old_use = "  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t\n"
new_use = (old_use +
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\n"
"  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t\n"
"  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &\n"
"       fmr_wofost_crop_event_token_t, open_wofost_accepted_window, prepare_wofost_crop_event_delivery, &\n"
"       FMR_WOFOST_LINEAGE_OK\n"
"  use mod_fmr_wofost_physical_trial_binding, only: fmr_run_serialized_multiswap_with_wofost_integrals, &\n"
"       FMR_WOF36_BINDING_OK, FMR_WOF36_BINDING_INVALID_CROP_INPUT, &\n"
"       FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED\n")
assert prefix.count(old_use) == 1
prefix = prefix.replace(old_use, new_use, 1)

old_root_active = '    parameters%root_extraction_active = .false.\n'
assert helpers.count(old_root_active) == 1
helpers = helpers.replace(old_root_active, '    parameters%root_extraction_active = .true.\n', 1)
old_root_sink = '      forcing%root_extraction_sink(i) = 0.0_real64\n'
assert helpers.count(old_root_sink) == 1
helpers = helpers.replace(old_root_sink, '      forcing%root_extraction_sink(i) = scale*1.0e-8_real64*real(i,real64)\n', 1)

extra_decl = '''  integer(int64), parameter :: bind_ids(2) = [505001_int64, 505003_int64]\n  integer(int64), allocatable :: no_bind_ids(:)\n  type(fmr_wofost_accepted_window_t), allocatable :: windows_a(:), windows_a2(:), windows_reverse(:), windows_fail(:), windows_empty(:)\n  real(real64), allocatable :: qrot_a(:), ptra_a(:), qrot_a2(:), ptra_a2(:), qrot_reverse(:), ptra_reverse(:), &\n       qrot_fail(:), ptra_fail(:), qrot_empty(:), ptra_empty(:)\n  integer :: binding_status\n\n'''

main = '''  allocate(no_bind_ids(0))\n\n  ! Reference B: current physical route with exactly the same nonzero root sink.\n  call execute_case(4, 2, .false., 0, .false., baseline_results, baseline_diag, baseline_aggregate, &\n       baseline_states, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate B physical baseline dispatch')\n\n  ! A: sparse WOFOST binding around the same physical route.\n  call execute_wofost_case(4, 2, .false., 0_int64, 0, 0, bind_ids, trial_results, trial_diag, trial_aggregate, &\n       trial_states, windows_a, qrot_a, ptra_a, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate B wrapper dispatch')\n  call require(binding_status == FMR_WOF36_BINDING_OK, 'Gate B wrapper binding status')\n  call require(result_sets_identical(baseline_results, trial_results), 'Gate B physical result identity')\n  call require(state_sets_identical(baseline_states, trial_states), 'Gate B committed-state identity')\n  call require(same_bits(baseline_aggregate%aggregate_unrounded_mass_residual, &\n       trial_aggregate%aggregate_unrounded_mass_residual), 'Gate B aggregate mass identity')\n  call validate_window_integral(windows_a(1), qrot_a(1), ptra_a(1), 'Gate B binding one')\n  call validate_window_integral(windows_a(2), qrot_a(2), ptra_a(2), 'Gate B binding two')\n  write(*,'(A)') 'FWOF36_GATE_B_PHYSICAL_AND_MASS_IDENTITY=PASS'\n  write(*,'(A)') 'FWOF36_GATE_B_EXACT_QROT_PTRA_INTEGRALS=PASS'\n\n  ! Batch size and input execution order must not alter state, results or integrals.\n  call execute_wofost_case(4, 1, .true., 0_int64, 0, 0, bind_ids, single_results, single_diag, single_aggregate, &\n       single_states, windows_reverse, qrot_reverse, ptra_reverse, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &\n       'Gate B reverse dispatch')\n  call require(result_sets_identical(trial_results, single_results), 'Gate B reverse result identity')\n  call require(state_sets_identical(trial_states, single_states), 'Gate B reverse state identity')\n  call validate_window_integral(windows_reverse(1), qrot_reverse(1), ptra_reverse(1), 'Gate B reverse one')\n  call validate_window_integral(windows_reverse(2), qrot_reverse(2), ptra_reverse(2), 'Gate B reverse two')\n  call require(same_bits(qrot_a(1), qrot_reverse(1)) .and. same_bits(qrot_a(2), qrot_reverse(2)), &\n       'Gate B reverse QROT identity')\n  call require(same_bits(ptra_a(1), ptra_reverse(1)) .and. same_bits(ptra_a(2), ptra_reverse(2)), &\n       'Gate B reverse PTRA identity')\n  write(*,'(A)') 'FWOF36_GATE_B_BATCH_AND_INPUT_ORDER_IDENTITY=PASS'\n\n  ! A-B-A replay with fresh state/window instances.\n  call execute_case(4, 3, .false., 0, .false., failure_results, failure_diag, failure_aggregate, &\n       failure_states, dispatch_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'Gate B middle B dispatch')\n  call execute_wofost_case(4, 2, .false., 0_int64, 0, 0, bind_ids, duplicate_results, duplicate_diag, duplicate_aggregate, &\n       duplicate_states, windows_a2, qrot_a2, ptra_a2, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &\n       'Gate B replay A dispatch')\n  call require(result_sets_identical(trial_results, duplicate_results), 'Gate B A-B-A result replay')\n  call require(state_sets_identical(trial_states, duplicate_states), 'Gate B A-B-A state replay')\n  call require(same_bits(qrot_a(1), qrot_a2(1)) .and. same_bits(qrot_a(2), qrot_a2(2)), &\n       'Gate B A-B-A QROT replay')\n  call require(same_bits(ptra_a(1), ptra_a2(1)) .and. same_bits(ptra_a(2), ptra_a2(2)), &\n       'Gate B A-B-A PTRA replay')\n  call validate_window_integral(windows_a2(1), qrot_a2(1), ptra_a2(1), 'Gate B replay one')\n  call validate_window_integral(windows_a2(2), qrot_a2(2), ptra_a2(2), 'Gate B replay two')\n  write(*,'(A)') 'FWOF36_GATE_B_A_B_A_REPLAY=PASS'\n\n  ! Invalid PTRA is rejected by the wrapper before physical publication.\n  call execute_wofost_case(4, 2, .false., 0_int64, 1, 0, bind_ids, failure_results, failure_diag, failure_aggregate, &\n       failure_states, windows_fail, qrot_fail, ptra_fail, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_INVALID_REQUEST, 'Gate B invalid PTRA dispatch')\n  call require(binding_status == FMR_WOF36_BINDING_INVALID_CROP_INPUT, 'Gate B invalid PTRA binding status')\n  call require(all_revisions_zero(failure_states), 'Gate B invalid PTRA no physical mutation')\n  call require(windows_fail(1)%interval_count() == 0 .and. windows_fail(2)%interval_count() == 0, &\n       'Gate B invalid PTRA zero window contribution')\n  write(*,'(A)') 'FWOF36_GATE_B_INVALID_PTRA_PRECOMMIT_ZERO_MUTATION=PASS'\n\n  ! Wrong accepted-window lineage is also detected before the physical call.\n  call execute_wofost_case(4, 2, .false., 0_int64, 0, 1, bind_ids, failure_results, failure_diag, failure_aggregate, &\n       failure_states, windows_fail, qrot_fail, ptra_fail, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_INVALID_REQUEST, 'Gate B window mismatch dispatch')\n  call require(binding_status == FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED, &\n       'Gate B window mismatch binding status')\n  call require(all_revisions_zero(failure_states), 'Gate B window mismatch no physical mutation')\n  call require(windows_fail(1)%interval_count() == 0 .and. windows_fail(2)%interval_count() == 0, &\n       'Gate B window mismatch zero contribution')\n  write(*,'(A)') 'FWOF36_GATE_B_WINDOW_MISMATCH_PRECOMMIT_ZERO_MUTATION=PASS'\n\n  ! A physically unroutable requested column receives no receipt and therefore\n  ! contributes zero; a neighboring accepted requested column still contributes once.\n  call execute_wofost_case(4, 2, .false., bind_ids(1), 0, 0, bind_ids, failure_results, failure_diag, failure_aggregate, &\n       failure_states, windows_fail, qrot_fail, ptra_fail, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &\n       'Gate B physical rejection dispatch')\n  call require(failure_states(1)%current_revision() == 0_int64, 'Gate B rejected selected physical state unchanged')\n  call require(windows_fail(1)%interval_count() == 0, 'Gate B rejected selected zero WOFOST contribution')\n  call require(windows_fail(2)%interval_count() == 1, 'Gate B accepted selected exactly one contribution')\n  call validate_window_integral(windows_fail(2), qrot_fail(2), ptra_fail(2), 'Gate B accepted neighbor')\n  write(*,'(A)') 'FWOF36_GATE_B_PHYSICAL_REJECTION_ZERO_CONTRIBUTION=PASS'\n\n  ! Empty sparse binding is a functional zero-cost path through the old runtime call.\n  call execute_wofost_case(4, 2, .false., 0_int64, 0, 0, no_bind_ids, failure_results, failure_diag, failure_aggregate, &\n       failure_states, windows_empty, qrot_empty, ptra_empty, dispatch_status, binding_status)\n  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &\n       'Gate B empty binding dispatch')\n  call require(result_sets_identical(baseline_results, failure_results), 'Gate B empty binding result identity')\n  call require(state_sets_identical(baseline_states, failure_states), 'Gate B empty binding state identity')\n  call require(size(windows_empty) == 0, 'Gate B empty binding no WOFOST state')\n  write(*,'(A)') 'FWOF36_GATE_B_EMPTY_BINDING_PHYSICAL_IDENTITY=PASS'\n\n  write(*,'(A)') 'FWOF36_GATE_B_PHYSICAL_BINDING_TEST PASS'\n\n'''

extra_helpers = r'''  subroutine execute_wofost_case(n, batch_size, reverse_order, routing_bad_column_id, invalid_ptra_slot, &
                                  mismatch_window_slot, binding_ids, results, diagnostics, aggregate, states, windows, &
                                  qrot_expected, ptra_expected, dispatch_status, binding_status)
    integer, intent(in) :: n, batch_size, invalid_ptra_slot, mismatch_window_slot
    logical, intent(in) :: reverse_order
    integer(int64), intent(in) :: routing_bad_column_id
    integer(int64), intent(in) :: binding_ids(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_wofost_accepted_window_t), allocatable, intent(out) :: windows(:)
    real(real64), allocatable, intent(out) :: qrot_expected(:), ptra_expected(:)
    integer, intent(out) :: dispatch_status, binding_status

    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(2)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: tmp_column
    type(crop_root_uptake_input_t), allocatable :: crop_inputs(:)
    type(kernel_checkpoint_t) :: checkpoint
    real(real64) :: conductivity0
    logical :: ok
    integer :: i, left, right, idx, sidx, fidx, alt_state, lineage_status

    call configure_templates(templates)
    call configure_parameters(parameters(1), initial_state, conductivity0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 50502_int64
    call configure_transaction(config)

    allocate(columns(n), forcings(n), states(n))
    do i = 1, n
      columns(i)%column_id = 505000_int64 + int(i, int64)
      if (mod(i,2) == 1) then
        columns(i)%template_id = templates(1)%template_id
      else
        columns(i)%template_id = templates(2)%template_id
      end if
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      call fmr_new_b110_committed_state(states(i), columns(i)%column_id, initial_state, t0, ok)
      call require(ok, 'Gate B committed-state initialization')
    end do

    if (reverse_order) then
      do left = 1, n/2
        right = n + 1 - left
        tmp_column = columns(left)
        columns(left) = columns(right)
        columns(right) = tmp_column
      end do
    end if

    allocate(windows(size(binding_ids)), crop_inputs(size(binding_ids)), &
             qrot_expected(size(binding_ids)), ptra_expected(size(binding_ids)))
    do i = 1, size(binding_ids)
      idx = find_column_position(binding_ids(i), columns)
      call require(idx > 0, 'Gate B binding column present')
      sidx = int(columns(idx)%state_handle)
      fidx = int(columns(idx)%forcing_handle)
      qrot_expected(i) = sum(forcings(fidx)%root_extraction_sink)
      ptra_expected(i) = 2.0_real64*qrot_expected(i)
      crop_inputs(i)%crop_emerged = .true.
      crop_inputs(i)%potential_transpiration = ptra_expected(i)
      crop_inputs(i)%rooted_nodes = 1
      allocate(crop_inputs(i)%cumulative_root_fraction(2))
      crop_inputs(i)%cumulative_root_fraction = [0.0_real64, 1.0_real64]

      if (i == mismatch_window_slot) then
        if (sidx == 1 .and. n >= 2) then
          alt_state = 2
        else
          alt_state = 1
        end if
        call states(alt_state)%capture_checkpoint(checkpoint, ok)
      else
        call states(sidx)%capture_checkpoint(checkpoint, ok)
      end if
      call require(ok, 'Gate B accepted-window checkpoint')
      call open_wofost_accepted_window(checkpoint, t1, windows(i), lineage_status)
      call require(lineage_status == FMR_WOFOST_LINEAGE_OK, 'Gate B accepted-window open')
    end do

    if (invalid_ptra_slot >= 1 .and. invalid_ptra_slot <= size(crop_inputs)) then
      crop_inputs(invalid_ptra_slot)%potential_transpiration = -1.0_real64
    end if
    if (routing_bad_column_id > 0_int64) then
      idx = find_column_position(routing_bad_column_id, columns)
      call require(idx > 0, 'Gate B bad routing column present')
      columns(idx)%backend_id = 999
    end if

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    call fmr_run_serialized_multiswap_with_wofost_integrals(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, batch_size, binding_ids, crop_inputs, windows, results, diagnostics, aggregate, &
         dispatch_status, binding_status)
  end subroutine execute_wofost_case

  integer function find_column_position(column_id, columns) result(index)
    integer(int64), intent(in) :: column_id
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer :: i
    index = 0
    do i = 1, size(columns)
      if (columns(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function find_column_position

  subroutine validate_window_integral(window, qrot_rate, ptra_rate, label)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    real(real64), intent(in) :: qrot_rate, ptra_rate
    character(len=*), intent(in) :: label
    type(wofost_accepted_window_aggregates_t) :: aggregates
    type(fmr_wofost_crop_event_token_t) :: token
    logical :: available
    integer :: status

    call require(window%interval_count() == 1 .and. window%complete() .and. window%event_due(), &
         trim(label)//' window complete')
    call prepare_wofost_crop_event_delivery(window, aggregates, token, available, status)
    call require(status == FMR_WOFOST_LINEAGE_OK .and. available .and. token%ready(), &
         trim(label)//' event available')
    call require(same_bits(aggregates%actual_root_uptake, qrot_rate*(t1-t0)), &
         trim(label)//' exact IQROT integral')
    call require(same_bits(aggregates%potential_transpiration, ptra_rate*(t1-t0)), &
         trim(label)//' exact IPTRA integral')
  end subroutine validate_window_integral

'''

Path(sys.argv[2]).write_text(prefix + extra_decl + main + '\ncontains\n' + extra_helpers + helpers, encoding='utf-8')
PY

echo 'FWOF36_GATE_B_REAL_PHYSICS_FIXTURE_MATERIALIZED=PASS'

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
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/runtime/mod_fmr_wofost_physical_trial_binding.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fwof36-gate-b.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "Gate B O$opt executable"; }
  for marker in \
    'FWOF36_GATE_B_PHYSICAL_AND_MASS_IDENTITY=PASS' \
    'FWOF36_GATE_B_EXACT_QROT_PTRA_INTEGRALS=PASS' \
    'FWOF36_GATE_B_BATCH_AND_INPUT_ORDER_IDENTITY=PASS' \
    'FWOF36_GATE_B_A_B_A_REPLAY=PASS' \
    'FWOF36_GATE_B_INVALID_PTRA_PRECOMMIT_ZERO_MUTATION=PASS' \
    'FWOF36_GATE_B_WINDOW_MISMATCH_PRECOMMIT_ZERO_MUTATION=PASS' \
    'FWOF36_GATE_B_PHYSICAL_REJECTION_ZERO_CONTRIBUTION=PASS' \
    'FWOF36_GATE_B_EMPTY_BINDING_PHYSICAL_IDENTITY=PASS' \
    'FWOF36_GATE_B_PHYSICAL_BINDING_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "FWOF36_GATE_B_O${opt}=PASS"
done

cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail "Gate B O0/O2 output mismatch"
echo 'FWOF36_GATE_B_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

# The F-WOF34 oracle must retain its exact transcript after the additive
# prevalidation helper. No historical oracle source is modified.
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
echo "FWOF36_GATE_B_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS SHA256=$FWO_SHA"

echo 'FWOF36_GATE_B_PHYSICAL_BINDING_GATE PASS'
