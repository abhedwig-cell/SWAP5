from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c6a_admissible_envelope_classifier as c6a
import run_lmfp09_gate_c7a_catalog_shard as c7a
import run_lmfp09_homogeneous_face_matrix as core
from lmfp09_staring2018_catalog import CATALOG, b110_material
from run_lmfp09_coordinate_envelope import MaterialFixture

PANEL = (
    "B10", "B11", "B12", "B17", "B18",
    "O01", "O05", "O07", "O11", "O13",
    "B01", "B05", "O02", "O16", "O18",
)
LENGTHS = (10.0, 20.0)
AXIS_N = 49
HMIN = core.R_HMIN
HMAX = core.R_HMAX

CATALOG_BY_NAME = {row.sfu: row for row in CATALOG}


def finite_json(value):
    if isinstance(value, dict):
        return {k: finite_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [finite_json(v) for v in value]
    if isinstance(value, tuple):
        return [finite_json(v) for v in value]
    if isinstance(value, float) and not math.isfinite(value):
        return None
    return value


def h50_scale_cm(mat):
    alpha = mat.c[4]
    n = mat.c[6]
    m = mat.c[7]
    if not (alpha > 0.0 and n > 1.0 and 0.0 < m < 1.0):
        raise ValueError(("invalid_vg_h50_parameters", alpha, n, m))
    dimensionless = math.expm1(math.log(2.0) / m)
    return dimensionless ** (1.0 / n) / alpha


class ScaleCoordinate:
    def __init__(self, name, scale_cm):
        if not (math.isfinite(scale_cm) and scale_cm > 0.0):
            raise ValueError(("invalid_coordinate_scale_cm", name, scale_cm))
        self.name = name
        self.scale_cm = float(scale_cm)
        self.xmin = self.x(HMIN)
        self.xmax = self.x(HMAX)
        if not self.xmin < 0.0 < self.xmax:
            raise ValueError(("coordinate_does_not_straddle_zero", name, self.xmin, self.xmax))

    def x(self, h):
        return math.asinh(float(h) / self.scale_cm)

    def h(self, x):
        return self.scale_cm * math.sinh(float(x))


def proportional_zero_aligned_axis(coord, n=AXIS_N):
    if n < 3:
        raise ValueError(n)
    intervals = n - 1
    negative_span = -coord.xmin
    positive_span = coord.xmax
    total_span = negative_span + positive_span
    nneg = int(round(intervals * negative_span / total_span))
    nneg = max(1, min(intervals - 1, nneg))
    npos = intervals - nneg
    negative = [
        coord.xmin + (0.0 - coord.xmin) * i / nneg
        for i in range(nneg + 1)
    ]
    positive = [
        coord.xmax * j / npos
        for j in range(1, npos + 1)
    ]
    axis = negative + positive
    if len(axis) != n:
        raise RuntimeError(("axis_cardinality", len(axis), n, nneg, npos))
    axis[nneg] = 0.0
    return axis, nneg, npos


class ScaledEndpointRatioView:
    def __init__(self, fixture, length, family):
        self.fixture = fixture
        self.mat = fixture.material
        self.length = float(length)
        self.family = family
        alpha = self.mat.c[4]
        if family == "A_ALPHA_NORMALIZED_ENDPOINTS":
            scale_cm = 1.0 / alpha
        elif family == "B_H50_NORMALIZED_ENDPOINTS":
            scale_cm = h50_scale_cm(self.mat)
        else:
            raise ValueError(("unknown_family", family))
        self.coordinate = ScaleCoordinate(family, scale_cm)
        self.x_axis, self.negative_intervals, self.positive_intervals = proportional_zero_aligned_axis(
            self.coordinate
        )
        self.h_axis = [
            HMIN if i == 0 else
            HMAX if i == len(self.x_axis) - 1 else
            0.0 if x == 0.0 else
            self.coordinate.h(x)
            for i, x in enumerate(self.x_axis)
        ]
        self.nx = len(self.x_axis)
        mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
        self.mfp = ep.HermiteMFPTable(self.mat, mfp_coord, core.MFP_N)
        self.values = []
        self.oracle_solves = 0
        for h_u in self.h_axis:
            out = []
            for h_l in self.h_axis:
                g = (h_l - h_u) / self.length
                kd, calls = core.oracle_kdar(self.mat, h_u, g, self.length)
                self.oracle_solves += calls
                kb = self.mfp.secant_k(h_u, h_l)
                if not (math.isfinite(kd) and kd > 0.0 and math.isfinite(kb) and kb > 0.0):
                    raise RuntimeError(("nonpositive_scaled_endpoint_conductivity", family, h_u, h_l, kd, kb))
                ratio = kd / kb
                if not (math.isfinite(ratio) and ratio > 0.0):
                    raise RuntimeError(("nonpositive_scaled_endpoint_ratio", family, h_u, h_l, ratio))
                out.append(math.log(ratio))
            self.values.append(out)

    def raw_log_ratio(self, h_u, h_l):
        if not HMIN <= h_u <= HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u, HMIN, HMAX))
        if not HMIN <= h_l <= HMAX:
            raise ValueError(("lower_head_out_of_ratio_envelope", h_l, HMIN, HMAX))
        xu = self.coordinate.x(h_u)
        xl = self.coordinate.x(h_l)
        i0, i1 = c3.tolerant_bracket(self.x_axis, xu)
        j0, j1 = c3.tolerant_bracket(self.x_axis, xl)
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
        w = ep.zero_identity_weight(g)
        if w == 0.0:
            return raw
        exact = math.log(self.mat.conductivity(h_u) / self.mfp.limit_k(h_u))
        interpolated = self.raw_log_ratio(h_u, h_u)
        return raw + w * (exact - interpolated)

    def flux(self, h_u, h_l):
        if not HMIN <= h_u <= HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u, HMIN, HMAX))
        if not HMIN <= h_l <= HMAX:
            raise ValueError(("lower_head_out_of_ratio_envelope", h_l, HMIN, HMAX))
        g = (h_l - h_u) / self.length
        kbase = self.mfp.secant_k(h_u, h_l)
        return kbase * (1.0 - g) * math.exp(self.log_ratio(h_u, h_l))

    def memory(self):
        values = self.nx * self.nx
        return {"values": values, "bytes_before_metadata": 8 * values}


