#!/usr/bin/env python3
"""Quantify the default-MvG Ksat-clamp discontinuity for Staring parameter sets.

Research-only diagnostic. The current default MvG residual returns Ksat when
relative saturation exceeds 1-1e-6. Immediately below that threshold it returns
the ordinary Mualem-van Genuchten conductivity. For some parameterizations these
two values are far apart, so the implemented residual contains a finite jump.
"""
from __future__ import annotations

import csv
import math
import sys
from pathlib import Path

SE = 1.0 - 1.0e-6

def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: ksat_clamp_jump_scan.py staringreeks1994.csv")
    path = Path(sys.argv[1])
    rows = []
    with path.open(newline="") as fh:
        for raw in csv.DictReader(fh):
            r = {k.strip(): v.strip() for k, v in raw.items()}
            spu = r["SPU"].lower()
            n = float(r["NPAR"])
            m = 1.0 - 1.0/n
            lam = float(r["LEXP"])
            alpha = float(r["ALFAD"])
            ksat = float(r["KSAT"])
            t = SE ** (1.0/m)
            bracket = 1.0 - (1.0 - t) ** m
            ratio_below = SE ** lam * bracket**2
            k_below = ksat * ratio_below
            jump = ksat - k_below
            factor = ksat / k_below
            h_threshold = -((SE ** (-1.0/m) - 1.0) ** (1.0/n)) / alpha
            rows.append((spu,n,lam,alpha,ksat,h_threshold,k_below,jump,factor,ratio_below))

    rows.sort(key=lambda x: x[8], reverse=True)
    print("soil,n,lexp,alpha,ksat,h_threshold,k_below,jump_abs,ksat_over_k_below,k_below_over_ksat")
    for row in rows:
        print(",".join(
            [row[0]] + [f"{x:.17g}" for x in row[1:]]
        ))
    print("KSAT_CLAMP_JUMP_SCAN_COMPLETED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
