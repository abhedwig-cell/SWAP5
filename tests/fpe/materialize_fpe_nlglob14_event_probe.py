#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

start=src.find("  subroutine advance_tg_subdiv(step_index)")
if start<0:
    raise SystemExit("NLGLOB14 wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0:
    raise SystemExit("NLGLOB14 wrapper end missing")
end=end+len("  end subroutine advance_tg_subdiv")

wrapper=r"""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state
    logical::domain_fail,event_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt,event_dt
    real(real64)::phi_sat,phi_i,event_ledger,dsat,overshoot
    character(len=64)::saved_terminal
    integer::saved_transition,event_node,i

    saved_state=state
    nominal_dt=dt
    saved_cumledger=cumledger
    saved_cumrunoff=cumrunoff
    saved_maxledger=maxledger
    saved_terminal=terminal_reason
    saved_transition=transition_step

!   prospective full-step trial; no state is committed when the accepted TG
!   moisture lies outside the constitutive domain.
    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    phi_sat=huge(1.0_real64)
    event_node=0
    do i=1,numnod
      if(theta_tg(i)>ts .and. theta_tg(i)>saved_state%water_content(i))then
        phi_i=(ts-saved_state%water_content(i))/(theta_tg(i)-saved_state%water_content(i))
        if(phi_i>0.0_real64 .and. phi_i<1.0_real64 .and. phi_i<phi_sat)then
          phi_sat=phi_i
          event_node=i
        end if
      end if
    end do

    if(event_node==0 .or. .not.ieee_is_finite(phi_sat))then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      dt=nominal_dt
      eligible=.false.
      terminal_reason='SATURATION_EVENT_FRACTION_INVALID'
      transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14_EVENT|STEP=',step_index,'|VALID=0|ROUTE=',trim(route_id)
      return
    end if

    write(*,'(*(g0))') 'F_PE_NLGLOB14_EVENT|STEP=',step_index,'|VALID=1|PHI=',phi_sat, &
         '|NODE=',event_node,'|PRE_THETA=',saved_state%water_content(event_node), &
         '|PROSPECTIVE_THETA=',theta_tg(event_node),'|TS=',ts,'|ROUTE=',trim(route_id)

!   exact rollback to the accepted physical origin before the event trial.
    state=saved_state
    cumledger=saved_cumledger
    cumrunoff=saved_cumrunoff
    maxledger=saved_maxledger
    terminal_reason=saved_terminal
    transition_step=saved_transition
    eligible=.true.

    event_dt=phi_sat*nominal_dt
    dt=event_dt
    call advance_tg_core(step_index,event_dt,event_fail)
    if(event_fail .or. .not.eligible)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      dt=nominal_dt
      eligible=.false.
      terminal_reason='SATURATION_EVENT_TRIAL_FAILED'
      transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14_TRIAL|STEP=',step_index,'|OK=0|PHI=',phi_sat, &
           '|NODE=',event_node,'|ROUTE=',trim(route_id)
      return
    end if

    dsat=ts-state%water_content(event_node)
    overshoot=max(0.0_real64,maxval(state%water_content-ts))
    event_ledger=cumledger-saved_cumledger
    write(*,'(*(g0))') 'F_PE_NLGLOB14_TRIAL|STEP=',step_index,'|OK=1|PHI=',phi_sat, &
         '|NODE=',event_node,'|THETA_EVENT=',state%water_content(event_node),'|TS=',ts, &
         '|DSAT=',dsat,'|DZ=',p%dz(event_node),'|OVERSHOOT=',overshoot, &
         '|LEDGER=',event_ledger,'|POND=',state%ponding_depth,'|ROUTE_BEFORE=',trim(route_id), &
         '|ACCEPT_ROUTE_CODE=',last_accept_route

!   P0 stops after the event-localization probe. The remainder is P1 scope.
    dt=nominal_dt
    eligible=.false.
    terminal_reason='SATURATION_EVENT_PROBE_COMPLETE'
    transition_step=step_index
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]
for req in ("F_PE_NLGLOB14_EVENT","F_PE_NLGLOB14_TRIAL","SATURATION_EVENT_PROBE_COMPLETE"):
    if req not in src:
        raise SystemExit("NLGLOB14 materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14_MATERIALIZER=PASS")
