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
    raise SystemExit("NLGLOB13D wrapper start missing")
end=src.find("  end subroutine advance_tg_subdiv",start)
if end<0:
    raise SystemExit("NLGLOB13D wrapper end missing")
end=end+len("  end subroutine advance_tg_subdiv")

wrapper=r"""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state,half_state,quarter_state
    logical::domain_fail,half_fail,qfail,efail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
    real(real64)::half_cumledger,half_cumrunoff,half_maxledger
    real(real64)::quarter_cumledger,quarter_cumrunoff,quarter_maxledger
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

      quarter_state=state
      quarter_cumledger=cumledger
      quarter_cumrunoff=cumrunoff
      quarter_maxledger=maxledger
      call advance_tg_core(step_index,dt,qfail)
      if(qfail)then
        state=quarter_state
        cumledger=quarter_cumledger
        cumrunoff=quarter_cumrunoff
        maxledger=quarter_maxledger
        eligible=.true.
        dt=0.125_real64*nominal_dt
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=1|QUARTER=1|EIGHTH=1|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=1|QUARTER=1|EIGHTH=2|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB13D_SUBDIV8|STEP=',step_index,'|HALF=1|QUARTER=1|DT=',dt
      else if(.not.eligible)then
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'; transition_step=step_index; return
      end if

      quarter_state=state
      quarter_cumledger=cumledger
      quarter_cumrunoff=cumrunoff
      quarter_maxledger=maxledger
      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
      if(qfail)then
        state=quarter_state
        cumledger=quarter_cumledger
        cumrunoff=quarter_cumrunoff
        maxledger=quarter_maxledger
        eligible=.true.
        dt=0.125_real64*nominal_dt
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=1|QUARTER=2|EIGHTH=1|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=1|QUARTER=2|EIGHTH=2|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB13D_SUBDIV8|STEP=',step_index,'|HALF=1|QUARTER=2|DT=',dt
      else if(.not.eligible)then
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'; transition_step=step_index; return
      end if
    else if(.not.eligible)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      dt=nominal_dt; terminal_reason='NEARSAT_HALF_OTHER_FAILED'; transition_step=step_index; return
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

      quarter_state=state
      quarter_cumledger=cumledger
      quarter_cumrunoff=cumrunoff
      quarter_maxledger=maxledger
      call advance_tg_core(step_index,dt,qfail)
      if(qfail)then
        state=quarter_state
        cumledger=quarter_cumledger
        cumrunoff=quarter_cumrunoff
        maxledger=quarter_maxledger
        eligible=.true.
        dt=0.125_real64*nominal_dt
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=2|QUARTER=1|EIGHTH=1|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=2|QUARTER=1|EIGHTH=2|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB13D_SUBDIV8|STEP=',step_index,'|HALF=2|QUARTER=1|DT=',dt
      else if(.not.eligible)then
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'; transition_step=step_index; return
      end if

      quarter_state=state
      quarter_cumledger=cumledger
      quarter_cumrunoff=cumrunoff
      quarter_maxledger=maxledger
      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
      if(qfail)then
        state=quarter_state
        cumledger=quarter_cumledger
        cumrunoff=quarter_cumrunoff
        maxledger=quarter_maxledger
        eligible=.true.
        dt=0.125_real64*nominal_dt
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=2|QUARTER=2|EIGHTH=1|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        call advance_tg_core(step_index,dt,efail)
        if(efail .or. .not.eligible)then
          write(*,'(*(g0))') 'F_PE_NLGLOB13D_EFAIL|STEP=',step_index,'|HALF=2|QUARTER=2|EIGHTH=2|DOMAIN=',merge(1,0,efail),'|DT=',dt
          state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
          dt=nominal_dt; eligible=.false.; terminal_reason='NEARSAT_EIGHTH_FAILED'; transition_step=step_index; return
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB13D_SUBDIV8|STEP=',step_index,'|HALF=2|QUARTER=2|DT=',dt
      else if(.not.eligible)then
        state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
        dt=nominal_dt; terminal_reason='NEARSAT_QUARTER_OTHER_FAILED'; transition_step=step_index; return
      end if
    else if(.not.eligible)then
      state=saved_state; cumledger=saved_cumledger; cumrunoff=saved_cumrunoff; maxledger=saved_maxledger
      dt=nominal_dt; terminal_reason='NEARSAT_HALF_OTHER_FAILED'; transition_step=step_index; return
    end if

    dt=nominal_dt
    write(*,'(*(g0))') 'F_PE_NLGLOB13D_SUBDIV_COMPLETE|STEP=',step_index,'|ROUTE=',trim(route_id)
  end subroutine advance_tg_subdiv"""

src=src[:start]+wrapper+src[end:]
for req in ("F_PE_NLGLOB13D_SUBDIV8","NEARSAT_EIGHTH_FAILED"):
    if req not in src:
        raise SystemExit("NLGLOB13D materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13D_MATERIALIZER=PASS")
