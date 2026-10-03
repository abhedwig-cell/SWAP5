#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
new="""    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14N2_SOLVE_FAIL|STEP=',step_index, &
           '|STATUS=',res%status,'|RETRY=',merge(1,0,res%retry_advised), &
           '|ROUTE=',trim(res%diagnostics%route), &
           '|NL=',res%diagnostics%nonlinear_iterations, &
           '|BACK=',res%diagnostics%backtracking_attempts, &
           '|JAC=',res%diagnostics%jacobian_builds, &
           '|LIN=',res%diagnostics%linear_solves, &
           '|INTERNAL_RETRIES=',res%diagnostics%internal_retries, &
           '|ALT=',res%diagnostics%alternative_solver_calls
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
if old not in src:
    raise SystemExit("NLGLOB14N2 endpoint solve marker missing")
src=src.replace(old,new,1)

old2="""      if(.not.eligible)then
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        eligible=.false.
        terminal_reason='SATURATION_ROOT_TRIAL_OTHER_FAILED'
"""
new2="""      if(.not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14N2_ROOT_CONTEXT|STEP=',step_index,'|ITER=',ibis, &
             '|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|PHI_MID=',phi_mid,'|TRIAL_DT=',trial_dt, &
             '|UNDERLYING=',trim(terminal_reason)
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        eligible=.false.
        terminal_reason='SATURATION_ROOT_TRIAL_OTHER_FAILED'
"""
if old2 not in src:
    raise SystemExit("NLGLOB14N2 root context marker missing")
src=src.replace(old2,new2,1)

if "F_PE_NLGLOB14N2_SOLVE_FAIL" not in src or "F_PE_NLGLOB14N2_ROOT_CONTEXT" not in src:
    raise SystemExit("NLGLOB14N2 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14N2_MATERIALIZER=PASS")
