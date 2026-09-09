from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
LMFP = HERE.parent / "lmfp"
if str(LMFP) not in sys.path:
    sys.path.insert(0, str(LMFP))

import run_lmfp08_physics_informed_correction as lmfp08_core
from run_lmfp08_constrained_mfp_ratio import ConstrainedMFPCache
from run_lmfp04_ab import DZ, SAND, CLAY, case_definition
from run_lmfp07_transient_abc import STRESS, candidate_trial

MATERIAL_BY_CODE = {1: SAND, 2: CLAY}
SQRT_PI = math.sqrt(math.pi)
NUMERICAL_DIRECTION_FLOOR = 1.0e-12


def literal_eq5(times, theta):
    """Exact copy of the H0-qualified literal midpoint Eq. 5 operator."""
    if len(times) != len(theta):
        raise ValueError("times_theta_length_mismatch")
    if len(times) < 2:
        raise ValueError("at_least_one_interval_required")
    for j in range(len(times) - 1):
        if not times[j + 1] > times[j]:
            raise ValueError(("times_not_strictly_increasing", j, times[j], times[j + 1]))
    tn = times[-1]
    terms = []
    for j in range(len(times) - 1):
        midpoint = 0.5 * (times[j] + times[j + 1])
        lag = tn - midpoint
        if not lag > 0.0:
            raise ValueError(("nonpositive_midpoint_lag", j, lag))
        terms.append((theta[j + 1] - theta[j]) / math.sqrt(lag))
    return -math.fsum(terms) / SQRT_PI


def vg_parameters(mat):
    c = mat.c
    return {
        "theta_r": c[1],
        "theta_s": c[2],
        "Ks": c[3],
        "alpha": c[4],
        "n": c[6],
        "m": c[7],
    }


def published_vg_k_d(mat, theta):
    """Sadeghi et al. (2026) Eqs. 15 and 17, without clipping."""
    p = vg_parameters(mat)
    span = p["theta_s"] - p["theta_r"]
    s = (theta - p["theta_r"]) / span
    if not (0.0 < s < 1.0):
        raise ValueError(("effective_saturation_outside_open_unit_interval", s, theta))
    m = p["m"]
    u = 1.0 - s ** (1.0 / m)
    if not u > 0.0:
        raise ValueError(("vg_inner_term_nonpositive", u, s))
    kval = p["Ks"] * s ** 0.5 * (1.0 - u ** m) ** 2
    diffusivity = ((1.0 - m) * p["Ks"] / (p["alpha"] * m * span)) * (
        s ** (0.5 - 1.0 / m)
    ) * (u ** (-m) + u ** m - 2.0)
    if not math.isfinite(kval) or not math.isfinite(diffusivity) or diffusivity < 0.0:
        raise ValueError(("nonfinite_or_negative_published_vg_hydraulics", kval, diffusivity, s))
    return s, kval, diffusivity


def parse_fullrichards_trajectory(path):
    out = {}
    for raw in Path(path).read_text().splitlines():
        parts = raw.split()
        if not parts:
            continue
        if parts[0] == "D0STEP":
            cid, refinement, step = map(int, parts[1:4])
            key = (cid, refinement)
            item = out.setdefault(key, {"steps": {}})
            item["steps"][step] = {
                "dt": float(parts[4]),
                "top_up": float(parts[5]),
                "bottom_up": float(parts[6]),
                "mass_residual": float(parts[7]),
                "nonlinear_iterations": int(parts[8]),
                "nodes": {},
            }
        elif parts[0] == "D0NODE":
            cid, refinement, step, node = map(int, parts[1:5])
            key = (cid, refinement)
            item = out.setdefault(key, {"steps": {}})
            st = item["steps"].setdefault(step, {"nodes": {}})
            st.setdefault("nodes", {})[node] = {
                "theta_old": float(parts[5]),
                "theta_new": float(parts[6]),
                "head_new": float(parts[7]),
            }
    return out


def reconstruct_ledger_faces(step, thickness):
    q = [-step["top_up"]]
    for i, dz in enumerate(thickness, start=1):
        node = step["nodes"][i]
        delta_s = dz * (node["theta_new"] - node["theta_old"])
        q.append(q[-1] - delta_s / step["dt"])
    bottom_reported = -step["bottom_up"]
    return q, q[-1] - bottom_reported


