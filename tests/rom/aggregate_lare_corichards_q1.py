#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

ORDER=("R4","R5","R6","R8","R12","R16")
REDUCED=("R4","R5","R6","R8","R12")
EXPECTED_R16_QUALIFIED={"S1_B1_F1","S1_B1_F2","S1_B1_F3","S1_B1_F4","S2_B1_F1","S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F1","S3_B1_F3"}
EXPECTED_R16_OOD={"S3_B1_F2","S3_B1_F4"}
EXPECTED_INDOMAIN_DYNAMIC={"S1_B1_F2","S1_B1_F3","S1_B1_F4","S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--member-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4O_BEFORE_HIGHER_DIMENSION_CORICHARDS_VIABILITY_CURVE"

    members={}
    for p in sorted(args.member_dir.rglob("LARE_CORICHARDS_Q1_*_RESULT.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.corichards.q1.member-result.v1": continue
        m=r["member"]
        if m in members: raise SystemExit(f"duplicate member {m}")
        members[m]=r
    if set(members)!=set(ORDER):
        raise SystemExit(f"member set mismatch missing={sorted(set(ORDER)-set(members))} extra={sorted(set(members)-set(ORDER))}")

    r16=members["R16"]
    reproduction=True
    sub1={}
    for case,row in r16["cases"].items():
        status=row["routes"]["1"]["status"]
        sub1[case]=status
        expected="QUALIFIED" if case in EXPECTED_R16_QUALIFIED else "OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION"
        if status!=expected: reproduction=False
    if set(sub1)!=EXPECTED_R16_QUALIFIED|EXPECTED_R16_OOD: reproduction=False

    technical={m:r["technical_failure_cases"] for m,r in members.items() if r["technical_failure_cases"]}
    all_identity=all(r["all_O0_O2_identity"] for r in members.values())
    max_mass=max(float(r["maximum_mass_residual_cm"]) for r in members.values())

    reduced_with_dynamic=[m for m in REDUCED if members[m]["dynamic_qualified_count"]>0]
    min_reduced=None if not reduced_with_dynamic else min(reduced_with_dynamic,key=lambda m:members[m]["dimension"])
    all_indomain=[m for m in REDUCED if EXPECTED_INDOMAIN_DYNAMIC.issubset(set(members[m]["dynamic_qualified_cases"]))]
    min_all=None if not all_indomain else min(all_indomain,key=lambda m:members[m]["dimension"])

    if (not reproduction) or technical or (not all_identity) or r16["dynamic_qualified_count"]==0:
        decision="CORICHARDS_Q1_COMPARATOR_AUTHORITY_BLOCKED"
    elif reduced_with_dynamic:
        decision="REDUCED_CORICHARDS_DYNAMIC_VIABILITY_ESTABLISHED"
    else:
        decision="ONLY_FINE_CORICHARDS_DYNAMIC_VIABLE"

    curve=[]
    for m in ORDER:
        r=members[m]
        curve.append({
            "member":m,
            "dimension":r["dimension"],
            "dynamic_qualified_count":r["dynamic_qualified_count"],
            "dynamic_qualified_cases":r["dynamic_qualified_cases"],
            "equilibrium_qualified_count":r["equilibrium_qualified_count"],
            "outside_domain_cases":r["outside_domain_cases"],
            "numerically_blocked_dynamic_cases":r["numerically_blocked_dynamic_cases"],
            "maximum_mass_residual_cm":r["maximum_mass_residual_cm"],
        })

    result={
        "schema":"swap5.lare.corichards.q1.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-CORICHARDS-Q1",
        "decision":decision,"complete":True,
        "frozen_scientific_base":pre["governing_authority"]["frozen_scientific_base"],
        "R3_imported_anchor":pre["imported_anchor"]["R3"],
        "R16_authority_reproduction":{
            "pass":reproduction,
            "substeps1_status":sub1,
            "expected_qualified":sorted(EXPECTED_R16_QUALIFIED),
            "expected_outside_domain":sorted(EXPECTED_R16_OOD),
        },
        "integrity":{
            "technical_failures":technical,
            "all_O0_O2_identity":all_identity,
            "maximum_mass_residual_cm":max_mass,
        },
        "viability_curve":curve,
        "minimum_reduced_dimension_with_any_dynamic_qualification":None if min_reduced is None else members[min_reduced]["dimension"],
        "minimum_reduced_member_with_any_dynamic_qualification":min_reduced,
        "minimum_reduced_dimension_with_all_expected_in_domain_dynamic_cases":None if min_all is None else members[min_all]["dimension"],
        "minimum_reduced_member_with_all_expected_in_domain_dynamic_cases":min_all,
        "members":members,
        "scientific_interpretation":[
            "Q1 maps numerical comparator viability only. It does not compare LARE and CoRichards hydrological fidelity.",
            "R3 is imported as the previously blocked equal-dimension anchor; R4-R16 are the frozen nested LARE resolution ladder run through conventional Reference-Richards discretisation.",
            "A reduced member is scientifically usable for later paired fidelity only on histories that are also qualified for LARE and the fine Reference.",
            "Numerical robustness of one representation is not hydrological superiority over another."
        ],
        "Q2_authorized":decision=="REDUCED_CORICHARDS_DYNAMIC_VIABILITY_ESTABLISHED",
        "Q2_scope":"PAIRED_LARE_VS_CORICHARDS_FIDELITY_ON_COMMON_QUALIFIED_COHORT" if decision=="REDUCED_CORICHARDS_DYNAMIC_VIABILITY_ESTABLISHED" else None,
        "hydrological_comparison_performed":False,
        "performance_comparison_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "R16_reproduction":reproduction,
        "curve":curve,
        "minimum_reduced_member_with_any_dynamic_qualification":min_reduced,
        "minimum_reduced_member_with_all_expected_in_domain_dynamic_cases":min_all,
        "Q2_authorized":result["Q2_authorized"],
        "integrity":result["integrity"]
    },sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
