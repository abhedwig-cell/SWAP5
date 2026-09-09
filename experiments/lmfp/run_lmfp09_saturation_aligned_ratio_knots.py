from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket
import run_lmfp09_adaptive_ratio_refinement as adaptive

FIXTURE = next(f for f in core.ACTIVE if f.name == "reference_sand")
LENGTH = 20.0
PROBE_SEED = 431090101
CROSSING_G = (-3.0, -1.0, 0.5, 2.0, 3.0, 5.0, 8.0, 20.0)
CROSSING_EPS = (0.1, 0.02, 0.004, 0.0008)

core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.continuity_test = asymptotic_continuity_test
core.MASTER_NX = 33
core.VIEW_NX = (33,)


class SaturationAlignedRatioView(core.RatioView):
    """33-node base ratio grid augmented by h_lower=0 knot heads.

    For each fixed gradient node g, h_lower=0 occurs at h_upper=-g*L.
    All such upper-head locations inside the qualified ratio envelope are added
    to the common head axis. This is geometry-derived and does not use
    validation error or probe locations.
    """

    def __init__(self, master):
        self.master = master
        self.fixture = master.fixture
        self.mat = master.mat
        self.length = master.length
        self.mfp = master.mfp

        pairs = [(x, list(v), "base") for x, v in zip(master.x_axis, master.values)]
        self.crossing_knots = []
        self.extra_oracle_solves = 0

        for g in core.G_AXIS:
            h = -g * self.length
            if h < core.R_HMIN or h > core.R_HMAX:
                continue
            x = master.coordinate.x(h)
            if any(math.isclose(x, x0, rel_tol=0.0, abs_tol=2.0e-14) for x0, _, _ in pairs):
                self.crossing_knots.append({"gradient": g, "h_upper_cm": h, "x": x,
                                            "inserted": False})
                continue
            row, calls = adaptive.interpolation_row(master, h)
            self.extra_oracle_solves += calls
            pairs.append((x, row, "crossing"))
            self.crossing_knots.append({"gradient": g, "h_upper_cm": h, "x": x,
                                        "inserted": True})

        pairs.sort(key=lambda p: p[0])
        self.x_axis = [p[0] for p in pairs]
        self.values = [p[1] for p in pairs]
        self.nx = len(self.x_axis)


def evaluate(view, probes):
    identity = core.identity_test(view)
    continuity = asymptotic_continuity_test(view)
    fail_closed = core.fail_closed_test(view)
    face = core.metrics_for_view(view, probes)
    return {
        "pass": identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"],
        "identity": identity,
        "asymptotic_continuity": continuity,
        "fail_closed": fail_closed,
        "face_matrix": face,
        "memory": view.memory(),
    }


