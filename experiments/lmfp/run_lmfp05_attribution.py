from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp04_ab import SAND, CLAY, TABLES
from run_lmfp03_column import homogeneous_face_flux, heterogeneous_face_flux


def material(code: int):
    return SAND if code == 1 else CLAY


def table(code: int):
    return TABLES[code]


def parse_reference(path: Path):
    data = {}
    for raw in path.read_text().splitlines():
        parts = raw.split()
        if not parts:
            continue
        if parts[0] == "RUN":
            case_id, n, tref = int(parts[1]), int(parts[2]), int(parts[3])
            data[(case_id, n, tref)] = {
                "summary": {
                    "name": parts[4],
                    "dt": float(parts[5]),
                    "initial_storage": float(parts[6]),
                    "final_storage": float(parts[7]),
                    "bottom_down": float(parts[8]),
                    "nonlinear_iterations": int(parts[9]),
                },
                "nodes": {},
            }
        elif parts[0] == "MASS":
            key = (int(parts[1]), int(parts[2]), int(parts[3]))
            data.setdefault(key, {"nodes": {}})["mass_residual"] = float(parts[4])
        elif parts[0] == "NODE":
            key = (int(parts[1]), int(parts[2]), int(parts[3]))
            i = int(parts[4])
            data.setdefault(key, {"nodes": {}}).setdefault("nodes", {})[i] = {
                "code": int(parts[5]),
                "depth": float(parts[6]),
                "dz": float(parts[7]),
                "h0": float(parts[8]),
                "theta0": float(parts[9]),
                "h1": float(parts[10]),
                "theta1": float(parts[11]),
            }
    return data


def initial_vectors(entry):
    nodes = [entry["nodes"][i] for i in sorted(entry["nodes"])]
    return (
        [n["code"] for n in nodes],
        [n["dz"] for n in nodes],
        [n["h0"] for n in nodes],
        [n["theta0"] for n in nodes],
    )


def arithmetic_face_flux(mat_u, mat_l, h_u, h_l, distance):
    ku = mat_u.conductivity(h_u)
    kl = mat_l.conductivity(h_l)
    kmean = 0.5 * (ku + kl)
    return kmean * (1.0 + (h_u - h_l) / distance)


def build_faces(entry, mode):
    codes, dz, heads, _ = initial_vectors(entry)
    n = len(codes)
    faces = [0.0] * (n + 1)
    metadata = []
    for i in range(n - 1):
        mu = material(codes[i])
        ml = material(codes[i + 1])
        distance = 0.5 * (dz[i] + dz[i + 1])
        if mode == "arithmetic":
            q = arithmetic_face_flux(mu, ml, heads[i], heads[i + 1], distance)
            metadata.append({"face": i + 1, "iterations": 0})
        elif mode == "mfp":
            if codes[i] == codes[i + 1]:
                q = homogeneous_face_flux(table(codes[i]), heads[i], heads[i + 1], distance)
                metadata.append({"face": i + 1, "iterations": 0})
            else:
                q, h_int, iterations, residual = heterogeneous_face_flux(
                    table(codes[i]), table(codes[i + 1]), heads[i], heads[i + 1],
                    0.5 * dz[i], 0.5 * dz[i + 1]
                )
                metadata.append({
                    "face": i + 1,
                    "iterations": iterations,
                    "interface_head": h_int,
                    "equal_flux_residual": residual,
                })
        else:
            raise ValueError(mode)
        faces[i + 1] = q
    faces[-1] = material(codes[-1]).conductivity(heads[-1])
    return faces, metadata


