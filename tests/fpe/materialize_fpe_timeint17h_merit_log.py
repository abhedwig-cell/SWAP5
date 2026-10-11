#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   logical                          :: flboth, flok\n"
insert=marker+"""   real(8) :: timeint17h_mcp,timeint17h_mtot,timeint17h_mh,timeint17h_m,timeint17h_dh
"""
if marker not in src: raise SystemExit("TIMEINT17H declaration marker missing")
src=src.replace(marker,insert,1)

marker="""!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
insert="""!        TIMEINT17H observational globalization-merit audit.
!        This does not change the existing accept/reduce decision.
         if (provider_dynamic_top_active) then
            timeint17h_mcp = Fmax / max(CritDevBalCp,tiny(1.0d0))
            timeint17h_mtot = dabs(sum1) / max(CritDevBalTot,tiny(1.0d0))
            timeint17h_mh = 0.0d0
            do i=1,NN
               timeint17h_dh = dabs(state%h(i)-fsi_ws%old_head(i))
               if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
                  timeint17h_mh=max(timeint17h_mh,timeint17h_dh/max(CritDevh2Cp,tiny(1.0d0)))
               else
                  timeint17h_mh=max(timeint17h_mh, &
                       timeint17h_dh/max(dabs(fsi_ws%old_head(i))*CritDevh1Cp,tiny(1.0d0)))
               end if
            end do
            timeint17h_m=max(timeint17h_mcp,max(timeint17h_mtot,timeint17h_mh))
            write(*,'(*(g0))') 'F_PE_TIMEINT17H_BT|ITER=',state%numbit,'|TRY=',itry,'|FACTOR=',factor, &
                 '|RAW=',sump,'|RAW_ORIGIN=',sumold,'|M_CP=',timeint17h_mcp,'|M_TOT=',timeint17h_mtot, &
                 '|M_H=',timeint17h_mh,'|M=',timeint17h_m,'|CURRENT_ACCEPT=', &
                 merge(1,0,(sump < sumold .OR. Fmax < CritDevBalCp)), &
                 '|ROUTE=',trim(provider_dynamic_top_result%route)
         end if

!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
if marker not in src: raise SystemExit("TIMEINT17H progress marker missing")
src=src.replace(marker,insert,1)

if "F_PE_TIMEINT17H_BT" not in src: raise SystemExit("TIMEINT17H injection failed")
Path(args.output).write_text(src)
print("F_PE_TIMEINT17H_MATERIALIZER=PASS")
