#!/usr/bin/env python3
"""Create a 40-node copy of the qualified F-SI04 HeadCalc fixture stubs."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_fsi04_scale40_stub.py INPUT OUTPUT")
src=Path(sys.argv[1])
dst=Path(sys.argv[2])
text=src.read_text()
text,n1=re.subn(
    r"module MOD_arrays.*?end module MOD_arrays",
    """module MOD_arrays
  implicit none
  integer, parameter :: macp = 64
  integer, parameter :: mabbc = 8
end module MOD_arrays""",
    text,count=1,flags=re.S)
text,n2=re.subn(
    r"module MOD_grid.*?end module MOD_grid",
    """module MOD_grid
  implicit none
  integer, parameter :: numnod = 40
  real(8), parameter :: z(numnod) = [(-2.5d0-5.0d0*(i-1), i=1,numnod)]
  real(8), parameter :: dz(numnod) = 5.0d0
  real(8), parameter :: disnod(numnod+1) = 5.0d0
end module MOD_grid""",
    text,count=1,flags=re.S)
text=text.replace("real(8) :: qbotab(2*4) = 0.0d0","real(8) :: qbotab(2*64) = 0.0d0")
if n1 != 1 or n2 != 1:
    raise SystemExit(f"stub anchors failed arrays={n1} grid={n2}")
dst.parent.mkdir(parents=True,exist_ok=True)
dst.write_text(text)
print("TABHYD_SCALE40_STUB_PATCH=PASS")
