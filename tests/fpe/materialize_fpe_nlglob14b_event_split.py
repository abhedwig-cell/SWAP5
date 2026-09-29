#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

start=src.find("  subroutine advance_tg_subdiv(step_index)")
if start<0: raise SystemExit("NLGLOB14B wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0: raise SystemExit("NLGLOB14B wrapper end missing")
end+=len("  end subroutine advance_tg_subdiv")

wrapper=r"""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state
    logical::domain_fail,trial_fail,remainder_fail,localized
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_i,phi_lo,phi_hi,phi_mid,trial_dt,dsat,event_depth,max_over
    real(real64)::event_ledger,remainder_dt,split_ledger
    character(len=64)::saved_terminal
    integer::saved_transition,event_node,i,ibis,saved_target_route,event_route,remainder_route

    saved_state=state
    nominal_dt=dt
    saved_cumledger=cumledger
    saved_cumrunoff=cumrunoff
    saved_maxledger=maxledger
    saved_terminal=terminal_reason
    saved_transition=transition_step
    saved_target_route=target_route

    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    phi_hi=huge(1.0_real64)
    event_node=0
    do i=1,numnod
      if(theta_tg(i)>ts .and. theta_tg(i)>saved_state%water_content(i))then
        phi_i=(ts-saved_state%water_content(i))/(theta_tg(i)-saved_state%water_content(i))
        if(phi_i>0.0_real64 .and. phi_i<phi_hi)then
          phi_hi=phi_i
          event_node=i
        end if
      end if
    end do

    if(event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      target_route=saved_target_route
      eligible=.false.; terminal_reason='SATURATION_SPLIT_BRACKET_INVALID'; transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=INVALID_BRACKET'
      return
    end if

    phi_lo=0.0_real64
    localized=.false.
    do ibis=1,32
      phi_mid=0.5_real64*(phi_lo+phi_hi)
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      target_route=saved_target_route
      eligible=.true.

      trial_dt=phi_mid*nominal_dt
      call advance_tg_core(step_index,trial_dt,trial_fail)

      if(trial_fail)then
        phi_hi=phi_mid
        cycle
      end if
      if(.not.eligible)then
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        target_route=saved_target_route
        eligible=.false.; terminal_reason='SATURATION_SPLIT_EVENT_TRIAL_UNSAFE'; transition_step=step_index
        write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=EVENT_TRIAL_UNSAFE'
        return
      end if

      phi_lo=phi_mid
      dsat=ts-state%water_content(event_node)
      event_depth=dabs(dsat)*dabs(p%dz(event_node))
      max_over=maxval(state%water_content-ts)
      if(event_depth<=5.0e-8_real64 .and. max_over<=0.0_real64)then
        localized=.true.
        exit
      end if
    end do

    if(.not.localized)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      target_route=saved_target_route
      eligible=.false.; terminal_reason='SATURATION_SPLIT_EVENT_NOT_LOCALIZED'; transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=EVENT_NOT_LOCALIZED'
      return
    end if

    event_route=last_accept_route
    event_ledger=dabs(cumledger-saved_cumledger)
    remainder_dt=(1.0_real64-phi_lo)*nominal_dt
    if(.not.ieee_is_finite(remainder_dt) .or. remainder_dt<=0.0_real64)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      target_route=saved_target_route
      eligible=.false.; terminal_reason='SATURATION_SPLIT_REMAINDER_INVALID'; transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=0|REASON=REMAINDER_INVALID'
      return
    end if

    target_route=event_route
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
    split_ledger=dabs(cumledger-saved_cumledger)
    write(*,'(*(g0))') 'F_PE_NLGLOB14B_SPLIT|STEP=',step_index,'|COMPLETE=1|PHI=',phi_lo, &
         '|BISECT=',ibis,'|NODE=',event_node,'|EVENT_DEPTH=',event_depth,'|EVENT_LEDGER=',event_ledger, &
         '|REMAINDER_DT=',remainder_dt,'|SPLIT_LEDGER=',split_ledger,'|EVENT_ROUTE=',event_route, &
         '|REMAINDER_ROUTE=',remainder_route,'|MAX_OVER=',maxval(state%water_content-ts),'|POND=',state%ponding_depth

    target_route=saved_target_route
    eligible=.false.
    terminal_reason='SATURATION_EVENT_SPLIT_COMPLETE'
    transition_step=step_index
    dt=nominal_dt
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]
for req in ("F_PE_NLGLOB14B_SPLIT","SATURATION_EVENT_SPLIT_COMPLETE","REMAINDER_DOMAIN"):
    if req not in src: raise SystemExit("NLGLOB14B materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14B_MATERIALIZER=PASS")
