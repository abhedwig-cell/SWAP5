#!/usr/bin/env python3
"""F-MACRO-ALT55: conservative tracer forward-ledger contract.

Research-only. Standard library only.

This module composes already-owned contributions; it deliberately does not
invent matrix solute transport or MB wall-exchange physics.

Inputs:
- total applied tracer mass;
- preferential entry fraction (from frozen RFM activation);
- f_MB;
- p and sampling depth-bin edges for IC endpoint deposition;
- matrix retained tracer profile from a separate matrix-solute owner;
- optional MB wall-retained tracer profile from the wall-exchange owner;
- optional MB below-profile receipt.

The only hard requirement is exact tracer conservation.
"""

from __future__ import annotations
import json
import math
import sys


def endpoint_weights(edges, p):
    if p <= 0:
        raise ValueError("p must be positive")
    if len(edges) < 2 or abs(edges[0]) > 1e-12 or abs(edges[-1]-1.0) > 1e-12:
        raise ValueError("normalized edges must span 0..1")
    if any(b <= a for a, b in zip(edges, edges[1:])):
        raise ValueError("edges must be increasing")
    w = [b**p - a**p for a, b in zip(edges, edges[1:])]
    if abs(sum(w) - 1.0) > 1e-12:
        raise ValueError("endpoint weights do not close")
    return w


def _valid_profile(x, n):
    return isinstance(x, list) and len(x) == n and all(
        math.isfinite(v) and v >= 0.0 for v in x
    )


def route(
    applied_mass,
    preferential_fraction,
    f_mb,
    p,
    edges,
    matrix_profile,
    mb_wall_profile,
    mb_bottom_mass,
):
    if not math.isfinite(applied_mass) or applied_mass <= 0.0:
        raise ValueError("applied_mass must be positive")
    if not 0.0 <= preferential_fraction <= 1.0:
        raise ValueError("preferential_fraction outside [0,1]")
    if not 0.0 <= f_mb <= 1.0:
        raise ValueError("f_mb outside [0,1]")

    n = len(edges) - 1
    if not _valid_profile(matrix_profile, n):
        raise ValueError("invalid matrix_profile")
    if not _valid_profile(mb_wall_profile, n):
        raise ValueError("invalid mb_wall_profile")
    if not math.isfinite(mb_bottom_mass) or mb_bottom_mass < 0.0:
        raise ValueError("invalid mb_bottom_mass")

    pref_mass = applied_mass * preferential_fraction
    matrix_source = applied_mass - pref_mass
    mb_source = pref_mass * f_mb
    ic_source = pref_mass - mb_source

    matrix_retained = sum(matrix_profile)
    if abs(matrix_retained - matrix_source) > 1e-10 * max(1.0, applied_mass):
        raise ValueError(
            "matrix profile must be supplied by an owner that closes the matrix source mass"
        )

    weights = endpoint_weights(edges, p)
    ic_profile = [ic_source * w for w in weights]

    mb_wall_retained = sum(mb_wall_profile)
    if abs(mb_wall_retained + mb_bottom_mass - mb_source) > 1e-10 * max(1.0, applied_mass):
        raise ValueError(
            "MB wall-retained profile + bottom receipt must close the MB source mass"
        )

    observed_profile = [
        matrix_profile[i] + ic_profile[i] + mb_wall_profile[i]
        for i in range(n)
    ]

    ledger = {
        "applied": applied_mass,
        "matrix_source": matrix_source,
        "preferential_source": pref_mass,
        "ic_source": ic_source,
        "mb_source": mb_source,
        "matrix_retained": matrix_retained,
        "ic_retained": sum(ic_profile),
        "mb_wall_retained": mb_wall_retained,
        "mb_bottom": mb_bottom_mass,
        "sampled_profile_mass": sum(observed_profile),
    }
    residual = (
        ledger["applied"]
        - ledger["matrix_retained"]
        - ledger["ic_retained"]
        - ledger["mb_wall_retained"]
        - ledger["mb_bottom"]
    )
    ledger["residual"] = residual

    if abs(residual) > 1e-10 * max(1.0, applied_mass):
        raise ValueError("tracer ledger does not close")

    return {
        "observed_profile": observed_profile,
        "matrix_profile": matrix_profile,
        "ic_profile": ic_profile,
        "mb_wall_profile": mb_wall_profile,
        "ledger": ledger,
    }


def demonstration():
    edges = [i / 10 for i in range(11)]
    applied = 1.0
    pref = 0.4
    fmb = 0.1
    p = 0.25

    # These two external-owner profiles are illustrative contract fixtures only.
    matrix_source = applied * (1-pref)
    matrix_profile = [matrix_source] + [0.0]*9

    mb_source = applied*pref*fmb
    mb_bottom = 0.01
    mb_wall_total = mb_source-mb_bottom
    mb_wall_profile = [0.0]*9 + [mb_wall_total]

    return route(
        applied, pref, fmb, p, edges,
        matrix_profile, mb_wall_profile, mb_bottom
    )


if __name__ == "__main__":
    print(json.dumps({
        "schema":"swap5.f_macro_alt55.tracer_forward_ledger.v1",
        "status":"RESEARCH_ONLY",
        "demo":demonstration(),
        "decision":"The composition contract closes tracer mass exactly and forces matrix and MB wall-exchange owners to provide explicit mass-closing contributions."
    }, indent=2, sort_keys=True))
