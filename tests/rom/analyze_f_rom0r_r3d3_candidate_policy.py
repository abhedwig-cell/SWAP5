#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def truth(v):
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()

    controls=[];steps=[];passes=[];fails=[];directions=[]
    complete_count=None;neutrality_count=None
    for line in text.splitlines():
        if "F_ROM0R_R3D3_CONTROL|" in line:
            controls.append(fields(line.split("F_ROM0R_R3D3_CONTROL|",1)[1]))
        elif "F_ROM0R_R3D3_POLICY_STEP|" in line:
            steps.append(fields(line.split("F_ROM0R_R3D3_POLICY_STEP|",1)[1]))
        elif "F_ROM0R_R3D3_POLICY_CASE_PASS|" in line:
            passes.append(fields(line.split("F_ROM0R_R3D3_POLICY_CASE_PASS|",1)[1]))
        elif "F_ROM0R_R3D3_POLICY_FAIL|" in line:
            fails.append(fields(line.split("F_ROM0R_R3D3_POLICY_FAIL|",1)[1]))
        elif "F_ROM0R_R3D3_DIRECTION|" in line:
            directions.append(fields(line.split("F_ROM0R_R3D3_DIRECTION|",1)[1]))
        elif "F_ROM0R_R3D3_CANDIDATE_COMPLETE_COUNT=" in line:
            complete_count=int(line.rsplit("=",1)[1])
        elif "F_ROM0R_R3D3_NEUTRALITY_COMPLETE_COUNT=" in line:
            neutrality_count=int(line.rsplit("=",1)[1])

    expected={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    control_map={(x["MATERIAL"],x["CASE"]):x for x in controls}
    pass_map={(x["MATERIAL"],x["CASE"]):x for x in passes}
    direction_map={x["MATERIAL"]:x for x in directions}
    repeat_identity=text==repeat

    baseline_ok=(
      set(control_map)==expected
      and int(control_map[("B01","BOTTOM_HEAD_RISE")]["PASS_STEPS"])==10
      and int(control_map[("B01","BOTTOM_HEAD_RISE")]["FAIL_STEP"])==11
      and int(control_map[("B01","BOTTOM_HEAD_FALL")]["PASS_STEPS"])==9
      and int(control_map[("B01","BOTTOM_HEAD_FALL")]["FAIL_STEP"])==10
      and int(control_map[("B14","BOTTOM_HEAD_RISE")]["PASS_STEPS"])==16
      and int(control_map[("B14","BOTTOM_HEAD_RISE")]["FAIL_STEP"])==0
      and int(control_map[("B14","BOTTOM_HEAD_FALL")]["PASS_STEPS"])==16
      and int(control_map[("B14","BOTTOM_HEAD_FALL")]["FAIL_STEP"])==0
    )

    overlap_rows=[x for x in steps if truth(x.get("OVERLAP","F"))]
    neutrality_ok=(len(overlap_rows)==51 and all(truth(x.get("NEUTRAL","F")) for x in overlap_rows))
    all_candidate_steps=(len(steps)==64)
    candidate_ok=(len(fails)==0 and set(pass_map)==expected and complete_count==4 and all_candidate_steps)
    case_neutrality=(neutrality_count==4 and all(truth(x.get("NEUTRALITY","F")) for x in passes))

    direction_ok=False
    if set(direction_map)=={"B01","B14"}:
        direction_ok=all(
          truth(direction_map[m].get("LOWER_ORDER","F"))
          and truth(direction_map[m].get("EXCHANGE_ORDER","F"))
          for m in ("B01","B14")
        )

    bounds=[float(x["REP_BOUND_CM"]) for x in steps]
    tols=[float(x["TOTAL_TOL"]) for x in steps]
    mass=[abs(float(x["MASS"])) for x in steps]

    structural=(
      "F_ROM0R_R3D3_EXECUTION_COMPLETE=PASS" in text
      and baseline_ok and repeat_identity and len(controls)==4
    )

    if not structural:
        decision="R3_REPRESENTATION_BOUNDED_TOTAL_POLICY_NO_GO"
    elif not candidate_ok:
        decision="R3_REPRESENTATION_BOUNDED_TOTAL_POLICY_NO_GO"
    elif not neutrality_ok or not case_neutrality:
        decision="R3_POLICY_OVERLAP_NEUTRALITY_FAILED"
    elif not direction_ok:
        decision="R3_POLICY_DIRECTIONAL_REACHABILITY_NOT_ESTABLISHED"
    else:
        decision="R3_REPRESENTATION_BOUNDED_TOTAL_POLICY_QUALIFIED"

    result={
      "schema":"swap5.f-rom0r.r3d3-result.v1",
      "work_unit":"ROM-0R-R3D3",
      "decision":decision,
      "baseline_provenance_reproduced":baseline_ok,
      "control_case_count":len(controls),
      "candidate_case_pass_count":len(passes),
      "candidate_case_fail_count":len(fails),
      "candidate_step_count":len(steps),
      "expected_candidate_step_count":64,
      "overlap_step_count":len(overlap_rows),
      "expected_overlap_step_count":51,
      "overlap_bit_neutrality_all":neutrality_ok,
      "case_neutrality_all":case_neutrality,
      "directional_reachability_both_materials":direction_ok,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "representation_bound_cm_range":[min(bounds) if bounds else None,max(bounds) if bounds else None],
      "candidate_total_balance_rate_tolerance_range":[min(tols) if tols else None,max(tols) if tols else None],
      "max_abs_transaction_mass_residual_cm":max(mass) if mass else None,
      "directions":direction_map,
      "candidate_failures":fails,
      "formula":"max(1e-12 cm/day, 0.5*sum((spacing(theta_s)+spacing(theta_base_i))*dz_i)/dt)",
      "original_R3_decision_unchanged":"PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO",
      "production_default_changed":False,
      "production_or_reference_source_mutated":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if structural else 2

if __name__=="__main__":
    raise SystemExit(main())
