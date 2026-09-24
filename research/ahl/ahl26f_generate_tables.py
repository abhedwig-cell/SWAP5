#!/usr/bin/env python3
from __future__ import annotations
import math,pathlib,sys
import ahl26b_pdi_transform_diagnosis as pdi
import ahl26c_pdi_retention as ret
import ahl26e_pdi_novap_k as kk

OUT=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/ahl26f")
OUT.mkdir(parents=True,exist_ok=True)
for name,p0 in pdi.SETS.items():
    p=dict(p0,ksat=50.0,lpar=0.5)
    rknots=sorted(set(ret.refine(ret.HMAX,ret.HMIN,p)),key=ret.xh)
    kknots=sorted(set(kk.refine(kk.HMAX,kk.HMIN,p,1e-3)),key=kk.xh)
    vals=[
      p["model"],p["tr"],p["ts"],p["a1"],p["n1"],p["m1"],
      p.get("a2",0.0),p.get("n2",0.0),p.get("m2",0.0),p.get("w1",1.0),p.get("w2",0.0),
      p["h0"],p["ha"],p["apar"],p["omegaK"],p["ksat"],p["lpar"]
    ]
    with (OUT/f"{name}.dat").open("w") as f:
        f.write(" ".join(str(v) for v in vals)+"\n")
        f.write(f"{len(rknots)} {len(kknots)}\n")
        for h in rknots:
            z,m=ret.node(h,p)
            f.write(f"R {ret.xh(h):.17e} {z:.17e} {m:.17e}\n")
        for h in kknots:
            f.write(f"K {kk.xh(h):.17e} {math.log(kk.kliq(h,p)):.17e}\n")
    print(name,len(rknots),len(kknots))
