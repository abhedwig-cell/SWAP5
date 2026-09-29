#!/usr/bin/env python3
from pathlib import Path
import argparse

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

marker="      terminal_reason='ENDPOINT_SOLVE_FAILURE'\\n"
inject="""      if(nl14r_handoff_active .and. step_index==nl14r_handoff_step+1)then
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
if marker not in seg:
    raise SystemExit("NLGLOB14R1 endpoint failure marker missing")
seg=seg.replace(marker,inject+marker,1)
src=src[:tg_start]+seg+src[tg_end:]

if "F_PE_NLGLOB14R1_FAIL" not in src:
    raise SystemExit("NLGLOB14R1 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R1_MATERIALIZER=PASS")
