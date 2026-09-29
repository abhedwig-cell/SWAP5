#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

start=src.find("  subroutine advance_tg_subdiv(step_index)")
end=src.find("  subroutine advance_tg_core",start)
if start<0 or end<0:
    raise SystemExit("NLGLOB13B subdivision wrapper markers missing")

wrapper="""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    logical::ok
    call advance_tg_segment(step_index,dt,0,ok)
    if(.not.ok)then
      eligible=.false.
      terminal_reason='NEARSAT_SUBDIV4_FAILED'
      transition_step=step_index
    end if
  end subroutine advance_tg_subdiv

  recursive subroutine advance_tg_segment(step_index,segdt,level,ok)
    integer,intent(in)::step_index,level
    real(real64),intent(in)::segdt
    logical,intent(out)::ok
    type(soil_water_physical_state_t)::saved_state
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,saved_dt
    character(len=64)::saved_terminal
    integer::saved_transition
    logical::domain_fail,child_ok

    saved_state=state
    saved_cumledger=cumledger
    saved_cumrunoff=cumrunoff
    saved_maxledger=maxledger
    saved_terminal=terminal_reason
    saved_transition=transition_step
    saved_dt=dt

    dt=segdt
    eligible=.true.
    call advance_tg_core(step_index,segdt,domain_fail)

    if(.not.domain_fail .and. eligible)then
      dt=saved_dt
      ok=.true.
      return
    end if

    if((.not.domain_fail) .or. level>=2)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      dt=saved_dt
      eligible=.true.
      ok=.false.
      return
    end if

    state=saved_state
    cumledger=saved_cumledger
    cumrunoff=saved_cumrunoff
    maxledger=saved_maxledger
    terminal_reason=saved_terminal
    transition_step=saved_transition
    eligible=.true.

    write(*,'(*(g0))') 'F_PE_NLGLOB13B_SPLIT|STEP=',step_index,'|LEVEL=',level, &
         '|PARENT_DT=',segdt,'|CHILD_DT=',0.5_real64*segdt,'|ROUTE=',trim(route_id)

    call advance_tg_segment(step_index,0.5_real64*segdt,level+1,child_ok)
    if(.not.child_ok)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      dt=saved_dt
      eligible=.true.
      ok=.false.
      return
    end if

    call advance_tg_segment(step_index,0.5_real64*segdt,level+1,child_ok)
    if(.not.child_ok)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      terminal_reason=saved_terminal
      transition_step=saved_transition
      dt=saved_dt
      eligible=.true.
      ok=.false.
      return
    end if

    dt=saved_dt
    eligible=.true.
    ok=.true.
  end subroutine advance_tg_segment

"""
src=src[:start]+wrapper+src[end:]
if "F_PE_NLGLOB13B_SPLIT" not in src:
    raise SystemExit("NLGLOB13B materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13B_MATERIALIZER=PASS")
