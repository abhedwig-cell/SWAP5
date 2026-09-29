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
    raise SystemExit("NLGLOB14A wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0:
    raise SystemExit("NLGLOB14A wrapper end missing")
end+=len("  end subroutine advance_tg_subdiv")

wrapper=r"""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state
    logical::domain_fail,mid_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_linear,phi_i,phi_lo,phi_hi,phi_mid,denom
    real(real64)::event_dt,water_dist,max_over
    character(len=64)::saved_terminal
    integer::saved_transition,event_node,i,ibis

    saved_state=state
    nominal_dt=dt
    saved_cumledger=cumledger
    saved_cumrunoff=cumrunoff
    saved_maxledger=maxledger
    saved_terminal=terminal_reason
    saved_transition=transition_step

    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    phi_linear=huge(1.0_real64)
    event_node=0
    do i=1,numnod
      denom=theta_tg(i)-saved_state%water_content(i)
      if(theta_tg(i)>ts .and. denom>0.0_real64)then
        phi_i=(ts-saved_state%water_content(i))/denom
        if(phi_i>0.0_real64 .and. phi_i<phi_linear)then
          phi_linear=phi_i
          event_node=i
        end if
      end if
    end do

    if(event_node==0 .or. .not.ieee_is_finite(phi_linear) .or. phi_linear<=0.0_real64 .or. phi_linear>=1.0_real64)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      eligible=.false.
      terminal_reason='SATURATION_ROOT_BRACKET_INVALID'
      transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|LOCALIZED=0|REASON=INVALID_BRACKET'
      return
    end if

    phi_lo=0.0_real64
    phi_hi=phi_linear

    do ibis=1,32
      phi_mid=0.5_real64*(phi_lo+phi_hi)
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      eligible=.true.

      event_dt=phi_mid*nominal_dt
      call advance_tg_core(step_index,event_dt,mid_fail)

      if(mid_fail)then
        phi_hi=phi_mid
        cycle
      end if

      if(.not.eligible)then
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        terminal_reason='SATURATION_ROOT_TRIAL_UNSAFE'
        transition_step=step_index
        eligible=.false.
        write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|LOCALIZED=0|REASON=TRIAL_UNSAFE', &
             '|ITER=',ibis,'|PHI=',phi_mid
        return
      end if

      phi_lo=phi_mid
      water_dist=dabs(ts-state%water_content(event_node))*dabs(p%dz(event_node))
      max_over=maxval(state%water_content-ts)

      if(water_dist<=5.0e-8_real64 .and. max_over<=0.0_real64)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|LOCALIZED=1|ITER=',ibis, &
             '|NODE=',event_node,'|PHI_LINEAR=',phi_linear,'|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi, &
             '|WATER_DIST=',water_dist,'|MAX_OVER=',max_over,'|MAX_LEDGER=',maxledger, &
             '|ORIGIN_ROUTE_CODE=',last_origin_route,'|EVENT_ROUTE_CODE=',last_accept_route, &
             '|POND=',state%ponding_depth
        terminal_reason='SATURATION_ROOT_LOCALIZED'
        transition_step=step_index
        eligible=.false.
        dt=nominal_dt
        return
      end if
    end do

    state=saved_state
    cumledger=saved_cumledger
    cumrunoff=saved_cumrunoff
    maxledger=saved_maxledger
    terminal_reason='SATURATION_ROOT_NOT_LOCALIZED'
    transition_step=step_index
    eligible=.false.
    write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|LOCALIZED=0|REASON=MAX_BISECTION', &
         '|PHI_LINEAR=',phi_linear,'|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi
    dt=nominal_dt
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]
for req in ("F_PE_NLGLOB14A_ROOT","SATURATION_ROOT_LOCALIZED","do ibis=1,32"):
    if req not in src:
        raise SystemExit("NLGLOB14A materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14A_MATERIALIZER=PASS")
