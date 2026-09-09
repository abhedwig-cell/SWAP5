from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
expected_blob = '7a60f8b8d18672098fed1c6890a95aac738ed21d'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'F-MR18 Gate C source base mismatch: expected {expected_blob}, got {actual_blob}')

src = path.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global src
    if src.count(old) != 1:
        raise SystemExit(f'F-MR18 Gate C patch anchor count={src.count(old)} for:\n{old}')
    src = src.replace(old, new, 1)

replace_once(
"  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate\n",
"  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate\n"
"  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &\n"
"       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_COMMIT_REJECTED\n")

replace_once(
"  integer, parameter, public :: FMR_SERIAL_DISPATCH_REGISTRY_REJECTED = 2\n",
"  integer, parameter, public :: FMR_SERIAL_DISPATCH_REGISTRY_REJECTED = 2\n"
"  integer, parameter, public :: FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED = 3\n")

replace_once(
"                                                    batch_size, results, diagnostics, aggregate, dispatch_status, &\n"
"                                                    runtime_diagnostics)\n",
"                                                    batch_size, results, diagnostics, aggregate, dispatch_status, &\n"
"                                                    runtime_diagnostics, receipt_column_ids, commit_receipts)\n")

replace_once(
"    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics\n\n"
"    type(fmr_serialized_reference_backend_t), target :: backend\n",
"    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics\n"
"    integer(int64), intent(in), optional :: receipt_column_ids(:)\n"
"    type(fmr_accepted_commit_receipt_t), allocatable, intent(out), optional :: commit_receipts(:)\n\n"
"    type(fmr_serialized_reference_backend_t), target :: backend\n")

replace_once(
"    integer :: batch_start, batch_end, pos, idx, batches, active_physical_calls\n",
"    integer :: batch_start, batch_end, pos, idx, batches, active_physical_calls, receipt_slot\n")

replace_once(
"    active_physical_calls = 0\n"
"    dispatch_status = FMR_SERIAL_DISPATCH_OK\n\n"
"    if (batch_size <= 0 .or. t1 <= t0) then\n",
"    active_physical_calls = 0\n"
"    dispatch_status = FMR_SERIAL_DISPATCH_OK\n"
"    if (present(commit_receipts)) allocate(commit_receipts(0))\n\n"
"    ! Receipt requests are optional feature-scoped runtime metadata. Validate\n"
"    ! the complete sparse request before backend initialization or any physical\n"
"    ! trial so every expected request error is transactionally precommit.\n"
"    if (present(receipt_column_ids) .neqv. present(commit_receipts)) then\n"
"      dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED\n"
"      call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')\n"
"      call build_aggregate(columns, diagnostics, 0, aggregate)\n"
"      call finalize_runtime_diagnostics(results, local_runtime)\n"
"      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n"
"      return\n"
"    end if\n"
"    if (present(receipt_column_ids)) then\n"
"      if (.not. receipt_request_valid(columns, receipt_column_ids)) then\n"
"        dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED\n"
"        call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')\n"
"        call build_aggregate(columns, diagnostics, 0, aggregate)\n"
"        call finalize_runtime_diagnostics(results, local_runtime)\n"
"        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n"
"        return\n"
"      end if\n"
"      deallocate(commit_receipts)\n"
"      allocate(commit_receipts(size(receipt_column_ids)))\n"
"    end if\n\n"
"    if (batch_size <= 0 .or. t1 <= t0) then\n")

replace_once(
"        call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &\n"
"             forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &\n"
"             local_runtime, active_physical_calls)\n",
"        receipt_slot = 0\n"
"        if (present(receipt_column_ids)) receipt_slot = find_receipt_slot(columns(idx)%column_id, receipt_column_ids)\n"
"        if (receipt_slot > 0) then\n"
"          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &\n"
"               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &\n"
"               local_runtime, active_physical_calls, commit_receipts(receipt_slot))\n"
"        else\n"
"          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &\n"
"               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &\n"
"               local_runtime, active_physical_calls)\n"
"        end if\n")

