#!/usr/bin/env python3
"""Prepare the TAB-HYD envelope with sub-threshold knots uniform in log10(-h).

This is a post-failure research candidate. It reuses all scenario and residual
policies from prepare_envelope_cases.py but changes only table knot placement.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path
import importlib.util

base = Path(__file__).with_name("prepare_envelope_cases.py")
spec = importlib.util.spec_from_file_location("tabhyd_base_prepare", base)
prep = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(prep)

def loghead_rows(p: dict, n: int = prep.NROWS):
    h0 = -1.0e7
    h1 = prep.threshold_head(p)
    u0 = math.log10(-h0)
    u1 = math.log10(-h1)
    rows = []
    for i in range(n - 1):
        frac = i / (n - 2)
        u = u0 + frac * (u1 - u0)
        h = h1 if i == n - 2 else -10.0**u
        rows.append((h, prep.theta_policy(h, p), prep.k_policy(h, p)))
    rows.append((0.0, p["osat"], p["ksat"]))
    for a, b in zip(rows, rows[1:]):
        if not (b[0] > a[0] and b[1] > a[1] and b[2] > a[2]):
            raise RuntimeError((p["comment"], "nonmonotone log-head table", a, b))
    return rows

prep.uniform_rows = loghead_rows

if __name__ == "__main__":
    prep.main()
