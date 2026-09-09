from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_corrected_interface as gatec
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable

AXIS_N = 33
ZERO_LEFT_G = -0.5
ZERO_RIGHT_G = 0.25


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x >= axis[-1]:
        return len(axis) - 2, len(axis) - 1
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


def zero_identity_weight(g):
    if ZERO_LEFT_G <= g <= 0.0:
        return (g - ZERO_LEFT_G) / (-ZERO_LEFT_G)
    if 0.0 <= g <= ZERO_RIGHT_G:
        return (ZERO_RIGHT_G - g) / ZERO_RIGHT_G
    return 0.0


class EndpointPairRatioView:
    def __init__(self, fixture, length):
        self.fixture = fixture
        self.mat = fixture.material
        self.length = float(length)
        mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
        self.mfp = HermiteMFPTable(self.mat, mfp_coord, core.MFP_N)
        self.coordinate = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
        base = [
            self.coordinate.xmin
            + (self.coordinate.xmax - self.coordinate.xmin) * i / (AXIS_N - 1)
            for i in range(AXIS_N)
        ]
        self.x_axis = sorted(set(base + [0.0]))
        self.h_axis = [0.0 if x == 0.0 else self.coordinate.h(x) for x in self.x_axis]
        self.nx = len(self.x_axis)
        self.values = []
        self.oracle_solves = 0
        for h_u in self.h_axis:
            row = []
            for h_l in self.h_axis:
                g = (h_l - h_u) / self.length
                kd, calls = core.oracle_kdar(self.mat, h_u, g, self.length)
                self.oracle_solves += calls
                kb = self.mfp.secant_k(h_u, h_l)
                if not (math.isfinite(kd) and kd > 0.0 and math.isfinite(kb) and kb > 0.0):
                    raise RuntimeError(("nonpositive_endpoint_pair_conductivity", h_u, h_l, kd, kb))
                ratio = kd / kb
                if not (math.isfinite(ratio) and ratio > 0.0):
                    raise RuntimeError(("nonpositive_endpoint_pair_ratio", h_u, h_l, ratio))
                row.append(math.log(ratio))
            self.values.append(row)

    def raw_log_ratio(self, h_u, h_l):
        if h_u < core.R_HMIN or h_u > core.R_HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u, core.R_HMIN, core.R_HMAX))
        if h_l < core.R_HMIN or h_l > core.R_HMAX:
            raise ValueError(("lower_head_out_of_ratio_envelope", h_l, core.R_HMIN, core.R_HMAX))
        xu = self.coordinate.x(h_u)
        xl = self.coordinate.x(h_l)
        i0, i1 = bracket(self.x_axis, xu)
        j0, j1 = bracket(self.x_axis, xl)
        x0, x1 = self.x_axis[i0], self.x_axis[i1]
        y0, y1 = self.x_axis[j0], self.x_axis[j1]
        tx = 0.0 if x1 == x0 else (xu - x0) / (x1 - x0)
        ty = 0.0 if y1 == y0 else (xl - y0) / (y1 - y0)
        a00 = self.values[i0][j0]
        a10 = self.values[i1][j0]
        a11 = self.values[i1][j1]
        a01 = self.values[i0][j1]
        return (
            (1.0 - tx) * (1.0 - ty) * a00
            + tx * (1.0 - ty) * a10
            + tx * ty * a11
            + (1.0 - tx) * ty * a01
        )

    def log_ratio(self, h_u, h_l):
        raw = self.raw_log_ratio(h_u, h_l)
        g = (h_l - h_u) / self.length
        w = zero_identity_weight(g)
        if w == 0.0:
            return raw
        exact = math.log(self.mat.conductivity(h_u) / self.mfp.limit_k(h_u))
        interpolated = self.raw_log_ratio(h_u, h_u)
        return raw + w * (exact - interpolated)

    def flux(self, h_u, h_l):
        if h_u < core.R_HMIN or h_u > core.R_HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u, core.R_HMIN, core.R_HMAX))
        if h_l < core.R_HMIN or h_l > core.R_HMAX:
            raise ValueError(("lower_head_out_of_ratio_envelope", h_l, core.R_HMIN, core.R_HMAX))
        g = (h_l - h_u) / self.length
        kbase = self.mfp.secant_k(h_u, h_l)
        return kbase * (1.0 - g) * math.exp(self.log_ratio(h_u, h_l))

    def memory(self):
        n = self.nx * self.nx
        return {"values": n, "bytes_before_metadata": 8 * n}


