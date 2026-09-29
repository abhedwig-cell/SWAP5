#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="""    integer::saved_transition

    saved_state=state
"""
insert="""    integer::saved_transition,nl13c1_i

    saved_state=state
"""
if marker not in src:
    raise SystemExit("NLGLOB13C1 declaration marker missing")
src=src.replace(marker,insert,1)

needle1="""      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
"""
repl1="""      dt=0.25_real64*nominal_dt
      do nl13c1_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB13C1_STATE|STEP=',step_index,'|HALF=1|NODE=',nl13c1_i, &
             '|PTHETA=',half_state%water_content(nl13c1_i),'|CTHETA=',state%water_content(nl13c1_i), &
             '|PH=',half_state%pressure_head(nl13c1_i),'|CH=',state%pressure_head(nl13c1_i), &
             '|PPOND=',half_state%ponding_depth,'|CPOND=',state%ponding_depth,'|DZ=',p%dz(nl13c1_i), &
             '|ROUTE=',trim(route_id)
      end do
      call advance_tg_core(step_index,dt,qfail)
"""
if needle1 not in src:
    raise SystemExit("NLGLOB13C1 half1 quarter marker missing")
src=src.replace(needle1,repl1,1)

needle2="""      dt=0.25_real64*nominal_dt
      call advance_tg_core(step_index,dt,qfail)
"""
repl2="""      dt=0.25_real64*nominal_dt
      do nl13c1_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB13C1_STATE|STEP=',step_index,'|HALF=2|NODE=',nl13c1_i, &
             '|PTHETA=',half_state%water_content(nl13c1_i),'|CTHETA=',state%water_content(nl13c1_i), &
             '|PH=',half_state%pressure_head(nl13c1_i),'|CH=',state%pressure_head(nl13c1_i), &
             '|PPOND=',half_state%ponding_depth,'|CPOND=',state%ponding_depth,'|DZ=',p%dz(nl13c1_i), &
             '|ROUTE=',trim(route_id)
      end do
      call advance_tg_core(step_index,dt,qfail)
"""
if needle2 not in src:
    raise SystemExit("NLGLOB13C1 half2 quarter marker missing")
src=src.replace(needle2,repl2,1)

if src.count("F_PE_NLGLOB13C1_STATE") != 2:
    raise SystemExit("NLGLOB13C1 expected two state log sites")
Path(args.output).write_text(src)
print("F_PE_NLGLOB13C1_MATERIALIZER=PASS")
