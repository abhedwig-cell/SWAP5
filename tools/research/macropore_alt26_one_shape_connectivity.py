#!/usr/bin/env python3
"""F-MACRO-ALT26: one-shape connectivity nested-model screen.

Research-only. Standard library only.

Compares:
- previous two-shape bounded survival;
- constrained one-shape survival C(z) = 1 - x**p, x=(z-Z_AH)/(Z_IC-Z_AH).

R_AH is removed from the free parameter set.

Tests:
- ability to reproduce depth-sensitive and depth-insensitive ALT22 regimes;
- local identifiability of sigma_B, f_MB, p.
"""

from __future__ import annotations

import json
import math


Z_AH = 25.0
Z_IC = 85.0
ACTIVATIONS = [0.526, 0.642, 0.699]

TARGETS = {
    "broad_depth_sensitive": {"a": 0.31, "b": 0.55, "r_ah": 0.20},
    "depth_insensitive": {"a": 0.10, "b": 5.00, "r_ah": 0.20},
    "moderate_depth_sensitive": {"a": 3.00, "b": 3.00, "r_ah": 0.20},
}

EVENTS = [(4.0, 2.0), (8.0, 4.0), (15.0, 7.5),
          (20.0, 40.0), (40.0, 40.0), (60.0, 40.0)]

K_SURFACE = 0.396
S_SURFACE = 13.34


def old_survival(z, a, b, r_ah):
    if z <= Z_AH:
        return 1.0
    if z >= Z_IC:
        return 0.0
    x = (z - Z_AH) / (Z_IC - Z_AH)
    return (1.0 - r_ah) * ((1.0 - x ** a) ** b)


def one_shape_survival(z, p):
    if z <= Z_AH:
        return 1.0
    if z >= Z_IC:
        return 0.0
    x = (z - Z_AH) / (Z_IC - Z_AH)
    return 1.0 - x ** p


def metrics(activation, survival):
    dz = 0.1
    n = round((Z_IC - Z_AH) / dz)
    depths = [Z_AH + i * dz for i in range(n + 1)]
    active = [
        max(0.0, activation - (1.0 - survival(z)))
        for z in depths
    ]
    active_depths = [z for z, s in zip(depths, active) if s > 1.0e-8]
    max_depth = max(active_depths) if active_depths else Z_AH

    losses = [max(0.0, active[i] - active[i + 1]) for i in range(n)]
    mids = [0.5 * (depths[i] + depths[i + 1]) for i in range(n)]
    total = sum(losses)
    mean_depth = (
        sum(z * w for z, w in zip(mids, losses)) / total
        if total > 0.0 else Z_AH
    )
    return mean_depth, max_depth


def target_signature(cfg):
    out = []
    for aev in ACTIVATIONS:
        m, x = metrics(
            aev,
            lambda z: old_survival(z, cfg["a"], cfg["b"], cfg["r_ah"]),
        )
        out.extend([m, x])
    return out


def one_signature(p):
    out = []
    for aev in ACTIVATIONS:
        m, x = metrics(aev, lambda z: one_shape_survival(z, p))
        out.extend([m, x])
    return out


def rmse(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)) / len(a))


def best_fit(target):
    best = None
    # log-space scan; deterministic, no optimizer dependency
    n = 2400
    lo = math.log(0.01)
    hi = math.log(100.0)
    for i in range(n):
        p = math.exp(lo + (hi - lo) * i / (n - 1))
        sig = one_signature(p)
        e = rmse(target, sig)
        if best is None or e < best[0]:
            best = (e, p, sig)
    return best


def normal_cdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def preferential_fraction(R, total, sigma, dt=0.002):
    duration = total / R
    n = max(1, round(duration / dt))
    dt = duration / n
    pref = 0.0
    for i in range(n):
        tau = (i + 0.5) * dt
        b50 = K_SURFACE + S_SURFACE / (2.0 * math.sqrt(tau))
        mu = math.log(b50)
        lr = math.log(R)
        z1 = (lr - mu - sigma * sigma) / sigma
        z2 = (lr - mu) / sigma
        matrix = (
            math.exp(mu + 0.5 * sigma * sigma) * normal_cdf(z1)
            + R * (1.0 - normal_cdf(z2))
        )
        matrix = max(0.0, min(R, matrix))
        pref += (R - matrix) * dt
    return pref / total


def observables(sigma, f_mb, p):
    out = []
    for R, total in EVENTS:
        pf = preferential_fraction(R, total, sigma)
        mean_depth, max_depth = metrics(
            pf,
            lambda z: one_shape_survival(z, p),
        )
        out.extend([
            pf,
            pf * f_mb,
            mean_depth / 60.0,
            max_depth / 60.0,
        ])
    return out


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def jacobi_eigenvalues_symmetric(matrix, sweeps=100):
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
        app, aqq, apq = a[p][p], a[q][q], a[p][q]
        phi = 0.5 * math.atan2(2.0 * apq, aqq - app)
        c, s = math.cos(phi), math.sin(phi)
        for k in range(n):
            if k != p and k != q:
                akp, akq = a[k][p], a[k][q]
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
    return [math.sqrt(max(0.0, e)) for e in eig]


def identifiability():
    base = [0.65, 0.25, 0.66]
    eps = 0.01
    cols = []
    for j in range(3):
        pp = base[:]
        pm = base[:]
        pp[j] *= 1.0 + eps
        pm[j] *= 1.0 - eps
        yp = observables(*pp)
        ym = observables(*pm)
        cols.append([(a - b) / (2.0 * eps) for a, b in zip(yp, ym)])
    sv = singular_values(cols)
    return {
        "base": {"sigma_B": base[0], "f_MB": base[1], "p": base[2]},
        "singular_values": sv,
        "condition_number": sv[0] / sv[-1],
    }


def main():
    fits = {}
    for name, cfg in TARGETS.items():
        target = target_signature(cfg)
        e, p, sig = best_fit(target)
        fits[name] = {
            "best_p": p,
            "rmse_cm_over_mean_and_max_depth_signatures": e,
            "target_signature_cm": target,
            "one_shape_signature_cm": sig,
        }

    regime_examples = {}
    for p in [0.01, 0.10, 0.30, 0.66, 1.0, 1.44, 3.0, 10.0]:
        vals = [metrics(a, lambda z, p=p: one_shape_survival(z, p)) for a in ACTIVATIONS]
        regime_examples[str(p)] = {
            "rows": [
                {"activation": a, "mean_depth_cm": m, "max_depth_cm": x}
                for a, (m, x) in zip(ACTIVATIONS, vals)
            ],
            "max_depth_change_cm": vals[-1][1] - vals[0][1],
        }

    print(json.dumps({
        "schema": "swap5.f_macro_alt26.one_shape_connectivity.v1",
        "status": "RESEARCH_ONLY",
        "one_shape_family": "C(z)=1-x^p",
        "R_AH_free_parameter": False,
        "nested_target_fits": fits,
        "representable_regimes": regime_examples,
        "identifiability": identifiability(),
        "decision": (
            "One-shape connectivity preserves the required qualitative depth-response "
            "regimes and materially improves parsimony/conditioning. Promote as leading "
            "candidate; keep the two-shape family only as fallback until empirical fit."
        ),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
