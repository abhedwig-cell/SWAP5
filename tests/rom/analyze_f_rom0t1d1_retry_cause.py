#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def as_bool(v): return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    classes={}
    bounds={}
    for line in text.splitlines():
        if "F_ROM0T1D1_CLASS|" in line:
            r=fields(line.split("F_ROM0T1D1_CLASS|",1)[1]); classes[r["CASE"]]=r
        elif "F_ROM0T1D1_BOUND|" in line:
            r=fields(line.split("F_ROM0T1D1_BOUND|",1)[1]); bounds[r["CASE"]]=r
    expected={"B01_E1_NOMINAL_FLUX","B01_E2_DRYING_FLUX","B14_E2_DRYING_FLUX"}
    repeat_identity=text==repeat
    complete=(set(classes)==expected and set(bounds)==expected)
    rows=[]
    positive=[]
    for case in sorted(expected):
        if case not in classes or case not in bounds: continue
        c=classes[case]; b=bounds[case]
        row={
          "case":case,
          "classification":c["CLASS"],
          "local_balance_flag_count":int(c["BAL_FLAGS"]),
          "head_flag_count":int(c["HEAD_FLAGS"]),
          "max_abs_local_residual_cm_per_day":float(c["RMAX"]),
          "total_residual_cm_per_day":float(c["RSUM"]),
          "representation_bound_cm":float(b["REP_BOUND_CM"]),
          "representation_rate_bound_cm_per_day":float(b["REP_RATE_BOUND"]),
          "abs_total_residual_integrated_cm":float(b["ABS_TOTAL_RESIDUAL_CM"]),
          "residual_over_representation_bound":float(b["RESIDUAL_OVER_BOUND"]),
          "within_representation_bound":as_bool(b["WITHIN_BOUND"]),
        }
        rows.append(row)
        positive.append(
          row["classification"]=="RETRY_TOTAL_ONLY"
          and row["local_balance_flag_count"]==0
          and row["head_flag_count"]==0
          and row["within_representation_bound"]
        )
    if not complete:
        decision="T1_RETRY_DIAGNOSTIC_BLOCKED"
    elif all(positive):
        decision="T1_ALL_RETRIES_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
    elif any(positive):
        decision="T1_RETRY_CAUSE_NONUNIFORM"
    else:
        decision="T1_TOTAL_ONLY_EXCEEDS_PRIOR_REPRESENTATION_BOUND"
    result={
      "schema":"swap5.f-rom0t1d1-result.v1",
      "work_unit":"ROM-0T1D1",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "rows":rows,
      "formula":"0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i)",
      "formula_inputs_are_pre_solve_only":True,
      "observed_failed_residual_used_in_bound_formula":False,
      "empirical_safety_factor_used":False,
      "solver_tolerance_changed":False,
      "production_or_reference_source_mutated":False,
      "remedy_authorized":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    if decision=="T1_RETRY_DIAGNOSTIC_BLOCKED" or not repeat_identity:
        return 2
    return 0

if __name__=="__main__":
    raise SystemExit(main())
