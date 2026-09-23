#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

EPS=2.220446049250313e-16
SCALE=64.0
BOUND=SCALE*EPS
HISTORIES=("V01","V02","V03","V04")
MATERIALS=("B01","B14")
ROUTES=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
TARGET="R2048_T32"
NOBS=1024
OBS_DT=0.0008

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def identity_bound(a:float,b:float)->float:
    return BOUND*max(1.0,abs(a),abs(b))

def parse(path:pathlib.Path)->dict[str,dict[int,dict[str,float]]]:
    rows={h:{} for h in HISTORIES}
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_ROOT|"):
            continue
        r=fields(line)
        h=r.get("CASE")
        if h not in rows:
            continue
        obs=int(r["OBS_STEP"])
        rows[h][obs]={
            "ptra":float(r["PTRA"]),
            "rate":float(r["ACTUAL_RATE"]),
            "fraction":float(r["ACTUAL_FRACTION"]),
            "cumulative":float(r["CUMULATIVE_ROOT"]),
        }
    for h in HISTORIES:
        if sorted(rows[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{path}: incomplete root observations for {h}: {len(rows[h])}/{NOBS}")
    return rows

def compare_series(a:list[float],b:list[float])->dict[str,object]:
    max_abs=0.0
    max_ratio=0.0
    fail_count=0
    worst_obs=None
    for i,(x,y) in enumerate(zip(a,b),start=1):
        d=abs(x-y)
        bound=identity_bound(x,y)
        ratio=d/bound if bound>0.0 else (0.0 if d==0.0 else math.inf)
        if d>max_abs:
            max_abs=d
            worst_obs=i
        max_ratio=max(max_ratio,ratio)
        if d>bound:
            fail_count+=1
    return {
        "pass":fail_count==0,
        "max_abs_difference":max_abs,
        "max_ratio_to_64eps_bound":max_ratio,
        "failure_count":fail_count,
        "worst_observation":worst_obs,
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--artifact-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_S3C0_D1_ROUTE_LEVEL_RESPONSE_INSPECTION"
    contract=pre["arithmetic_identity_contract"]
    assert float(contract["epsilon_binary64"])==EPS
    assert float(contract["scale"])==SCALE

    parsed={}
    for material in MATERIALS:
        parsed[material]={}
        for route in ROUTES:
            path=a.artifact_dir/f"{material}_{route}_o0.txt"
            if not path.is_file():
                raise RuntimeError(f"missing frozen C0 route: {path}")
            parsed[material][route]=parse(path)

    route_results={}
    full_identity={}
    all_pass=True
    for material in MATERIALS:
        full_identity[material]={}
        route_results[material]={}
        for history in HISTORIES:
            full_identity[material][history]={}
            route_results[material][history]={}
            for route in ROUTES:
                rows=parsed[material][route][history]
                obs=[rows[i] for i in range(1,NOBS+1)]
                frac=compare_series([x["fraction"] for x in obs],[1.0]*NOBS)
                rate=compare_series([x["rate"] for x in obs],[x["ptra"] for x in obs])
                analytic_cum=[x["ptra"]*OBS_DT*i for i,x in enumerate(obs,start=1)]
                cum_analytic=compare_series([x["cumulative"] for x in obs],analytic_cum)
                full_identity[material][history][route]={
                    "fraction_vs_one":frac,
                    "rate_vs_ptra":rate,
                    "cumulative_vs_analytic_full_potential_diagnostic":cum_analytic,
                    "decision_identity_pass":bool(frac["pass"] and rate["pass"]),
                }
                all_pass &= bool(frac["pass"] and rate["pass"])

            target=parsed[material][TARGET][history]
            t=[target[i] for i in range(1,NOBS+1)]
            for route in ROUTES:
                rows=parsed[material][route][history]
                r=[rows[i] for i in range(1,NOBS+1)]
                comparisons={
                    "rate":compare_series([x["rate"] for x in r],[x["rate"] for x in t]),
                    "fraction":compare_series([x["fraction"] for x in r],[x["fraction"] for x in t]),
                    "cumulative":compare_series([x["cumulative"] for x in r],[x["cumulative"] for x in t]),
                }
                route_pass=all(v["pass"] for v in comparisons.values())
                route_results[material][history][route]={
                    "vs_target":TARGET,
                    "metrics":comparisons,
                    "route_identity_pass":route_pass,
                }
                all_pass &= route_pass

    classification=(
        "STRUCTURAL_FULL_POTENTIAL_ROOT_UPTAKE_INVARIANT_AT_BINARY64_FLOOR"
        if all_pass else
        "ROOT_UPTAKE_ROUTE_DEPENDENCE_EXCEEDS_PREDECLARED_ARITHMETIC_IDENTITY_FLOOR"
    )
    implication=(
        "S3C0R_REQUALIFICATION_MAY_BE_PREREGISTERED"
        if all_pass else
        "S3C0_REMAINS_BLOCKED"
    )
    out={
        "schema":"swap5.rom_root.s3c0_d1.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3C0-D1",
        "date":"2026-09-23",
        "status":"S3C0_D1_INVARIANT_DIAGNOSTIC_COMPLETE",
        "classification":classification,
        "decision":implication,
        "criterion":{
            "formula":"abs(a-b) <= 64*epsilon_binary64*max(1,abs(a),abs(b))",
            "epsilon_binary64":EPS,
            "scale":SCALE,
            "base_floor":BOUND,
        },
        "full_potential_identity":full_identity,
        "route_to_target_identity":route_results,
        "all_decision_checks_pass":bool(all_pass),
        "authorized_arithmetic_floor_if_pass":{
            "interval_actual_root_uptake_rmse_cm_per_day":BOUND if all_pass else None,
            "cumulative_actual_root_uptake_rmse_cm":BOUND if all_pass else None,
            "actual_over_potential_fraction":BOUND if all_pass else None,
            "basis":"predeclared 64-epsilon structural-invariant arithmetic floor, not observed error"
        },
        "interpretation":{
            "original_s3c0_reclassified":False,
            "richardson_order_claimed_for_invariant_metrics":False,
            "application_tolerance":False,
            "dynamic_reduced_response_authorized":False,
        },
        "scientific_firewall":{
            "original_c0_reclassified":False,
            "reduced_dynamic_feedback_response_generated":False,
            "new_root_specific_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":out["status"],
        "classification":classification,
        "decision":implication,
        "all_checks":all_pass,
        "floor":BOUND,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
