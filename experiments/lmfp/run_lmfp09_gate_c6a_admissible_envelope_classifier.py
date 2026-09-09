from __future__ import annotations

import itertools
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c3b_offgrid_holdout as c3b
import run_lmfp09_gate_c5a_mixed_state_tail as c5a
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES

ALLOWED_CLASSES = (("reference_sand", 10.0), ("very_fast", 5.0))
ALLOWED_BASE_N = (33, 97)
BROAD_SEED = 6092026

SE_MIN_GRID = (1.0e-6, 1.0e-5, 1.0e-4, 1.0e-3, 1.0e-2, 5.0e-2, 1.0e-1)
G_MAX_GRID = (10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0, 10000.0)
DH_MAX_GRID = (10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0, 10000.0, 100000.0)
KR_MAX_GRID = (10.0, 100.0, 1000.0, 1000000.0)


def candidate_id(se_min, g_max, dh_max, kr_max):
    return f"se={se_min:g}|g={g_max:g}|dh={dh_max:g}|kr={kr_max:g}"


def broad_revealed_rows(fixture, length):
    raw = core.build_probe_rows(fixture, length, BROAD_SEED)
    kept = []
    excluded = 0
    for row in raw:
        if not (core.R_HMIN <= row["h_u"] <= core.R_HMAX and
                core.R_HMIN <= row["h_l"] <= core.R_HMAX):
            excluded += 1
            continue
        kept.append({**row, "probe_source": "C6A_NEW_BROAD_FIXED_SEED_REVEALED"})
    return kept, len(raw), excluded


def characterization_rows(fixture, length):
    broad, raw_count, excluded = broad_revealed_rows(fixture, length)
    tail, attempts = c3b.holdout_rows(fixture.material, length)
    tail = [{**row, "probe_source": "C3B_REVEALED_DRY_TO_WET"} for row in tail]
    return broad + tail, {
        "broad_seed": BROAD_SEED,
        "broad_raw_cases": raw_count,
        "broad_cases_inside_base_provider_envelope": len(broad),
        "broad_cases_outside_base_provider_envelope": excluded,
        "c3b_cases": len(tail),
        "c3b_random_sampling_attempts": attempts,
        "combined_cases": len(broad) + len(tail),
    }


def features(mat, row):
    hu, hl = row["h_u"], row["h_l"]
    seu = c5a.effective_saturation(mat, hu)
    sel = c5a.effective_saturation(mat, hl)
    ku = max(mat.conductivity(hu), 1.0e-300)
    kl = max(mat.conductivity(hl), 1.0e-300)
    return {
        "min_se": min(seu, sel),
        "max_se": max(seu, sel),
        "upper_saturated": hu >= 0.0,
        "lower_saturated": hl >= 0.0,
        "abs_g": abs(row["g"]),
        "abs_dh": abs(hl - hu),
        "k_ratio": max(ku, kl) / min(ku, kl),
    }


def evaluate_rows(view, rows):
    evaluated = []
    ks_scale = max(view.mat.conductivity(0.0), 1.0)
    for row in rows:
        feat = features(view.mat, row)
        base = {**row, "classifier_features": feat}
        try:
            qc = view.flux(row["h_u"], row["h_l"])
            qm = view.mfp.secant_k(row["h_u"], row["h_l"]) * (1.0 - row["g"])
        except Exception as exc:
            evaluated.append({**base, "failed": True,
                              "error": type(exc).__name__ + ":" + str(exc)})
            continue
        qd = row["q_ref"]
        active = abs(qd) >= row["active_floor"]
        if active:
            ec = abs(qc - qd) / abs(qd)
            em = abs(qm - qd) / abs(qd)
        else:
            ec = abs(qc - qd) / ks_scale
            em = abs(qm - qd) / ks_scale
        evaluated.append({
            **base,
            "failed": False,
            "active": active,
            "q_candidate": qc,
            "q_mfp": qm,
            "candidate_error": ec,
            "mfp_error": em,
            "sign_mismatch": active and qc * qd < 0.0,
        })
    return evaluated


