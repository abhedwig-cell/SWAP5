#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

SUCCESS="C6R_ROOT_ACTIVE_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED"
FAILURE="C6R_ROOT_ACTIVE_REFERENCE_UNCERTAINTY_NOT_QUALIFIED"
HISTORIES=("V01","V02","V03","V04")

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def root_activation(path:Path,guard:float)->dict[str,object]:
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
          "fraction":float(r["ACTUAL_FRACTION"]),
          "rate":float(r["ACTUAL_RATE"]),
          "ptra":float(r["PTRA"])
        }
    out={}
    for h in HISTORIES:
        if sorted(rows[h])!=list(range(1,1025)):
            raise SystemExit(f"{path} {h}: incomplete root observations")
        fractions=[rows[h][i]["fraction"] for i in range(1,1025)]
        first=fractions[0]
        stressed=[i for i,x in enumerate(fractions,1) if x < 1.0-guard]
        out[h]={
          "first_fraction":first,
          "first_within_roundoff_guard":abs(first-1.0)<=guard,
          "minimum_fraction":min(fractions),
          "first_stress_observation":stressed[0] if stressed else None,
          "stress_observation_count":len(stressed),
          "stress_activated":bool(stressed and stressed[0]>1),
          "maximum_fraction_deficit":max(0.0,1.0-min(fractions))
        }
    return out

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--raw",required=True,type=Path)
    ap.add_argument("--prereg",required=True,type=Path)
    ap.add_argument("--b01-target",required=True,type=Path)
    ap.add_argument("--b14-target",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    raw=json.loads(args.raw.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_RA02_REFERENCE_RESPONSE":
        raise SystemExit("invalid RA02 preregistration state")
    if raw.get("status") not in (SUCCESS,FAILURE):
        raise SystemExit(f"unexpected frozen analyzer status {raw.get('status')}")
    guard=float(pre["activation_gate"]["absolute_fraction_roundoff_guard"])
    activation={
      "B01":root_activation(args.b01_target,guard),
      "B14":root_activation(args.b14_target,guard)
    }
    activation_pass=all(
      row["first_within_roundoff_guard"] and row["stress_activated"]
      for mat in activation.values() for row in mat.values()
    )
    uncertainty_pass=raw["status"]==SUCCESS
    qualified=bool(raw.get("integrity_pass",False) and activation_pass and uncertainty_pass)
    status=("RA02_STRESS_ACTIVE_REFERENCE_QUALIFIED" if qualified
            else "RA02_STRESS_ACTIVE_REFERENCE_NOT_QUALIFIED")
    decision=("NEW_STRESS_ACTIVE_REFERENCE_AUTHORITY_AVAILABLE_STAGE2_MAY_BE_PREREGISTERED"
              if qualified else "STOP_BEFORE_REDUCED_RESPONSE")
    out={
      "schema":"swap5.rom_root.ra02.result.v1",
      "workstream":"ROM-ROOT",
      "work_unit":"ROM-ROOT-RA02",
      "date":"2026-09-23",
      "status":status,
      "decision":decision,
      "stress_activation_guard":guard,
      "stress_activation_pass":activation_pass,
      "stress_activation":activation,
      "uncertainty_pass":uncertainty_pass,
      "integrity_pass":bool(raw.get("integrity_pass",False)),
      "reference_target":"R2048_T32",
      "materials":raw.get("materials",{}),
      "frozen_raw_uncertainty_result":raw,
      "scientific_firewall":{
        "c6r_reopened":False,
        "c6r_reclassified":False,
        "ra01_reclassified":False,
        "reduced_candidate_response_generated":False,
        "stage2_executed":False,
        "stage3_executed":False,
        "new_root_specific_state_selected":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      },
      "model_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "decision":decision,
      "integrity":out["integrity_pass"],
      "stress_activation_pass":activation_pass,
      "uncertainty_pass":uncertainty_pass,
      "activation":activation
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
