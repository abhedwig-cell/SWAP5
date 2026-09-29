#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old="""        eligible=.true.
        terminal_reason=saved_terminal
        transition_step=saved_transition
        call advance_tg_core(step_index,remainder_dt,remainder_fail)
        if(remainder_fail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|SPLIT_OK=0|REASON=REMAINDER_FAILED', &
               '|DOMAIN=',merge(1,0,remainder_fail),'|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt, &
               '|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger,'|EVENT_ROUTE=',event_route
          eligible=.false.
          if(remainder_fail) terminal_reason='SATURATION_EVENT_REMAINDER_DOMAIN_FAILED'
          if(.not.remainder_fail) terminal_reason='SATURATION_EVENT_REMAINDER_ENDPOINT_FAILED'
          transition_step=step_index
          dt=nominal_dt
          return
        end if
"""
new="""        eligible=.true.
        terminal_reason=saved_terminal
        transition_step=saved_transition
        dt=remainder_dt
        call advance_klag(step_index)
        remainder_fail=.not.eligible
        if(remainder_fail)then
          write(*,'(*(g0))') 'F_PE_NLGLOB14C_SPLIT|STEP=',step_index,'|SPLIT_OK=0|REASON=KLAG_REMAINDER_FAILED', &
               '|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt,'|EVENT_DEPTH=',event_depth, &
               '|EVENT_LEDGER=',event_ledger,'|EVENT_ROUTE=',event_route
          eligible=.false.
          terminal_reason='SATURATION_EVENT_KLAG_REMAINDER_ENDPOINT_FAILED'
          transition_step=step_index
          dt=nominal_dt
          return
        end if
"""
if old not in src:
    raise SystemExit("NLGLOB14C TG remainder block missing")
src=src.replace(old,new,1)

old2="""        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|SPLIT_OK=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI=',phi_lo,'|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt, &
             '|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger,'|NOMINAL_LEDGER=',nominal_ledger, &
             '|EVENT_ROUTE=',event_route,'|FINAL_ROUTE=',last_accept_route,'|EVENT_POND=',event_pond, &
             '|FINAL_POND=',state%ponding_depth
"""
new2="""        write(*,'(*(g0))') 'F_PE_NLGLOB14C_SPLIT|STEP=',step_index,'|SPLIT_OK=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI=',phi_lo,'|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt, &
             '|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger,'|NOMINAL_LEDGER=',nominal_ledger, &
             '|EVENT_ROUTE=',event_route,'|FINAL_ROUTE=',last_accept_route,'|EVENT_POND=',event_pond, &
             '|FINAL_POND=',state%ponding_depth,'|REMAINDER_MODE=KLAG'
"""
if old2 not in src:
    raise SystemExit("NLGLOB14C success log marker missing")
src=src.replace(old2,new2,1)

if "F_PE_NLGLOB14C_SPLIT" not in src or "REMAINDER_MODE=KLAG" not in src:
    raise SystemExit("NLGLOB14C injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14C_MATERIALIZER=PASS")
