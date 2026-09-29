#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  logical :: nl14d_saturated_mode\n"
if decl not in src:
    raise SystemExit("NLGLOB14F saturated-mode declaration marker missing")
src=src.replace(decl,decl+"  integer :: nl14f_event_node,nl14f_i\n",1)

init="  nl14d_saturated_mode=.false.\n"
if init not in src:
    raise SystemExit("NLGLOB14F init marker missing")
src=src.replace(init,init+"  nl14f_event_node=0\n",1)

entry="""        nl14d_saturated_mode=.true.
        write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=1', &
"""
entry_repl="""        nl14d_saturated_mode=.true.
        nl14f_event_node=event_node
        write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=1', &
"""
if entry not in src:
    raise SystemExit("NLGLOB14F entry marker missing")
src=src.replace(entry,entry_repl,1)

decl2="    integer::r0,rp\n"
if decl2 not in src:
    raise SystemExit("NLGLOB14F advance_klag declaration marker missing")
src=src.replace(decl2,"    integer::r0,rp,nl14f_i\n",1)

needle="""    state=res%candidate_state
  end subroutine
"""
repl="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
      do nl14f_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB14F_STATE|STEP=',step_index,'|NODE=',nl14f_i, &
             '|EVENT_NODE=',nl14f_event_node,'|H=',state%pressure_head(nl14f_i),'|THETA=',state%water_content(nl14f_i), &
             '|THETA_S=',ts,'|DEFICIT=',ts-state%water_content(nl14f_i),'|SAT_H=',merge(1,0,state%pressure_head(nl14f_i)>=0.0_real64), &
             '|SAT_THETA=',merge(1,0,state%water_content(nl14f_i)==ts),'|ROUTE=',trim(route_id), &
             '|TOP_FLUX=',res%top_flux,'|BOTTOM_FLUX=',res%bottom_flux,'|POND=',state%ponding_depth
      end do
    end if
  end subroutine
"""
# replace the occurrence in advance_klag, which is the last exact state assignment before its end
idx=src.rfind(needle)
if idx<0:
    raise SystemExit("NLGLOB14F advance_klag state marker missing")
src=src[:idx]+src[idx:].replace(needle,repl,1)

if "F_PE_NLGLOB14F_STATE" not in src or "nl14f_event_node" not in src:
    raise SystemExit("NLGLOB14F injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14F_MATERIALIZER=PASS")