def row_for_layer(*, case, reference_family, refinement, step_index, time, dt, layer,
                  mat, theta_old_candidate, theta_new_candidate, theta_new_reference,
                  candidate_faces, reference_faces, candidate_mass_residual,
                  reference_mass_residual, history_times, history_theta,
                  reference_bottom_ledger_gap=None):
    row = {
        "case": case,
        "reference_family": reference_family,
        "refinement": refinement,
        "step": step_index,
        "time": time,
        "dt": dt,
        "layer": layer + 1,
        "theta_old_candidate": theta_old_candidate,
        "theta_new_candidate": theta_new_candidate,
        "theta_new_reference": theta_new_reference,
        "candidate_face_top": candidate_faces[layer],
        "candidate_face_bottom": candidate_faces[layer + 1],
        "candidate_mid_flux": 0.5 * (candidate_faces[layer] + candidate_faces[layer + 1]),
        "reference_face_top": reference_faces[layer],
        "reference_face_bottom": reference_faces[layer + 1],
        "reference_mid_flux": 0.5 * (reference_faces[layer] + reference_faces[layer + 1]),
        "candidate_mass_residual": candidate_mass_residual,
        "reference_mass_residual": reference_mass_residual,
        "reference_bottom_ledger_gap": reference_bottom_ledger_gap,
        "history_length": len(history_theta),
        "history_bytes_raw": 8 * len(history_theta),
        "history_eval_terms": len(history_theta) - 1,
        "diagnostic_ok": False,
        "diagnostic_failure": None,
    }
    try:
        hval = literal_eq5(history_times, history_theta)
        cfac = 0.5 if hval <= 0.0 else 2.0
        s, kval, diff = published_vg_k_d(mat, theta_new_candidate)
        qhist = -math.sqrt(cfac * diff) * hval
        qsteady = kval
        qvzaa = qhist + qsteady
        qlmfp = row["candidate_mid_flux"]
        qref = row["reference_mid_flux"]
        row.update({
            "H_literal_eq5": hval,
            "c_regime": "wetting_or_zero" if hval <= 0.0 else "drying",
            "c_value": cfac,
            "effective_saturation": s,
            "K_theta": kval,
            "D_theta": diff,
            "q_hist": qhist,
            "q_steady": qsteady,
            "q_vzaa_mid": qvzaa,
            "e_vzaa": qvzaa - qref,
            "e_lmfp": qlmfp - qref,
            "delta_q": qvzaa - qlmfp,
            "e_needed": qref - qlmfp,
            "diagnostic_ok": True,
        })
    except (ValueError, OverflowError, ZeroDivisionError) as exc:
        row["diagnostic_failure"] = repr(exc)
    return row


def run_ordinary(reference):
    rows = []
    execution_failures = []
    cache_diag = {}
    for case_id in range(1, 5):
        name, codes, heads0, duration, base_dt, top_down = case_definition(case_id)
        mats = [MATERIAL_BY_CODE[c] for c in codes]
        for refinement in (1, 2):
            key = (case_id, refinement)
            if key not in reference:
                execution_failures.append({"case": name, "refinement": refinement, "reason": "missing_fullrichards_reference"})
                continue
            dt = base_dt / refinement
            nsteps = round(duration / dt)
            ref_steps = reference[key]["steps"]
            if set(ref_steps) != set(range(1, nsteps + 1)):
                execution_failures.append({"case": name, "refinement": refinement, "reason": "incomplete_fullrichards_steps"})
                continue
            cache = ConstrainedMFPCache()
            state = [m.theta(h) * dz for m, h, dz in zip(mats, heads0, DZ)]
            initial_theta = [w / dz for w, dz in zip(state, DZ)]
            times = [0.0]
            histories = [[t] for t in initial_theta]
            for step_index in range(1, nsteps + 1):
                base_state = list(state)
                trial = lmfp08_core.corrected_trial(state, codes, DZ, dt, top_down, cache)
                if not trial["accepted"]:
                    execution_failures.append({"case": name, "refinement": refinement, "step": step_index,
                                               "reason": "candidate:" + trial["reason"]})
                    break
                state = trial["state"]
                theta_new = [w / dz for w, dz in zip(state, DZ)]
                theta_old = [w / dz for w, dz in zip(base_state, DZ)]
                now = step_index * dt
                times.append(now)
                for i, value in enumerate(theta_new):
                    histories[i].append(value)
                ref = ref_steps[step_index]
                ref_faces, bottom_gap = reconstruct_ledger_faces(ref, DZ)
                for i, mat in enumerate(mats):
                    rows.append(row_for_layer(
                        case=name, reference_family="fullrichards_accepted_ledger",
                        refinement=refinement, step_index=step_index, time=now, dt=dt, layer=i,
                        mat=mat, theta_old_candidate=theta_old[i], theta_new_candidate=theta_new[i],
                        theta_new_reference=ref["nodes"][i + 1]["theta_new"],
                        candidate_faces=trial["face"], reference_faces=ref_faces,
                        candidate_mass_residual=trial["mass_residual"],
                        reference_mass_residual=ref["mass_residual"],
                        history_times=times, history_theta=histories[i],
                        reference_bottom_ledger_gap=bottom_gap,
                    ))
            cache_diag[f"{name}:r{refinement}"] = cache.diagnostics()
    return rows, execution_failures, cache_diag


