#!/usr/bin/env python3
"""F-AHL21F: generate tighter derivative-consistent retention supports while
freezing conductivity support exactly to the selected F-AHL15 representation.
"""
from __future__ import annotations
import pathlib, sys
import ahl09_derivative_consistent as dc
import ahl15_wet_local_k as selected

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl21f")
OUT.mkdir(parents=True,exist_ok=True)
p=dc.base.MATERIALS["O05"]

# Build selected F-AHL15 representation once, then freeze its K support/values.
orig_out=selected.OUT
selected.OUT=OUT
sel_knots=selected.build(p)
selected.write_table("O05_selected_joint",p,sel_knots)
selected.OUT=orig_out

joint=OUT/"O05_selected_joint_dc.dat"
lines=joint.read_text().splitlines()
n=int(lines[1])
with (OUT/"O05_selected_k.dat").open("w") as f:
    f.write(f"{n}\n")
    for line in lines[2:]:
        x,z,m,lk=line.split()
        f.write(f"{x} {lk}\n")

variants=[
    ("selected",1e-5,1e-2),
    ("ret3",3e-6,3e-3),
    ("ret1",1e-6,1e-3),
]
for name,tt,ct in variants:
    dc.THETA_TOL=tt
    dc.LOGC_TOL=ct
    knots=dc.build(p)
    old=dc.OUT; dc.OUT=OUT
    dc.write_table(f"O05_{name}_ret",p,knots)
    dc.OUT=old
    print(f"AHL21F_SUPPORT {name} points={len(knots)} theta_tol={tt:.17e} logc_tol={ct:.17e}")
print(f"AHL21F_K_SUPPORT points={n}")
