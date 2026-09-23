#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,statistics

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    rows=[json.loads(p.read_text()) for p in sorted(a.input_dir.rglob("result.json"))]
    if len(rows)!=8: raise SystemExit(f"expected 8 case results, found {len(rows)}")
    summary={}
    for purpose in ("SURF_P","GW_LB"):
        rr=[r for r in rows if r["purpose"]==purpose]
        bysplit={}
        for split in ("development","validation"):
            rs=[r for r in rr if r["split"]==split]
            counts={}
            for r in rs: counts[r["classification"]]=counts.get(r["classification"],0)+1
            ratios=[r["performance"]["candidate_over_reference_wall_ratio"] for r in rs if r["performance"]["candidate_over_reference_wall_ratio"] is not None]
            bysplit[split]={
              "classification_counts":counts,
              "materials":{r["material"]:r["classification"] for r in rs},
              "observable_primary_discrete_claim_count":sum(bool(r["reference_observable_for_primary_discrete_claim"]) for r in rs),
              "wall_ratio":({"min":min(ratios),"median":statistics.median(ratios),"max":max(ratios)} if ratios else None)
            }
        summary[purpose]=bysplit
    val=[r for r in rows if r["split"]=="validation"]
    decision="P3_DAILY_VALIDATION_COMPLETE_PURPOSE_FAMILY_RETAINED_WITH_ERROR_REGIMES"
    out={
      "schema":"swap5.rom-practical.p3.aggregate-result.v1","workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P3",
      "status":"P3_60_DAY_DAILY_VALIDATION_COMPLETE","decision":decision,
      "summary":summary,"cases":rows,
      "validation_materials":["B05","B16"],
      "interpretation":[
        "This is a 60-day daily validation, not a seasonal validation.",
        "S4 and G8 were frozen before response and were not tuned per material.",
        "Discrete timing/event claims are qualified against R64-vs-R128 reference observability.",
        "Runtime ratios are same-job GitHub Actions implementation measurements only."
      ],
      "P_ROM_ET_opened":False,"state_count_escalated":False,"closure_changed":False,
      "production_rom_authorized":False,"application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":out["status"],"summary":summary},sort_keys=True))
if __name__=="__main__": main()
