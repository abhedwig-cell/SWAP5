from __future__ import annotations

import hashlib
import json
import math
import sys
from collections import Counter
from pathlib import Path

import mpmath as mp
from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_r2r1_endpoint_limit_oracle_repair_fastscan as fastscan
import run_ross01_gate_e3e_5cm_surface_boundary_face as old_e3e

r2 = fastscan.base

CONTRACT = "F-ROSS01_GATE_E3E_R2R2_FRESH_5CM_REFERENCE_CHARACTERIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
FACE_LENGTH_CM = 5.0
ZERO_N = 16
DRY_N = 32
NEAR_N = 32
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
REF_RES_TOL_CM = 1.0e-8
CROSSCHECK_Q_OVER_KSAT = 1.0e-9
ENDPOINT_CANDIDATE_Q_OVER_KSAT = 1.0e-12
CROSSCHECK_IDS = {"fresh_zero_0003", "fresh_near_0011"}


def seed(material: str, family: str) -> int:
    token = f"F-ROSS01-E3E-R2R2-FRESH-V1:{material}:{family}"
    return int(hashlib.sha256(token.encode()).hexdigest()[:8], 16)


def hsurf_positive(a: float) -> float:
    return float(10.0 ** (-8.0 * (1.0 - float(a))))


def build_fresh(material: str) -> list[dict]:
    probes: list[dict] = []
    zero = qmc.Sobol(d=1, scramble=True, seed=seed(material, "zero")).random_base2(m=4)
    for i, (b,) in enumerate(zero):
        probes.append({
            "id": f"fresh_zero_{i:04d}",
            "family": "zero_surface",
            "h_surface": 0.0,
            "h_top_node": -(10.0 ** (4.0 * float(b))),
        })
    dry = qmc.Sobol(d=2, scramble=True, seed=seed(material, "dry")).random_base2(m=5)
    for i, (a, b) in enumerate(dry):
        probes.append({
            "id": f"fresh_dry_{i:04d}",
            "family": "positive_surface_dry",
            "h_surface": hsurf_positive(float(a)),
            "h_top_node": -(10.0 ** (4.0 * float(b))),
        })
    near = qmc.Sobol(d=2, scramble=True, seed=seed(material, "near")).random_base2(m=5)
    for i, (a, b) in enumerate(near):
        probes.append({
            "id": f"fresh_near_{i:04d}",
            "family": "positive_surface_near_saturation",
            "h_surface": hsurf_positive(float(a)),
            "h_top_node": -(10.0 ** (-8.0 * float(b))),
        })
    return probes


def reference_b(hs_f: float, ht_f: float, row: dict) -> dict:
    hs = mp.mpf(str(hs_f)); ht = mp.mpf(str(ht_f)); ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    setup = r2.setup_b(ht, row)
    endpoint = None
    plateau = None
    if hs == 0:
        with mp.workdps(60):
            endpoint = r2.path_b_delta(hs, mp.mpf("0"), setup)
        branch = r2.endpoint_class(endpoint)
    else:
        branch = "INTERIOR_ROOT"
    if branch.startswith("ENDPOINT_KSAT"):
        delta = mp.mpf("0"); y = None; residual = mp.mpf("0")
        plateau = max(mp.mpf("0"), r2.LENGTH - endpoint)
    else:
        delta, y, residual = r2.solve_interior_b(hs, ht, setup)
    q = ks * (1 + delta)
    return {
        "q": float(q),
        "branch": branch,
        "residual_cm": float(residual),
        "log10_delta": None if y is None else float(y),
        "endpoint_path_cm": None if endpoint is None else float(endpoint),
        "plateau_length_cm": None if plateau is None else float(plateau),
    }


