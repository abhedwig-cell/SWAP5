#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tests/fsi/fsi04_real_headcalc_stubs.f90"
TOOL = ROOT / "tests/rom/materialize_lare_variable_grid_stubs.py"


def run_case(spec: str, expected_n: int, expected_z: list[float], expected_dz: list[float], expected_disnod: list[float]) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        out = pathlib.Path(tmp) / "stubs.f90"
        subprocess.run(
            [sys.executable, str(TOOL), "--source", str(SOURCE), "--output", str(out), "--layer-thickness-cm", spec],
            cwd=ROOT, check=True,
        )
        text = out.read_text()
        block = re.search(r"(?ms)^module MOD_grid\n.*?^end module MOD_grid\n", text)
        assert block is not None
        grid = block.group(0)
        assert f"integer, parameter :: numnod = {expected_n}" in grid
        for value in expected_z:
            assert f"{value:.17g}d0" in grid
        for value in expected_dz:
            assert f"{value:.17g}d0" in grid
        for value in expected_disnod:
            assert f"{value:.17g}d0" in grid


def main() -> int:
    run_case(
        "140,10,10",
        3,
        [-70.0, -145.0, -155.0],
        [140.0, 10.0, 10.0],
        [70.0, 75.0, 10.0, 5.0],
    )
    run_case(
        "150,10",
        2,
        [-75.0, -155.0],
        [150.0, 10.0],
        [75.0, 80.0, 5.0],
    )
    print("LARE_VARIABLE_GRID_MATERIALIZER=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
