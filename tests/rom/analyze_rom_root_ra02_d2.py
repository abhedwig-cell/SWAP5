#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
from collections import defaultdict
from pathlib import Path

LINE_RE=re.compile(
    r"ROM_ROOT_RA02_D2_HISTORY\|CASE=(?P<case>V0[1-4])"
    r"\|ROOT_NODE_EVALS=(?P<evals>\d+)"
    r"\|STRESSED_NODE_EVALS=(?P<stress>\d+)"
    r"\|MIN_ALPHA=(?P<alpha>[^|\n]+)"
    r"\|MIN_H_MINUS_H3=(?P<margin>[^|\n]+)"
)
NAME_RE=re.compile(
    r"(?P<material>B01|B14)_(?P<route>R512_T32|R1024_T32|R2048_T32|R2048_T16|R2048_T8)_(?P<history>V0[1-4])(?:_seg(?P<seg>[1-4]))?\.txt$"
)

ROUTE_INFO={
    "R512_T32":(512,32),
    "R1024_T32":(1024,32),
    "R2048_T32":(2048,32),
    "R2048_T16":(2048,16),
    "R2048_T8":(2048,8),
}

def f(x:str)->float:
    return float(x.strip().replace("D","E").replace("d","e"))

def expected_evals(route:str,seg:bool)->int:
    nodes,factor=ROUTE_INFO[route]
    rooted=nodes//2
    steps=8192 if route=="R2048_T32" and seg else 1024*factor
    return rooted*steps

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=Path)
    ap.add_argument("--logs",required=True,nargs="+",type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_RA02_D2_REFERENCE_RESPONSE":
        raise SystemExit("invalid D2 preregistration state")

    raw=[]
    for path in args.logs:
        m=NAME_RE.match(path.name)
        if not m:
            continue
        hits=list(LINE_RE.finditer(path.read_text(errors="replace")))
        if len(hits)!=1:
            raise SystemExit(f"{path}: expected one D2 history summary, found {len(hits)}")
        h=hits[0]
        if h["case"]!=m["history"]:
            raise SystemExit(f"{path}: history mismatch")
        alpha=f(h["alpha"]); margin=f(h["margin"])
        if not math.isfinite(alpha) or not math.isfinite(margin):
            raise SystemExit(f"{path}: nonfinite diagnostic")
        rec={
          "material":m["material"],"route":m["route"],"history":m["history"],
          "segment":int(m["seg"]) if m["seg"] else None,
          "root_node_evaluations":int(h["evals"]),
          "stressed_node_evaluations":int(h["stress"]),
          "minimum_alpha":alpha,
          "minimum_h_minus_h3":margin,
          "expected_root_node_evaluations":expected_evals(m["route"],bool(m["seg"]))
        }
        rec["count_integrity"]=rec["root_node_evaluations"]==rec["expected_root_node_evaluations"]
        raw.append(rec)

    if len(raw)!=64:
        raise SystemExit(f"expected 64 route/segment records, found {len(raw)}")

    grouped=defaultdict(list)
    for r in raw:
        grouped[(r["material"],r["route"],r["history"])].append(r)

    expected_keys={(m,r,h) for m in ("B01","B14") for r in ROUTE_INFO for h in ("V01","V02","V03","V04")}
    if set(grouped)!=expected_keys:
        raise SystemExit("incomplete material/route/history coverage")

    cases={}
    integrity=True
    full=True
    for key in sorted(grouped):
        material,route,history=key
        rows=grouped[key]
        want=4 if route=="R2048_T32" else 1
        if len(rows)!=want:
            raise SystemExit(f"{key}: expected {want} records, found {len(rows)}")
        if route=="R2048_T32" and sorted(r["segment"] for r in rows)!=[1,2,3,4]:
            raise SystemExit(f"{key}: incomplete segment set")
        count_ok=all(r["count_integrity"] for r in rows)
        evals=sum(r["root_node_evaluations"] for r in rows)
        stressed=sum(r["stressed_node_evaluations"] for r in rows)
        min_alpha=min(r["minimum_alpha"] for r in rows)
        min_margin=min(r["minimum_h_minus_h3"] for r in rows)
        route_expected=(ROUTE_INFO[route][0]//2)*(1024*ROUTE_INFO[route][1])
        count_ok=count_ok and evals==route_expected
        case_full=(stressed==0 and min_alpha==1.0 and min_margin>=0.0 and count_ok)
        integrity=integrity and count_ok
        full=full and case_full
        cases[f"{material}_{route}_{history}"]={
          "root_node_evaluations":evals,
          "expected_root_node_evaluations":route_expected,
          "stressed_node_evaluations":stressed,
          "minimum_alpha":min_alpha,
          "minimum_h_minus_h3":min_margin,
          "count_integrity":count_ok,
          "full_potential_identity":case_full
        }

    if not integrity:
        classification="DIAGNOSTIC_INTEGRITY_FAILURE"
    elif full:
        classification="NODE_LEVEL_FULL_POTENTIAL_IDENTITY"
    else:
        classification="NODE_LEVEL_PHYSICAL_STRESS_PRESENT"

    out={
      "schema":"swap5.rom_root.ra02_d2.result.v1",
      "workstream":"ROM-ROOT",
      "work_unit":"ROM-ROOT-RA02-D2",
      "date":"2026-09-23",
      "status":"DIAGNOSTIC_COMPLETE",
      "classification":classification,
      "cases":cases,
      "summary":{
        "all_count_integrity":integrity,
        "all_full_potential_identity":full,
        "total_root_node_evaluations":sum(c["root_node_evaluations"] for c in cases.values()),
        "total_stressed_node_evaluations":sum(c["stressed_node_evaluations"] for c in cases.values()),
        "global_minimum_alpha":min(c["minimum_alpha"] for c in cases.values()),
        "global_minimum_h_minus_h3":min(c["minimum_h_minus_h3"] for c in cases.values())
      },
      "decision":{
        "ra01_reclassified":False,
        "reference_qualified":False,
        "reduced_candidate_response_generated":False,
        "d1_numerical_floor_interpretation_node_level_supported":classification=="NODE_LEVEL_FULL_POTENTIAL_IDENTITY",
        "original_ra02_release_supported":False,
        "ra02r_dependency_on_d2":False
      },
      "model_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"classification":classification,"summary":out["summary"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
