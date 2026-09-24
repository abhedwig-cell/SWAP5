#!/usr/bin/env python3
"""F-AHL12 tight-envelope derivative-consistent table generator."""
from __future__ import annotations
import pathlib, sys
import ahl09_derivative_consistent as dc

out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl12")
out.mkdir(parents=True,exist_ok=True)
variants={
    "theta1":(1e-6,1e-2),
    "k1":(1e-5,1e-3),
    "both1":(1e-6,1e-3),
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
        print("AHL12_TABLE",mid,name,"points",len(knots),
              "theta",f"{errors[0]:.12e}","logC",f"{errors[1]:.12e}","logK",f"{errors[2]:.12e}")
