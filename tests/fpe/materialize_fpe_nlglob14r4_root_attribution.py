#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="""    integer::saved_transition,event_node,i,ibis
"""
repl="""    integer::saved_transition,event_node,i,ibis
    integer::nl14r4_origin_sat,nl14r4_new_cross,nl14r4_sat_overshoot
    real(real64)::nl14r4_phi
"""
if decl not in src:
    raise SystemExit("NLGLOB14R4 root declaration marker missing")
src=src.replace(decl,repl,1)

marker="""    if(event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)then
"""
diag="""    if(nl14r_handoff_active .and. step_index==nl14r_handoff_step+1)then
      nl14r4_origin_sat=0
      nl14r4_new_cross=0
      nl14r4_sat_overshoot=0
      do i=1,numnod
        if(saved_state%water_content(i)==ts) nl14r4_origin_sat=nl14r4_origin_sat+1
        nl14r4_phi=huge(1.0_real64)
        if(theta_tg(i)>ts)then
          if(saved_state%water_content(i)<ts)then
            nl14r4_new_cross=nl14r4_new_cross+1
            if(theta_tg(i)>saved_state%water_content(i)) &
                 nl14r4_phi=(ts-saved_state%water_content(i))/(theta_tg(i)-saved_state%water_content(i))
          else
            nl14r4_sat_overshoot=nl14r4_sat_overshoot+1
            if(theta_tg(i)>saved_state%water_content(i)) &
                 nl14r4_phi=(ts-saved_state%water_content(i))/(theta_tg(i)-saved_state%water_content(i))
          end if
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB14R4_NODE|STEP=',step_index,'|ATTEMPT_DT=',nominal_dt, &
             '|NODE=',i,'|ORIGIN_SAT=',merge(1,0,saved_state%water_content(i)==ts), &
             '|ORIGIN_THETA=',saved_state%water_content(i),'|THETA_S=',ts, &
             '|CAND_THETA=',theta_tg(i),'|DELTA_S=',theta_tg(i)-ts,'|PHI=',nl14r4_phi
      end do
      write(*,'(*(g0))') 'F_PE_NLGLOB14R4_ROOT|STEP=',step_index,'|ATTEMPT_DT=',nominal_dt, &
           '|ORIGIN_SAT_COUNT=',nl14r4_origin_sat,'|NEW_CROSSINGS=',nl14r4_new_cross, &
           '|SAT_OVERSHOOTS=',nl14r4_sat_overshoot,'|EVENT_NODE=',event_node,'|PHI_HI=',phi_hi, &
           '|BRACKET_INVALID=',merge(1,0,event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. &
           phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)
    end if

    if(event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)then
"""
if marker not in src:
    raise SystemExit("NLGLOB14R4 invalid-bracket marker missing")
src=src.replace(marker,diag,1)

if "F_PE_NLGLOB14R4_ROOT" not in src or "F_PE_NLGLOB14R4_NODE" not in src:
    raise SystemExit("NLGLOB14R4 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R4_MATERIALIZER=PASS")
