#!/usr/bin/env python3
"""F-AHL12E: capacity-controlled derivative-consistent retention support."""
from __future__ import annotations
import pathlib, sys
import ahl09_derivative_consistent as dc

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl12e")
OUT.mkdir(parents=True,exist_ok=True)
P=dc.base.MATERIALS["B01"]

# Retention support is driven only by theta and C.
dc.THETA_TOL=1e-5
dc.LOGK_TOL=1e99

for name,ctol in (("c1e6",1e-6),("c3e7",3e-7)):
    dc.LOGC_TOL=ctol
    knots=dc.build(P)
    err=dc.validate(knots,P)
    dc.OUT=OUT
    dc.write_table(f"B01_{name}_ret",P,knots)
    print("AHL12E_RET",name,"points",len(knots),
          "theta_err",f"{err[0]:.12e}",
          "logC_err",f"{err[1]:.12e}",
          "logC_tol",ctol)
