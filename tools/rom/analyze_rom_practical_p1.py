#!/usr/bin/env python3
import argparse, json
from pathlib import Path

def classify(purpose, rec):
    if not rec["qualified"]:
        return "STRUCTURALLY_UNRELIABLE"
    m=rec["metrics"]
    if purpose=="GW_LB" and (m["bottom_flux_sign_mismatch_count"]>0 or m["reversal_sequence_mismatch_count"]>0 or m["reversal_timing_error_steps"]>0):
        return "EVENT_SENSITIVE"
    if purpose=="SURF_P" and m["storage_extremum_timing_error_steps"]>0:
        return "TIMING_SENSITIVE"
    if rec["aligned_vs_U4_componentwise_no_worse"]:
        return "ROBUST"
    return "STRUCTURALLY_UNRELIABLE"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    data=json.load(open(a.input)); pre=json.load(open(a.prereg))
    result={
      "schema":"swap5.rom-practical.p1.evidence-screen-result.v1",
      "workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P1",
      "status":"P1_EVIDENCE_SCREEN_COMPLETE_FRESH_BLIND_BENCHMARK_REQUIRED",
      "reference":pre["reference"],
      "development_regime_map":{},
      "performance_screen":data["cost_screen"],
      "pareto_interpretation":[],
      "limitations":[
        "This is a development evidence screen over previously exposed dynamic P2 histories, not fresh blind validation.",
        "S4/G4 timing is not directly measured here; L4/L6/R8 COST1 supplies only a state-count implementation-cost prior.",
        "No application tolerance or production admission is adjudicated.",
        "MetaSWAP direct execution remains open."
      ],
      "next_gate":"FRESH_PRACTICAL_DYNAMIC_PANEL_PREREGISTRATION_AND_EXECUTION",
      "P_ROM_ET_opened":False,
      "production_rom_authorized":False,
      "application_acceptance_adjudicated":False
    }
    for purpose, mats in data["cases"].items():
        result["development_regime_map"][purpose]={}
        for mat, candidates in mats.items():
            name,rec=next(iter(candidates.items()))
            result["development_regime_map"][purpose][mat]={"candidate":name,"classification":classify(purpose,rec),"metrics":rec["metrics"],"aligned_vs_U4_componentwise_no_worse":rec["aligned_vs_U4_componentwise_no_worse"]}
    result["pareto_interpretation"]=[
      "Four-state implementations have the lowest measured COST1 CPU ratios of the frozen 4/6/8-state screen, but direct S4/G4 timing is still required.",
      "S4 is relatively robust on the exposed profile/storage development cases for both B01 and B14.",
      "G4 is relatively robust on B14 but event-sensitive on B01 because sign/reversal behaviour is not preserved.",
      "The first targeted practical repair, if confirmed on fresh data, should therefore focus on groundwater event/reversal representation rather than adding a general closure family."
    ]
    Path(a.output).parent.mkdir(parents=True,exist_ok=True)
    json.dump(result,open(a.output,"w"),indent=2,sort_keys=True); print(json.dumps(result,indent=2,sort_keys=True))

if __name__=="__main__": main()
