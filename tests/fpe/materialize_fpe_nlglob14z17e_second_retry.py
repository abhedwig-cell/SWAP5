#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  integer :: nl14f_event_node\n"
if decl not in src:
    raise SystemExit("NLGLOB14Z17E global declaration marker missing")
src=src.replace(decl,decl+"""  logical :: nl14z17e_retry_advised
  integer :: nl14z17e_recovery_count
  type(soil_water_physical_state_t) :: nl14z17e_saved_state
  type(reference_richards_legacy_workspace_t) :: nl14z17e_saved_ws
  real(real64) :: nl14z17e_saved_cumledger,nl14z17e_saved_cumrunoff,nl14z17e_saved_maxledger
  logical :: nl14z17e_saved_eligible
  integer :: nl14z17e_saved_transition
  character(len=64) :: nl14z17e_saved_terminal
""",1)

init="  nl14f_event_node=0\n"
if init not in src:
    raise SystemExit("NLGLOB14Z17E init marker missing")
src=src.replace(init,init+"""  nl14z17e_retry_advised=.false.
  nl14z17e_recovery_count=0
""",1)

ks=src.find("  subroutine advance_klag")
ke=src.find("  end subroutine",ks)
if ks<0 or ke<0:
    raise SystemExit("NLGLOB14Z17E KLAG bounds missing")
seg=src[ks:ke]
fail="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
if fail not in seg:
    raise SystemExit("NLGLOB14Z17E KLAG failure marker missing")
seg=seg.replace(fail,"""    if(res%status/=SW_SOLVE_CONVERGED)then
      if(nl14d_saturated_mode) nl14z17e_retry_advised=res%retry_advised
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
""",1)
src=src[:ks]+seg+src[ke:]

persist="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      write(*,'(*(g0))') 'F_PE_NLGLOB14G_FORCING|STEP=',step_index,'|PHASE=DRY', &
           '|PRECIP=',0.0_real64,'|EBARE=',rain,'|EPOND=',rain,'|ROUTE_TARGET=',trim(route_id)
      call advance_klag(step_index)
      write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=0', &
           '|OK=',merge(1,0,eligible),'|DT=',nominal_dt,'|ROUTE=',trim(route_id), &
           '|TERMINAL=',trim(terminal_reason)
      return
    end if
