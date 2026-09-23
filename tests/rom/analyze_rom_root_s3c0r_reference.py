#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

EPS=2.220446049250313e-16
GUARD=2.9103830456733704e-11
OBS_DT=0.0008
OBSERVATIONS=1024
HORIZON=OBS_DT*OBSERVATIONS
ROUTES=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")


def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def gamma(k:int)->float:
    x=k*EPS
    if x>=1.0:
        raise ValueError(k)
    return x/(1.0-x)


def verify_route(path:pathlib.Path)->dict:
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
        }
    out={}
    for h in HISTORIES:
        if sorted(rows[h])!=list(range(1,OBSERVATIONS+1)):
            raise SystemExit(f"{path} {h}: incomplete root observations")
        max_frac=max(abs(rows[h][i]["fraction"]-1.0) for i in range(1,OBSERVATIONS+1))
        max_rate=max(
            abs(rows[h][i]["rate"]-rows[h][i]["ptra"])
            for i in range(1,OBSERVATIONS+1)
        )
        ptra=max(abs(rows[h][i]["ptra"]) for i in range(1,OBSERVATIONS+1))
        rate_bound=GUARD*max(1.0,ptra)
        out[h]={
            "max_abs_fraction_error":max_frac,
            "max_abs_rate_error_cm_per_day":max_rate,
            "fraction_bound":GUARD,
            "rate_bound_cm_per_day":rate_bound,
            "pass":bool(max_frac<=GUARD and max_rate<=rate_bound),
        }
    return out


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--artifact-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    c0=json.loads(a.c0_result.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_C0R_REQUALIFICATION"
    assert c0["status"]=="S3C0_FULL_POTENTIAL_REFERENCE_NOT_QUALIFIED"
    assert c0["execution"]["full_potential_identity_pass"] is True
    assert c0["execution"]["integrity_pass"] is True

    route_checks={}
    route_identity_pass=True
    for material in MATERIALS:
        route_checks[material]={}
        for route in ROUTES:
            p=a.artifact_dir/f"{material}_{route}_o0.txt"
            if not p.is_file():
                raise SystemExit(f"missing {p}")
            q=verify_route(p)
            route_checks[material][route]=q
            route_identity_pass &= all(v["pass"] for v in q.values())

    interval_u=GUARD
    cumulative_u=HORIZON*interval_u + gamma(OBSERVATIONS)*max(1.0,0.6*HORIZON)

    materials={}
    hydraulic_pass=True
    for material in MATERIALS:
        src=c0["materials"][material]
        qm=src["qualified_metrics"]
        hydraulic_required=(
            "root_zone_0_40_storage_rmse_cm",
            "upper_0_80_storage_rmse_cm",
            "mapped_10cm_theta_rmse",
        )
        hp=all(k in qm and qm[k] is not None for k in hydraulic_required)
        hydraulic_pass &= hp
        metrics={
            "root_zone_0_40_storage_rmse_cm":{"U_combined":float(qm["root_zone_0_40_storage_rmse_cm"]),"qualified":True,"qualification_route":"UNCHANGED_C0_THREE_LEVEL"},
            "upper_0_80_storage_rmse_cm":{"U_combined":float(qm["upper_0_80_storage_rmse_cm"]),"qualified":True,"qualification_route":"UNCHANGED_C0_THREE_LEVEL"},
            "mapped_10cm_theta_rmse":{"U_combined":float(qm["mapped_10cm_theta_rmse"]),"qualified":True,"qualification_route":"UNCHANGED_C0_THREE_LEVEL"},
            "interval_actual_root_uptake_rmse_cm_per_day":{"U_combined":interval_u,"qualified":bool(route_identity_pass),"qualification_route":"PRESCRIBED_INVARIANT_ARITHMETIC_ENVELOPE"},
            "cumulative_actual_root_uptake_rmse_cm":{"U_combined":cumulative_u,"qualified":bool(route_identity_pass),"qualification_route":"PRESCRIBED_INVARIANT_ARITHMETIC_ENVELOPE"},
        }
        materials[material]={
            "reference_uncertainty_pass":bool(hp and route_identity_pass),
            "metrics":metrics,
        }

    qualified=bool(route_identity_pass and hydraulic_pass)
    status="S3C0R_FULL_POTENTIAL_REFERENCE_QUALIFIED" if qualified else "S3C0R_FULL_POTENTIAL_REFERENCE_NOT_QUALIFIED"
    decision="STAGE3_DYNAMIC_REDUCED_RESPONSE_MAY_EXECUTE" if qualified else "STOP_BEFORE_STAGE3_DYNAMIC_REDUCED_RESPONSE"

    out={
        "schema":"swap5.rom_root.s3c0r.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3-C0R",
        "date":"2026-09-23",
        "status":status,
        "decision":decision,
        "source_c0_status":c0["status"],
        "source_c0_reclassified":False,
        "immutable_source_artifact":pre["predecessor"]["immutable_artifact"],
        "full_potential_route_identity_pass":route_identity_pass,
        "hydraulic_uncertainty_pass":hydraulic_pass,
        "interval_root_arithmetic_U_cm_per_day":interval_u,
        "cumulative_root_arithmetic_U_cm":cumulative_u,
        "route_checks":route_checks,
        "materials":materials,
        "interpretation":[
            "The original C0 result remains formally not qualified.",
            "C0R reuses the immutable C0 physics and changes only the qualification semantics for two analytically prescribed root-uptake metrics whose route variation is arithmetic, not spatial or temporal discretization error.",
            "The three hydraulic numerical uncertainty metrics are copied unchanged from C0.",
            "C0R is a Reference-control authority only and does not inspect reduced dynamic candidate response."
        ],
        "scientific_firewall":{
            "c0_reclassified":False,
            "reduced_dynamic_feedback_response_generated":False,
            "new_root_specific_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":status,
        "decision":decision,
        "route_identity_pass":route_identity_pass,
        "hydraulic_uncertainty_pass":hydraulic_pass,
        "interval_root_U":interval_u,
        "cumulative_root_U":cumulative_u
    },sort_keys=True))
    return 0 if qualified else 1


if __name__=="__main__":
    raise SystemExit(main())
