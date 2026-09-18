from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

MATERIALS = (
    "B01","B02","B03","B04","B05","B06","B07","B08","B09",
    "B10","B11","B12","B13","B14","B15","B16","B17","B18",
    "O01","O02","O03","O04","O05","O06","O07","O08","O09",
    "O10","O11","O12","O13","O14","O15","O16","O17","O18",
)


def parse_args():
    p=argparse.ArgumentParser()
    p.add_argument("--input-root",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    return p.parse_args()


def main():
    a=parse_args()
    rows=[]
    for path in sorted(a.input_root.rglob("diagnostic-*.json")):
        row=json.loads(path.read_text())
        if row.get("work_unit")=="F-ROSS14D1":
            rows.append(row)

    by={}
    dup=[]
    for row in rows:
        m=row["material"]
        if m in by:
            dup.append(m)
        else:
            by[m]=row
    missing=[m for m in MATERIALS if m not in by]
    unexpected=sorted(m for m in by if m not in MATERIALS)
    if missing or dup or unexpected or len(by)!=36:
        raise SystemExit(f"F_ROSS14D1_AGGREGATE_FAIL missing={missing} duplicate={dup} unexpected={unexpected}")

    inadmissible_materials=[m for m in MATERIALS if by[m]["inadmissible_route_count"]>0]
    production_relevant=[m for m in MATERIALS if by[m]["production_relevant_failure"]]
    clean=[m for m in MATERIALS if by[m]["inadmissible_route_count"]==0]

    by_se=Counter()
    by_step=Counter()
    by_pair=Counter()
    for m in MATERIALS:
        for k,v in by[m]["inadmissible_by_Se"].items():
            by_se[k]+=int(v)
        for k,v in by[m]["inadmissible_by_step_count"].items():
            by_step[k]+=int(v)
        for k,v in by[m]["inadmissible_by_Se_and_step_count"].items():
            by_pair[k]+=int(v)

    max_components=max(by[m]["max_transitioning_components"] for m in MATERIALS)
    max_disp=max(by[m]["max_abs_cell_displacement"] for m in MATERIALS)
    worst_route=max(MATERIALS,key=lambda m:by[m]["inadmissible_route_count"])
    worst_prod=max(MATERIALS,key=lambda m:by[m]["production_relevant_inadmissible_count"])

    result={
      "schema_version":1,
      "workstream":"F-ROSS",
      "work_unit":"F-ROSS14D1",
      "parent_work_unit":"F-ROSS14",
      "kind":"PIECEWISE_ROUTE_FAILURE_DIAGNOSTIC_AGGREGATE",
      "material_count":36,
      "target_top_internal_over_K":-0.025,
      "target_bottom_up_over_K":0.011,
      "materials_with_any_inadmissible_routes":inadmissible_materials,
      "materials_with_production_relevant_8_or_16_step_failures":production_relevant,
      "materials_without_inadmissible_routes":clean,
      "material_counts":{
        "any_inadmissible":len(inadmissible_materials),
        "production_relevant":len(production_relevant),
        "clean":len(clean)
      },
      "total_transition_route_count":sum(by[m]["transition_route_count"] for m in MATERIALS),
      "total_inadmissible_route_count":sum(by[m]["inadmissible_route_count"] for m in MATERIALS),
      "total_production_relevant_inadmissible_count":sum(by[m]["production_relevant_inadmissible_count"] for m in MATERIALS),
      "inadmissible_by_Se":dict(sorted(by_se.items())),
      "inadmissible_by_step_count":dict(sorted(by_step.items(),key=lambda kv:int(kv[0]))),
      "inadmissible_by_Se_and_step_count":dict(sorted(by_pair.items())),
      "max_transitioning_components":max_components,
      "max_abs_cell_displacement":max_disp,
      "worst_material_by_inadmissible_count":{
        "material":worst_route,
        "count":by[worst_route]["inadmissible_route_count"]
      },
      "worst_material_by_production_relevant_count":{
        "material":worst_prod,
        "count":by[worst_prod]["production_relevant_inadmissible_count"]
      },
      "max_abs_global_mass_residual_cm":max(by[m]["max_abs_global_mass_residual_cm"] for m in MATERIALS),
      "max_abs_cell_mass_residual_cm":max(by[m]["max_abs_cell_mass_residual_cm"] for m in MATERIALS),
      "domain_failure_count":sum(by[m]["domain_failure_count"] for m in MATERIALS),
      "head_envelope_failure_count":sum(by[m]["head_envelope_failure_count"] for m in MATERIALS),
      "nonfinite_count":sum(by[m]["nonfinite_count"] for m in MATERIALS),
      "per_material":{
        m:{
          "transition_route_count":by[m]["transition_route_count"],
          "inadmissible_route_count":by[m]["inadmissible_route_count"],
          "production_relevant_inadmissible_count":by[m]["production_relevant_inadmissible_count"],
          "production_relevant_failure":by[m]["production_relevant_failure"],
          "inadmissible_by_Se":by[m]["inadmissible_by_Se"],
          "inadmissible_by_step_count":by[m]["inadmissible_by_step_count"],
          "max_transitioning_components":by[m]["max_transitioning_components"],
          "max_abs_cell_displacement":by[m]["max_abs_cell_displacement"],
        } for m in MATERIALS
      },
      "interpretation":(
        "If production_relevant is non-empty, the exact target forcing violates the frozen adjacent-cell transition qualification not only in coarse historical probes but in the 8-step coarse and/or 16-step refined trajectories used to support the current D3R temporal certificate. F-ROSS14 therefore cannot be rescued by merely arguing that failures occur only at irrelevant coarse probes."
      ),
      "production_mutation_allowed":False,
      "verdict":(
        "TARGET_FORCING_HAS_PRODUCTION_RELEVANT_PIECEWISE_FAILURES"
        if production_relevant else
        "TARGET_FORCING_FAILURES_ARE_OUTSIDE_8_16_STEP_PRODUCTION_RELEVANT_TRAJECTORIES"
      )
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "any_inadmissible_materials":len(inadmissible_materials),
      "production_relevant_materials":len(production_relevant),
      "clean_materials":len(clean),
      "total_inadmissible":result["total_inadmissible_route_count"],
      "production_relevant_inadmissible":result["total_production_relevant_inadmissible_count"],
      "by_step":result["inadmissible_by_step_count"],
      "verdict":result["verdict"]
    },sort_keys=True))


if __name__=="__main__":
    main()
