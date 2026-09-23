#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

SUCCESS = "C6R_ROOT_ACTIVE_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED"
HISTORIES = ("V01","V02","V03","V04")

def fields(line: str) -> dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def verify_full_potential(path: Path, guard: float) -> dict[str,object]:
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
        if sorted(rows[h]) != list(range(1,1025)):
            raise SystemExit(f"{path} {h}: incomplete root observations")
        fractions=[rows[h][i]["fraction"] for i in range(1,1025)]
        rate_error=max(abs(rows[h][i]["rate"]-rows[h][i]["ptra"]) for i in range(1,1025))
        fraction_error=max(abs(x-1.0) for x in fractions)
        out[h]={
            "max_abs_fraction_error":fraction_error,
            "max_abs_rate_error_cm_per_day":rate_error,
            "full_potential_identity":fraction_error <= guard and rate_error <= guard,
        }
    return out

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--raw",required=True,type=Path)
    ap.add_argument("--s3-prereg",required=True,type=Path)
    ap.add_argument("--b01-target",required=True,type=Path)
    ap.add_argument("--b14-target",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    a=ap.parse_args()

    pre=json.loads(a.s3_prereg.read_text())
    raw=json.loads(a.raw.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_ANY_STAGE3_REDUCED_DYNAMIC_FEEDBACK_RESPONSE":
        raise SystemExit("invalid Stage3 preregistration")
    guard=float(pre["metrics"]["stress_definition"].split()[-1]) if False else 2.9103830456733704e-11
    identity={
        "B01":verify_full_potential(a.b01_target,guard),
        "B14":verify_full_potential(a.b14_target,guard),
    }
    identity_pass=all(v["full_potential_identity"] for mat in identity.values() for v in mat.values())
    uncertainty_pass=raw.get("status")==SUCCESS
    integrity_pass=bool(raw.get("integrity_pass",False))
    qualified=bool(identity_pass and uncertainty_pass and integrity_pass)
    status=("S3C0_FULL_POTENTIAL_REFERENCE_QUALIFIED"
            if qualified else "S3C0_FULL_POTENTIAL_REFERENCE_NOT_QUALIFIED")
    decision=("STAGE3_DYNAMIC_REDUCED_RESPONSE_MAY_EXECUTE"
              if qualified else "STOP_BEFORE_STAGE3_DYNAMIC_REDUCED_RESPONSE")
    out={
        "schema":"swap5.rom_root.s3c0.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3-C0",
        "date":"2026-09-23",
        "status":status,
        "decision":decision,
        "full_potential_identity_pass":identity_pass,
        "full_potential_identity":identity,
        "uncertainty_pass":uncertainty_pass,
        "integrity_pass":integrity_pass,
        "reference_target":"R2048_T32",
        "materials":raw.get("materials",{}),
        "frozen_raw_uncertainty_result":raw,
        "scientific_firewall":{
            "ra02r_reclassified":False,
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
        "status":status,
        "decision":decision,
        "identity_pass":identity_pass,
        "uncertainty_pass":uncertainty_pass,
        "integrity_pass":integrity_pass,
        "materials":{m:{
            "pass":v["reference_uncertainty_pass"],
            "metrics":{k:q["U_combined"] for k,q in v["metrics"].items()}
        } for m,v in raw.get("materials",{}).items()},
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
