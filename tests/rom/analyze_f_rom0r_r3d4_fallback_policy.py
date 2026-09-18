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

    controls=[]; steps=[]; triggers=[]; passes=[]; fails=[]; directions=[]
    complete_count=None; neutrality_count=None
    for line in text.splitlines():
        if "F_ROM0R_R3D4_CONTROL|" in line:
            controls.append(fields(line.split("F_ROM0R_R3D4_CONTROL|",1)[1]))
        elif "F_ROM0R_R3D4_POLICY_STEP|" in line:
            steps.append(fields(line.split("F_ROM0R_R3D4_POLICY_STEP|",1)[1]))
        elif "F_ROM0R_R3D4_TRIGGER|" in line:
            triggers.append(fields(line.split("F_ROM0R_R3D4_TRIGGER|",1)[1]))
        elif "F_ROM0R_R3D4_POLICY_CASE_PASS|" in line:
            passes.append(fields(line.split("F_ROM0R_R3D4_POLICY_CASE_PASS|",1)[1]))
        elif "F_ROM0R_R3D4_POLICY_FAIL|" in line:
            fails.append(fields(line.split("F_ROM0R_R3D4_POLICY_FAIL|",1)[1]))
        elif "F_ROM0R_R3D4_DIRECTION|" in line:
            directions.append(fields(line.split("F_ROM0R_R3D4_DIRECTION|",1)[1]))
        elif "F_ROM0R_R3D4_CANDIDATE_COMPLETE_COUNT=" in line:
            complete_count=int(line.rsplit("=",1)[1])
        elif "F_ROM0R_R3D4_NEUTRALITY_COMPLETE_COUNT=" in line:
            neutrality_count=int(line.rsplit("=",1)[1])

    expected={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    cm={(x["MATERIAL"],x["CASE"]):x for x in controls}
    pm={(x["MATERIAL"],x["CASE"]):x for x in passes}
    dm={x["MATERIAL"]:x for x in directions}

    baseline_ok=(
      set(cm)==expected
      and int(cm[("B01","BOTTOM_HEAD_RISE")]["PASS_STEPS"])==10
      and int(cm[("B01","BOTTOM_HEAD_RISE")]["FAIL_STEP"])==11
      and int(cm[("B01","BOTTOM_HEAD_FALL")]["PASS_STEPS"])==9
      and int(cm[("B01","BOTTOM_HEAD_FALL")]["FAIL_STEP"])==10
      and int(cm[("B14","BOTTOM_HEAD_RISE")]["PASS_STEPS"])==16
      and int(cm[("B14","BOTTOM_HEAD_RISE")]["FAIL_STEP"])==0
      and int(cm[("B14","BOTTOM_HEAD_FALL")]["PASS_STEPS"])==16
      and int(cm[("B14","BOTTOM_HEAD_FALL")]["FAIL_STEP"])==0
    )

    repeat_identity=text==repeat
    overlap=[x for x in steps if truth(x.get("OVERLAP","F"))]
    overlap_neutral=(len(overlap)==51 and all(truth(x.get("NEUTRAL","F")) for x in overlap))
    candidate_complete=(len(steps)==64 and len(fails)==0 and set(pm)==expected and complete_count==4)
    case_neutral=(neutrality_count==4 and all(truth(x.get("NEUTRALITY","F")) for x in passes))

    fallback_by_case={(m,c):0 for m,c in expected}
    for x in steps:
        if truth(x.get("FALLBACK_USED","F")):
            fallback_by_case[(x["MATERIAL"],x["CASE"])]+=1

    b14_zero=all(fallback_by_case[("B14",c)]==0 for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"))
    b01_positive=all(fallback_by_case[("B01",c)]>0 for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"))

    triggers_ok=(
      len(triggers)==sum(fallback_by_case.values())
      and len(triggers)>0
      and all(
        truth(x.get("ELIGIBLE","F"))
        and int(x["BAL_FLAGS"])==0
        and int(x["HEAD_FLAGS"])==0
        and float(x["RMAX"])<=1e-12
        and abs(float(x["RSUM"]))>1e-12
        and float(x["INTEGRATED_ABS"])<=float(x["REP_BOUND_CM"])
        and x["ROUTE"]=="legacy-reference-retry"
        for x in triggers
      )
    )

    direction_ok=(
      set(dm)=={"B01","B14"}
      and all(truth(dm[m].get("LOWER_ORDER","F")) and truth(dm[m].get("EXCHANGE_ORDER","F")) for m in ("B01","B14"))
    )
    mass=[abs(float(x["MASS"])) for x in steps]
    hard_mass_ok=(len(mass)==64 and max(mass)<=1e-12)

    structural=("F_ROM0R_R3D4_EXECUTION_COMPLETE=PASS" in text and baseline_ok and repeat_identity)
    if not structural or not candidate_complete:
        decision="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_NO_GO"
    elif not overlap_neutral or not case_neutral:
        decision="R3_FALLBACK_OVERLAP_NEUTRALITY_FAILED"
    elif not triggers_ok or not b14_zero or not b01_positive:
        decision="R3_FALLBACK_TRIGGER_CLASSIFICATION_FAILED"
    elif not direction_ok:
        decision="R3_FALLBACK_DIRECTIONAL_REACHABILITY_NOT_ESTABLISHED"
    elif not hard_mass_ok:
        decision="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_NO_GO"
    else:
        decision="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED"

    result={
      "schema":"swap5.f-rom0r.r3d4-result.v1",
      "work_unit":"ROM-0R-R3D4",
      "decision":decision,
      "baseline_provenance_reproduced":baseline_ok,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "candidate_case_pass_count":len(passes),
      "candidate_case_fail_count":len(fails),
      "candidate_step_count":len(steps),
      "overlap_step_count":len(overlap),
      "overlap_bit_neutrality_all":overlap_neutral,
      "case_neutrality_all":case_neutral,
      "fallback_count_by_case":{"%s:%s"%k:v for k,v in fallback_by_case.items()},
      "B14_zero_fallbacks":b14_zero,
      "B01_positive_fallbacks_both_directions":b01_positive,
      "trigger_count":len(triggers),
      "all_triggers_total_only_within_pre_solve_bound":triggers_ok,
      "directional_reachability_both_materials":direction_ok,
      "max_abs_transaction_mass_residual_cm":max(mass) if mass else None,
      "hard_mass_gate_all_steps":hard_mass_ok,
      "directions":dm,
      "trigger_rows":triggers,
      "candidate_failures":fails,
      "original_R3_decision_unchanged":"PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO",
      "original_R3D3_decision_unchanged":"R3_POLICY_OVERLAP_NEUTRALITY_FAILED",
      "production_default_changed":False,
      "production_or_reference_source_mutated":False,
      "production_admission_authorized":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if structural else 2

if __name__=="__main__":
    raise SystemExit(main())