def admitted(row, se_min, g_max, dh_max, kr_max):
    f = row["classifier_features"]
    return (f["min_se"] >= se_min and f["abs_g"] <= g_max and
            f["abs_dh"] <= dh_max and f["k_ratio"] <= kr_max)


def summarize(rows):
    active_corr = []
    active_mfp = []
    strong = []
    near = []
    dormant = []
    failures = 0
    sign_mismatches = 0
    informative = 0
    better = 0
    source_counts = {}
    sat_counts = {"UU": 0, "US": 0, "SU": 0, "SS": 0}

    for row in rows:
        source = row["probe_source"]
        source_counts[source] = source_counts.get(source, 0) + 1
        f = row["classifier_features"]
        sat_key = ("S" if f["upper_saturated"] else "U") + ("S" if f["lower_saturated"] else "U")
        sat_counts[sat_key] += 1
        if row.get("failed"):
            failures += 1
            continue
        if row["active"]:
            ec = row["candidate_error"]
            em = row["mfp_error"]
            active_corr.append(ec)
            active_mfp.append(em)
            if row["strong_gradient"]:
                strong.append(ec)
            if row["near_saturation"]:
                near.append(ec)
            if row["sign_mismatch"]:
                sign_mismatches += 1
            if em > 1.0e-5:
                informative += 1
                if ec < em:
                    better += 1
        else:
            dormant.append(row["candidate_error"])

    corrected = {
        "median": core.percentile(active_corr, 0.50),
        "p90": core.percentile(active_corr, 0.90),
        "p99": core.percentile(active_corr, 0.99),
        "maximum": max(active_corr) if active_corr else math.inf,
    }
    mfp = {
        "median": core.percentile(active_mfp, 0.50),
        "p90": core.percentile(active_mfp, 0.90),
        "p99": core.percentile(active_mfp, 0.99),
        "maximum": max(active_mfp) if active_mfp else math.inf,
    }
    strong_p90 = core.percentile(strong, 0.90)
    near_p90 = core.percentile(near, 0.90)
    dormant_max = max(dormant) if dormant else 0.0
    better_fraction = better / informative if informative else 1.0

    checks = {
        "failures_zero": failures == 0,
        "sign_mismatches_zero": sign_mismatches == 0,
        "active_p90_lt_0p02": corrected["p90"] < 0.02,
        "active_p99_lt_0p10": corrected["p99"] < 0.10,
        "active_max_lt_0p30": corrected["maximum"] < 0.30,
        "strong_gradient_p90_lt_0p02": strong_p90 < 0.02,
        "near_saturation_p90_lt_0p02": near_p90 < 0.02,
        "dormant_scaled_abs_lt_1e_7": dormant_max < 1.0e-7,
        "corrected_p90_better_than_plain_mfp": corrected["p90"] < mfp["p90"],
        "fraction_better_ge_0p75": better_fraction >= 0.75,
    }
    return {
        "pass": all(checks.values()),
        "checks": checks,
        "cases": len(rows),
        "active_cases": len(active_corr),
        "dormant_cases": len(dormant),
        "failures": failures,
        "sign_mismatches": sign_mismatches,
        "corrected_active_rel_error": corrected,
        "mfp_active_rel_error": mfp,
        "strong_gradient_corrected_p90_rel_error": strong_p90,
        "near_saturation_corrected_p90_rel_error": near_p90,
        "dormant_max_abs_error_over_ks_scale": dormant_max,
        "informative_mfp_cases": informative,
        "fraction_corrected_better_on_informative_cases": better_fraction,
        "source_counts": source_counts,
        "saturation_regime_counts": sat_counts,
    }


