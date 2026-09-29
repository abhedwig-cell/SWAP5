#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

start=src.find("  subroutine advance_tg_subdiv(step_index)")
if start<0: raise SystemExit("NLGLOB14A wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0: raise SystemExit("NLGLOB14A wrapper end missing")
end+=len("  end subroutine advance_tg_subdiv")

wrapper=r"""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state
    logical::domain_fail,trial_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::phi_i,phi_lo,phi_hi,phi_mid,trial_dt,dsat,event_depth,event_ledger,max_over
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
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      eligible=.false.
      terminal_reason='SATURATION_ROOT_BRACKET_INVALID'
      transition_step=step_index
      write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|VALID=0|NODE=',event_node,'|PHI_HI=',phi_hi
      return
    end if

    phi_lo=0.0_real64
    do ibis=1,32
      phi_mid=0.5_real64*(phi_lo+phi_hi)
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      eligible=.true.
      trial_dt=phi_mid*nominal_dt
      call advance_tg_core(step_index,trial_dt,trial_fail)

      if(trial_fail)then
        phi_hi=phi_mid
        cycle
      end if

      if(.not.eligible)then
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        eligible=.false.
        terminal_reason='SATURATION_ROOT_TRIAL_OTHER_FAILED'
        transition_step=step_index
        write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|VALID=1|NODE=',event_node, &
             '|ITER=',ibis,'|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|TRIAL_OK=0'
        return
      end if

      phi_lo=phi_mid
      dsat=ts-state%water_content(event_node)
      event_depth=dabs(dsat)*dabs(p%dz(event_node))
      max_over=maxval(state%water_content-ts)
      event_ledger=dabs(cumledger-saved_cumledger)

      if(event_depth<=5.0e-8_real64 .and. max_over<=0.0_real64)then
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
    end do

    state=saved_state
    cumledger=saved_cumledger
    cumrunoff=saved_cumrunoff
    maxledger=saved_maxledger
    eligible=.false.
    terminal_reason='SATURATION_ROOT_NOT_LOCALIZED'
    transition_step=step_index
    write(*,'(*(g0))') 'F_PE_NLGLOB14A_ROOT|STEP=',step_index,'|VALID=1|NODE=',event_node, &
         '|ITER=32|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|TRIAL_OK=0'
    dt=nominal_dt
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]

old="""    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
      domain_fail=.true.
      return
    end if
"""
new="""    if(any(theta_tg<=tr) .or. any(theta_tg>ts))then
      domain_fail=.true.
      return
    end if
"""
if old not in src: raise SystemExit("NLGLOB14A domain marker missing")
src=src.replace(old,new,1)

for req in ("F_PE_NLGLOB14A_ROOT","SATURATION_ROOT_PROBE_COMPLETE","phi_lo","phi_hi"):
    if req not in src: raise SystemExit("NLGLOB14A injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14A_MATERIALIZER=PASS")
