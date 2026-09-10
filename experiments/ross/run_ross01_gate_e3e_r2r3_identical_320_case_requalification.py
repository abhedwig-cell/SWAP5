from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_r2r2_fresh_5cm_reference_characterization as frozen
import run_ross01_gate_e3e_r2r2_r2_analytic_saturated_segment_candidate as r2
import run_ross01_gate_e3e_r2r2_r3_physical_envelope_upper_snap as r3

CONTRACT = "F-ROSS01_GATE_E3E_R2R3_IDENTICAL_320_CASE_FRESH_REQUALIFICATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
EXPECTED = 80
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_MAX = 0.0005
MAX_K = 530
MAX_ROOT = 66
REF_RES = 1.0e-8
CROSS_Q = 1.0e-9
ENDPOINT_Q = 1.0e-12
CROSSCHECK_IDS = frozen.CROSSCHECK_IDS
FORMER_FAILURES = {"B01": "fresh_near_0023", "O14": "fresh_near_0003"}


def primary_reference(hs: float, ht: float, row: dict) -> dict:
    if hs == 0.0:
        return frozen.reference_b(hs, ht, row)
    q, residual = r2.reference_b(hs, ht, row)
    return {
        "q": float(q),
        "branch": "INTERIOR_ROOT",
        "residual_cm": float(residual),
        "log10_delta": None,
        "endpoint_path_cm": None,
        "plateau_length_cm": None,
    }