"""
if persist not in src:
    raise SystemExit("NLGLOB14Z17E persistent wrapper marker missing")

repl="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      write(*,'(*(g0))') 'F_PE_NLGLOB14G_FORCING|STEP=',step_index,'|PHASE=DRY', &
           '|PRECIP=',0.0_real64,'|EBARE=',rain,'|EPOND=',rain,'|ROUTE_TARGET=',trim(route_id)

      nl14z17e_saved_state=state
      nl14z17e_saved_ws=ws
      nl14z17e_saved_cumledger=cumledger
      nl14z17e_saved_cumrunoff=cumrunoff
      nl14z17e_saved_maxledger=maxledger
      nl14z17e_saved_eligible=eligible
      nl14z17e_saved_transition=transition_step
      nl14z17e_saved_terminal=terminal_reason
      nl14z17e_retry_advised=.false.

      call advance_klag(step_index)

      if((.not.eligible) .and. nl14z17e_retry_advised .and. nl14z17e_recovery_count<2)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_NOMINAL_RETRY|STEP=',step_index, &
             '|INDEX=',nl14z17e_recovery_count+1,'|RETRY=1|DT=',nominal_dt, &
             '|SOLVER_STATUS=',last_solver_status, &
             '|SAT_COUNT=',count(nl14z17e_saved_state%pressure_head>=0.0_real64 .and. &
                                  nl14z17e_saved_state%water_content==ts), &
             '|TERMINAL=',trim(terminal_reason)

        state=nl14z17e_saved_state
        ws=nl14z17e_saved_ws
        cumledger=nl14z17e_saved_cumledger
        cumrunoff=nl14z17e_saved_cumrunoff
        maxledger=nl14z17e_saved_maxledger
        eligible=nl14z17e_saved_eligible
        transition_step=nl14z17e_saved_transition
        terminal_reason=nl14z17e_saved_terminal
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_ROLLBACK|STEP=',step_index, &
             '|INDEX=',nl14z17e_recovery_count+1, &
             '|H=',maxval(abs(state%pressure_head-nl14z17e_saved_state%pressure_head)), &
             '|THETA=',maxval(abs(state%water_content-nl14z17e_saved_state%water_content)), &
             '|POND=',abs(state%ponding_depth-nl14z17e_saved_state%ponding_depth), &
             '|LEDGER=',abs(cumledger-nl14z17e_saved_cumledger), &
             '|RUNOFF=',abs(cumrunoff-nl14z17e_saved_cumrunoff)

        dt=0.5_real64*nominal_dt
        nl14z17e_retry_advised=.false.
        call advance_klag(step_index)
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_HALF|STEP=',step_index, &
             '|INDEX=',nl14z17e_recovery_count+1,'|HALF=1', &
             '|ELIGIBLE=',merge(1,0,eligible),'|RETRY=',merge(1,0,nl14z17e_retry_advised), &
             '|SOLVER_STATUS=',last_solver_status, &
             '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
             '|TERMINAL=',trim(terminal_reason),'|CUM_LEDGER=',cumledger,'|DT=',dt

        if(eligible)then
          nl14z17e_retry_advised=.false.
          call advance_klag(step_index)
          write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_HALF|STEP=',step_index, &
               '|INDEX=',nl14z17e_recovery_count+1,'|HALF=2', &
               '|ELIGIBLE=',merge(1,0,eligible),'|RETRY=',merge(1,0,nl14z17e_retry_advised), &
               '|SOLVER_STATUS=',last_solver_status, &
               '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
               '|TERMINAL=',trim(terminal_reason),'|CUM_LEDGER=',cumledger,'|DT=',dt
        end if

        if(eligible)then
          nl14z17e_recovery_count=nl14z17e_recovery_count+1
          write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_RECOVERED|STEP=',step_index, &
               '|COUNT=',nl14z17e_recovery_count,'|DT=',nominal_dt, &
               '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts)
        else
          state=nl14z17e_saved_state
          ws=nl14z17e_saved_ws
          cumledger=nl14z17e_saved_cumledger
          cumrunoff=nl14z17e_saved_cumrunoff
          maxledger=nl14z17e_saved_maxledger
          eligible=.false.
          transition_step=step_index
          terminal_reason='NLGLOB14Z17E_HALF_RECOVERY_FAILED'
          write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_RECOVERY_FAILED|STEP=',step_index, &
               '|INDEX=',nl14z17e_recovery_count+1,'|RETRY=',merge(1,0,nl14z17e_retry_advised)
        end if
        dt=nominal_dt
      end if

      if((.not.eligible) .and. nl14z17e_retry_advised .and. nl14z17e_recovery_count>=2)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z17E_THIRD_RETRY|STEP=',step_index, &
             '|RETRY=1|DT=',nominal_dt,'|SOLVER_STATUS=',last_solver_status, &
             '|SAT_COUNT=',count(nl14z17e_saved_state%pressure_head>=0.0_real64 .and. &
                                  nl14z17e_saved_state%water_content==ts), &
             '|TERMINAL=',trim(terminal_reason)
      end if

      write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=0', &
           '|OK=',merge(1,0,eligible),'|DT=',nominal_dt,'|ROUTE=',trim(route_id), &
           '|TERMINAL=',trim(terminal_reason)
      return
    end if
"""
src=src.replace(persist,repl,1)

for marker in ("F_PE_NLGLOB14Z17E_NOMINAL_RETRY","F_PE_NLGLOB14Z17E_ROLLBACK",
               "F_PE_NLGLOB14Z17E_HALF","F_PE_NLGLOB14Z17E_RECOVERED",
               "F_PE_NLGLOB14Z17E_THIRD_RETRY"):
    if marker not in src:
        raise SystemExit("NLGLOB14Z17E injection failed: "+marker)

Path(args.output).write_text(src)
print("F_PE_NLGLOB14Z17E_MATERIALIZER=PASS")
