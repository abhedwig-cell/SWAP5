#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="    integer::saved_transition,event_node,i,ibis\n"
if decl not in src:
    raise SystemExit("NLGLOB14R4 root declaration marker missing")
src=src.replace(decl,decl+"    integer::nl14r4_over,nl14r4_existing,nl14r4_new,nl14r4_valid\n",1)

old="""    if(event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)then
      state=saved_state
"""
new="""    if(event_node==0 .or. .not.ieee_is_finite(phi_hi) .or. phi_hi<=0.0_real64 .or. phi_hi>=1.0_real64)then
      nl14r4_over=0
      nl14r4_existing=0
      nl14r4_new=0
      nl14r4_valid=0
      do i=1,numnod
        phi_i=huge(1.0_real64)
        if(theta_tg(i)>ts)then
          nl14r4_over=nl14r4_over+1
          if(saved_state%water_content(i)>=ts)then
            nl14r4_existing=nl14r4_existing+1
          else
            nl14r4_new=nl14r4_new+1
          end if
          if(theta_tg(i)>saved_state%water_content(i))then
            phi_i=(ts-saved_state%water_content(i))/(theta_tg(i)-saved_state%water_content(i))
            if(phi_i>0.0_real64 .and. phi_i<1.0_real64 .and. ieee_is_finite(phi_i)) nl14r4_valid=nl14r4_valid+1
          end if
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB14R4_NODE|STEP=',step_index,'|DT=',nominal_dt,'|NODE=',i, &
             '|ORIGIN_THETA=',saved_state%water_content(i),'|THETA_S=',ts,'|THETA_TG=',theta_tg(i), &
             '|ORIGIN_SAT=',merge(1,0,saved_state%water_content(i)>=ts), &
             '|OVERSHOOT=',merge(1,0,theta_tg(i)>ts),'|PHI=',phi_i
      end do
      write(*,'(*(g0))') 'F_PE_NLGLOB14R4_INVALID|STEP=',step_index,'|DT=',nominal_dt, &
           '|OVER=',nl14r4_over,'|EXISTING=',nl14r4_existing,'|NEW=',nl14r4_new, &
           '|VALID_PHI=',nl14r4_valid,'|EVENT_NODE=',event_node,'|PHI_HI=',phi_hi, &
           '|SAT_COUNT=',count(saved_state%water_content>=ts)
      state=saved_state
"""
if old not in src:
    raise SystemExit("NLGLOB14R4 invalid bracket marker missing")
src=src.replace(old,new,1)

if "F_PE_NLGLOB14R4_INVALID" not in src:
    raise SystemExit("NLGLOB14R4 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R4_MATERIALIZER=PASS")