def physical_crossing_characterization(view):
    rows = []
    all_finite = True
    for g in CROSSING_G:
        h_cross = -g * view.length
        if h_cross < core.R_HMIN or h_cross > core.R_HMAX:
            continue
        q0_ref = core.direct_flux(view.mat, h_cross, 0.0, view.length)
        q0_fit = view.flux(h_cross, 0.0)
        jumps_ref = []
        jumps_fit = []
        samples = []
        for eps in CROSSING_EPS:
            hm = h_cross - eps
            hp = h_cross + eps
            qmr = core.direct_flux(view.mat, hm, -eps, view.length)
            qpr = core.direct_flux(view.mat, hp, eps, view.length)
            qmf = view.flux(hm, -eps)
            qpf = view.flux(hp, eps)
            jumps_ref.append(abs(qpr - qmr))
            jumps_fit.append(abs(qpf - qmf))
            samples.append({
                "epsilon_cm": eps,
                "q_ref_minus": qmr,
                "q_ref_at_crossing": q0_ref,
                "q_ref_plus": qpr,
                "q_fit_minus": qmf,
                "q_fit_at_crossing": q0_fit,
                "q_fit_plus": qpf,
                "left_derivative_ref": (q0_ref - qmr) / eps,
                "right_derivative_ref": (qpr - q0_ref) / eps,
                "left_derivative_fit": (q0_fit - qmf) / eps,
                "right_derivative_fit": (qpf - q0_fit) / eps,
            })
        ratios_ref = [b / max(a, 1.0e-300) for a, b in zip(jumps_ref[:-1], jumps_ref[1:])]
        ratios_fit = [b / max(a, 1.0e-300) for a, b in zip(jumps_fit[:-1], jumps_fit[1:])]
        finite = all(math.isfinite(v) for v in jumps_ref + jumps_fit + ratios_ref + ratios_fit + [q0_ref, q0_fit])
        all_finite = all_finite and finite
        rows.append({
            "gradient": g,
            "h_upper_at_hlower_zero_cm": h_cross,
            "finite": finite,
            "reference_crossing_jumps": jumps_ref,
            "fit_crossing_jumps": jumps_fit,
            "reference_consecutive_jump_ratios": ratios_ref,
            "fit_consecutive_jump_ratios": ratios_fit,
            "samples": samples,
        })
    return {
        "finite": all_finite,
        "epsilon_cm": list(CROSSING_EPS),
        "expected_ratio_for_locally_continuous_first_order_behavior": 0.2,
        "rows": rows,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_saturation_aligned_ratio_knots.py EVIDENCE_JSON")

    mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
    mfp = HermiteMFPTable(FIXTURE.material, mfp_coord, core.MFP_N)
    master = core.RatioMaster(FIXTURE, LENGTH, mfp)
    base = core.RatioView(master, 33)
    candidate = SaturationAlignedRatioView(master)
    probes = core.build_probe_rows(FIXTURE, LENGTH, PROBE_SEED)

    base_result = evaluate(base, probes)
    candidate_result = evaluate(candidate, probes)
    crossing = physical_crossing_characterization(candidate)

    if candidate_result["pass"]:
        decision = "SATURATION_ALIGNED_HLOWER_ZERO_KNOTS_RESOLVE_REFERENCE_SAND_20CM_FACE_GATE"
    else:
        decision = "SATURATION_ALIGNED_HLOWER_ZERO_KNOTS_INSUFFICIENT_REPRESENTATION_GEOMETRY_REQUIRES_FURTHER_CHARACTERIZATION"

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "subgate": "B1_C2_SATURATION_ALIGNED_RATIO_KNOTS",
        "material": FIXTURE.name,
        "face_length_cm": LENGTH,
        "probe_seed": PROBE_SEED,
        "representation": "CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO_WITH_HLOWER_ZERO_ALIGNED_HEAD_KNOTS",
        "selection_uses_validation_error": False,
        "knot_rule": "augment the 33-node asinh upper-head ratio axis with every h_upper=-g*L for fixed G_AXIS nodes whose h_lower=0 crossing lies inside the ratio envelope",
        "thresholds_changed": False,
        "base_33": base_result,
        "saturation_aligned": candidate_result,
        "crossing_knots": candidate.crossing_knots,
        "inserted_crossing_knots": sum(1 for r in candidate.crossing_knots if r["inserted"]),
        "oracle_cost": {
            "base_master_oracle_solves": master.oracle_solves,
            "extra_crossing_knot_oracle_solves": candidate.extra_oracle_solves,
            "runtime_oracle_calls": 0,
        },
        "physical_crossing_characterization": crossing,
        "hard_invariants_pass": (
            candidate_result["identity"]["pass"]
            and candidate_result["asymptotic_continuity"]["pass"]
            and candidate_result["fail_closed"]["pass"]
            and crossing["finite"]
        ),
        "decision": decision,
        "architecture": {
            "production_code_changed": False,
            "physics_changed": False,
            "mass_semantics_changed": False,
            "equal_head_identity_preserved": candidate_result["identity"]["pass"],
            "hydrostatic_identity_preserved": candidate_result["identity"]["pass"],
            "fail_closed_preserved": candidate_result["fail_closed"]["pass"],
            "shared_immutable_geometry_class_data": True,
            "per_column_table": False,
            "runtime_interpolation": "bounded local bracketing and bilinear interpolation; no oracle",
            "production_admission": False,
            "groundwater_admission": False,
        },
        "next_step_if_pass": "Rerun the unchanged expanded homogeneous material/length matrix with the same algorithmic knot rule, then persist cardinality and transient-regression evidence.",
        "next_step_if_fail": "Do not increase uniform density blindly; compare a coordinate or interpolation family explicitly aligned with both endpoint-head saturation geometry.",
    }

    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["hard_invariants_pass"] else 1)


if __name__ == "__main__":
    main()
