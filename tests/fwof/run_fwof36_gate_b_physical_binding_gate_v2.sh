#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/swap5-fwof36-gate-b-v2-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

python3 - "$ROOT/tests/fwof/run_fwof36_gate_b_physical_binding_gate.sh" "$TMP/gate.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')

# Add only qualification-harness names/helpers. Production source is untouched.
old = '''new_use = (old_use +
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
new = '''new_use = (old_use +
"  use mod_kernel_transactions, only: kernel_checkpoint_t\\n"
"  use mod_fmr_serialized_multiswap_runtime, only: FMR_SERIAL_DISPATCH_INVALID_REQUEST\\n"
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 generated-use anchor count={src.count(old)}')
src = src.replace(old, new, 1)

old = '"       FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED\\n")'
new = '"       FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED, FMR_WOF36_BINDING_TRIAL_REJECTED\\n")'
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 binding-status import anchor count={src.count(old)}')
src = src.replace(old, new, 1)

old = "extra_helpers = r'''  subroutine execute_wofost_case"
new = r'''extra_helpers = r''' + "'''" + r'''  subroutine diagnose_result_difference(left, right)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j
    do i = 1, size(left)
      j = result_index(right, left(i)%column_id)
      if (j == 0) then
        write(*,'(A,I0)') 'FWOF36_DIAG_MISSING_COLUMN=', left(i)%column_id
        cycle
      end if
      if (.not. column_results_identical(left(i), right(j))) then
        write(*,'(A,I0)') 'FWOF36_DIAG_COLUMN=', left(i)%column_id
        call diag_logical('KERNEL_STATUS', left(i)%kernel_status == right(j)%kernel_status)
        call diag_logical('COMMIT_STATUS', left(i)%commit_status == right(j)%commit_status)
        call diag_logical('COMPLETED', left(i)%completed .eqv. right(j)%completed)
        call diag_logical('COMMITTED', left(i)%committed .eqv. right(j)%committed)
        call diag_logical('SOLVER_EXECUTED', left(i)%solver_executed .eqv. right(j)%solver_executed)
        call diag_logical('SOLVER_ROUTE', trim(left(i)%solver_route) == trim(right(j)%solver_route))
        call diag_logical('SOLVER_ITERATIONS', left(i)%solver_iterations == right(j)%solver_iterations)
        call diag_logical('INITIAL_REVISION', left(i)%initial_revision == right(j)%initial_revision)
        call diag_logical('FINAL_REVISION', left(i)%final_revision == right(j)%final_revision)
        call diag_logical('FINAL_TIME_BOUND', left(i)%final_committed_time_bound .eqv. right(j)%final_committed_time_bound)
        call diag_logical('FINAL_TIME_BITS', same_bits(left(i)%final_committed_time, right(j)%final_committed_time))
        call diag_logical('MASS_COMPLETE', left(i)%mass%complete .eqv. right(j)%mass%complete)
        call diag_logical('MASS_MISSING_MASK', left(i)%mass%missing_contribution_mask == right(j)%mass%missing_contribution_mask)
        call diag_logical('MASS_ORIGIN_LINEAGE', left(i)%mass%origin_lineage_id == right(j)%mass%origin_lineage_id)
        call diag_logical('MASS_ORIGIN_REVISION', left(i)%mass%origin_revision == right(j)%mass%origin_revision)
        call diag_logical('MASS_ACCEPTED_COUNT', left(i)%mass%accepted_transaction_count == right(j)%mass%accepted_transaction_count)
        call diag_logical('MASS_INTERVAL_T0', same_bits(left(i)%mass%interval_t0, right(j)%mass%interval_t0))
        call diag_logical('MASS_INTERVAL_T1', same_bits(left(i)%mass%interval_t1, right(j)%mass%interval_t1))
        call diag_logical('MASS_STORAGE_START', same_bits(left(i)%mass%storage_start, right(j)%mass%storage_start))
        call diag_logical('MASS_STORAGE_END', same_bits(left(i)%mass%storage_end, right(j)%mass%storage_end))
        call diag_logical('MASS_STORAGE_CHANGE', same_bits(left(i)%mass%storage_change, right(j)%mass%storage_change))
        call diag_logical('MASS_TOTAL_IN', same_bits(left(i)%mass%total_in, right(j)%mass%total_in))
        call diag_logical('MASS_TOTAL_OUT', same_bits(left(i)%mass%total_out, right(j)%mass%total_out))
        call diag_logical('MASS_RESIDUAL', same_bits(left(i)%mass%residual, right(j)%mass%residual))
      end if
    end do
  end subroutine diagnose_result_difference

  subroutine diag_logical(label, matches)
    character(len=*), intent(in) :: label
    logical, intent(in) :: matches
    if (.not. matches) write(*,'(A,A)') 'FWOF36_DIAG_MISMATCH=', trim(label)
  end subroutine diag_logical

  logical function all_revisions_zero(states) result(zero)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i
    zero = .true.
    do i = 1, size(states)
      if (states(i)%current_revision() /= 0_int64) then
        zero = .false.
        return
      end if
    end do
  end function all_revisions_zero

  subroutine execute_retry_case()
    integer(int64), parameter :: retry_ids(1) = [505001_int64]
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(2)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(kernel_committed_state_t) :: states(1)
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(crop_root_uptake_input_t) :: crop_inputs(1)
    type(fmr_wofost_accepted_window_t) :: windows(1)
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    real(real64) :: conductivity0, qrot_rate, ptra_rate
    logical :: ok
    integer :: dispatch_status, binding_status, lineage_status

    call configure_templates(templates)
    call configure_parameters(parameters(1), initial_state, conductivity0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 50502_int64
    call configure_transaction(config)

    columns(1)%column_id = retry_ids(1)
    columns(1)%template_id = templates(1)%template_id
    columns(1)%parameter_ref = 1_int64
    columns(1)%state_handle = 1_int64
    columns(1)%forcing_handle = 1_int64
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(1), conductivity0, 1.01_real64)
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, initial_state, t0, ok)
    call require(ok, 'Gate B retry committed-state initialization')

    qrot_rate = sum(forcings(1)%root_extraction_sink)
    ptra_rate = 2.0_real64*qrot_rate
    crop_inputs(1)%crop_emerged = .true.
    crop_inputs(1)%potential_transpiration = ptra_rate
    crop_inputs(1)%rooted_nodes = 1
    allocate(crop_inputs(1)%cumulative_root_fraction(2))
    crop_inputs(1)%cumulative_root_fraction = [0.0_real64, 1.0_real64]

    call states(1)%capture_checkpoint(checkpoint, ok)
    call require(ok, 'Gate B retry accepted-window checkpoint')
    call open_wofost_accepted_window(checkpoint, t1, windows(1), lineage_status)
    call require(lineage_status == FMR_WOFOST_LINEAGE_OK, 'Gate B retry accepted-window open')

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    ! First attempt is physically unroutable. It must leave both physical state
    ! and WOFOST accepted-window state at the original checkpoint.
    columns(1)%backend_id = 999
    call fmr_run_serialized_multiswap_with_wofost_integrals(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, 1, retry_ids, crop_inputs, windows, results, diagnostics, aggregate, &
         dispatch_status, binding_status)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &
         'Gate B rejected retry first dispatch')
    call require(size(results) == 1 .and. .not. results(1)%committed, 'Gate B rejected retry no physical commit')
    call require(states(1)%current_revision() == 0_int64, 'Gate B rejected retry state unchanged')
    call require(windows(1)%interval_count() == 0, 'Gate B rejected retry zero window contribution')

    ! Retry from exactly the same committed state/window. The accepted retry
    ! commits once and contributes exactly one QROT/PTRA interval.
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_run_serialized_multiswap_with_wofost_integrals(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, 1, retry_ids, crop_inputs, windows, results, diagnostics, aggregate, &
         dispatch_status, binding_status)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &
         'Gate B accepted retry dispatch')
    call require(size(results) == 1 .and. results(1)%committed, 'Gate B accepted retry physical commit')
    call require(states(1)%current_revision() == 1_int64, 'Gate B accepted retry revision exactly once')
    call require(windows(1)%interval_count() == 1, 'Gate B accepted retry contribution exactly once')
    call validate_window_integral(windows(1), qrot_rate, ptra_rate, 'Gate B accepted retry')
    write(*,'(A)') 'FWOF36_GATE_B_REJECT_THEN_ACCEPT_RETRY_EXACTLY_ONCE=PASS'

    ! A duplicate attempt for the already-covered interval is rejected during
    ! trial preparation because the committed state is already at t1. Neither
    ! physical revision nor accepted-window count may change.
    call fmr_run_serialized_multiswap_with_wofost_integrals(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, 1, retry_ids, crop_inputs, windows, results, diagnostics, aggregate, &
         dispatch_status, binding_status)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_INVALID_REQUEST .and. &
         binding_status == FMR_WOF36_BINDING_TRIAL_REJECTED, 'Gate B duplicate accepted interval rejected precommit')
    call require(states(1)%current_revision() == 1_int64, 'Gate B duplicate retry physical revision unchanged')
    call require(windows(1)%interval_count() == 1, 'Gate B duplicate retry window count unchanged')
    write(*,'(A)') 'FWOF36_GATE_B_DUPLICATE_ACCEPTED_INTERVAL_ZERO_EXTRA_CONTRIBUTION=PASS'
  end subroutine execute_retry_case

  subroutine execute_wofost_case'''
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 helper anchor count={src.count(old)}')
src = src.replace(old, new, 1)

diag_anchor = "  call require(result_sets_identical(baseline_results, trial_results), 'Gate B physical result identity')\\n"
if src.count(diag_anchor) != 1:
    raise SystemExit(f'FWOF36 V2 result diagnostic anchor count={src.count(diag_anchor)}')
src = src.replace(diag_anchor,
                  "  call diagnose_result_difference(baseline_results, trial_results)\\n" + diag_anchor,
                  1)

# Add the two qualification cases immediately before the existing final marker.
main_anchor = "  write(*,'(A)') 'FWOF36_GATE_B_PHYSICAL_BINDING_TEST PASS'\\n\\n'''"
supplement = r'''  ! True one-logical-column execution, not merely batch_size=1 in a four-column run.
  call execute_wofost_case(1, 1, .false., 0_int64, 0, 0, bind_ids(1:1), single_results, single_diag, single_aggregate, &
       single_states, windows_reverse, qrot_reverse, ptra_reverse, dispatch_status, binding_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK .and. binding_status == FMR_WOF36_BINDING_OK, &
       'Gate B true single-column dispatch')
  call require(size(single_results) == 1, 'Gate B true single-column result size')
  call require(column_results_identical(result_for_id(trial_results, bind_ids(1)), single_results(1)), &
       'Gate B true single-column result equals MultiSWAP column')
  call require(single_states(1)%current_revision() == trial_states(1)%current_revision(), &
       'Gate B true single-column revision equals MultiSWAP column')
  call require(committed_fingerprint(single_states(1)) == committed_fingerprint(trial_states(1)), &
       'Gate B true single-column committed state equals MultiSWAP column')
  call require(same_bits(qrot_reverse(1), qrot_a(1)) .and. same_bits(ptra_reverse(1), ptra_a(1)), &
       'Gate B true single-column QROT/PTRA equals MultiSWAP column')
  call validate_window_integral(windows_reverse(1), qrot_reverse(1), ptra_reverse(1), 'Gate B true single column')
  write(*,'(A)') 'FWOF36_GATE_B_TRUE_SINGLE_COLUMN_MULTISWAP_IDENTITY=PASS'

  call execute_retry_case()

  write(*,'(A)') 'FWOF36_GATE_B_PHYSICAL_BINDING_TEST PASS'

'''
if src.count(main_anchor) != 1:
    raise SystemExit(f'FWOF36 V2 final-main anchor count={src.count(main_anchor)}')
src = src.replace(main_anchor, supplement + "'''", 1)

root_anchor = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if src.count(root_anchor) != 1:
    raise SystemExit(f'FWOF36 V2 root anchor count={src.count(root_anchor)}')
src = src.replace(root_anchor, 'ROOT="${FWOF36_V2_ROOT:?}"', 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF36_GATE_B_V2_DISPOSABLE_MAIN_FIX=PASS')
PY

chmod +x "$TMP/gate.sh"
FWOF36_V2_ROOT="$ROOT" bash "$TMP/gate.sh" | tee "$TMP/out.txt"
grep -Fq 'FWOF36_GATE_B_TRUE_SINGLE_COLUMN_MULTISWAP_IDENTITY=PASS' "$TMP/out.txt"
grep -Fq 'FWOF36_GATE_B_REJECT_THEN_ACCEPT_RETRY_EXACTLY_ONCE=PASS' "$TMP/out.txt"
grep -Fq 'FWOF36_GATE_B_DUPLICATE_ACCEPTED_INTERVAL_ZERO_EXTRA_CONTRIBUTION=PASS' "$TMP/out.txt"