def production_k_jump_factor(mat):
    se = 0.999999
    m = mat.c[7]
    lam = mat.c[5]
    ks = mat.c[3]
    term1 = (1.0 - se ** (1.0 / m)) ** m
    raw = ks * (se ** lam) * (1.0 - term1) ** 2
    below = min(raw, ks)
    return ks / max(below, 1.0e-300)


def raw_inside_rows(mat, length):
    raw = c7a.raw_gradient_family(length) + c7a.raw_head_pair_family(length)
    inside = []
    active_floor = 1.0e-8 * max(mat.conductivity(0.0), 1.0)
    reference_failures = 0
    for row in raw:
        if not c7a.inside_provider_head_envelope(row):
            continue
        try:
            q_ref = core.direct_flux(mat, row["h_u"], row["h_l"], length)
        except Exception:
            reference_failures += 1
            continue
        feat = c6a.features(mat, row)
        reasons = c7a.classifier_reasons(feat)
        inside.append({
            **row,
            "q_ref": q_ref,
            "active_floor": active_floor,
            "strong_gradient": abs(row["g"]) >= 5.0,
            "near_saturation": max(abs(row["h_u"]), abs(row["h_l"])) <= 10.0,
            "classifier_features": feat,
            "frozen_classifier_admitted": not reasons,
            "classifier_reasons": reasons,
        })
    return inside, reference_failures


