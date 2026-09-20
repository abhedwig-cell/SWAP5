#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import importlib.util
import math
import sys

prep_path = Path(__file__).with_name("prepare_hupsel_e2e.py")
spec = importlib.util.spec_from_file_location("tabhyd_prep", prep_path)
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)

def relsat(h: float, p: tuple[float, ...]) -> float:
    th = prep.theta_policy(h, p)
    return (th-p[0])/(p[1]-p[0])

def threshold_head(p: tuple[float, ...], k_margin: float = 1.0e-8) -> float:
    """Wettest negative head whose K is still strictly below Ksat.

    The current ReadSwap table contract requires conductab to be strictly
    increasing.  Using the relative-saturation cut-off directly can already
    land on the Ksat clamp because the analytical K expression itself reaches
    the min(K, Ksat) cap slightly before the relsat threshold.  Bind the
    uniform negative grid to a conductivity target instead.
    """
    lo = -1.0e7
    hi = -1.0e-12
    target = p[4] * (1.0 - k_margin)
    if not (prep.k_policy(lo, p) < target < prep.k_policy(hi, p)):
        raise RuntimeError("strict-K wet endpoint not bracketed")
    for _ in range(120):
        mid = 0.5 * (lo + hi)
        if prep.k_policy(mid, p) <= target:
            lo = mid
        else:
            hi = mid
    return lo

def rows_uniform_x(p: tuple[float, ...], n: int):
    if n < 4:
        raise ValueError("n must be >=4")
    h0 = -1.0e7
    h1 = threshold_head(p)
    if not prep.k_policy(h1,p) < p[4]:
        raise RuntimeError("uniform-x negative endpoint is not strictly below Ksat")
    x0 = -math.log(1.0-h0)
    x1 = -math.log(1.0-h1)
    rows=[]
    for i in range(n-1):
        frac=i/(n-2)
        x=x0+frac*(x1-x0)
        # Preserve the bisection-certified wet endpoint exactly.  The
        # x->h round-trip can move the final negative knot a few ulps to
        # the wet side and cross the discontinuous Ksat clamp.
        h=h1 if i == n-2 else 1.0-math.exp(-x)
        th=prep.theta_policy(h,p)
        k=prep.k_policy(h,p)
        rows.append((h,th,k))
    rows.append((0.0,p[1],p[4]))
    for a,b in zip(rows,rows[1:]):
        if not (b[0]>a[0] and b[1]>a[1] and b[2]>a[2]):
            raise RuntimeError(f"nonmonotone uniform-x table: {a} -> {b}")
    return rows

def write(path: Path, p: tuple[float, ...], n: int):
    rows=rows_uniform_x(p,n)
    with path.open("w",newline="\n") as fh:
        fh.write("* TAB-HYD research uniform transformed-x table\n")
        fh.write("headtab,thetatab,conductab\n")
        for h,th,k in rows:
            fh.write(f"{h:.16e},{th:.16e},{k:.16e}\n")
    return rows

def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: generate_uniform_x_hupsel_tables.py CASE_DIR N")
    case=Path(sys.argv[1])
    n=int(sys.argv[2])
    for name,p in zip(prep.TABLE_NAMES,prep.PARAMS):
        rows=write(case/name,p,n)
        x0=-math.log(1.0-rows[0][0])
        xlast=-math.log(1.0-rows[-2][0])
        dx=(xlast-x0)/(n-2)
        print(f"{name} rows={n} x0={x0:.17e} xlast={xlast:.17e} dx={dx:.17e}")
if __name__=="__main__":
    main()