def run_stress():
    rows = []
    execution_failures = []
    cache_diag = {}
    for name, codes, heads0, thickness in STRESS:
        mats = [MATERIAL_BY_CODE[c] for c in codes]
        duration = 1.0e-4
        base_dt = 1.0e-5
        for refinement in (1, 2):
            dt = base_dt / refinement
            nsteps = round(duration / dt)
            ref_state = [m.theta(h) * dz for m, h, dz in zip(mats, heads0, thickness)]
            cand_state = list(ref_state)
            initial_theta = [w / dz for w, dz in zip(cand_state, thickness)]
            times = [0.0]
            histories = [[t] for t in initial_theta]
            cache = ConstrainedMFPCache()
            for step_index in range(1, nsteps + 1):
                cand_base = list(cand_state)
                ref_trial = candidate_trial(ref_state, codes, thickness, dt, 0.0, "oracle")
                cand_trial = lmfp08_core.corrected_trial(cand_state, codes, thickness, dt, 0.0, cache)
                if not ref_trial["accepted"] or not cand_trial["accepted"]:
                    execution_failures.append({
                        "case": name, "refinement": refinement, "step": step_index,
                        "reason": f"reference={ref_trial['reason']};candidate={cand_trial['reason']}",
                    })
                    break
                ref_state = ref_trial["state"]
                cand_state = cand_trial["state"]
                theta_new_c = [w / dz for w, dz in zip(cand_state, thickness)]
                theta_old_c = [w / dz for w, dz in zip(cand_base, thickness)]
                theta_new_r = [w / dz for w, dz in zip(ref_state, thickness)]
                now = step_index * dt
                times.append(now)
                for i, value in enumerate(theta_new_c):
                    histories[i].append(value)
                for i, mat in enumerate(mats):
                    rows.append(row_for_layer(
                        case=name, reference_family="direct_darcian_conservative_oracle",
                        refinement=refinement, step_index=step_index, time=now, dt=dt, layer=i,
                        mat=mat, theta_old_candidate=theta_old_c[i], theta_new_candidate=theta_new_c[i],
                        theta_new_reference=theta_new_r[i], candidate_faces=cand_trial["face"],
                        reference_faces=ref_trial["face"],
                        candidate_mass_residual=cand_trial["mass_residual"],
                        reference_mass_residual=ref_trial["mass_residual"],
                        history_times=times, history_theta=histories[i],
                    ))
            cache_diag[f"{name}:r{refinement}"] = cache.diagnostics()
    return rows, execution_failures, cache_diag


def rms(values):
    return math.sqrt(math.fsum(v * v for v in values) / len(values)) if values else math.nan


def mean_abs(values):
    return math.fsum(abs(v) for v in values) / len(values) if values else math.nan


def summarize_subset(rows):
    ok = [r for r in rows if r["diagnostic_ok"]]
    ev = [r["e_vzaa"] for r in ok]
    el = [r["e_lmfp"] for r in ok]
    closer = sum(abs(r["e_vzaa"]) < abs(r["e_lmfp"]) for r in ok)
    tied = sum(abs(r["e_vzaa"]) == abs(r["e_lmfp"]) for r in ok)
    direction = [r for r in ok if abs(r["e_needed"]) > NUMERICAL_DIRECTION_FLOOR and abs(r["delta_q"]) > NUMERICAL_DIRECTION_FLOOR]
    sign_match = sum(r["e_needed"] * r["delta_q"] > 0.0 for r in direction)
    switches = 0
    regimes = defaultdict(list)
    for r in ok:
        regimes[(r["layer"])].append((r["step"], r["c_regime"]))
    for vals in regimes.values():
        vals.sort()
        switches += sum(vals[j][1] != vals[j - 1][1] for j in range(1, len(vals)))
    return {
        "rows_total": len(rows),
        "diagnostic_rows": len(ok),
        "diagnostic_failures": len(rows) - len(ok),
        "vzaa_rmse_cm_d": rms(ev),
        "lmfp_rmse_cm_d": rms(el),
        "vzaa_mae_cm_d": mean_abs(ev),
        "lmfp_mae_cm_d": mean_abs(el),
        "vzaa_closer_fraction": closer / len(ok) if ok else math.nan,
        "equal_abs_error_fraction": tied / len(ok) if ok else math.nan,
        "direction_compared": len(direction),
        "delta_q_direction_match_fraction": sign_match / len(direction) if direction else math.nan,
        "h_regime_switches": switches,
        "max_history_length": max((r["history_length"] for r in rows), default=0),
        "max_raw_theta_history_bytes_per_layer": max((r["history_bytes_raw"] for r in rows), default=0),
    }


