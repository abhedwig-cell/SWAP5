#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def kv(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def truth(v):
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def parse(text):
    d={"neutral":[],"neutral_fail":[],"original_fail":[],"original_summary":[],
       "candidate_fail":[],"candidate_step":[],"case_pass":[]}
    for line in text.splitlines():
        for marker,key in [
            ("F_ROM0R_R3R1_NEUTRAL|","neutral"),
            ("F_ROM0R_R3R1_NEUTRAL_FAIL|","neutral_fail"),
            ("F_ROM0R_R3R1_ORIGINAL_FAIL|","original_fail"),
            ("F_ROM0R_R3R1_ORIGINAL_SUMMARY|","original_summary"),
            ("F_ROM0R_R3R1_CANDIDATE_FAIL|","candidate_fail"),
            ("F_ROM0R_R3R1_CAND_STEP|","candidate_step"),
            ("F_ROM0R_R3R1_CASE_PASS|","case_pass"),
        ]:
            if marker in line:
                d[key].append(kv(line.split(marker,1)[1]))
                break
    return d

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    t0=pathlib.Path(a.o0).read_text()
    t2=pathlib.Path(a.o2).read_text()
    tr=pathlib.Path(a.repeat).read_text()
    p=parse(t2)

    o0_o2_identity=t0==t2
    repeat_identity=t2==tr
    execution_complete="F_ROM0R_R3R1_EXECUTION_COMPLETE=PASS" in t2

    expected_fail={("B01","BOTTOM_HEAD_RISE"):11,("B01","BOTTOM_HEAD_FALL"):10}
    fail_seen={(r.get("MATERIAL"),r.get("CASE")):r for r in p["original_fail"]}
    summaries={(r.get("MATERIAL"),r.get("CASE")):r for r in p["original_summary"]}
    original_reproduced=True
    for key,step in expected_fail.items():
        r=fail_seen.get(key)
        s=summaries.get(key)
        original_reproduced &= bool(r and s)
        if r:
            original_reproduced &= int(r.get("STEP","-1"))==step
            original_reproduced &= int(r.get("EXPECTED_STEP","-1"))==step
            original_reproduced &= int(r.get("STATUS","-1"))==2
            original_reproduced &= r.get("ROUTE")=="legacy-reference-retry"
        if s:
            original_reproduced &= truth(s.get("FAILED","F"))
            original_reproduced &= int(s.get("PREFIX_PASSES","-1"))==step-1
    for case in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"):
        s=summaries.get(("B14",case))
        original_reproduced &= bool(s)
        if s:
            original_reproduced &= not truth(s.get("FAILED","T"))
            original_reproduced &= int(s.get("PREFIX_PASSES","-1"))==16
    original_reproduced &= len(p["original_fail"])==2

    expected_neutral=10+9+16+16
    neutrality_pass=(len(p["neutral"])==expected_neutral and len(p["neutral_fail"])==0)

    expected_cases={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    case_by={(r.get("MATERIAL"),r.get("CASE")):r for r in p["case_pass"]}
    completion_pass=(len(p["candidate_fail"])==0 and len(p["candidate_step"])==64 and set(case_by)==expected_cases)

    directional={}
    directional_pass=completion_pass
    if completion_pass:
        for material in ("B01","B14"):
            rise=case_by[(material,"BOTTOM_HEAD_RISE")]
            fall=case_by[(material,"BOTTOM_HEAD_FALL")]
            rise_lower=float(rise["LOWER_STORAGE"]); fall_lower=float(fall["LOWER_STORAGE"])
            rise_bottom=float(rise["CUM_BOTTOM_OUTWARD_EXCHANGE"]); fall_bottom=float(fall["CUM_BOTTOM_OUTWARD_EXCHANGE"])
            a_ok=rise_lower>fall_lower
            b_ok=rise_bottom<fall_bottom
            directional[material]={
                "rise_lower_storage_cm":rise_lower,
                "fall_lower_storage_cm":fall_lower,
                "rise_minus_fall_lower_storage_cm":rise_lower-fall_lower,
                "rise_cumulative_bottom_outward_exchange_cm":rise_bottom,
                "fall_cumulative_bottom_outward_exchange_cm":fall_bottom,
                "rise_minus_fall_bottom_outward_exchange_cm":rise_bottom-fall_bottom,
                "rise_lower_storage_gt_fall":a_ok,
                "rise_bottom_outward_exchange_lt_fall":b_ok,
            }
            directional_pass &= a_ok and b_ok

    max_mass=0.0
    mass_pass=completion_pass
    if completion_pass:
        for r in case_by.values():
            m=abs(float(r["MAX_ABS_MASS"]))
            max_mass=max(max_mass,m)
            mass_pass &= m<=1e-12

    policy_rows=[]
    policy_pre_solve_pass=True
    for r in p["candidate_step"]:
        tol=float(r["POLICY_TOL"]); bound=float(r["REP_BOUND"])
        policy_rows.append((tol,bound))
        policy_pre_solve_pass &= tol>=1e-12 and bound>0.0

    determinism_pass=o0_o2_identity and repeat_identity
    if not execution_complete or not original_reproduced:
        decision="CANDIDATE_POLICY_TRAJECTORY_COMPLETION_NO_GO"
    elif not completion_pass:
        decision="CANDIDATE_POLICY_TRAJECTORY_COMPLETION_NO_GO"
    elif not neutrality_pass:
        decision="CANDIDATE_POLICY_ENDPOINT_NEUTRALITY_NO_GO"
    elif not directional_pass:
        decision="CANDIDATE_POLICY_DIRECTIONAL_REACHABILITY_NO_GO"
    elif not mass_pass or not policy_pre_solve_pass or not determinism_pass:
        decision="CANDIDATE_POLICY_MASS_OR_DETERMINISM_NO_GO"
    else:
        decision="ROM_REFERENCE_REPRESENTATION_BOUNDED_TOTAL_POLICY_QUALIFIED_FOR_R3_DOMAIN"

    result={
      "schema":"swap5.f-rom0r.r3r1-result.v1",
      "work_unit":"ROM-0R-R3R1",
      "decision":decision,
      "execution_complete":execution_complete,
      "original_control_reproduced":original_reproduced,
      "neutrality":{
        "required_original_accepted_endpoints":expected_neutral,
        "bit_identical_endpoint_count":len(p["neutral"]),
        "bit_identity_failure_count":len(p["neutral_fail"]),
        "pass":neutrality_pass,
      },
      "candidate_completion":{
        "case_pass_count":len(p["case_pass"]),
        "candidate_step_count":len(p["candidate_step"]),
        "candidate_fail_count":len(p["candidate_fail"]),
        "pass":completion_pass,
      },
      "directional_separation":directional,
      "directional_pass":directional_pass,
      "maximum_abs_transaction_mass_residual_cm":max_mass,
      "hard_mass_gate_cm":1e-12,
      "mass_pass":mass_pass,
      "prospective_policy_inputs_valid":policy_pre_solve_pass,
      "policy_rate_tolerance_range_cm_per_day":[
          min((x[0] for x in policy_rows),default=0.0),
          max((x[0] for x in policy_rows),default=0.0)
      ],
      "representation_bound_range_cm":[
          min((x[1] for x in policy_rows),default=0.0),
          max((x[1] for x in policy_rows),default=0.0)
      ],
      "o0_o2_stdout_bitwise_identity":o0_o2_identity,
      "o2_repeat_stdout_bitwise_identity":repeat_identity,
      "production_or_reference_source_mutated":False,
      "original_r3_reclassified":False,
      "production_application_admission":False,
      "vertical_reference_floor_authorized":decision=="ROM_REFERENCE_REPRESENTATION_BOUNDED_TOTAL_POLICY_QUALIFIED_FOR_R3_DOMAIN",
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
