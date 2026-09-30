#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,re
from pathlib import Path

def d0(x):
    text=format(float(x),".17g")
    if "e" in text.lower():
        mantissa,exponent=re.split("[eE]",text)
        return f"{mantissa}d{int(exponent):+d}"
    return text+"d0"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True)
    ap.add_argument("--geometry-json",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    g=json.loads(Path(a.geometry_json).read_text())
    z=[float(v) for v in g["z_cm"]]; dz=[float(v) for v in g["dz_cm"]]; dis=[float(v) for v in g["node_distance_cm"]]
    n=len(z)
    if n<=0 or len(dz)!=n or len(dis)!=n: raise SystemExit("F_PE_ELASTIC70_FAIL invalid geometry")
    source=Path(a.source).read_text()
    pattern=re.compile(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n")
    if len(pattern.findall(source))!=1: raise SystemExit("F_PE_ELASTIC70_FAIL MOD_grid block")
    block=("module MOD_grid\n"
           "  implicit none\n"
           f"  integer, parameter :: numnod = {n}\n"
           f"  real(8), parameter :: z(numnod) = [{', '.join(d0(v) for v in z)}]\n"
           f"  real(8), parameter :: dz(numnod) = [{', '.join(d0(v) for v in dz)}]\n"
           f"  real(8), parameter :: disnod(numnod+1) = [{', '.join(d0(v) for v in dis+[dis[-1]])}]\n"
           "end module MOD_grid\n")
    Path(a.output).write_text(pattern.sub(block,source,count=1))
    print("F_PE_ELASTIC70_STUB_GRID=PASS")
if __name__=="__main__": main()
