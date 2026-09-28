#!/usr/bin/env python3
from pathlib import Path

svc=Path("src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90").read_text()
p1=Path("src/legacy/b1_10_fci11_port/timecontrol_part01.inc").read_text()
p4=Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc").read_text()
p5=Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc").read_text()
p3=Path("src/legacy/b1_10_fci11_port/swap_part03.inc").read_text()
p6=Path("src/legacy/b1_10_fci11_port/swap_part06.inc").read_text()
worker=Path("src/runtime/mod_a23bu_worker_execution_context.f90").read_text()

for token in [
    "type, public :: b1_10_timestep_trace_t",
    "preferred_dt",
    "executed_dt",
    "event_clipped",
    "sequence",
]:
    assert token in svc, token

assert "subroutine TimeControl(task, interval, timestep_trace)" in p1
assert "type(b1_10_timestep_trace_t), intent(inout), optional :: timestep_trace" in p1
assert "timestep_trace%preferred_dt = timestepDecision%preferred_dt" in p4
assert "timestep_trace%executed_dt = dt" in p4
assert "timestep_trace%event_clipped = .TRUE." in p4
assert "timestep_trace%reason = timestepDecision%reason" in p5

# Legacy scheduler ownership/formulas remain present.
for token in [
    "dtEvent = get_dtevent()",
    "if (dt > dtevent) then",
    "call irrigation(9)",
]:
    assert token in p4, token
for token in [
    "if (sw_inter == 3 .AND. dt_interc_event < 1.0d0) dt = min(dt, dt_interc_event)",
    "if (swmacro == 1 .AND. FlDecMpRat) then",
    "dt = dsqrt(dtmin*dtmax)",
    "function get_dtevent()",
]:
    assert token in p5, token

# Trace is explicitly worker-local when a worker exists; standalone stays optional.
assert "type(b1_10_timestep_trace_t) :: timestep_trace" in worker
assert "worker%timestep_trace = b1_10_timestep_trace_t()" in worker
assert "call TimeControl(task, interval, worker%timestep_trace)" in p6
assert "call TimeControl(task, timestep_trace=worker%timestep_trace)" in p6
assert "call TimeControl(task, interval)" in p6
assert "call TimeControl(task)" in p6
assert "timestep_trace" in p3

print("F_PE_TIMEARCH07_SOURCE_SCOPE=PASS")
