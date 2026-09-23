#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

SUCCESS="C6R_ROOT_ACTIVE_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED"
FAILURE="C6R_ROOT_ACTIVE_REFERENCE_UNCERTAINTY_NOT_QUALIFIED"

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--raw",required=True,type=Path)
    ap.add_argument("--prereg",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    raw=json.loads(args.raw.read_text())
    if prereg["state"]!="PREREGISTERED_BEFORE_RA01_REFERENCE_RESPONSE":
        raise SystemExit("invalid RA01 preregistration state")
    if raw.get("status") not in (SUCCESS,FAILURE):
        raise SystemExit(f"unexpected frozen analyzer status {raw.get('status')}")

    qualified=raw["status"]==SUCCESS
    status=("RA01_ROOT_ACTIVE_REFERENCE_TRANSFER_QUALIFIED"
            if qualified else
            "RA01_ROOT_ACTIVE_REFERENCE_TRANSFER_NOT_QUALIFIED")
    decision=("NEW_RESEARCH_ONLY_REFERENCE_AUTHORITY_AVAILABLE_STAGE2_MAY_BE_PREREGISTERED"
              if qualified else
              "STOP_BEFORE_REDUCED_RESPONSE")

    out={
      "schema":"swap5.rom_root.ra01.result.v1",
      "workstream":"ROM-ROOT",
      "work_unit":"ROM-ROOT-RA01",
      "date":"2026-09-23",
      "status":status,
      "decision":decision,
      "authority":{
        "external_policy":"PUB-P2E20 QUALIFIED_REF_HIGH_36_OF_36_USING_PROSPECTIVE_REPRESENTATION_FLOOR_POLICY",
        "external_head":"341b383c3e1872e9b5421c4f8742749259d9def4",
        "external_result_blob":"e6586623ec7c9d9f0d34fb741687deb8601f0615",
        "transfer_preregistration":"integration/f-rom/ROM_ROOT_RA01_PREREGISTRATION.json",
        "frozen_uncertainty_method":"tests/rom/analyze_lare_bc2_c6r_reference_uncertainty.py"
      },
      "policy":{
        "formula":"F_repr_cm=sum_i(dz_i*spacing(theta_s_i)); total_tol_rate=max(1e-12,F_repr_cm/dt_day)",
        "safety_factor":1,
        "root_active_first_solve_only":True,
        "second_attempt_rescue":False,
        "max_iterations":16,
        "max_backtracking":8,
        "compartment_balance_tolerance_rate":1e-12,
        "hard_transaction_mass_gate_cm":1e-12,
        "production_source_change":False
      },
      "qualification":{
        "qualified":qualified,
        "integrity_pass":bool(raw.get("integrity_pass",False)),
        "reference_target":"R2048_T32",
        "materials":raw.get("materials",{}),
        "frozen_raw_uncertainty_result":raw
      },
      "scientific_firewall":{
        "c6r_reopened":False,
        "c6r_reclassified":False,
        "reduced_candidate_response_generated":False,
        "stage2_executed":False,
        "stage3_executed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      },
      "model_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"decision":decision,"integrity":out["qualification"]["integrity_pass"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
