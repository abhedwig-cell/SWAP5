#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,re
from pathlib import Path

def d0(x):
    t=format(float(x),".17g")
    if "e" in t.lower():
        m,e=re.split("[eE]",t); return f"{m}d{int(e):+d}"
    return t+"d0"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True); ap.add_argument("--geometry-json",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    g=json.loads(Path(a.geometry_json).read_text())
    z=[float(x) for x in g["z_cm"]]; dz=[float(x) for x in g["dz_cm"]]; ds=[float(x) for x in g["node_distance_cm"]]
    n=len(z)
    src=Path(a.source).read_text()
    pat=re.compile(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n")
    if len(pat.findall(src))!=1: raise SystemExit("F_PE_MULTI06B_FAIL MOD_grid")
    block=("module MOD_grid\n  implicit none\n"
           f"  integer, parameter :: numnod = {n}\n"
           f"  real(8), parameter :: z(numnod) = [{', '.join(d0(x) for x in z)}]\n"
           f"  real(8), parameter :: dz(numnod) = [{', '.join(d0(x) for x in dz)}]\n"
           f"  real(8), parameter :: disnod(numnod+1) = [{', '.join(d0(x) for x in ds+[ds[-1]])}]\n"
           "end module MOD_grid\n")
    Path(a.output).write_text(pat.sub(block,src,count=1))
    print("F_PE_MULTI06B_STUB=PASS")
if __name__=="__main__": main()