def candidate_from_faces(entry, mode):
    codes, dz, heads, theta0 = initial_vectors(entry)
    dt = entry["summary"]["dt"]
    faces, metadata = build_faces(entry, mode)
    theta_rate = [(faces[i] - faces[i + 1]) / dz[i] for i in range(len(dz))]
    theta1 = [t + dt * r for t, r in zip(theta0, theta_rate)]
    h1 = [material(c).head_from_theta(t) for c, t in zip(codes, theta1)]
    delta_storage = sum(d * (b - a) for d, a, b in zip(dz, theta0, theta1))
    expected = dt * (faces[0] - faces[-1])
    return {
        "mode": mode,
        "faces_down": faces,
        "face_metadata": metadata,
        "theta_rate": theta_rate,
        "theta1": theta1,
        "h1": h1,
        "mass_residual": delta_storage - expected,
        "bottom_down": faces[-1],
    }


def reference_theta_rate(entry):
    dt = entry["summary"]["dt"]
    nodes = [entry["nodes"][i] for i in sorted(entry["nodes"])]
    return [(n["theta1"] - n["theta0"]) / dt for n in nodes]


def weighted_metrics(error, dz):
    depth = sum(dz)
    return {
        "max_abs": max(abs(v) for v in error),
        "weighted_l1": sum(d * abs(v) for d, v in zip(dz, error)) / depth,
        "weighted_rmse": math.sqrt(sum(d * v * v for d, v in zip(dz, error)) / depth),
    }


def compare_candidate(entry, cand):
    _, dz, _, _ = initial_vectors(entry)
    ref_rate = reference_theta_rate(entry)
    rate_error = [a - b for a, b in zip(cand["theta_rate"], ref_rate)]
    nodes = [entry["nodes"][i] for i in sorted(entry["nodes"])]
    theta_error = [a - n["theta1"] for a, n in zip(cand["theta1"], nodes)]
    head_error = [a - n["h1"] for a, n in zip(cand["h1"], nodes)]
    return {
        "theta_rate_error": weighted_metrics(rate_error, dz),
        "theta_final_max_abs": max(abs(v) for v in theta_error),
        "head_final_max_abs_cm": max(abs(v) for v in head_error),
        "bottom_flux_abs_cm_d": abs(cand["bottom_down"] - entry["summary"]["bottom_down"]),
        "mass_residual": cand["mass_residual"],
    }


def face_delta(entry):
    arith, _ = build_faces(entry, "arithmetic")
    mfp, meta = build_faces(entry, "mfp")
    deltas = [m - a for m, a in zip(mfp, arith)]
    sign_disagreements = 0
    compared = 0
    for a, m in zip(arith[1:-1], mfp[1:-1]):
        if max(abs(a), abs(m)) > 1.0e-10:
            compared += 1
            if a * m < 0.0:
                sign_disagreements += 1
    denom = max(max(abs(v) for v in arith), max(abs(v) for v in mfp), 1.0e-12)
    return {
        "arithmetic_faces_down": arith,
        "mfp_faces_down": mfp,
        "delta_faces": deltas,
        "max_abs_delta_cm_d": max(abs(v) for v in deltas),
        "max_delta_normalized": max(abs(v) for v in deltas) / denom,
        "sign_disagreements": sign_disagreements,
        "sign_compared": compared,
        "mfp_metadata": meta,
    }


