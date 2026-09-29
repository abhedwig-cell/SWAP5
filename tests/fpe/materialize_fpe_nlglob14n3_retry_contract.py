#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  logical :: nl14d_saturated_mode\n"
if decl not in src:
    raise SystemExit("NLGLOB14N3 global declaration marker missing")
src=src.replace(decl,decl+"  logical :: nl14n3_root_trial_active,nl14n3_retry_trial\n  integer :: nl14n3_retry_contractions\n",1)

init="  nl14d_saturated_mode=.false.\n"
if init not in src:
    raise SystemExit("NLGLOB14N3 init marker missing")
src=src.replace(init,init+"  nl14n3_root_trial_active=.false.\n  nl14n3_retry_trial=.false.\n  nl14n3_retry_contractions=0\n",1)

core_start=src.find("  subroutine advance_tg_core")
core_end=src.find("  end subroutine advance_tg_core",core_start)
if core_start<0 or core_end<0:
    raise SystemExit("NLGLOB14N3 advance_tg_core bounds missing")
seg=src[core_start:core_end]
old_core="""    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
new_core="""    if(res%status/=SW_SOLVE_CONVERGED)then
      if(nl14n3_root_trial_active .and. res%retry_advised) nl14n3_retry_trial=.true.
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
"""
if old_core not in seg:
    raise SystemExit("NLGLOB14N3 endpoint failure marker missing in TG core")
seg=seg.replace(old_core,new_core,1)
src=src[:core_start]+seg+src[core_end:]

old_trial="""      trial_dt=phi_mid*nominal_dt
      call advance_tg_core(step_index,trial_dt,trial_fail)

      if(trial_fail)then
        phi_hi=phi_mid
        cycle
      end if
"""
new_trial="""      trial_dt=phi_mid*nominal_dt
      nl14n3_root_trial_active=.true.
      nl14n3_retry_trial=.false.
      call advance_tg_core(step_index,trial_dt,trial_fail)
      nl14n3_root_trial_active=.false.

      if(nl14n3_retry_trial)then
        state=saved_state
        cumledger=saved_cumledger
        cumrunoff=saved_cumrunoff
        maxledger=saved_maxledger
        terminal_reason=saved_terminal
        transition_step=saved_transition
        eligible=.true.
        phi_hi=phi_mid
        nl14n3_retry_contractions=nl14n3_retry_contractions+1
        write(*,'(*(g0))') 'F_PE_NLGLOB14N3_RETRY_CONTRACT|STEP=',step_index,'|ITER=',ibis, &
             '|PHI_LO=',phi_lo,'|PHI_HI=',phi_hi,'|PHI_MID=',phi_mid,'|TRIAL_DT=',trial_dt, &
             '|COUNT=',nl14n3_retry_contractions, &
             '|RESTORE_H=',maxval(abs(state%pressure_head-saved_state%pressure_head)), &
             '|RESTORE_THETA=',maxval(abs(state%water_content-saved_state%water_content)), &
             '|RESTORE_POND=',abs(state%ponding_depth-saved_state%ponding_depth)
        cycle
      end if

      if(trial_fail)then
        phi_hi=phi_mid
        cycle
      end if
"""
if old_trial not in src:
    raise SystemExit("NLGLOB14N3 bisection trial marker missing")
src=src.replace(old_trial,new_trial,1)

if "F_PE_NLGLOB14N3_RETRY_CONTRACT" not in src:
    raise SystemExit("NLGLOB14N3 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14N3_MATERIALIZER=PASS")
