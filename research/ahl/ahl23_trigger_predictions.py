#!/usr/bin/env python3
"""F-AHL23 frozen storage-Jacobian trigger evaluation for prospectively defined cases."""
from __future__ import annotations
import math, pathlib, subprocess, sys
import ahl01_adaptive_lookup as base
from ahl22_fallback_indicator_diagnostic import load_table, interp_retention

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl23")
OUT.mkdir(parents=True,exist_ok=True)
subprocess.run(["python3","research/ahl/ahl15_wet_local_k.py",str(OUT)],check=True,stdout=subprocess.DEVNULL)

CASES=[
 ("B01_dry_dt0060","B01",-500.0,0.060),
 ("B01_dry_dt0065","B01",-500.0,0.065),
 ("O05_dry_dt0060","O05",-500.0,0.060),
 ("O05_dry_dt0065","O05",-500.0,0.065),
]
THRESH=1e-8
for cid,mid,h,dt in CASES:
    p=base.MATERIALS[mid]
    _,rows=load_table(OUT/f"{mid}_dc.dat")
    _,c,_=base.evaluate_core(h,p)
    _,ci,_=interp_retention(h,p,rows)
    metric=max(abs(ci-c)*dz/dt for dz in (0.5,0.5,1.0,1.0))
    pred="FALLBACK" if metric>THRESH else "LOOKUP_SAFE"
    print(f"AHL23_TRIGGER {cid} metric={metric:.17e} threshold={THRESH:.17e} prediction={pred}")
