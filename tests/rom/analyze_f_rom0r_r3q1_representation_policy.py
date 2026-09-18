#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,math

def fields(s:str)->dict[str,str]:
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def as_bool(v:str)->bool:
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    steps=[]
    cases=[]
    for line in text.splitlines():
        if "F_ROM0R_R3Q1_STEP|" in line:
            steps.append(fields(line.split("F_ROM0R_R3Q1_STEP|",1)[1]))
        elif "F_ROM0R_R3Q1_CASE_PASS|" in line:
            cases.append(fields(line.split("F_ROM0R_R3Q1_CASE_PASS|",1)[1]))

    expected={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    case_keys={(r.get("MATERIAL"),r.get("CASE")) for r in cases}
    repeat_identity=text==repeat
    controls_ok=all(s.get("CONTROL") in {"CONTROL_CONVERGED","CONTROL_TOTAL_ONLY"} for s in steps)
    neutrality_ok=all(as_bool(s.get("NEUTRAL","F")) for s in steps)
    mass_ok=all(math.isfinite(float(s["MASS_CM"])) and abs(float(s["MASS_CM"]))<=1e-12 for s in steps)
    bounds_ok=all(math.isfinite(float(s["REP_BOUND_CM"])) and float(s["REP_BOUND_CM"])>0 for s in steps)
    total_retry_count=sum(s.get("CONTROL")=="CONTROL_TOTAL_ONLY" for s in steps)
    control_converged_count=sum(s.get("CONTROL")=="CONTROL_CONVERGED" for s in steps)

    by={(r["MATERIAL"],r["CASE"]):r for r in cases}
    directional={}
    directional_ok=True
    if case_keys==expected and len(cases)==4:
        for material in ("B01","B14"):
            rise=by[(material,"BOTTOM_HEAD_RISE")]
            fall=by[(material,"BOTTOM_HEAD_FALL")]
            rise_lower=float(rise["LOWER_STORAGE"]);fall_lower=float(fall["LOWER_STORAGE"])
            rise_bottom=float(rise["CUM_BOTTOM_OUTWARD_EXCHANGE"]);fall_bottom=float(fall["CUM_BOTTOM_OUTWARD_EXCHANGE"])
            storage_ok=rise_lower>fall_lower
            bottom_ok=rise_bottom<fall_bottom
            directional[material]={
                "rise_lower_storage_cm":rise_lower,
                "fall_lower_storage_cm":fall_lower,
                "rise_minus_fall_lower_storage_cm":rise_lower-fall_lower,
                "rise_cumulative_bottom_outward_exchange_cm":rise_bottom,
                "fall_cumulative_bottom_outward_exchange_cm":fall_bottom,
                "rise_minus_fall_bottom_outward_exchange_cm":rise_bottom-fall_bottom,
                "storage_direction_pass":storage_ok,
                "bottom_exchange_direction_pass":bottom_ok,
            }
            directional_ok=directional_ok and storage_ok and bottom_ok
    else:
        directional_ok=False

    complete=(len(steps)==64 and len(cases)==4 and case_keys==expected and
              "F_ROM0R_R3Q1_MATRIX_COMPLETE=PASS" in text)
    qualified=(complete and repeat_identity and controls_ok and neutrality_ok and mass_ok and bounds_ok and directional_ok)
    decision="PRESCRIBED_HEAD_REPRESENTATION_POLICY_QUALIFIED" if qualified else "PRESCRIBED_HEAD_REPRESENTATION_POLICY_NOT_QUALIFIED"
    result={
      "schema":"swap5.f-rom0r.r3q1-result.v1",
      "work_unit":"ROM-0R-R3Q1",
      "decision":decision,
      "matrix":{
        "step_count":len(steps),
        "expected_step_count":64,
        "case_pass_count":len(cases),
        "expected_case_count":4,
        "control_converged_step_count":control_converged_count,
        "control_total_only_retry_step_count":total_retry_count,
      },
      "gates":{
        "complete_matrix":complete,
        "repeat_stdout_bitwise_identity":repeat_identity,
        "only_control_converged_or_total_only":controls_ok,
        "all_paired_endpoint_neutrality_gates_pass":neutrality_ok,
        "all_candidate_integrated_mass_residuals_within_1e_12_cm":mass_ok,
        "all_pre_solve_representation_bounds_positive_finite":bounds_ok,
        "both_materials_directional_reachability":directional_ok,
      },
      "directional_reachability":directional,
      "case_summaries":[{
        "material":r["MATERIAL"],"case":r["CASE"],
        "final_storage_cm":float(r["FINAL_STORAGE"]),
        "upper_storage_cm":float(r["UPPER_STORAGE"]),
        "lower_storage_cm":float(r["LOWER_STORAGE"]),
        "cumulative_bottom_outward_exchange_cm":float(r["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
        "max_abs_integrated_mass_residual_cm":float(r["MAX_ABS_MASS"]),
        "control_converged_steps":int(r["CONTROL_CONVERGED"]),
        "control_total_only_retry_steps":int(r["CONTROL_TOTAL_RETRY"]),
        "final_time_day":float(r["FINAL_T"]),
      } for r in cases],
      "original_r3_decision_changed":False,
      "production_or_reference_source_mutated":False,
      "production_application_admission":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if qualified else 2

if __name__=="__main__":
    raise SystemExit(main())
