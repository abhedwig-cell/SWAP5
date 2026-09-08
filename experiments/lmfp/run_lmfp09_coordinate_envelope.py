from __future__ import annotations

import bisect
import json
import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp02_testbench import B110Material, adaptive_simpson

HMIN = -1.0e8
HMAX = 100.0
G_POINTS = 27  # F-LMFP08 gradient-axis cardinality, used only for memory projection.


@dataclass(frozen=True)
class MaterialFixture:
    name: str
    material: B110Material


def make_material(theta_r, theta_s, ks, alpha, lamb, n):
    vals = [0.0] * 24
    vals[0] = theta_r
    vals[1] = theta_s
    vals[2] = ks
    vals[3] = alpha
    vals[4] = lamb
    vals[5] = n
    vals[6] = 1.0 - 1.0 / n
    vals[7] = alpha
    vals[8] = 0.0
    vals[9] = ks
    vals[10] = 0.999
    vals[11] = 0.99 * ks
    vals[21] = -1.0e8
    vals[22] = 1.0e-12
    return B110Material.from_input(vals)


# Synthetic hydraulic stress fixtures, not named soil classes and not a production catalog.
FIXTURES = [
    MaterialFixture("very_fast", make_material(0.030, 0.400, 100.0, 0.080, 0.50, 2.20)),
    MaterialFixture("reference_sand", make_material(0.045, 0.430, 20.0, 0.040, 0.50, 1.80)),
    MaterialFixture("intermediate", make_material(0.060, 0.460, 2.0, 0.020, 0.50, 1.55)),
    MaterialFixture("reference_clay", make_material(0.080, 0.500, 0.20, 0.010, 0.50, 1.30)),
    MaterialFixture("slow_heavy", make_material(0.100, 0.520, 0.020, 0.005, 0.50, 1.20)),
]


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values) - 1, int(p * len(values)))]


def relerr(a, b, floor=1.0e-12):
    return abs(a - b) / max(abs(b), floor)


def integrate_k(mat, a, b):
    """Reference integral split at hydraulic transition scales for robustness."""
    if a == b:
        return 0.0
    sign = 1.0
    if b < a:
        a, b = b, a
        sign = -1.0
    cuts = [a]
    for x in (-1.0e6, -1.0e4, -1.0e2, -1.0, -1.0e-2, 0.0):
        if a < x < b:
            cuts.append(x)
    cuts.append(b)
    total = 0.0
    for x0, x1 in zip(cuts[:-1], cuts[1:]):
        v, _ = adaptive_simpson(mat.conductivity, x0, x1, atol=1.0e-12, rtol=2.0e-10,
                                max_depth=24)
        total += v
    return sign * total


class AsinhCoordinate:
    def __init__(self, hscale, hmin=HMIN, hmax=HMAX):
        if hscale <= 0.0 or not hmin < 0.0 < hmax:
            raise ValueError("invalid coordinate parameters")
        self.hscale = float(hscale)
        self.hmin = float(hmin)
        self.hmax = float(hmax)
        self.xmin = self.x(hmin)
        self.xmax = self.x(hmax)

    def x(self, h):
        return math.asinh(h / self.hscale)

    def h(self, x):
        return self.hscale * math.sinh(x)

    def dxdh(self, h):
        return 1.0 / math.sqrt(h * h + self.hscale * self.hscale)


class AsinhMFPTable:
    """Experimental MFP potential table with a coordinate regular through h=0.

    For h>=0 the constitutive fixture is saturated and Phi is extended analytically
    with slope Ks. The negative-pressure table therefore never needs to fake a
    saturated derivative by extrapolation.
    """

    def __init__(self, mat, coordinate, n):
        if n < 4:
            raise ValueError("at least four nodes required")
        self.mat = mat
        self.coordinate = coordinate
        self.n = int(n)
        self.x0 = coordinate.x(0.0)
        self.xs = [coordinate.xmin + (self.x0 - coordinate.xmin) * i / (n - 1)
                   for i in range(n)]
        self.heads = [coordinate.h(x) for x in self.xs]
        self.heads[-1] = 0.0
        self.phi = [0.0]
        for a, b in zip(self.heads[:-1], self.heads[1:]):
            self.phi.append(self.phi[-1] + integrate_k(mat, a, b))
        self.phi0 = self.phi[-1]
        self.ks = mat.conductivity(0.0)

    def value(self, h):
        if h < self.coordinate.hmin or h > self.coordinate.hmax:
            raise ValueError(("head_out_of_range", h, self.coordinate.hmin,
                              self.coordinate.hmax))
        if h >= 0.0:
            return self.phi0 + self.ks * h
        x = self.coordinate.x(h)
        i = bisect.bisect_right(self.xs, x) - 1
        i = max(0, min(i, self.n - 2))
        x0, x1 = self.xs[i], self.xs[i + 1]
        f = (x - x0) / (x1 - x0)
        return self.phi[i] + f * (self.phi[i + 1] - self.phi[i])

    def limit_k(self, h):
        if h < self.coordinate.hmin or h > self.coordinate.hmax:
            raise ValueError(("head_out_of_range", h, self.coordinate.hmin,
                              self.coordinate.hmax))
        if h >= 0.0:
            return self.ks
        x = self.coordinate.x(h)
        i = bisect.bisect_right(self.xs, x) - 1
        i = max(0, min(i, self.n - 2))
        slope_x = (self.phi[i + 1] - self.phi[i]) / (self.xs[i + 1] - self.xs[i])
        return slope_x * self.coordinate.dxdh(h)

    def secant_k(self, h1, h2):
        scale = max(1.0, abs(h1), abs(h2))
        if abs(h1 - h2) <= 1.0e-14 * scale:
            return self.limit_k(0.5 * (h1 + h2))
        return (self.value(h1) - self.value(h2)) / (h1 - h2)


