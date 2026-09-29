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
    raise SystemExit("NLGLOB14Z4 event-log declaration marker missing")
src=src.replace(decl,decl+"  integer :: nl14z4_prev_sat_top,nl14z4_sat_top\n",1)

init="  nl14f_event_node=0\n"
if init not in src:
    raise SystemExit("NLGLOB14Z4 event-log init marker missing")
src=src.replace(init,init+"  nl14z4_prev_sat_top=-999\n",1)

old="""    if(nl14d_saturated_mode)then
      do nl14f_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB14F_STATE|STEP=',step_index,'|NODE=',nl14f_i, &
             '|EVENT_NODE=',nl14f_event_node,'|H=',state%pressure_head(nl14f_i),'|THETA=',state%water_content(nl14f_i), &
             '|THETA_S=',ts,'|DEFICIT=',ts-state%water_content(nl14f_i),'|SAT_H=',merge(1,0,state%pressure_head(nl14f_i)>=0.0_real64), &
             '|SAT_THETA=',merge(1,0,state%water_content(nl14f_i)==ts),'|ROUTE=',trim(route_id), &
             '|TOP_FLUX=',res%top_flux,'|BOTTOM_FLUX=',res%bottom_flux,'|POND=',state%ponding_depth
      end do
    end if
"""
new="""    if(nl14d_saturated_mode)then
      nl14z4_sat_top=0
      do nl14f_i=1,numnod
        if(state%pressure_head(nl14f_i)>=0.0_real64 .and. state%water_content(nl14f_i)==ts)then
          nl14z4_sat_top=nl14f_i
          exit
        end if
      end do
      if(nl14z4_sat_top/=nl14z4_prev_sat_top)then
        do nl14f_i=1,numnod
          write(*,'(*(g0))') 'F_PE_NLGLOB14F_STATE|STEP=',step_index,'|NODE=',nl14f_i, &
               '|EVENT_NODE=',nl14f_event_node,'|H=',state%pressure_head(nl14f_i),'|THETA=',state%water_content(nl14f_i), &
               '|THETA_S=',ts,'|DEFICIT=',ts-state%water_content(nl14f_i),'|SAT_H=',merge(1,0,state%pressure_head(nl14f_i)>=0.0_real64), &
               '|SAT_THETA=',merge(1,0,state%water_content(nl14f_i)==ts),'|ROUTE=',trim(route_id), &
               '|TOP_FLUX=',res%top_flux,'|BOTTOM_FLUX=',res%bottom_flux,'|POND=',state%ponding_depth
        end do
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z4_EVENT|STEP=',step_index,'|SAT_TOP=',nl14z4_sat_top
        nl14z4_prev_sat_top=nl14z4_sat_top
      end if
    end if
"""
if old not in src:
    raise SystemExit("NLGLOB14Z4 event-log state block missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_NLGLOB14Z4_EVENT_LOG_MATERIALIZER=PASS")
