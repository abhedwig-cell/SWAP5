#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

def kv(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    text=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    passes=[]
    fails=[]
    steps=[]
    attempted=None
    for line in text.splitlines():
        if "F_ROM0R_R3_CASE_PASS|" in line:
            passes.append(kv(line.split("F_ROM0R_R3_CASE_PASS|",1)[1]))
        elif "F_ROM0R_R3_CASE_FAIL|" in line:
            fails.append(kv(line.split("F_ROM0R_R3_CASE_FAIL|",1)[1]))
        elif "F_ROM0R_R3_STEP|" in line:
            steps.append(kv(line.split("F_ROM0R_R3_STEP|",1)[1]))
        elif "F_ROM0R_R3_CASES_ATTEMPTED=" in line:
            attempted=int(line.rsplit("=",1)[1])

    repeat_identity=text==repeat
    structural_complete=attempted==4 and "F_ROM0R_R3_EXECUTION_COMPLETE=PASS" in text
    expected={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    observed={(p.get("MATERIAL"),p.get("CASE")) for p in passes}
    unique_passes=len(observed)==len(passes)

    metrics={}
    for p in passes:
        key=(p["MATERIAL"],p["CASE"])
        metrics[key]={
            "final_storage_cm":float(p["FINAL_STORAGE"]),
            "upper_storage_0_40_cm":float(p["UPPER_STORAGE"]),
            "lower_storage_40_160_cm":float(p["LOWER_STORAGE"]),
            "cumulative_bottom_outward_exchange_cm":float(p["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
            "terminal_bottom_flux_cm_day":float(p["TERMINAL_BOTTOM_FLUX"]),
            "final_bottom_node_head_cm":float(p["FINAL_BOTTOM_NODE_HEAD"]),
            "max_abs_mass_residual_cm":float(p["MAX_ABS_MASS"]),
            "final_revision":int(p["FINAL_REV"]),
            "final_time_day":float(p["FINAL_T"]),
        }

    directional={}
    all_directional=True
    if observed==expected and unique_passes:
        for material in ("B01","B14"):
            rise=metrics[(material,"BOTTOM_HEAD_RISE")]
            fall=metrics[(material,"BOTTOM_HEAD_FALL")]
            lower_storage_separated=rise["lower_storage_40_160_cm"] > fall["lower_storage_40_160_cm"]
            bottom_exchange_toward_inflow=(
                rise["cumulative_bottom_outward_exchange_cm"] <
                fall["cumulative_bottom_outward_exchange_cm"]
            )
            bottom_head_ordered=rise["final_bottom_node_head_cm"] > fall["final_bottom_node_head_cm"]
            directional[material]={
                "lower_storage_rise_gt_fall":lower_storage_separated,
                "bottom_outward_exchange_rise_lt_fall":bottom_exchange_toward_inflow,
                "final_bottom_node_head_rise_gt_fall":bottom_head_ordered,
                "lower_storage_difference_cm":(
                    rise["lower_storage_40_160_cm"]-fall["lower_storage_40_160_cm"]
                ),
                "bottom_outward_exchange_difference_cm":(
                    rise["cumulative_bottom_outward_exchange_cm"]-
                    fall["cumulative_bottom_outward_exchange_cm"]
                ),
                "bottom_node_head_difference_cm":(
                    rise["final_bottom_node_head_cm"]-fall["final_bottom_node_head_cm"]
                ),
            }
            all_directional &= lower_storage_separated and bottom_exchange_toward_inflow
    else:
        all_directional=False

    if not structural_complete or not repeat_identity:
        decision="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
    elif fails:
        decision="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
    elif observed!=expected or not unique_passes:
        decision="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
    elif all_directional:
        decision="PRESSURE_BOUNDARY_REACHABILITY_QUALIFIED"
    else:
        decision="BIDIRECTIONAL_REACHABILITY_NOT_ESTABLISHED"

    result={
        "schema":"swap5.f-rom0r.r3-result.v1",
        "work_unit":"ROM-0R-R3",
        "decision":decision,
        "matrix_cases_attempted":attempted,
        "case_pass_count":len(passes),
        "case_fail_count":len(fails),
        "step_record_count":len(steps),
        "expected_step_record_count_if_all_pass":64,
        "structural_execution_complete":structural_complete,
        "repeat_stdout_bitwise_identity":repeat_identity,
        "all_four_expected_cases_pass":observed==expected and unique_passes and len(fails)==0,
        "hard_mass_gate_cm":1e-12,
        "metrics":{f"{m}:{c}":v for (m,c),v in metrics.items()},
        "directional_separation":directional,
        "failed_cases":fails,
        "post_result_retuning_allowed":False,
        "production_application_admission":False,
        "rom1a_authorized":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