def face_sweep():
    heads = [-1000.0, -500.0, -200.0, -100.0, -50.0, -20.0, -10.0, -5.0, -1.0]
    distances = [2.0, 5.0, 10.0, 20.0]
    orientations = [(1, 1), (2, 2), (1, 2), (2, 1)]
    cases = 0
    failures = 0
    sign_disagreements = 0
    max_normalized_delta = 0.0
    max_abs_delta = 0.0
    max_mfp_iterations = 0
    worst = None
    for cu, cl in orientations:
        for hu in heads:
            for hl in heads:
                for distance in distances:
                    cases += 1
                    mu, ml = material(cu), material(cl)
                    qa = arithmetic_face_flux(mu, ml, hu, hl, distance)
                    try:
                        if cu == cl:
                            qm = homogeneous_face_flux(table(cu), hu, hl, distance)
                            iterations = 0
                        else:
                            qm, _, iterations, _ = heterogeneous_face_flux(
                                table(cu), table(cl), hu, hl, 0.5 * distance, 0.5 * distance
                            )
                    except RuntimeError:
                        failures += 1
                        continue
                    max_mfp_iterations = max(max_mfp_iterations, iterations)
                    if max(abs(qa), abs(qm)) > 1.0e-10 and qa * qm < 0.0:
                        sign_disagreements += 1
                    delta = abs(qm - qa)
                    norm = delta / max(abs(qa), abs(qm), 1.0e-8)
                    if norm > max_normalized_delta:
                        max_normalized_delta = norm
                        worst = {"upper_code": cu, "lower_code": cl, "h_upper": hu, "h_lower": hl,
                                 "distance": distance, "q_arithmetic": qa, "q_mfp": qm,
                                 "normalized_delta": norm}
                    max_abs_delta = max(max_abs_delta, delta)
    return {
        "cases": cases,
        "failures": failures,
        "sign_disagreements": sign_disagreements,
        "max_normalized_delta": max_normalized_delta,
        "max_abs_delta_cm_d": max_abs_delta,
        "max_mfp_iterations": max_mfp_iterations,
        "worst_case": worst,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp05_attribution.py REFERENCE_OUTPUT EVIDENCE_JSON")
    ref = parse_reference(Path(sys.argv[1]))
    expected_keys = [(c, n, tr) for c in (1, 2, 3) for n in (4, 6, 12, 24, 48) for tr in (1, 2)]
    missing = [k for k in expected_keys if k not in ref]
    if missing:
        raise SystemExit(f"missing FullRichards results: {missing}")

    evidence = {
        "schema_version": 1,
        "scope": "one-small-step hydraulic face-closure attribution; FullRichards SWKMEAN=1, free drainage",
        "cases": {},
        "face_sweep": face_sweep(),
        "spatial_refinement": {},
        "temporal_attribution": {},
        "tests": {},
    }

    structural_ok = True
    for case_id in (1, 2, 3):
        case_name = ref[(case_id, 4, 1)]["summary"]["name"]
        evidence["cases"][case_name] = {}
        for n in (4, 6, 12, 24, 48):
            n_ev = {}
            for tr in (1, 2):
                entry = ref[(case_id, n, tr)]
                mfp = candidate_from_faces(entry, "mfp")
                arith = candidate_from_faces(entry, "arithmetic")
                mcmp = compare_candidate(entry, mfp)
                acmp = compare_candidate(entry, arith)
                closure = face_delta(entry)
                if abs(entry.get("mass_residual", math.inf)) > 2.0e-8:
                    structural_ok = False
                if abs(mfp["mass_residual"]) > 2.0e-10 or abs(arith["mass_residual"]) > 2.0e-10:
                    structural_ok = False
                n_ev[str(tr)] = {
                    "fullrichards": entry,
                    "mfp_candidate": {"comparison": mcmp, "mass_residual": mfp["mass_residual"]},
                    "arithmetic_control": {"comparison": acmp, "mass_residual": arith["mass_residual"]},
                    "frozen_face_closure": closure,
                }
            evidence["cases"][case_name][str(n)] = n_ev

            coarse_rate = reference_theta_rate(ref[(case_id, n, 1)])
            fine_rate = reference_theta_rate(ref[(case_id, n, 2)])
            _, dz, _, _ = initial_vectors(ref[(case_id, n, 2)])
            temporal_error = weighted_metrics([a - b for a, b in zip(coarse_rate, fine_rate)], dz)
            fine_mfp = n_ev["2"]["mfp_candidate"]["comparison"]["theta_rate_error"]
            fine_arith = n_ev["2"]["arithmetic_control"]["comparison"]["theta_rate_error"]
            evidence["temporal_attribution"][f"{case_name}:n={n}"] = {
                "fullrichards_dt_to_halfdt_theta_rate_change": temporal_error,
                "fine_mfp_vs_fullrichards_theta_rate_error": fine_mfp,
                "fine_arithmetic_vs_fullrichards_theta_rate_error": fine_arith,
                "mfp_over_reference_temporal_l1": fine_mfp["weighted_l1"] / max(temporal_error["weighted_l1"], 1.0e-30),
                "arithmetic_over_reference_temporal_l1": fine_arith["weighted_l1"] / max(temporal_error["weighted_l1"], 1.0e-30),
                "mfp_over_arithmetic_error_l1": fine_mfp["weighted_l1"] / max(fine_arith["weighted_l1"], 1.0e-30),
            }

        spatial = []
        for n in (6, 12, 24, 48):
            fine = evidence["cases"][case_name][str(n)]["2"]
            spatial.append({
                "n": n,
                "dx_cm": 60.0 / n,
                "mfp_theta_rate_error": fine["mfp_candidate"]["comparison"]["theta_rate_error"],
                "arithmetic_theta_rate_error": fine["arithmetic_control"]["comparison"]["theta_rate_error"],
                "frozen_face_max_abs_delta_cm_d": fine["frozen_face_closure"]["max_abs_delta_cm_d"],
                "frozen_face_max_delta_normalized": fine["frozen_face_closure"]["max_delta_normalized"],
            })
        for i in range(1, len(spatial)):
            prev = spatial[i - 1]["mfp_theta_rate_error"]["weighted_l1"]
            cur = spatial[i]["mfp_theta_rate_error"]["weighted_l1"]
            spatial[i]["mfp_l1_reduction_from_previous"] = prev / max(cur, 1.0e-30)
        evidence["spatial_refinement"][case_name] = spatial

    anchor = {}
    for case_id in (1, 2, 3):
        name = ref[(case_id, 4, 2)]["summary"]["name"]
        fine = evidence["cases"][name]["4"]["2"]
        anchor[name] = {
            "mfp_theta_rate_error": fine["mfp_candidate"]["comparison"]["theta_rate_error"],
            "arithmetic_theta_rate_error": fine["arithmetic_control"]["comparison"]["theta_rate_error"],
            "mfp_over_arithmetic_error_l1": fine["mfp_candidate"]["comparison"]["theta_rate_error"]["weighted_l1"] /
                max(fine["arithmetic_control"]["comparison"]["theta_rate_error"]["weighted_l1"], 1.0e-30),
            "frozen_face_closure": fine["frozen_face_closure"],
        }
    evidence["four_layer_anchor_attribution"] = anchor

    evidence["tests"]["all_reference_runs_present"] = {"pass": not missing, "count": len(expected_keys)}
    evidence["tests"]["reference_mass_closure"] = {
        "pass": all(abs(ref[k].get("mass_residual", math.inf)) <= 2.0e-8 for k in expected_keys),
        "threshold": 2.0e-8,
        "max_abs": max(abs(ref[k].get("mass_residual", math.inf)) for k in expected_keys),
    }
    evidence["tests"]["candidate_mass_closure"] = {
        "pass": structural_ok,
        "threshold": 2.0e-10,
    }
    evidence["tests"]["face_sweep_solved"] = {
        "pass": evidence["face_sweep"]["failures"] == 0,
        "cases": evidence["face_sweep"]["cases"],
        "failures": evidence["face_sweep"]["failures"],
    }
    structural_ok = structural_ok and evidence["face_sweep"]["failures"] == 0
    evidence["structural_pass"] = structural_ok
    evidence["interpretation_guard"] = {
        "physical_similarity_thresholds_predeclared": False,
        "arithmetic_control_is_a_diagnostic_model": True,
        "arithmetic_control_is_not_a_layeredmfp_candidate_change": True,
        "swkmean7_behaviour_inferred": False,
        "reason": "SWAP 4.3.1 source shows table-backed Darcian mean mode 7, but the required Kavg_Szymkiewicz profile/grid tables are not present in the supplied archive."
    }

    Path(sys.argv[2]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if structural_ok else 1)


if __name__ == "__main__":
    main()
