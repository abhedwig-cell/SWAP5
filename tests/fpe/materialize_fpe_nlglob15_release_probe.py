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
    raise SystemExit("NLGLOB15 saturated-mode declaration marker missing")
src=src.replace(decl,decl+"  integer :: nl15_event_node\n",1)

init="  nl14d_saturated_mode=.false.\n"
if init not in src:
    raise SystemExit("NLGLOB15 init marker missing")
src=src.replace(init,init+"  nl15_event_node=0\n",1)

local_decl="    real(real64)::remainder_dt,nominal_ledger,event_pond\n"
if local_decl not in src:
    raise SystemExit("NLGLOB15 local declaration marker missing")
src=src.replace(local_decl,local_decl+"    real(real64)::nl15_cum_before,nl15_delta,nl15_u,nl15_interval_ledger\n",1)

entry="        nl14d_saturated_mode=.true.\n"
if entry not in src:
    raise SystemExit("NLGLOB15 entry marker missing")
src=src.replace(entry,entry+"        nl15_event_node=event_node\n",1)

old="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      call advance_klag(step_index)
      write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=0', &
           '|OK=',merge(1,0,eligible),'|DT=',nominal_dt,'|ROUTE=',trim(route_id), &
           '|TERMINAL=',trim(terminal_reason)
      return
    end if
"""
new="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      rain=0.0_real64
      nl15_cum_before=cumledger
      call advance_klag(step_index)
      nl15_interval_ledger=dabs(cumledger-nl15_cum_before)
      if(nl15_event_node>0)then
        nl15_delta=ts-state%water_content(nl15_event_node)
        nl15_u=dabs(spacing(ts))+dabs(spacing(state%water_content(nl15_event_node)))
      else
        nl15_delta=-huge(1.0_real64)
        nl15_u=huge(1.0_real64)
      end if
      write(*,'(*(g0))') 'F_PE_NLGLOB15_RELEASE|STEP=',step_index,'|NODE=',nl15_event_node, &
           '|THETA=',merge(state%water_content(nl15_event_node),0.0_real64,nl15_event_node>0), &
           '|THETA_S=',ts,'|DELTA=',nl15_delta,'|U=',nl15_u, &
           '|R_UNSAT=',nl15_delta/max(nl15_u,tiny(1.0_real64)), &
           '|ELIGIBLE=',merge(1,0,(eligible .and. nl15_event_node>0 .and. nl15_delta>nl15_u)), &
           '|MASS_LEDGER=',nl15_interval_ledger,'|ROUTE=',trim(route_id), &
           '|FINITE=',merge(1,0,eligible),'|TERMINAL=',trim(terminal_reason)
      write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=0', &
           '|OK=',merge(1,0,eligible),'|DT=',nominal_dt,'|ROUTE=',trim(route_id), &
           '|TERMINAL=',trim(terminal_reason)
      return
    end if
"""
if old not in src:
    raise SystemExit("NLGLOB15 persistent-mode marker missing")
src=src.replace(old,new,1)

if "F_PE_NLGLOB15_RELEASE" not in src:
    raise SystemExit("NLGLOB15 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB15_RELEASE_MATERIALIZER=PASS")
