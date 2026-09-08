from __future__ import annotations

import bisect
import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp08_physics_informed_correction as f08
from run_lmfp06_darcian_reference import solve_steady_flux
from run_lmfp09_coordinate_envelope import (
    AsinhCoordinate,
    AsinhMFPTable,
    FIXTURES,
)

H_SCALE = 0.01
MFP_N = 128
MFP_HMIN = -1.0e8
MFP_HMAX = 1000.0
R_HMIN = -1.0e6
R_HMAX = 100.0
LENGTHS = (10.0, 20.0)
MASTER_NX = 65
VIEW_NX = (17, 33, 65)
G_AXIS = list(f08.G_AXIS)

FIXTURE_BY_NAME = {f.name: f for f in FIXTURES}
ACTIVE = [FIXTURE_BY_NAME["reference_sand"], FIXTURE_BY_NAME["reference_clay"]]


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values) - 1, int(p * len(values)))]


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis) - 2, len(axis) - 1
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


def g0_hat(g):
    j = G_AXIS.index(0.0)
    gl = G_AXIS[j - 1]
    gr = G_AXIS[j + 1]
    if gl <= g <= 0.0:
        return (g - gl) / (0.0 - gl)
    if 0.0 <= g <= gr:
        return (gr - g) / (gr - 0.0)
    return 0.0


def direct_flux(mat, h_u, h_l, length):
    return solve_steady_flux(mat, mat, h_u, h_l, 0.5 * length, 0.5 * length)[0]


def oracle_kdar(mat, h_u, g, length):
    if abs(g) <= 1.0e-14:
        return mat.conductivity(h_u), 0

    def at(gg):
        h_l = h_u + gg * length
        q = direct_flux(mat, h_u, h_l, length)
        grad = 1.0 - gg
        if abs(grad) < 1.0e-14:
            raise ZeroDivisionError(gg)
        k = q / grad
        if not math.isfinite(k) or k <= 0.0:
            raise RuntimeError(("nonpositive_kdar", h_u, gg, length, q, k))
        return k

    if abs(g - 1.0) <= 1.0e-14:
        eps = 2.0e-3
        km = at(1.0 - eps)
        kp = at(1.0 + eps)
        return math.exp(0.5 * (math.log(km) + math.log(kp))), 2
    return at(g), 1


class RatioMaster:
    """Fine offline oracle grid reused by nested runtime-density views."""

    def __init__(self, fixture, length, mfp_table):
        self.fixture = fixture
        self.mat = fixture.material
        self.length = float(length)
        self.mfp = mfp_table
        self.coordinate = AsinhCoordinate(H_SCALE, hmin=R_HMIN, hmax=R_HMAX)
        self.x_axis = [self.coordinate.xmin +
                       (self.coordinate.xmax - self.coordinate.xmin) * i / (MASTER_NX - 1)
                       for i in range(MASTER_NX)]
        self.h_axis = [self.coordinate.h(x) for x in self.x_axis]
        self.values = []
        self.oracle_solves = 0
        for h_u in self.h_axis:
            row = []
            for g in G_AXIS:
                h_l = h_u + g * self.length
                if h_l < MFP_HMIN or h_l > MFP_HMAX:
                    raise RuntimeError(("master_face_outside_mfp_envelope", h_u, h_l, g,
                                        self.length, MFP_HMIN, MFP_HMAX))
                kd, calls = oracle_kdar(self.mat, h_u, g, self.length)
                self.oracle_solves += calls
                kb = self.mfp.secant_k(h_u, h_l)
                if not math.isfinite(kb) or kb <= 0.0:
                    raise RuntimeError(("nonpositive_mfp_secant", h_u, h_l, kb))
                ratio = kd / kb
                if not math.isfinite(ratio) or ratio <= 0.0:
                    raise RuntimeError(("nonpositive_ratio", h_u, g, kd, kb, ratio))
                row.append(math.log(ratio))
            self.values.append(row)


