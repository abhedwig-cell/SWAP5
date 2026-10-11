from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
expected_blob = '921c268e44162e317cbf64adc78220a12cca2184'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'F-MR18 Gate C alignment base mismatch: expected {expected_blob}, got {actual_blob}')

src = path.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global src
    if src.count(old) != 1:
        raise SystemExit(f'F-MR18 Gate C alignment anchor count={src.count(old)} for:\n{old}')
    src = src.replace(old, new, 1)

replace_once(
"  end type fmr_serialized_column_result_t\n\n"
"  ! F-MR05-specific composition diagnostics.",
"  end type fmr_serialized_column_result_t\n\n"
"  ! Sparse ephemeral receipt output. The explicit column id makes the\n"
"  ! request/output association self-describing without adding any persistent\n"
"  ! optional state to logical columns or committed physical state.\n"
"  type, public :: fmr_serialized_commit_receipt_record_t\n"
"    integer(int64) :: column_id = 0_int64\n"
"    type(fmr_accepted_commit_receipt_t) :: receipt\n"
"  end type fmr_serialized_commit_receipt_record_t\n\n"
"  ! F-MR05-specific composition diagnostics.")

replace_once(
"    type(fmr_accepted_commit_receipt_t), allocatable, intent(out), optional :: commit_receipts(:)\n",
"    type(fmr_serialized_commit_receipt_record_t), allocatable, intent(out), optional :: commit_receipts(:)\n")

replace_once(
"      deallocate(commit_receipts)\n"
"      allocate(commit_receipts(size(receipt_column_ids)))\n"
"    end if\n",
"      deallocate(commit_receipts)\n"
"      allocate(commit_receipts(size(receipt_column_ids)))\n"
"      do receipt_slot = 1, size(receipt_column_ids)\n"
"        commit_receipts(receipt_slot)%column_id = receipt_column_ids(receipt_slot)\n"
"      end do\n"
"    end if\n")

replace_once(
"               local_runtime, active_physical_calls, commit_receipts(receipt_slot))\n",
"               local_runtime, active_physical_calls, commit_receipts(receipt_slot)%receipt)\n")

replace_once(
"    type(fmr_accepted_commit_receipt_t), intent(out), optional :: commit_receipt\n",
"    type(fmr_accepted_commit_receipt_t), intent(inout), optional :: commit_receipt\n")

replace_once(
"      if (present(commit_receipt) .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then\n"
"        diagnostic%failure_classification = 'RECEIPT_PREVALIDATION_REJECTED'\n"
"      else\n",
"      if (present(commit_receipt) .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then\n"
"        if (candidate%ready()) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)\n"
"        diagnostic%failure_classification = 'RECEIPT_PREVALIDATION_REJECTED'\n"
"      else\n")

path.write_text(src, encoding='utf-8')
print('FMR18_GATE_C_FROZEN_DESIGN_ALIGNMENT_MATERIALIZED=PASS')
