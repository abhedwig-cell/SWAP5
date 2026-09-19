#!/usr/bin/env python3
"""Prepare paired Hupsel analytical/table cases for the TAB-HYD audit.

Research harness only. The table generator mirrors the legacy default-MvG
theta(h) and K(h) policy used by the pinned pre-strangler runtime for the
Hupsel h_enpr=0 layers, including the near-saturation theta smoothing and
Ksat clamp. Repeated Ksat points are omitted because ReadSwap requires
strictly increasing conductab.
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
HCRIT = -1.0e-2
RELSAT_KSAT = 1.0 - 1.0e-6
NCANDIDATE = 900


def theta_policy(h: float, p: tuple[float, ...]) -> float:
    ores, osat, alfa, npar, _ksat, _lexp = p
    m = 1.0 - 1.0 / npar
    if h >= 0.0:
        return osat
    if h > HCRIT:
        help0 = (abs(alfa * HCRIT)) ** npar
        theta_crit = ores + (osat - ores) / ((1.0 + help0) ** m)
        return min(theta_crit + (osat - theta_crit) / (-HCRIT) * (h - HCRIT), osat)
    return ores + (osat - ores) / ((1.0 + (abs(alfa * h)) ** npar) ** m)


def k_policy(h: float, p: tuple[float, ...]) -> float:
    ores, osat, _alfa, npar, ksat, lexp = p
    m = 1.0 - 1.0 / npar
    th = theta_policy(h, p)
    relsat = (th - ores) / (osat - ores)
    if h < -1.0e14:
        return 1.0e-10
    if relsat > RELSAT_KSAT:
        return ksat
    term = (1.0 - relsat ** (1.0 / m)) ** m
    return min(ksat * relsat ** lexp * (1.0 - term) ** 2, ksat)


def build_rows(p: tuple[float, ...]) -> list[tuple[float, float, float]]:
    rows: list[tuple[float, float, float]] = []
    for i in range(NCANDIDATE):
        frac = i / (NCANDIDATE - 1)
        exponent = 7.0 - 13.0 * frac
        h = -(10.0 ** exponent)
        th = theta_policy(h, p)
        k = k_policy(h, p)
        relsat = (th - p[0]) / (p[1] - p[0])
        if relsat > RELSAT_KSAT:
            continue
        if not (math.isfinite(th) and math.isfinite(k) and k > 0.0):
            raise RuntimeError(f"invalid generated hydraulic row h={h} theta={th} K={k}")
        if rows and not (h > rows[-1][0] and th > rows[-1][1] and k > rows[-1][2]):
            raise RuntimeError(f"non-monotone generated row {rows[-1]} -> {(h, th, k)}")
        rows.append((h, th, k))

    rows.append((0.0, p[1], p[4]))
    if len(rows) > 1000:
        raise RuntimeError(f"generated table exceeds MATB=1000: {len(rows)}")
    for a, b in zip(rows, rows[1:]):
        if not (b[0] > a[0] and b[1] > a[1] and b[2] > a[2]):
            raise RuntimeError(f"final table not strictly increasing: {a} -> {b}")
    return rows


def write_table(path: Path, p: tuple[float, ...]) -> int:
    rows = build_rows(p)
    with path.open("w", newline="\n") as fh:
        fh.write("* TAB-HYD research table generated from Hupsel analytical policy\n")
        fh.write("headtab,thetatab,conductab\n")
        for h, theta, k in rows:
            fh.write(f"{h:.16e},{theta:.16e},{k:.16e}\n")
    return len(rows)


def edit_case(case_dir: Path, table: bool, swkimpl: int) -> list[int]:
    template = case_dir / "swap_linux.swp.template"
    target = case_dir / "swap.swp"
    text = template.read_text()
    text, n_sophy = re.subn(
        r"(?m)^(\s*SWSOPHY\s*=\s*)[01]\b",
        rf"\g<1>{1 if table else 0}",
        text,
        count=1,
    )
    text, n_kimpl = re.subn(
        r"(?m)^(\s*SWKIMPL\s*=\s*)[01]\b",
        rf"\g<1>{swkimpl}",
        text,
        count=1,
    )
    if n_sophy != 1 or n_kimpl != 1:
        raise RuntimeError(f"failed to edit switches in {template}")
    target.write_text(text)
    counts: list[int] = []
    if table:
        for name, p in zip(TABLE_NAMES, PARAMS):
            counts.append(write_table(case_dir / name, p))
    return counts


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
    table_counts = None
    for name, table, kimpl in configs:
        dst = out / name
        shutil.copytree(src, dst)
        counts = edit_case(dst, table=table, swkimpl=kimpl)
        if counts:
            table_counts = counts
        print(f"CASE {name} swsophy={1 if table else 0} swkimpl={kimpl}")

    if table_counts:
        print(f"TABLE_ROWS top={table_counts[0]} sub={table_counts[1]}")
    print(f"prepared={len(configs)}")
    print("PREPARE_E2E_COMPLETED")


if __name__ == "__main__":
    main()
