#!/usr/bin/env python3
from pathlib import Path
import argparse, re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

tg_start=src.find("  subroutine advance_tg_core")
tg_end=src.find("  end subroutine advance_tg_core",tg_start)
if tg_start<0 or tg_end<0:
    raise SystemExit("NLGLOB14R1 TG core bounds missing")
seg=src[tg_start:tg_end]

pat=re.compile(r"(\n\s*if\s*\(\s*res%status\s*/=\s*SW_SOLVE_CONVERGED\s*\)\s*then\s*\n)")
m=pat.search(seg)
if not m:
    raise SystemExit("NLGLOB14R1 endpoint failure branch missing")
inject="""\n    if(res%status/=SW_SOLVE_CONVERGED)then
      if(nl14r_handoff_active .and. step_index==nl14r_handoff_step+1)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14R1_FAIL|STEP=',step_index, &
             '|STATUS=',res%status,'|RETRY=',merge(1,0,res%retry_advised), &
             '|ROUTE=',trim(res%diagnostics%route), &
             '|NL=',res%diagnostics%nonlinear_iterations, &
             '|BACK=',res%diagnostics%backtracking_attempts, &
             '|JAC=',res%diagnostics%jacobian_builds, &
             '|LIN=',res%diagnostics%linear_solves, &
             '|INTERNAL_RETRIES=',res%diagnostics%internal_retries, &
             '|ALT=',res%diagnostics%alternative_solver_calls, &
             '|ORIGIN_ROUTE=',last_origin_route,'|PRED_ROUTE=',last_pred_route
      end if
"""
seg=seg[:m.start()]+inject+seg[m.end():]
src=src[:tg_start]+seg+src[tg_end:]

if "F_PE_NLGLOB14R1_FAIL" not in src:
    raise SystemExit("NLGLOB14R1 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R1_MATERIALIZER=PASS")