def strip_summary(summary):
    return {
        "cases": summary["cases"],
        "active_cases": summary["active_cases"],
        "dormant_cases": summary["dormant_cases"],
        "failures": summary["failures"],
        "sign_mismatches": summary["sign_mismatches"],
        "corrected_active_rel_error": summary["corrected_active_rel_error"],
        "mfp_active_rel_error": summary["mfp_active_rel_error"],
        "strong_gradient_corrected_p90_rel_error": summary["strong_gradient_corrected_p90_rel_error"],
        "near_saturation_corrected_p90_rel_error": summary["near_saturation_corrected_p90_rel_error"],
        "dormant_max_abs_error_over_ks_scale": summary["dormant_max_abs_error_over_ks_scale"],
        "informative_mfp_cases": summary["informative_mfp_cases"],
        "fraction_corrected_better_on_informative_cases": summary["fraction_corrected_better_on_informative_cases"],
        "saturation_regime_counts": summary["saturation_regime_counts"],
        "legacy_C7_threshold_diagnostics": summary["checks"],
    }


def compare_to_n49(candidate_rows, baseline_rows):
    if len(candidate_rows) != len(baseline_rows):
        raise RuntimeError(("row_count_mismatch", len(candidate_rows), len(baseline_rows)))
    active = 0
    candidate_better = 0
    error_ratios = []
    for cand, base in zip(candidate_rows, baseline_rows):
        if cand.get("failed") or base.get("failed"):
            continue
        if not cand.get("active") or not base.get("active"):
            continue
        active += 1
        ec = cand["candidate_error"]
        eb = base["candidate_error"]
        if ec < eb:
            candidate_better += 1
        if eb > 1.0e-15:
            error_ratios.append(ec / eb)
    return {
        "active_common_rows": active,
        "candidate_better_rows": candidate_better,
        "fraction_candidate_better": candidate_better / active if active else None,
        "median_error_ratio_candidate_over_n49": core.percentile(error_ratios, 0.50) if error_ratios else None,
        "p90_error_ratio_candidate_over_n49": core.percentile(error_ratios, 0.90) if error_ratios else None,
    }


def structural_checks(view, runtime_oracle_before):
    identity = ep.provider_identity(view)
    continuity = ep.provider_continuity(view)
    fail_closed = ep.provider_fail_closed(view)
    return {
        "identity": {
            "pass": identity["pass"],
            "max_equal_head_abs_error": identity["max_equal_head_abs_error"],
            "max_hydrostatic_abs_flux": identity["max_hydrostatic_abs_flux"],
        },
        "continuity": {
            "pass": continuity["pass"],
            "maximum_final_ratio": continuity["maximum_final_ratio"],
        },
        "fail_closed": {"pass": fail_closed["pass"]},
        "runtime_oracle_counter_before": runtime_oracle_before,
        "runtime_oracle_counter_after": view.oracle_solves,
        "runtime_oracle_calls_eq_0": view.oracle_solves == runtime_oracle_before,
    }


