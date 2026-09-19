#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

ORDER=("R3","R4","R5","R6","R8","R12")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--member-dir",required=True,type=pathlib.Path)
    ap.add_argument("--controls",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    ctrl=json.loads(a.controls.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4R_BEFORE_D13_SAME_PARTITION_CORICHARDS_QUALIFICATION"

    members={}
    for p in a.member_dir.rglob("LARE_BC2_C4S_*_RESULT.json"):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.bc2.c4s.member-result.v1": continue
        if r["member"] in members: raise SystemExit(f"duplicate {r['member']}")
        members[r["member"]]=r
    if set(members)!=set(ORDER):
        raise SystemExit(f"C4S member mismatch missing={sorted(set(ORDER)-set(members))} extra={sorted(set(members)-set(ORDER))}")

    tech={m:r["technical_failure_histories"] for m,r in members.items() if r["technical_failure_histories"]}
    all_identity=all(r["all_status_or_trace_identity"] for r in members.values())
    maxmass=max([r["maximum_qualified_mass_residual_cm"] for r in members.values()] or [0.0])
    hard=(
      ctrl["pass"] is True
      and ctrl["R2_exact_C4R_reproduction"] is True
      and ctrl["R16_exact_C4R_reproduction"] is True
      and not tech
      and all_identity
      and maxmass<=1e-12
    )
    any_members=[m for m in ORDER if members[m]["qualified_history_count"]>0]
    full_members=[m for m in ORDER if members[m]["qualified_history_count"]==4]
    min_any=None if not any_members else min(any_members,key=lambda m:members[m]["dimension"])
    min_full=None if not full_members else min(full_members,key=lambda m:members[m]["dimension"])

    if not hard:
        decision="C4S_COMPARATOR_AUTHORITY_BLOCKED"
    elif full_members:
        decision="C4S_CORICHARDS_FULL_COMMON_COHORT_AVAILABLE"
    elif any_members:
        decision="C4S_CORICHARDS_PARTIAL_COMMON_COHORT_ONLY"
    else:
        decision="C4S_CORICHARDS_REDUCED_COMPARATOR_UNAVAILABLE"

    curve=[]
    for m in ORDER:
        r=members[m]
        curve.append({
          "member":m,"dimension":r["dimension"],
          "qualified_history_count":r["qualified_history_count"],
          "qualified_histories":r["qualified_histories"],
          "fail_closed_histories":r["fail_closed_histories"],
          "maximum_qualified_mass_residual_cm":r["maximum_qualified_mass_residual_cm"]
        })
    result={
      "schema":"swap5.lare.bc2.c4s.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4S",
      "decision":decision,
      "controls":ctrl,
      "integrity":{
        "pass":hard,
        "technical_failures":tech,
        "all_status_or_trace_identity":all_identity,
        "maximum_qualified_mass_residual_cm":maxmass
      },
      "availability_curve":curve,
      "minimum_member_with_any_qualified_history":min_any,
      "minimum_dimension_with_any_qualified_history":None if min_any is None else members[min_any]["dimension"],
      "minimum_member_with_all_four_qualified_histories":min_full,
      "minimum_dimension_with_all_four_qualified_histories":None if min_full is None else members[min_full]["dimension"],
      "members":members,
      "interpretation":[
        "C4S tests numerical comparator availability only on the exact blind C4R workload and current-canonical Reference authority.",
        "No hydrological-error or runtime comparison is performed.",
        "A qualified member/history may enter a separately preregistered common-cohort value screen; fail-closed histories may not be extrapolated.",
        "Fixed-flux Q1 and fixed-water-table C4S are distinct numerical-authority workloads."
      ],
      "value_screen_authorized":decision in ("C4S_CORICHARDS_FULL_COMMON_COHORT_AVAILABLE","C4S_CORICHARDS_PARTIAL_COMMON_COHORT_ONLY"),
      "hydrological_comparison_performed":False,
      "performance_measurement_performed":False,
      "application_acceptance_adjudicated":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,"integrity":result["integrity"],
      "curve":curve,"min_any":min_any,"min_full":min_full,
      "value_screen_authorized":result["value_screen_authorized"]
    },sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
