#!/usr/bin/env python3
"""F-AHL12C: retention-only support sweep for the frozen B01 prescribed-qbot case."""
from __future__ import annotations
import pathlib, sys
import ahl09_derivative_consistent as dc

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl12c")
OUT.mkdir(parents=True,exist_ok=True)
P=dc.base.MATERIALS["B01"]

# Retention support must be driven only by theta and C. Conductivity has its
# own F-AHL11 support and must not silently densify this grid.
dc.LOGC_TOL=1e-2
dc.LOGK_TOL=1e99

for name,tol in (("theta3",3e-6),("theta1",1e-6)):
    dc.THETA_TOL=tol
    knots=dc.build(P)
    err=dc.validate(knots,P)
    dc.OUT=OUT
    dc.write_table(f"B01_{name}_ret",P,knots)
    print("AHL12C_RET",name,"points",len(knots),
          "theta_err",f"{err[0]:.12e}","logC_err",f"{err[1]:.12e}")
