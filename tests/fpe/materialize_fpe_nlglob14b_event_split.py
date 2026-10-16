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
new_decl="""    logical::domain_fail,trial_fail,remainder_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_i,phi_lo,phi_hi,phi_mid,trial_dt,dsat,event_depth,event_ledger,max_over
    real(real64)::remainder_dt,nominal_ledger,event_pond
    integer::event_route
"""
if old_decl not in src: raise SystemExit("NLGLOB14B declaration marker missing")
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
          terminal_reason='SATURATION_EVENT_REMAINDER_INVALID'
          transition_step=step_index
          write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|SPLIT_OK=0|REASON=REMAINDER_INVALID', &
               '|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt
          dt=nominal_dt
          return
        end if

        eligible=.true.
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

        nominal_ledger=dabs(cumledger-saved_cumledger)
        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|SPLIT_OK=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI=',phi_lo,'|EVENT_DT=',trial_dt,'|REM_DT=',remainder_dt, &
             '|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger,'|NOMINAL_LEDGER=',nominal_ledger, &
             '|EVENT_ROUTE=',event_route,'|FINAL_ROUTE=',last_accept_route,'|EVENT_POND=',event_pond, &
             '|FINAL_POND=',state%ponding_depth
        dt=nominal_dt
        return
      end if
"""
if old not in src: raise SystemExit("NLGLOB14B localized block marker missing")
src=src.replace(old,new,1)

if "F_PE_NLGLOB14B_SPLIT" not in src: raise SystemExit("NLGLOB14B injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14B_MATERIALIZER=PASS")