def build_provider(fixture, length):
    view = EndpointPairRatioView(fixture, length)
    return view, view.oracle_solves, 0


def corrected_interface_flux(view_u, view_l, h_u, h_l):
    if h_u < core.R_HMIN or h_u > core.R_HMAX:
        raise gatec.CoverageFailure(("upper_endpoint_outside_ratio_envelope", h_u))
    if h_l < core.R_HMIN or h_l > core.R_HMAX:
        raise gatec.CoverageFailure(("lower_endpoint_outside_ratio_envelope", h_l))
    lo = core.R_HMIN
    hi = core.R_HMAX

    def residual(h_i):
        q_u = view_u.flux(h_u, h_i)
        q_l = view_l.flux(h_i, h_l)
        return q_u - q_l, q_u, q_l

    f_lo, q_ul, q_ll = residual(lo)
    f_hi, q_uh, q_lh = residual(hi)
    for h, f, q_u, q_l in ((lo, f_lo, q_ul, q_ll), (hi, f_hi, q_uh, q_lh)):
        scale = max(1.0, abs(q_u), abs(q_l))
        if abs(f) <= gatec.ROOT_TOL * scale:
            return gatec.RootResult(0.5 * (q_u + q_l), h, 0, f, abs(f) / scale, (lo, hi))
    if f_lo * f_hi > 0.0:
        raise gatec.CoverageFailure(("equal_flux_root_not_bracketed_inside_endpoint_domain", lo, hi, f_lo, f_hi))
    for iteration in range(1, gatec.ROOT_MAX + 1):
        mid = 0.5 * (lo + hi)
        f_mid, q_u, q_l = residual(mid)
        scale = max(1.0, abs(q_u), abs(q_l))
        if abs(f_mid) <= gatec.ROOT_TOL * scale:
            return gatec.RootResult(0.5 * (q_u + q_l), mid, iteration, f_mid, abs(f_mid) / scale, (lo, hi))
        if f_lo * f_mid <= 0.0:
            hi = mid
        else:
            lo = mid
            f_lo = f_mid
    mid = 0.5 * (lo + hi)
    f_mid, q_u, q_l = residual(mid)
    scale = max(1.0, abs(q_u), abs(q_l))
    raise gatec.CoverageFailure(("root_iteration_cap_without_acceptance", gatec.ROOT_MAX, f_mid, scale, mid))


def provider_identity(view):
    rows = []
    max_equal = 0.0
    max_hydro = 0.0
    heads = (-1.0e6, -1.0e5, -1.0e3, -100.0, -10.0, -1.0, -0.01, -0.001, 0.0, 0.001, 0.01, 1.0, 10.0, 100.0)
    for h in heads:
        q = view.flux(h, h)
        expected = view.mat.conductivity(h)
        err = abs(q - expected)
        max_equal = max(max_equal, err)
        rows.append({"kind": "equal_head", "h": h, "q": q, "expected": expected, "abs_error": err})
        h_l = h + view.length
        if h_l <= core.R_HMAX:
            q0 = view.flux(h, h_l)
            max_hydro = max(max_hydro, abs(q0))
            rows.append({"kind": "hydrostatic", "h_u": h, "h_l": h_l, "q": q0, "abs_error": abs(q0)})
    return {
        "pass": max_equal < 2.0e-10 and max_hydro < 2.0e-10,
        "max_equal_head_abs_error": max_equal,
        "max_hydrostatic_abs_flux": max_hydro,
        "rows": rows,
    }


