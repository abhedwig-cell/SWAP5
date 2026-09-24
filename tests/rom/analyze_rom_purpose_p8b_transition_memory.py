#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np

HISTORIES=("G25","G26","G27","G28")
MATERIALS=("B01","B14")
SE={"G25":0.75,"G26":0.83,"G27":0.89,"G28":0.95}
PARAMS={
 "B01":{"alpha":0.021659,"n":1.734737},
 "B14":{"alpha":0.00541,"n":1.301528},
}
CANDIDATES=("STORAGE","STORAGE_LOWER80","STORAGE_MEMORY1","STORAGE_LOWER80_MEMORY1")

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def h_from_se(material,se):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    return -((se**(-1.0/m)-1.0)**(1.0/p["n"]))/p["alpha"]

def parse(path):
    state={h:{} for h in HISTORIES}; prof={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in state:
                step=int(r["STEP"])
                if step%8==0:
                    state[h][step//8]={
                      "storage":float(r["TOTAL_STORAGE"]),
                      "mode":int(r["BOTTOM_MODE"]),
                      "symbol":r["SYMBOL"]
                    }
        elif line.startswith("LAREGW1_PROFILE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in prof:
                prof[h].setdefault(int(r["OBS_STEP"]),{})[int(r["BIN"])]=float(r["THETA"])
    for h in HISTORIES:
        if len(state[h])!=1024 or len(prof[h])!=1024:
            raise RuntimeError((path,h,len(state[h]),len(prof[h])))
    return state,prof

def hbot(material,history,symbol):
    h0=h_from_se(material,SE[history])
    if symbol=="RISE": return 0.90*h0
    if symbol=="FALL": return 1.10*h0
    raise ValueError((history,symbol))

def rows(material,path):
    state,prof=parse(path); out=[]
    for h in HISTORIES:
        for obs in range(2,1024):
            nxt=state[h][obs+1]
            if nxt["mode"]!=5: continue
            bins=np.asarray([prof[h][obs][i] for i in range(1,17)],float)
            out.append({
              "history":h,"obs":obs,
              "S":state[h][obs]["storage"],
              "L80":float(np.sum(bins[8:])*10.0),
              "PREV_DS":state[h][obs]["storage"]-state[h][obs-1]["storage"],
              "HBOT_NEXT":hbot(material,h,nxt["symbol"]),
              "target":state[h][obs+1]["storage"]-state[h][obs]["storage"],
              "event_switch":state[h][obs]["symbol"]!=nxt["symbol"]
            })
    return out

def predict(rows,coef):
    feats=coef["features"]
    mean=np.asarray(coef["feature_mean"],float)
    scale=np.asarray(coef["feature_scale"],float)
    beta=np.asarray(coef["standardized_coefficients"],float)
    X=np.asarray([[r[k] for k in feats] for r in rows],float)
    z=(X-mean)/scale
    return float(coef["intercept"])+z@beta

def metrics(rows,pred):
    y=np.asarray([r["target"] for r in rows],float); e=np.asarray(pred)-y
    byh={}
    for h in HISTORIES:
        idx=np.asarray([r["history"]==h for r in rows],bool); eh=e[idx]
        byh[h]={
          "count":int(np.count_nonzero(idx)),
          "rmse_cm":float(np.sqrt(np.mean(eh*eh))),
          "signed_mean_error_cm":float(np.mean(eh))
        }
    switch=np.asarray([r["event_switch"] for r in rows],bool)
    return {
      "count":len(rows),
      "rmse_cm":float(np.sqrt(np.mean(e*e))),
      "signed_mean_error_cm":float(np.mean(e)),
      "event_switch_count":int(np.count_nonzero(switch)),
      "event_switch_rmse_cm":None if not np.any(switch) else float(np.sqrt(np.mean(e[switch]*e[switch]))),
      "by_history":byh
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--coefficients",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text()); co=json.loads(a.coefficients.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P8B_REFERENCE_OR_VALIDATION_RESPONSE"
    assert co["status"]=="P8A_DERIVATION_COMPLETE_COEFFICIENTS_FROZEN_FOR_P8B"
    results={}; ratios={}; h1=True; h2=True
    for material in MATERIALS:
        exe=json.loads((a.root/f"p8b_{material}_execution.json").read_text())
        assert exe["scientific_trace_identity"] and exe["trace_complete"]
        assert float(exe["max_abs_transaction_mass_cm"])<=float(pre["fresh_workload"]["mass_gate_cm"])
        rr=rows(material,a.root/f"p8b_{material}_o0.txt")
        results[material]={}
        for name in CANDIDATES:
            p=predict(rr,co["materials"][material][name])
            results[material][name]=metrics(rr,p)
        base=results[material]["STORAGE"]["rmse_cm"]
        lower=results[material]["STORAGE_LOWER80"]["rmse_cm"]
        mem=results[material]["STORAGE_MEMORY1"]["rmse_cm"]
        combo=results[material]["STORAGE_LOWER80_MEMORY1"]["rmse_cm"]
        ratios[material]={
          "MEMORY_over_STORAGE":mem/base,
          "MEMORY_over_LOWER80":mem/lower,
          "LOWER80_over_STORAGE":lower/base,
          "COMBINED_over_MEMORY":combo/mem,
          "memory_improved_history_count":sum(
             results[material]["STORAGE_MEMORY1"]["by_history"][h]["rmse_cm"] <
             results[material]["STORAGE"]["by_history"][h]["rmse_cm"] for h in HISTORIES)
        }
        h1=h1 and mem<base
        h2=h2 and mem<lower
    decision="BLIND_TRANSITION_MEMORY_SIGNAL_SUPPORTED" if h1 and h2 else "BLIND_TRANSITION_MEMORY_SIGNAL_NOT_SUPPORTED"
    out={
      "schema":"swap5.rom-purpose.p8b.blind-transition-memory-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P8B-BLIND-TRANSITION-MEMORY-VALIDATION",
      "status":"P8B_BLIND_VALIDATION_COMPLETE","decision":decision,
      "hypotheses":{"H1_supported":bool(h1),"H2_supported":bool(h2)},
      "materials":results,"ratios":ratios,
      "interpretation":{
        "transition_memory_response_relevant":bool(h1 and h2),
        "minimum_memory_order_established":False,
        "dynamic_rom_validated":False,
        "application_acceptance_adjudicated":False
      },
      "scientific_firewall":{
        "coefficients_refit_on_validation":False,"candidate_family_changed":False,
        "weighted_cross_material_score_used":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"ratios":ratios},sort_keys=True))

if __name__=="__main__": main()
