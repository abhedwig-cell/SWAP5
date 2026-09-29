#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  logical :: eligible\n"
ins=decl+"  logical :: nl14b_remainder_active\n  integer :: nl14b_expected_route\n"
if decl not in src:
    raise SystemExit("NLGLOB14B declaration marker missing")
src=src.replace(decl,ins,1)

init="  terminal_reason='COMPLETE_SAME_ROUTE'\n"
if init not in src:
    raise SystemExit("NLGLOB14B init marker missing")
src=src.replace(init,init+"  nl14b_remainder_active=.false.; nl14b_expected_route=0\n",1)

src=src.replace(
"    if(r0/=target_route)then\n",
"    if(nl14b_remainder_active) nl14b_expected_route=r0\n    if(r0/=target_route .and. .not.nl14b_remainder_active)then\n",
1
)
for old,new in [
("    if(rtilde/=target_route)then\n","    if(rtilde/=merge(nl14b_expected_route,target_route,nl14b_remainder_active))then\n"),
("    if(rp/=target_route)then\n","    if(rp/=merge(nl14b_expected_route,target_route,nl14b_remainder_active))then\n"),
("    if(ra/=target_route)then\n","    if(ra/=merge(nl14b_expected_route,target_route,nl14b_remainder_active))then\n"),
]:
    if old not in src:
        raise SystemExit("NLGLOB14B route marker missing")
    src=src.replace(old,new,1)

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
        nl14b_remainder_active=.true.
        nl14b_expected_route=0
        call advance_tg_core(step_index,(1.0_real64-phi_lo)*nominal_dt,trial_fail)
        nl14b_remainder_active=.false.
        if(trial_fail)then
          state=saved_state
          cumledger=saved_cumledger
          cumrunoff=saved_cumrunoff
          maxledger=saved_maxledger
          eligible=.false.
          terminal_reason='EVENT_REMAINDER_SECOND_CROSSING'
          transition_step=step_index
          write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|OK=0|REASON=SECOND_CROSSING', &
               '|NODE=',event_node,'|PHI=',phi_lo,'|EVENT_LEDGER=',event_ledger
          dt=nominal_dt
          return
        end if
        if(.not.eligible)then
          state=saved_state
          cumledger=saved_cumledger
          cumrunoff=saved_cumrunoff
          maxledger=saved_maxledger
          eligible=.false.
          terminal_reason='EVENT_REMAINDER_SOLVE_FAILED'
          transition_step=step_index
          write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|OK=0|REASON=REMAINDER_SOLVE', &
               '|NODE=',event_node,'|PHI=',phi_lo,'|EVENT_LEDGER=',event_ledger
          dt=nominal_dt
          return
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|OK=1|NODE=',event_node, &
             '|PHI=',phi_lo,'|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger, &
             '|NOMINAL_LEDGER=',dabs(cumledger-saved_cumledger),'|EVENT_ROUTE_CODE=',last_origin_route, &
             '|FINAL_ROUTE_CODE=',last_accept_route,'|REMAINDER_DT=',(1.0_real64-phi_lo)*nominal_dt
        dt=nominal_dt
        return
      end if
"""
if old not in src:
    raise SystemExit("NLGLOB14B localized block missing")
src=src.replace(old,new,1)

for req in ("F_PE_NLGLOB14B_SPLIT","EVENT_REMAINDER_SECOND_CROSSING","nl14b_remainder_active"):
    if req not in src:
        raise SystemExit("NLGLOB14B injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14B_MATERIALIZER=PASS")
