#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def as_bool(v):
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()

    steps=[]
    fallbacks=[]
    cases=[]
    summary={}
    for line in text.splitlines():
        if "ROM1AD2_STEP|" in line:
            steps.append(fields(line.split("ROM1AD2_STEP|",1)[1]))
        elif "ROM1AD2_FALLBACK|" in line:
            fallbacks.append(fields(line.split("ROM1AD2_FALLBACK|",1)[1]))
        elif "ROM1AD2_CASE_PASS|" in line:
            cases.append(fields(line.split("ROM1AD2_CASE_PASS|",1)[1]))
        elif line.startswith("ROM1AD2_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()

    repeat_identity=text==repeat
    expected_cases={"TOP_PLUS","TOP_MINUS"}
    observed_cases={c.get("CASE") for c in cases}
    all_step_mass=all(abs(float(s["MASS"]))<=1e-12 for s in steps)
    fallback_rows=[]
    triggers_ok=True
    for f in fallbacks:
        rsum=float(f["RSUM"])
        bound=float(f["REP_BOUND_CM"])
        integrated=float(f["ABS_TOTAL_RESIDUAL_CM"])
        row={
          "classification":f["CLASS"],
          "local_balance_flag_count":int(f["BAL_FLAGS"]),
          "head_flag_count":int(f["HEAD_FLAGS"]),
          "max_abs_local_residual_cm_per_day":float(f["RMAX"]),
          "total_residual_cm_per_day":rsum,
          "representation_bound_cm":bound,
          "abs_total_residual_integrated_cm":integrated,
          "residual_over_bound":integrated/bound,
          "fallback_total_tolerance_cm_per_day":float(f["FALLBACK_TOTAL_TOL"]),
          "failed_nonlinear_iterations":int(f["FAILED_NL"]),
          "failed_backtracking":int(f["FAILED_BACKTRACK"]),
          "accepted_nonlinear_iterations":int(f["ACCEPT_NL"]),
          "accepted_backtracking":int(f["ACCEPT_BACKTRACK"]),
        }
        fallback_rows.append(row)
        triggers_ok &= (
          row["classification"]=="RETRY_TOTAL_ONLY"
          and row["local_balance_flag_count"]==0
          and row["head_flag_count"]==0
          and row["max_abs_local_residual_cm_per_day"]<=1e-12
          and abs(row["total_residual_cm_per_day"])>1e-12
          and row["abs_total_residual_integrated_cm"]<=row["representation_bound_cm"]
        )

    case_fallbacks={c["CASE"]:int(c["FALLBACKS"]) for c in cases if "CASE" in c}
    complete=(
      len(steps)==128
      and observed_cases==expected_cases
      and all(int(c["STEPS"])==64 for c in cases)
      and summary.get("ROM1AD2_COMMITTED_STEP_COUNT")=="128"
      and summary.get("ROM1AD2_EXECUTION_COMPLETE")=="PASS"
      and summary.get("ROM1AD2_HELDOUT_EXECUTED")=="FALSE"
      and summary.get("ROM1AD2_B14_EXECUTED")=="FALSE"
      and all_step_mass
      and triggers_ok
      and case_fallbacks.get("TOP_PLUS",0)>0
      and repeat_identity
    )
    decision="ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_QUALIFIED" if complete else "ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_NO_GO"
    result={
      "schema":"swap5.rom1ad2.result.v1",
      "work_unit":"ROM-1A-D2",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "trajectory_count":len(cases),
      "committed_step_count":len(steps),
      "case_fallback_counts":case_fallbacks,
      "fallback_count":len(fallbacks),
      "fallback_rows":fallback_rows,
      "hard_mass_gate_cm":1e-12,
      "max_abs_committed_mass_residual_cm":max([abs(float(s["MASS"])) for s in steps],default=0.0),
      "hard_mass_gate_pass":all_step_mass,
      "heldout_executed":False,
      "B14_executed":False,
      "history_changed":False,
      "dt_subdivision_used":False,
      "production_fallback_admitted":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
