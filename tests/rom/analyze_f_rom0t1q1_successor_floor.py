#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

CASES=[
 "B01_E1_NOMINAL_FLUX","B01_E2_DRYING_FLUX",
 "B14_E1_NOMINAL_FLUX","B14_E2_DRYING_FLUX",
]
EXPECTED_CONTROL={
 "B01_E1_NOMINAL_FLUX":(17,18),
 "B01_E2_DRYING_FLUX":(3,4),
 "B14_E1_NOMINAL_FLUX":(64,0),
 "B14_E2_DRYING_FLUX":(3,4),
}
ALLOW=1.6e-15
DT=0.0008

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def b(v): return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()

    bases=[];controls=[];steps=[];fallbacks=[];compares=[];passes=[]
    complete_count=overlap_count=fallback_count=compare_count=None
    for line in text.splitlines():
        if "F_ROM0T1Q1_BASE_PASS|" in line: bases.append(fields(line.split("F_ROM0T1Q1_BASE_PASS|",1)[1]))
        elif "F_ROM0T1Q1_CONTROL|" in line: controls.append(fields(line.split("F_ROM0T1Q1_CONTROL|",1)[1]))
        elif "F_ROM0T1Q1_STEP|" in line: steps.append(fields(line.split("F_ROM0T1Q1_STEP|",1)[1]))
        elif "F_ROM0T1Q1_FALLBACK|" in line: fallbacks.append(fields(line.split("F_ROM0T1Q1_FALLBACK|",1)[1]))
        elif "F_ROM0T1Q1_COMPARE|" in line: compares.append(fields(line.split("F_ROM0T1Q1_COMPARE|",1)[1]))
        elif "F_ROM0T1Q1_CASE_PASS|" in line: passes.append(fields(line.split("F_ROM0T1Q1_CASE_PASS|",1)[1]))
        elif "F_ROM0T1Q1_POLICY_COMPLETE_COUNT=" in line: complete_count=int(line.rsplit("=",1)[1])
        elif "F_ROM0T1Q1_OVERLAP_NEUTRAL_COUNT=" in line: overlap_count=int(line.rsplit("=",1)[1])
        elif "F_ROM0T1Q1_TOTAL_FALLBACK_COUNT=" in line: fallback_count=int(line.rsplit("=",1)[1])
        elif "F_ROM0T1Q1_TEMPORAL_COMPARE_COUNT=" in line: compare_count=int(line.rsplit("=",1)[1])

    base_map={r["CASE"]:r for r in bases}
    control_map={r["CASE"]:(int(r["PASS_STEPS"]),int(r["FAIL_STEP"])) for r in controls}
    pass_map={r["CASE"]:r for r in passes}

    base_ok=(set(base_map)==set(CASES) and all(int(base_map[c]["STEPS"])==32 and abs(float(base_map[c]["MAX_ABS_MASS"]))<=1e-12 for c in CASES))
    control_ok=(control_map==EXPECTED_CONTROL)
    case_ok=(set(pass_map)==set(CASES) and complete_count==4 and all(int(pass_map[c]["FINAL_REV"])==64 for c in CASES))
    expected_overlap=sum(v[0] for v in EXPECTED_CONTROL.values())
    overlap_rows=[r for r in steps if b(r.get("OVERLAP","F"))]
    overlap_ok=(expected_overlap==87 and overlap_count==87 and len(overlap_rows)==87 and all(b(r.get("NEUTRAL","F")) for r in overlap_rows))

    fb_rows=[];trigger_ok=True
    for r in fallbacks:
        row={
          "case":r["CASE"],"step":int(r["STEP"]),"classification":r["CLASS"],
          "local_balance_flags":int(r["BAL_FLAGS"]),"head_flags":int(r["HEAD_FLAGS"]),
          "max_abs_local_residual_cm_per_day":float(r["RMAX"]),
          "total_residual_cm_per_day":float(r["RSUM"]),
          "local_integrated_cm":float(r["LOCAL_INTEGRATED_CM"]),
          "local_allowance_cm":float(r["LOCAL_ALLOWANCE_CM"]),
          "representation_bound_cm":float(r["REP_BOUND_CM"]),
          "total_bound_cm":float(r["TOTAL_BOUND_CM"]),
          "abs_total_residual_cm":float(r["ABS_TOTAL_RESIDUAL_CM"]),
          "compartment_tolerance_cm_per_day":float(r["COMP_TOL"]),
          "total_tolerance_cm_per_day":float(r["TOTAL_TOL"]),
          "failed_nonlinear_iterations":int(r["FAILED_NL"]),
          "failed_backtracking":int(r["FAILED_BACKTRACK"]),
          "accepted_nonlinear_iterations":int(r["ACCEPT_NL"]),
          "accepted_backtracking":int(r["ACCEPT_BACKTRACK"]),
          "accepted_mass_residual_cm":float(r["MASS"]),
        }
        fb_rows.append(row)
        allowed_class=row["classification"] in {"RETRY_TOTAL_ONLY","RETRY_LOCAL_BALANCE"}
        local_ok=(row["local_balance_flags"]==0 or row["local_integrated_cm"]<=ALLOW)
        expected_total=max(ALLOW,row["representation_bound_cm"])
        row_ok=all([
          allowed_class,row["head_flags"]==0,local_ok,
          row["abs_total_residual_cm"]<=row["total_bound_cm"],
          abs(row["local_allowance_cm"]-ALLOW)<=1e-30,
          abs(row["compartment_tolerance_cm_per_day"]-ALLOW/DT)<=1e-24,
          abs(row["total_bound_cm"]-expected_total)<=1e-28,
          abs(row["total_tolerance_cm_per_day"]-expected_total/DT)<=1e-20,
          row["failed_nonlinear_iterations"]==16,
          abs(row["accepted_mass_residual_cm"])<=1e-12,
        ])
        trigger_ok &= row_ok

    fallback_consistent=(fallback_count==len(fallbacks) and fallback_count is not None)
    fallback_case_counts={c:sum(1 for r in fallbacks if r["CASE"]==c) for c in CASES}
    exercise_ok=(fallback_case_counts["B14_E1_NOMINAL_FLUX"]==0 and
                 all(fallback_case_counts[c]>0 for c in CASES if c!="B14_E1_NOMINAL_FLUX"))

    compare_by_case={c:[] for c in CASES}
    finite=True
    metric_names=[
      "D_H_INF","D_H_RMS","D_THETA_INF","D_THETA_RMS","D_TOTAL_STORAGE",
      "D_UPPER_STORAGE","D_LOWER_STORAGE","D_CUM_TOP","D_CUM_BOTTOM","D_BOTTOM_FLUX"
    ]
    for r in compares:
        if r.get("CASE") not in compare_by_case:
            finite=False;continue
        vals={m:float(r[m]) for m in metric_names}
        finite &= all(math.isfinite(v) and v>=0.0 for v in vals.values())
        compare_by_case[r["CASE"]].append((int(r["BASE_STEP"]),int(r["REFINED_STEP"]),float(r["T"]),vals))
    compare_ok=(compare_count==128 and len(compares)==128 and finite and
                all(len(compare_by_case[c])==32 and [x[0] for x in compare_by_case[c]]==list(range(1,33)) for c in CASES))

    maxima={}
    for c in CASES:
        maxima[c]={}
        for m in metric_names:
            if compare_by_case[c]:
                rr=max(compare_by_case[c],key=lambda x:x[3][m])
                maxima[c][m]={"value":rr[3][m],"base_step":rr[0],"refined_step":rr[1],"time_day":rr[2]}

    masses=[abs(float(r["MASS"])) for r in steps]+[abs(float(r["MASS"])) for r in fallbacks]
    max_mass=max(masses) if masses else None
    mass_ok=max_mass is not None and max_mass<=1e-12
    repeat_identity=text==repeat

    qualified=all([
      base_ok,control_ok,case_ok,overlap_ok,trigger_ok,fallback_consistent,exercise_ok,
      compare_ok,mass_ok,repeat_identity,"F_ROM0T1Q1_EXECUTION_COMPLETE=PASS" in text
    ])
    decision="T1_SUCCESSOR_REFERENCE_POLICY_QUALIFIED_AND_TEMPORAL_FLOOR_MEASURED" if qualified else "T1_SUCCESSOR_REFERENCE_POLICY_NO_GO"
    result={
      "schema":"swap5.f-rom0t1q1-result.v1",
      "work_unit":"ROM-0T1Q1",
      "decision":decision,
      "strict_base_complete":base_ok,
      "strict_refined_provenance_reproduced":control_ok,
      "overlap":{"expected":87,"observed":overlap_count,"all_bit_neutral":overlap_ok},
      "successor":{"case_pass_count":len(pass_map),"all_four_complete":case_ok,"fallback_count":len(fallbacks),
                   "fallback_count_consistent":fallback_consistent,"fallback_exercise_by_case":fallback_case_counts,
                   "all_fallback_triggers_inside_preexisting_bounds":trigger_ok,"fallback_rows":fb_rows},
      "temporal_floor":{"comparison_count":len(compares),"all_128_common_time_rows_finite":compare_ok,"max_over_time":maxima,
                        "threshold_rule":"MEASURE_ONLY_NO_POST_RESULT_NUMERICAL_ACCEPTANCE_THRESHOLD"},
      "max_abs_committed_transaction_mass_residual_cm":max_mass,
      "hard_mass_gate_pass":mass_ok,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "compartment_integrated_allowance_cm":ALLOW,
      "total_integrated_bound_formula":"max(1.6e-15, 0.5 * sum_i((spacing(theta_s_material)+spacing(theta_base_i))*dz_i))",
      "observed_failed_residual_used_to_choose_policy":False,
      "dt_subdivision_used":False,
      "production_or_reference_source_mutated":False,
      "production_policy_admitted":False,
      "original_T1_reclassified":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