def provider_continuity(view):
    rows = []
    ratios = []
    finite = True
    for h in (-1.0e5, -100.0, -1.0, -0.01, -0.001, 0.0, 0.001, 0.01, 1.0, 10.0):
        for g0 in (0.0, 1.0):
            h0 = h + g0 * view.length
            if not core.R_HMIN <= h0 <= core.R_HMAX:
                continue
            q0 = view.flux(h, h0)
            distances = []
            for eps in gatec.CONT_EPS:
                vals = []
                for sign in (-1.0, 1.0):
                    hl = h + (g0 + sign * eps) * view.length
                    if core.R_HMIN <= hl <= core.R_HMAX:
                        vals.append(abs(view.flux(h, hl) - q0))
                if len(vals) != 2:
                    break
                distances.append(max(vals))
            if len(distances) != len(gatec.CONT_EPS):
                continue
            rs = [b / max(a, 1.0e-300) for a, b in zip(distances[:-1], distances[1:])]
            finite = finite and all(math.isfinite(v) for v in distances + rs)
            ratios.append(rs[-1])
            rows.append({"h_u": h, "g": g0, "distances": distances, "ratios": rs, "final_ratio": rs[-1]})
    maximum = max(ratios) if ratios else math.inf
    return {"pass": finite and maximum <= 0.35, "maximum_final_ratio": maximum, "rows": rows}


def provider_fail_closed(view):
    trials = [
        (core.R_HMIN - 1.0, -10.0),
        (-10.0, core.R_HMIN - 1.0),
        (core.R_HMAX + 1.0, -10.0),
        (-10.0, core.R_HMAX + 1.0),
    ]
    rows = []
    for h_u, h_l in trials:
        failed = False
        error = None
        try:
            view.flux(h_u, h_l)
        except Exception as exc:
            failed = True
            error = type(exc).__name__ + ":" + str(exc)
        rows.append({"h_u": h_u, "h_l": h_l, "explicit_failure": failed, "error": error})
    return {"pass": all(r["explicit_failure"] for r in rows), "rows": rows}


def provider_probe_rows(fixture, length, seed):
    rows = [r for r in core.build_probe_rows(fixture, length, seed) if core.R_HMIN <= r["h_l"] <= core.R_HMAX]
    extreme_pairs = (
        (-1.0e5, -1.0e3), (-1.0e5, -100.0), (-1.0e5, -10.0), (-1.0e5, 0.0), (-1.0e5, 100.0),
        (-1.0e3, -1.0e5), (-100.0, -1.0e5), (-10.0, -1.0e5), (0.0, -1.0e5), (100.0, -1.0e5),
    )
    seen = {(round(r["h_u"], 12), round(r["h_l"], 12)) for r in rows}
    for h_u, h_l in extreme_pairs:
        key = (round(h_u, 12), round(h_l, 12))
        if key in seen:
            continue
        g = (h_l - h_u) / length
        qd = core.direct_flux(fixture.material, h_u, h_l, length)
        rows.append({
            "h_u": h_u,
            "h_l": h_l,
            "g": g,
            "q_ref": qd,
            "active_floor": 1.0e-8 * max(fixture.material.conductivity(0.0), 1.0),
            "strong_gradient": abs(g) >= 5.0,
            "near_saturation": max(abs(h_u), abs(h_l)) <= 10.0,
            "composition_tail_probe": True,
        })
        seen.add(key)
    return rows


