#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  logical :: eligible\n"
if decl not in src:
    raise SystemExit("NLGLOB14D global flag marker missing")
src=src.replace(decl,decl+"  logical :: nl14d_saturated_mode\n",1)

init="  cumrunoff=0.0_real64; eligible=.true.; transition_step=0\n"
if init not in src:
    raise SystemExit("NLGLOB14D init marker missing")
src=src.replace(init,init+"  nl14d_saturated_mode=.false.\n",1)

start="""    saved_state=state
    nominal_dt=dt
"""
insert="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      call advance_klag(step_index)
      write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=0', &
           '|OK=',merge(1,0,eligible),'|DT=',nominal_dt,'|ROUTE=',trim(route_id), &
           '|TERMINAL=',trim(terminal_reason)
      return
    end if

    saved_state=state
    nominal_dt=dt
"""
if start not in src:
    raise SystemExit("NLGLOB14D wrapper start marker missing")
src=src.replace(start,insert,1)

success="""        nominal_ledger=dabs(cumledger-saved_cumledger)
        write(*,'(*(g0))') 'F_PE_NLGLOB14C_SWITCH|STEP=',step_index,'|SWITCH_OK=1|NODE=',event_node, &
"""
success_repl="""        nominal_ledger=dabs(cumledger-saved_cumledger)
        nl14d_saturated_mode=.true.
        write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=1', &
             '|OK=1|DT=',nominal_dt,'|ROUTE=',trim(route_id),'|TERMINAL=',trim(terminal_reason)
        write(*,'(*(g0))') 'F_PE_NLGLOB14C_SWITCH|STEP=',step_index,'|SWITCH_OK=1|NODE=',event_node, &
"""
if success not in src:
    raise SystemExit("NLGLOB14D switch-success marker missing")
src=src.replace(success,success_repl,1)

for req in ("nl14d_saturated_mode","F_PE_NLGLOB14D_MODE","MODE=SATURATED_KLAG"):
    if req not in src:
        raise SystemExit(f"NLGLOB14D injection failed: {req}")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14D_MATERIALIZER=PASS")