def main():
    if len(sys.argv) != 5:
        raise SystemExit("usage: run_lmfp09_gate_c6a_admissible_envelope_classifier.py EVIDENCE_JSON MATERIAL HALF_FACE_LENGTH_CM BASE_N")
    out = Path(sys.argv[1])
    material_name = sys.argv[2]
    length = float(sys.argv[3])
    base_n = int(sys.argv[4])
    if (material_name, length) not in ALLOWED_CLASSES:
        raise SystemExit(("unsupported_precommitted_class", material_name, length))
    if base_n not in ALLOWED_BASE_N:
        raise SystemExit(("unsupported_precommitted_provider_base_n", base_n))

    fixture = {f.name: f for f in FIXTURES}[material_name]
    c3.BASE_N = base_n
    ep.bracket = c3.tolerant_bracket

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C6A_ADMISSIBLE_ENVELOPE_CLASSIFIER_CHARACTERIZATION",
        "qualification": False,
        "material": material_name,
        "half_face_length_cm": length,
        "provider_base_n": base_n,
        "provider_family": "ANCHORED_HEAD_PAIR",
        "new_broad_characterization_seed": BROAD_SEED,
        "new_broad_sample_is_revealed_not_holdout": True,
        "thresholds_changed": False,
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    view, oracle_solves, _ = c3.build_provider(fixture, length)
    evidence["provider"] = {
        "actual_axis_nodes": view.nx,
        "table_values": view.memory()["values"],
        "bytes_before_metadata": view.memory()["bytes_before_metadata"],
        "offline_oracle_solves": oracle_solves,
    }
    evidence["stage"] = "REVEALED_CHARACTERIZATION_SET_GENERATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    probes, probe_info = characterization_rows(fixture, length)
    evidence["characterization_set"] = probe_info
    evidence["stage"] = "ONE_TIME_PROVIDER_EVALUATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    evaluated = evaluate_rows(view, probes)
    baseline = summarize(evaluated)

    evidence["stage"] = "PRECOMMITTED_GRID_SEARCH"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    passing = {}
    top_details = []
    tested = 0
    for se_min, g_max, dh_max, kr_max in itertools.product(SE_MIN_GRID, G_MAX_GRID, DH_MAX_GRID, KR_MAX_GRID):
        tested += 1
        subset = [r for r in evaluated if admitted(r, se_min, g_max, dh_max, kr_max)]
        if not subset:
            continue
        summary = summarize(subset)
        if not summary["pass"]:
            continue
        cid = candidate_id(se_min, g_max, dh_max, kr_max)
        fraction = len(subset) / len(evaluated)
        passing[cid] = fraction
        top_details.append({
            "classifier_id": cid,
            "thresholds": {"min_se": se_min, "g_max": g_max, "dh_max_cm": dh_max, "k_ratio_max": kr_max},
            "admitted_fraction": fraction,
            "metrics": summary,
        })

    top_details.sort(key=lambda x: (-x["admitted_fraction"], x["classifier_id"]))
    top_details = top_details[:25]
    evidence.update({
        "baseline_without_classifier": baseline,
        "classifier_grid": {
            "tested_candidates": tested,
            "passing_candidates": len(passing),
            "passing_admitted_fraction_by_id": passing,
            "top_25_by_admitted_fraction": top_details,
        },
        "status": "COMPLETED",
        "stage": "COMPLETE",
        "decision": (
            "C6A_CLASS_HAS_PASSING_SIMPLE_ENVELOPES_AGGREGATE_ACROSS_CLASSES_BEFORE_ANY_C6B"
            if passing else
            "C6A_CLASS_HAS_NO_PASSING_SIMPLE_ENVELOPE"
        ),
    })
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material_name,
        "half_face_length_cm": length,
        "provider": evidence["provider"],
        "characterization_set": probe_info,
        "baseline_pass": baseline["pass"],
        "tested_candidates": tested,
        "passing_candidates": len(passing),
        "top_5": top_details[:5],
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
