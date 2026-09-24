#!/usr/bin/env python3
"""Generate F-AHL03 frozen table files for the Fortran timing screen."""
from __future__ import annotations
import math
import pathlib
import sys
import ahl01_adaptive_lookup as a1
import ahl02_representation_transform as a2

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ahl03")
OUT.mkdir(parents=True, exist_ok=True)

for mid, p in a1.MATERIALS.items():
    direct = a1.adaptive_knots(p)
    transformed = a2.adaptive_knots(p)

    with (OUT / f"{mid}_direct.dat").open("w") as f:
        f.write(" ".join(f"{v:.17e}" for v in p) + "\n")
        f.write(f"{len(direct)}\n")
        for h in reversed(direct):
            theta, c, k = a1.evaluate_core(h, p)
            x = a1.x_from_head(h)
            f.write(f"{x:.17e} {theta:.17e} {math.log(c):.17e} {math.log(k):.17e}\n")

    with (OUT / f"{mid}_logit.dat").open("w") as f:
        f.write(" ".join(f"{v:.17e}" for v in p) + "\n")
        f.write(f"{len(transformed)}\n")
        tr, ts, *_ = p
        for h in reversed(transformed):
            theta, c, k = a1.evaluate_core(h, p)
            se = (theta - tr) / (ts - tr)
            se = min(max(se, 1.0e-15), 1.0 - 1.0e-15)
            z = math.log(se / (1.0 - se))
            x = a1.x_from_head(h)
            f.write(f"{x:.17e} {z:.17e} {math.log(c):.17e} {math.log(k):.17e}\n")
