#!/usr/bin/env python3
from pathlib import Path

worker=Path("src/runtime/mod_a23bu_worker_execution_context.f90").read_text()
p1=Path("src/legacy/b1_10_fci11_port/timecontrol_part01.inc").read_text()
p4=Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc").read_text()
p5=Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc").read_text()
s3=Path("src/legacy/b1_10_fci11_port/swap_part03.inc").read_text()
s6=Path("src/legacy/b1_10_fci11_port/swap_part06.inc").read_text()

for token in [
    "type, public :: a23bu_timestep_decision_trace_t",
    "type(a23bu_timestep_decision_trace_t) :: timestep_trace",
    "subroutine a23bu_record_timestep_trace",
    "subroutine a23bu_reset_timestep_trace",
    "A23BU_TS_LIMIT_HARD_EVENT",
    "A23BU_TS_LIMIT_SOLVER_RETRY",
]:
    assert token in worker, token

assert "subroutine TimeControl(task, interval, worker)" in p1
assert "type(a23bu_worker_context_t), intent(inout), optional :: worker" in p1

proposal=p4.index("timestepDecision = b1_10_legacy_accepted_step_decision")
event=p4.index("dtEvent = get_dtevent()")
trace=p4.index("call a23bu_record_timestep_trace")
assert proposal < event < trace
assert "timestepDecisionInput = dt" in p4
assert "timestepEventClamped = .TRUE." in p4
assert "timestepLimitReason = A23BU_TS_LIMIT_HARD_EVENT" in p4

retry=p5.index("timestepDecision = b1_10_legacy_solver_retry_decision")
retry_trace=p5.index("call a23bu_record_timestep_trace")
assert retry < retry_trace
assert "A23BU_TS_LIMIT_SOLVER_RETRY_FLOOR" in p5

assert "subroutine TimeControl(task, interval, worker)" in s3
assert "call TimeControl(task, interval, worker)" in s6
assert "call TimeControl(task, worker=worker)" in s6

# Diagnostic trace is write-only with respect to timestep selection.
for source in (p1,p4,p5):
    assert "%timestep_trace%" not in source

print("F_PE_TIMEARCH07_SOURCE_SCOPE=PASS")
