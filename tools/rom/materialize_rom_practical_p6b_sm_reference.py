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
    if len(vals)!=60: raise SystemExit("expected 60 values")
    t=a.source.read_text()
    arr=", &\n       ".join(f"{v:.17g}_real64" for v in vals)
    decl=f"  real(real64), parameter :: P6B_DELTA(60)=[ &\n       {arr} ]\n"
    anchor="  integer, parameter :: NHIST=2, NSTEPS=1920\n  integer, parameter :: OUTPUT_FACTOR=32\n"
    if anchor not in t: raise SystemExit("reference declaration anchor missing")
    t=t.replace(anchor,anchor+decl,1)
    pat=re.compile(r"^  pure real\(real64\) function top_multiplier\(kind,step\) result\(value\).*?^  end function top_multiplier\n",re.M|re.S)
    repl="""  pure real(real64) function top_multiplier(kind,step) result(value)
    integer,intent(in) :: kind,step
    integer :: day
    day=(step-1)/OUTPUT_FACTOR+1
    if(kind<1.or.kind>2.or.day<1.or.day>60)then
      value=huge(0.0_real64)
    else
      value=P6B_DELTA(day)
    end if
  end function top_multiplier
"""
    t,n=pat.subn(repl,t,count=1)
    if n!=1: raise SystemExit(f"top multiplier block expected once, found {n}")
    t=t.replace("case(1); label='SD01'","case(1); label='HR72'")
    t=t.replace("case(2); label='SD02'","case(2); label='HR86'")
    a.output.write_text(t)
    print("ROM_PRACTICAL_P6B_SM_REFERENCE=PASS")
if __name__=="__main__": main()
