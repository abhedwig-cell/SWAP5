from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_vzaa01_d0_donor_separability as d0

FULLRICHARDS_MASS_THRESHOLD_CM = 2.0e-8
CANDIDATE_MASS_THRESHOLD_CM = 2.0e-10
STRESS_REFERENCE_MASS_THRESHOLD_CM = 2.0e-10
LEDGER_IDENTITY_THRESHOLD_CM_D = 1.0e-10


def rms(values):
    if not values:
        return None
    return math.sqrt(math.fsum(v * v for v in values) / len(values))


def mean_abs(values):
    if not values:
        return None
    return math.fsum(abs(v) for v in values) / len(values)


def safe_fraction(num, den):
    return num / den if den else None


def safe_ratio(num, den):
    if num is None or den is None or den == 0.0:
        return None
    return num / den


def safe_difference(a, b):
    if a is None or b is None:
        return None
    return a - b


def summarize_subset(rows):
    ok = [r for r in rows if r["diagnostic_ok"]]
    ev = [r["e_vzaa"] for r in ok]
    el = [r["e_lmfp"] for r in ok]
    closer = sum(abs(r["e_vzaa"]) < abs(r["e_lmfp"]) for r in ok)
    tied = sum(abs(r["e_vzaa"]) == abs(r["e_lmfp"]) for r in ok)
    direction = [
        r for r in ok
        if abs(r["e_needed"]) > d0.NUMERICAL_DIRECTION_FLOOR
        and abs(r["delta_q"]) > d0.NUMERICAL_DIRECTION_FLOOR
    ]
    sign_match = sum(r["e_needed"] * r["delta_q"] > 0.0 for r in direction)
    switches = 0
    regimes = defaultdict(list)
    for r in ok:
        regimes[r["layer"]].append((r["step"], r["c_regime"]))
    for values in regimes.values():
        values.sort()
        switches += sum(values[j][1] != values[j - 1][1] for j in range(1, len(values)))
    return {
        "rows_total": len(rows),
        "diagnostic_rows": len(ok),
        "diagnostic_failures": len(rows) - len(ok),
        "vzaa_rmse_cm_d": rms(ev),
        "lmfp_rmse_cm_d": rms(el),
        "vzaa_mae_cm_d": mean_abs(ev),
        "lmfp_mae_cm_d": mean_abs(el),
        "vzaa_closer_fraction": safe_fraction(closer, len(ok)),
        "equal_abs_error_fraction": safe_fraction(tied, len(ok)),
        "direction_compared": len(direction),
        "delta_q_direction_match_fraction": safe_fraction(sign_match, len(direction)),
        "h_regime_switches": switches,
        "max_history_length": max((r["history_length"] for r in rows), default=0),
        "max_raw_theta_history_bytes_per_layer": max((r["history_bytes_raw"] for r in rows), default=0),
    }


def structural_mass_gate(rows):
    candidate = [abs(r["candidate_mass_residual"]) for r in rows]
    ordinary_ref = [
        abs(r["reference_mass_residual"]) for r in rows
        if r["reference_family"] == "fullrichards_accepted_ledger"
    ]
    stress_ref = [
        abs(r["reference_mass_residual"]) for r in rows
        if r["reference_family"] == "direct_darcian_conservative_oracle"
    ]
    ledger_identity = []
    for r in rows:
        if r["reference_family"] != "fullrichards_accepted_ledger":
            continue
        gap = r["reference_bottom_ledger_gap"]
        if gap is None:
            continue
        ledger_identity.append(abs(gap + r["reference_mass_residual"] / r["dt"]))
    candidate_max = max(candidate, default=0.0)
    ordinary_max = max(ordinary_ref, default=0.0)
    stress_max = max(stress_ref, default=0.0)
    ledger_max = max(ledger_identity, default=0.0)
    passed = (
        candidate_max <= CANDIDATE_MASS_THRESHOLD_CM
        and ordinary_max <= FULLRICHARDS_MASS_THRESHOLD_CM
        and stress_max <= STRESS_REFERENCE_MASS_THRESHOLD_CM
        and ledger_max <= LEDGER_IDENTITY_THRESHOLD_CM_D
    )
    return {
        "pass": passed,
        "candidate_max_abs_mass_residual_cm": candidate_max,
        "candidate_threshold_cm": CANDIDATE_MASS_THRESHOLD_CM,
        "ordinary_fullrichards_max_abs_mass_residual_cm": ordinary_max,
        "ordinary_fullrichards_threshold_cm": FULLRICHARDS_MASS_THRESHOLD_CM,
        "stress_direct_darcian_max_abs_mass_residual_cm": stress_max,
        "stress_direct_darcian_threshold_cm": STRESS_REFERENCE_MASS_THRESHOLD_CM,
        "fullrichards_ledger_identity_max_abs_cm_d": ledger_max,
        "fullrichards_ledger_identity_threshold_cm_d": LEDGER_IDENTITY_THRESHOLD_CM_D,
    }


