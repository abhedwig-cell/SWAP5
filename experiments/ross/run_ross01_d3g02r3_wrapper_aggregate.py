from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

EXPECTED_MATERIALS = {"B01", "B12", "O01", "O05", "O14", "O18"}
EXPECTED_CASES = 54
MASS_TOL_CM = 1.0e-12


def load_materials(root: Path) -> list[dict]:
    docs = []
    for p in sorted(root.rglob("F-ROSS01_D3G02R3_MATERIAL_*.json")):
        docs.append(json.loads(p.read_text(encoding="utf-8")))
    return docs


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--artifacts", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    docs = load_materials(a.artifacts)
    materials = [d.get("material") for d in docs]
    all_cases = [c for d in docs for c in d.get("cases", [])]
    negative_docs = [d.get("negative_tests") for d in docs if "negative_tests" in d]
    canonical_heads = sorted({d.get("canonical_head") for d in docs})

    case_keys = {(c.get("material"), c.get("attempt_index")) for c in all_cases}
    expected_keys = {(m, k) for m in EXPECTED_MATERIALS for k in range(9)}

    max_indicator = max((float(c["temporal_indicator"]) for c in all_cases if isinstance(c.get("temporal_indicator"), (int, float)) and math.isfinite(float(c["temporal_indicator"]))), default=float("inf"))
    max_mass = max((abs(float(c["aggregate_mass_residual_cm"])) for c in all_cases if isinstance(c.get("aggregate_mass_residual_cm"), (int, float)) and math.isfinite(float(c["aggregate_mass_residual_cm"]))), default=float("inf"))
    floor_cases = sum(1 for c in all_cases if c.get("bound_branch") == "PREEXISTING_GATE_F_RESOLUTION_FLOOR")
    raw_cases = sum(1 for c in all_cases if c.get("bound_branch") == "RAW_ESTIMATOR")

    checks = {
        "six_material_artifacts": len(docs) == 6 and set(materials) == EXPECTED_MATERIALS and len(set(materials)) == 6,
        "exact_54_case_matrix": len(all_cases) == EXPECTED_CASES and case_keys == expected_keys,
        "all_material_shards_pass": all(d.get("pass") is True for d in docs),
        "all_positive_cases_pass": all(c.get("pass") is True for c in all_cases),
        "exactly_one_negative_path_suite": len(negative_docs) == 1,
        "negative_paths_pass": len(negative_docs) == 1 and negative_docs[0].get("pass") is True,
        "single_live_canonical_head": len(canonical_heads) == 1 and canonical_heads[0] is not None,
        "all_indicators_finite_nonnegative_le_one": all(isinstance(c.get("temporal_indicator"), (int, float)) and math.isfinite(float(c["temporal_indicator"])) and 0.0 <= float(c["temporal_indicator"]) <= 1.0 for c in all_cases),
        "all_mass_residuals_within_hard_gate": max_mass <= MASS_TOL_CM,
        "bound_branch_partition_complete": floor_cases + raw_cases == EXPECTED_CASES,
    }

    out = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D3G02R3",
        "kind": "FAIL_CLOSED_RUNTIME_CERTIFICATE_WRAPPER_AGGREGATE",
        "pass": all(checks.values()),
        "decision": "QUALIFIED_ROSSFAST_D3G02R_FAIL_CLOSED_MODEL_CERTIFICATE_ON_EXACT_D3R_DOMAIN" if all(checks.values()) else "NEGATIVE_D3G02R3_LEAVE_D3_G02_OPEN",
        "checks": checks,
        "material_count": len(docs),
        "case_count": len(all_cases),
        "floor_bound_case_count": floor_cases,
        "raw_bound_case_count": raw_cases,
        "max_temporal_indicator": max_indicator,
        "max_abs_mass_residual_cm": max_mass,
        "canonical_heads": canonical_heads,
        "negative_tests": negative_docs[0] if len(negative_docs) == 1 else negative_docs,
        "g02_effect_if_pass": "CLOSE_AT_RESTRICTED_RESEARCH_CURRENT_CANONICAL_CONTRACT_COMPOSABILITY_LEVEL_ONLY",
        "production_admission": False,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(out, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"pass": out["pass"], "case_count": out["case_count"], "max_temporal_indicator": max_indicator, "max_abs_mass_residual_cm": max_mass, "decision": out["decision"]}, sort_keys=True, allow_nan=False))
    return 0 if out["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
