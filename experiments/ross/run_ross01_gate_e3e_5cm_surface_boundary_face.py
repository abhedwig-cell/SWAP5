from __future__ import annotations

import hashlib
import json
import math
import multiprocessing as mp
import sys
from collections import Counter
from pathlib import Path

from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e2c_bounded_local_face_solve as e2c
import run_ross01_gate_e3a_r2_two_sided_k_endpoint_limit as e3a_r2

CONTRACT = "F-ROSS01_GATE_E3E_5CM_SURFACE_BOUNDARY_FACE_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
FACE_LENGTH_CM = 5.0
SURFACE_HEADS = (0.0, 1.0e-6, 1.0e-4, 1.0e-3, 1.0e-2, 1.0e-1, 2.0e-1, 1.0)
TOP_NODE_HEADS = (-10000.0, -1000.0, -100.0, -10.0, -5.0, -1.0, -0.5, -0.1, -0.01, -0.001, -1.0e-6, 0.0)
HOLDOUT_PER_FAMILY = 256
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
CTX = mp.get_context("fork")


def seed(material: str, family: str) -> int:
    token = f"F-ROSS01-E3E-5CM:{material}:{family}"
    return int(hashlib.sha256(token.encode()).hexdigest()[:8], 16)


def build_probes(material: str) -> list[dict]:
    probes: list[dict] = []
    for i, hs in enumerate(SURFACE_HEADS):
        for j, ht in enumerate(TOP_NODE_HEADS):
            probes.append({
                "id": f"det_{i:02d}_{j:02d}",
                "probe_set": "deterministic",
                "family": "deterministic",
                "h_surface": float(hs),
                "h_top_node": float(ht),
            })

    dry = qmc.Sobol(d=2, scramble=True, seed=seed(material, "dry")).random_base2(m=8)
    for i, (a, b) in enumerate(dry):
        probes.append({
            "id": f"dry_{i:04d}",
            "probe_set": "independent_holdout",
            "family": "dry",
            "h_surface": float(a) ** 4,
            "h_top_node": -(10.0 ** (4.0 * float(b))),
        })

    near = qmc.Sobol(d=2, scramble=True, seed=seed(material, "near")).random_base2(m=8)
    for i, (a, b) in enumerate(near):
        probes.append({
            "id": f"near_{i:04d}",
            "probe_set": "independent_holdout",
            "family": "near_saturation",
            "h_surface": float(a) ** 4,
            "h_top_node": -(float(b) ** 4),
        })
    return probes


def configure_5cm(row: dict) -> None:
    e2c.LENGTH = FACE_LENGTH_CM
    e2c.c1.LENGTH_CM = FACE_LENGTH_CM
    e2c.configure(row)
    # Fail closed if either qualification or full-accuracy reference still carries 10 cm.
    if float(e2c.LENGTH) != FACE_LENGTH_CM:
        raise RuntimeError("candidate_face_length_not_5cm")
    if float(e2c.c1.core.LENGTH_CM) != FACE_LENGTH_CM:
        raise RuntimeError("reference_face_length_not_5cm")


def safe_ref(pair: tuple[float, float]):
    hs, ht = pair
    try:
        return pair, float(e2c.c1.core.steady_q(float(hs), float(ht))), None
    except Exception as exc:
        return pair, None, repr(exc)


def candidate_q(h_surface: float, h_top_node: float) -> tuple[float, dict]:
    if h_surface >= 0.0 and h_top_node >= 0.0:
        q = float(e2c.c1.core.KSAT) * (1.0 - (h_top_node - h_surface) / FACE_LENGTH_CM)
        return q, {
            "branch": "SAT_SAT_ANALYTIC_5CM",
            "root_residual_evaluations": 0,
            "constitutive_K_evaluations": 0,
        }
    return e3a_r2.candidate_q(float(h_surface), float(h_top_node))


