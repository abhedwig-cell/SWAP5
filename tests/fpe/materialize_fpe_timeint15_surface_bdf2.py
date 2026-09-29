#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

decl="""   real(8) :: timeint05_a0, timeint05_a1, timeint05_a2
   common /timeint05_coeff_common/ timeint05_a0, timeint05_a1, timeint05_a2
"""
decl_new=decl+"""   real(8) :: timeint15_surface_a0, timeint15_surface_a1, timeint15_surface_a2
   real(8) :: timeint15_surface_pond_nm1, timeint15_surface_runoff_rate
   common /timeint15_surface_common/ timeint15_surface_a0, timeint15_surface_a1, timeint15_surface_a2, &
        timeint15_surface_pond_nm1, timeint15_surface_runoff_rate
"""
if decl not in src:
    raise SystemExit("TIMEINT05 coefficient block not found")
src=src.replace(decl,decl_new,1)

old="""            deviat = state%pond - state%pondm1 - provider_dynamic_top_result%net_potential_surface_flux*dt + &
                     state%runots - state%qtop * dt
"""
new="""            deviat = timeint15_surface_a0*state%pond + timeint15_surface_a1*state%pondm1 + &
                     timeint15_surface_a2*timeint15_surface_pond_nm1 - &
                     provider_dynamic_top_result%net_potential_surface_flux*dt + &
                     timeint15_surface_runoff_rate*dt - state%qtop*dt
"""
if old not in src:
    raise SystemExit("dynamic-top pond balance patch point missing")
src=src.replace(old,new,1)

if "timeint15_surface_a0*state%pond" not in src:
    raise SystemExit("TIMEINT15 surface balance patch failed")

Path(args.output).write_text(src)
print("F_PE_TIMEINT15_SURFACE_MATERIALIZER=PASS")
