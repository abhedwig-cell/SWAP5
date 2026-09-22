#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

START="  subroutine diagnose_failed_interval"
END="  end subroutine diagnose_failed_interval"
MARKER="ROM_ROOT_RNP02_SHADOW128"

def one(text,old,new,label):
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    text=args.input.read_text()
    i=text.find(START); j=text.find(END,i)
    if i<0 or j<0:
        raise SystemExit("diagnose_failed_interval block not found")
    block=text[i:j]
    if MARKER in block:
        raise SystemExit("already patched")
    block=one(block,
        "    type(soil_water_solve_result_t) :: result\n",
        "    type(soil_water_solve_result_t) :: result, shadow_result128\n",
        "result declaration")
    block=one(block,
        "    type(reference_richards_legacy_workspace_t) :: workspace\n",
        "    type(reference_richards_legacy_workspace_t) :: workspace, shadow_workspace128\n",
        "workspace declaration")
    anchor="    if(allocated(snap))deallocate(snap)\n"
    extra="""    ! ROM_ROOT_RNP02_SHADOW128: diagnostic only, exact same state/forcing/tolerances.
    request%numerical%max_iterations=128
    call solver%solve(request,shadow_workspace128,shadow_result128)
    write(*,'(*(g0))') 'RNP02_SHADOW128|STATUS=',shadow_result128%status, &
         '|ROUTE=',trim(shadow_result128%diagnostics%route), &
         '|NL=',shadow_result128%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',shadow_result128%diagnostics%backtracking_attempts, &
         '|SUM=',sum(shadow_workspace128%richards%residual), &
         '|FMAX=',maxval(abs(shadow_workspace128%richards%residual)), &
         '|SUMP=',0.5_real64*sum(shadow_workspace128%richards%residual*shadow_workspace128%richards%residual)
"""
    block=one(block,anchor,extra+anchor,"shadow insertion")
    text=text[:i]+block+text[j:]
    args.output.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
