#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,statistics

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    rows=[json.loads(p.read_text()) for p in sorted(a.input_dir.rglob("result.json"))]
    if len(rows)!=6: raise SystemExit(f"expected 6 case results, found {len(rows)}")
    supported=[r["material"] for r in rows if r["event_repair_supported"]]
    er={r["material"]:r["event_relation"]["decision"] for r in rows}
    cr={r["material"]:r["continuous_relation"]["decision"] for r in rows}
    wall=[r["performance"]["candidate_over_reference_wall_ratio"] for r in rows]
    if len(supported)==6:
        decision="G6_EVENT_REPAIR_GENERALIZED_BLIND_REVALIDATION_AUTHORIZED"
    else:
        decision="G6_EVENT_REPAIR_NOT_GENERALIZED_STOP_BEFORE_BLIND_REVALIDATION"
    out={
      "schema":"swap5.rom-practical.p2b-gw1.aggregate-result.v1",
      "workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P2B-GW1",
      "status":"P2B_GW1_DEVELOPMENT_CHALLENGE_COMPLETE",
      "decision":decision,
      "event_repair_supported_materials":supported,
      "event_relation_by_material":er,
      "continuous_relation_by_material":cr,
      "same_runner_G6_over_R256_wall_ratio":{"min":min(wall),"median":statistics.median(wall),"max":max(wall)},
      "cases":rows,
      "next_gate":("FREEZE_FRESH_BLIND_GW_PANEL_G4_VS_G6" if len(supported)==6 else "ATTRIBUTION_REVIEW_NO_AUTOMATIC_G8_OR_CLOSURE"),
      "G8_executed":False,
      "closure_changed":False,
      "development_only":True,
      "production_rom_authorized":False,
      "application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"supported":supported,"event_relations":er,"continuous_relations":cr},sort_keys=True))
if __name__=="__main__": main()
