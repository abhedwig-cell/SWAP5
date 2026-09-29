#!/usr/bin/env python3
"""Materialize HeadCalc stubs with the exact ELASTIC46 variable grid."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def d0(x: float) -> str:
    text = format(float(x), ".17g")
    if "e" in text.lower():
        mantissa, exponent = re.split("[eE]", text)
        return f"{mantissa}d{int(exponent):+d}"
    return text + "d0"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--geometry-json", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    geometry = json.loads(Path(args.geometry_json).read_text(encoding="utf-8"))
    z = [float(v) for v in geometry["z_cm"]]
    dz = [float(v) for v in geometry["dz_cm"]]
    disnod = [float(v) for v in geometry["node_distance_cm"]]
    n = len(z)
    if n <= 0 or len(dz) != n or len(disnod) != n:
        raise SystemExit("F_PE_ELASTIC46_FAIL invalid geometry JSON")
    if any(v <= 0.0 for v in dz) or any(v <= 0.0 for v in disnod):
        raise SystemExit("F_PE_ELASTIC46_FAIL nonpositive grid spacing")

    source = Path(args.source).read_text(encoding="utf-8")
    pattern = re.compile(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n")
    matches = pattern.findall(source)
    if len(matches) != 1:
        raise SystemExit(f"F_PE_ELASTIC46_FAIL expected one MOD_grid block, found {len(matches)}")

    z_text = ", ".join(d0(v) for v in z)
    dz_text = ", ".join(d0(v) for v in dz)
    disnod_full = disnod + [disnod[-1]]
    disnod_text = ", ".join(d0(v) for v in disnod_full)
    block = (
        "module MOD_grid\n"
        "  implicit none\n"
        f"  integer, parameter :: numnod = {n}\n"
        f"  real(8), parameter :: z(numnod) = [{z_text}]\n"
        f"  real(8), parameter :: dz(numnod) = [{dz_text}]\n"
        f"  real(8), parameter :: disnod(numnod+1) = [{disnod_text}]\n"
        "end module MOD_grid\n"
    )
    Path(args.output).write_text(pattern.sub(block, source, count=1), encoding="utf-8")
    print(f"F_PE_ELASTIC46_STUB_GRID_N={n}")
    print("F_PE_ELASTIC46_STUB_GRID=PASS")


if __name__ == "__main__":
    main()