class RatioView:
    def __init__(self, master, nx):
        if nx not in VIEW_NX:
            raise ValueError(nx)
        step = (MASTER_NX - 1) // (nx - 1)
        if step * (nx - 1) != MASTER_NX - 1:
            raise ValueError(("view_not_nested", nx, MASTER_NX))
        self.master = master
        self.fixture = master.fixture
        self.mat = master.mat
        self.length = master.length
        self.mfp = master.mfp
        self.nx = nx
        self.indices = list(range(0, MASTER_NX, step))
        self.x_axis = [master.x_axis[i] for i in self.indices]
        self.values = [master.values[i] for i in self.indices]

    def raw_log_ratio(self, h_u, g):
        if h_u < R_HMIN or h_u > R_HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u, R_HMIN, R_HMAX))
        if g < G_AXIS[0] or g > G_AXIS[-1]:
            raise ValueError(("gradient_out_of_ratio_envelope", g, G_AXIS[0], G_AXIS[-1]))
        x = self.master.coordinate.x(h_u)
        i0, i1 = bracket(self.x_axis, x)
        j0, j1 = bracket(G_AXIS, g)
        x0, x1 = self.x_axis[i0], self.x_axis[i1]
        g0, g1 = G_AXIS[j0], G_AXIS[j1]
        tx = 0.0 if x1 == x0 else (x - x0) / (x1 - x0)
        tg = 0.0 if g1 == g0 else (g - g0) / (g1 - g0)
        a00 = self.values[i0][j0]
        a10 = self.values[i1][j0]
        a11 = self.values[i1][j1]
        a01 = self.values[i0][j1]
        return ((1 - tx) * (1 - tg) * a00 + tx * (1 - tg) * a10 +
                tx * tg * a11 + (1 - tx) * tg * a01)

    def log_ratio(self, h_u, g):
        raw = self.raw_log_ratio(h_u, g)
        w = g0_hat(g)
        if w == 0.0:
            return raw
        k_exact = self.mat.conductivity(h_u)
        k_lim = self.mfp.limit_k(h_u)
        r0_exact = math.log(k_exact / k_lim)
        r0_interp = self.raw_log_ratio(h_u, 0.0)
        return raw + w * (r0_exact - r0_interp)

    def flux(self, h_u, h_l):
        g = (h_l - h_u) / self.length
        if h_l < MFP_HMIN or h_l > MFP_HMAX:
            raise ValueError(("lower_head_out_of_mfp_envelope", h_l, MFP_HMIN, MFP_HMAX))
        kbase = self.mfp.secant_k(h_u, h_l)
        qbase = kbase * (1.0 - g)
        return qbase * math.exp(self.log_ratio(h_u, g))

    def memory(self):
        n = self.nx * len(G_AXIS)
        return {"values": n, "bytes_before_metadata": n * 8}


def build_probe_rows(fixture, length, seed):
    mat = fixture.material
    rng = random.Random(seed)
    fixed_h = [-1.0e6, -1.0e5, -1.0e4, -1.0e3, -100.0, -10.0, -1.0,
               -0.1, -0.01, -0.001, 0.0, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0]
    fixed_g = [-20.0, -5.0, -1.0, 0.0, 0.5, 1.0, 2.0, 5.0, 20.0]
    probes = [(h, g) for h in fixed_h for g in fixed_g]
    coord = AsinhCoordinate(H_SCALE, hmin=R_HMIN, hmax=R_HMAX)
    for _ in range(120):
        h = coord.h(rng.uniform(coord.xmin, coord.xmax))
        if rng.random() < 0.5:
            g = rng.uniform(-6.0, 8.0)
        else:
            g = rng.uniform(-24.0, 24.0)
        probes.append((h, g))

    rows = []
    for h_u, g in probes:
        h_l = h_u + g * length
        if h_l < MFP_HMIN or h_l > MFP_HMAX:
            continue
        qd = direct_flux(mat, h_u, h_l, length)
        rows.append({
            "h_u": h_u,
            "h_l": h_l,
            "g": g,
            "q_ref": qd,
            "active_floor": 1.0e-8 * max(mat.conductivity(0.0), 1.0),
            "strong_gradient": abs(g) >= 5.0,
            "near_saturation": max(abs(h_u), abs(h_l)) <= 10.0,
        })
    return rows


def identity_test(view):
    max_equal = 0.0
    max_hydro = 0.0
    rows = []
    for h in (-1.0e6, -1.0e3, -100.0, -1.0, -0.01, -0.001,
              0.0, 0.001, 0.01, 1.0, 10.0, 100.0):
        q = view.flux(h, h)
        expected = view.mat.conductivity(h)
        max_equal = max(max_equal, abs(q - expected))
        rows.append({"kind": "equal_head", "h": h, "q": q, "expected": expected,
                     "abs_error": abs(q - expected)})
        h_l = h + view.length
        if h_l <= MFP_HMAX:
            q0 = view.flux(h, h_l)
            max_hydro = max(max_hydro, abs(q0))
            rows.append({"kind": "hydrostatic", "h_u": h, "h_l": h_l,
                         "q": q0, "abs_error": abs(q0)})
    return {"pass": max_equal < 2.0e-10 and max_hydro < 2.0e-10,
            "max_equal_head_abs_error": max_equal,
            "max_hydrostatic_abs_flux": max_hydro,
            "rows": rows}


