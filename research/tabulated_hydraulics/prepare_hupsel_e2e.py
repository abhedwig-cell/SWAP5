#!/usr/bin/env python3
"""Prepare paired Hupsel analytical/table cases for the TAB-HYD audit.

This is research harness code only. It does not modify production SWAP5.
The hydraulic table is generated from the two analytical Mualem-van Genuchten
parameter rows authored in the public Hupsel legacy testcase.
"""

from __future__ import annotations
import argparse
import math
import re
import shutil
from pathlib import Path

PARAMS = [
    # ores, osat, alfa, npar, ksatfit, lexp
    (0.01, 0.42, 0.0276, 1.491, 12.52, -1.060),
    (0.02, 0.38, 0.0213, 1.951, 12.68,  0.168),
]
TABLE_NAMES = ["topsoil_sand_b2.csv", "subsoil_sand_o2.csv"]
NPOINTS = 801


def vg_row(h: float, p: tuple[float, ...]) -> tuple[float, float]:
    ores, osat, alfa, npar, ksat, lexp = p
    if h >= 0.0:
        return osat, ksat
    m = 1.0 - 1.0 / npar
    se = (1.0 + (alfa * abs(h)) ** npar) ** (-m)
    theta = ores + (osat - ores) * se
    bracket = 1.0 - (1.0 - se ** (1.0 / m)) ** m
    k = ksat * se ** lexp * bracket ** 2
    return theta, k


def build_heads(n: int = NPOINTS) -> list[float]:
    # n-1 log-spaced points from -1e7 through -1e-5, then exact h=0.
    # This respects the current SWAP lookup-table indexing scheme, which
    # collapses h > -1e-5 into lookup bin 0.
    heads = []
    for i in range(n - 1):
        frac = i / (n - 2)
        exponent = 7.0 - 12.0 * frac
        heads.append(-(10.0 ** exponent))
    heads.append(0.0)
    return heads


def write_table(path: Path, p: tuple[float, ...]) -> None:
    rows = []
    for h in build_heads():
        theta, k = vg_row(h, p)
        rows.append((h, theta, k))
    for a, b in zip(rows, rows[1:]):
        if not (b[0] > a[0] and b[1] > a[1] and b[2] > a[2]):
            raise RuntimeError(f"non-monotone generated table at {a} -> {b}")
    with path.open("w") as fh:
        fh.write("* TAB-HYD research table generated from Hupsel MvG parameters\n")
        fh.write("headtab,thetatab,conductab\n")
        for h, theta, k in rows:
            fh.write(f"{h:.16e},{theta:.16e},{k:.16e}\n")


def edit_case(case_dir: Path, table: bool, swkimpl: int) -> None:
    template = case_dir / "swap_linux.swp.template"
    target = case_dir / "swap.swp"
    text = template.read_text()
    text, n_sophy = re.subn(r"(?m)^(\s*SWSOPHY\s*=\s*)0\b", r"\g<1>1" if table else r"\g<1>0", text, count=1)
    text, n_kimpl = re.subn(r"(?m)^(\s*SWKIMPL\s*=\s*)[01]\b", rf"\g<1>{swkimpl}", text, count=1)
    if n_sophy != 1 or n_kimpl != 1:
        raise RuntimeError(f"failed to edit switches in {template}")
    target.write_text(text)
    if table:
        for name, p in zip(TABLE_NAMES, PARAMS):
            write_table(case_dir / name, p)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("source_case", type=Path)
    ap.add_argument("output_root", type=Path)
    ns = ap.parse_args()
    src = ns.source_case
    out = ns.output_root
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    configs = [
        ("analytic_k0", False, 0),
        ("table_k0", True, 0),
        ("analytic_k1", False, 1),
        ("table_k1", True, 1),
    ]
    for name, table, kimpl in configs:
        dst = out / name
        shutil.copytree(src, dst)
        edit_case(dst, table=table, swkimpl=kimpl)

    print(f"prepared={len(configs)}")
    print(f"table_points={NPOINTS}")
    print("PREPARE_E2E_COMPLETED")


if __name__ == "__main__":
    main()
