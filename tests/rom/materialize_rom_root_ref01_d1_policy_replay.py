#!/usr/bin/env python3
"""Align the legacy C6R failure replay with the already-bound REF01 policy.

Diagnostic-only repair. It changes no executed REF01 trial. The direct
Reference replay inside diagnose_failed_interval must use the parameter object's
current total-balance tolerance rather than the historical C6R constant.
"""
from __future__ import annotations
import argparse
from pathlib import Path

START="  subroutine diagnose_failed_interval"
END="  end subroutine diagnose_failed_interval"
MARKER="ROM_ROOT_REF01_D1_POLICY_REPLAY"

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--path",required=True,type=Path)
    args=ap.parse_args()
    text=args.path.read_text()
    i=text.find(START); j=text.find(END,i)
    if i<0 or j<0:
        raise SystemExit("diagnose_failed_interval block missing")
    block=text[i:j]
    if MARKER in block:
        return 0
    old1="    request%numerical%total_balance_tolerance=original_total_tol\n"
    new1="    request%numerical%total_balance_tolerance=p%total_balance_tolerance\n"
    old2="else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and.rmax<=p%compartment_balance_tolerance.and.abs(rsum)>original_total_tol)then\n"
    new2="else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and.rmax<=p%compartment_balance_tolerance.and.abs(rsum)>p%total_balance_tolerance)then\n"
    if block.count(old1)!=1 or block.count(old2)!=1:
        raise SystemExit(f"unexpected diagnostic policy anchors: total={block.count(old1)} class={block.count(old2)}")
    block=block.replace(old1,new1,1).replace(old2,new2,1)
    anchor="    call solver%solve(request,workspace,result)\n"
    if block.count(anchor)!=1:
        raise SystemExit("solver replay anchor missing")
    block=block.replace(anchor,
        "    write(*,'(*(g0))') 'ROM_ROOT_REF01_D1_TOL|TOTAL=',p%total_balance_tolerance, &\n"
        "         '|LOCAL=',p%compartment_balance_tolerance,'|"+MARKER+"=TRUE'\n"+anchor,1)
    args.path.write_text(text[:i]+block+text[j:])
    return 0

if __name__=="__main__":
    raise SystemExit(main())
