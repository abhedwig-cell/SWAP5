#!/usr/bin/env python3
from pathlib import Path
import re, subprocess

ROOT=Path(__file__).resolve().parents[2]
HEAD=ROOT/'src/legacy/b1_10_port/headcalc.f90'
PRE=ROOT/'src/legacy/b1_10_fci11_port/swap_part05.inc'
POST=ROOT/'src/legacy/b1_10_fci13_port/swap_part05.inc'
TC=ROOT/'src/legacy/b1_10_fci11_port/timecontrol_part05.inc'
EXEC=ROOT/'src/adapter/mod_b1_10_recoverable_interval_executor.f90'
MODEL=ROOT/'src/adapter/mod_b1_10_recoverable_reference_model.f90'
STATUS=ROOT/'src/adapter/mod_b1_10_trial_status.f90'
PARENT=ROOT/'src/adapter/mod_b1_10_reference_model.f90'

expected={
    HEAD:'225b9f2cc1ecff01414b5691799103b92bc068c5',
    PRE:'beb729ff8b399c5522c9e54a7a8429bb0a1504e5',
    TC:'fe351d7c1c9dfd7edbd831acb527049cb8e4a9b5',
    POST:'48fcc9d6f8cb95ef3ef773b27077c8368fdf72f9',
    PARENT:'366a4df93a829413bed552b050ca723544e31ce4',
}
for path,sha in expected.items():
    got=subprocess.check_output(['git','hash-object',str(path)],text=True).strip()
    if got!=sha:
        raise SystemExit(f'F-CI13 provenance mismatch: {path} {got} != {sha}')

# The F-CI13 legacy postimage must differ from F-CI11 only by the guarded
# canonical-trial abort immediately after SoilWater(2).
insert="""
!        F-CI13: a canonical trial must not continue from the legacy terminal
!        non-converged minimum-dt route. HeadCalc records that route by
!        incrementing worker%history%iwarn. Standalone execution has no worker
!        and therefore retains the qualified legacy continuation behaviour.
         if (present(worker)) then
            if (worker%history%iwarn > 0) then
               call SoilWaterStateVar(2)
               return
            end if
         end if
"""
pre=PRE.read_text()
post=POST.read_text()
if insert not in post or post.replace(insert,'')!=pre:
    raise SystemExit('F-CI13 swap postimage contains changes beyond the admitted terminal-status guard')

h=HEAD.read_text().lower()
t=TC.read_text().lower()
e=EXEC.read_text().lower()
m=MODEL.read_text().lower()
s=STATUS.read_text().lower()
p=PARENT.read_text().lower()

checks={
 'headcalc_terminal_nonconvergence_exists':'continue without convergence' in h,
 'headcalc_terminal_marker':'ctx%history%iwarn = ctx%history%iwarn + 1' in h,
 'headcalc_canonical_warning_suppression':"if (.not.canonical_trial) call swap_warning ('headcalc', message)" in h,
 'headcalc_internal_retry_flag':'ctx%control%request_dt_reduction = .true.' in h,
 'timecontrol_internal_dt_reduction':'if (fldecdt) then' in t and 'dt = dt / fact_dt_fldect' in t,
 'status_success':'b1_10_trial_status_success' in s,
 'status_retryable':'b1_10_trial_status_retryable_numerical' in s,
 'status_fatal':'b1_10_trial_status_fatal_contract' in s,
 'executor_resets_warning_observer':'worker%history%iwarn = 0' in e,
 'executor_detects_terminal_marker':'worker%history%iwarn > 0' in e,
 'executor_invalidates_retryable_mass':'invalidate_b1_10_trial_mass' in e,
 'model_admits_recoverable_status':'recoverable_solver_failure_status = .true.' in m,
 'model_retryable_restores_state':'if (status%retryable()) then' in m and 'call restore_b1_10_process_state(physical)' in m,
 'model_fatal_not_retried':'if (status%fatal()) then' in m and 'error stop' in m,
 'scalar_temporal_still_blocked':'scalar_temporal_error_policy = .false.' in m and 'scalar_temporal_error_policy = .false.' in p,
 'parent_reference_executor_still_gated':'reference_execution_admitted' in p,
 'new_adapters_no_file_io':not re.search(r'\b(open|read|write)\s*\(',e+m+s),
 'guard_before_postprocessing':post.find('worker%history%iwarn > 0') < post.find('call drain(3)') < post.find('call SoilWater(3, worker)'),
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI13','checks':checks,'failed':failed})
if failed:
    raise SystemExit(2)
