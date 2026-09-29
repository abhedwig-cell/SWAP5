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
    raise SystemExit("NLGLOB13B wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0:
    raise SystemExit("NLGLOB13B wrapper end missing")
end=end+len("  end subroutine advance_tg_subdiv")

wrapper="""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state,half_state
    logical::domain_fail,half_fail,qfail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::half_cumledger,half_cumrunoff,half_maxledger
    character(len=64)::saved_terminal
    integer::saved_transition

    saved_state=state
    nominal_dt=dt
    saved_cumledger=cumledger
    saved_cumrunoff=cumrunoff
    saved_maxledger=maxledger
    saved_terminal=terminal_reason
    saved_transition=transition_step

    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return

    state=saved_state
    cumledger=saved_cumledger
    cumrunoff=saved_cumrunoff
    maxledger=saved_maxledger
    terminal_reason=saved_terminal
    transition_step=saved_transition
    eligible=.true.

!   first half
    half_state=state
    half_cumledger=cumledger
    half_cumrunoff=cumrunoff
    half_maxledger=maxledger
    dt=0.5_real64*nominal_dt
    call advance_tg_core(step_index,dt,half_fail)
    if(half_fail)then
      state=half_state
      cumledger=half_cumledger
      cumrunoff=half_cumrunoff
      maxledger=half_maxledger
      eligible=.true.
      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
      if(qfail .or. .not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB13B_QFAIL|STEP=',step_index,'|HALF=1|QUARTER=1|DOMAIN=',merge(1,0,qfail), &
             '|UNDERLYING=',trim(terminal_reason),'|DT=',dt
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; eligible=.false.
        if(qfail)then
          terminal_reason='NEARSAT_QUARTER_DOMAIN_FAILED'
        else
          terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'
        end if
        transition_step=step_index
        return
      end if
      call advance_tg_core(step_index,dt,qfail)
      if(qfail .or. .not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB13B_QFAIL|STEP=',step_index,'|HALF=1|QUARTER=2|DOMAIN=',merge(1,0,qfail), &
             '|UNDERLYING=',trim(terminal_reason),'|DT=',dt
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; eligible=.false.
        if(qfail)then
          terminal_reason='NEARSAT_QUARTER_DOMAIN_FAILED'
        else
          terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'
        end if
        transition_step=step_index
        return
      end if
      write(*,'(*(g0))') 'F_PE_NLGLOB13B_SUBDIV4|STEP=',step_index,'|HALF=1|QUARTER_DT=',dt,'|ROUTE=',trim(route_id)
    else if(.not.eligible)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      dt=nominal_dt
      terminal_reason='NEARSAT_HALF_OTHER_FAILED'
      transition_step=step_index
      return
    end if

!   second half
    half_state=state
    half_cumledger=cumledger
    half_cumrunoff=cumrunoff
    half_maxledger=maxledger
    dt=0.5_real64*nominal_dt
    call advance_tg_core(step_index,dt,half_fail)
    if(half_fail)then
      state=half_state
      cumledger=half_cumledger
      cumrunoff=half_cumrunoff
      maxledger=half_maxledger
      eligible=.true.
      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
      if(qfail .or. .not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB13B_QFAIL|STEP=',step_index,'|HALF=2|QUARTER=1|DOMAIN=',merge(1,0,qfail), &
             '|UNDERLYING=',trim(terminal_reason),'|DT=',dt
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; eligible=.false.
        if(qfail)then
          terminal_reason='NEARSAT_QUARTER_DOMAIN_FAILED'
        else
          terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'
        end if
        transition_step=step_index
        return
      end if
      call advance_tg_core(step_index,dt,qfail)
      if(qfail .or. .not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB13B_QFAIL|STEP=',step_index,'|HALF=2|QUARTER=2|DOMAIN=',merge(1,0,qfail), &
             '|UNDERLYING=',trim(terminal_reason),'|DT=',dt
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; eligible=.false.
        if(qfail)then
          terminal_reason='NEARSAT_QUARTER_DOMAIN_FAILED'
        else
          terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'
        end if
        transition_step=step_index
        return
      end if
      write(*,'(*(g0))') 'F_PE_NLGLOB13B_SUBDIV4|STEP=',step_index,'|HALF=2|QUARTER_DT=',dt,'|ROUTE=',trim(route_id)
    else if(.not.eligible)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      dt=nominal_dt
      terminal_reason='NEARSAT_HALF_OTHER_FAILED'
      transition_step=step_index
      return
    end if

    dt=nominal_dt
    write(*,'(*(g0))') 'F_PE_NLGLOB13B_SUBDIV_COMPLETE|STEP=',step_index,'|ROUTE=',trim(route_id)
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]
if "F_PE_NLGLOB13B_SUBDIV4" not in src or "NEARSAT_QUARTER_DOMAIN_FAILED" not in src:
    raise SystemExit("NLGLOB13B materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13B_MATERIALIZER=PASS")
