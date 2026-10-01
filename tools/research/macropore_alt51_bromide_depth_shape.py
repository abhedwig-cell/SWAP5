#!/usr/bin/env python3
"""F-MACRO-ALT51: conservative bromide depth-mass operator for RFM p.

Inputs are numeric bromide recovery profiles such as:
- echoRD_model/testcases/brspecht.dat (10 depth bins x 20 lateral cells;
  two independent 10-column profiles)
- echoRD_model/testcases/brprofileXI.dat (15 depth bins x 5 lateral cells)

Only normalized depth mass is used. Absolute recovery units are not required,
provided all cells in one profile share the same volume and tracer unit.

Observation model:
  IC endpoint cumulative F_end(x) = x**p
  -> mass in normalized depth bin [a,b] = b**p - a**p

This identifies an effective retained-tracer endpoint-shape p_obs.
It is not assumed a priori to equal structural RFM p without transport bias.
"""

from __future__ import annotations
import argparse, csv, json, math, random
from pathlib import Path


def read_tab(path: Path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    if not rows:
        raise ValueError("empty file")
    data = []
    for row in rows[1:]:
        if not row:
            continue
        data.append([float(x) for x in row if x != ""])
    ncol = len(data[0])
    if any(len(r) != ncol for r in data):
        raise ValueError("ragged tracer matrix")
    return data


def subset_columns(data, lo, hi):
    return [row[lo:hi] for row in data]


def normalized_depth_mass(data):
    mass = [sum(row) for row in data]
    total = sum(mass)
    if total <= 0.0:
        raise ValueError("nonpositive tracer mass")
    return [m / total for m in mass]


def predicted_bins(n, p):
    edges = [i / n for i in range(n + 1)]
    return [edges[i + 1] ** p - edges[i] ** p for i in range(n)]


def fit_p(obs):
    best = None
    # log grid is dense enough for the empirical uncertainty here
    for i in range(4001):
        p = 10 ** (-2.0 + i * 4.0 / 4000.0)
        pred = predicted_bins(len(obs), p)
        sse = sum((a - b) ** 2 for a, b in zip(obs, pred))
        if best is None or sse < best[0]:
            best = (sse, p, pred)
    sse, p, pred = best
    mean = sum(obs) / len(obs)
    sst = sum((x - mean) ** 2 for x in obs)
    r2 = 1.0 - sse / sst if sst > 0.0 else None
    return p, r2, pred


def bootstrap_p(data, nboot=1000, seed=12345):
    rng = random.Random(seed)
    ncol = len(data[0])
    vals = []
    for _ in range(nboot):
        picks = [rng.randrange(ncol) for _ in range(ncol)]
        sample = [[row[j] for j in picks] for row in data]
        p, _, _ = fit_p(normalized_depth_mass(sample))
        vals.append(p)
    vals.sort()
    def q(prob):
        i = min(len(vals) - 1, max(0, int(round(prob * (len(vals) - 1)))))
        return vals[i]
    return {"p025": q(0.025), "median": q(0.5), "p975": q(0.975)}


def characterize(label, data, bin_m):
    obs = normalized_depth_mass(data)
    p, r2, pred = fit_p(obs)
    centers = [(i + 0.5) * bin_m for i in range(len(obs))]
    centroid = sum(m * z for m, z in zip(obs, centers))
    return {
        "label": label,
        "n_depth_bins": len(obs),
        "n_lateral_cells": len(data[0]),
        "bin_thickness_m": bin_m,
        "normalized_mass_by_depth": obs,
        "depth_centroid_m": centroid,
        "p_effective": p,
        "r2": r2,
        "bootstrap_95": bootstrap_p(data),
        "predicted_endpoint_bin_mass": pred,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spechtacker", required=True)
    ap.add_argument("--colpach", required=True)
    args = ap.parse_args()

    specht = read_tab(Path(args.spechtacker))
    colpach = read_tab(Path(args.colpach))

    result = {
        "schema": "swap5.f_macro_alt51.conservative_tracer_depth_shape.v1",
        "status": "RESEARCH_ONLY",
        "operator": "normalized tracer mass bin = b^p - a^p",
        "profiles": [
            characterize("Spechtacker-profile-1", subset_columns(specht, 0, 10), 0.10),
            characterize("Spechtacker-profile-2", subset_columns(specht, 10, 20), 0.10),
            characterize("Colpach-profile-1", colpach, 0.05),
        ],
        "qualification_boundary": [
            "Only relative depth mass is used; no absolute recovery claim is made.",
            "Equal cell-volume geometry is required within each profile.",
            "p_effective is an observed retained-tracer endpoint-shape parameter.",
            "Equality p_effective == structural RFM p is a testable hypothesis, not assumed truth.",
            "Missing tracer mass below the sampled profile cannot identify f_MB without applied/recovered mass closure.",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
