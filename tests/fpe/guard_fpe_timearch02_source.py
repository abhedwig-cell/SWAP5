#!/usr/bin/env python3
from pathlib import Path
checks={
"src/legacy/b1_10_fci11_port/timecontrol_part02.inc":[
"dtmax = min(dtmax, 1.0d0/dble(nprintday))",
"dtmin = min(dtmin, 0.1d0*dtmax)",
"dt = dsqrt(dtmin*dtmax)",
],
"src/legacy/b1_10_fci11_port/timecontrol_part03.inc":[
"dt = max(dt, dsqrt(dtmin*dtmax))",
],
"src/legacy/b1_10_fci11_port/timecontrol_part04.inc":[
"if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)",
"if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)",
"if (dt > dtevent) then",
],
"src/legacy/b1_10_fci11_port/timecontrol_part05.inc":[
"if (dt > fact_dt_fldect*dtmin) then",
"dt = dt / fact_dt_fldect",
"dt = dtmin",
],
}
for path,needles in checks.items():
    text=Path(path).read_text()
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"TIMEARCH02 source guard failed: {path}: {needle}")
print("F_PE_TIMEARCH02_SOURCE_GUARD=PASS")
