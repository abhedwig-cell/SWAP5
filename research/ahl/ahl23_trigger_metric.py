#!/usr/bin/env python3
from __future__ import annotations
import json, pathlib, sys
import ahl01_adaptive_lookup as base
import ahl22_fallback_indicator_diagnostic as diag

if len(sys.argv)!=5:
    raise SystemExit("usage: metric TABLE MATERIAL HEAD DT")
table=pathlib.Path(sys.argv[1]); material=sys.argv[2]; head=float(sys.argv[3]); dt=float(sys.argv[4])
p=base.MATERIALS[material]
_,rows=diag.load_table(table)
_,c,_=base.evaluate_core(head,p)
_,ci,_=diag.interp_retention(head,p,rows)
metric=max(abs(ci-c)*dz/dt for dz in (0.5,0.5,1.0,1.0))
print(json.dumps({"material":material,"head_cm":head,"dt_day":dt,"metric":metric,"trigger":metric>1e-8}))