def cross_reference(hs: float, ht: float, row: dict) -> dict:
    if hs == 0.0:
        return frozen.reference_a(hs, ht, row)
    q, residual = r2.reference_a(hs, ht, row)
    return {"q": float(q), "branch": "INTERIOR_ROOT", "residual_cm": float(residual)}


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    r2.old_e3e.configure_5cm(row)
    ksat = float(r2.old_e3e.e2c.c1.core.KSAT)
    probes = frozen.build_fresh(material)
    old_pairs = {(float(p["h_surface"]), float(p["h_top_node"])) for p in frozen.old_e3e.build_probes(material)}
    fresh_pairs = {(float(p["h_surface"]), float(p["h_top_node"])) for p in probes}
    overlap = sorted(old_pairs & fresh_pairs)

    rows = []
    ref_failures = []
    unresolved = 0
    nonfinite = 0
    crosschecks = []
    max_k = 0
    max_root = 0
    snap_count = 0

    for p in probes:
        hs = float(p["h_surface"])
        ht = float(p["h_top_node"])
        try:
            ref = primary_reference(hs, ht, row)
        except Exception as exc:
            ref_failures.append({"probe_id": p["id"], "error": repr(exc)})
            continue
        if not (math.isfinite(ref["q"]) and math.isfinite(ref["residual_cm"])):
            ref_failures.append({"probe_id": p["id"], "error": "nonfinite_reference"})
            continue
        if abs(ref["residual_cm"]) > REF_RES:
            ref_failures.append({"probe_id": p["id"], "error": "reference_path_residual", "residual_cm": ref["residual_cm"]})
            continue

        try:
            qc, cost, cert = r3.candidate_with_envelope(hs, ht)
        except RuntimeError as exc:
            unresolved += 1
            rows.append({
                "probe_id": p["id"], "family": p["family"], "h_surface": hs, "h_top_node": ht,
                "q_reference": ref["q"], "reference_branch": ref["branch"], "candidate_error": repr(exc)
            })
            continue
        except (FloatingPointError, OverflowError, ValueError) as exc:
            nonfinite += 1
            rows.append({
                "probe_id": p["id"], "family": p["family"], "h_surface": hs, "h_top_node": ht,
                "q_reference": ref["q"], "reference_branch": ref["branch"], "candidate_error": repr(exc)
            })
            continue

        qc = float(qc)
        if not math.isfinite(qc):
            nonfinite += 1
            continue
        hybrid, absolute, wrong = r2.old_e3e.e2c._metric(float(ref["q"]), qc, ksat)
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        is_snap = cost["branch"] == "SURFACE_SATURATED_PHYSICAL_ENVELOPE_UPPER_SNAP"
        snap_count += int(is_snap)

        endpoint_q_error = None
        if str(ref["branch"]).startswith("ENDPOINT_KSAT"):
            endpoint_q_error = abs(qc - ksat) / ksat

        snap_tests = None
        if is_snap:
            if cert is None:
                raise AssertionError("snap_without_certificate")
            snap_tests = {
                "theorem_abs_bound": cert["abs_error_bound_over_ksat"] <= ABS_MAX,
                "theorem_hybrid_bound": cert["hybrid_error_bound"] <= HYBRID_MAX,
                "actual_abs_inside_theorem": absolute <= cert["abs_error_bound_over_ksat"] + 64.0 * sys.float_info.epsilon,
                "actual_hybrid_inside_theorem": hybrid <= cert["hybrid_error_bound"] + 64.0 * sys.float_info.epsilon,
            }

        row_out = {
            "probe_id": p["id"],
            "family": p["family"],
            "h_surface": hs,
            "h_top_node": ht,
            "q_reference": float(ref["q"]),
            "reference_branch": ref["branch"],
            "reference_path_residual_cm": ref["residual_cm"],
            "reference_endpoint_path_cm": ref.get("endpoint_path_cm"),
            "reference_plateau_length_cm": ref.get("plateau_length_cm"),
            "q_candidate": qc,
            "candidate_branch": str(cost["branch"]),
            "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute,
            "wrong_sign": wrong,
            "endpoint_candidate_abs_error_over_ksat": endpoint_q_error,
            "physical_envelope": cert,
            "snap_tests": snap_tests,
            "root_residual_evaluations": int(cost["root_residual_evaluations"]),
            "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
        }
        rows.append(row_out)

        if p["id"] in CROSSCHECK_IDS:
            try:
                a = cross_reference(hs, ht, row)
                qdiff = abs(float(a["q"]) - float(ref["q"])) / ksat
                crosschecks.append({
                    "probe_id": p["id"],
                    "family": p["family"],
                    "oracle_a_q": a["q"],
                    "oracle_b_q": ref["q"],
                    "oracle_a_branch": a["branch"],
                    "oracle_b_branch": ref["branch"],
                    "oracle_a_path_residual_cm": a["residual_cm"],
                    "oracle_b_path_residual_cm": ref["residual_cm"],
                    "q_abs_difference_over_ksat": qdiff,
                    "pass": a["branch"] == ref["branch"] and qdiff <= CROSS_Q,
                })
            except Exception as exc:
                crosschecks.append({"probe_id": p["id"], "error": repr(exc), "pass": False})

    valid = [x for x in rows if "hybrid_metric" in x]
    hybrids = sorted(x["hybrid_metric"] for x in valid)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))] if hybrids else math.inf
    max_hybrid = max(hybrids) if hybrids else math.inf
    max_abs = max((x["abs_error_over_ksatfit"] for x in valid), default=math.inf)
    wrong = sum(int(x["wrong_sign"]) for x in valid)
    endpoint_rows = [x for x in valid if str(x["reference_branch"]).startswith("ENDPOINT_KSAT")]
    positive_endpoint = [x for x in valid if x["h_surface"] > 0.0 and str(x["reference_branch"]).startswith("ENDPOINT_KSAT")]
    endpoint_q_max = max((x["endpoint_candidate_abs_error_over_ksat"] for x in endpoint_rows), default=0.0)
    branch_counts = Counter(x["reference_branch"] for x in valid)
    snap_rows = [x for x in valid if x["candidate_branch"] == "SURFACE_SATURATED_PHYSICAL_ENVELOPE_UPPER_SNAP"]
    former_id = FORMER_FAILURES.get(material)
    former_row = next((x for x in valid if x["probe_id"] == former_id), None) if former_id else None

    tests = {
        "fresh_probe_count_identical": len(probes) == EXPECTED,
        "fresh_overlap_with_original_zero": len(overlap) == 0,
        "reference_failure_count": len(ref_failures) == 0,
        "candidate_unresolved_count": unresolved == 0,
        "candidate_nonfinite_count": nonfinite == 0,
        "all_fresh_probes_valid": len(valid) == EXPECTED,
        "crosscheck_count": len(crosschecks) == len(CROSSCHECK_IDS),
        "all_crosschecks_pass": len(crosschecks) == len(CROSSCHECK_IDS) and all(x.get("pass") for x in crosschecks),
        "wrong_sign_count": wrong == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_MAX,
        "max_constitutive_K_evaluations": max_k <= MAX_K,
        "max_root_residual_evaluations": max_root <= MAX_ROOT,
        "endpoint_candidate_q_matches_ksat": endpoint_q_max <= ENDPOINT_Q,
        "positive_surface_never_endpoint_plateau": len(positive_endpoint) == 0,
        "all_snap_certificates_pass": all(s is not None and all(s.values()) for s in (x["snap_tests"] for x in snap_rows)),
        "former_reference_failure_now_valid": former_id is None or former_row is not None,
        "B01_former_defect_not_ksat": material != "B01" or (former_row is not None and abs(former_row["q_candidate"] - ksat) > 1.0e-8 * ksat),
    }

    return {
        "material": material,
        "fresh_probe_count": len(probes),
        "fresh_overlap_count_with_original_e3e": len(overlap),
        "valid_probe_count": len(valid),
        "reference_failure_count": len(ref_failures),
        "reference_failures": ref_failures,
        "candidate_unresolved_count": unresolved,
        "candidate_nonfinite_count": nonfinite,
        "crosschecks": crosschecks,
        "reference_branch_counts": dict(sorted(branch_counts.items())),
        "endpoint_reference_case_count": len(endpoint_rows),
        "positive_surface_endpoint_case_count": len(positive_endpoint),
        "endpoint_candidate_max_abs_error_over_ksat": endpoint_q_max,
        "snap_count": snap_count,
        "snap_rows": snap_rows,
        "former_R2R2_failure_row": former_row,
        "wrong_sign_count": wrong,
        "max_hybrid_metric": max_hybrid,
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max_abs,
        "max_constitutive_K_evaluations": max_k,
        "max_root_residual_evaluations": max_root,
        "worst_probe": max(valid, key=lambda x: x["hybrid_metric"]) if valid else None,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2r3_identical_320_case_requalification.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    mr = run_material(row)
    passed = bool(mr["pass"])
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_R2R3_IDENTICAL_320_CASE_FRESH_REQUALIFICATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": True,
        "fresh_case_identity": "EXACT_R2R2_FRESH_V1_GENERATOR_AND_SEEDS",
        "reference": "R2P zero-surface endpoint semantics plus exact-physical-upper R2R1/R1 high-accuracy interior reference for positive surface heads",
        "candidate": "R2 analytic saturated segment plus R3 physical-envelope-certified upper snap",
        "inherited_steady_q_is_qualification_authority": False,
        "material_result": mr,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_ENDPOINT_AWARE_AND_PHYSICAL_ENVELOPE_REMEDIATED_5CM_SURFACE_FACE_READY_FOR_TRANSACTIONAL_TOP_BOUNDARY_COMPOSITION"
            if passed else
            "REMEDIATED_5CM_SURFACE_FACE_FRESH_REQUALIFICATION_FAILED_FURTHER_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No full top-boundary composition yet.",
            "No rainfall, evaporation, ponding-storage or runoff ledger qualification.",
            "No response tangent across endpoint or snap switching.",
            "No surface heads above 1 cm.",
            "No runtime, MultiSWAP, groundwater or production admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "valid": mr["valid_probe_count"],
        "reference_failures": mr["reference_failure_count"],
        "candidate_unresolved": mr["candidate_unresolved_count"],
        "snap_count": mr["snap_count"],
        "max_hybrid_metric": mr["max_hybrid_metric"],
        "p99_hybrid_metric": mr["p99_hybrid_metric"],
        "max_abs_error_over_ksatfit": mr["max_abs_error_over_ksatfit"],
        "max_k": mr["max_constitutive_K_evaluations"],
        "max_root": mr["max_root_residual_evaluations"],
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
