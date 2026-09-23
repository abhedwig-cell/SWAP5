#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys

HERE=pathlib.Path(__file__).resolve().parent
TOL=1.0e-12
SURF_H=("S17","S18","S19","S20")
GW_H=("G17","G18","G19","G20")
RUNGS={"SURF_P":("S8","S12","S16"),"GW_LB":("G8","G12","G16")}

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None: raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod

decision_policy=load_module("rom_purpose_p4_decision_policy",HERE/"rom_purpose_p4_decision_policy.py")

p3=load_module("rom_purpose_p4_p3_analysis",HERE/"analyze_rom_purpose_p3_candidates.py")
p3.SURF_H=SURF_H; p3.GW_H=GW_H
p3.base.SURF_H=SURF_H; p3.base.GW_H=GW_H
p3.base.p2ref.HISTORIES=SURF_H
p3.base.p2ref.PHASES={
  "S17":("WET","DRY","WET","DRY"),
  "S18":("DRY","WET","DRY","WET"),
  "S19":("WET","DRY","WET","DRY"),
  "S20":("DRY","WET","DRY","WET"),
}
p3.base.p1ref.GW_H=GW_H

def load_candidate(root,purpose,material,member):
    obj=json.loads((root/f"{purpose}_{material}_{member}.json").read_text())
    assert obj["schema"]=="swap5.rom-purpose.p4.layer-candidate.v1"
    c=obj["candidate"]
    assert (c["purpose"],c["material"],c["id"])==(purpose,material,member)
    return c

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    ref_result=json.loads(a.reference_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P4_REFERENCE_LAYER_ROM_OR_MATCHED_RICHARDS_RESPONSE"
    assert ref_result["status"]=="P4_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
    assert ref_result["candidate_response_authorized"] is True

    refs,comparators=p3.reference_bundle(a.reference_root)
    cases={}; decisions={}; summary={}
    for purpose in ("SURF_P","GW_LB"):
        cases[purpose]={}; decisions[purpose]={}
        for material in ("B01","B14"):
            cases[purpose][material]={}
            for member in RUNGS[purpose]:
                cand=load_candidate(a.candidate_root,purpose,material,member)
                metrics=p3.candidate_metrics(purpose,cand,refs[purpose][material])
                cls,relation=p3.classify_case(metrics,cand["status"],comparators[purpose][material])
                cases[purpose][material][member]={
                  "status":cand["status"],"dimension":cand["dimension"],
                  "boundaries_cm":cand["boundaries_cm"],"metrics":metrics,
                  "representation_sufficiency":cls,"comparator_relation":relation,
                  "max_abs_water_ledger_cm":cand["max_abs_water_ledger_cm"],
                  "failures":cand["failures"]
                }
            frontier=decision_policy.frontier([
                (m, cases[purpose][material][m]["status"]=="QUALIFIED",
                 cases[purpose][material][m]["representation_sufficiency"]=="REPRESENTATION_COMPARATOR_REACHED")
                for m in RUNGS[purpose]
            ])
            minimum=frontier["minimum_tested_member"]
            decisions[purpose][material]={
              "minimum_tested_member":minimum,
              "minimum_tested_state_count":None if minimum is None else int(minimum[1:]),
              "minimum_tested_state_placement_cm":None if minimum is None else cases[purpose][material][minimum]["boundaries_cm"],
              "representation_frontier_status":frontier["frontier_status"],
              "frontier_evidence":frontier,
              "rungs":[
                {"member":m,"dimension":int(m[1:]),"classification":cases[purpose][material][m]["representation_sufficiency"]}
                for m in RUNGS[purpose]
              ]
            }
        mins=[decisions[purpose][m]["minimum_tested_state_count"] for m in ("B01","B14")]
        summary[purpose]={
          "both_materials_reach_comparator":all(
              decisions[purpose][m]["frontier_evidence"]["first_comparator_reaching_member"] is not None
              for m in ("B01","B14")),
          "both_material_minima_identified":all(x is not None for x in mins),
          "material_minima":{m:decisions[purpose][m]["minimum_tested_state_count"] for m in ("B01","B14")},
          "status":("PURPOSE_SPECIFIC_FINITE_REPRESENTATION_FRONTIER_SUPPORTED" if all(x is not None for x in mins)
                    else "REPRESENTATION_FRONTIER_NOT_ESTABLISHED_WITHIN_P4")
        }
    out={
      "schema":"swap5.rom-purpose.p4.layer-frontier-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P4-LAYER-FRONTIER",
      "reference_status":ref_result["status"],"componentwise_equality_tolerance":TOL,
      "cases":cases,"decisions":decisions,"purpose_summary":summary,
      "scientific_firewall":{
        "weighted_score_used":False,"materials_aggregated_for_primary_decision":False,
        "state_boundaries_changed_after_response":False,"closure_changed":False,
        "application_acceptance_adjudicated":False,"performance_comparison_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"purpose_summary":summary},sort_keys=True))

if __name__=="__main__": main()
