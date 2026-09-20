#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shard-dir", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    x = ap.parse_args()

    files = sorted(x.shard_dir.glob("**/LARE_BC2_C6C_SHARD_*.json"))
    if not files:
        raise SystemExit("no C6C shard JSON files found")

    shards = [json.loads(p.read_text()) for p in files]
    shard_counts = {int(s["shard_count"]) for s in shards}
    total_counts = {int(s["total_case_count"]) for s in shards}
    if len(shard_counts) != 1 or len(total_counts) != 1:
        raise SystemExit("inconsistent shard metadata")
    shard_count = shard_counts.pop()
    total_case_count = total_counts.pop()
    shard_ids = sorted(int(s["shard_index"]) for s in shards)
    if shard_ids != list(range(shard_count)):
        raise SystemExit(f"missing/duplicate shards: {shard_ids}")

    rows = []
    for shard in shards:
        f = shard["scientific_firewall"]
        assert f["hydrological_response_used"] is False
        assert f["model_run_executed"] is False
        assert f["response_based_profile_fit"] is False
        assert f["c5z_post_result_retuning"] is False
        rows.extend(shard["rows"])

    rows.sort(key=lambda r: int(r["case_index"]))
    indices = [int(r["case_index"]) for r in rows]
    if indices != list(range(total_case_count)):
        raise SystemExit("case partition is not an exact cover")

    gates = {
        "G1_STRICT_STATE_MOMENT_REALIZABILITY": all(r["moment_bound_gate"] for r in rows),
        "G2_ALL_CASES_CONVERGE": all(r["all_starts_converged"] for r in rows),
        "G3_UNIQUE_NUMERICAL_BRANCH": all(r["unique_numerical_branch"] for r in rows),
        "G4_BOUNDED_REALIZABILITY": all(r["theta_admissible"] for r in rows),
        "G5_HYDRAULIC_CONTINUITY": all(r["hydraulic_continuity"] for r in rows),
        "G6_STATE_RECOVERY": all(r["state_recovery"] for r in rows),
        "G7_QUADRATURE_CONSISTENCY": all(r["quadrature_consistency"] for r in rows),
        "G8_NO_RESPONSE_DATA": True,
    }

    if all(gates.values()):
        status = "C6C_BEMR_MATHEMATICALLY_QUALIFIED"
    elif gates["G1_STRICT_STATE_MOMENT_REALIZABILITY"] and gates["G4_BOUNDED_REALIZABILITY"]:
        status = "C6C_BEMR_NUMERICALLY_NONUNIQUE_OR_HYDRAULICALLY_INADMISSIBLE"
    else:
        status = "C6C_BEMR_STATE_DOMAIN_NOT_REALIZABLE"

    def count(key):
        return sum(bool(r[key]) for r in rows)

    conds = []
    for r in rows:
        for run in r["runs"]:
            v = float(run["condition_number"])
            if math.isfinite(v):
                conds.append(v)

    out = {
        "schema": "swap5.lare.bc2.c6c.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C6C",
        "status": status,
        "role": "NO_HYDROLOGICAL_RESPONSE_BEMR_MATHEMATICAL_QUALIFICATION",
        "execution": {
            "mode": "EXACT_CASE_SHARDED",
            "shard_count": shard_count,
            "case_partition": "case_index modulo shard_count",
        },
        "case_count": len(rows),
        "gates": gates,
        "qualification_counts": {
            "moment_bound_pass": count("moment_bound_gate"),
            "all_starts_converged": count("all_starts_converged"),
            "unique_numerical_branch": count("unique_numerical_branch"),
            "theta_admissible": count("theta_admissible"),
            "hydraulic_continuity": count("hydraulic_continuity"),
            "state_recovery": count("state_recovery"),
            "quadrature_consistency": count("quadrature_consistency"),
        },
        "conditioning": {
            "finite_jacobian_condition_count": len(conds),
            "median_condition_number": float(np.median(conds)) if conds else None,
            "max_condition_number": max(conds) if conds else None,
            "hard_gate": False,
        },
        "cases": rows,
        "scientific_firewall": {
            "hydrological_response_used": False,
            "model_run_executed": False,
            "moment_state_implemented_in_hydrological_model": False,
            "moment_localization_selected": False,
            "response_based_profile_fit": False,
            "c5z_post_result_retuning": False,
            "application_acceptance_adjudicated": False,
            "performance_comparison_authorized": False,
            "speed_claim_authorized": False,
            "production_rom_authorized": False,
        },
    }
    x.output.parent.mkdir(parents=True, exist_ok=True)
    x.output.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "status": status,
        "case_count": len(rows),
        "gates": gates,
        "counts": out["qualification_counts"],
        "conditioning": out["conditioning"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
