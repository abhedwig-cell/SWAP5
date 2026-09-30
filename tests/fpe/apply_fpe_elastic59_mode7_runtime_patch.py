#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    a=ap.parse_args()
    p=Path(a.root).resolve()/"src/solver/mod_reference_richards_temporal_indicator.f90"
    s=p.read_text(encoding="utf-8")
    old="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)"
    new="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2 .and. request%boundary%bottom_mode /= 7)"
    if s.count(old)!=1:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL boundary anchor count={s.count(old)}")
    if "request%boundary%bottom_mode == 7" in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL canonical already admits mode7")
    s=s.replace(old,new,1)
    p.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_MODE7_PATCH=PASS")

if __name__=="__main__":
    main()
