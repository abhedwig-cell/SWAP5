#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np

HISTORIES=("G21","G22","G23","G24")
MATERIALS=("B01","B14")
FEATURES={
 "STORAGE":("S","HBOT_NEXT"),
 "STORAGE_LOWER80":("S","L80","HBOT_NEXT"),
 "STORAGE_MEMORY1":("S","PREV_DS","HBOT_NEXT"),
 "STORAGE_LOWER80_MEMORY1":("S","L80","PREV_DS","HBOT_NEXT"),
}

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def parse(path):
    state={h:{} for h in HISTORIES}; prof={h:{} for h in HISTORIES}; iface={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in state:
                step=int(r["STEP"])
                if step%8==0:
                    state[h][step//8]={"storage":float(r["TOTAL_STORAGE"])}
        elif line.startswith("LAREGW1_PROFILE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in prof:
                prof[h].setdefault(int(r["OBS_STEP"]),{})[int(r["BIN"])]=float(r["THETA"])
        elif line.startswith("ROMPURP_P5C_GW_INTERFACE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in iface:
                iface[h][int(r["OBS_STEP"])]={"hbot":float(r["BOTTOM_HEAD"]),"mode":int(r["BOTTOM_MODE"])}
    return state,prof,iface

def dataset(path):
    state,prof,iface=parse(path)
    rows=[]
    for h in HISTORIES:
        if len(state[h])!=1024 or len(prof[h])!=1024 or len(iface[h])!=1024:
            raise RuntimeError((h,len(state[h]),len(prof[h]),len(iface[h])))
        for obs in range(2,1024):
            if iface[h][obs+1]["mode"]!=5: continue
            bins=np.asarray([prof[h][obs][i] for i in range(1,17)],float)
            rows.append({
              "history":h,"obs":obs,
              "S":state[h][obs]["storage"],
              "L80":float(np.sum(bins[8:])*10.0),
              "PREV_DS":state[h][obs]["storage"]-state[h][obs-1]["storage"],
              "HBOT_NEXT":iface[h][obs+1]["hbot"],
              "target":state[h][obs+1]["storage"]-state[h][obs]["storage"]
            })
    return rows

def fit(rows,features):
    X=np.asarray([[r[k] for k in features] for r in rows],float)
    y=np.asarray([r["target"] for r in rows],float)
    mean=X.mean(axis=0); scale=X.std(axis=0); scale[scale==0.0]=1.0
    z=(X-mean)/scale
    A=np.column_stack([np.ones(len(z)),z])
    beta=np.linalg.lstsq(A,y,rcond=None)[0]
    pred=A@beta
    err=pred-y
    by_history={}
    for h in HISTORIES:
        idx=np.asarray([r["history"]==h for r in rows],bool)
        e=err[idx]
        by_history[h]={"count":int(np.count_nonzero(idx)),"rmse_cm":float(np.sqrt(np.mean(e*e)))}
    return {
      "features":list(features),
      "feature_mean":[float(v) for v in mean],
      "feature_scale":[float(v) for v in scale],
      "intercept":float(beta[0]),
      "standardized_coefficients":[float(v) for v in beta[1:]],
      "training_count":len(rows),
      "training_rmse_cm":float(np.sqrt(np.mean(err*err))),
      "training_by_history":by_history
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--contract",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    c=json.loads(a.contract.read_text())
    assert c["status"]=="DERIVATION_ONLY_RESPONSE_EXPOSED"
    outm={}
    for material in MATERIALS:
        exe=json.loads((a.root/f"p5c_{material}_execution.json").read_text())
        assert exe["scientific_trace_identity"] and exe["trace_complete"]
        rows=dataset(a.root/f"p5c_{material}_o0.txt")
        outm[material]={name:fit(rows,features) for name,features in FEATURES.items()}
    out={
      "schema":"swap5.rom-purpose.p8a.transition-carrier-derivation.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P8A-TRANSITION-CARRIER-DERIVATION",
      "status":"P8A_DERIVATION_COMPLETE_COEFFICIENTS_FROZEN_FOR_P8B",
      "evidence_class":"RESPONSE_EXPOSED_DERIVATION_ONLY",
      "materials":outm,
      "candidate_family":list(FEATURES),
      "scientific_firewall":{
        "training_performance_is_validation":False,
        "candidate_family_pruned":False,
        "validation_histories_seen":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":out["status"],"training_rmse":{m:{k:v["training_rmse_cm"] for k,v in outm[m].items()} for m in MATERIALS}},sort_keys=True))

if __name__=="__main__": main()