def provider_self_check(fixtures, providers):
    rows = []
    all_pass = True
    for ni, (name, fixture) in enumerate(fixtures.items()):
        for li, length in enumerate(gatec.HALF_LENGTHS):
            view = providers[(name, length)]
            identity = provider_identity(view)
            continuity = provider_continuity(view)
            fail_closed = provider_fail_closed(view)
            face = core.metrics_for_view(view, provider_probe_rows(fixture, length, 531092000 + 100 * ni + li))
            passed = identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"]
            all_pass = all_pass and passed
            rows.append({
                "material": name,
                "length_cm": length,
                "pass": passed,
                "identity": identity,
                "continuity": continuity,
                "fail_closed": fail_closed,
                "face_matrix": face,
                "memory": view.memory(),
            })
    return {"pass": all_pass, "rows": rows}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_gate_c_endpoint_pair.py EVIDENCE_JSON")
    out_path = Path(sys.argv[1])
    fixtures, pairs = gatec.material_group("synthetic")

    providers = {}
    prep = []
    total_bytes = 0
    total_oracle = 0
    for name, fixture in fixtures.items():
        for length in gatec.HALF_LENGTHS:
            view, calls, _ = build_provider(fixture, length)
            providers[(name, length)] = view
            memory = view.memory()["bytes_before_metadata"]
            total_bytes += memory
            total_oracle += calls
            prep.append({
                "material": name,
                "half_face_length_cm": length,
                "upper_axis_nodes": view.nx,
                "lower_axis_nodes": view.nx,
                "values": view.memory()["values"],
                "bytes_before_metadata": memory,
                "oracle_solves": calls,
            })

    gatec.corrected_interface_flux = corrected_interface_flux
    gatec.build_provider = build_provider

    provider_check = provider_self_check(fixtures, providers)
    interface = gatec.interface_matrix(fixtures, pairs, providers)
    fail_closed = gatec.explicit_fail_closed(fixtures, providers)
    continuity = gatec.continuity_checks(fixtures, pairs, providers)
    reduction = gatec.homogeneous_reduction(fixtures, providers, "synthetic")

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C2_BOUNDED_TRANSFORMED_ENDPOINT_PAIR_SYNTHETIC_QUALIFICATION",
        "candidate": "BOUNDED_TRANSFORMED_ENDPOINT_PAIR_LOG_RATIO",
        "coordinates": ["x_upper=asinh(h_upper/0.01cm)", "x_lower=asinh(h_lower/0.01cm)"],
        "ratio_head_envelope_cm": [core.R_HMIN, core.R_HMAX],
        "axis_base_nodes": AXIS_N,
        "zero_knot_inserted": True,
        "thresholds_changed_from_gate_c1": False,
        "pair_selection_uses_validation_error": False,
        "provider_preparation": {
            "classes": prep,
            "shared_bytes_before_metadata_for_tested_classes": total_bytes,
            "offline_oracle_solves": total_oracle,
            "runtime_oracle_calls": 0,
            "pair_specific_table_classes": 0,
        },
        "provider_self_check": provider_check,
        "interface_matrix": interface,
        "explicit_fail_closed": fail_closed,
        "continuity": continuity,
        "homogeneous_reduction": reduction,
        "catalog_admission": False,
        "catalog_blocker": "B110 near-saturation conductivity jump is separately localized and not solved by this coordinate candidate",
        "architecture": {
            "production_code_changed": False,
            "persistent_column_state_added": False,
            "pair_specific_tables": False,
            "shared_immutable_material_geometry_data": True,
            "worker_local_root_scratch": True,
            "single_realized_face_flux": True,
            "mass_compatible": True,
            "no_silent_extrapolation": True,
            "no_silent_solver_switch": True,
            "fullrichards_reference_preserved": True,
        },
    }
    evidence["structural_pass"] = all((
        provider_check["pass"],
        interface["pass"],
        fail_closed["pass"],
        continuity["pass"],
        reduction["pass"],
    ))
    evidence["decision"] = (
        "GATE_C2_SYNTHETIC_ENDPOINT_PAIR_QUALIFIED"
        if evidence["structural_pass"]
        else "GATE_C2_SYNTHETIC_ENDPOINT_PAIR_FAILED_LOCALIZE_WITHOUT_THRESHOLD_RELAXATION"
    )
    out_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["structural_pass"] else 1)


if __name__ == "__main__":
    main()
