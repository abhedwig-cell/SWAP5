#!/usr/bin/env python3
from pathlib import Path
import hashlib

LEDGER = Path('src/runtime/mod_energy_conservation_ledger.f90')
RUNTIME = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')

EXPECTED_LEDGER_BLOB_SHA1 = 'e71820784780e4a45a7024dbc437c71f0fb7d0c4'
EXPECTED_RUNTIME_BLOB_SHA1 = '07d3699e3e3972921fdb36352d75c47cb12d03b7'


def git_blob_sha1(data: bytes) -> str:
    h = hashlib.sha1()
    h.update(f'blob {len(data)}\0'.encode())
    h.update(data)
    return h.hexdigest()


def require_blob(path: Path, expected: str) -> str:
    data = path.read_bytes()
    actual = git_blob_sha1(data)
    if actual != expected:
        raise SystemExit(f'EB-I21R preblob drift for {path}: {actual} != {expected}')
    return data.decode()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'EB-I21R expected exactly one {label}, found {count}')
    return text.replace(old, new, 1)


ledger = require_blob(LEDGER, EXPECTED_LEDGER_BLOB_SHA1)
ledger = replace_once(
    ledger,
    '  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t\n',
    '  use mod_fmr_owned_commit_receipt, only: fmr_owned_commit_receipt_t\n',
    'ledger receipt import')
ledger = ledger.replace('type(fmr_accepted_commit_receipt_t), intent(in) :: receipt',
                        'type(fmr_owned_commit_receipt_t), intent(in) :: receipt')
if ledger.count('type(fmr_owned_commit_receipt_t), intent(in) :: receipt') != 2:
    raise SystemExit('EB-I21R expected two owned receipt ledger arguments')
ledger = replace_once(
    ledger,
    '    if (.not. receipt%ready()) return\n    if (.not. prepared_matches_ledger(self, prepared)) return\n',
    '    if (.not. receipt%ready()) return\n'
    '    if (.not. prepared_matches_ledger(self, prepared)) return\n'
    '    if (receipt%owner_instance_id() /= prepared%owner_instance_id) return\n',
    'ledger owner association guard')
LEDGER.write_text(ledger)

runtime = require_blob(RUNTIME, EXPECTED_RUNTIME_BLOB_SHA1)
runtime = replace_once(
    runtime,
    '  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &\n'
    '       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_COMMIT_REJECTED\n',
    '  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &\n'
    '       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_COMMIT_REJECTED\n'
    '  use mod_fmr_owned_commit_receipt, only: fmr_owned_commit_receipt_t, fmr_commit_candidate_with_owned_receipt\n',
    'runtime owned receipt import')
runtime = replace_once(
    runtime,
    '    type(fmr_accepted_commit_receipt_t) :: local_energy_receipt\n'
    '    integer :: commit_status, receipt_status, simultaneous_physical_calls\n'
    '    logical :: checkpoint_ok, candidate_ready, did_commit, energy_requested, receipt_path\n',
    '    type(fmr_owned_commit_receipt_t) :: local_energy_receipt\n'
    '    integer :: commit_status, receipt_status, simultaneous_physical_calls\n'
    '    logical :: checkpoint_ok, candidate_ready, did_commit, energy_requested, receipt_path, exported_receipt_available\n',
    'runtime local owned receipt declaration')
old_commit = '''    if (energy_requested) then
      if (present(commit_receipt)) then
        call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
             kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
      else
        call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
             kernel_diag, did_commit, local_energy_receipt, receipt_status, commit_status)
      end if
    else if (present(commit_receipt)) then
      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
    else
'''
new_commit = '''    if (energy_requested) then
      call fmr_commit_candidate_with_owned_receipt(column%column_id, transaction_control, checkpoint, &
           committed_state, candidate, kernel_diag, did_commit, local_energy_receipt, receipt_status, commit_status)
      if (did_commit .and. present(commit_receipt)) then
        call local_energy_receipt%export_accepted_receipt(commit_receipt, exported_receipt_available)
        if (.not. exported_receipt_available) &
             error stop 'EB-I21R: accepted owned receipt could not export generic receipt'
      end if
    else if (present(commit_receipt)) then
      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
    else
'''
runtime = replace_once(runtime, old_commit, new_commit, 'runtime commit routing block')
old_post = '''    if (present(commit_receipt)) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. commit_receipt%ready()) &
           error stop 'F-MR18: successful physical commit without ready accepted receipt'
    else if (energy_requested) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. local_energy_receipt%ready()) &
           error stop 'EB-I18: successful energy-path commit without ready accepted receipt'
    end if

    if (energy_requested) then
      if (present(commit_receipt)) then
        call finalize_bottom_energy_publication(column%column_id, prepared_bottom_energy, commit_receipt, &
             bottom_energy_publication)
      else
        call finalize_bottom_energy_publication(column%column_id, prepared_bottom_energy, local_energy_receipt, &
             bottom_energy_publication)
      end if
    end if
'''
new_post = '''    if (energy_requested) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. local_energy_receipt%ready()) &
           error stop 'EB-I21R: successful energy-path commit without ready owned accepted receipt'
      if (local_energy_receipt%owner_instance_id() /= column%column_id) &
           error stop 'EB-I21R: accepted energy receipt owner does not match executing column'
      if (present(commit_receipt)) then
        if (.not. commit_receipt%ready()) &
             error stop 'F-MR18: successful physical commit without exported accepted receipt'
      end if
    else if (present(commit_receipt)) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. commit_receipt%ready()) &
           error stop 'F-MR18: successful physical commit without ready accepted receipt'
    end if

    if (energy_requested) then
      call finalize_bottom_energy_publication(column%column_id, prepared_bottom_energy, local_energy_receipt, &
           bottom_energy_publication)
    end if
'''
runtime = replace_once(runtime, old_post, new_post, 'runtime postcommit/finalization block')
runtime = replace_once(
    runtime,
    '    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt\n'
    '    type(fmr_serialized_bottom_energy_publication_t), intent(out) :: publication\n',
    '    type(fmr_owned_commit_receipt_t), intent(in) :: receipt\n'
    '    type(fmr_serialized_bottom_energy_publication_t), intent(out) :: publication\n',
    'bottom energy finalizer receipt type')
runtime = replace_once(
    runtime,
    "    if (.not. receipt%ready()) error stop 'EB-I18: accepted candidate has no ready receipt for energy publication'\n"
    '    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)\n',
    "    if (.not. receipt%ready()) error stop 'EB-I21R: accepted candidate has no ready owned receipt for energy publication'\n"
    "    if (receipt%owner_instance_id() /= column_id) error stop 'EB-I21R: energy publication owner mismatch'\n"
    '    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)\n',
    'bottom energy finalizer owner guard')
RUNTIME.write_text(runtime)

print('EB_I21R_PATCH_LEDGER=READY')
print('EB_I21R_PATCH_SERIALIZED_RUNTIME=READY')
