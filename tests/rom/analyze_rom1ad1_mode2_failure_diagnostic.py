#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1);out[k]=v
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
    cls=None;bound=None;prefix=None
    for line in text.splitlines():
        if "ROM1AD1_PREFIX|" in line: prefix=fields(line.split("ROM1AD1_PREFIX|",1)[1])
        elif "ROM1AD1_CLASS|" in line: cls=fields(line.split("ROM1AD1_CLASS|",1)[1])
        elif "ROM1AD1_BOUND|" in line: bound=fields(line.split("ROM1AD1_BOUND|",1)[1])
    repeat_identity=text==repeat
    complete=prefix is not None and cls is not None and bound is not None and "ROM1AD1_DIAGNOSTIC_COMPLETE=PASS" in text
    decision="ROM1AD1_DIAGNOSTIC_BLOCKED"
    if complete:
        c=cls["CLASS"]
        within=b(bound["WITHIN_BOUND"])
        if c=="RETRY_TOTAL_ONLY" and within:
            decision="ROM1AD1_RETRY_TOTAL_ONLY_WITHIN_REPRESENTATION_BOUND"
        elif c=="RETRY_TOTAL_ONLY":
            decision="ROM1AD1_RETRY_TOTAL_ONLY_EXCEEDS_REPRESENTATION_BOUND"
        elif c=="RETRY_LOCAL_BALANCE": decision="ROM1AD1_RETRY_LOCAL_BALANCE"
        elif c=="RETRY_HEAD": decision="ROM1AD1_RETRY_HEAD"
        elif c=="RETRY_MIXED": decision="ROM1AD1_RETRY_MIXED"
        elif c=="RETRY_OTHER": decision="ROM1AD1_RETRY_OTHER"
    result={
      "schema":"swap5.rom1ad1.result.v1",
      "work_unit":"ROM-1A-D1",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "accepted_prefix":{
        "steps":int(prefix["PASS_STEPS"]) if prefix else None,
        "revision":int(prefix["REV"]) if prefix else None,
        "time_day":float(prefix["T"]) if prefix else None,
      },
      "failure":{
        "classification":cls["CLASS"] if cls else None,
        "local_balance_flag_count":int(cls["BAL_FLAGS"]) if cls else None,
        "head_flag_count":int(cls["HEAD_FLAGS"]) if cls else None,
        "max_abs_local_residual_cm_per_day":float(cls["RMAX"]) if cls else None,
        "total_residual_cm_per_day":float(cls["RSUM"]) if cls else None,
        "max_residual_node":int(cls["IMAX"]) if cls else None,
        "nonlinear_iterations":int(cls["NL"]) if cls else None,
        "backtracking_attempts":int(cls["BACKTRACK"]) if cls else None,
      },
      "representation":{
        "bound_cm":float(bound["REP_BOUND_CM"]) if bound else None,
        "abs_total_residual_integrated_cm":float(bound["ABS_TOTAL_RESIDUAL_CM"]) if bound else None,
        "residual_over_bound":float(bound["RESIDUAL_OVER_BOUND"]) if bound else None,
        "within_bound":b(bound["WITHIN_BOUND"]) if bound else None,
        "formula":"0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i)",
        "observed_residual_used_in_formula":False,
        "policy_applied_to_solver":False,
      },
      "controls_changed":False,
      "history_changed":False,
      "failed_candidate_committed":False,
      "mode2_fallback_authorized":False,
      "rom1a_parent_reclassified":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    if not repeat_identity or decision=="ROM1AD1_DIAGNOSTIC_BLOCKED":
        return 2
    return 0
if __name__=="__main__":
    raise SystemExit(main())
