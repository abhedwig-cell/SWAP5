from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
s = src.read_text(encoding='utf-8')

old = 'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t'
new = 'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE'
if s.count(old) != 1:
    raise SystemExit(f'transaction use anchor count={s.count(old)}')
s = s.replace(old, new, 1)

old = '    procedure :: temporal_error => ebi01_temporal_error\n'
new = old + '    procedure :: storage_accounting_status => ebi01_storage_accounting_status\n'
if s.count(old) != 1:
    raise SystemExit(f'model binding anchor count={s.count(old)}')
s = s.replace(old, new, 1)

old = '    outcome%mass_in = transfer_mass\n    outcome%nonlinear_iterations = 1\n'
new = ('    outcome%mass_in = transfer_mass\n'
       '    outcome%mass_accounting_complete = .true.\n'
       '    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE\n'
       '    outcome%nonlinear_iterations = 1\n')
if s.count(old) != 1:
    raise SystemExit(f'advance anchor count={s.count(old)}')
s = s.replace(old, new, 1)

anchor = '  real(real64) function ebi01_temporal_error(self, full_state, half_state) result(value)\n'
proc = '''  subroutine ebi01_storage_accounting_status(self, state, complete, missing_mask)\n    class(ebi01_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: state\n    logical, intent(out) :: complete\n    integer(int64), intent(out) :: missing_mask\n    complete = .false.\n    missing_mask = TX_MASS_MISSING_NONE\n    if (self%scale < 0.0_real64) return\n    select type (state)\n    type is (ebi01_state_t)\n      complete = .true.\n    class default\n      complete = .false.\n    end select\n  end subroutine ebi01_storage_accounting_status\n\n'''
if s.count(anchor) != 1:
    raise SystemExit(f'storage procedure anchor count={s.count(anchor)}')
s = s.replace(anchor, proc + anchor, 1)

old = 'call ledger%commit_prepared(prepared, receipt, record)'
if s.count(old) != 2:
    raise SystemExit(f'commit call count={s.count(old)}')
s = s.replace(old, 'call ledger%commit_prepared(prepared, receipt, record, status)')

old = 'call ledger%abort_prepared(prepared)'
if s.count(old) != 1:
    raise SystemExit(f'abort call count={s.count(old)}')
s = s.replace(old, 'call ledger%abort_prepared(prepared, status)', 1)

dst.write_text(s, encoding='utf-8')