def run_material(row: dict) -> dict:
    configure_5cm(row)
    material = str(row["sfu"])
    ksat = float(e2c.c1.core.KSAT)
    probes = build_probes(material)
    unique_pairs = sorted({(float(p["h_surface"]), float(p["h_top_node"])) for p in probes})

    refs: dict[tuple[float, float], float] = {}
    ref_errors: list[dict] = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, value, error in pool.imap_unordered(safe_ref, unique_pairs, chunksize=4):
            if error is None:
                refs[pair] = float(value)
            else:
                ref_errors.append({"pair": list(pair), "error": error})

    rows = []
    unresolved = 0
    nonfinite = 0
    max_root = 0
    max_k = 0
    for p in probes:
        hs = float(p["h_surface"])
        ht = float(p["h_top_node"])
        q_ref = refs.get((hs, ht))
        if q_ref is None:
            continue
        try:
            q_cand, cost = candidate_q(hs, ht)
        except RuntimeError:
            unresolved += 1
            continue
        except (FloatingPointError, OverflowError, ValueError):
            nonfinite += 1
            continue
        if not (math.isfinite(q_ref) and math.isfinite(q_cand)):
            nonfinite += 1
            continue
        hybrid, absolute, wrong_sign = e2c._metric(q_ref, q_cand, ksat)
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        rows.append({
            "probe_id": p["id"],
            "probe_set": p["probe_set"],
            "family": p["family"],
            "h_surface": hs,
            "h_top_node": ht,
            "q_ref": q_ref,
            "q_candidate": q_cand,
            "branch": str(cost["branch"]),
            "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute,
            "wrong_sign": wrong_sign,
            "root_residual_evaluations": int(cost["root_residual_evaluations"]),
            "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
        })

    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))] if hybrids else math.inf
    max_hybrid = max(hybrids) if hybrids else math.inf
    max_abs = max((r["abs_error_over_ksatfit"] for r in rows), default=math.inf)
    wrong_sign_count = sum(int(r["wrong_sign"]) for r in rows)
    expected_probe_count = len(SURFACE_HEADS) * len(TOP_NODE_HEADS) + 2 * HOLDOUT_PER_FAMILY
    branch_counts = Counter(r["branch"] for r in rows)

    tests = {
        "explicit_candidate_face_length_5cm": float(e2c.LENGTH) == FACE_LENGTH_CM,
        "explicit_reference_face_length_5cm": float(e2c.c1.core.LENGTH_CM) == FACE_LENGTH_CM,
        "expected_probe_count": len(probes) == expected_probe_count,
        "reference_failure_count": len(ref_errors) == 0,
        "candidate_unresolved_count": unresolved == 0,
        "candidate_nonfinite_count": nonfinite == 0,
        "all_probes_valid": len(rows) == expected_probe_count,
        "wrong_sign_count": wrong_sign_count == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "max_constitutive_K_evaluations": max_k <= MAX_K_EVALS,
        "max_root_residual_evaluations": max_root <= MAX_ROOT_EVALS,
    }
    return {
        "material": material,
        "face_length_cm": FACE_LENGTH_CM,
        "probe_count": len(probes),
        "valid_probe_count": len(rows),
        "deterministic_probe_count": sum(p["probe_set"] == "deterministic" for p in probes),
        "independent_holdout_probe_count": sum(p["probe_set"] == "independent_holdout" for p in probes),
        "dry_holdout_probe_count": sum(p["family"] == "dry" for p in probes),
        "near_saturation_holdout_probe_count": sum(p["family"] == "near_saturation" for p in probes),
        "reference_failure_count": len(ref_errors),
        "candidate_unresolved_count": unresolved,
        "candidate_nonfinite_count": nonfinite,
        "wrong_sign_count": wrong_sign_count,
        "max_hybrid_metric": max_hybrid,
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max_abs,
        "max_constitutive_K_evaluations": max_k,
        "max_root_residual_evaluations": max_root,
        "branch_counts": dict(sorted(branch_counts.items())),
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
        "worst_probe": max(rows, key=lambda r: r["hybrid_metric"]) if rows else None,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_5cm_surface_boundary_face.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)

    old_e2c_length = float(e2c.LENGTH)
    old_c1_length = float(e2c.c1.LENGTH_CM)
    old_core_length = float(e2c.c1.core.LENGTH_CM)
    try:
        result_material = run_material(row)
    finally:
        e2c.LENGTH = old_e2c_length
        e2c.c1.LENGTH_CM = old_c1_length
        e2c.c1.core.LENGTH_CM = old_core_length

    passed = bool(result_material["pass"])
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_5CM_SURFACE_WET_TO_UNSAT_BOUNDARY_FACE",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": True,
        "new_persistent_state_bytes": 0,
        "scratch_owner": "worker",
        "face_length_cm": FACE_LENGTH_CM,
        "surface_head_scope_cm": [0.0, 1.0],
        "top_node_head_scope_cm": [-10000.0, 0.0],
        "material_result": result_material,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_5CM_SURFACE_BOUNDARY_FACE_READY_FOR_TOP_BOUNDARY_COMPOSITION_PROTOTYPE"
            if passed else
            "FIVE_CM_SURFACE_BOUNDARY_FACE_NOT_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No full top-boundary or ponding qualification.",
            "No runoff or surface-water ledger qualification.",
            "No C1R 10 cm table reuse at 5 cm.",
            "No production implementation or admission.",
            "No surface heads above 1 cm qualified."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "decision": result["decision"],
        "valid_probe_count": result_material["valid_probe_count"],
        "max_hybrid_metric": result_material["max_hybrid_metric"],
        "p99_hybrid_metric": result_material["p99_hybrid_metric"],
        "max_abs_error_over_ksatfit": result_material["max_abs_error_over_ksatfit"],
        "unresolved": result_material["candidate_unresolved_count"],
        "max_root_evals": result_material["max_root_residual_evaluations"],
        "max_k_evals": result_material["max_constitutive_K_evaluations"],
        "branch_counts": result_material["branch_counts"],
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
