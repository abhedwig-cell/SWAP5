from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c3b_offgrid_holdout as c3b
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable

SE_STEP = 0.02
POSITIVE_HEAD_AXIS = (0.0, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0)
ALLOWED_CLASSES = (("reference_sand", 10.0), ("very_fast", 5.0))


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x >= axis[-1]:
        return len(axis) - 2, len(axis) - 1
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


def effective_saturation(mat, h):
    theta = mat.theta(h)
    return (theta - mat.theta_r) / (mat.theta_s - mat.theta_r)


def head_from_effective_saturation(mat, se, se_min):
    if se <= se_min:
        return core.R_HMIN
    if se >= 1.0:
        return 0.0
    theta = mat.theta_r + se * (mat.theta_s - mat.theta_r)
    return mat.head_from_theta(theta, hmin=core.R_HMIN)


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values) - 1, int(p * len(values)))]


class MixedStateDirectFluxView:
    """C5a characterization only: direct steady-q lookup in Se/Se and Se/h+ coordinates."""

    def __init__(self, fixture, length):
        self.fixture = fixture
        self.mat = fixture.material
        self.length = float(length)
        self.se_min = effective_saturation(self.mat, core.R_HMIN)
        nominal = [i * SE_STEP for i in range(int(round(1.0 / SE_STEP)) + 1)]
        self.se_axis = sorted(set([self.se_min] + [x for x in nominal if x > self.se_min]))
        if self.se_axis[-1] != 1.0:
            self.se_axis.append(1.0)
        self.unsat_heads = [head_from_effective_saturation(self.mat, se, self.se_min) for se in self.se_axis]
        self.positive_head_axis = list(POSITIVE_HEAD_AXIS)

        self.q_uu = []
        self.q_us = []
        self.oracle_solves = 0
        for h_u in self.unsat_heads:
            row_uu = []
            row_us = []
            for h_l in self.unsat_heads:
                row_uu.append(core.direct_flux(self.mat, h_u, h_l, self.length))
                self.oracle_solves += 1
            for h_l in self.positive_head_axis:
                row_us.append(core.direct_flux(self.mat, h_u, h_l, self.length))
                self.oracle_solves += 1
            self.q_uu.append(row_uu)
            self.q_us.append(row_us)

        mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
        self.mfp = HermiteMFPTable(self.mat, mfp_coord, core.MFP_N)

    @staticmethod
    def bilinear(x_axis, y_axis, values, x, y):
        i0, i1 = bracket(x_axis, x)
        j0, j1 = bracket(y_axis, y)
        x0, x1 = x_axis[i0], x_axis[i1]
        y0, y1 = y_axis[j0], y_axis[j1]
        tx = 0.0 if x1 == x0 else (x - x0) / (x1 - x0)
        ty = 0.0 if y1 == y0 else (y - y0) / (y1 - y0)
        a00 = values[i0][j0]
        a10 = values[i1][j0]
        a11 = values[i1][j1]
        a01 = values[i0][j1]
        return (
            (1.0 - tx) * (1.0 - ty) * a00
            + tx * (1.0 - ty) * a10
            + tx * ty * a11
            + (1.0 - tx) * ty * a01
        )

    def flux(self, h_u, h_l):
        if not (core.R_HMIN <= h_u < 0.0):
            raise ValueError(("C5a_upper_not_unsaturated_or_outside_envelope", h_u))
        if not (core.R_HMIN <= h_l <= core.R_HMAX):
            raise ValueError(("C5a_lower_outside_envelope", h_l))
        se_u = effective_saturation(self.mat, h_u)
        if h_l < 0.0:
            se_l = effective_saturation(self.mat, h_l)
            return self.bilinear(self.se_axis, self.se_axis, self.q_uu, se_u, se_l)
        return self.bilinear(self.se_axis, self.positive_head_axis, self.q_us, se_u, h_l)

    def memory(self):
        uu = len(self.se_axis) * len(self.se_axis)
        us = len(self.se_axis) * len(self.positive_head_axis)
        return {
            "se_nodes": len(self.se_axis),
            "positive_head_nodes": len(self.positive_head_axis),
            "uu_values": uu,
            "us_values": us,
            "total_values": uu + us,
            "bytes_before_metadata": 8 * (uu + us),
        }