def reference_a(hs_f: float, ht_f: float, row: dict) -> dict:
    hs = mp.mpf(str(hs_f)); ht = mp.mpf(str(ht_f)); ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    endpoint = None
    if hs == 0:
        with mp.workdps(100):
            endpoint = r2.path_a_delta(hs, ht, mp.mpf("0"), row)
        branch = r2.endpoint_class(endpoint)
    else:
        branch = "INTERIOR_ROOT"
    if branch.startswith("ENDPOINT_KSAT"):
        delta = mp.mpf("0"); residual = mp.mpf("0")
    else:
        delta, _, residual = r2.solve_interior_a(hs, ht, row)
    return {"q": float(ks * (1 + delta)), "branch": branch, "residual_cm": float(residual)}


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    old_e3e.configure_5cm(row)
    ksat = float(old_e3e.e2c.c1.core.KSAT)
    probes = build_fresh(material)
    old_pairs = {(float(p["h_surface"]), float(p["h_top_node"])) for p in old_e3e.build_probes(material)}
    fresh_pairs = {(float(p["h_surface"]), float(p["h_top_node"])) for p in probes}
    overlap = sorted(old_pairs & fresh_pairs)

    rows = []
    ref_failures = []
    candidate_unresolved = 0
    candidate_nonfinite = 0
    crosschecks = []
    max_k = 0
    max_root = 0

    for p in probes:
        hs = float(p["h_surface"]); ht = float(p["h_top_node"])
        try:
            ref = reference_b(hs, ht, row)
        except Exception as exc:
            ref_failures.append({"probe_id": p["id"], "error": repr(exc)})
            continue
        if not (math.isfinite(ref["q"]) and math.isfinite(ref["residual_cm"])):
            ref_failures.append({"probe_id": p["id"], "error": "nonfinite_reference"})
            continue
        if abs(ref["residual_cm"]) > REF_RES_TOL_CM:
            ref_failures.append({"probe_id": p["id"], "error": "reference_path_residual", "residual_cm": ref["residual_cm"]})
            continue
        try:
            qc, cost = old_e3e.candidate_q(hs, ht)
        except RuntimeError as exc:
            candidate_unresolved += 1
            rows.append({"probe_id": p["id"], "family": p["family"], "h_surface": hs, "h_top_node": ht, "q_reference": ref["q"], "reference_branch": ref["branch"], "candidate_error": repr(exc)})
            continue
        except (FloatingPointError, OverflowError, ValueError) as exc:
            candidate_nonfinite += 1
            rows.append({"probe_id": p["id"], "family": p["family"], "h_surface": hs, "h_top_node": ht, "q_reference": ref["q"], "reference_branch": ref["branch"], "candidate_error": repr(exc)})
            continue
        qc = float(qc)
        if not math.isfinite(qc):
            candidate_nonfinite += 1
            continue
        hybrid, absolute, wrong_sign = old_e3e.e2c._metric(float(ref["q"]), qc, ksat)
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        endpoint_q_error = None
        if str(ref["branch"]).startswith("ENDPOINT_KSAT"):
            endpoint_q_error = abs(qc - ksat) / ksat
        row_out = {
            "probe_id": p["id"], "family": p["family"], "h_surface": hs, "h_top_node": ht,
            "q_reference": float(ref["q"]), "reference_branch": ref["branch"],
            "reference_path_residual_cm": ref["residual_cm"],
            "reference_endpoint_path_cm": ref["endpoint_path_cm"],
            "reference_plateau_length_cm": ref["plateau_length_cm"],
            "q_candidate": qc, "candidate_branch": str(cost["branch"]),
            "hybrid_metric": hybrid, "abs_error_over_ksatfit": absolute, "wrong_sign": wrong_sign,
            "endpoint_candidate_abs_error_over_ksat": endpoint_q_error,
            "root_residual_evaluations": int(cost["root_residual_evaluations"]),
            "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
        }
        rows.append(row_out)

        if p["id"] in CROSSCHECK_IDS:
            try:
                a = reference_a(hs, ht, row)
                qdiff = abs(float(a["q"]) - float(ref["q"])) / ksat
                crosschecks.append({
                    "probe_id": p["id"], "family": p["family"],
                    "oracle_a_q": a["q"], "oracle_b_q": ref["q"],
                    "oracle_a_branch": a["branch"], "oracle_b_branch": ref["branch"],
                    "oracle_a_path_residual_cm": a["residual_cm"],
                    "oracle_b_path_residual_cm": ref["residual_cm"],
                    "q_abs_difference_over_ksat": qdiff,
                    "pass": a["branch"] == ref["branch"] and qdiff <= CROSSCHECK_Q_OVER_KSAT,
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
    positive_endpoint = [x for x in valid if x["h_surface"] > 0 and str(x["reference_branch"]).startswith("ENDPOINT_KSAT")]
    endpoint_q_max = max((x["endpoint_candidate_abs_error_over_ksat"] for x in endpoint_rows), default=0.0)
    branch_counts = Counter(x["reference_branch"] for x in valid)
    expected_count = ZERO_N + DRY_N + NEAR_N

    tests = {
        "fresh_probe_count": len(probes) == expected_count,
        "fresh_overlap_with_original_zero": len(overlap) == 0,
        "reference_failure_count": len(ref_failures) == 0,
        "candidate_unresolved_count": candidate_unresolved == 0,
        "candidate_nonfinite_count": candidate_nonfinite == 0,
        "all_fresh_probes_valid": len(valid) == expected_count,
        "crosscheck_count": len(crosschecks) == len(CROSSCHECK_IDS),
        "all_crosschecks_pass": len(crosschecks) == len(CROSSCHECK_IDS) and all(x.get("pass") for x in crosschecks),
        "wrong_sign_count": wrong == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "max_constitutive_K_evaluations": max_k <= MAX_K_EVALS,
        "max_root_residual_evaluations": max_root <= MAX_ROOT_EVALS,
        "endpoint_candidate_q_matches_ksat": endpoint_q_max <= ENDPOINT_CANDIDATE_Q_OVER_KSAT,
        "positive_surface_never_endpoint_plateau": len(positive_endpoint) == 0,
    }
    return {
        "material": material,
        "fresh_probe_count": len(probes),
        "fresh_overlap_count_with_original_e3e": len(overlap),
        "valid_probe_count": len(valid),
        "reference_failure_count": len(ref_failures),
        "reference_failures": ref_failures,
        "candidate_unresolved_count": candidate_unresolved,
        "candidate_nonfinite_count": candidate_nonfinite,
        "crosschecks": crosschecks,
        "reference_branch_counts": dict(sorted(branch_counts.items())),
        "endpoint_reference_case_count": len(endpoint_rows),
        "positive_surface_endpoint_case_count": len(positive_endpoint),
        "endpoint_candidate_max_abs_error_over_ksat": endpoint_q_max,
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
        raise SystemExit("usage: run_ross01_gate_e3e_r2r2_fresh_5cm_reference_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    result_material = run_material(row)
    passed = bool(result_material["pass"])
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_R2R2_FRESH_5CM_REFERENCE_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": True,
        "reference": "R2R1 stable endpoint-aware independent oracle with R2P endpoint semantics",
        "inherited_steady_q_is_qualification_authority": False,
        "fresh_probe_count": ZERO_N + DRY_N + NEAR_N,
        "material_result": result_material,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_FRESH_ENDPOINT_AWARE_5CM_SURFACE_BOUNDARY_FACE_READY_FOR_TOP_BOUNDARY_COMPOSITION_PROTOTYPE"
            if passed else
            "FRESH_ENDPOINT_AWARE_5CM_SURFACE_BOUNDARY_FACE_NOT_QUALIFIED_REMEDIATION_REQUIRED"
        ),
        "hard_nonclaims": [
            "No full top-boundary, ponding storage, rainfall, evaporation or runoff qualification.",
            "No surface-water ledger qualification.",
            "No response tangent qualification across endpoint switching.",
            "No surface heads above 1 cm.",
            "No groundwater, runtime, MultiSWAP or production admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "fresh_probe_count": result_material["fresh_probe_count"],
        "endpoint_cases": result_material["endpoint_reference_case_count"],
        "max_hybrid_metric": result_material["max_hybrid_metric"],
        "p99_hybrid_metric": result_material["p99_hybrid_metric"],
        "max_abs_error_over_ksatfit": result_material["max_abs_error_over_ksatfit"],
        "failed_metrics": result_material["failed_metrics"],
        "decision": result["decision"],
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
