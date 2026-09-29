#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

use_marker="  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &\n       bind_fpe_timeint13_predicted_k_provider\n"
use_add=use_marker+"""  use mod_fpe_timeint17c_logging_top_provider, only: fpe_timeint17c_logging_top_provider_t, &
       bind_fpe_timeint17c_logging_top_provider, reset_fpe_timeint17c_log, summarize_fpe_timeint17c_log
"""
if use_marker not in src: raise SystemExit("TIMEINT17C use marker missing")
src=src.replace(use_marker,use_add,1)

decl="  type(b110_dynamic_top_boundary_solver_provider_t),target :: top\n"
decl2=decl+"  type(fpe_timeint17c_logging_top_provider_t),target :: logged_top\n"
if decl not in src: raise SystemExit("TIMEINT17C top declaration missing")
src=src.replace(decl,decl2,1)

old="    req%evaluation%dynamic_top_boundary=>provider\n"
new="""    call bind_fpe_timeint17c_logging_top_provider(logged_top,provider)
    req%evaluation%dynamic_top_boundary=>logged_top
"""
if old not in src: raise SystemExit("TIMEINT17C provider binding missing")
src=src.replace(old,new)

# Reset only around endpoint solver calls, not origin/predictor diagnostics.
src=src.replace(
"    storage0=sum(state%water_content*p%dz)+state%ponding_depth\n    call solver%solve(req,ws,res)\n",
"    storage0=sum(state%water_content*p%dz)+state%ponding_depth\n    call reset_fpe_timeint17c_log()\n    call solver%solve(req,ws,res)\n")

fail="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
repl_tg="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      call emit_timeint17c_trial('TG',step_index,trim(terminal_reason))
      eligible=.false.; transition_step=step_index; return
    end if
"""
if fail not in src: raise SystemExit("TIMEINT17C TG failure marker missing")
src=src.replace(fail,repl_tg,1)

# second occurrence belongs KLAG
if fail not in src: raise SystemExit("TIMEINT17C KLAG failure marker missing")
repl_klag="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      call emit_timeint17c_trial('KLAG',step_index,trim(terminal_reason))
      eligible=.false.; transition_step=step_index; return
    end if
"""
src=src.replace(fail,repl_klag,1)

contains_marker="  subroutine read_real(i,x)\n"
helper="""  subroutine emit_timeint17c_trial(mode_name,step_index,reason)
    character(len=*),intent(in)::mode_name,reason
    integer,intent(in)::step_index
    integer::eval_count,distinct_routes,route_transitions,first_route,last_route
    integer::flux_count,head_count,runoff_count,atmos_count,other_count,unavailable
    real(real64)::min_head,max_head,min_pond,max_pond,min_flux,max_flux
    call summarize_fpe_timeint17c_log(eval_count,distinct_routes,route_transitions,first_route,last_route, &
         flux_count,head_count,runoff_count,atmos_count,other_count,unavailable, &
         min_head,max_head,min_pond,max_pond,min_flux,max_flux)
    write(*,'(*(g0))') 'F_PE_TIMEINT17C_TRIAL|MATERIAL=',trim(material_id),'|MODE=',trim(mode_name), &
         '|ROUTE=',trim(route_id),'|DT=',dt,'|STEP=',step_index,'|TERMINAL_REASON=',trim(reason), &
         '|EVALS=',eval_count,'|DISTINCT_ROUTES=',distinct_routes,'|ROUTE_TRANSITIONS=',route_transitions, &
         '|FIRST_ROUTE=',first_route,'|LAST_ROUTE=',last_route,'|UNAVAILABLE=',unavailable, &
         '|FLUX_COUNT=',flux_count,'|HEAD_COUNT=',head_count,'|RUNOFF_COUNT=',runoff_count, &
         '|ATMOS_COUNT=',atmos_count,'|OTHER_COUNT=',other_count, &
         '|MIN_HEAD=',min_head,'|MAX_HEAD=',max_head,'|MIN_POND=',min_pond,'|MAX_POND=',max_pond, &
         '|MIN_FLUX=',min_flux,'|MAX_FLUX=',max_flux
  end subroutine

  subroutine read_real(i,x)
"""
if contains_marker not in src: raise SystemExit("TIMEINT17C contains marker missing")
src=src.replace(contains_marker,helper,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT17C_MATERIALIZER=PASS")
