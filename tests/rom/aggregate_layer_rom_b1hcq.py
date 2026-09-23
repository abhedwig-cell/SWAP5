#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
DIMS={"L4":4,"L6":6,"R8":8}
HISTS=("X01","X02","X03","X04")


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_SAME_PARTITION_CORICHARDS_TRANSFER_QUALIFICATION":
        raise SystemExit("wrong B1HC-Q preregistration phase")
    if tuple(pre["frozen_cohort"]["materials"])!=MATERIALS:
        raise SystemExit("material set drift")
    if tuple(x["id"] for x in pre["partitions"])!=MEMBERS:
        raise SystemExit("member set drift")

    results={}
    controls={}
    for path in a.input_dir.rglob("LAYER_ROM_B1HCQ_*_RESULT.json"):
        row=json.loads(path.read_text())
        if row.get("schema")!="swap5.layer-rom.phase-b1hc-q.member-result.v1":
            continue
        key=(row["material"],row["member"])
        if key in results:
            raise SystemExit(f"duplicate result {key}")
        results[key]=row
    for path in a.input_dir.rglob("LAYER_ROM_B1HCQ_*_CONTROL.json"):
        row=json.loads(path.read_text())
        material=row["material"]
        if material in controls:
            raise SystemExit(f"duplicate control {material}")
        controls[material]=row

    expected={(m,r) for m in MATERIALS for r in MEMBERS}
    if set(results)!=expected:
        raise SystemExit(f"result set mismatch missing={sorted(expected-set(results))} extra={sorted(set(results)-expected)}")
    if set(controls)!=set(MATERIALS):
        raise SystemExit(f"control set mismatch {sorted(controls)}")

    technical={}
    all_identity=True
    maxmass=0.0
    control_pass=True
    for material in MATERIALS:
        ctrl=controls[material]
        control_pass &= bool(ctrl["pass"])
        control_pass &= bool(ctrl["R16_exact_B1H_reproduction"])
        for member in MEMBERS:
            r=results[(material,member)]
            if r["technical_failure_histories"]:
                technical[f"{material}:{member}"]=r["technical_failure_histories"]
            all_identity &= bool(r["all_status_or_trace_identity"])
            maxmass=max(maxmass,float(r["maximum_qualified_mass_residual_cm"]))

    hard=(
        control_pass
        and not technical
        and all_identity
        and maxmass<=1e-12
    )

    matrix={}
    member_totals={}
    full_members=[]
    for member in MEMBERS:
        qcells=[]
        material_rows={}
        for material in MATERIALS:
            r=results[(material,member)]
            material_rows[material]={
              "qualified_histories":r["qualified_histories"],
              "fail_closed_histories":r["fail_closed_histories"],
              "qualified_history_count":r["qualified_history_count"]
            }
            qcells.extend((material,h) for h in r["qualified_histories"])
        member_totals[member]={
          "dimension":DIMS[member],
          "qualified_cell_count":len(qcells),
          "total_cell_count":len(MATERIALS)*len(HISTS),
          "full_common_cohort":len(qcells)==len(MATERIALS)*len(HISTS),
          "qualified_cells":[f"{m}:{h}" for m,h in qcells]
        }
        if member_totals[member]["full_common_cohort"]:
            full_members.append(member)
        matrix[member]=material_rows

    any_qualified=any(x["qualified_cell_count"]>0 for x in member_totals.values())
    if not hard:
        decision="B1HCQ_COMPARATOR_AUTHORITY_BLOCKED"
    elif full_members:
        decision="B1HCQ_FULL_COMMON_COHORT_AVAILABLE"
    elif any_qualified:
        decision="B1HCQ_PARTIAL_COMMON_COHORT_ONLY"
    else:
        decision="B1HCQ_REDUCED_COMPARATOR_UNAVAILABLE"

    common_all_members=set(f"{m}:{h}" for m in MATERIALS for h in HISTS)
    for member in MEMBERS:
        common_all_members &= set(member_totals[member]["qualified_cells"])

    result={
      "schema":"swap5.layer-rom.phase-b1hc-q.result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HC-Q",
      "decision":decision,
      "integrity":{
        "pass":hard,
        "material_control_pass":control_pass,
        "technical_failures":technical,
        "all_status_or_trace_identity":all_identity,
        "maximum_qualified_mass_residual_cm":maxmass
      },
      "controls":controls,
      "availability_matrix":matrix,
      "member_totals":member_totals,
      "full_common_cohort_members":full_members,
      "minimum_full_common_cohort_dimension":(
        None if not full_members else min(DIMS[m] for m in full_members)
      ),
      "qualified_cells_common_to_all_three_members":sorted(common_all_members),
      "qualified_cell_count_common_to_all_three_members":len(common_all_members),
      "hydrological_decomposition_authorized":decision in (
        "B1HCQ_FULL_COMMON_COHORT_AVAILABLE","B1HCQ_PARTIAL_COMMON_COHORT_ONLY"
      ),
      "interpretation":[
        "B1HC-Q is numerical comparator qualification only. It does not compare hydrological errors.",
        "A fail-closed cell is excluded from any later same-partition decomposition; its hydrology may not be extrapolated.",
        "A full common cohort means one frozen partition is numerically admissible for all 24 material-history cells under the unchanged policy.",
        "No time-step, tolerance, fallback, partition, closure or material selection may be changed from this result."
      ],
      "hydrological_comparison_performed":False,
      "performance_measurement_performed":False,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "integrity":result["integrity"],
      "member_totals":member_totals,
      "full_common_cohort_members":full_members,
      "common_all_three_count":len(common_all_members)
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
