#!/usr/bin/env python3
"""Materialize the existing HeadCalc test stubs at a ROM-0 fixed geometry.

Only MOD_grid is replaced. All other legacy support stubs remain byte-for-byte
from the established fsi04 test fixture.
"""
from __future__ import annotations
import argparse, re
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True)
    ap.add_argument("--output",required=True)
    ap.add_argument("--nodes",type=int,required=True)
    ap.add_argument("--dz-cm",type=float,required=True)
    args=ap.parse_args()
    if args.nodes <= 0 or args.dz_cm <= 0:
        raise SystemExit("invalid geometry")
    text=Path(args.source).read_text(encoding="utf-8")
    pattern=re.compile(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n")
    matches=pattern.findall(text)
    if len(matches)!=1:
        raise SystemExit(f"expected one MOD_grid block, found {len(matches)}")
    z=", ".join(f"{-args.dz_cm*(i-0.5):.17g}d0" for i in range(1,args.nodes+1))
    block=(
        "module MOD_grid\n"
        "  implicit none\n"
        f"  integer, parameter :: numnod = {args.nodes}\n"
        f"  real(8), parameter :: z(numnod) = [{z}]\n"
        f"  real(8), parameter :: dz(numnod) = {args.dz_cm:.17g}d0\n"
        f"  real(8), parameter :: disnod(numnod+1) = {args.dz_cm:.17g}d0\n"
        "end module MOD_grid\n"
    )
    out=pattern.sub(block,text,count=1)
    Path(args.output).write_text(out,encoding="utf-8")
    print(f"F_ROM0_STUB_GEOMETRY_N={args.nodes}")
    print(f"F_ROM0_STUB_GEOMETRY_DZ_CM={args.dz_cm:.17g}")

if __name__=="__main__":
    main()
