#!/usr/bin/env python3
from pathlib import Path

parts = [
    Path(f"src/legacy/b1_10_fci11_port/timecontrol_part0{i}.inc").read_text()
    for i in range(1,7)
]
text = " ".join(("\n".join(parts)).lower().split())

patterns = [
    "dtmax = min(dtmax, 1.0d0/dble(nprintday))",
    "if (swmetdetail == 1) dtmax = min(dtmax, dt_meteo)",
    "dtmin = min(dtmin, 0.1d0*dtmax)",
    "dt = max(dt, dsqrt(dtmin*dtmax))",
    "get_dtevent = min(dteventeod, dteventprint)",
    "get_dtevent = min(get_dtevent, intervalremaining)",
    "get_dtevent = min(get_dtevent, dteventrain)",
    "get_dtevent = min(get_dtevent, dteventssdi)",
    "get_dtevent = min(get_dtevent, dteventrunon)",
]

for pattern in patterns:
    normalized = " ".join(pattern.lower().split())
    if normalized not in text:
        raise SystemExit(f"missing guarded source pattern: {pattern}")

print("F_PE_TIMEARCH04_SOURCE_GUARD=PASS")
