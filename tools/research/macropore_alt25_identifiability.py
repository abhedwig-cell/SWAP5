#!/usr/bin/env python3
"""F-MACRO-ALT25: local structural identifiability screen for RFM.

Research-only. Standard library only.

Parameters:
- sigma_B
- f_MB
- shape_a
- shape_b
- R_AH

Observables over multiple forcing cases:
- preferential fraction
- deep receipt fraction
- mean IC endpoint/deposition depth
- maximum recruited IC depth

Computes log-parameter finite-difference sensitivities, column correlations,
and singular values of the stacked sensitivity matrix.

The script is a structural-identifiability diagnostic, not an empirical fit.
"""

from __future__ import annotations
import json
import math


EVENTS = [
    (4.0, 2.0),
    (8.0, 4.0),
    (15.0, 7.5),
    (20.0, 40.0),
    (40.0, 40.0),
    (60.0, 40.0),
]

BASE = {
    "sigma_B": 0.65,
    "f_MB": 0.25,
    "shape_a": 0.31,
    "shape_b": 0.55,
    "R_AH": 0.20,
}

K_SURFACE = 0.396
S_SURFACE = 13.34
Z_AH = 25.0
Z_IC = 85.0


def cdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def preferential_rate(R, b50, sigma):
    mu = math.log(b50)
    lr = math.log(R)
    z1 = (lr - mu - sigma * sigma) / sigma
    z2 = (lr - mu) / sigma
    matrix = math.exp(mu + 0.5 * sigma * sigma) * cdf(z1)
    matrix += R * (1.0 - cdf(z2))
    matrix = max(0.0, min(R, matrix))
    return R - matrix


def c_struct(z, shape_a, shape_b, r_ah):
    if z <= Z_AH:
        return 1.0
    if z >= Z_IC:
        return 0.0
    x = (z - Z_AH) / (Z_IC - Z_AH)
    return (1.0 - r_ah) * ((1.0 - x ** shape_a) ** shape_b)


def endpoint_weights(activation, shape_a, shape_b, r_ah):
    depths = list(range(1, int(Z_IC) + 1))
    previous = activation
    raw = []
    for z in depths:
        survival = max(
            0.0,
            activation - (1.0 - c_struct(float(z), shape_a, shape_b, r_ah)),
        )
        loss = max(0.0, previous - survival)
        raw.append((z, loss))
        previous = survival

    total = sum(w for _, w in raw)
    if total <= 0.0:
        return [(Z_AH, 1.0)]
    return [(z, w / total) for z, w in raw if w > 0.0]


def event_observables(R, total, p, dt=0.002):
    duration = total / R
    n = max(1, round(duration / dt))
    dt = duration / n

    pref = 0.0
    deep = 0.0
    depth_num = 0.0
    depth_den = 0.0
    max_depth = Z_AH

    for i in range(n):
        tau = (i + 0.5) * dt
        b50 = K_SURFACE + S_SURFACE / (2.0 * math.sqrt(tau))
        pr = preferential_rate(R, b50, p["sigma_B"])
        q = pr * dt
        pref += q
        deep += q * p["f_MB"]

        activation = pr / R
        for z, w in endpoint_weights(
            activation,
            p["shape_a"],
            p["shape_b"],
            p["R_AH"],
        ):
            qq = q * (1.0 - p["f_MB"]) * w
            depth_num += qq * z
            depth_den += qq
            if qq > 0.0:
                max_depth = max(max_depth, z)

    return [
        pref / total,
        deep / total,
        (depth_num / depth_den) / 60.0 if depth_den else Z_AH / 60.0,
        max_depth / 60.0,
    ]


def all_observables(p):
    out = []
    for R, total in EVENTS:
        out.extend(event_observables(R, total, p))
    return out


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def norm(a):
    return math.sqrt(dot(a, a))


def correlation(a, b):
    na = norm(a)
    nb = norm(b)
    return dot(a, b) / (na * nb) if na and nb else 0.0


def jacobi_eigenvalues_symmetric(matrix, sweeps=100):
    """Small symmetric Jacobi eigenvalue solver, standard library only."""
    a = [row[:] for row in matrix]
    n = len(a)
    for _ in range(sweeps):
        p = q = 0
        best = 0.0
        for i in range(n):
            for j in range(i + 1, n):
                if abs(a[i][j]) > best:
                    best = abs(a[i][j])
                    p, q = i, j
        if best < 1.0e-14:
            break

        app = a[p][p]
        aqq = a[q][q]
        apq = a[p][q]
        phi = 0.5 * math.atan2(2.0 * apq, aqq - app)
        c = math.cos(phi)
        s = math.sin(phi)

        for k in range(n):
            if k != p and k != q:
                akp = a[k][p]
                akq = a[k][q]
                a[k][p] = a[p][k] = c * akp - s * akq
                a[k][q] = a[q][k] = s * akp + c * akq

        a[p][p] = c*c*app - 2*s*c*apq + s*s*aqq
        a[q][q] = s*s*app + 2*s*c*apq + c*c*aqq
        a[p][q] = a[q][p] = 0.0

    return sorted((a[i][i] for i in range(n)), reverse=True)


def singular_values(columns):
    gram = [
        [dot(columns[i], columns[j]) for j in range(len(columns))]
        for i in range(len(columns))
    ]
    eig = jacobi_eigenvalues_symmetric(gram)
    return [math.sqrt(max(0.0, x)) for x in eig]


def main():
    names = list(BASE)
    eps = 0.01
    columns = []

    for name in names:
        pp = dict(BASE)
        pm = dict(BASE)
        pp[name] *= 1.0 + eps
        pm[name] *= 1.0 - eps
        yp = all_observables(pp)
        ym = all_observables(pm)
        # derivative w.r.t. log(parameter)
        columns.append([
            (a - b) / (2.0 * eps)
            for a, b in zip(yp, ym)
        ])

    sv_all = singular_values(columns)
    condition_all = sv_all[0] / sv_all[-1]

    idx_fix_rah = [0, 1, 2, 3]
    cols_fix_rah = [columns[i] for i in idx_fix_rah]
    sv_fix_rah = singular_values(cols_fix_rah)
    condition_fix_rah = sv_fix_rah[0] / sv_fix_rah[-1]

    correlations = {
        names[i]: {
            names[j]: correlation(columns[i], columns[j])
            for j in range(len(names))
        }
        for i in range(len(names))
    }

    sensitivity_norms = {
        names[i]: norm(columns[i])
        for i in range(len(names))
    }

    print(json.dumps({
        "schema": "swap5.f_macro_alt25.identifiability.v1",
        "status": "RESEARCH_ONLY",
        "events": [
            {"rain_rate": r, "total_input": t}
            for r, t in EVENTS
        ],
        "parameters": BASE,
        "observables_per_event": [
            "preferential_fraction",
            "deep_receipt_fraction",
            "mean_ic_depth_normalized",
            "max_ic_depth_normalized",
        ],
        "sensitivity_norms": sensitivity_norms,
        "correlations": correlations,
        "singular_values_all_parameters": sv_all,
        "condition_number_all_parameters": condition_all,
        "singular_values_fix_R_AH": sv_fix_rah,
        "condition_number_fix_R_AH": condition_fix_rah,
        "key_result": {
            "shape_a_vs_R_AH_correlation": correlations["shape_a"]["R_AH"],
            "decision": (
                "R_AH should not remain an independently calibrated parameter "
                "in the leading reduced parameter set unless new orthogonal data "
                "are identified."
            ),
        },
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
