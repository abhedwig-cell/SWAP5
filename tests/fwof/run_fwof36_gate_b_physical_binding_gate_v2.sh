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
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_KERNEL_STATUS=', left(i)%kernel_status, right(j)%kernel_status
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_COMMIT_STATUS=', left(i)%commit_status, right(j)%commit_status
        write(*,'(A,2(1X,L1))') 'FWOF36_DIAG_COMPLETED=', left(i)%completed, right(j)%completed
        write(*,'(A,2(1X,L1))') 'FWOF36_DIAG_COMMITTED=', left(i)%committed, right(j)%committed
        write(*,'(A,2(1X,L1))') 'FWOF36_DIAG_SOLVER_EXECUTED=', left(i)%solver_executed, right(j)%solver_executed
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_SOLVER_ITERATIONS=', left(i)%solver_iterations, right(j)%solver_iterations
        write(*,'(A,2(1X,I0))') 'FWOF36_DIAG_REVISIONS=', left(i)%final_revision, right(j)%final_revision
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_STORAGE_START=', left(i)%mass%storage_start, right(j)%mass%storage_start
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_STORAGE_END=', left(i)%mass%storage_end, right(j)%mass%storage_end
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_STORAGE_CHANGE=', left(i)%mass%storage_change, right(j)%mass%storage_change
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_TOTAL_IN=', left(i)%mass%total_in, right(j)%mass%total_in
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_TOTAL_OUT=', left(i)%mass%total_out, right(j)%mass%total_out
        write(*,'(A,2(1X,ES26.17E3))') 'FWOF36_DIAG_RESIDUAL=', left(i)%mass%residual, right(j)%mass%residual
      end if
    end do
  end subroutine diagnose_result_difference

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
