#!/usr/bin/env python3
"""Generate F-AHL10B derivative-consistent tables for preregistered log(K) tolerances."""
from __future__ import annotations
import json, pathlib, sys
import ahl09_derivative_consistent as dc

ROOT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl10b")
ROOT.mkdir(parents=True,exist_ok=True)
TOLS=[("k3",3e-3),("k1",1e-3),("k03",3e-4),("k01",1e-4)]
summary={"work_unit":"F-AHL10B","variants":{}}

for tag,tol in TOLS:
    out=ROOT/tag
    out.mkdir(parents=True,exist_ok=True)
    dc.LOGK_TOL=tol
    dc.OUT=out
    rows={}
    for mid,p in dc.base.MATERIALS.items():
        knots=dc.build(p)
        err=dc.validate(knots,p)
        dc.write_table(mid,p,knots)
        rows[mid]={
            "points":len(knots),
            "theta_span_error":err[0],
            "log_capacity_error":err[1],
            "log_conductivity_error":err[2],
            "constitutive_pass": err[0] <= dc.THETA_TOL and err[1] <= dc.LOGC_TOL and err[2] <= tol
        }
    summary["variants"][tag]={"logK_tolerance":tol,"materials":rows}

print(json.dumps(summary,indent=2,sort_keys=True))
