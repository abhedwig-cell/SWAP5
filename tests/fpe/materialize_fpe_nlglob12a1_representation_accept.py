#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   real(8) :: nl12a1_utotal,nl12a1_ui,nl12a1_rtotal,nl12a1_rlocal,nl12a1_rhead,nl12a1_rpond
   logical :: nl12a1_finite,nl12a1_head_ok,nl12a1_pond_ok,nl12a1_accept,nl12a1_pond_app
"""
if marker not in src:
    raise SystemExit("NLGLOB12A1 declaration marker missing")
src=src.replace(marker,insert,1)

needle="""      if (nl09_s0 .and. flnonconv) then
"""
repl="""      nl12a1_utotal=0.0d0
      nl12a1_rlocal=0.0d0
      nl12a1_finite=.true.
      do i=1,NN
         nl12a1_ui=(dabs(spacing(state%theta(i)))+dabs(spacing(state%thetm1(i)))) * &
              dabs(matrix_fraction(i))*dabs(grid_dz(i))/dt
         nl12a1_utotal=nl12a1_utotal+dabs(nl12a1_ui)
         nl12a1_rlocal=max(nl12a1_rlocal,dabs(fsi_ws%residual(i))/max(dabs(nl12a1_ui),tiny(1.0d0)))
         nl12a1_finite=nl12a1_finite .and. ieee_is_finite(state%theta(i)) .and. ieee_is_finite(state%h(i)) .and. &
              ieee_is_finite(fsi_ws%residual(i))
      end do
      nl12a1_rtotal=dabs(sum1)/max(nl12a1_utotal,tiny(1.0d0))
      nl12a1_rhead=0.0d0
      do i=1,NN
         if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
            nl12a1_rhead=max(nl12a1_rhead,dabs(state%h(i)-fsi_ws%old_head(i))/critdevh2cp)
         else
            nl12a1_rhead=max(nl12a1_rhead,(dabs(state%h(i)-fsi_ws%old_head(i))/dabs(fsi_ws%old_head(i)))/critdevh1cp)
         end if
      end do
      nl12a1_head_ok=nl12a1_rhead<=1.0d0
      nl12a1_pond_app=provider_dynamic_top_active .and. index(trim(provider_dynamic_top_result%route),'surface-flux') == 0
      nl12a1_rpond=0.0d0
      if (nl12a1_pond_app) then
         nl12a1_rpond=dabs(state%pond-state%pondm1-provider_dynamic_top_result%net_potential_surface_flux*dt + &
              state%runots-state%qtop*dt)/critdevponddt
      end if
      nl12a1_pond_ok=(.not.nl12a1_pond_app) .or. nl12a1_rpond<=1.0d0
      nl12a1_accept=flnonconv .and. nl12a1_rtotal<=1.0d0 .and. nl12a1_rlocal<=1.0d0 .and. &
           nl12a1_head_ok .and. nl12a1_pond_ok .and. nl12a1_finite
      if (nl12a1_accept) then
         flnonconv=.false.
         write(*,'(*(g0))') 'F_PE_NLGLOB12A1_ACCEPT|REASON=REPRESENTATION_FLOOR|ITER=',state%numbit, &
              '|R_TOTAL_ULP=',nl12a1_rtotal,'|R_LOCAL_ULP=',nl12a1_rlocal, &
              '|R_HEAD=',nl12a1_rhead,'|R_POND=',nl12a1_rpond,'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if

      if (nl09_s0 .and. flnonconv) then
"""
if needle not in src:
    raise SystemExit("NLGLOB12A1 S0 marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB12A1_ACCEPT" not in src:
    raise SystemExit("NLGLOB12A1 injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB12A1_MATERIALIZER=PASS")
