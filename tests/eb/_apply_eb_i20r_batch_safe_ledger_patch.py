from pathlib import Path
import subprocess

path = Path('src/runtime/mod_energy_conservation_ledger.f90')
expected_blob = 'aba5a63a10d7f37cb89e31882851d0f4e9b99ffa'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'EB-I20R unexpected ledger preblob: {actual_blob}')

text = path.read_text(encoding='utf-8')
old_commit = '''  subroutine energy_ledger_commit_prepared(self, prepared, receipt, record)\n    class(energy_trial_ledger_t), intent(inout) :: self\n    type(prepared_energy_trial_t), intent(inout) :: prepared\n    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt\n    type(energy_commit_record_t), intent(out) :: record\n    real(real64) :: receipt_t0, receipt_t1\n    logical :: interval_available\n\n    record = energy_commit_record_t()\n    if (.not. self%prepared_ready_for_receipt(prepared, receipt)) then\n      error stop 'energy conservation ledger prepared commit invariant violation'\n    end if\n    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)\n    if (.not. interval_available) error stop 'energy conservation ledger receipt interval invariant violation'\n\n    record%lineage_id = receipt%current_lineage_id()\n    record%origin_revision_value = receipt%origin_revision()\n    record%committed_revision_value = receipt%committed_revision()\n    record%t0_value = receipt_t0\n    record%t1_value = receipt_t1\n    record%balance = prepared%balance\n    record%initialized = .true.\n\n    call clear_prepared(self, prepared)\n  end subroutine energy_ledger_commit_prepared\n'''
new_commit = '''  subroutine energy_ledger_commit_prepared(self, prepared, receipt, record, status)\n    class(energy_trial_ledger_t), intent(inout) :: self\n    type(prepared_energy_trial_t), intent(inout) :: prepared\n    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt\n    type(energy_commit_record_t), intent(out) :: record\n    integer, intent(out) :: status\n    real(real64) :: receipt_t0, receipt_t1\n    logical :: interval_available\n\n    record = energy_commit_record_t()\n    status = ENERGY_LEDGER_INVALID_PROVENANCE\n    if (.not. self%prepared_ready_for_receipt(prepared, receipt)) return\n    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)\n    if (.not. interval_available) return\n\n    record%lineage_id = receipt%current_lineage_id()\n    record%origin_revision_value = receipt%origin_revision()\n    record%committed_revision_value = receipt%committed_revision()\n    record%t0_value = receipt_t0\n    record%t1_value = receipt_t1\n    record%balance = prepared%balance\n    record%initialized = .true.\n\n    call clear_prepared(self, prepared)\n    status = ENERGY_LEDGER_OK\n  end subroutine energy_ledger_commit_prepared\n'''
old_abort = '''  subroutine energy_ledger_abort_prepared(self, prepared)\n    class(energy_trial_ledger_t), intent(inout) :: self\n    type(prepared_energy_trial_t), intent(inout) :: prepared\n\n    if (.not. self%prepared_active .or. .not. prepared%ready()) then\n      error stop 'energy conservation ledger prepared abort invariant violation'\n    end if\n    if (prepared%generation /= self%prepared_generation) then\n      error stop 'energy conservation ledger prepared abort generation mismatch'\n    end if\n    call clear_prepared(self, prepared)\n  end subroutine energy_ledger_abort_prepared\n'''
new_abort = '''  subroutine energy_ledger_abort_prepared(self, prepared, status)\n    class(energy_trial_ledger_t), intent(inout) :: self\n    type(prepared_energy_trial_t), intent(inout) :: prepared\n    integer, intent(out) :: status\n\n    status = ENERGY_LEDGER_INVALID_PROVENANCE\n    if (.not. self%prepared_active .or. .not. prepared%ready()) return\n    if (prepared%generation /= self%prepared_generation) return\n    call clear_prepared(self, prepared)\n    status = ENERGY_LEDGER_OK\n  end subroutine energy_ledger_abort_prepared\n'''

if text.count(old_commit) != 1:
    raise SystemExit(f'EB-I20R commit anchor count={text.count(old_commit)}')
if text.count(old_abort) != 1:
    raise SystemExit(f'EB-I20R abort anchor count={text.count(old_abort)}')
text = text.replace(old_commit, new_commit, 1).replace(old_abort, new_abort, 1)
path.write_text(text, encoding='utf-8')

if 'error stop' in path.read_text(encoding='utf-8'):
    raise SystemExit('EB-I20R ledger still contains error stop')
