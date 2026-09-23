#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib, statistics

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    rows=[json.loads(p.read_text()) for p in sorted(a.input_dir.rglob("*.json")) if p.name=="result.json"]
    if len(rows)!=12: raise SystemExit(f"expected 12 case results, found {len(rows)}")
    byp={"SURF_P":[],"GW_LB":[]}
    for r in rows: byp[r["purpose"]].append(r)
    summary={}
    for purpose,rr in byp.items():
        counts={}
        for r in rr: counts[r["classification"]]=counts.get(r["classification"],0)+1
        wr=[r["performance"]["candidate_over_reference_wall_ratio"] for r in rr]
        cr=[r["performance"]["candidate_over_reference_cpu_ratio"] for r in rr]
        summary[purpose]={
          "classification_counts":counts,
          "materials":{r["material"]:r["classification"] for r in rr},
          "wall_ratio":{"min":min(wr),"median":statistics.median(wr),"max":max(wr)},
          "cpu_ratio":{"min":min(cr),"median":statistics.median(cr),"max":max(cr)},
          "candidate_reaches_reference_comparator_count":sum(bool(r["candidate_reaches_comparator"]) for r in rr)
        }
    gw_event=[r["material"] for r in byp["GW_LB"] if r["classification"]=="EVENT_SENSITIVE"]
    surf_timing=[r["material"] for r in byp["SURF_P"] if r["classification"]=="TIMING_SENSITIVE"]
    if gw_event:
        next_decision="TARGETED_GW_REPRESENTATION_CHALLENGE_AUTHORIZED"
    elif surf_timing:
        next_decision="TARGETED_SURFACE_PROPAGATION_CHALLENGE_AUTHORIZED"
    else:
        next_decision="PROCEED_TO_LONGER_DAILY_SEASONAL_PANEL_WITHOUT_REPAIR"
    out={
      "schema":"swap5.rom-practical.p2a.aggregate-result.v1","workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P2A",
      "status":"P2A_CROSS_MATERIAL_PILOT_COMPLETE","summary":summary,
      "gw_event_sensitive_materials":gw_event,"surface_timing_sensitive_materials":surf_timing,
      "decision":next_decision,
      "cases":rows,
      "limitations":[
        "Short-horizon controlled dynamic pilot; not yet the requested longer production-like daily/seasonal forcing panel.",
        "R256 target with R128-vs-R256 comparator is a practical Reference Richards screen, not a new application authority.",
        "Performance ratios are same-job GitHub Actions implementation measurements only.",
        "No application acceptance or production admission."
      ],
      "P_ROM_ET_opened":False,"production_rom_authorized":False,"application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":next_decision,"summary":summary},sort_keys=True))
if __name__=="__main__": main()
