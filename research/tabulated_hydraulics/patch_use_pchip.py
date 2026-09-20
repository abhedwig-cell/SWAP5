#!/usr/bin/env python3
"""Research-only switch from TSPACK tension splines to the existing PCHIP path."""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_use_pchip.py sptabulated.f90")
p=Path(sys.argv[1])
s=p.read_text()
old="""module doTSPACK
!   logical, parameter :: use_TSPACK = .false.
   logical, parameter :: use_TSPACK = .true."""
new="""module doTSPACK
   logical, parameter :: use_TSPACK = .false.
!  logical, parameter :: use_TSPACK = .true."""
if s.count(old)!=1:
    raise SystemExit(f"TSPACK switch block mismatch: {s.count(old)}")
p.write_text(s.replace(old,new,1))
print(f"PCHIP_INTERPOLATION_PATCH_APPLIED {p}")
