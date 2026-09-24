#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
import numpy as np

MATERIALS=("B01","B14")
HISTORIES=("G21","G22","G23","G24")
PARAMS={
 "B01":{"alpha":0.021659,"n":1.734737,"ks":31.225016,"lam":0.98087},
 "B14":{"alpha":0.00541,"n":1.301528,"ks":0.895023,"lam":-0.334926},
}
DELTA=0.15625

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def k_from_head(material,h):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    if h>=0.0: return float(p["ks"])
    se=(1.0+(p["alpha"]*abs(h))**p["n"])**(-m)
    term=1.0-(1.0-se**(1.0/m))**m
    return float(p["ks"]*se**p["lam"]*term*term)

def parse(path):
    rows=[]
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith("ROMPURP_P6A_BOUNDARY_ORACLE|"):
            r=fields(line)
            rows.append({
              "history":r["HISTORY"],"step":int(r["STEP"]),
              "pre_h":float(r["PRE_BOTTOM_H"]),"post_h":float(r["POST_BOTTOM_H"]),
              "hbot":float(r["HBOT"]),"target":float(r["BOTTOM_OUTWARD_FLUX"])
            })
    return rows

def metrics(pred,target):
    p=np.asarray(pred,float); y=np.asarray(target,float); d=p-y
    return {
      "count":int(len(d)),
      "rmse_cm_per_day":float(np.sqrt(np.mean(np.square(d)))),
      "max_abs_error_cm_per_day":float(np.max(np.abs(d))),
      "sign_mismatch_count":int(np.count_nonzero(np.sign(p)!=np.sign(y))),
      "mean_abs_error_cm_per_day":float(np.mean(np.abs(d)))
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P6A_RESPONSE"

    results={}; all_pass=True
    for material in MATERIALS:
        exe=json.loads((a.root/f"p6a_{material}_execution.json").read_text())
        assert exe["scientific_trace_identity"] and exe["trace_complete"]
        rows=parse(a.root/f"p6a_{material}_o0.txt")
        if len(rows)!=3072:
            raise RuntimeError((material,len(rows)))
        target=[]; lagged=[]; current=[]
        for r in rows:
            g=(r["post_h"]-r["hbot"])/DELTA+1.0
            target.append(r["target"])
            lagged.append(k_from_head(material,r["pre_h"])*g)
            current.append(k_from_head(material,r["post_h"])*g)
        lm=metrics(lagged,target); cm=metrics(current,target)
        gate=(lm["count"]==3072 and
              lm["rmse_cm_per_day"]<=float(pre["oracle"]["rmse_gate_cm_per_day"]) and
              lm["max_abs_error_cm_per_day"]<=float(pre["oracle"]["max_abs_gate_cm_per_day"]) and
              lm["sign_mismatch_count"]==int(pre["oracle"]["sign_mismatch_gate"]))
        all_pass=all_pass and gate
        results[material]={
          "lagged_conductivity_oracle":lm,
          "current_conductivity_contrast":cm,
          "oracle_pass":bool(gate),
          "rmse_improvement_factor":None if lm["rmse_cm_per_day"]==0 else cm["rmse_cm_per_day"]/lm["rmse_cm_per_day"]
        }

    decision="LAGGED_BOUNDARY_OPERATOR_CONFIRMED" if all_pass else "LAGGED_BOUNDARY_OPERATOR_NOT_CONFIRMED"
    out={
      "schema":"swap5.rom-purpose.p6a.lagged-boundary-operator-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P6A-LAGGED-BOUNDARY-OPERATOR-ORACLE",
      "status":"P6A_COMPLETE","decision":decision,"oracle_gate_pass":bool(all_pass),
      "materials":results,
      "downstream_authority":(
        "P6B_LAGGED_CONDUCTIVITY_MEMORY_CARRIER_MAY_BE_PREREGISTERED"
        if all_pass else "NO_REDUCED_MEMORY_CARRIER_TEST_AUTHORIZED_BY_P6A"),
      "scientific_firewall":{
        "solver_or_physics_changed":False,"numerical_policy_changed":False,
        "tolerance_changed":False,"reduced_state_sufficiency_adjudicated":False,
        "application_acceptance_adjudicated":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"oracle_gate_pass":all_pass},sort_keys=True))

if __name__=="__main__": main()
