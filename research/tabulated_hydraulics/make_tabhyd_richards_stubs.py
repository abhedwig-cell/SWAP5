#!/usr/bin/env python3
"""Create a larger research-only HeadCalc stub profile from the canonical F-SI04 stubs."""
from pathlib import Path
import re,sys
if len(sys.argv)!=3:
    raise SystemExit("usage: make_tabhyd_richards_stubs.py INPUT OUTPUT")
src=Path(sys.argv[1]).read_text()
n=32
src=src.replace("integer, parameter :: macp = 4","integer, parameter :: macp = 64",1)
src=src.replace("integer, parameter :: mabbc = 4","integer, parameter :: mabbc = 64",1)
src=src.replace("integer, parameter :: numnod = 4",f"integer, parameter :: numnod = {n}",1)
z=[-(2.5+5.0*i) for i in range(n)]
dz=[5.0]*n
dis=[5.0]*(n+1)
def arr(vals):
    return "["+", ".join(f"{v:.1f}d0" for v in vals)+"]"
src,n1=re.subn(r"real\(8\), parameter :: z\(numnod\) = \[[^\n]+",
               f"real(8), parameter :: z(numnod) = {arr(z)}",src,count=1)
src,n2=re.subn(r"real\(8\), parameter :: dz\(numnod\) = \[[^\n]+",
               f"real(8), parameter :: dz(numnod) = {arr(dz)}",src,count=1)
src,n3=re.subn(r"real\(8\), parameter :: disnod\(numnod\+1\) = 1\.0d0",
               f"real(8), parameter :: disnod(numnod+1) = {arr(dis)}",src,count=1)
if (n1,n2,n3)!=(1,1,1):
    raise SystemExit(f"grid patch mismatch {(n1,n2,n3)}")
Path(sys.argv[2]).write_text(src)
print(f"TABHYD_RICHARDS_STUBS_NODES={n}")