def continuity_test(view):
    ratios = []
    finite = True
    rows = []
    eps_large = 1.0e-3
    eps_small = 2.0e-4
    for h in (-1.0e5, -100.0, -1.0, -0.01, -0.001, 0.0, 0.001, 0.01, 1.0, 10.0, 100.0):
        for g0 in (0.0, 1.0):
            def q(g):
                return view.flux(h, h + g * view.length)
            q0 = q(g0)
            large = max(abs(q(g0 - eps_large) - q0), abs(q(g0 + eps_large) - q0))
            small = max(abs(q(g0 - eps_small) - q0), abs(q(g0 + eps_small) - q0))
            ratio = 0.0 if large < 1.0e-14 and small < 1.0e-14 else small / max(large, 1.0e-300)
            finite = finite and math.isfinite(ratio)
            ratios.append(ratio)
            rows.append({"h_u": h, "g": g0, "small_over_large": ratio,
                         "epsilon_ratio": eps_small / eps_large})
    maximum = max(ratios)
    return {"pass": finite and maximum <= 0.35, "finite": finite,
            "epsilon_ratio": eps_small / eps_large,
            "maximum_small_over_large": maximum, "threshold": 0.35,
            "rows": rows}


def fail_closed_test(view):
    trials = [
        (R_HMIN - 1.0, R_HMIN - 1.0),
        (R_HMAX + 1.0, R_HMAX + 1.0),
        (-10.0, -10.0 + (G_AXIS[0] - 0.1) * view.length),
        (-10.0, -10.0 + (G_AXIS[-1] + 0.1) * view.length),
        (100.0, MFP_HMAX + 1.0),
    ]
    rows = []
    for h_u, h_l in trials:
        failed = False
        try:
            view.flux(h_u, h_l)
        except ValueError:
            failed = True
        rows.append({"h_u": h_u, "h_l": h_l, "explicit_failure": failed})
    return {"pass": all(r["explicit_failure"] for r in rows), "rows": rows}


