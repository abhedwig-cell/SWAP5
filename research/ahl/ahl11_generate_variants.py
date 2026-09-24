#!/usr/bin/env python3
"""F-AHL11 generate prospective derivative-consistent tolerance variants."""
from __future__ import annotations
import pathlib, sys
import ahl09_derivative_consistent as dc

out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl11")
out.mkdir(parents=True,exist_ok=True)
variants={
    "base":(1e-5,1e-2),
    "theta3":(3e-6,1e-2),
    "k3":(1e-5,3e-3),
    "both3":(3e-6,3e-3),
}
for name,(ttol,ktol) in variants.items():
    dc.THETA_TOL=ttol
    dc.LOGC_TOL=1e-2
    dc.LOGK_TOL=ktol
    dc.OUT=out
    for mid,p in dc.base.MATERIALS.items():
        knots=dc.build(p)
        errors=dc.validate(knots,p)
        dc.write_table(f"{mid}_{name}",p,knots)
        print(
            "AHL11_TABLE",
            mid,name,
            "points",len(knots),
            "theta",f"{errors[0]:.12e}",
            "logC",f"{errors[1]:.12e}",
            "logK",f"{errors[2]:.12e}",
        )