def build_summary(rows, failures, caches):
    grouped = defaultdict(list)
    for row in rows:
        grouped[(row["reference_family"], row["case"], row["refinement"])].append(row)

    cases = {}
    for (family, case, refinement), values in grouped.items():
        key = f"{family}:{case}"
        cases.setdefault(key, {"reference_family": family, "case": case, "refinements": {}})
        final_time = max(row["time"] for row in values)
        cases[key]["refinements"][str(refinement)] = {
            "all": summarize_subset(values),
            "first_step": summarize_subset([row for row in values if row["step"] == 1]),
            "early_first_quarter": summarize_subset([row for row in values if row["time"] <= 0.25 * final_time]),
            "later_after_first_quarter": summarize_subset([row for row in values if row["time"] > 0.25 * final_time]),
        }

    refinement_characterization = {}
    for key, item in cases.items():
        if "1" not in item["refinements"] or "2" not in item["refinements"]:
            continue
        coarse = item["refinements"]["1"]["all"]
        fine = item["refinements"]["2"]["all"]
        refinement_characterization[key] = {
            "vzaa_rmse_fine_over_coarse": safe_ratio(fine["vzaa_rmse_cm_d"], coarse["vzaa_rmse_cm_d"]),
            "lmfp_rmse_fine_over_coarse": safe_ratio(fine["lmfp_rmse_cm_d"], coarse["lmfp_rmse_cm_d"]),
            "vzaa_closer_fraction_change": safe_difference(fine["vzaa_closer_fraction"], coarse["vzaa_closer_fraction"]),
            "direction_match_fraction_change": safe_difference(
                fine["delta_q_direction_match_fraction"],
                coarse["delta_q_direction_match_fraction"],
            ),
        }

    diagnostic_failures = [
        {k: row[k] for k in ("case", "reference_family", "refinement", "step", "layer", "diagnostic_failure")}
        for row in rows if not row["diagnostic_ok"]
    ]
    ordinary = [row for row in rows if row["reference_family"] == "fullrichards_accepted_ledger"]
    stress = [row for row in rows if row["reference_family"] == "direct_darcian_conservative_oracle"]
    mass_gate = structural_mass_gate(rows)
    execution_complete = len(failures) == 0 and mass_gate["pass"]

    return {
        "schema_version": 2,
        "work_unit": "F-VZAA01-D0",
        "stage": "D0-A",
        "candidate": "F-LMFP08_CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO",
        "history_operator": "literal Eq. 5 midpoint sum copied from H0-qualified implementation sha ed785a5e2a89ab2f6cdb8cac5255b2f047de708b",
        "vzaa_hydraulics": "published VG Eqs. 15 and 17",
        "vzaa_flux": "deep-groundwater specialization of Eq. 3: q=-sqrt(cD)H+K",
        "scientific_pass_threshold": None,
        "structural_mass_thresholds": "inherited from existing F-LMFP04/F-LMFP07 gates; not donor-accuracy tolerances",
        "numerical_direction_floor": d0.NUMERICAL_DIRECTION_FLOOR,
        "segment_definition": "early_first_quarter means time <= 0.25*case_duration; descriptive only",
        "reference_families": {
            "ordinary": summarize_subset(ordinary),
            "stress": summarize_subset(stress),
        },
        "cases": cases,
        "refinement_characterization": refinement_characterization,
        "execution_failures": failures,
        "diagnostic_failures": diagnostic_failures,
        "candidate_cache_diagnostics": caches,
        "structural_mass_gate": mass_gate,
        "execution_complete": execution_complete,
        "scientific_decision": "UNSET_CHARACTERIZATION_REQUIRES_EVIDENCE_REVIEW",
        "production_admission": "NONE",
    }


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: run_vzaa01_d0_gate_driver.py FULLRICHARDS_TRAJECTORY SUMMARY_JSON ROWS_JSONL")
    reference = d0.parse_fullrichards_trajectory(Path(sys.argv[1]))
    ordinary_rows, ordinary_failures, ordinary_cache = d0.run_ordinary(reference)
    stress_rows, stress_failures, stress_cache = d0.run_stress()
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
