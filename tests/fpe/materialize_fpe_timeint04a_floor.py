#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

marker="""      if (timeint04_step == 24 .or. timeint04_step == 25) then
         write(*,'(*(g0))') 'F_PE_TIMEINT04_CHECK|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
              '|ITER=',solver_numbit,'|SUMNEW=',sump,'|FINF=',Fmax,'|SUMRES=',sum1, &
              '|DHACT=',maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
              '|NONCONV=',merge(1,0,flnonconv)
      end if

!     save sump voor next iteration
"""
insert="""      if (timeint04_step == 24 .or. timeint04_step == 25) then
         write(*,'(*(g0))') 'F_PE_TIMEINT04_CHECK|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
              '|ITER=',solver_numbit,'|SUMNEW=',sump,'|FINF=',Fmax,'|SUMRES=',sum1, &
              '|DHACT=',maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
              '|NONCONV=',merge(1,0,flnonconv)
      end if
      if (timeint04_step == 25 .and. timeint02_mode == 2 .and. solver_numbit >= 4) then
         do i = 1, NN
            write(*,'(*(g0))') 'F_PE_TIMEINT04A_NODE|ITER=',solver_numbit,'|NODE=',i, &
                 '|RES=',fsi_ws%residual(i),'|THNP1=',state%theta(i),'|THN=',state%thetm1(i), &
                 '|THNM1=',timeint02_thetam2(i),'|DZ=',grid_dz(i),'|DT=',dt
         end do
         write(*,'(*(g0))') 'F_PE_TIMEINT04A_TOTAL|ITER=',solver_numbit,'|SUMRES=',sum1
      end if

!     save sump voor next iteration
"""
if marker not in src:
    raise SystemExit("TIMEINT04 CHECK patch point missing")
src=src.replace(marker,insert,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT04A_FLOOR_MATERIALIZER=PASS")
