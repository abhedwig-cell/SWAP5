#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
import numpy as np

MATERIALS=("B01","B14")
HISTORIES=("G17","G18","G19","G20")
EPS=1.0e-12

PARAMS={
 "B01":{"tr":0.02,"ts":0.427494,"alpha":0.021659,"n":1.734737,"ks":31.225016,"lam":0.98087},
 "B14":{"tr":0.01,"ts":0.416774,"alpha":0.00541,"n":1.301528,"ks":0.895023,"lam":-0.334926},
}

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def psi_k(material,theta):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    se=(theta-p["tr"])/(p["ts"]-p["tr"])
    if not (math.isfinite(se) and 0.0<se<1.0): raise ValueError(("theta",material,theta,se))
    psi=(se**(-1.0/m)-1.0)**(1.0/p["n"])/p["alpha"]
    term=1.0-(1.0-se**(1.0/m))**m
    k=p["ks"]*se**p["lam"]*term*term
    return -psi,k

def parse(path):
    hist={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if not line.startswith("ROMPURP_P5B_GW_SHAPE|"): continue
        r=fields(line); h=r["HISTORY"]; obs=int(r["OBS_STEP"])
        if h in hist:
            hist[h][obs]={k:float(r[k]) for k in (
                "THETA_PREV","THETA_BOTTOM","THETA_HALF1","THETA_HALF2",
                "H_SLOPE_BOTTOM","BOTTOM_FLUX","BOTTOM_HEAD")}
    for h in HISTORIES:
        if sorted(hist[h])!=list(range(1,1025)):
            raise RuntimeError(f"{path}: P5B coverage {h} {len(hist[h])}/1024")
    return hist

def predictions(material,hist):
    out={x:{} for x in ("BASE16","SPLIT17","HM17")}
    for h in HISTORIES:
      for obs,r in hist[h].items():
        hp,kp=psi_k(material,r["THETA_PREV"])
        hb,kb=psi_k(material,r["THETA_BOTTOM"])
        h1,k1=psi_k(material,r["THETA_HALF1"])
        h2,k2=psi_k(material,r["THETA_HALF2"])
        g_base=(hb-hp)/2.5
        g_split=(h2-h1)/1.25
        g_hm=r["H_SLOPE_BOTTOM"]
        out["BASE16"].setdefault(h,{})[obs]=-kb*(1.0-g_base)
        out["SPLIT17"].setdefault(h,{})[obs]=-k2*(1.0-g_split)
        out["HM17"].setdefault(h,{})[obs]=-kb*(1.0-g_hm)
    return out

def metrics(pred,hist):
    diffs=[]; sign=0; biases=[]
    for h in HISTORIES:
        p=np.asarray([pred[h][i] for i in range(1,1025)],float)
        y=np.asarray([hist[h][i]["BOTTOM_FLUX"] for i in range(1,1025)],float)
        d=p-y; diffs.append(d)
        sign += int(np.count_nonzero(np.sign(p)!=np.sign(y)))
        biases.append(abs(float(np.mean(d))))
    return {
      "instantaneous_bottom_flux_rmse_cm_per_day":float(np.sqrt(np.mean(np.square(np.concatenate(diffs))))),
      "bottom_flux_sign_mismatch_count":int(sign),
      "history_signed_bottom_flux_bias_cm_per_day":float(np.mean(biases))
    }

def relation(left,right):
    keys=tuple(left)
    no_worse=all(float(left[k])<=float(right[k])+EPS for k in keys)
    strict=any(float(left[k])<float(right[k])-EPS for k in keys)
    return {"componentwise_noninferior":bool(no_worse),"strict_gain":bool(strict),
            "delta":{k:float(left[k])-float(right[k]) for k in keys}}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P5B_DIAGNOSTIC_RESPONSE"
    results={}; signals={"HM17":True,"SPLIT17":True}
    for material in MATERIALS:
        e=json.loads((a.root/f"p5b_{material}_execution.json").read_text())
        assert e["scientific_trace_identity"] and e["trace_complete"]
        hist=parse(a.root/f"p5b_{material}_o0.txt")
        pred=predictions(material,hist)
        mm={k:metrics(v,hist) for k,v in pred.items()}
        rel_h=relation(mm["HM17"],mm["BASE16"])
        rel_s=relation(mm["SPLIT17"],mm["BASE16"])
        signals["HM17"] &= rel_h["componentwise_noninferior"] and rel_h["strict_gain"]
        signals["SPLIT17"] &= rel_s["componentwise_noninferior"] and rel_s["strict_gain"]
        results[material]={"metrics":mm,"HM17_vs_BASE16":rel_h,"SPLIT17_vs_BASE16":rel_s,
                           "HM17_vs_SPLIT17":relation(mm["HM17"],mm["SPLIT17"])}
    if signals["HM17"] and signals["SPLIT17"]: decision="BOTH_SIGNAL"
    elif signals["HM17"]: decision="HYDRAULIC_SHAPE_SIGNAL"
    elif signals["SPLIT17"]: decision="STORAGE_SPLIT_SIGNAL"
    else:
        any_gain=any(results[m][x]["strict_gain"] for m in MATERIALS for x in ("HM17_vs_BASE16","SPLIT17_vs_BASE16"))
        decision="MIXED_SIGNAL" if any_gain else "NO_ROBUST_SIGNAL"
    out={
      "schema":"swap5.rom-purpose.p5b.gw-information-carrier-screen.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P5B-GW-INFORMATION-CARRIER-SCREEN",
      "status":"P5B_SCREEN_COMPLETE","decision":decision,"materials":results,
      "cross_material_signal":{"HM17":bool(signals["HM17"]),"SPLIT17":bool(signals["SPLIT17"])},
      "claims_not_made":pre["claims_not_allowed"],
      "scientific_firewall":{"dynamic_state_sufficiency_adjudicated":False,"closure_admitted":False,
                              "application_acceptance_adjudicated":False,"production_rom_authorized":False}
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"signals":out["cross_material_signal"]},sort_keys=True))

if __name__=="__main__": main()
