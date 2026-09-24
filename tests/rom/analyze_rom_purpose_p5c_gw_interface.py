#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
import numpy as np

MATERIALS=("B01","B14")
HISTORIES=("G21","G22","G23","G24")
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

def head_k_from_theta(material,theta):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    se=(theta-p["tr"])/(p["ts"]-p["tr"])
    if not (math.isfinite(se) and 0.0<se<1.0):
        raise ValueError(("theta outside constitutive screen",material,theta,se))
    psi=(se**(-1.0/m)-1.0)**(1.0/p["n"])/p["alpha"]
    h=-psi
    term=1.0-(1.0-se**(1.0/m))**m
    k=p["ks"]*se**p["lam"]*term*term
    return float(h),float(k)

def k_from_head(material,h):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    if h>=0.0:
        return float(p["ks"])
    se=(1.0+(p["alpha"]*abs(h))**p["n"])**(-m)
    term=1.0-(1.0-se**(1.0/m))**m
    return float(p["ks"]*se**p["lam"]*term*term)

def parse(path):
    hist={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if not line.startswith("ROMPURP_P5C_GW_INTERFACE|"): continue
        r=fields(line); h=r["HISTORY"]; obs=int(r["OBS_STEP"])
        if h in hist:
            hist[h][obs]={
              "theta_prev":float(r["THETA_PREV"]),
              "theta_bottom":float(r["THETA_BOTTOM"]),
              "theta_half1":float(r["THETA_HALF1"]),
              "theta_half2":float(r["THETA_HALF2"]),
              "h_slope":float(r["H_SLOPE_BOTTOM"]),
              "h_fine":float(r["H_FINE_BOTTOM"]),
              "theta_fine":float(r["THETA_FINE_BOTTOM"]),
              "face_distance":float(r["FACE_DISTANCE_CM"]),
              "q":float(r["BOTTOM_FLUX"]),
              "hbot":float(r["BOTTOM_HEAD"]),
              "bottom_mode":int(r["BOTTOM_MODE"])
            }
    for h in HISTORIES:
        if sorted(hist[h])!=list(range(1,1025)):
            raise RuntimeError(f"{path}: P5C coverage {h} {len(hist[h])}/1024")
    return hist

def qface(k,h,hbot,delta):
    # The Reference trace field BOTTOM_FLUX is terminal_bottom_outward_flux_native,
    # which the serialized backend defines as -solve_result%bottom_flux.
    # headcalc's native qbot for SWBOTB=5 is -K*g, so the outward trace is +K*g.
    return float(k)*((float(h)-float(hbot))/float(delta)+1.0)

def estimates(material,hist):
    out={x:{h:{} for h in HISTORIES} for x in ("BASE16","SPLIT17","HM17","FINE_ORACLE")}
    for h in HISTORIES:
      for obs,r in hist[h].items():
        hb,kb=head_k_from_theta(material,r["theta_bottom"])
        h2,k2=head_k_from_theta(material,r["theta_half2"])
        hnear=hb+0.625*r["h_slope"]
        khm=k_from_head(material,hnear)
        kfine=k_from_head(material,r["h_fine"])
        out["BASE16"][h][obs]=qface(kb,hb,r["hbot"],1.25)
        out["SPLIT17"][h][obs]=qface(k2,h2,r["hbot"],0.625)
        out["HM17"][h][obs]=qface(khm,hnear,r["hbot"],0.625)
        out["FINE_ORACLE"][h][obs]=qface(kfine,r["h_fine"],r["hbot"],r["face_distance"])
    return out

def selected_arrays(pred,hist,h):
    idx=[i for i in range(1,1025) if hist[h][i]["bottom_mode"]==5]
    p=np.asarray([pred[h][i] for i in idx],float)
    y=np.asarray([hist[h][i]["q"] for i in idx],float)
    return idx,p,y

def metrics(pred,hist):
    diffs=[]; sign=0; biases=[]; n=0; maxabs=0.0
    for h in HISTORIES:
        _,p,y=selected_arrays(pred,hist,h)
        d=p-y; diffs.append(d); n+=len(d)
        sign+=int(np.count_nonzero(np.sign(p)!=np.sign(y)))
        biases.append(abs(float(np.mean(d))))
        if d.size: maxabs=max(maxabs,float(np.max(np.abs(d))))
    return {
      "scored_observation_count":int(n),
      "instantaneous_bottom_flux_rmse_cm_per_day":float(np.sqrt(np.mean(np.square(np.concatenate(diffs))))),
      "maximum_absolute_bottom_flux_error_cm_per_day":float(maxabs),
      "bottom_flux_sign_mismatch_count":int(sign),
      "history_signed_bottom_flux_bias_cm_per_day":float(np.mean(biases))
    }

def candidate_metrics(full):
    return {k:v for k,v in full.items() if k in (
      "instantaneous_bottom_flux_rmse_cm_per_day",
      "bottom_flux_sign_mismatch_count",
      "history_signed_bottom_flux_bias_cm_per_day")}

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
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P5C_RESPONSE"
    oracle_rmse_gate=float(pre["oracle_gate"]["rmse_gate_cm_per_day"])
    oracle_max_gate=float(pre["oracle_gate"]["max_abs_gate_cm_per_day"])

    results={}; signal={"BASE":True,"SPLIT17":True,"HM17":True}; oracle_all=True
    for material in MATERIALS:
        exe=json.loads((a.root/f"p5c_{material}_execution.json").read_text())
        assert exe["scientific_trace_identity"] and exe["trace_complete"]
        hist=parse(a.root/f"p5c_{material}_o0.txt")
        est=estimates(material,hist)
        full={name:metrics(pred,hist) for name,pred in est.items()}
        oracle=full["FINE_ORACLE"]
        oracle_pass=(oracle["scored_observation_count"]==3072 and
                     oracle["instantaneous_bottom_flux_rmse_cm_per_day"]<=oracle_rmse_gate and
                     oracle["maximum_absolute_bottom_flux_error_cm_per_day"]<=oracle_max_gate and
                     oracle["bottom_flux_sign_mismatch_count"]==0)
        oracle_all=oracle_all and oracle_pass
        cm={name:candidate_metrics(full[name]) for name in ("BASE16","SPLIT17","HM17")}
        rs=relation(cm["SPLIT17"],cm["BASE16"])
        rh=relation(cm["HM17"],cm["BASE16"])
        rhs=relation(cm["HM17"],cm["SPLIT17"])
        signal["SPLIT17"] &= rs["componentwise_noninferior"] and rs["strict_gain"]
        signal["HM17"] &= rh["componentwise_noninferior"] and rh["strict_gain"]
        results[material]={
          "oracle":{"metrics":oracle,"pass":bool(oracle_pass),
                    "rmse_gate_cm_per_day":oracle_rmse_gate,"max_abs_gate_cm_per_day":oracle_max_gate},
          "metrics":full,
          "SPLIT17_vs_BASE16":rs,
          "HM17_vs_BASE16":rh,
          "HM17_vs_SPLIT17":rhs
        }

    if not oracle_all:
        decision="ORACLE_GATE_FAILED"
        signal["SPLIT17"]=False; signal["HM17"]=False
    elif signal["HM17"] and signal["SPLIT17"]: decision="BOTH_SIGNAL"
    elif signal["HM17"]: decision="HYDRAULIC_SHAPE_SIGNAL"
    elif signal["SPLIT17"]: decision="STORAGE_SPLIT_SIGNAL"
    else:
        any_gain=any(results[m][x]["strict_gain"] for m in MATERIALS for x in ("HM17_vs_BASE16","SPLIT17_vs_BASE16"))
        decision="MIXED_SIGNAL" if any_gain else "NO_ROBUST_SIGNAL"

    out={
      "schema":"swap5.rom-purpose.p5c.gw-boundary-interface-carrier-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P5C-GW-BOUNDARY-INTERFACE-CARRIER",
      "status":"P5C_SCREEN_COMPLETE","decision":decision,
      "oracle_gate_pass":bool(oracle_all),
      "cross_material_signal":{"HM17":bool(signal["HM17"]),"SPLIT17":bool(signal["SPLIT17"])},
      "materials":results,
      "downstream_authority":(
        "FRESH_DYNAMIC_BLIND_VALIDATION_MAY_BE_PREREGISTERED_FOR_SCREENED_CARRIER"
        if oracle_all and decision in ("HYDRAULIC_SHAPE_SIGNAL","STORAGE_SPLIT_SIGNAL","BOTH_SIGNAL")
        else "NO_DYNAMIC_CARRIER_VALIDATION_AUTHORIZED_BY_P5C"),
      "scientific_firewall":{
        "minimum_state_count_adjudicated":False,"dynamic_state_sufficiency_adjudicated":False,
        "closure_admitted":False,"application_acceptance_adjudicated":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"oracle_gate_pass":oracle_all,
                      "signals":out["cross_material_signal"]},sort_keys=True))

if __name__=="__main__": main()
