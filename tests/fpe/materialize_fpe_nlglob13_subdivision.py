#!/usr/bin/env python3
from pathlib import Path
import argparse,re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old_call="""    if(trim(mode)=='TG')then
      call advance_tg(step)
    else
"""
new_call="""    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
if old_call not in src:
    raise SystemExit("NLGLOB13 main TG call marker missing")
src=src.replace(old_call,new_call,1)

start=src.find("  subroutine advance_tg(step_index)")
if start<0:
    raise SystemExit("NLGLOB13 advance_tg start missing")
end=src.find("  end subroutine",start)
if end<0:
    raise SystemExit("NLGLOB13 advance_tg end missing")
end=end+len("  end subroutine")
body=src[start:end]

body=body.replace(
"  subroutine advance_tg(step_index)\n    integer,intent(in)::step_index",
"  subroutine advance_tg_core(step_index,stepdt,domain_fail)\n    integer,intent(in)::step_index\n    real(real64),intent(in)::stepdt\n    logical,intent(out)::domain_fail"
)
body=body.replace(
"    type(soil_water_physical_state_t)::predstate,acceptstate",
"    type(soil_water_physical_state_t)::predstate,acceptstate\n    domain_fail=.false."
)
body=re.sub(r'\bdt\b','stepdt',body)

needle="""    theta_tg=state%water_content+0.5_real64*stepdt*(theta_dot_n+theta_dot_p)
    do i=1,numnod
"""
repl="""    theta_tg=state%water_content+0.5_real64*stepdt*(theta_dot_n+theta_dot_p)
    if(any(theta_tg<=tr) .or. any(theta_tg>=ts))then
      domain_fail=.true.
      return
    end if
    do i=1,numnod
"""
if needle not in body:
    raise SystemExit("NLGLOB13 accepted theta marker missing")
body=body.replace(needle,repl,1)
body=body.replace("  end subroutine","  end subroutine advance_tg_core",1)

wrapper="""  subroutine advance_tg_subdiv(step_index)
    integer,intent(in)::step_index
    type(soil_water_physical_state_t)::saved_state
    logical::domain_fail,half_fail
    real(real64)::saved_cumledger,saved_cumrunoff,saved_maxledger,nominal_dt
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

    dt=0.5_real64*nominal_dt
    call advance_tg_core(step_index,dt,half_fail)
    if(half_fail .or. .not.eligible)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      dt=nominal_dt
      eligible=.false.
      terminal_reason='NEARSAT_SUBDIVISION_FAILED'
      transition_step=step_index
      return
    end if

    call advance_tg_core(step_index,dt,half_fail)
    if(half_fail .or. .not.eligible)then
      state=saved_state
      cumledger=saved_cumledger
      cumrunoff=saved_cumrunoff
      maxledger=saved_maxledger
      dt=nominal_dt
      eligible=.false.
      terminal_reason='NEARSAT_SUBDIVISION_FAILED'
      transition_step=step_index
      return
    end if

    dt=nominal_dt
    write(*,'(*(g0))') 'F_PE_NLGLOB13_SUBDIV|STEP=',step_index,'|HALF_DT=',0.5_real64*nominal_dt, &
         '|ROUTE=',trim(route_id)
  end subroutine advance_tg_subdiv

"""
src=src[:start]+wrapper+body+src[end:]

if "F_PE_NLGLOB13_SUBDIV" not in src or "subroutine advance_tg_core" not in src:
    raise SystemExit("NLGLOB13 materialization failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13_MATERIALIZER=PASS")
