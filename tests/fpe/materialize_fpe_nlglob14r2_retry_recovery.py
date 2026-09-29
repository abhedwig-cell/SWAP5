#!/usr/bin/env python3
from pathlib import Path
import argparse, re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

# Global retry-observation state.
decl="  integer :: nl14r_handoff_step\n"
if decl not in src:
    raise SystemExit("NLGLOB14R2 handoff declaration marker missing")
src=src.replace(decl,decl+"""  logical :: nl14r2_retry_advised,nl14r2_second_origin_saved
  real(real64) :: nl14r2_nominal_dt
  type(soil_water_physical_state_t) :: nl14r2_saved_state
  type(reference_richards_legacy_workspace_t) :: nl14r2_saved_ws
  real(real64) :: nl14r2_saved_cumledger,nl14r2_saved_cumrunoff,nl14r2_saved_maxledger
  logical :: nl14r2_saved_eligible
  integer :: nl14r2_saved_transition
  character(len=64) :: nl14r2_saved_terminal
""",1)

init="  nl14r_handoff_step=0\n"
if init not in src:
    raise SystemExit("NLGLOB14R2 init marker missing")
src=src.replace(init,init+"""  nl14r2_retry_advised=.false.
  nl14r2_second_origin_saved=.false.
  nl14r2_nominal_dt=dt
""",1)

# Capture retry-advised status from the actual second-interval endpoint solve.
tg_start=src.find("  subroutine advance_tg_core")
tg_end=src.find("  end subroutine advance_tg_core",tg_start)
if tg_start<0 or tg_end<0:
    raise SystemExit("NLGLOB14R2 TG core bounds missing")
seg=src[tg_start:tg_end]
pat=re.compile(r"(\n\s*if\s*\(\s*res%status\s*/=\s*SW_SOLVE_CONVERGED\s*\)\s*then\s*\n)")
m=pat.search(seg)
if not m:
    raise SystemExit("NLGLOB14R2 endpoint failure branch missing")
inject="""\n    if(res%status/=SW_SOLVE_CONVERGED)then
      if(nl14r_handoff_active .and. step_index==nl14r_handoff_step+1)then
        nl14r2_retry_advised=res%retry_advised
      end if
"""
seg=seg[:m.start()]+inject+seg[m.end():]
src=src[:tg_start]+seg+src[tg_end:]

# Save the accepted origin immediately before the nominal second interval.
dispatch="""    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
save="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step+1)then
      nl14r2_nominal_dt=dt
      nl14r2_saved_state=state
      nl14r2_saved_ws=ws
      nl14r2_saved_cumledger=cumledger
      nl14r2_saved_cumrunoff=cumrunoff
      nl14r2_saved_maxledger=maxledger
      nl14r2_saved_eligible=eligible
      nl14r2_saved_transition=transition_step
      nl14r2_saved_terminal=terminal_reason
      nl14r2_retry_advised=.false.
      nl14r2_second_origin_saved=.true.
    end if
    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
if dispatch not in src:
    raise SystemExit("NLGLOB14R2 main dispatch marker missing")
src=src.replace(dispatch,save,1)

# Intercept the retry-advised nominal failure before the existing R follow logging.
follow="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step)then
"""
recovery="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step+1 .and. &
         (.not.eligible) .and. nl14r2_retry_advised .and. nl14r2_second_origin_saved)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14R2_NOMINAL_RETRY|STEP=',step, &
           '|RETRY=1|DT=',nl14r2_nominal_dt,'|TERMINAL=',trim(terminal_reason)
      state=nl14r2_saved_state
      ws=nl14r2_saved_ws
      cumledger=nl14r2_saved_cumledger
      cumrunoff=nl14r2_saved_cumrunoff
      maxledger=nl14r2_saved_maxledger
      eligible=nl14r2_saved_eligible
      transition_step=nl14r2_saved_transition
      terminal_reason=nl14r2_saved_terminal
      write(*,'(*(g0))') 'F_PE_NLGLOB14R2_ROLLBACK|STEP=',step, &
           '|H=',maxval(abs(state%pressure_head-nl14r2_saved_state%pressure_head)), &
           '|THETA=',maxval(abs(state%water_content-nl14r2_saved_state%water_content)), &
           '|POND=',abs(state%ponding_depth-nl14r2_saved_state%ponding_depth), &
           '|LEDGER=',abs(cumledger-nl14r2_saved_cumledger), &
           '|RUNOFF=',abs(cumrunoff-nl14r2_saved_cumrunoff), &
           '|RETRY_SCALE=',0.5_real64

      dt=0.5_real64*nl14r2_nominal_dt
      nl14r2_retry_advised=.false.
      call advance_tg_subdiv(step)
      write(*,'(*(g0))') 'F_PE_NLGLOB14R2_HALF|STEP=',step,'|HALF=1', &
           '|ELIGIBLE=',merge(1,0,eligible),'|RETRY=',merge(1,0,nl14r2_retry_advised), &
           '|SAT_MODE=',merge(1,0,nl14d_saturated_mode), &
           '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
           '|TERMINAL=',trim(terminal_reason),'|CUM_LEDGER=',cumledger,'|DT=',dt

      if(eligible)then
        nl14r2_retry_advised=.false.
        call advance_tg_subdiv(step)
        write(*,'(*(g0))') 'F_PE_NLGLOB14R2_HALF|STEP=',step,'|HALF=2', &
             '|ELIGIBLE=',merge(1,0,eligible),'|RETRY=',merge(1,0,nl14r2_retry_advised), &
             '|SAT_MODE=',merge(1,0,nl14d_saturated_mode), &
             '|SAT_COUNT=',count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
             '|TERMINAL=',trim(terminal_reason),'|CUM_LEDGER=',cumledger
      end if
      dt=nl14r2_nominal_dt
    end if

    if(nl14r_handoff_active .and. step==nl14r_handoff_step)then
"""
if follow not in src:
    raise SystemExit("NLGLOB14R2 follow marker missing")
src=src.replace(follow,recovery,1)

if "F_PE_NLGLOB14R2_ROLLBACK" not in src or "F_PE_NLGLOB14R2_HALF" not in src:
    raise SystemExit("NLGLOB14R2 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R2_MATERIALIZER=PASS")
