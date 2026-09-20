#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import numpy as np


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--shard-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    files=sorted(a.shard_dir.glob("**/LARE_BC2_C6E_SHARD_*.json"))
    if not files:
        raise SystemExit("no C6E shard files found")
    shards=[json.loads(p.read_text()) for p in files]
    shard_counts={int(s["shard_count"]) for s in shards}
    total_counts={int(s["total_case_count"]) for s in shards}
    if len(shard_counts)!=1 or len(total_counts)!=1:
        raise SystemExit("inconsistent shard metadata")
    shard_count=shard_counts.pop()
    total_case_count=total_counts.pop()
    ids=sorted(int(s["shard_index"]) for s in shards)
    if ids!=list(range(shard_count)):
        raise SystemExit(f"missing/duplicate shards: {ids}")

    rows=[]
    for s in shards:
        f=s["scientific_firewall"]
        assert f["hydrological_response_used"] is False
        assert f["model_run_executed"] is False
        assert f["c6d_response_used_for_design"] is False
        assert f["production_rom_authorized"] is False
        rows.extend(s["rows"])
    rows.sort(key=lambda r:int(r["case_index"]))
    if [int(r["case_index"]) for r in rows] != list(range(total_case_count)):
        raise SystemExit("case partition is not an exact cover")

    gates={
      "G1_STRICT_STATE_MOMENT_REALIZABILITY":all(r["moment_bound_gate"] for r in rows),
      "G2_ALL_CASES_CONVERGE":all(r["all_starts_converged"] for r in rows),
      "G3_UNIQUE_NUMERICAL_BRANCH":all(r["unique_numerical_branch"] for r in rows),
      "G4_BOUNDED_REALIZABILITY":all(r["bounded_realizability"] for r in rows),
      "G5_HYDRAULIC_CONTINUITY":all(r["hydraulic_continuity"] for r in rows),
      "G6_STATE_RECOVERY":all(r["state_recovery"] for r in rows),
      "G7_QUADRATURE_CONSISTENCY":all(r["quadrature_consistency"] for r in rows),
      "G8_NO_RESPONSE_DATA":True
    }
    status="C6E_BEMR_PRESCRIBED_FLUX_BOUNDARY_QUALIFIED" if all(gates.values()) else "C6E_BEMR_PRESCRIBED_FLUX_BOUNDARY_NOT_QUALIFIED"

    def count(k): return sum(bool(r[k]) for r in rows)
    cond=[]
    diags=[]
    for r in rows:
        for run in r["runs"]:
            v=float(run["condition_number"])
            if math.isfinite(v):
                cond.append(v)
            if run.get("diagnostics") is not None:
                diags.append(run["diagnostics"])
    extrema={
      "min_Se":min(d["Se_min"] for d in diags) if diags else None,
      "max_Se":max(d["Se_max"] for d in diags) if diags else None,
      "max_abs_interface_pressure_jump_cm":max(d["max_abs_interface_pressure_jump_cm"] for d in diags) if diags else None,
      "max_abs_interface_flux_jump_cm_per_day":max(d["max_abs_interface_flux_jump_cm_per_day"] for d in diags) if diags else None,
      "max_abs_top_flux_residual_cm_per_day":max(d["abs_top_flux_residual_cm_per_day"] for d in diags) if diags else None,
      "max_abs_bottom_flux_residual_cm_per_day":max(d["abs_bottom_flux_residual_cm_per_day"] for d in diags) if diags else None,
      "max_abs_storage_recovery_cm":max(d["max_abs_storage_recovery_cm"] for d in diags) if diags else None,
      "max_abs_moment_recovery_cm2":max(d["max_abs_moment_recovery_cm2"] for d in diags) if diags else None
    }
    out={
      "schema":"swap5.lare.bc2.c6e.result.v1",
      "workstream":"F-ROM-LARE",
      "work_unit":"LARE-BC2-C6E",
      "status":status,
      "role":"NO_HYDROLOGICAL_RESPONSE_BEMR_PRESCRIBED_FLUX_BOUNDARY_QUALIFICATION",
      "execution":{"mode":"EXACT_CASE_SHARDED","shard_count":shard_count,"case_partition":"case_index modulo shard_count"},
      "case_count":len(rows),
      "fixed_start_count":len(rows)*5,
      "gates":gates,
      "qualification_counts":{
        "moment_bound_pass":count("moment_bound_gate"),
        "all_starts_converged":count("all_starts_converged"),
        "unique_numerical_branch":count("unique_numerical_branch"),
        "bounded_realizability":count("bounded_realizability"),
        "hydraulic_continuity":count("hydraulic_continuity"),
        "state_recovery":count("state_recovery"),
        "quadrature_consistency":count("quadrature_consistency")
      },
      "conditioning":{
        "finite_jacobian_condition_count":len(cond),
        "median_condition_number":float(np.median(cond)) if cond else None,
        "max_condition_number":max(cond) if cond else None,
        "hard_gate":False
      },
      "diagnostic_extrema":extrema,
      "cases":rows,
      "scientific_firewall":{
        "hydrological_response_used":False,
        "model_run_executed":False,
        "c6d_response_used_for_design":False,
        "free_running_bemr_implemented":False,
        "moment_fitting":False,
        "moment_localization":False,
        "c6c_retuning":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "case_count":len(rows),
      "gates":gates,
      "counts":out["qualification_counts"],
      "conditioning":out["conditioning"],
      "extrema":extrema
    },sort_keys=True))


if __name__=="__main__":
    main()
