#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
import numpy as np

OBS_DT=0.0008
HISTORIES=("G17","G18","G19","G20")
MEMBERS=("G8","G12","G16")
MATERIALS=("B01","B14")
SE={"G17":0.72,"G18":0.80,"G19":0.85,"G20":0.90}
PARAMS={
 "B01":{"ks":31.225016,"lam":0.98087,"n":1.734737},
 "B14":{"ks":0.895023,"lam":-0.334926,"n":1.301528},
}

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def k_from_se(material,se):
    p=PARAMS[material]; m=1.0-1.0/p["n"]
    term=1.0-(1.0-se**(1.0/m))**m
    return float(p["ks"]*se**p["lam"]*term*term)

def parse_reference(path):
    hist={h:{} for h in HISTORIES}
    for line in path.read_text(errors="strict").splitlines():
        if not line.startswith("LAREGW1_STATE|"): continue
        r=fields(line); h=r.get("HISTORY")
        if h in hist:
            hist[h][int(r["STEP"])]={
              "storage":float(r["TOTAL_STORAGE"]),
              "top_exchange":float(r["TOP_EXCHANGE"]),
              "bottom_exchange":float(r["BOTTOM_OUTWARD_EXCHANGE"])
            }
    for h in HISTORIES:
        if sorted(hist[h])!=list(range(1,32769)):
            raise RuntimeError(f"{path}: {h} coverage {len(hist[h])}/32768")
    out={h:{"storage":[],"top_input":[],"bottom_exchange":[]} for h in HISTORIES}
    for h in HISTORIES:
        for obs in range(1,1025):
            lo=(obs-1)*32+1; hi=obs*32
            rows=[hist[h][k] for k in range(lo,hi+1)]
            out[h]["storage"].append(rows[-1]["storage"])
            out[h]["top_input"].append(-sum(x["top_exchange"] for x in rows))
            out[h]["bottom_exchange"].append(sum(x["bottom_exchange"] for x in rows))
    return out

def load_candidate(root,material,member):
    hits=list(root.rglob(f"GW_LB_{material}_{member}.json"))
    if len(hits)!=1:
        raise RuntimeError((material,member,[str(x) for x in hits]))
    obj=json.loads(hits[0].read_text())
    c=obj["candidate"]
    assert c["material"]==material and c["id"]==member and c["purpose"]=="GW_LB"
    assert c["status"]=="QUALIFIED"
    return c

def rmse(x):
    a=np.asarray(x,float)
    return float(np.sqrt(np.mean(np.square(a))))