def metrics_for_view(view, probe_rows):
    active_corr = []
    active_mfp = []
    strong_corr = []
    near_corr = []
    dormant_scaled_abs = []
    sign_mismatch = 0
    failures = 0
    informative = 0
    corrected_better = 0
    rows = []
    ks_scale = max(view.mat.conductivity(0.0), 1.0)
    for row in probe_rows:
        h_u, h_l, qd = row["h_u"], row["h_l"], row["q_ref"]
        try:
            qc = view.flux(h_u, h_l)
            g = row["g"]
            qm = view.mfp.secant_k(h_u, h_l) * (1.0 - g)
        except Exception as exc:
            failures += 1
            rows.append({**row, "failed": True, "error": type(exc).__name__ + ":" + str(exc)})
            continue
        floor = row["active_floor"]
        if abs(qd) >= floor:
            ec = abs(qc - qd) / abs(qd)
            em = abs(qm - qd) / abs(qd)
            active_corr.append(ec)
            active_mfp.append(em)
            if row["strong_gradient"]:
                strong_corr.append(ec)
            if row["near_saturation"]:
                near_corr.append(ec)
            if qc * qd < 0.0:
                sign_mismatch += 1
            if em > 1.0e-5:
                informative += 1
                if ec < em:
                    corrected_better += 1
        else:
            ec = abs(qc - qd) / ks_scale
            em = abs(qm - qd) / ks_scale
            dormant_scaled_abs.append(ec)
        rows.append({**row, "q_corrected": qc, "q_mfp": qm,
                     "corrected_error": ec, "mfp_error": em})

    corrected = {"median": percentile(active_corr, 0.50),
                 "p90": percentile(active_corr, 0.90),
                 "p99": percentile(active_corr, 0.99),
                 "maximum": max(active_corr) if active_corr else math.inf}
    mfp = {"median": percentile(active_mfp, 0.50),
           "p90": percentile(active_mfp, 0.90),
           "p99": percentile(active_mfp, 0.99),
           "maximum": max(active_mfp) if active_mfp else math.inf}
    strong_p90 = percentile(strong_corr, 0.90)
    near_p90 = percentile(near_corr, 0.90)
    dormant_max = max(dormant_scaled_abs) if dormant_scaled_abs else 0.0
    better_fraction = corrected_better / informative if informative else 1.0

    passed = (
        failures == 0
        and sign_mismatch == 0
        and corrected["p90"] < 0.02
        and corrected["p99"] < 0.10
        and corrected["maximum"] < 0.30
        and strong_p90 < 0.02
        and near_p90 < 0.02
        and dormant_max < 1.0e-7
        and corrected["p90"] < mfp["p90"]
        and better_fraction >= 0.75
    )
    return {
        "pass": passed,
        "cases": len(probe_rows),
        "failures": failures,
        "sign_mismatches": sign_mismatch,
        "active_cases": len(active_corr),
        "dormant_cases": len(dormant_scaled_abs),
        "corrected_active_rel_error": corrected,
        "mfp_active_rel_error": mfp,
        "strong_gradient_corrected_p90_rel_error": strong_p90,
        "near_saturation_corrected_p90_rel_error": near_p90,
        "dormant_max_abs_error_over_ks_scale": dormant_max,
        "informative_mfp_cases": informative,
        "fraction_corrected_better_on_informative_cases": better_fraction,
        "rows": rows,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_homogeneous_face_matrix.py EVIDENCE_JSON")

    mfp_coord = AsinhCoordinate(H_SCALE, hmin=MFP_HMIN, hmax=MFP_HMAX)
    mfp_tables = {f.name: AsinhMFPTable(f.material, mfp_coord, MFP_N) for f in ACTIVE}

    masters = {}
    total_oracle_solves = 0
    for fixture in ACTIVE:
        for length in LENGTHS:
            master = RatioMaster(fixture, length, mfp_tables[fixture.name])
            masters[(fixture.name, length)] = master
            total_oracle_solves += master.oracle_solves

    probes = {}
    for fi, fixture in enumerate(ACTIVE):
        for li, length in enumerate(LENGTHS):
            probes[(fixture.name, length)] = build_probe_rows(
                fixture, length, 431090100 + 100 * fi + li)

    candidates = []
    for nx in VIEW_NX:
        class_results = []
        all_pass = True
        for fixture in ACTIVE:
            for length in LENGTHS:
                view = RatioView(masters[(fixture.name, length)], nx)
                identity = identity_test(view)
                continuity = continuity_test(view)
                fail_closed = fail_closed_test(view)
                face = metrics_for_view(view, probes[(fixture.name, length)])
                class_pass = identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"]
                all_pass = all_pass and class_pass
                class_results.append({
                    "material": fixture.name,
                    "length_cm": length,
                    "pass": class_pass,
                    "memory": view.memory(),
                    "identity": identity,
                    "continuity": continuity,
                    "fail_closed": fail_closed,
                    "face_matrix": face,
                })
        candidates.append({
            "ratio_head_nodes": nx,
            "values_per_material_geometry_class": nx * len(G_AXIS),
            "bytes_per_material_geometry_class_before_metadata": nx * len(G_AXIS) * 8,
            "pass": all_pass,
            "classes": class_results,
        })

    passing = [c for c in candidates if c["pass"]]
    passing.sort(key=lambda c: c["bytes_per_material_geometry_class_before_metadata"])
    selected = passing[0] if passing else None

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "B1_EXPANDED_HOMOGENEOUS_FACE_MATRIX",
        "mfp_material_table": {
            "coordinate": "x=asinh(h/0.01 cm)",
            "negative_head_nodes": MFP_N,
            "head_envelope_cm": [MFP_HMIN, MFP_HMAX],
            "ownership": "immutable shared per hydraulic material",
        },
        "darcian_ratio_master": {
            "ratio_upper_head_envelope_cm": [R_HMIN, R_HMAX],
            "gradient_envelope": [G_AXIS[0], G_AXIS[-1]],
            "master_head_nodes": MASTER_NX,
            "gradient_nodes": len(G_AXIS),
            "materials": [f.name for f in ACTIVE],
            "face_lengths_cm": list(LENGTHS),
            "offline_oracle_solves": total_oracle_solves,
            "runtime_oracle_calls": 0,
        },
        "candidate_ratio_head_nodes": list(VIEW_NX),
        "candidates": candidates,
        "selected": selected,
        "structural_pass": selected is not None,
        "interpretation": {
            "production_admission": "none",
            "material_catalog_admission": "none; only the two F-LMFP08 reference hydraulic fixtures are used in B1",
            "positive_pressure_head_admission": "experimental homogeneous-face evidence only",
            "dry_tail_admission": "B1 ratio upper-head envelope extends to -1e6 cm; deeper Gate-A MFP tail is not yet a corrected-face admission",
            "heterogeneous_interface_admission": "none",
            "response_tangent_admission": "none",
            "next_gate_if_pass": "B2 expanded materials/geometry classes or C heterogeneous interface, depending selected density and offline cost",
        },
    }
    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["structural_pass"] else 1)


if __name__ == "__main__":
    main()
