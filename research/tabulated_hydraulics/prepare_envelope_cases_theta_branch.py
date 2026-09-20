#!/usr/bin/env python3
"""Prepare TAB-HYD tables with explicit h=-0.01 theta branch boundary.

Post-failure diagnostic.  Conductivity retains the explicit Ksat plateau split.
The continuous table has an exact h=-0.01 knot so theta/C preprocessing can be
split at the analytical default-MvG wet-branch boundary.
"""
from __future__ import annotations
import math, importlib.util
from pathlib import Path

HERE=Path(__file__).parent
spec=importlib.util.spec_from_file_location("tabhyd_base",HERE/"prepare_envelope_cases.py")
prep=importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(prep)

def branch_rows(p: dict, n: int=prep.NROWS):
    if n < 8:
        raise ValueError("need at least 8 rows")
    h0=-1.0e7
    hc=prep.HCRIT
    h1=prep.threshold_head(p)
    if not (h0 < hc < h1 < 0.0):
        raise RuntimeError((p["comment"],"unexpected branch ordering",h0,hc,h1))

    u0=math.log10(-h0)
    uc=math.log10(-hc)
    u1=math.log10(-h1)
    n_intervals=n-2  # n-1 continuous points incl h0,h1, plus final h=0
    span_d=u0-uc
    span_w=uc-u1
    nd=max(2,round(n_intervals*span_d/(span_d+span_w)))
    nw=n_intervals-nd
    if nw < 2:
        nw=2
        nd=n_intervals-nw

    heads=[]
    # h0..hc inclusive
    for i in range(nd+1):
        f=i/nd
        u=u0+f*(uc-u0)
        h=hc if i==nd else -10.0**u
        heads.append(h)
    # hc..h1, skip duplicate hc
    for i in range(1,nw+1):
        f=i/nw
        u=uc+f*(u1-uc)
        h=h1 if i==nw else -10.0**u
        heads.append(h)

    if len(heads) != n-1:
        raise RuntimeError(("row-count",len(heads),n))
    rows=[(h,prep.theta_policy(h,p),prep.k_policy(h,p)) for h in heads]
    rows.append((0.0,p["osat"],p["ksat"]))
    for a,b in zip(rows,rows[1:]):
        if not (b[0]>a[0] and b[1]>a[1] and b[2]>a[2]):
            raise RuntimeError((p["comment"],"nonmonotone branch table",a,b))
    if min(abs(h-hc) for h,_,_ in rows) > 1e-14:
        raise RuntimeError("exact hcrit knot missing")
    return rows

prep.uniform_rows=branch_rows

if __name__=="__main__":
    prep.main()
