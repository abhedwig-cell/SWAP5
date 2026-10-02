#!/usr/bin/env python3
from __future__ import annotations
import argparse,glob,json,pathlib,statistics

MATERIALS=("B02","B05","B06","B11","B12","B16")
DIMS=(4,6,8)

def spread(v):
    s=sorted(float(x) for x in v)
    return {"min":s[0],"median":statistics.median(s),"max":s[-1]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--fidelity",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text());fid=json.loads(a.fidelity.read_text())
    if pre["phase"]!="PREREGISTERED_AFTER_PHASE_B_FIDELITY_FREEZE_BEFORE_NEW_TIMING_EXPOSURE":
        raise SystemExit("wrong COST1 preregistration")
    if fid["decision"]!="B1HCP_CORRECTED_MODEL_FORM_DECOMPOSITION_COMPLETE":
        raise SystemExit("wrong frozen fidelity authority")

    rows={}
    for m in MATERIALS:
        fs=list(a.input_dir.glob(f"**/LAYER_ROM_COST1_{m}_RESULT.json"))
        if len(fs)!=1: raise SystemExit(f"{m}: expected one timing result, found {len(fs)}")
        r=json.loads(fs[0].read_text())
        if r["decision"]!="COST1_MATERIAL_SHARED_HOST_TIMING_COMPLETE":
            raise SystemExit(f"{m}: timing incomplete {r['decision']}")
        rows[m]=r

    by_dim={}
    for d in DIMS:
        per={}
        for m in MATERIALS:
            x=rows[m]["cost_ratios"][str(d)]
            per[m]={
              **x,
              "fidelity_relation":fid["groundwater_relations"][m][f"L{d}" if d in (4,6) else "R8"]
            }
        by_dim[str(d)]={
          "per_material":per,
          "BASE_over_R16_spread":spread([per[m]["BASE_over_R16"] for m in MATERIALS]),
          "FINE_over_R16_spread":spread([per[m]["FINE_over_R16"] for m in MATERIALS]),
          "BASE_over_CoRichards_spread":spread([per[m]["BASE_over_CoRichards"] for m in MATERIALS]),
          "FINE_over_CoRichards_spread":spread([per[m]["FINE_over_CoRichards"] for m in MATERIALS]),
          "FINE_over_BASE_spread":spread([per[m]["FINE_over_BASE"] for m in MATERIALS]),
          "BASE_cheaper_than_R16_count":sum(bool(per[m]["BASE_resolved_cheaper_than_R16"]) for m in MATERIALS),
          "FINE_cheaper_than_R16_count":sum(bool(per[m]["FINE_resolved_cheaper_than_R16"]) for m in MATERIALS),
          "BASE_cheaper_than_CoRichards_count":sum(bool(per[m]["BASE_resolved_cheaper_than_CoRichards"]) for m in MATERIALS),
          "FINE_cheaper_than_CoRichards_count":sum(bool(per[m]["FINE_resolved_cheaper_than_CoRichards"]) for m in MATERIALS),
          "robust_reduction_signal_vs_R16":all(
             per[m]["BASE_resolved_cheaper_than_R16"] and per[m]["FINE_resolved_cheaper_than_R16"]
             for m in MATERIALS
          )
        }

    result={
      "schema":"swap5.layer-rom.cost1.result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-COST1",
      "decision":pre["decisions"]["complete"],
      "materials":list(MATERIALS),"dimensions":list(DIMS),
      "by_dimension":by_dim,
      "per_material_timing":rows,
      "fidelity_authority":"integration/f-rom/LAYER_ROM_B1HCP_RESULT.json",
      "interpretation":[
        "CPU ratios are shared-host implementation screening values, not portable speedups.",
        "Layer-ROM BASE and FINE are timing brackets for the unchanged Heun equations; continuous-time fidelity remains governed by B1HCMR/B1HCP.",
        "The same-partition fidelity relation is shown beside cost but never collapsed to a weighted score.",
        "A robust reduction signal versus R16 requires both BASE and fourfold-refined FINE to be resolved cheaper on every material.",
        "Material-to-material ratio spreads are descriptive only; no pooled speedup estimator is defined."
      ],
      "application_acceptance_adjudicated":False,
      "formal_performance_claim":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":result["decision"],
      "by_dimension":{d:{k:v for k,v in x.items() if k!="per_material"} for d,x in by_dim.items()}
    },sort_keys=True))

if __name__=="__main__":
    raise SystemExit(main())
