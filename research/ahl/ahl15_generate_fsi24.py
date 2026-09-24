#!/usr/bin/env python3
"""Generate F-AHL15 floor-scaled shared-support table for the frozen FSI24 timing fixture."""
from __future__ import annotations
import json, pathlib, sys
import ahl15_floor_scaled_k as a15

out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl15r")
out.mkdir(parents=True,exist_ok=True)
p=(0.032,0.423,0.0135,1.455,4.75,0.365)
knots=a15.build(p)
e=a15.validate(knots,p)
a15.OUT=out
a15.write_table("FSI24",p,knots)
print(json.dumps({
 "points":len(knots),
 "theta_span_error":e[0],
 "log_capacity_error":e[1],
 "floored_logK_error":e[2]
},indent=2))
