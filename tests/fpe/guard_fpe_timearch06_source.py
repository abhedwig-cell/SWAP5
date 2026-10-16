#!/usr/bin/env python3
from pathlib import Path

p1=Path("src/legacy/b1_10_fci11_port/timecontrol_part01.inc").read_text()
p4=Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc").read_text()
p5=Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc").read_text()
svc=Path("src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90").read_text()

assert "use mod_b1_10_timestep_decision_service" in p1
assert "b1_10_legacy_accepted_step_decision" in p4
assert "b1_10_legacy_solver_retry_decision" in p5

# The extracted arithmetic must no longer remain duplicated in TimeControl.
assert "if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)" not in p4
assert "dt = dt / fact_dt_fldect" not in p5

# Scheduler and unrelated legacy ownership must remain in place.
for token in [
    "dtEvent = get_dtevent()",
    "if (dt > dtevent) then",
    "call irrigation(9)",
    "if (dt > (1.0d0+dtCrit)*dtmin) fldtmin = .FALSE.",
]:
    assert token in p4, token
for token in [
    "if (sw_inter == 3 .AND. dt_interc_event < 1.0d0) dt = min(dt, dt_interc_event)",
    "if (swmacro == 1 .AND. FlDecMpRat) then",
    "dt = dsqrt(dtmin*dtmax)",
    "if (dt_irr_event < 1.0d0) dt = min(dt, dt_irr_event)",
    "function get_dtevent()",
]:
    assert token in p5, token

# Exact legacy formula order must exist in the service.
grow=svc.index("if (numbit <= numbit_crit) then")
shrink=svc.index("if (numbit >= maxit) then")
floor=svc.index("if (decision%preferred_dt < dtmin) then")
assert grow < shrink < floor
assert "if (dt > fact_failure*dtmin) then" in svc
assert "decision%preferred_dt = dt/fact_failure" in svc
assert "decision%preferred_dt = dtmin" in svc

print("F_PE_TIMEARCH06_SOURCE_SCOPE=PASS")
