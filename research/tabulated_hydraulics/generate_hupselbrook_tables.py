#!/usr/bin/env python3
"""Generate tabulated hydraulics matching the Hupselbrook analytical MvG setup.

This is a characterization utility. It mirrors the current public SWAP
default-MvG water-content and conductivity policy closely enough to construct
an equivalent table without repeated saturated K values, which ReadSwap rejects.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys

PARAMS = {
    "topsoil_sand_b2.csv": dict(theta_r=0.01, theta_s=0.42, alpha=0.0276, n=1.491, ksat=12.52, lexp=-1.060),
    "subsoil_sand_o2.csv": dict(theta_r=0.02, theta_s=0.38, alpha=0.0213, n=1.951, ksat=12.68, lexp=0.168),
}
HCRIT = -1.0e-2
RELSAT_KSAT = 1.0 - 1.0e-6


def theta(head: float, p: dict[str, float]) -> float:
    tr, ts, alpha, n = p["theta_r"], p["theta_s"], p["alpha"], p["n"]
    m = 1.0 - 1.0 / n
    if head >= 0.0:
        return ts
    if head > HCRIT:
        help0 = (abs(alpha * HCRIT)) ** n
        theta_crit = tr + (ts - tr) / ((1.0 + help0) ** m)
        return min(theta_crit + (ts - theta_crit) / (-HCRIT) * (head - HCRIT), ts)
    return tr + (ts - tr) / ((1.0 + (abs(alpha * head)) ** n) ** m)


def conductivity(head: float, p: dict[str, float]) -> float:
    tr, ts, n, ksat, lexp = p["theta_r"], p["theta_s"], p["n"], p["ksat"], p["lexp"]
    m = 1.0 - 1.0 / n
    th = theta(head, p)
    relsat = (th - tr) / (ts - tr)
    if head < -1.0e14:
        return 1.0e-10
    if relsat > RELSAT_KSAT:
        return ksat
    term = (1.0 - relsat ** (1.0 / m)) ** m
    return min(ksat * relsat ** lexp * (1.0 - term) ** 2, ksat)


def generate(p: dict[str, float]) -> list[tuple[float, float, float]]:
    # Dense log grid from -1e7 toward zero. Points in the analytical Ksat
    # plateau are omitted; one exact h=0 endpoint is appended.
    exponents = [7.0 - 13.0 * i / 849.0 for i in range(850)]
    rows: list[tuple[float, float, float]] = []
    for exponent in exponents:
        h = -(10.0 ** exponent)
        th = theta(h, p)
        k = conductivity(h, p)
        relsat = (th - p["theta_r"]) / (p["theta_s"] - p["theta_r"])
        if relsat > RELSAT_KSAT:
            continue
        if not (math.isfinite(th) and math.isfinite(k) and k > 0.0):
            raise RuntimeError(f"non-finite/non-positive table value at h={h}: theta={th}, K={k}")
        if rows and not (h > rows[-1][0] and th > rows[-1][1] and k > rows[-1][2]):
            raise RuntimeError(f"non-monotone generated table at h={h}")
        rows.append((h, th, k))

    rows.append((0.0, p["theta_s"], p["ksat"]))
    if len(rows) > 1000:
        raise RuntimeError(f"table exceeds MATB=1000: {len(rows)} rows")
    for a, b in zip(rows, rows[1:]):
        if not (b[0] > a[0] and b[1] > a[1] and b[2] > a[2]):
            raise RuntimeError(f"final table is not strictly increasing: {a} -> {b}")
    return rows


def write_table(path: Path, rows: list[tuple[float, float, float]]) -> None:
    with path.open("w", newline="\n") as f:
        f.write("* Generated for TAB-HYD Hupselbrook equivalence characterization\n")
        f.write("headtab,thetatab,conductab\n")
        for h, th, k in rows:
            f.write(f"{h:.16E}, {th:.16E}, {k:.16E}\n")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_hupselbrook_tables.py OUTPUT_DIR")
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, params in PARAMS.items():
        rows = generate(params)
        write_table(out / name, rows)
        first, last = rows[0], rows[-1]
        print(
            f"TABLE {name} rows={len(rows)} "
            f"h_min={first[0]:.6e} h_max={last[0]:.6e} "
            f"theta=[{first[1]:.6e},{last[1]:.6e}] "
            f"K=[{first[2]:.6e},{last[2]:.6e}]"
        )


if __name__ == "__main__":
    main()
