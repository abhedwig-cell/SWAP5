#!/usr/bin/env python3
from pathlib import Path

checks = {
    "src/legacy/b1_10_fci11_port/timecontrol_part02.inc": [
        "dtmax = min(dtmax, 1.0d0/dble(nprintday))",
        "if (swmetdetail == 1) dtmax = min(dtmax, dt_meteo)",
        "dtmin = min(dtmin, 0.1d0*dtmax)",
    ],
    "src/legacy/b1_10_fci11_port/timecontrol_part03.inc": [
        "dt = max(dt, dsqrt(dtmin*dtmax))",
    ],
    "src/legacy/b1_10_fci11_port/timecontrol_part04.inc": [
        "get_dtEvent = min(dtEventEOD, dtEventPrint)",
        "get_dtEvent = min(get_dtEvent, intervalRemaining)",
    ],
    "src/legacy/b1_10_fci11_port/timecontrol_part06.inc": [
        "get_dtEvent = min(get_dtEvent, dtEventRain)",
        "get_dtEvent = min(get_dtEvent, dtEventSSDI)",
        "get_dtEvent = min(get_dtEvent, dtEventRunon)",
    ],
}
for path, patterns in checks.items():
    text=Path(path).read_text()
    for pattern in patterns:
        if pattern not in text:
            raise SystemExit(f"missing guarded source pattern: {path}: {pattern}")
print("F_PE_TIMEARCH04_SOURCE_GUARD=PASS")
