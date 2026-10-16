#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old_decl="""    logical::domain_fail,trial_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_i,phi_lo,phi_hi,phi_mid,trial_dt,dsat,event_depth,event_ledger,max_over
"""
new_decl="""    logical::domain_fail,trial_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_i,phi_lo,phi_hi,phi_mid,trial_dt,dsat,event_depth,event_ledger,max_over
    real(real64)::remainder_dt,nominal_ledger,event_pond
    integer::event_route
"""
if old_decl not in src:
    raise SystemExit("NLGLOB14C declaration marker missing")
src=src.replace(old_decl,new_decl,1)

old="""      if(event_depth<=5.0e-8_real64 .and. max_over<=0.0_real64)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|VALID=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|TRIAL_OK=1|DSAT=',dsat, &
             '|EVENT_DEPTH=',event_depth,'|MAX_OVER=',max_over,'|EVENT_LEDGER=',event_ledger, &
             '|ROUTE=',trim(route_id),'|POND=',state%ponding_depth
        eligible=.false.
        terminal_reason='SATURATION_ROOT_PROBE_COMPLETE'
        transition_step=step_index
        dt=nominal_dt
        return
      end if
"""
new="""      if(event_depth<=5.0e-8_real64 .and. max_over<=0.0_real64)then
        event_pond=state%ponding_depth
        event_route=last_accept_route
        remainder_dt=nominal_dt-trial_dt
        if(remainder_dt<=0.0_real64)then
          eligible=.false.
          terminal_reason='SATURATION_EVENT_KLAG_REMAINDER_INVALID'
          transition_step=step_index
          write(*,'(*(g0))') 'F_PE_NLGLOB14C_SWITCH|STEP=',step_index,'|SWITCH_OK=0|REASON=REMAINDER_INVALID', &
               '|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt
          dt=nominal_dt
          return
        end if

        eligible=.true.
        terminal_reason=saved_terminal
        transition_step=saved_transition
        dt=remainder_dt
        call advance_klag(step_index)
        if(.not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB14C_SWITCH|STEP=',step_index,'|SWITCH_OK=0|REASON=KLAG_REMAINDER_FAILED', &
               '|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt,'|EVENT_DEPTH=',event_depth, &
               '|EVENT_LEDGER=',event_ledger,'|EVENT_ROUTE=',event_route,'|TERMINAL=',trim(terminal_reason)
          dt=nominal_dt
          return
        end if

        nominal_ledger=dabs(cumledger-saved_cumledger)
        write(*,'(*(g0))') 'F_PE_NLGLOB14C_SWITCH|STEP=',step_index,'|SWITCH_OK=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI=',phi_lo,'|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt, &
             '|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger,'|NOMINAL_LEDGER=',nominal_ledger, &
             '|EVENT_ROUTE=',event_route,'|FINAL_ROUTE=',last_endpoint_route,'|EVENT_POND=',event_pond, &
             '|FINAL_POND=',state%ponding_depth
        dt=nominal_dt
        return
      end if
"""
if old not in src:
    raise SystemExit("NLGLOB14C localized block marker missing")
src=src.replace(old,new,1)

if "F_PE_NLGLOB14C_SWITCH" not in src:
    raise SystemExit("NLGLOB14C injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14C_MATERIALIZER=PASS")