def metrics(view, probes):
    active = []
    strong = []
    dormant = []
    sign_mismatches = 0
    failures = 0
    informative = 0
    better_than_plain_mfp = 0
    worst = None
    ks_scale = max(view.mat.conductivity(0.0), 1.0)

    for row in probes:
        try:
            qc = view.flux(row["h_u"], row["h_l"])
            qm = view.mfp.secant_k(row["h_u"], row["h_l"]) * (1.0 - row["g"])
        except Exception as exc:
            failures += 1
            candidate = {**row, "failed": True, "error": type(exc).__name__ + ":" + str(exc)}
            if worst is None:
                worst = (math.inf, candidate)
            continue
        qd = row["q_ref"]
        if abs(qd) >= row["active_floor"]:
            ec = abs(qc - qd) / abs(qd)
            em = abs(qm - qd) / abs(qd)
            active.append(ec)
            if row["strong_gradient"]:
                strong.append(ec)
            if qc * qd < 0.0:
                sign_mismatches += 1
            if em > 1.0e-5:
                informative += 1
                if ec < em:
                    better_than_plain_mfp += 1
        else:
            ec = abs(qc - qd) / ks_scale
            em = abs(qm - qd) / ks_scale
            dormant.append(ec)
        candidate = {
            **row,
            "q_candidate": qc,
            "q_mfp": qm,
            "candidate_error": ec,
            "mfp_error": em,
        }
        if worst is None or ec > worst[0]:
            worst = (ec, candidate)

    result = {
        "cases": len(probes),
        "active_cases": len(active),
        "dormant_cases": len(dormant),
        "failures": failures,
        "sign_mismatches": sign_mismatches,
        "active_relative_error": {
            "median": percentile(active, 0.50),
            "p90": percentile(active, 0.90),
            "p99": percentile(active, 0.99),
            "maximum": max(active) if active else math.inf,
        },
        "strong_gradient_p90": percentile(strong, 0.90),
        "dormant_max_scaled_abs": max(dormant) if dormant else 0.0,
        "informative_cases": informative,
        "fraction_better_than_plain_mfp": better_than_plain_mfp / informative if informative else 1.0,
        "worst_probe": worst[1] if worst else None,
    }
    result["diagnostic_threshold_pass"] = all((
        failures == 0,
        sign_mismatches == 0,
        result["active_relative_error"]["p90"] < 0.02,
        result["active_relative_error"]["p99"] < 0.10,
        result["active_relative_error"]["maximum"] < 0.30,
        result["strong_gradient_p90"] < 0.02,
        result["dormant_max_scaled_abs"] < 1.0e-7,
        result["fraction_better_than_plain_mfp"] >= 0.75,
    ))
    return result


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: run_lmfp09_gate_c5a_mixed_state_tail.py EVIDENCE_JSON MATERIAL HALF_FACE_LENGTH_CM")
    out = Path(sys.argv[1])
    material_name = sys.argv[2]
    length = float(sys.argv[3])
    if (material_name, length) not in ALLOWED_CLASSES:
        raise SystemExit(("unsupported_precommitted_class", material_name, length))
    fixtures = {f.name: f for f in FIXTURES}
    fixture = fixtures[material_name]

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C5A_MIXED_STATE_TAIL_CHARACTERIZATION",
        "qualification": False,
        "material": material_name,
        "half_face_length_cm": length,
        "candidate": "DIRECT_STEADY_Q_SE_SE_AND_SE_POSITIVE_H",
        "se_nominal_increment": SE_STEP,
        "positive_head_axis_cm": list(POSITIVE_HEAD_AXIS),
        "probe_set": "REVEALED_C3B_CHARACTERIZATION_SET_NOT_VALID_FOR_QUALIFICATION",
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    view = MixedStateDirectFluxView(fixture, length)
    evidence["provider"] = {
        **view.memory(),
        "se_min_at_ratio_head_envelope": view.se_min,
        "offline_oracle_solves": view.oracle_solves,
    }
    evidence["stage"] = "REVEALED_C3B_REFERENCE_GENERATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    probes, attempts = c3b.holdout_rows(fixture.material, length)
    evidence["probe_count"] = len(probes)
    evidence["random_sampling_attempts"] = attempts
    evidence["stage"] = "EVALUATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    result = metrics(view, probes)
    evidence["metrics"] = result
    evidence["status"] = "COMPLETED"
    evidence["stage"] = "COMPLETE"
    evidence["decision"] = (
        "C5A_MIXED_STATE_TAIL_CHARACTERIZATION_MEETS_EXISTING_DIAGNOSTIC_THRESHOLDS_REQUIRES_NEW_C5B_HOLDOUT"
        if result["diagnostic_threshold_pass"] else
        "C5A_MIXED_STATE_TAIL_CHARACTERIZATION_DOES_NOT_MEET_EXISTING_DIAGNOSTIC_THRESHOLDS"
    )
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    # Characterization is observational. The workflow should stay green unless execution failed.


if __name__ == "__main__":
    main()
