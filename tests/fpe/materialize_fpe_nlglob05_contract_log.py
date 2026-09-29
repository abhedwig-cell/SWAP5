#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   real(8) :: nlglob05_head_ratio,nlglob05_ratio,nlglob05_pond_dev,nlglob05_pond_ratio,nlglob05_qtop
   logical :: nlglob05_pond_applicable
"""
if marker not in src:
    raise SystemExit("NLGLOB05 declaration marker missing")
src=src.replace(marker,insert,1)

needle=""" 1    continue

!     check on convergence of solution
"""
repl=""" 1    continue

      if (provider_dynamic_top_active) then
         nlglob05_head_ratio=0.0d0
         do i=1,NN
            if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
               nlglob05_ratio=dabs(state%h(i)-fsi_ws%old_head(i))/critdevh2cp
            else
               nlglob05_ratio=(dabs(state%h(i)-fsi_ws%old_head(i))/dabs(fsi_ws%old_head(i)))/critdevh1cp
            end if
            nlglob05_head_ratio=max(nlglob05_head_ratio,nlglob05_ratio)
         end do
         nlglob05_pond_applicable=index(trim(provider_dynamic_top_result%route),'surface-flux') == 0
         nlglob05_pond_ratio=0.0d0
         nlglob05_pond_dev=0.0d0
         if (nlglob05_pond_applicable) then
            if (state%ftoph) then
               nlglob05_qtop=-state%kmean(1)*((state%hsurf-state%h(1))/grid_disnod(1)+1.0d0)
            else
               nlglob05_qtop=state%qtop
            end if
            nlglob05_pond_dev=state%pond-state%pondm1-provider_dynamic_top_result%net_potential_surface_flux*dt+ &
                 state%runots-nlglob05_qtop*dt
            nlglob05_pond_ratio=dabs(nlglob05_pond_dev)/critdevponddt
         end if
         write(*,'(*(g0))') 'F_PE_NLGLOB05_CONTRACT|ITER=',state%numbit, &
              '|HEAD_RATIO=',nlglob05_head_ratio,'|POND_APPLICABLE=',merge(1,0,nlglob05_pond_applicable), &
              '|POND_RATIO=',nlglob05_pond_ratio,'|POND_DEV=',nlglob05_pond_dev, &
              '|ROUTE=',trim(provider_dynamic_top_result%route)
      end if

!     check on convergence of solution
"""
if needle not in src:
    raise SystemExit("NLGLOB05 convergence marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB05_CONTRACT" not in src:
    raise SystemExit("NLGLOB05 injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB05_MATERIALIZER=PASS")
