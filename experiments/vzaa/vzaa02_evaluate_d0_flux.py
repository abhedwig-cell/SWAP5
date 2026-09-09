from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

SQRT_PI = math.sqrt(math.pi)

# Frozen F-LMFP04 hydraulic fixtures. These values are copied from
# experiments/lmfp/run_lmfp04_ab.py on the F-VZAA02 executable base.
MATERIALS = {
    1: {"name": "sand", "theta_r": 0.045, "theta_s": 0.430, "ks": 20.0,
        "alpha": 0.040, "n": 1.80},
    2: {"name": "clay", "theta_r": 0.080, "theta_s": 0.500, "ks": 0.20,
        "alpha": 0.010, "n": 1.30},
}
for _p in MATERIALS.values():
    _p["m"] = 1.0 - 1.0 / _p["n"]

CASE_NAMES = {
    1: "steady_sand",
    2: "redistribution_sand",
    3: "infiltration_sand",
    4: "infiltration_clay",
    5: "sand_over_clay",
    6: "clay_over_sand",
}
HOMOGENEOUS_SOURCE_SCOPE = {1, 2, 3, 4}
NONTRIVIAL_HOMOGENEOUS = {2, 3, 4}


def literal_eq5(times, theta):
    if len(times) != len(theta) or len(times) < 2:
        raise ValueError("invalid_Eq5_history")
    tn = times[-1]
    terms = []
    for j in range(len(times) - 1):
        midpoint = 0.5 * (times[j] + times[j + 1])
        lag = tn - midpoint
        if not lag > 0.0:
            raise ValueError(("nonpositive_Eq5_midpoint_lag", j, lag))
        terms.append((theta[j + 1] - theta[j]) / math.sqrt(lag))
    return -math.fsum(terms) / SQRT_PI


def vg_k_d_from_theta(code, theta):
    """Return K(theta), D(theta) using Sadeghi et al. (2022) Eqs. 28 and 30."""
    p = MATERIALS[code]
    s = (theta - p["theta_r"]) / (p["theta_s"] - p["theta_r"])
    if not (0.0 < s < 1.0):
        raise ValueError(("state_outside_unsaturated_vg_domain", code, theta, s))
    m = p["m"]
    b = 1.0 - s ** (1.0 / m)
    if not b > 0.0:
        raise ValueError(("nonpositive_vg_B", code, theta, s, b))
    k = p["ks"] * s ** 0.5 * (1.0 - b ** m) ** 2
    d = ((1.0 - m) * p["ks"] / (p["alpha"] * m * (p["theta_s"] - p["theta_r"]))
         * s ** (0.5 - 1.0 / m) * (b ** (-m) - 2.0 + b ** m))
    if not (math.isfinite(k) and math.isfinite(d) and k >= 0.0 and d > 0.0):
        raise ValueError(("nonfinite_or_nonpositive_hydraulics", code, theta, k, d))
    return k, d


def parse_fullrichards(path):
    steps = {}
    nodes = defaultdict(dict)
    for raw in Path(path).read_text().splitlines():
        parts = raw.split()
        if not parts:
            continue
        if parts[0] == "VZAA02_STEP":
            case_id, refinement, step = map(int, parts[1:4])
            t0, t1, dt, top_native, bottom_native, residual = map(float, parts[4:])
            steps[(case_id, refinement, step)] = {
                "t0": t0, "t1": t1, "dt": dt,
                "top_native_up": top_native, "bottom_native_up": bottom_native,
                "driver_mass_residual": residual,
            }
        elif parts[0] == "VZAA02_NODE":
            case_id, refinement, step, node = map(int, parts[1:5])
            dz, h_before, theta_before, h_after, theta_after = map(float, parts[5:])
            nodes[(case_id, refinement, step)][node] = {
                "dz": dz, "h_before": h_before, "theta_before": theta_before,
                "h_after": h_after, "theta_after": theta_after,
            }
    if not steps:
        raise ValueError("no_FullRichards_steps")
    return steps, nodes


def parse_candidate(path):
    records = {}
    for raw in Path(path).read_text().splitlines():
        record = json.loads(raw)
        if record.get("record_type") == "accepted_step":
            key = (int(record["case_id"]), int(record["refinement"]), int(record["step"]))
            if key in records:
                raise ValueError(("duplicate_candidate_step", key))
            records[key] = record
    if not records:
        raise ValueError("no_candidate_steps")
    return records


