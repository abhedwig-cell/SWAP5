#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--factor",required=True,type=int,choices=(64,128))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    t=a.source.read_text()
    old="integer, parameter :: NHIST=2, NSTEPS=1920\n  integer, parameter :: OUTPUT_FACTOR=32"
    new=f"integer, parameter :: NHIST=2, NSTEPS={60*a.factor}\n  integer, parameter :: OUTPUT_FACTOR={a.factor}"
    if t.count(old)!=1: raise SystemExit(f"time grid expected once, found {t.count(old)}")
    t=t.replace(old,new,1)
    olddt="real(real64), parameter :: step_dt=0.03125_real64"
    newdt=f"real(real64), parameter :: step_dt={1.0/a.factor:.17e}_real64"
    if t.count(olddt)!=1: raise SystemExit(f"step dt expected once, found {t.count(olddt)}")
    t=t.replace(olddt,newdt,1)
    a.output.write_text(t)
    print(f"ROM_PRACTICAL_P6B_REFERENCE_T{a.factor}=PASS")
if __name__=="__main__": main()
