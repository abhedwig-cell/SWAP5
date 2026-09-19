#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[2]


def run(*args: str) -> None:
    subprocess.run(args, check=True, cwd=ROOT)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = pathlib.Path(tmp)

        swp = tmpdir / "swap.swp"
        prepared = tmpdir / "swap_daily.swp"
        manifest = tmpdir / "prepare.json"
        swp.write_text(
            """
TSTART = 2002-01-01
TEND = 2004-12-31
SWMONTH = 1
* PERIOD = 1
* SWRES = 0
* SWODAT = 0
SWVAP = 1
SWCSV = 1
SWETR = 0
SWDIVIDE = 1
SWMETDETAIL = 0
SWRAIN = 0
SWCROP = 1
SWINCO = 2
GWLI = -75.0
SWBOTB = 1
DTMIN = 1.0e-6
DTMAX = 0.2
MAXIT = 30
SWSOPHY = 0
SWDRA = 1
""".lstrip()
        )

        run(
            sys.executable,
            "tests/rom/prepare_lare_rs1_hupsel_daily_output.py",
            "--input", str(swp),
            "--output", str(prepared),
            "--manifest", str(manifest),
        )
        text = prepared.read_text()
        assert "SWMONTH = 0" in text
        assert "PERIOD = 1" in text
        assert "SWRES = 0" in text
        assert "SWODAT = 0" in text
        assert "SWVAP = 1" in text
        assert "SWCSV = 0" in text
        assert "GWLI = -75.0" in text
        prep = json.loads(manifest.read_text())
        assert prep["scientific_semantics_changed"] is False
        assert prep["numerical_semantics_changed"] is False

        vap = tmpdir / "result.vap"
        # 16 comma-separated columns matching outvap. Two 100-cm compartments
        # are sufficient to test exact overlap projection onto all frozen grids.
        vap.write_text(
            "2002-01-01,50.0,0.2,-50,1.0,0,0,0,10,0,0,0,0,100,1,1\n"
            "2002-01-01,150.0,0.4,-10,2.0,0,0,0,10,0,0,0,100,200,1,1\n"
            "2002-01-02,50.0,0.3,-40,1.5,0,0,0,10,0,0,0,0,100,2,2\n"
            "2002-01-02,150.0,0.5,-5,2.5,0,0,0,10,0,0,0,100,200,2,2\n"
        )
        output = tmpdir / "library.json"
        run(
            sys.executable,
            "tests/rom/build_lare_rs1_hupsel_profile_library.py",
            "--vap", str(vap),
            "--candidates", "integration/f-rom/LARE_RS1_HUPSEL_CANDIDATES.json",
            "--output", str(output),
        )
        library = json.loads(output.read_text())
        assert library["profile_count"] == 2
        assert library["node_counts"] == [2]
        assert library["maximum_abs_projection_storage_closure_cm"] <= 1.0e-12
        first = library["profiles"][0]
        assert abs(first["full_profile_storage_cm"] - 60.0) <= 1.0e-12
        assert abs(sum(first["candidates"]["H4_ACTIVE_BOUNDARIES"]["storage_cm"]) - 60.0) <= 1.0e-12

    print("LARE_RS1_HUPSEL_OBSERVATION_TOOLS=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
