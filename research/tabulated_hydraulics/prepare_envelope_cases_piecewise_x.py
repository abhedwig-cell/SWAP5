#!/usr/bin/env python3
"""Piecewise-uniform x=-ln(1-h) tables for TAB-HYD acceleration research.

The grid uses 400 rows by default. Rows 1..N-1 cover the continuous branch.
A fixed breakpoint at h=-1 cm allocates 128 intervals to the wet segment from
h=-1 cm to the generated K-branch threshold; the remaining intervals cover
-1e7..-1 cm. Row N is the explicit h=0/Ksat plateau endpoint.
"""
from __future__ import annotations
import math
import importlib.util
from pathlib import Path

HERE=Path(__file__).parent
spec=importlib.util.spec_from_file_location("tabhyd_base",HERE/"prepare_envelope_cases.py")
prep=importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(prep)

HBREAK=-1.0
NWET=128
NROWS=400

def xcoord(h: float) -> float:
    return -math.log(1.0-h)

def piecewise_x_rows(p: dict, n: int=NROWS, nwet: int=NWET):
    h0=-1.0e7
    h1=prep.threshold_head(p)
    hb=HBREAK
    if not (h0 < hb < h1 < 0.0):
        raise RuntimeError((p["comment"],"unexpected piecewise-x ordering",h0,hb,h1))
    total_intervals=n-2
    if nwet < 2 or nwet >= total_intervals-1:
        raise ValueError((n,nwet))
    ndry=total_intervals-nwet

    x0=xcoord(h0)
    xb=xcoord(hb)
    x1=xcoord(h1)
    heads=[]

    for i in range(ndry+1):
        f=i/ndry
        x=x0+f*(xb-x0)
        h=hb if i==ndry else 1.0-math.exp(-x)
        heads.append(h)

    for i in range(1,nwet+1):
        f=i/nwet
        x=xb+f*(x1-xb)
        h=h1 if i==nwet else 1.0-math.exp(-x)
        heads.append(h)

    if len(heads)!=n-1:
        raise RuntimeError(("continuous-row-count",len(heads),n))
    rows=[(h,prep.theta_policy(h,p),prep.k_policy(h,p)) for h in heads]
    rows.append((0.0,p["osat"],p["ksat"]))
    for a,b in zip(rows,rows[1:]):
        if not (b[0]>a[0] and b[1]>a[1] and b[2]>a[2]):
            raise RuntimeError((p["comment"],"nonmonotone piecewise-x table",a,b))
    return rows

prep.NROWS=NROWS
prep.uniform_rows=piecewise_x_rows

if __name__=="__main__":
    prep.main()