CANDIDATES = [
    (0.01, 48), (0.01, 64), (0.01, 96),
    (0.10, 48), (0.10, 64), (0.10, 96),
    (1.00, 48), (1.00, 64), (1.00, 96),
    (10.0, 48), (10.0, 64), (10.0, 96),
]


def probe_pairs(seed=4310901):
    rng = random.Random(seed)
    pairs = []
    # Deterministic regime probes around saturation, the H_CRIT scale and the dry tail.
    fixed = [
        (-1.0e8, -1.0e7), (-1.0e7, -1.0e6), (-1.0e6, -1.0e5),
        (-1.0e5, -1.0e4), (-1.0e4, -1.0e3), (-1.0e3, -100.0),
        (-100.0, -10.0), (-10.0, -1.0), (-1.0, -0.1),
        (-0.1, -0.01), (-0.01, -0.001), (-0.001, -0.0001),
        (-0.1, 0.0), (-0.01, 0.01), (-1.0, 1.0), (0.0, 1.0),
        (1.0, 10.0), (10.0, 100.0),
    ]
    pairs.extend(fixed)
    # Random pairs are sampled uniformly in an asinh coordinate so both tails and
    # the near-zero region receive material representation.
    ref = AsinhCoordinate(0.1)
    for _ in range(180):
        xa = rng.uniform(ref.xmin, ref.xmax)
        xb = rng.uniform(ref.xmin, ref.xmax)
        a, b = ref.h(xa), ref.h(xb)
        if abs(a - b) < 1.0e-8 * max(1.0, abs(a), abs(b)):
            b = min(HMAX, b + 0.01)
        pairs.append((a, b))
    return pairs


def near_equal_heads():
    return [-1.0e7, -1.0e5, -1.0e3, -100.0, -10.0, -1.0, -0.1,
            -0.01, -0.003, -0.001, -0.0001, 0.0, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0]


def evaluate_candidate(hscale, n, reference_pairs):
    coord = AsinhCoordinate(hscale)
    tables = {f.name: AsinhMFPTable(f.material, coord, n) for f in FIXTURES}

    # Coordinate round-trip and endpoint monotonicity.
    test_heads = [HMIN, -1.0e6, -1.0e3, -1.0, -0.01, -1.0e-6,
                  0.0, 1.0e-6, 0.01, 1.0, 100.0]
    roundtrip = [abs(coord.h(coord.x(h)) - h) / max(1.0, abs(h)) for h in test_heads]

    secant_errors = []
    derivative_errors = []
    zero_rows = []
    finite = True
    for fixture in FIXTURES:
        mat = fixture.material
        tab = tables[fixture.name]
        for (a, b), refk in reference_pairs[fixture.name]:
            try:
                kt = tab.secant_k(a, b)
                e = relerr(kt, refk, 1.0e-12)
            except Exception:
                finite = False
                e = math.inf
            secant_errors.append(e)

        for h in near_equal_heads():
            try:
                kd = tab.limit_k(h)
                ke = mat.conductivity(h)
                derivative_errors.append(relerr(kd, ke, 1.0e-12))
            except Exception:
                finite = False
                derivative_errors.append(math.inf)

        # Refinement around h=0 for Phi and the limiting secant conductance.
        for eps_large, eps_small in ((1.0e-2, 2.0e-3), (1.0e-3, 2.0e-4)):
            p0 = tab.value(0.0)
            large = max(abs(tab.value(-eps_large) - p0),
                        abs(tab.value(eps_large) - p0))
            small = max(abs(tab.value(-eps_small) - p0),
                        abs(tab.value(eps_small) - p0))
            ratio = small / max(large, 1.0e-300)
            zero_rows.append({
                "material": fixture.name,
                "eps_large": eps_large,
                "eps_small": eps_small,
                "epsilon_ratio": eps_small / eps_large,
                "phi_small_over_large": ratio,
                "k_minus": tab.limit_k(-eps_small),
                "k_zero": tab.limit_k(0.0),
                "k_plus": tab.limit_k(eps_small),
            })
            finite = finite and all(math.isfinite(v) for v in
                                    (large, small, ratio, zero_rows[-1]["k_minus"],
                                     zero_rows[-1]["k_zero"], zero_rows[-1]["k_plus"]))

    max_zero_ratio = max(r["phi_small_over_large"] for r in zero_rows)
    max_roundtrip = max(roundtrip)
    stats = {
        "hscale_cm": hscale,
        "negative_head_nodes": n,
        "projected_R_values_per_material_geometry_class": n * G_POINTS,
        "projected_R_bytes_per_class_before_metadata": n * G_POINTS * 8,
        "coordinate_roundtrip_max_rel_or_scaled_abs": max_roundtrip,
        "mfp_secant_rel_error": {
            "median": percentile(secant_errors, 0.50),
            "p90": percentile(secant_errors, 0.90),
            "p99": percentile(secant_errors, 0.99),
            "maximum": max(secant_errors),
        },
        "limit_k_rel_error": {
            "median": percentile(derivative_errors, 0.50),
            "p90": percentile(derivative_errors, 0.90),
            "maximum": max(derivative_errors),
        },
        "zero_continuity": {
            "maximum_phi_small_over_large": max_zero_ratio,
            "expected_refinement_ratio": 0.2,
            "rows": zero_rows,
        },
        "finite": finite,
    }

    # Gate A is deliberately stricter on the secant than on the point derivative:
    # the final equal-head manifold is analytically reconciled as in F-LMFP08,
    # while finite MFP secants drive the actual baseline away from that manifold.
    stats["pass"] = (
        finite
        and max_roundtrip < 1.0e-11
        and stats["mfp_secant_rel_error"]["p90"] < 0.01
        and stats["mfp_secant_rel_error"]["p99"] < 0.08
        and stats["mfp_secant_rel_error"]["maximum"] < 0.25
        and stats["limit_k_rel_error"]["p90"] < 0.10
        and stats["limit_k_rel_error"]["maximum"] < 0.35
        and max_zero_ratio < 0.35
    )
    return stats


