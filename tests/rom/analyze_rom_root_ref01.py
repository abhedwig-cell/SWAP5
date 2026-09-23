#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, re
from pathlib import Path

POLICY=re.compile(
    r"ROM_ROOT_REF01_POLICY\|CASE=(?P<case>[^|]+)"
    r"\|F_REPR_CM=(?P<floor>[^|]+)"
    r"\|A_TOTAL_CM=(?P<allow>[^|]+)"
    r"\|NOMINAL_DT_DAY=(?P<dt>[^|]+)"
    r"\|NOMINAL_TOTAL_RATE=(?P<rate>[^|]+)"
    r"\|LOCAL_RATE=(?P<local>[^|]+)"
    r"\|MAXIT=(?P<maxit>\d+)"
)

def close(a:float,b:float)->bool:
    scale=max(1.0,abs(a),abs(b))
    return abs(a-b) <= 64.0*math.ulp(scale)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=Path)
    ap.add_argument("--metric-result",required=True,type=Path)
    ap.add_argument("--routes",required=True,nargs="+",type=Path)
    ap.add_argument("--output",required=True,type=Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    metric=json.loads(a.metric_result.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_REF01_ROOT_ACTIVE_RESPONSE"

    policy_records=[]
    policy_ok=True
    per_file={}
    for path in a.routes:
        raw=path.read_text(errors="replace")
        rows=[]
        for m in POLICY.finditer(raw):
            row={
                "case":m["case"].strip(),
                "F_repr_cm":float(m["floor"]),
                "A_total_cm":float(m["allow"]),
                "nominal_dt_day":float(m["dt"]),
                "nominal_total_rate":float(m["rate"]),
                "local_rate":float(m["local"]),
                "max_iterations":int(m["maxit"])
            }
            expected_allow=max(1.6e-15,row["F_repr_cm"])
            expected_rate=expected_allow/row["nominal_dt_day"]
            row["formula_pass"]=(
                math.isfinite(row["F_repr_cm"]) and row["F_repr_cm"]>0.0
                and close(row["A_total_cm"],expected_allow)
                and close(row["nominal_total_rate"],expected_rate)
                and row["local_rate"]==1.0e-12
                and row["max_iterations"]==16
            )
            policy_ok &= row["formula_pass"]
            rows.append(row)
            policy_records.append(row)
        per_file[path.name]={"policy_records":len(rows),"policy_pass":all(r["formula_pass"] for r in rows) and bool(rows)}
        policy_ok &= per_file[path.name]["policy_pass"]

    metric_qualified=metric.get("status")=="C6R_ROOT_ACTIVE_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED"
    hard_mass_ok=all(
        float(metric["materials"][m]["max_abs_transaction_mass_cm"]) <= 1.0e-12
        for m in ("B01","B14")
    )
    qualified=bool(metric_qualified and hard_mass_ok and policy_ok)
    status=(
        "QUALIFIED_ROOT_ACTIVE_REFERENCE_UNDER_INDEPENDENT_REPRESENTATION_FLOOR_POLICY"
        if qualified else
        "REFERENCE_REMAINS_NOT_QUALIFIED_STOP_BEFORE_REDUCED_RESPONSE"
    )
    decision=(
        "AUTHORIZE_ROM_ROOT_STAGE2_PRESCRIBED_SINK_EQUIVALENCE"
        if qualified else
        "STOP_BEFORE_REDUCED_RESPONSE"
    )
    out={
        "schema":"swap5.rom_root.ref01.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-REF01",
        "status":status,
        "decision":decision,
        "metric_authority":{
            "unchanged_c6r_three_level_analyzer_status":metric.get("status"),
            "integrity_pass":bool(metric.get("integrity_pass")),
            "materials":metric.get("materials")
        },
        "policy_materialization":{
            "records":len(policy_records),
            "policy_pass":policy_ok,
            "files":per_file,
            "formula":"max(1.6e-15 cm, sum_i(dz_i*spacing(theta_s_i))) / actual_trial_dt_day",
            "local_rate_unchanged_cm_per_day":1.0e-12,
            "max_iterations_unchanged":16
        },
        "hard_mass_gate_cm":1.0e-12,
        "hard_mass_gate_pass":hard_mass_ok,
        "scientific_firewall":{
            "reduced_candidate_response_generated":False,
            "dynamic_root_feedback_executed":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"decision":decision,"policy_records":len(policy_records),"policy_pass":policy_ok,"hard_mass_pass":hard_mass_ok},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
