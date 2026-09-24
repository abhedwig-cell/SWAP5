#!/usr/bin/env python3
from __future__ import annotations
import math,pathlib,sys
import ahl25b_model3_retention as ret
import ahl25c_model3_conductivity as kon

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl25d")
OUT.mkdir(parents=True,exist_ok=True)

for name,pfull in kon.SETS.items():
    pret=pfull[:9]
    rknots=sorted(set(ret.refine(ret.HMAX,ret.HMIN,pret)),key=ret.xh)
    kknots=sorted(set(kon.refine(kon.HMAX,kon.HMIN,pfull)),key=kon.xh)
    with (OUT/f"{name}.dat").open("w") as f:
        f.write(" ".join(f"{v:.17e}" for v in pfull)+"\n")
        f.write(f"{len(rknots)} {len(kknots)}\n")
        for h in rknots:
            z,m=ret.node(h,pret)
            f.write(f"R {ret.xh(h):.17e} {z:.17e} {m:.17e}\n")
        for h in kknots:
            f.write(f"K {kon.xh(h):.17e} {math.log(kon.exact_k(h,pfull)):.17e}\n")
    print(name,len(rknots),len(kknots))
