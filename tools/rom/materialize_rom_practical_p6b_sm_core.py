#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib, re

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--workload",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    w=json.loads(a.workload.read_text())
    vals=[float(x["net_atmospheric_proxy_cm_per_day"]) for x in w["records"]]
    if len(vals)!=60: raise SystemExit("expected 60 daily forcing values")
    t=a.source.read_text()
    t=t.replace("integer, parameter :: MAXN=8, NDAYS=60","integer, parameter :: MAXN=8, NDAYS=60")
    # Force SURF_P only for this dedicated workload executable.
    t=t.replace("  if(argc<4.or.argc>5) error stop 'usage: purpose material parameters.nml dt [probe]'",
                "  if(argc<4.or.argc>5) error stop 'usage: purpose material parameters.nml dt [probe]'")
    arr=", &\n       ".join(f"{v:.17g}_real64" for v in vals)
    decl=f"  real(real64), parameter :: P6B_DELTA(60)=[ &\n       {arr} ]\n"
    anchor="  real(real64) :: c0,c1,wall_s\n"
    if anchor not in t: raise SystemExit("declaration anchor missing")
    t=t.replace(anchor,anchor+decl,1)
    old=re.compile(r"    if\(trim\(purpose\)=='SURF_P'\)then\n      if\(history=='SD01'\)then\n.*?      qb=k0\n",re.S)
    repl="    if(trim(purpose)=='SURF_P')then\n      qt=k0+P6B_DELTA(iday)\n      qb=k0\n"
    t,n=old.subn(repl,t,count=1)
    if n!=1: raise SystemExit(f"surface forcing block expected once, found {n}")
    # Rename histories to make workload identity explicit while retaining initial Se.
    t=t.replace("history=merge('SD01','SD02',ih==1)","history=merge('HR72','HR86',ih==1)")
    a.output.write_text(t)
    print("ROM_PRACTICAL_P6B_SM_CORE=PASS")
if __name__=="__main__": main()
