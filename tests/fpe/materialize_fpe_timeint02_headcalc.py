#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()
orig=src

marker="implicit none"
insert="""implicit none
   integer :: timeint02_mode
   real(8) :: timeint02_thetam2(1000)
   common /timeint02_history_common/ timeint02_mode, timeint02_thetam2
"""
if marker not in src:
    raise SystemExit("missing implicit none")
src=src.replace(marker,insert,1)

repls={
"grid_dz(i)*matrix_fraction(i)*(state%theta(i)-state%thetm1(i)) / dt":
"grid_dz(i)*matrix_fraction(i)*timeint02_storage_rate(i)",
"(state%theta(1) - state%thetm1(1)) * matrix_fraction(1) * grid_dz(1) / dt":
"timeint02_storage_rate(1) * matrix_fraction(1) * grid_dz(1)",
"(state%theta(i) - state%thetm1(i)) * matrix_fraction(i) * grid_dz(i) / dt":
"timeint02_storage_rate(i) * matrix_fraction(i) * grid_dz(i)",
"(state%theta(NN) - state%thetm1(NN))*matrix_fraction(NN)*grid_dz(NN)/dt":
"timeint02_storage_rate(NN)*matrix_fraction(NN)*grid_dz(NN)",
"state%dimoca(1)*matrix_fraction(1)*grid_dz(1)/dt":
"timeint02_jac_factor()*state%dimoca(1)*matrix_fraction(1)*grid_dz(1)/dt",
"state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt":
"timeint02_jac_factor()*state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt",
"state%dimoca(NN)*matrix_fraction(NN)*grid_dz(NN)/dt":
"timeint02_jac_factor()*state%dimoca(NN)*matrix_fraction(NN)*grid_dz(NN)/dt",
}
counts={}
for a,b in repls.items():
    counts[a]=src.count(a)
    src=src.replace(a,b)

contains="contains\\n"
helper="""contains

real(8) function timeint02_storage_rate(node) result(rate)
   integer, intent(in) :: node
   if (timeint02_mode == 2) then
      rate = (1.5d0*state%theta(node)-2.0d0*state%thetm1(node)+0.5d0*timeint02_thetam2(node))/dt
   else
      rate = (state%theta(node)-state%thetm1(node))/dt
   end if
end function timeint02_storage_rate

real(8) function timeint02_jac_factor() result(value)
   if (timeint02_mode == 2) then
      value = 1.5d0
   else
      value = 1.0d0
   end if
end function timeint02_jac_factor

"""
if contains not in src:
    raise SystemExit("missing contains")
src=src.replace(contains,helper,1)

required=[
"(state%theta(1) - state%thetm1(1)) * matrix_fraction(1) * grid_dz(1) / dt",
"(state%theta(i) - state%thetm1(i)) * matrix_fraction(i) * grid_dz(i) / dt",
"state%dimoca(1)*matrix_fraction(1)*grid_dz(1)/dt",
"state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt",
"state%dimoca(NN)*matrix_fraction(NN)*grid_dz(NN)/dt",
]
for key in required:
    if counts[key] < 1:
        raise SystemExit(f"required patch point missing: {key}")

Path(args.output).write_text(src)
print("F_PE_TIMEINT02_MATERIALIZER=PASS")
for k,v in counts.items():
    print("PATCH_COUNT",v,k)
