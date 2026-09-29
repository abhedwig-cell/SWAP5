#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="""   character(len=64) :: nl09_route0,nl09_route1
"""
insert=marker+"""   real(8) :: nl12c_ui,nl12c_utotal,nl12c_rlocal,nl12c_rtotal
   logical :: nl12c_rep
"""
if marker not in src:
    raise SystemExit("NLGLOB12C declaration marker missing")
src=src.replace(marker,insert,1)

needle="""      if (nl09_s0 .and. flnonconv) then
         flnonconv=.false.
         write(*,'(*(g0))') 'F_PE_NLGLOB09_ACCEPT|REASON=S0_STATE_STATIONARITY|ITER=',state%numbit, &
              '|ROUTE=',trim(provider_dynamic_top_result%route),'|RBAL=',nl09_rbal,'|RSTORAGE=',nl09_rstorage
      end if
"""
repl=needle+"""      if (flnonconv) then
         nl12c_utotal=0.0d0
         nl12c_rlocal=0.0d0
         do i=1,NN
            nl12c_ui=(dabs(spacing(state%theta(i)))+dabs(spacing(state%thetm1(i)))) * &
                 dabs(matrix_fraction(i))*dabs(grid_dz(i))/dt
            nl12c_utotal=nl12c_utotal+dabs(nl12c_ui)
            nl12c_rlocal=max(nl12c_rlocal,dabs(fsi_ws%residual(i))/max(dabs(nl12c_ui),tiny(1.0d0)))
         end do
         nl12c_rtotal=dabs(sum1)/max(nl12c_utotal,tiny(1.0d0))
         nl12c_rep=nl09_finite .and. nl09_rhead<=1.0d0 .and. &
              ((.not.nl09_pond_app) .or. nl09_rpond<=1.0d0) .and. &
              nl12c_rlocal<=1.0d0 .and. nl12c_rtotal<=1.0d0
         if (nl12c_rep) then
            flnonconv=.false.
            write(*,'(*(g0))') 'F_PE_NLGLOB12C_ACCEPT|REASON=REPRESENTATION_FLOOR|ITER=',state%numbit, &
                 '|ROUTE=',trim(provider_dynamic_top_result%route),'|RLOCAL=',nl12c_rlocal, &
                 '|RTOTAL=',nl12c_rtotal,'|RHEAD=',nl09_rhead,'|RPOND=',nl09_rpond
         end if
      end if
"""
if needle not in src:
    raise SystemExit("NLGLOB12C S0 marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB12C_ACCEPT" not in src:
    raise SystemExit("NLGLOB12C injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB12C_MATERIALIZER=PASS")
