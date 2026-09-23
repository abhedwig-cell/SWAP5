#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib
import numpy as np

EVENT=("bottom_flux_sign_mismatch_count","reversal_sequence_mismatch_count","reversal_timing_error_steps")
CONT=("cumulative_bottom_exchange_error_cm","interval_bottom_flux_error_cm_per_day","total_storage_error_cm","history_signed_bottom_flux_bias_cm_per_day","long_horizon_exchange_drift_cm")

def relation(a,b,keys,tol=1e-12):
    left=all(float(a[k])<=float(b[k])+tol for k in keys)
    right=all(float(b[k])<=float(a[k])+tol for k in keys)
    lstrict=any(float(a[k])<float(b[k])-tol for k in keys)
    rstrict=any(float(b[k])<float(a[k])-tol for k in keys)
    if left and lstrict and not (right and rstrict): d="G6_COMPONENTWISE_NO_WORSE"
    elif right and rstrict and not (left and lstrict): d="G4_COMPONENTWISE_NO_WORSE"
    elif left and right: d="EQUAL_WITHIN_TOLERANCE"
    else: d="TRADEOFF"
    return {"decision":d,"G6_no_worse":left,"G4_no_worse":right,"G6_strict":lstrict,"G4_strict":rstrict,
            "G6_minus_G4":{k:float(a[k])-float(b[k]) for k in keys}}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--g6-case",required=True,type=pathlib.Path)
    ap.add_argument("--p2a-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    g6=json.loads(a.g6_case.read_text())
    p2a=json.loads(a.p2a_result.read_text())
    g4=next(x for x in p2a["cases"] if x["purpose"]=="GW_LB" and x["material"]==a.material)
    m6=g6["candidate_metrics"]; m4=g4["candidate_metrics"]
    er=relation(m6,m4,EVENT,0.0)
    cr=relation(m6,m4,CONT,1e-12)
    event_supported=bool(er["G6_no_worse"] and er["G6_strict"])
    out={
      "schema":"swap5.rom-practical.p2b-gw1.case-result.v1",
      "material":a.material,
      "G4_metrics":m4,"G6_metrics":m6,
      "event_relation":er,"continuous_relation":cr,
      "event_repair_supported":event_supported,
      "G6_reference_comparator_relation":{
        "candidate_reaches_comparator":g6["candidate_reaches_comparator"],
        "reference_numerical_comparator":g6["reference_numerical_comparator"]
      },
      "performance":g6["performance"],
      "interpretation":(
        "G6 improves the complete discrete event vector without event degradation."
        if event_supported else
        "G6 does not provide a componentwise event-vector repair relative to G4."
      ),
      "development_only":True,
      "production_rom_authorized":False,
      "application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"material":a.material,"event_relation":er["decision"],"continuous_relation":cr["decision"],"event_repair_supported":event_supported},sort_keys=True))
if __name__=="__main__": main()
