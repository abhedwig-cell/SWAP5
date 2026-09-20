#!/usr/bin/env python3
"""Materialize the established HeadCalc test stubs on a fixed nonuniform grid.

Research/test infrastructure only. MOD_grid is the only replaced module.
"""
from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def parse_thicknesses(raw: str) -> list[float]:
    values=[float(x.strip()) for x in raw.split(",") if x.strip()]
    if not values or any((not math.isfinite(x) or x <= 0.0) for x in values):
        raise SystemExit("invalid positive finite layer thickness list")
    if abs(sum(values)-160.0)>1e-12:
        raise SystemExit(f"Layer-ROM comparator depth drift: {sum(values)}")
    return values


def f90_array(values: list[float]) -> str:
    return ", ".join(f"{value:.17g}d0" for value in values)


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True)
    ap.add_argument("--output",required=True)
    ap.add_argument("--layer-thickness-cm",required=True)
    a=ap.parse_args()

    dz=parse_thicknesses(a.layer_thickness_cm)
    n=len(dz)
    z=[]
    depth=0.0
    for thickness in dz:
        z.append(-(depth+0.5*thickness))
        depth+=thickness
    disnod=[0.5*dz[0]]
    for i in range(1,n):
        disnod.append(0.5*(dz[i-1]+dz[i]))
    disnod.append(0.5*dz[-1])

    text=Path(a.source).read_text(encoding="utf-8")
    pattern=re.compile(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n")
    found=pattern.findall(text)
    if len(found)!=1:
        raise SystemExit(f"expected one MOD_grid block, found {len(found)}")
    block=(
        "module MOD_grid\n"
        "  implicit none\n"
        f"  integer, parameter :: numnod = {n}\n"
        f"  real(8), parameter :: z(numnod) = [{f90_array(z)}]\n"
        f"  real(8), parameter :: dz(numnod) = [{f90_array(dz)}]\n"
        f"  real(8), parameter :: disnod(numnod+1) = [{f90_array(disnod)}]\n"
        "end module MOD_grid\n"
    )
    Path(a.output).write_text(pattern.sub(block,text,count=1),encoding="utf-8")
    print(f"LAYER_ROM_VARIABLE_GRID_N={n}")
    print(f"LAYER_ROM_VARIABLE_GRID_DEPTH_CM={depth:.17g}")
    print("LAYER_ROM_VARIABLE_GRID_DZ_CM="+",".join(f"{x:.17g}" for x in dz))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
