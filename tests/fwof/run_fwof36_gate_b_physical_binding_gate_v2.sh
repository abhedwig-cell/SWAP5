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

# The V1 failure was confined to the generated disposable Fortran main. Add
# only the missing names/helper; production source and all physical test cases
# are unchanged.
old = '''new_use = (old_use +
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
new = '''new_use = (old_use +
"  use mod_kernel_transactions, only: kernel_checkpoint_t\\n"
"  use mod_fmr_serialized_multiswap_runtime, only: FMR_SERIAL_DISPATCH_INVALID_REQUEST\\n"
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 generated-use anchor count={src.count(old)}')
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
        write(*,'(A,A,A,A)') 'FWOF36_DIAG_SOLVER_ROUTE_VALUES=', trim(left(i)%solver_route), '|', trim(right(j)%solver_route)
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_INITIAL_REVISION_VALUES=', left(i)%initial_revision, right(j)%initial_revision
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_FINAL_TIME_VALUES=', left(i)%final_committed_time, right(j)%final_committed_time
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_MASS_MASK_VALUES=', left(i)%mass%missing_contribution_mask, right(j)%mass%missing_contribution_mask
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_MASS_LINEAGE_VALUES=', left(i)%mass%origin_lineage_id, right(j)%mass%origin_lineage_id
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_MASS_REVISION_VALUES=', left(i)%mass%origin_revision, right(j)%mass%origin_revision
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_MASS_COUNT_VALUES=', left(i)%mass%accepted_transaction_count, right(j)%mass%accepted_transaction_count
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_INTERVAL_T0_VALUES=', left(i)%mass%interval_t0, right(j)%mass%interval_t0
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_INTERVAL_T1_VALUES=', left(i)%mass%interval_t1, right(j)%mass%interval_t1
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

root_anchor = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if src.count(root_anchor) != 1:
    raise SystemExit(f'FWOF36 V2 root anchor count={src.count(root_anchor)}')
src = src.replace(root_anchor, 'ROOT="${FWOF36_V2_ROOT:?}"', 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF36_GATE_B_V2_DISPOSABLE_MAIN_FIX=PASS')
PY

chmod +x "$TMP/gate.sh"
FWOF36_V2_ROOT="$ROOT" bash "$TMP/gate.sh"