def score_case(material,member,cand,ref):
    interval_errors=[]; storage_transition_errors=[]; top_errors=[]; identity_residuals=[]
    cumulative_identity_residuals=[]; history={}
    for h in HISTORIES:
        c=cand["histories"][h]
        cs=np.asarray(c["total_storage_cm"],float)
        cb=np.asarray(c["interval_average_bottom_downward_flux_cm_per_day"],float)*OBS_DT
        cc=np.asarray(c["cumulative_bottom_downward_cm"],float)
        rs=np.asarray(ref[h]["storage"],float)
        rt=np.asarray(ref[h]["top_input"],float)
        rb=np.asarray(ref[h]["bottom_exchange"],float)
        qt=k_from_se(material,SE[h])*OBS_DT
        qtc=np.full(1024,qt,float)
        eB=cb[1:]-rb[1:]
        eDS=(cs[1:]-cs[:-1])-(rs[1:]-rs[:-1])
        eQ=qtc[1:]-rt[1:]
        resid=eB-(eQ-eDS)
        # cumulative identity relative to the first serialized observation
        ref_cum=np.cumsum(rb)
        eCum=(cc[1:]-cc[0])-(ref_cum[1:]-ref_cum[0])
        predCum=np.cumsum(eQ)-((cs[1:]-cs[0])-(rs[1:]-rs[0]))
        cres=eCum-predCum
        interval_errors.extend(eB); storage_transition_errors.extend(eDS)
        top_errors.extend(eQ); identity_residuals.extend(resid); cumulative_identity_residuals.extend(cres)
        history[h]={
          "interval_count":1023,
          "bottom_exchange_error_rmse_cm":rmse(eB),
          "storage_transition_error_rmse_cm":rmse(eDS),
          "top_input_error_max_abs_cm":float(np.max(np.abs(eQ))),
          "identity_residual_rmse_cm":rmse(resid),
          "identity_residual_max_abs_cm":float(np.max(np.abs(resid))),
          "cumulative_identity_residual_max_abs_cm":float(np.max(np.abs(cres))),
          "exchange_vs_negative_storage_transition_correlation":float(np.corrcoef(eB,-eDS)[0,1])
        }
    eB=np.asarray(interval_errors); eDS=np.asarray(storage_transition_errors)
    eQ=np.asarray(top_errors); resid=np.asarray(identity_residuals); cres=np.asarray(cumulative_identity_residuals)
    return {
      "interval_count":int(len(eB)),
      "bottom_exchange_error_rmse_cm":rmse(eB),
      "bottom_flux_error_rmse_cm_per_day":rmse(eB)/OBS_DT,
      "storage_transition_error_rmse_cm":rmse(eDS),
      "top_input_error_max_abs_cm":float(np.max(np.abs(eQ))),
      "identity_residual_rmse_cm":rmse(resid),
      "identity_residual_max_abs_cm":float(np.max(np.abs(resid))),
      "cumulative_identity_residual_max_abs_cm":float(np.max(np.abs(cres))),
      "identity_residual_to_exchange_rmse_ratio":float(rmse(resid)/rmse(eB)),
      "exchange_vs_negative_storage_transition_correlation":float(np.corrcoef(eB,-eDS)[0,1]),
      "candidate_max_abs_water_ledger_cm":float(cand["max_abs_water_ledger_cm"]),
      "histories":history
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--authority",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-root",required=True,type=pathlib.Path)
    ap.add_argument("--reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    auth=json.loads(a.authority.read_text())
    assert auth["status"]=="RETROSPECTIVE_ALGEBRAIC_RECONCILIATION_RESPONSE_EXPOSED"
    cases={}; plateau={}
    for material in MATERIALS:
        ref=parse_reference(a.reference_root/f"gw_{material}_R2048_T32_o0.txt")
        cases[material]={}
        for member in MEMBERS:
            cases[material][member]=score_case(material,member,load_candidate(a.candidate_root,material,member),ref)
        plateau[material]={
          "G8_to_G12_exchange_rmse_fraction":cases[material]["G12"]["bottom_exchange_error_rmse_cm"]/cases[material]["G8"]["bottom_exchange_error_rmse_cm"],
          "G12_to_G16_exchange_rmse_fraction":cases[material]["G16"]["bottom_exchange_error_rmse_cm"]/cases[material]["G12"]["bottom_exchange_error_rmse_cm"],
          "G12_to_G16_storage_transition_rmse_fraction":cases[material]["G16"]["storage_transition_error_rmse_cm"]/cases[material]["G12"]["storage_transition_error_rmse_cm"]
        }
    max_ratio=max(cases[m][g]["identity_residual_to_exchange_rmse_ratio"] for m in MATERIALS for g in MEMBERS)
    max_top=max(cases[m][g]["top_input_error_max_abs_cm"] for m in MATERIALS for g in MEMBERS)
    decision=("GW_EXCHANGE_ERROR_STORAGE_TRANSITION_ATTRIBUTED"
              if max_ratio<1e-8 and max_top<1e-12
              else "GW_EXCHANGE_ERROR_ATTRIBUTION_NOT_CLOSED")
    out={
      "schema":"swap5.rom-purpose.p7a.gw-exchange-storage-attribution.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P7A-GW-EXCHANGE-STORAGE-ATTRIBUTION",
      "status":"P7A_RETROSPECTIVE_RECONCILIATION_COMPLETE",
      "evidence_class":"RETROSPECTIVE_ALGEBRAIC_RESPONSE_EXPOSED",
      "decision":decision,
      "cases":cases,"state_count_plateau":plateau,
      "max_identity_residual_to_exchange_rmse_ratio":max_ratio,
      "max_top_input_error_cm":max_top,
      "interpretation":(
        "Within the existing P4 groundwater evidence, interval bottom-exchange error is the negative storage-transition error to numerical ledger/serialization precision because top forcing is shared. The published bottom-exchange metric therefore does not independently diagnose a local lower-boundary closure."
        if decision=="GW_EXCHANGE_ERROR_STORAGE_TRANSITION_ATTRIBUTED"
        else "The expected conservation-law attribution did not close numerically."),
      "scientific_firewall":{
        "blind_validation_claimed":False,"minimum_state_count_adjudicated":False,
        "closure_deficit_adjudicated":False,"application_acceptance_adjudicated":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"max_ratio":max_ratio,"plateau":plateau},sort_keys=True))

if __name__=="__main__": main()
