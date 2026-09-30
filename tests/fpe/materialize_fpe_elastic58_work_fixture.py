#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fixture",required=True)
    a=ap.parse_args()
    p=Path(a.fixture)
    s=p.read_text(encoding="utf-8")
    old="""       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|half2_nonlinear=',res_half2%diagnostics%nonlinear_iterations
"""
    new="""       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|half2_nonlinear=',res_half2%diagnostics%nonlinear_iterations, &
       '|full_linear=',res_full%diagnostics%linear_solves,'|half1_linear=',res_half1%diagnostics%linear_solves, &
       '|half2_linear=',res_half2%diagnostics%linear_solves, &
       '|full_jacobian=',res_full%diagnostics%jacobian_builds,'|half1_jacobian=',res_half1%diagnostics%jacobian_builds, &
       '|half2_jacobian=',res_half2%diagnostics%jacobian_builds, &
       '|full_backtracking=',res_full%diagnostics%backtracking_attempts, &
       '|half1_backtracking=',res_half1%diagnostics%backtracking_attempts, &
       '|half2_backtracking=',res_half2%diagnostics%backtracking_attempts
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC58_FAIL diagnostic output anchor")
    s=s.replace(old,new,1)
    p.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC58_WORK_FIXTURE=PASS")

if __name__=="__main__":
    main()