def build_summary(rows, failures, caches):
    grouped = defaultdict(list)
    for r in rows:
        grouped[(r["reference_family"], r["case"], r["refinement"])].append(r)
    cases = {}
    for (family, case, refinement), vals in grouped.items():
        key = f"{family}:{case}"
        cases.setdefault(key, {"reference_family": family, "case": case, "refinements": {}})
        full = summarize_subset(vals)
        first = summarize_subset([r for r in vals if r["step"] == 1])
        final_time = max(r["time"] for r in vals)
        early = summarize_subset([r for r in vals if r["time"] <= 0.25 * final_time])
        later = summarize_subset([r for r in vals if r["time"] > 0.25 * final_time])
        cases[key]["refinements"][str(refinement)] = {
            "all": full,
            "first_step": first,
            "early_first_quarter": early,
            "later_after_first_quarter": later,
        }
    refinement_characterization = {}
    for key, item in cases.items():
        if "1" in item["refinements"] and "2" in item["refinements"]:
            a = item["refinements"]["1"]["all"]
            b = item["refinements"]["2"]["all"]
            refinement_characterization[key] = {
                "vzaa_rmse_fine_over_coarse": b["vzaa_rmse_cm_d"] / a["vzaa_rmse_cm_d"] if a["vzaa_rmse_cm_d"] else None,
                "lmfp_rmse_fine_over_coarse": b["lmfp_rmse_cm_d"] / a["lmfp_rmse_cm_d"] if a["lmfp_rmse_cm_d"] else None,
                "vzaa_closer_fraction_change": b["vzaa_closer_fraction"] - a["vzaa_closer_fraction"],
                "direction_match_fraction_change": (
                    b["delta_q_direction_match_fraction"] - a["delta_q_direction_match_fraction"]
                    if math.isfinite(a["delta_q_direction_match_fraction"]) and math.isfinite(b["delta_q_direction_match_fraction"])
                    else None
                ),
            }
    diag_failures = [
        {k: r[k] for k in ("case", "reference_family", "refinement", "step", "layer", "diagnostic_failure")}
        for r in rows if not r["diagnostic_ok"]
    ]
    ordinary = [r for r in rows if r["reference_family"] == "fullrichards_accepted_ledger"]
    stress = [r for r in rows if r["reference_family"] == "direct_darcian_conservative_oracle"]
    return {
        "schema_version": 1,
        "work_unit": "F-VZAA01-D0",
        "stage": "D0-A",
        "candidate": "F-LMFP08_CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO",
        "history_operator": "literal Eq. 5 midpoint sum copied from H0-qualified implementation sha ed785a5e2a89ab2f6cdb8cac5255b2f047de708b",
        "vzaa_hydraulics": "published VG Eqs. 15 and 17",
        "vzaa_flux": "deep-groundwater specialization of Eq. 3: q=-sqrt(cD)H+K",
        "scientific_pass_threshold": None,
        "numerical_direction_floor": NUMERICAL_DIRECTION_FLOOR,
        "segment_definition": "early_first_quarter means time <= 0.25*case_duration; descriptive only",
        "reference_families": {
            "ordinary": summarize_subset(ordinary),
            "stress": summarize_subset(stress),
        },
        "cases": cases,
        "refinement_characterization": refinement_characterization,
        "execution_failures": failures,
        "diagnostic_failures": diag_failures,
        "candidate_cache_diagnostics": caches,
        "execution_complete": len(failures) == 0,
        "scientific_decision": "UNSET_CHARACTERIZATION_REQUIRES_EVIDENCE_REVIEW",
        "production_admission": "NONE",
    }


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: run_vzaa01_d0_donor_separability.py FULLRICHARDS_TRAJECTORY SUMMARY_JSON ROWS_JSONL")
    reference = parse_fullrichards_trajectory(Path(sys.argv[1]))
    ordinary_rows, ordinary_failures, ordinary_cache = run_ordinary(reference)
    stress_rows, stress_failures, stress_cache = run_stress()
    rows = ordinary_rows + stress_rows
    failures = ordinary_failures + stress_failures
    summary = build_summary(rows, failures, {**ordinary_cache, **stress_cache})
    Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False) + "\n")
    with Path(sys.argv[3]).open("w") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps(summary, indent=2, sort_keys=True, allow_nan=False))
    if not summary["execution_complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