def fail_closed_tests(candidate):
    coord = AsinhCoordinate(candidate["hscale_cm"])
    tab = AsinhMFPTable(FIXTURES[0].material, coord, candidate["negative_head_nodes"])
    rows = []
    for h in (HMIN - 1.0, HMAX + 1.0):
        failed = False
        try:
            tab.value(h)
        except ValueError:
            failed = True
        rows.append({"head": h, "explicit_failure": failed})
    return {"pass": all(r["explicit_failure"] for r in rows), "rows": rows}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_coordinate_envelope.py EVIDENCE_JSON")

    pairs = probe_pairs()
    # Compute independent reference secant conductances only once.
    reference_pairs = {}
    for fixture in FIXTURES:
        rows = []
        for a, b in pairs:
            integ = integrate_k(fixture.material, b, a)
            refk = integ / (a - b)
            if not math.isfinite(refk) or refk <= 0.0:
                raise RuntimeError(("bad_reference_secant", fixture.name, a, b, refk))
            rows.append(((a, b), refk))
        reference_pairs[fixture.name] = rows

    candidates = [evaluate_candidate(hscale, n, reference_pairs)
                  for hscale, n in CANDIDATES]
    passing = [c for c in candidates if c["pass"]]
    # Prefer the smallest correction-table footprint; break ties by secant p90 then max.
    passing.sort(key=lambda c: (c["projected_R_bytes_per_class_before_metadata"],
                                c["mfp_secant_rel_error"]["p90"],
                                c["mfp_secant_rel_error"]["maximum"],
                                c["hscale_cm"]))
    selected = passing[0] if passing else None
    fail_closed = fail_closed_tests(selected) if selected else {"pass": False, "rows": []}

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "A_COORDINATE_AND_ENVELOPE",
        "head_envelope_cm": [HMIN, HMAX],
        "coordinate_family": "x=asinh(h/hscale)",
        "materials": [f.name for f in FIXTURES],
        "materials_are": "synthetic hydraulic stress fixtures, not a production soil catalog",
        "reference": "piecewise adaptive integration of the constitutive K(h)",
        "pair_cases_per_material": len(pairs),
        "candidate_count": len(candidates),
        "candidates": candidates,
        "selected": selected,
        "fail_closed": fail_closed,
        "structural_pass": selected is not None and fail_closed["pass"],
        "interpretation": {
            "production_admission": "none",
            "darcian_correction_admission": "none in this gate; F-LMFP08 representation is not yet rebuilt on the selected coordinate",
            "heterogeneous_interface_admission": "none",
            "response_tangent_admission": "none",
            "next_gate": "B_HOMOGENEOUS_FACE_MATRIX_REBUILD_FLMFP08_CORRECTION_ON_SELECTED_COORDINATE",
        },
    }
    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["structural_pass"] else 1)


if __name__ == "__main__":
    main()
