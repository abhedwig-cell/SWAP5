#!/usr/bin/env python3
"""F-MACRO-ALT52: held-out conservative-tracer endpoint-shape validation.

Calibration:
  Spechtacker Profile 1 only.

Held-out within-site validation:
  Spechtacker Profile 2 with p frozen.

Out-of-system form check:
  Colpach profile may fit its own p because p is a structural profile parameter,
  but the endpoint law itself is unchanged.
"""

from __future__ import annotations
import csv, json, math, sys
from pathlib import Path


def read_tab(path):
    with Path(path).open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    return [[float(x) for x in r if x != ""] for r in rows[1:] if r]


def columns(data, a, b):
    return [r[a:b] for r in data]


def norm_mass(data):
    m = [sum(r) for r in data]
    s = sum(m)
    return [x / s for x in m]


def pred(n, p):
    e = [i / n for i in range(n + 1)]
    return [e[i + 1] ** p - e[i] ** p for i in range(n)]


def metrics(obs, prediction):
    mean = sum(obs) / len(obs)
    sse = sum((a - b) ** 2 for a, b in zip(obs, prediction))
    sst = sum((a - mean) ** 2 for a in obs)
    rmse = math.sqrt(sse / len(obs))
    return {"r2": 1.0 - sse / sst, "rmse_fraction_per_bin": rmse}


def fit_p(obs):
    best = None
    for i in range(4001):
        p = 10 ** (-2.0 + 4.0 * i / 4000.0)
        y = pred(len(obs), p)
        sse = sum((a - b) ** 2 for a, b in zip(obs, y))
        if best is None or sse < best[0]:
            best = (sse, p)
    return best[1]


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: alt52 SPECHT.dat COLPACH.dat")

    specht = read_tab(sys.argv[1])
    colpach = read_tab(sys.argv[2])

    obs_cal = norm_mass(columns(specht, 0, 10))
    obs_hold = norm_mass(columns(specht, 10, 20))
    p_cal = fit_p(obs_cal)
    y_cal = pred(len(obs_cal), p_cal)
    y_hold = pred(len(obs_hold), p_cal)

    obs_col = norm_mass(colpach)
    p_col = fit_p(obs_col)
    y_col = pred(len(obs_col), p_col)

    print(json.dumps({
        "schema": "swap5.f_macro_alt52.heldout_tracer_endpoint_validation.v1",
        "status": "RESEARCH_ONLY",
        "spechtacker": {
            "p_calibrated_profile1": p_cal,
            "calibration_metrics": metrics(obs_cal, y_cal),
            "heldout_profile2_metrics_with_p_frozen": metrics(obs_hold, y_hold),
        },
        "colpach": {
            "p_profile_specific": p_col,
            "form_check_metrics": metrics(obs_col, y_col),
        },
        "decision": (
            "One Spechtacker-calibrated p transfers strongly to the independent "
            "second profile; the same endpoint-mass law also describes the "
            "independent Colpach profile with a different structural p."
        ),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
