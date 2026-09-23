#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")
MEMBERS=("U4","U8","R8","R16")
REQUIRED_CHECKS=(
    "fractions_nonnegative",
    "fraction_sum_within_arithmetic_guard",
    "sink_rate_within_arithmetic_guard",
    "route_sum_within_layer_summation_bound",
    "cumulative_root_within_operation_count_bound",
    "root_generic_bit_identity",
    "zero_sink_legacy_bit_identity",
    "root_ledger_pass",
    "generic_ledger_pass",
    "zero_root_ledger_pass",
    "legacy_ledger_pass",
)


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_S2R_EXECUTION"

    cases={}
    failures=[]
    max_ledger=0.0
    max_cumulative_ratio=0.0
    max_route_sum_ratio=0.0
    for material in MATERIALS:
        for history in HISTORIES:
            raw=json.loads((a.input_dir/f"{material}_{history}.json").read_text())
            assert raw["material"]==material
            assert raw["history"]==history
            assert raw["work_unit"]=="ROM-ROOT-S2R"
            f=raw["scientific_firewall"]
            assert f["feddes_evaluated"] is False
            assert f["dynamic_root_feedback_implemented"] is False
            assert f["reduced_feedback_response_generated"] is False
            for member in MEMBERS:
                row=raw["cases"][member]
                key=f"{material}_{history}_{member}"
                cases[key]=row
                for check in REQUIRED_CHECKS:
                    if not bool(row["checks"].get(check,False)):
                        failures.append({"case":key,"check":check})
                for route in row["routes"].values():
                    max_ledger=max(max_ledger,float(route["max_abs_water_ledger_cm"]))
                cb=float(row["cumulative_roundoff_bound_cm"])
                cd=abs(float(row["cumulative_difference_cm"]))
                max_cumulative_ratio=max(max_cumulative_ratio,0.0 if cb==0.0 and cd==0.0 else cd/cb)
                rb=float(row["layer_summation_bound_cm_per_day"])
                rd=abs(float(row["prescribed_total_rate_route_sum_cm_per_day"])-float(row["prescribed_total_rate_fsum_cm_per_day"]))
                max_route_sum_ratio=max(max_route_sum_ratio,0.0 if rb==0.0 and rd==0.0 else rd/rb)

    expected=len(MATERIALS)*len(HISTORIES)*len(MEMBERS)
    all_pass=(len(cases)==expected and not failures and
              max_ledger<=float(pre["frozen_execution"]["ledger_gate_cm"]))
    status="S2R_PRESCRIBED_SINK_HARNESS_EQUIVALENCE_QUALIFIED" if all_pass else "S2R_PRESCRIBED_SINK_HARNESS_EQUIVALENCE_NOT_QUALIFIED"
    decision="STAGE3_DYNAMIC_FEEDBACK_MAY_BE_PREREGISTERED" if all_pass else "STOP_BEFORE_DYNAMIC_FEEDBACK"

    out={
        "schema":"swap5.rom_root.s2r.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S2R",
        "status":status,
        "decision":decision,
        "case_count":len(cases),
        "all_32_cases_pass":all_pass,
        "check_failures":failures,
        "maximum_abs_water_ledger_cm":max_ledger,
        "maximum_cumulative_error_to_preregistered_bound_ratio":max_cumulative_ratio,
        "maximum_route_sum_error_to_preregistered_bound_ratio":max_route_sum_ratio,
        "cases":cases,
        "interpretation":[
            "S2R preserves the failed S2 result and changes only the arithmetic validation of the cumulative root ledger.",
            "All hydraulic, prescribed-sink, root-fraction, representation, dt, identity and water-ledger semantics are inherited unchanged from S2.",
            "A pass establishes reduced-harness prescribed-sink equivalence only and does not evaluate Feddes feedback or hydrological fidelity."
        ],
        "scientific_firewall":{
            "s2_reclassified":False,
            "reference_changed":False,
            "feddes_evaluated":False,
            "dynamic_root_feedback_implemented":False,
            "reduced_feedback_response_generated":False,
            "new_root_specific_state_selected":False,
            "new_partition_selected":False,
            "new_hydraulic_closure_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":status,
        "decision":decision,
        "case_count":len(cases),
        "maximum_abs_water_ledger_cm":max_ledger,
        "maximum_cumulative_error_to_bound_ratio":max_cumulative_ratio,
        "maximum_route_sum_error_to_bound_ratio":max_route_sum_ratio,
        "failure_count":len(failures)
    },sort_keys=True))
    return 0 if all_pass else 1


if __name__=="__main__":
    raise SystemExit(main())
