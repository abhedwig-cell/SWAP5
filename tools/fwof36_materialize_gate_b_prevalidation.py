from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_wofost_accepted_window_lineage.f90')
expected_blob = '0e3f5d506f24669cae731fe71eb1411abc8d9008'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'F-WOF36 Gate B lineage base mismatch: expected {expected_blob}, got {actual_blob}')

src = path.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global src
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'F-WOF36 Gate B patch anchor count={count} for:\n{old}')
    src = src.replace(old, new, 1)

replace_once(
    '  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH = 11\n',
    '  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH = 11\n'
    '  integer, parameter, public :: FMR_WOFOST_LINEAGE_TRIAL_WINDOW_MISMATCH = 12\n'
)

replace_once(
    '  public :: admit_wofost_accepted_trial\n',
    '  public :: prevalidate_wofost_trial_admission\n'
    '  public :: admit_wofost_accepted_trial\n'
)

anchor = '  subroutine admit_wofost_accepted_trial(window, certificate, trial, status)\n'
helper = '''  subroutine prevalidate_wofost_trial_admission(window, trial, status)\n    type(fmr_wofost_accepted_window_t), intent(in) :: window\n    type(fmr_wofost_trial_contribution_t), intent(in) :: trial\n    integer, intent(out) :: status\n\n    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW\n    if (.not. window%ready()) return\n    if (window%event_delivered) return\n\n    status = FMR_WOFOST_LINEAGE_INVALID_TRIAL\n    if (.not. trial%ready()) return\n    if (.not. trial%complete()) return\n\n    status = FMR_WOFOST_LINEAGE_TRIAL_WINDOW_MISMATCH\n    if (trial%lineage_id /= window%lineage_id) return\n    if (trial%origin_revision /= window%next_revision) return\n\n    if (.not. same_time(trial%t0, window%covered_t)) then\n      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS\n      return\n    end if\n    if (trial%t1 > window%t1 .and. .not. same_time(trial%t1, window%t1)) then\n      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS\n      return\n    end if\n\n    status = FMR_WOFOST_LINEAGE_OK\n  end subroutine prevalidate_wofost_trial_admission\n\n'''
if src.count(anchor) != 1:
    raise SystemExit('F-WOF36 Gate B admission insertion anchor mismatch')
src = src.replace(anchor, helper + anchor, 1)

path.write_text(src, encoding='utf-8')
print('FWOF36_GATE_B_LINEAGE_PREVALIDATION_MATERIALIZED=PASS')