def reference_faces_down(step, node_map):
    # FullRichards raw result flux is upward-positive. Evidence convention is downward-positive.
    faces = [-step["top_native_up"]]
    for node in range(1, 5):
        row = node_map[node]
        delta_storage = row["dz"] * (row["theta_after"] - row["theta_before"])
        faces.append(faces[-1] - delta_storage / step["dt"])
    # Native face_N - q_bottom_native = residual/dt. After sign conversion:
    # face_N_down - q_bottom_down = -residual/dt.
    bottom_identity = faces[-1] - (-step["bottom_native_up"]) + step["driver_mass_residual"] / step["dt"]
    return faces, bottom_identity


def mean_abs(values):
    return math.fsum(abs(v) for v in values) / len(values)


def median_abs(values):
    ordered = sorted(abs(v) for v in values)
    n = len(ordered)
    if n % 2:
        return ordered[n // 2]
    return 0.5 * (ordered[n // 2 - 1] + ordered[n // 2])


def summarize_points(points):
    e_lmfp = [p["e_lmfp"] for p in points]
    e_vzaa = [p["e_vzaa"] for p in points]
    closer = [p for p in points if abs(p["e_vzaa"]) < abs(p["e_lmfp"])]
    direction = [p for p in points if math.copysign(1.0, p["delta_q"]) == math.copysign(1.0, p["e_needed"])
                 and p["delta_q"] != 0.0 and p["e_needed"] != 0.0]
    h_nonpos = sum(1 for p in points if p["H"] <= 0.0)
    return {
        "point_count": len(points),
        "lmfp_mean_abs_error": mean_abs(e_lmfp),
        "vzaa_mean_abs_error": mean_abs(e_vzaa),
        "lmfp_median_abs_error": median_abs(e_lmfp),
        "vzaa_median_abs_error": median_abs(e_vzaa),
        "lmfp_max_abs_error": max(abs(v) for v in e_lmfp),
        "vzaa_max_abs_error": max(abs(v) for v in e_vzaa),
        "vzaa_closer_count": len(closer),
        "vzaa_closer_fraction": len(closer) / len(points),
        "delta_direction_agree_count": len(direction),
        "delta_direction_agree_fraction": len(direction) / len(points),
        "zero_needed_count": sum(1 for p in points if p["e_needed"] == 0.0),
        "H_le_zero_count": h_nonpos,
        "H_gt_zero_count": len(points) - h_nonpos,
        "q_hist_max_abs": max(abs(p["q_hist"]) for p in points),
        "q_hist_median_abs": median_abs([p["q_hist"] for p in points]),
    }


def main():
    if len(sys.argv) != 5:
        raise SystemExit("usage: vzaa02_evaluate_d0_flux.py FULLRICHARDS_TXT LMFP08_JSONL EVIDENCE_JSON POINTS_JSONL")
    fr_path, lmfp_path, evidence_path, points_path = map(Path, sys.argv[1:])
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    points_path.parent.mkdir(parents=True, exist_ok=True)

    steps, nodes = parse_fullrichards(fr_path)
    candidate = parse_candidate(lmfp_path)
    if set(steps) != set(candidate):
        raise SystemExit(json.dumps({"key_mismatch": {
            "missing_candidate": sorted(set(steps) - set(candidate))[:10],
            "missing_reference": sorted(set(candidate) - set(steps))[:10],
        }}))

    groups = defaultdict(list)
    for key in sorted(candidate):
        groups[(key[0], key[1])].append(key)

    all_points = []
    max_reference_bottom_identity = 0.0
    history_term_evaluations = 0
    chain_exact = True

    for (case_id, refinement), keys in sorted(groups.items()):
        keys.sort(key=lambda x: x[2])
        first = candidate[keys[0]]
        if first["case_name"] != CASE_NAMES[case_id]:
            raise ValueError(("case_name_mismatch", case_id, first["case_name"]))
        times = [float(first["t0"])]
        histories = [[float(first["theta_before"][i])] for i in range(4)]
        previous_after = None

        for key in keys:
            step = steps[key]
            cand = candidate[key]
            if previous_after is not None and cand["theta_before"] != previous_after:
                chain_exact = False
            previous_after = list(cand["theta_after"])
            if cand["t0"] != times[-1] or cand["t0"] != step["t0"] or cand["t1"] != step["t1"] or cand["dt"] != step["dt"]:
                raise ValueError(("time_alignment_mismatch", key, cand["t0"], cand["t1"], cand["dt"], step))
            times.append(float(cand["t1"]))
            for i in range(4):
                histories[i].append(float(cand["theta_after"][i]))

            ref_faces, bottom_identity = reference_faces_down(step, nodes[key])
            max_reference_bottom_identity = max(max_reference_bottom_identity, abs(bottom_identity))
            lmfp_faces = [float(v) for v in cand["face_flux_down"]]
            if len(lmfp_faces) != 5:
                raise ValueError(("candidate_face_count", key, len(lmfp_faces)))

            for layer in range(4):
                theta = float(cand["theta_after"][layer])
                H = literal_eq5(times, histories[layer])
                history_term_evaluations += len(times) - 1
                c_factor = 0.5 if H <= 0.0 else 2.0
                K, D = vg_k_d_from_theta(int(cand["codes"][layer]), theta)
                q_hist = -math.sqrt(c_factor * D) * H
                # D0-A free-drainage/deep-groundwater simplification. The 2026
                # paper states K_d becomes negligible without a shallow water table.
                q_steady = K
                q_vzaa_mid = q_hist + q_steady
                q_ref_mid = 0.5 * (ref_faces[layer] + ref_faces[layer + 1])
                q_lmfp_mid = 0.5 * (lmfp_faces[layer] + lmfp_faces[layer + 1])
                e_lmfp = q_lmfp_mid - q_ref_mid
                e_vzaa = q_vzaa_mid - q_ref_mid
                all_points.append({
                    "record_type": "d0_flux_point",
                    "case_id": case_id,
                    "case_name": CASE_NAMES[case_id],
                    "source_scope": "homogeneous" if case_id in HOMOGENEOUS_SOURCE_SCOPE else "heterogeneous_falsification_only",
                    "refinement": refinement,
                    "step": int(cand["step"]),
                    "layer": layer + 1,
                    "t0": float(cand["t0"]),
                    "t1": float(cand["t1"]),
                    "dt": float(cand["dt"]),
                    "theta_candidate_committed": theta,
                    "head_candidate_committed": float(cand["head_after"][layer]),
                    "H": H,
                    "c": c_factor,
                    "K": K,
                    "D": D,
                    "q_hist": q_hist,
                    "q_steady": q_steady,
                    "q_vzaa_mid": q_vzaa_mid,
                    "q_ref_mid": q_ref_mid,
                    "q_lmfp_mid": q_lmfp_mid,
                    "e_vzaa": e_vzaa,
                    "e_lmfp": e_lmfp,
                    "delta_q": q_vzaa_mid - q_lmfp_mid,
                    "e_needed": q_ref_mid - q_lmfp_mid,
                })

    if not chain_exact:
        raise ValueError("candidate_committed_history_chain_not_exact")
    if not all(math.isfinite(v) for p in all_points for v in p.values() if isinstance(v, float)):
        raise ValueError("nonfinite_D0_point")

    by_case_ref = defaultdict(list)
    for p in all_points:
        by_case_ref[(p["case_id"], p["refinement"])].append(p)

    case_refinement_metrics = {}
    for case_id in range(1, 7):
        case_refinement_metrics[str(case_id)] = {
            "case_name": CASE_NAMES[case_id],
            "source_scope": "homogeneous" if case_id in HOMOGENEOUS_SOURCE_SCOPE else "heterogeneous_falsification_only",
            "refinements": {
                str(r): summarize_points(by_case_ref[(case_id, r)]) for r in (1, 2)
            },
        }

    # Operationalize only the already-persisted F-VZAA02 fail-closed rules.
    # No scientific tolerance is introduced here.
    all_homogeneous_transient_refinements_worse = all(
        case_refinement_metrics[str(case_id)]["refinements"][str(r)]["vzaa_mean_abs_error"]
        > case_refinement_metrics[str(case_id)]["refinements"][str(r)]["lmfp_mean_abs_error"]
        for case_id in NONTRIVIAL_HOMOGENEOUS for r in (1, 2)
    )
    exact_wrong_direction_regimes = []
    for case_id in NONTRIVIAL_HOMOGENEOUS:
        rows = [case_refinement_metrics[str(case_id)]["refinements"][str(r)] for r in (1, 2)]
        if all(row["vzaa_closer_count"] == 0 and row["delta_direction_agree_count"] == 0 for row in rows):
            exact_wrong_direction_regimes.append(case_id)

    if all_homogeneous_transient_refinements_worse and exact_wrong_direction_regimes:
        decision = "D0_DONOR_FALSIFIED_ON_ORDINARY_HOMOGENEOUS_MATRIX_DO_NOT_PROGRESS_TO_D1"
    else:
        decision = "D0_ORDINARY_MATRIX_INCONCLUSIVE_CONTINUE_ONLY_PER_PERSISTED_CONTRACT"

    first_step_points = [p for p in all_points if p["step"] == 1]
    after_first_points = [p for p in all_points if p["step"] > 1]
    evidence = {
        "schema_version": 1,
        "workstream": "F-VZAA",
        "work_unit": "F-VZAA02",
        "gate": "D0_DIAGNOSTIC_FLUX_FALSIFICATION",
        "production_implementation": False,
        "new_solver_family_implemented": False,
        "official_vzaa_code_reproduction": False,
        "operator_classification": "independent_source_bound_reconstruction",
        "source_provenance": {
            "vzaa_2026": "Sadeghi et al. (2026), Journal of Hydrology 673, 135467, DOI 10.1016/j.jhydrol.2026.135467, Eqs. 3, 5, 6, 7",
            "hydraulic_2022": "Sadeghi et al. (2022), Journal of Hydrology 610, 127999, DOI 10.1016/j.jhydrol.2022.127999, van Genuchten Eqs. 28 and 30",
            "eq5_reference_lineage": "F-VZAA01 cffeed211b4bc6f3389ed12ba555253d905f993e; qualified result run 34320488095",
            "fullrichards_and_candidate_lineage": "F-VZAA02 accepted-step trajectories at 84a1c878b19cc808c6ddaf6af94875620e73f05e",
        },
        "flux_sign": "downward_positive_for_reference_candidate_and_vzaa_diagnostic",
        "candidate_history": "candidate_committed_theta_only; FullRichards history is not used in H",
        "deep_groundwater_D0_A": "K_d treated as negligible, so Eq. 3 steady term reduces to K(theta), source-bound to the 2026 paper statement for absence of shallow water table",
        "hydraulic_fixture_parameters": MATERIALS,
        "structural": {
            "aligned_accepted_steps": len(candidate),
            "point_count": len(all_points),
            "candidate_committed_history_chain_exact": chain_exact,
            "max_reference_bottom_ledger_identity_mismatch_abs": max_reference_bottom_identity,
            "all_points_finite": True,
            "literal_history_term_evaluations": history_term_evaluations,
            "literal_history_complexity": "O(N_layers * N_steps^2) total direct-sum work over a trajectory",
        },
        "case_refinement_metrics": case_refinement_metrics,
        "startup_first_step": summarize_points(first_step_points),
        "after_first_step": summarize_points(after_first_points),
        "decision_evidence": {
            "all_nontrivial_homogeneous_case_refinements_have_vzaa_mae_gt_lmfp_mae": all_homogeneous_transient_refinements_worse,
            "homogeneous_regimes_with_zero_vzaa_closer_points_and_zero_delta_direction_agreement_at_both_refinements": exact_wrong_direction_regimes,
            "scientific_tolerance_introduced": False,
            "mixed_result_can_qualify": False,
        },
        "qualified": False,
        "decision": decision,
        "scope_limit": "This D0 result tests the raw source-bound VZAA midpoint diagnostic on the existing ordinary hydraulic matrix. It does not reproduce official MATLAB code, alter accepted transfers, qualify heterogeneous interfaces, or qualify any bounded-memory history representation.",
    }

    with points_path.open("w") as f:
        for point in all_points:
            f.write(json.dumps(point, sort_keys=True) + "\n")
    evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "qualified": False,
        "structural": evidence["structural"],
        "decision_evidence": evidence["decision_evidence"],
        "case_refinement_metrics": case_refinement_metrics,
    }, indent=2, sort_keys=True))
    print("F-VZAA02_D0_FLUX_CHARACTERIZATION_COMPLETE")


if __name__ == "__main__":
    main()