def evaluate_material(material_name):
    if material_name not in PANEL:
        raise ValueError(("material_not_in_A0_panel", material_name))
    row = CATALOG_BY_NAME[material_name]
    fixture = MaterialFixture(row.sfu, b110_material(row))
    mat = fixture.material
    h50 = h50_scale_cm(mat)
    result = {
        "material": material_name,
        "source_parameters": {
            "ORES": row.ores,
            "OSAT": row.osat,
            "ALFA": row.alfa,
            "NPAR": row.npar,
            "KSATFIT": row.ksatfit,
            "LEXP": row.lexp,
        },
        "derived": {
            "m": mat.c[7],
            "alpha_scale_cm": 1.0 / mat.c[4],
            "h50_scale_cm": h50,
            "production_k_jump_factor_at_relsat_0p999999": production_k_jump_factor(mat),
        },
        "classes": [],
    }

    for length in LENGTHS:
        rows_inside, ref_failures = raw_inside_rows(mat, length)
        admitted_mask = [r["frozen_classifier_admitted"] for r in rows_inside]
        qrows = [
            {k: v for k, v in r.items() if k not in ("classifier_features", "frozen_classifier_admitted", "classifier_reasons")}
            for r in rows_inside
        ]

        c3.BASE_N = 33
        ep.bracket = c3.tolerant_bracket
        n49, n49_offline, _ = c3.build_provider(fixture, length)
        n49_before = n49.oracle_solves
        n49_eval = c6a.evaluate_rows(n49, qrows)
        n49_struct = structural_checks(n49, n49_before)
        n49_full = strip_summary(c6a.summarize(n49_eval))
        n49_admitted_eval = [r for r, keep in zip(n49_eval, admitted_mask) if keep]
        n49_admitted = strip_summary(c6a.summarize(n49_admitted_eval))

        class_row = {
            "class": f"{material_name}:{length:g}cm",
            "length_cm": length,
            "reference_oracle_failures": ref_failures,
            "inside_head_envelope_rows": len(qrows),
            "frozen_classifier_admitted_rows": sum(admitted_mask),
            "n49_baseline": {
                "offline_oracle_solves": n49_offline,
                "memory": n49.memory(),
                "structural": n49_struct,
                "full_head_envelope": n49_full,
                "frozen_classifier_slice": n49_admitted,
            },
            "candidates": {},
        }

        for family in ("A_ALPHA_NORMALIZED_ENDPOINTS", "B_H50_NORMALIZED_ENDPOINTS"):
            view = ScaledEndpointRatioView(fixture, length, family)
            offline = view.oracle_solves
            before = view.oracle_solves
            evaluated = c6a.evaluate_rows(view, qrows)
            structural = structural_checks(view, before)
            full = strip_summary(c6a.summarize(evaluated))
            admitted_eval = [r for r, keep in zip(evaluated, admitted_mask) if keep]
            admitted = strip_summary(c6a.summarize(admitted_eval))
            candidate_meta = {
                "family": family,
                "coordinate_scale_cm": view.coordinate.scale_cm,
                "axis_nodes": view.nx,
                "negative_intervals": view.negative_intervals,
                "positive_intervals": view.positive_intervals,
                "memory": view.memory(),
                "offline_oracle_solves": offline,
                "structural": structural,
                "full_head_envelope": full,
                "frozen_classifier_slice": admitted,
                "versus_n49_full_head_envelope": compare_to_n49(evaluated, n49_eval),
                "versus_n49_frozen_classifier_slice": compare_to_n49(admitted_eval, n49_admitted_eval),
            }
            class_row["candidates"][family] = candidate_meta

        result["classes"].append(class_row)
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp10_a0_material_scale_screen.py EVIDENCE_JSON MATERIAL")
    out = Path(sys.argv[1])
    material = sys.argv[2]
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP10",
        "gate": "A0_MATERIAL_SCALE_COORDINATE_SCREEN",
        "qualification": False,
        "characterization_only": True,
        "material": material,
        "contract": "integration/f-lmfp/F-LMFP10_CONTRACT.json",
        "nomination_precommit": "integration/f-lmfp/F-LMFP10_A0_NOMINATION_PRECOMMIT.json",
        "C7a_probe_rows_reused_as_revealed_characterization": True,
        "thresholds_changed": False,
        "status": "IN_PROGRESS",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    evidence["result"] = evaluate_material(material)
    evidence["status"] = "COMPLETED"
    clean = finite_json(evidence)
    out.write_text(json.dumps(clean, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "material": material,
        "classes": [
            {
                "class": row["class"],
                "n49_p90": row["n49_baseline"]["frozen_classifier_slice"]["corrected_active_rel_error"]["p90"],
                "alpha_p90": row["candidates"]["A_ALPHA_NORMALIZED_ENDPOINTS"]["frozen_classifier_slice"]["corrected_active_rel_error"]["p90"],
                "h50_p90": row["candidates"]["B_H50_NORMALIZED_ENDPOINTS"]["frozen_classifier_slice"]["corrected_active_rel_error"]["p90"],
            }
            for row in evidence["result"]["classes"]
        ],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
