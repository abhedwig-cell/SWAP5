#!/usr/bin/env python3
"""Generate the F-AHL09 Stage-2 derivative-consistent table for the frozen FSI24 fixture."""
from __future__ import annotations
import json, pathlib, sys
import ahl09_derivative_consistent as dc

out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl09s2")
out.mkdir(parents=True,exist_ok=True)

# Exact FSI24 fixture parameters: theta_r, theta_s, alpha, n, Ksat, lambda.
p=(0.032,0.423,0.0135,1.455,4.75,0.365)
knots=dc.build(p)
errors=dc.validate(knots,p)
dc.OUT=out
dc.write_table("FSI24",p,knots)

summary={
  "work_unit":"F-AHL09_STAGE2",
  "material":"FSI24",
  "points":len(knots),
  "theta_span_error":errors[0],
  "log_capacity_error":errors[1],
  "log_conductivity_error":errors[2],
  "pass": errors[0]<=dc.THETA_TOL and errors[1]<=dc.LOGC_TOL and errors[2]<=dc.LOGK_TOL
}
print(json.dumps(summary,indent=2,sort_keys=True))
