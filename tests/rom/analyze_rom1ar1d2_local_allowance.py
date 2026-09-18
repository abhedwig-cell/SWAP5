#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,math

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    cls=bound=fail=None
    for line in text.splitlines():
        if "ROM1AR1D1_CLASS|" in line: cls=fields(line.split("ROM1AR1D1_CLASS|",1)[1])
        elif "ROM1AR1D1_BOUND|" in line: bound=fields(line.split("ROM1AR1D1_BOUND|",1)[1])
        elif "ROM1AR1D1_FAILURE|" in line: fail=fields(line.split("ROM1AR1D1_FAILURE|",1)[1])
    repeat_identity=text==repeat
    allowance=1.6e-15
    dt=0.0008
    rmax=float(cls["RMAX"]) if cls else math.nan
    local_integrated=abs(rmax)*dt
    ratio=local_integrated/allowance
    positive=(
      cls is not None and bound is not None and fail is not None
      and cls["CLASS"]=="RETRY_LOCAL_BALANCE"
      and int(cls["BAL_FLAGS"])==1
      and int(cls["HEAD_FLAGS"])==0
      and int(fail["STEP"])==34
      and int(fail["BOTTOM_MODE"])==5
      and local_integrated<=allowance
      and repeat_identity
    )
    decision=("ROM1AR1D2_LOCAL_RESIDUAL_WITHIN_PRIOR_INTEGRATED_ALLOWANCE"
              if positive else "ROM1AR1D2_LOCAL_RESIDUAL_EXCEEDS_PRIOR_INTEGRATED_ALLOWANCE")
    result={
      "schema":"swap5.rom1ar1d2.result.v1",
      "work_unit":"ROM-1A-R1-D2",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "case":{"history":"D08","step":34,"symbol":"BOTTOM_HEAD_RISE","bottom_mode":5,"dt_day":dt},
      "failure":{
        "classification":cls["CLASS"] if cls else None,
        "local_balance_flag_count":int(cls["BAL_FLAGS"]) if cls else None,
        "head_flag_count":int(cls["HEAD_FLAGS"]) if cls else None,
        "max_abs_local_residual_cm_per_day":rmax,
        "max_abs_local_residual_integrated_cm":local_integrated,
      },
      "prior_independent_allowance":{
        "source":"PUB-P2E19/P2E20/P2E21",
        "compartment_integrated_allowance_cm":allowance,
        "local_residual_over_allowance":ratio,
        "within_allowance":local_integrated<=allowance,
        "failed_D08_residual_used_to_choose_allowance":False,
        "empirical_safety_factor":None,
      },
      "total_context":{
        "abs_total_residual_integrated_cm":float(bound["ABS_TOTAL_RESIDUAL_CM"]) if bound else None,
        "total_representation_bound_cm":float(bound["REP_BOUND_CM"]) if bound else None,
        "total_within_representation_bound":(
          float(bound["ABS_TOTAL_RESIDUAL_CM"])<=float(bound["REP_BOUND_CM"]) if bound else None
        )
      },
      "policy_applied_to_solver":False,
      "controls_changed":False,
      "heldout_inspected":False,
      "B14_inspected":False,
      "policy_qualification_authorized_by_this_result":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if positive else 2

if __name__=="__main__":
    raise SystemExit(main())