replace_once(
"  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n"
"                            state_registry, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)\n",
"  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &\n"
"                            state_registry, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, &\n"
"                            commit_receipt)\n")

replace_once(
"    integer, intent(inout) :: active_physical_calls\n\n"
"    type(kernel_checkpoint_t) :: checkpoint\n",
"    integer, intent(inout) :: active_physical_calls\n"
"    type(fmr_accepted_commit_receipt_t), intent(out), optional :: commit_receipt\n\n"
"    type(kernel_checkpoint_t) :: checkpoint\n")

replace_once(
"    integer :: state_index, parameter_index, forcing_index, commit_status\n"
"    logical :: checkpoint_ok, candidate_ready, did_commit\n",
"    integer :: state_index, parameter_index, forcing_index, commit_status, receipt_status\n"
"    logical :: checkpoint_ok, candidate_ready, did_commit\n")

replace_once(
"    call fmr_commit_candidate(transaction_control, state_registry(state_index), candidate, kernel_diag, &\n"
"         did_commit, commit_status)\n"
"    output%commit_status = commit_status\n"
"    if (.not. did_commit) then\n"
"      diagnostic%rejected = 1\n"
"      diagnostic%failure_classification = 'COMMIT_REJECTED'\n"
"      call update_committed_provenance(state_registry(state_index), output, diagnostic)\n"
"      return\n"
"    end if\n",
"    if (present(commit_receipt)) then\n"
"      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, state_registry(state_index), candidate, &\n"
"           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)\n"
"    else\n"
"      receipt_status = FMR_COMMIT_RECEIPT_OK\n"
"      call fmr_commit_candidate(transaction_control, state_registry(state_index), candidate, kernel_diag, &\n"
"           did_commit, commit_status)\n"
"    end if\n"
"    output%commit_status = commit_status\n"
"    if (.not. did_commit) then\n"
"      diagnostic%rejected = 1\n"
"      if (present(commit_receipt) .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then\n"
"        diagnostic%failure_classification = 'RECEIPT_PREVALIDATION_REJECTED'\n"
"      else\n"
"        diagnostic%failure_classification = 'COMMIT_REJECTED'\n"
"      end if\n"
"      call update_committed_provenance(state_registry(state_index), output, diagnostic)\n"
"      return\n"
"    end if\n"
"    if (present(commit_receipt)) then\n"
"      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. commit_receipt%ready()) &\n"
"           error stop 'F-MR18: successful physical commit without ready accepted receipt'\n"
"    end if\n")

anchor = "  logical function registry_structure_valid(columns, templates, states) result(valid)\n"
insert = """  logical function receipt_request_valid(columns, receipt_column_ids) result(valid)\n    type(fmr_logical_column_t), intent(in) :: columns(:)\n    integer(int64), intent(in) :: receipt_column_ids(:)\n    integer :: i, j\n\n    valid = .true.\n    do i = 1, size(receipt_column_ids)\n      if (receipt_column_ids(i) <= 0_int64) then\n        valid = .false.\n        return\n      end if\n      if (.not. any(columns%column_id == receipt_column_ids(i))) then\n        valid = .false.\n        return\n      end if\n      do j = i + 1, size(receipt_column_ids)\n        if (receipt_column_ids(j) == receipt_column_ids(i)) then\n          valid = .false.\n          return\n        end if\n      end do\n    end do\n  end function receipt_request_valid\n\n  integer function find_receipt_slot(column_id, receipt_column_ids) result(slot)\n    integer(int64), intent(in) :: column_id\n    integer(int64), intent(in) :: receipt_column_ids(:)\n    integer :: i\n\n    slot = 0\n    do i = 1, size(receipt_column_ids)\n      if (receipt_column_ids(i) == column_id) then\n        slot = i\n        return\n      end if\n    end do\n  end function find_receipt_slot\n\n"""
if src.count(anchor) != 1:
    raise SystemExit('F-MR18 Gate C receipt helper insertion anchor mismatch')
src = src.replace(anchor, insert + anchor, 1)

path.write_text(src, encoding='utf-8')
print('FMR18_GATE_C_RUNTIME_PATCH_MATERIALIZED=PASS')
