#!/usr/bin/env python3
from pathlib import Path
import argparse, re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  integer :: nl14r_handoff_step\n"
if decl not in src:
    raise SystemExit("NLGLOB14R3 handoff declaration marker missing")
src=src.replace(decl,decl+"""  logical :: nl14r3_retry_advised,nl14r3_second_origin_saved
  real(real64) :: nl14r3_nominal_dt
  type(soil_water_physical_state_t) :: nl14r3_saved_state
  type(reference_richards_legacy_workspace_t) :: nl14r3_saved_ws
  real(real64) :: nl14r3_saved_cumledger,nl14r3_saved_cumrunoff,nl14r3_saved_maxledger
  logical :: nl14r3_saved_eligible,nl14r3_saved_sat_mode
  integer :: nl14r3_saved_transition,nl14r3_saved_target
  integer :: nl14r3_saved_origin,nl14r3_saved_pred,nl14r3_saved_endpoint,nl14r3_saved_accept,nl14r3_saved_status
  character(len=64) :: nl14r3_saved_terminal
""",1)

init="  nl14r_handoff_step=0\n"
if init not in src:
    raise SystemExit("NLGLOB14R3 init marker missing")
src=src.replace(init,init+"""  nl14r3_retry_advised=.false.
  nl14r3_second_origin_saved=.false.
  nl14r3_nominal_dt=dt
""",1)

# Capture retry-advised outcome from any second-window attempt.
tg_start=src.find("  subroutine advance_tg_core")
tg_end=src.find("  end subroutine advance_tg_core",tg_start)
if tg_start<0 or tg_end<0:
    raise SystemExit("NLGLOB14R3 TG core bounds missing")
seg=src[tg_start:tg_end]
pat=re.compile(r"(\n\s*if\s*\(\s*res%status\s*/=\s*SW_SOLVE_CONVERGED\s*\)\s*then\s*\n)")
m=pat.search(seg)
if not m:
    raise SystemExit("NLGLOB14R3 endpoint failure branch missing")
inject="""\n    if(res%status/=SW_SOLVE_CONVERGED)then
      if(nl14r_handoff_active .and. step_index==nl14r_handoff_step+1)then
        nl14r3_retry_advised=res%retry_advised
      end if
"""
seg=seg[:m.start()]+inject+seg[m.end():]
src=src[:tg_start]+seg+src[tg_end:]

# Save exact accepted origin before the nominal second interval.
dispatch="""    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
save="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step+1)then
      nl14r3_nominal_dt=dt
      nl14r3_saved_state=state
      nl14r3_saved_ws=ws
      nl14r3_saved_cumledger=cumledger
      nl14r3_saved_cumrunoff=cumrunoff
      nl14r3_saved_maxledger=maxledger
      nl14r3_saved_eligible=eligible
      nl14r3_saved_sat_mode=nl14d_saturated_mode
      nl14r3_saved_transition=transition_step
      nl14r3_saved_terminal=terminal_reason
      nl14r3_saved_target=target_route
      nl14r3_saved_origin=last_origin_route
      nl14r3_saved_pred=last_pred_route
      nl14r3_saved_endpoint=last_endpoint_route
      nl14r3_saved_accept=last_accept_route
      nl14r3_saved_status=last_solver_status
      nl14r3_retry_advised=.false.
      nl14r3_second_origin_saved=.true.
    end if
    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
if dispatch not in src:
    raise SystemExit("NLGLOB14R3 main dispatch marker missing")
src=src.replace(dispatch,save,1)

# Add retry loop locals to the main-program declarations.
local_marker="  integer :: steps,step,target_route,total_nl,total_back,total_jac,total_lin\n"
if local_marker not in src:
    raise SystemExit("NLGLOB14R3 main integer declaration marker missing")
src=src.replace(local_marker,local_marker+"  integer :: nl14r3_depth\n  real(real64) :: nl14r3_attempt_dt,nl14r3_ledger_delta\n",1)

# After the nominal retry-advised failure, retry from the same checkpoint at depths 1..8.
follow="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step)then
"""
retry_block="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step+1 .and. &
         (.not.eligible) .and. nl14r3_retry_advised .and. nl14r3_second_origin_saved)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14R3_NOMINAL|STEP=',step,'|RETRY=1|DT=',nl14r3_nominal_dt, &
           '|TERMINAL=',trim(terminal_reason)

      do nl14r3_depth=1,8
        state=nl14r3_saved_state
        ws=nl14r3_saved_ws
        cumledger=nl14r3_saved_cumledger
        cumrunoff=nl14r3_saved_cumrunoff
        maxledger=nl14r3_saved_maxledger
        eligible=nl14r3_saved_eligible
        nl14d_saturated_mode=nl14r3_saved_sat_mode
        transition_step=nl14r3_saved_transition
        terminal_reason=nl14r3_saved_terminal
        target_route=nl14r3_saved_target
        last_origin_route=nl14r3_saved_origin
        last_pred_route=nl14r3_saved_pred
        last_endpoint_route=nl14r3_saved_endpoint
        last_accept_route=nl14r3_saved_accept
        last_solver_status=nl14r3_saved_status
        nl14r3_attempt_dt=nl14r3_nominal_dt*(0.5_real64**nl14r3_depth)
        dt=nl14r3_attempt_dt
        nl14r3_retry_advised=.false.

        write(*,'(*(g0))') 'F_PE_NLGLOB14R3_ROLLBACK|STEP=',step,'|DEPTH=',nl14r3_depth, &
             '|H=',maxval(abs(state%pressure_head-nl14r3_saved_state%pressure_head)), &
             '|THETA=',maxval(abs(state%water_content-nl14r3_saved_state%water_content)), &
             '|POND=',abs(state%ponding_depth-nl14r3_saved_state%ponding_depth), &
             '|LEDGER=',abs(cumledger-nl14r3_saved_cumledger), &
             '|RUNOFF=',abs(cumrunoff-nl14r3_saved_cumrunoff),'|DT=',dt

        call advance_tg_subdiv(step)
        nl14r3_ledger_delta=cumledger-nl14r3_saved_cumledger
        write(*,'(*(g0))') 'F_PE_NLGLOB14R3_ATTEMPT|STEP=',step,'|DEPTH=',nl14r3_depth, &
             '|DT=',dt,'|ELIGIBLE=',merge(1,0,eligible),'|RETRY=',merge(1,0,nl14r3_retry_advised), &
             '|SAT_MODE=',merge(1,0,nl14d_saturated_mode), &
             '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
             '|TERMINAL=',trim(terminal_reason),'|LEDGER_DELTA=',nl14r3_ledger_delta

        if(eligible) exit
        if(.not.nl14r3_retry_advised) exit
      end do
      dt=nl14r3_nominal_dt
    end if

    if(nl14r_handoff_active .and. step==nl14r_handoff_step)then
"""
if follow not in src:
    raise SystemExit("NLGLOB14R3 follow marker missing")
src=src.replace(follow,retry_block,1)

if "F_PE_NLGLOB14R3_ATTEMPT" not in src or "F_PE_NLGLOB14R3_ROLLBACK" not in src:
    raise SystemExit("NLGLOB14R3 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R3_MATERIALIZER=PASS")
