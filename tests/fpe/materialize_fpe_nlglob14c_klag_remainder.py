#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old=r"""    target_route=event_route
    eligible=.true.
    call advance_tg_core(step_index,remainder_dt,remainder_fail)
    if(remainder_fail .or. .not.eligible)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      target_route=saved_target_route
      eligible=.false.; transition_step=step_index
      if(remainder_fail)then
        terminal_reason='SATURATION_SPLIT_REMAINDER_DOMAIN_FAILED'
        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=REMAINDER_DOMAIN', &
             '|PHI=',phi_lo,'|EVENT_ROUTE=',event_route
      else
        terminal_reason='SATURATION_SPLIT_REMAINDER_OTHER_FAILED'
        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=REMAINDER_OTHER', &
             '|PHI=',phi_lo,'|EVENT_ROUTE=',event_route
      end if
      return
    end if

    remainder_route=last_accept_route
"""
new=r"""    target_route=event_route
    eligible=.true.
    dt=remainder_dt
    call advance_klag(step_index)
    dt=nominal_dt
    remainder_fail=.false.
    if(.not.eligible)then
      rem_reason=trim(terminal_reason)
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      target_route=saved_target_route
      eligible=.false.; transition_step=step_index
      terminal_reason='SATURATION_SPLIT_KLAG_REMAINDER_FAILED'
      write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=KLAG_REMAINDER_FAILED', &
           '|PHI=',phi_lo,'|EVENT_ROUTE=',event_route,'|DETAIL=',trim(rem_reason)
      return
    end if

    remainder_route=last_endpoint_route
"""

if old not in src:
    raise SystemExit("NLGLOB14C remainder marker missing")
src=src.replace(old,new,1)

oldlog="""'|REMAINDER_ROUTE=',remainder_route,'|MAX_OVER=',maxval(state%water_content-ts),'|POND=',state%ponding_depth"""
newlog="""'|REMAINDER_ROUTE=',remainder_route,'|REMAINDER_MODE=KLAG|MAX_OVER=',maxval(state%water_content-ts),'|POND=',state%ponding_depth"""
if oldlog not in src:
    raise SystemExit("NLGLOB14C success log marker missing")
src=src.replace(oldlog,newlog,1)

src=src.replace("terminal_reason='SATURATION_EVENT_SPLIT_COMPLETE'","terminal_reason='SATURATION_EVENT_KLAG_SPLIT_COMPLETE'",1)

for req in ("KLAG_REMAINDER_FAILED","REMAINDER_MODE=KLAG","SATURATION_EVENT_KLAG_SPLIT_COMPLETE"):
    if req not in src: raise SystemExit("NLGLOB14C materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14C_MATERIALIZER=PASS")
