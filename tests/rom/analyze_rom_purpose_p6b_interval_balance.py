#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np

MATERIALS=("B01","B14")
HISTORIES=("G21","G22","G23","G24")
DT=0.0001

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def parse(path):
    hist={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if not line.startswith("LAREGW1_STATE|"): continue
        r=fields(line); h=r.get("HISTORY")
        if h in hist:
            hist[h][int(r["STEP"])]={
              "bottom_mode":int(r["BOTTOM_MODE"]),
              "storage":float(r["TOTAL_STORAGE"]),
              "top_exchange":float(r["TOP_EXCHANGE"]),
              "bottom_exchange":float(r["BOTTOM_OUTWARD_EXCHANGE"]),
              "bottom_flux":float(r["BOTTOM_FLUX"])
            }
    for h in HISTORIES:
        if sorted(hist[h])!=list(range(1,8193)):
            raise RuntimeError((path,h,len(hist[h])))
    return hist

def score(hist):
    errs=[]; flux_errs=[]; sign=0; n=0; by_history={}
    for h in HISTORIES:
        e=[]; f=[]; s=0
        rows=hist[h]
        for step in range(2,8193):
            r=rows[step]
            if r["bottom_mode"]!=5: continue
            prev=rows[step-1]
            pred=-r["top_exchange"]-(r["storage"]-prev["storage"])
            err=pred-r["bottom_exchange"]
            ferr=pred/DT-r["bottom_flux"]
            e.append(err); f.append(ferr)
            if np.sign(pred)!=np.sign(r["bottom_exchange"]): s+=1
        errs.extend(e); flux_errs.extend(f); sign+=s; n+=len(e)
        by_history[h]={
          "count":len(e),
          "rmse_exchange_cm":float(np.sqrt(np.mean(np.square(e)))) if e else None,
          "max_abs_exchange_error_cm":float(np.max(np.abs(e))) if e else None,
          "rmse_flux_cm_per_day":float(np.sqrt(np.mean(np.square(f)))) if f else None,
          "sign_mismatch_count":int(s)
        }
    ee=np.asarray(errs,float); ff=np.asarray(flux_errs,float)
    return {
      "count":int(n),
      "rmse_exchange_cm":float(np.sqrt(np.mean(np.square(ee)))),
      "max_abs_exchange_error_cm":float(np.max(np.abs(ee))),
      "rmse_flux_cm_per_day":float(np.sqrt(np.mean(np.square(ff)))),
      "max_abs_flux_error_cm_per_day":float(np.max(np.abs(ff))),
      "sign_mismatch_count":int(sign),
      "by_history":by_history
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P6B_ANALYSIS"
    results={}; allpass=True
    for material in MATERIALS:
        exe=json.loads((a.root/f"p5c_{material}_execution.json").read_text())
        assert exe["scientific_trace_identity"] and exe["trace_complete"]
        hist=parse(a.root/f"p5c_{material}_o0.txt")
        m=score(hist)
        gate=(m["rmse_exchange_cm"]<=float(pre["metrics"]["rmse_exchange_cm"]) and
              m["max_abs_exchange_error_cm"]<=float(pre["metrics"]["max_abs_exchange_error_cm"]) and
              m["sign_mismatch_count"]==int(pre["metrics"]["sign_mismatch_gate"]))
        m["oracle_pass"]=bool(gate); results[material]=m; allpass=allpass and gate
    decision="INTERVAL_BALANCE_OPERATOR_CONFIRMED" if allpass else "INTERVAL_BALANCE_OPERATOR_NOT_CONFIRMED"
    out={
      "schema":"swap5.rom-purpose.p6b.interval-balance-boundary-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P6B-INTERVAL-BALANCE-BOUNDARY-OPERATOR",
      "status":"P6B_COMPLETE","decision":decision,"oracle_gate_pass":bool(allpass),
      "materials":results,
      "implication":(
        "Published prescribed-head bottom exchange is an interval state-transition observable requiring start/end storage and interval external fluxes; terminal local boundary shape is not by itself the published exchange operator."
        if allpass else "Operator authority remains unresolved."),
      "scientific_firewall":{
        "simulations_rerun":False,"candidate_screen_adjudicated":False,
        "application_acceptance_adjudicated":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"oracle_gate_pass":allpass},sort_keys=True))

if __name__=="__main__": main()
