#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

HERE=pathlib.Path(__file__).resolve().parent
SURF_H=("S09","S10","S11","S12")
GW_H=("G06","G07","G08","G09")


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


p2=load_module("rom_purpose_p3_surface_reference_policy",HERE/"analyze_rom_purpose_p2_reference.py")
p1=load_module("rom_purpose_p3_gw_reference_policy",HERE/"analyze_rom_purpose_p1_reference.py")


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_NEW_P3_REFERENCE_OR_CANDIDATE_RESPONSE"
    assert tuple(pre["blind_validation_workload"]["SURF_P"]["ids"])==SURF_H
    assert tuple(pre["blind_validation_workload"]["GW_LB"]["ids"])==GW_H
    assert pre["reference_and_comparator"]["target"]=="R2048_T32"
    assert pre["reference_and_comparator"]["comparator"]=="R512_T32"
    assert pre["reference_and_comparator"]["O0_O2_scientific_identity_required"] is True
    assert float(pre["reference_and_comparator"]["max_abs_transaction_mass_cm"])==1.0e-12

    p2.HISTORIES=SURF_H
    p2.PHASES={
        "S09":("WET","DRY","WET","DRY"),
        "S10":("DRY","WET","DRY","WET"),
        "S11":("WET","DRY","WET","DRY"),
        "S12":("DRY","WET","DRY","WET"),
    }
    p1.GW_H=GW_H

    surface={m:p2.qualify_surface(m,a.root) for m in ("B01","B14")}
    gw={m:p1.qualify_purpose("gw",m,a.root) for m in ("B01","B14")}

    qualified=all(surface[m]["qualified"] for m in surface) and all(gw[m]["qualified"] for m in gw)
    status=(
        "P3_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
        if qualified else "P3_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES"
    )
    out={
      "schema":"swap5.rom-purpose.p3.reference-result.v1",
      "workstream":"ROM-PURPOSE",
      "work_unit":"ROM-PURPOSE-P3-REFERENCE",
      "status":status,
      "candidate_response_authorized":bool(qualified),
      "fresh_reference":{
        "SURF_P":surface,
        "GW_LB":gw
      },
      "reference_policy":{
        "SURF_P":"P2 frozen numerical-observability and extremum-observability policy, applied to fresh S09-S12.",
        "GW_LB":"P1/P2 inherited three-level numerical and discrete reversal qualification policy, applied to fresh G06-G09.",
        "target":"R2048_T32",
        "comparator":"R512_T32"
      },
      "interpretation":{
        "numerical_uncertainty_is_application_tolerance":False,
        "representation_or_closure_adjudicated":False,
        "candidate_response_generated":False
      },
      "scientific_firewall":{
        "p2_admission_histories_reused":False,
        "candidate_response_generated":False,
        "representation_tuned_from_response":False,
        "reference_policy_tuned_from_response":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "qualified":qualified,
      "SURF_P":{m:surface[m]["qualified"] for m in surface},
      "GW_LB":{m:gw[m]["qualified"] for m in gw}
    },sort_keys=True))
    return 0 if qualified else 3


if __name__=="__main__":
    raise SystemExit(main())
