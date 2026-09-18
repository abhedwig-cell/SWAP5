#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib

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
    raw=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    repeat_identity=raw==repeat

    states=[]; histories=[]; fallbacks=[]; summary={}
    current_history=None; current_step=0
    for line in raw.splitlines():
        if "ROM1AR1D3_STATE|" in line:
            r=fields(line.split("ROM1AR1D3_STATE|",1)[1])
            states.append(r)
            current_history=r["HISTORY"]; current_step=int(r["STEP"])
        elif "ROM1AR1D3_HISTORY_PASS|" in line:
            histories.append(fields(line.split("ROM1AR1D3_HISTORY_PASS|",1)[1]))
        elif "ROM1AR1D3_FALLBACK|" in line:
            r=fields(line.split("ROM1AR1D3_FALLBACK|",1)[1])
            r["_history_context"]=current_history
            r["_step_context"]=current_step+1
            fallbacks.append(r)
        elif line.startswith("ROM1AR1D3_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()

    expected={f"D{i:02d}" for i in range(1,9)}
    by_hist=collections.defaultdict(list)
    for s in states: by_hist[s.get("HISTORY","")].append(s)
    structure=(set(by_hist)==expected and all(len(by_hist[h])==64 for h in expected)
               and len(states)==512 and len(histories)==8
               and {h.get("HISTORY") for h in histories}==expected)

    max_mass=max((abs(float(s["MASS"])) for s in states),default=math.inf)
    all_finite=all(all(math.isfinite(float(s[k])) for k in (
        "T","TOTAL_STORAGE","UPPER_STORAGE","LOWER_STORAGE",
        "TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE","BOTTOM_FLUX","MASS"
    )) for s in states)
    progression=True
    for h,rows in by_hist.items():
        rows=sorted(rows,key=lambda r:int(r["STEP"]))
        for i,r in enumerate(rows,1):
            progression &= int(r["STEP"])==i and int(r["REV"])==2+i

    fallback_ok=True
    total_only_count=0; local_count=0
    fallback_rows=[]
    d08_step34_local=False
    for f in fallbacks:
        cls=f["CLASS"]
        bal=int(f["BAL_FLAGS"]); head=int(f["HEAD_FLAGS"])
        rmax=float(f["RMAX"]); rsum=float(f["RSUM"])
        rep=float(f["REP_BOUND_CM"]); total_int=float(f["ABS_TOTAL_RESIDUAL_CM"])
        local_int=float(f["LOCAL_INTEGRATED_CM"])
        cp_tol=float(f["FALLBACK_CP_TOL"]); total_tol=float(f["FALLBACK_TOTAL_TOL"])
        common=(head==0 and math.isfinite(rep) and rep>0 and total_int<=rep
                and total_tol>=1e-12)
        if cls=="RETRY_TOTAL_ONLY":
            ok=common and bal==0 and rmax<=1e-12 and abs(rsum)>1e-12 and cp_tol==1e-12
            total_only_count+=1
        elif cls=="RETRY_LOCAL_BALANCE":
            ok=(common and bal>0 and local_int<=1.6e-15
                and cp_tol==max(1e-12,1.6e-15/0.0008))
            local_count+=1
            if f.get("_history_context")=="D08" and int(f.get("_step_context",0))==34:
                d08_step34_local=True
        else:
            ok=False
        fallback_ok &= ok
        fallback_rows.append({
          "history_context":f.get("_history_context"),
          "step_context":f.get("_step_context"),
          "bottom_mode":int(f["BOTTOM_MODE"]),
          "classification":cls,
          "local_balance_flag_count":bal,
          "head_flag_count":head,
          "max_abs_local_residual_cm_per_day":rmax,
          "total_residual_cm_per_day":rsum,
          "local_integrated_cm":local_int,
          "total_integrated_cm":total_int,
          "total_representation_bound_cm":rep,
          "fallback_compartment_tolerance_cm_per_day":cp_tol,
          "fallback_total_tolerance_cm_per_day":total_tol,
        })

    state_fallback_count=sum(1 for s in states if as_bool(s["FALLBACK"]))
    fallback_count_consistent=state_fallback_count==len(fallbacks)
    complete=all([
      repeat_identity,structure,all_finite,progression,max_mass<=1e-12,
      fallback_ok,fallback_count_consistent,d08_step34_local,
      summary.get("ROM1AR1D3_HISTORY_COUNT")=="8",
      summary.get("ROM1AR1D3_STATE_COUNT")=="512",
      summary.get("ROM1AR1D3_HELDOUT_EXECUTED")=="FALSE",
      summary.get("ROM1AR1D3_B14_EXECUTED")=="FALSE",
      summary.get("ROM1AR1D3_EXECUTION_COMPLETE")=="PASS",
    ])
    decision=("ROM1AR1D3_DISCOVERY_LOCAL_PLUS_TOTAL_FALLBACK_QUALIFIED"
              if complete else "ROM1AR1D3_DISCOVERY_LOCAL_PLUS_TOTAL_FALLBACK_NO_GO")
    result={
      "schema":"swap5.rom1ar1d3.result.v1",
      "work_unit":"ROM-1A-R1-D3",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "discovery":{"history_count":len(histories),"accepted_state_count":len(states)},
      "fallback":{
        "count":len(fallbacks),
        "state_fallback_count":state_fallback_count,
        "total_only_count":total_only_count,
        "local_balance_count":local_count,
        "semantics_pass":fallback_ok,
        "count_consistent":fallback_count_consistent,
        "D08_step34_local_fallback_observed":d08_step34_local,
        "rows":fallback_rows,
      },
      "mass":{"hard_gate_cm":1e-12,"max_abs_committed_mass_residual_cm":max_mass,"pass":max_mass<=1e-12},
      "gates":{
        "structure":structure,
        "finite_primary_outputs":all_finite,
        "revision_progression":progression,
        "heldout_not_executed":summary.get("ROM1AR1D3_HELDOUT_EXECUTED")=="FALSE",
        "B14_not_executed":summary.get("ROM1AR1D3_B14_EXECUTED")=="FALSE",
      },
      "heldout_executed":False,
      "B14_executed":False,
      "production_reference_admitted":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
