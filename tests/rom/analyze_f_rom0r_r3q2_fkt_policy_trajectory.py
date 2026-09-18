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
        if "F_ROM0R_R3Q2_STEP|" in line:
            steps.append(fields(line.split("F_ROM0R_R3Q2_STEP|",1)[1]))
        elif "F_ROM0R_R3Q2_CASE_PASS|" in line:
            cases.append(fields(line.split("F_ROM0R_R3Q2_CASE_PASS|",1)[1]))

    expected={(m,c) for m in ("B01","B14") for c in ("BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")}
    case_keys={(r.get("MATERIAL"),r.get("CASE")) for r in cases}
    complete=(len(steps)==64 and len(cases)==4 and case_keys==expected and
              "F_ROM0R_R3Q2_MATRIX_COMPLETE=PASS" in text)
    repeat_identity=text==repeat
    step_identity=all(as_bool(s.get("IDENTITY","F")) for s in steps)
    mass_ok=all(math.isfinite(float(s["MASS_CM"])) and abs(float(s["MASS_CM"]))<=1e-12 for s in steps)
    direct_mass_ok=all(math.isfinite(float(s["DIRECT_MASS_CM"])) and abs(float(s["DIRECT_MASS_CM"]))<=1e-12 for s in steps)
    revisions_ok=True
    by_case={}
    for s in steps:
        key=(s["MATERIAL"],s["CASE"])
        by_case.setdefault(key,[]).append(s)
    for key,rows in by_case.items():
        rows=sorted(rows,key=lambda x:int(x["STEP"]))
        revisions=[int(r["REV"]) for r in rows]
        times=[float(r["T"]) for r in rows]
        revisions_ok &= revisions==list(range(3,19))
        revisions_ok &= all(abs(t-(0.0032+(i+1)*0.0008))<1e-15 for i,t in enumerate(times))

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

    qualified=complete and repeat_identity and step_identity and mass_ok and direct_mass_ok and revisions_ok and directional_ok
    decision="FKT_PRESCRIBED_HEAD_REPRESENTATION_TRAJECTORY_QUALIFIED" if qualified else "FKT_PRESCRIBED_HEAD_REPRESENTATION_TRAJECTORY_NOT_QUALIFIED"
    result={
      "schema":"swap5.f-rom0r.r3q2-result.v1",
      "work_unit":"ROM-0R-R3Q2",
      "decision":decision,
      "matrix":{
        "step_count":len(steps),
        "case_pass_count":len(cases),
      },
      "gates":{
        "complete_matrix":complete,
        "repeat_stdout_bitwise_identity":repeat_identity,
        "all_direct_vs_fkt_candidate_identity":step_identity,
        "all_canonical_step_mass_residuals_within_1e_12_cm":mass_ok,
        "all_direct_integrated_mass_residuals_within_1e_12_cm":direct_mass_ok,
        "revision_and_time_progression_exact":revisions_ok,
        "both_materials_directional_reachability":directional_ok,
      },
      "directional_reachability":directional,
      "case_summaries":[{
        "material":r["MATERIAL"],
        "case":r["CASE"],
        "final_storage_cm":float(r["FINAL_STORAGE"]),
        "upper_storage_cm":float(r["UPPER_STORAGE"]),
        "lower_storage_cm":float(r["LOWER_STORAGE"]),
        "cumulative_bottom_outward_exchange_cm":float(r["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
        "max_abs_canonical_mass_residual_cm":float(r["MAX_ABS_MASS"]),
        "final_revision":int(r["FINAL_REV"]),
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
