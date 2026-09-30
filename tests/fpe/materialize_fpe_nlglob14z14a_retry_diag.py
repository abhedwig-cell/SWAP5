#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

ks=src.find("  subroutine advance_klag")
ke=src.find("  end subroutine",ks)
if ks<0 or ke<0:
    raise SystemExit("NLGLOB14Z14A KLAG bounds missing")
seg=src[ks:ke]

old="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
new="""    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14Z14A_FAILURE|STEP=',step_index, &
           '|STATUS=',res%status,'|RETRY=',merge(1,0,res%retry_advised), &
           '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
           '|POND=',state%ponding_depth
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
if old not in seg:
    raise SystemExit("NLGLOB14Z14A endpoint failure marker missing")
seg=seg.replace(old,new,1)
src=src[:ks]+seg+src[ke:]
if "F_PE_NLGLOB14Z14A_FAILURE" not in src:
    raise SystemExit("NLGLOB14Z14A injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14Z14A_MATERIALIZER=PASS")
