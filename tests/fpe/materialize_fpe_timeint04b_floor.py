#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

decl="""   integer :: timeint02_mode
   real(8) :: timeint02_thetam2(1000)
   common /timeint02_history_common/ timeint02_mode, timeint02_thetam2
"""
decl_new=decl+"""   integer :: timeint04b_floor_mode
   common /timeint04b_floor_common/ timeint04b_floor_mode
   real(8) :: timeint04b_total_floor
"""
if decl not in src:
    raise SystemExit("TIMEINT02 common block not found")
src=src.replace(decl,decl_new,1)

old="""      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.

!     save sump voor next iteration
"""
new="""      if (timeint02_mode == 2 .and. timeint04b_floor_mode == 1) then
         timeint04b_total_floor = 0.0d0
         do i = 1, NN
            timeint04b_total_floor = timeint04b_total_floor + 0.5d0*grid_dz(i)/dt * &
                 (1.5d0*spacing(state%theta(i)) + 2.0d0*spacing(state%thetm1(i)) + &
                  0.5d0*spacing(timeint02_thetam2(i)))
         end do
         if (dabs(sum1) > max(CritDevBalTot,timeint04b_total_floor)) flnonconv = .TRUE.
      else
         if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.
      end if

!     save sump voor next iteration
"""
if old not in src:
    raise SystemExit("total balance patch point missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT04B_FLOOR_MATERIALIZER=PASS")
