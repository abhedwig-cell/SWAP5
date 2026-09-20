#!/usr/bin/env python3
"""Research-only hybrid TSPACK/PCHIP selector for TAB-HYD.

mode=theta-tspack: TSPACK for theta and C, PCHIP for K and dK/dh.
mode=k-tspack:     PCHIP for theta and C, TSPACK for K and dK/dh.
"""
from pathlib import Path
import sys
if len(sys.argv)!=3 or sys.argv[2] not in ("theta-tspack","k-tspack"):
    raise SystemExit("usage: patch_hybrid_interpolator.py sptabulated.f90 {theta-tspack|k-tspack}")
p=Path(sys.argv[1]); mode=sys.argv[2]
s=p.read_text()

ev_start=s.index("subroutine EvalTabulatedFunction")
ev_end=s.index("subroutine PreProcTabulatedFunction",ev_start)
ev=s[ev_start:ev_end]
needle="         if (use_TSPACK) then"
if ev.count(needle)!=1:
    raise SystemExit(f"Eval TSPACK branch mismatch: {ev.count(needle)}")
if mode=="theta-tspack":
    repl="         if (use_TSPACK .and. (iWhat == 1 .or. iWhat == 3)) then"
else:
    repl="         if (use_TSPACK .and. (iWhat == 2 .or. iWhat == 4)) then"
ev=ev.replace(needle,repl,1)
s=s[:ev_start]+ev+s[ev_end:]

pp_start=s.index("subroutine PreProcTabulatedFunction")
pp_end=s.index("SUBROUTINE DPCHIC",pp_start)
pp=s[pp_start:pp_end]
needle2="      if (use_TSPACK) then"
if pp.count(needle2)!=1:
    raise SystemExit(f"PreProc TSPACK branch mismatch: {pp.count(needle2)}")
if mode=="theta-tspack":
    repl2="      if (use_TSPACK .and. flag == 1) then"
else:
    repl2="      if (use_TSPACK .and. flag == 2) then"
pp=pp.replace(needle2,repl2,1)
s=s[:pp_start]+pp+s[pp_end:]
p.write_text(s)
print(f"HYBRID_INTERPOLATOR_PATCH_APPLIED mode={mode} {p}")
