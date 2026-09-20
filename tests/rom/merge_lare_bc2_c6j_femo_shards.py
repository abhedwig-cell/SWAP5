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

    files=sorted(a.shard_dir.glob("**/LARE_BC2_C6J_SHARD_*.json"))
    if not files:
        raise SystemExit("no C6J shard files found")
    shards=[json.loads(p.read_text()) for p in files]
    shard_counts={int(s["shard_count"]) for s in shards}
    total_counts={int(s["total_state_case_count"]) for s in shards}
    if len(shard_counts)!=1 or len(total_counts)!=1:
        raise SystemExit("inconsistent C6J shard metadata")
    shard_count=shard_counts.pop()
    total=total_counts.pop()
    ids=sorted(int(s["shard_index"]) for s in shards)
    if ids!=list(range(shard_count)):
        raise SystemExit(f"missing/duplicate shards: {ids}")

    rows=[]
    for s in shards:
        f=s["scientific_firewall"]
        assert f["hydrological_response_used"] is False
        assert f["model_run_executed"] is False
        assert f["c6d_response_used_for_design"] is False
        assert f["c6e_failures_used_for_penalty_design"] is False
        assert f["BEMR_reopened"] is False
        rows.extend(s["rows"])
    rows.sort(key=lambda r:int(r["case_index"]))
    if [int(r["case_index"]) for r in rows] != list(range(total)):
        raise SystemExit("C6J state cases are not an exact cover")

    head_ops=[op for r in rows for op in r["head_operators"]]
    flux_ops=[op for r in rows for op in r["flux_operators"]]
    expected_head_ops=168
    expected_flux_ops=126

    G1=all(r["gates"]["moment_realizable"] for r in rows)
    G2=all(r["gates"]["all_local_starts_converged"] for r in rows)
    G3=all(r["gates"]["all_local_profiles_unique"] for r in rows)
    G4=all(r["gates"]["all_local_profiles_interior"] for r in rows)
    G5=all(r["gates"]["all_local_state_recovery"] for r in rows)
    G6=all(r["gates"]["all_local_jacobians_negative_definite"] for r in rows)
    G7=all(r["metric"] is not None and r["metric"]["qualified"] for r in rows)
    G8=(len(head_ops)==expected_head_ops and all(op["qualified"] for op in head_ops))
    G9=(len(flux_ops)==expected_flux_ops and all(op["qualified"] for op in flux_ops))
    gates={
      "G1_FROZEN_STATE_MOMENT_REALIZABILITY":G1,
      "G2_LOCAL_PROFILE_CONVERGENCE":G2,
      "G3_LOCAL_PROFILE_UNIQUENESS":G3,
      "G4_INTERIOR_BOUNDED_PROFILE":G4,
      "G5_STATE_RECOVERY":G5,
      "G6_LOCAL_MOMENT_JACOBIAN":G6,
      "G7_ONSAGER_METRIC":G7,
      "G8_PRESCRIBED_HEAD_OPERATOR":G8,
      "G9_PRESCRIBED_FLUX_OPERATOR":G9,
      "G10_NO_RESPONSE_DATA":True
    }
    if all(gates.values()):
        status="C6J_FEMO_MATHEMATICALLY_QUALIFIED"
    elif not all([G1,G2,G3,G4,G5,G6]):
        status="C6J_FEMO_LOCAL_MANIFOLD_NOT_QUALIFIED"
    else:
        status="C6J_FEMO_ONSAGER_OPERATOR_NOT_QUALIFIED"

    all_local=[layer for r in rows for layer in r["local_layers"]]
    all_runs=[run for layer in all_local for run in layer["runs"]]
    metrics=[r["metric"] for r in rows if r["metric"] is not None]

    def count_state(key):
        return sum(bool(r["gates"][key]) for r in rows)

    finite_jac=[run["moment_jacobian_condition_number"] for run in all_runs if run.get("moment_jacobian_condition_number") is not None]
    finite_metric=[m["condition_number"] for m in metrics if m.get("condition_number") is not None]
    se_min=min((run["Se_min"] for run in all_runs if run.get("Se_min") is not None),default=None)
    se_max=max((run["Se_max"] for run in all_runs if run.get("Se_max") is not None),default=None)

    out={
      "schema":"swap5.lare.bc2.c6j.result.v1",
      "workstream":"F-ROM-LARE",
      "work_unit":"LARE-BC2-C6J",
      "status":status,
      "role":"NO_HYDROLOGICAL_RESPONSE_FEMO_MANIFOLD_METRIC_BOUNDARY_OPERATOR_QUALIFICATION",
      "execution":{"mode":"EXACT_STATE_CASE_SHARDED","shard_count":shard_count,"partition":"case_index modulo shard_count"},
      "state_case_count":len(rows),
      "head_operator_case_count":len(head_ops),
      "expected_head_operator_case_count":expected_head_ops,
      "flux_operator_case_count":len(flux_ops),
      "expected_flux_operator_case_count":expected_flux_ops,
      "gates":gates,
      "qualification_counts":{
        "state_moment_realizable":count_state("moment_realizable"),
        "local_profile_convergence":count_state("all_local_starts_converged"),
        "local_profile_uniqueness":count_state("all_local_profiles_unique"),
        "interior_bounded_profile":count_state("all_local_profiles_interior"),
        "state_recovery":count_state("all_local_state_recovery"),
        "local_jacobian":count_state("all_local_jacobians_negative_definite"),
        "onsager_metric":sum(m["qualified"] for m in metrics),
        "prescribed_head_operator":sum(op["qualified"] for op in head_ops),
        "prescribed_flux_operator":sum(op["qualified"] for op in flux_ops)
      },
      "diagnostics":{
        "sampled_Se_min":se_min,
        "sampled_Se_max":se_max,
        "finite_local_jacobian_condition_count":len(finite_jac),
        "median_local_jacobian_condition_number":float(np.median(finite_jac)) if finite_jac else None,
        "max_local_jacobian_condition_number":max(finite_jac) if finite_jac else None,
        "finite_metric_condition_count":len(finite_metric),
        "median_metric_condition_number":float(np.median(finite_metric)) if finite_metric else None,
        "max_metric_condition_number":max(finite_metric) if finite_metric else None,
        "min_metric_relative_eigenvalue":min((m["min_over_max_eigenvalue"] for m in metrics),default=None),
        "max_metric_grid_relative_frobenius":max((m["metric_grid_relative_frobenius"] for m in metrics),default=None),
        "max_b_grid_relative_l2":max((m["b_grid_relative_l2"] for m in metrics),default=None),
        "max_head_stationarity_residual":max((op["stationarity_residual"] for op in head_ops),default=None),
        "max_flux_stationarity_residual":max((op["stationarity_residual"] for op in flux_ops),default=None),
        "max_flux_constraint_residual_cm_per_day":max((op["constraint_residual_cm_per_day"] for op in flux_ops),default=None)
      },
      "rows":rows,
      "scientific_firewall":{
        "hydrological_response_used":False,
        "model_run_executed":False,
        "c6d_response_used_for_design":False,
        "c6e_failures_used_for_penalty_design":False,
        "BEMR_reopened":False,
        "free_running_FEMO_implemented":False,
        "moment_localization_selected":False,
        "fitted_parameter_added":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True,allow_nan=False)+"\n")
    print(json.dumps({
      "status":status,"gates":gates,"counts":out["qualification_counts"],
      "diagnostics":out["diagnostics"]
    },sort_keys=True,allow_nan=False))


if __name__=="__main__":
    main()
