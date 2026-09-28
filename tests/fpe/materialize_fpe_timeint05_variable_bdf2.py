#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

old="""   integer :: timeint04b_floor_mode
   common /timeint04b_floor_common/ timeint04b_floor_mode
   real(8) :: timeint04b_total_floor
"""
new=old+"""   real(8) :: timeint05_a0, timeint05_a1, timeint05_a2
   common /timeint05_coeff_common/ timeint05_a0, timeint05_a1, timeint05_a2
"""
if old not in src:
    raise SystemExit("TIMEINT04B declaration block not found")
src=src.replace(old,new,1)

src=src.replace(
"rate = (1.5d0*state%theta(node)-2.0d0*state%thetm1(node)+0.5d0*timeint02_thetam2(node))/dt",
"rate = (timeint05_a0*state%theta(node)+timeint05_a1*state%thetm1(node)+timeint05_a2*timeint02_thetam2(node))/dt")
src=src.replace(
"value = 1.5d0",
"value = timeint05_a0")
src=src.replace(
"""(1.5d0*spacing(state%theta(i)) + 2.0d0*spacing(state%thetm1(i)) + &
                  0.5d0*spacing(timeint02_thetam2(i)))""",
"""(abs(timeint05_a0)*spacing(state%theta(i)) + abs(timeint05_a1)*spacing(state%thetm1(i)) + &
                  abs(timeint05_a2)*spacing(timeint02_thetam2(i)))""")

if "timeint05_a0*state%theta(node)" not in src:
    raise SystemExit("variable BDF2 storage patch failed")
if "value = timeint05_a0" not in src:
    raise SystemExit("variable BDF2 Jacobian patch failed")
if "abs(timeint05_a2)*spacing" not in src:
    raise SystemExit("variable BDF2 floor patch failed")

Path(args.output).write_text(src)
print("F_PE_TIMEINT05_MATERIALIZER=PASS")
