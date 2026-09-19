#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS=("2.5","5.0")

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    cases={}
    for path in sorted(args.case_dir.glob("*.json")):
        row=json.loads(path.read_text())
        if row.get("schema")!="swap5.lare.bc2.c3b.case-result.v1":
            continue
        key=str(row["width_cm"])
        if key in cases:
            raise SystemExit(f"duplicate width {key}")
        cases[key]=row
    if set(cases)!=set(WIDTHS):
        raise SystemExit(f"case set mismatch {sorted(cases)}")

    complete=all(row["complete"] for row in cases.values())
    decisions={w:cases[w]["decision"] for w in WIDTHS}
    all_explain=complete and all(
        d=="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
        for d in decisions.values()
    )
    hard=[]
    for row in cases.values():
        for route in row["routes"].values():
            hard.append(float(route["hard_checks"]["maximum"]))
    max_hard=max(hard or [float("inf")])

    if not complete or max_hard>1e-10:
        decision="NUMERICAL_DIAGNOSTIC_BLOCKED"
    elif all_explain:
        decision="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
    else:
        decision="WITHIN_DIRECTION_REGIME_DEPENDENCE_REMAINS"

    result={
        "schema":"swap5.lare.bc2.c3b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3B",
        "decision":decision,
        "complete":complete and max_hard<=1e-10,
        "width_decisions":decisions,
        "cases":cases,
        "hard_checks":{
            "maximum_recorded_residual_or_identity_error":max_hard,
            "gate":1e-10,
            "all_widths_complete":complete,
        },
        "interpretation":[
            "C3B partitions only by the exact sign of prescribed Reference water-table depth change; no magnitude threshold is used.",
            "A positive result means the whole-cycle rank shift is explained by cancellation across physically distinct rising and falling blocks rather than a new cycle-specific closure family.",
            "C3B remains diagnostic. It implements no direction switch, closure correction, new state or groundwater feedback."
        ],
        "next_step":(
            "Preregister teacher-forced causal oracle-removal panel for QI, QH and QI+QH within the frozen Hdot-sign regimes."
            if decision=="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
            else
            "Retain finer phase/history dependence; do not use Hdot sign alone for a counterfactual."
        ),
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "complete":result["complete"],
        "width_decisions":decisions,
        "hard_checks":result["hard_checks"],
        "block_top_summary":{
            w:{
                route:[
                    {
                        "steps":b["steps"],
                        "regime":b["regime"],
                        "top":b["family_rank_by_cumulative_shape_injection"][0]
                    }
                    for b in cases[w]["routes"][route]["blocks"]
                ]
                for route in ("0.00005000","0.00002500")
            }
            for w in WIDTHS
        }
    },sort_keys=True))
    return 0 if result["complete"] else 2

if __name__=="__main__":
    raise SystemExit(main())
