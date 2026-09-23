#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib
import numpy as np

OBS_DT=0.0008
FACTOR=8
SURF=("S09","S10","S11","S12")
GW=("G06","G07","G08","G09")

def fields(s):
    out={}
    for x in s.split("|"):
        if "=" in x:
            k,v=x.split("=",1); out[k]=v
    return out

def parse_surface(path):
    states={}; prof={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line.split("|",1)[1]); step=int(r["STEP"])
            if step%FACTOR==0: states[(r["CASE"],step//FACTOR)]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line.split("|",1)[1])
            prof.setdefault((r["CASE"],int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
    out={"histories":{}}
    for h in SURF:
        total=[]; theta=[]
        for s in range(1,1025):
            total.append(states[(h,s)])
            bins=prof[(h,s)]
            theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta,float)
        out["histories"][h]={
          "total":np.asarray(total,float),
          "theta":th,
          "surface":np.sum(th[:,:2]*10.,axis=1),
          "root":np.sum(th[:,:4]*10.,axis=1),
          "upper":np.sum(th[:,:8]*10.,axis=1)
        }
    return out

def parse_gw(path):
    rows={h:[] for h in GW}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1]); h=r["HISTORY"]
            if h in rows:
                rows[h].append((int(r["STEP"]),float(r["TOTAL_STORAGE"]),float(r["BOTTOM_OUTWARD_EXCHANGE"])))
    out={"histories":{}}
    for h in GW:
        rr=sorted(rows[h])
        if len(rr)!=8192: raise RuntimeError((h,len(rr)))
        total=[]; cum=[]; q=[]; acc=0.
        for i in range(0,len(rr),FACTOR):
            chunk=rr[i:i+FACTOR]
            ex=sum(x[2] for x in chunk); acc+=ex
            total.append(chunk[-1][1]); cum.append(acc); q.append(ex/OBS_DT)
        out["histories"][h]={"total":np.asarray(total),"cum":np.asarray(cum),"q":np.asarray(q)}
    return out

def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,float)))))
def reversals(x):
    out=[]; prev=0
    for i,v in enumerate(np.asarray(x,float),1):
        s=1 if v>0 else -1 if v<0 else 0
        if s==0: continue
        if prev and s!=prev: out.append(i)
        prev=s
    return out

def extrema_delay(a,b):
    best=0
    for x,y in zip(a,b):
        for fn in (np.argmax,np.argmin):
            best=max(best,abs(int(fn(x))-int(fn(y))))
    return best

def surface_metrics(candidate,reference):
    pool={k:[] for k in ("surface_0_20_storage_error_cm","root_zone_0_40_storage_error_cm","upper_0_80_storage_error_cm","mapped_10cm_theta_error","total_storage_error_cm")}
    signed=[]; timing=0
    for h in SURF:
        c=candidate[h]; r=reference["histories"][h]
        cs=np.asarray(c["surface_0_20_storage_cm"]); cr=np.asarray(c["root_zone_0_40_storage_cm"])
        cu=np.asarray(c["upper_0_80_storage_cm"]); ct=np.asarray(c["theta_10cm"]); ctot=np.asarray(c["total_storage_cm"])
        pool["surface_0_20_storage_error_cm"].append(cs-r["surface"])
        pool["root_zone_0_40_storage_error_cm"].append(cr-r["root"])
        pool["upper_0_80_storage_error_cm"].append(cu-r["upper"])
        pool["mapped_10cm_theta_error"].append((ct-r["theta"]).ravel())
        pool["total_storage_error_cm"].append(ctot-r["total"])
        timing=max(timing,extrema_delay((cr,cu),(r["root"],r["upper"])))
        signed.append(abs(float(np.mean(ctot-r["total"]))))
    out={k:rmse(np.concatenate(v)) for k,v in pool.items()}
    out["storage_extremum_timing_error_steps"]=int(timing)
    out["history_signed_storage_bias_cm"]=float(np.mean(signed))
    return out

def gw_metrics(candidate,reference):
    pool={k:[] for k in ("cumulative_bottom_exchange_error_cm","interval_bottom_flux_error_cm_per_day","total_storage_error_cm")}
    sign=seq=timing=0; bias=[]; drift=[]
    for h in GW:
        c=candidate[h]; r=reference["histories"][h]
        cc=np.asarray(c["cumulative_bottom_downward_cm"]); cq=np.asarray(c["interval_average_bottom_downward_flux_cm_per_day"]); cs=np.asarray(c["total_storage_cm"])
        pool["cumulative_bottom_exchange_error_cm"].append(cc-r["cum"])
        pool["interval_bottom_flux_error_cm_per_day"].append(cq-r["q"])
        pool["total_storage_error_cm"].append(cs-r["total"])
        sign+=int(np.count_nonzero(np.sign(cq)!=np.sign(r["q"])))
        ca,ra=reversals(cq),reversals(r["q"])
        if len(ca)!=len(ra): seq+=1; timing=max(timing,1024)
        else: timing=max(timing,max([abs(a-b) for a,b in zip(ca,ra)] or [0]))
        bias.append(abs(float(np.mean(cq-r["q"])))); drift.append(abs(float((cc-r["cum"])[-1])))
    out={k:rmse(np.concatenate(v)) for k,v in pool.items()}
    out["bottom_flux_sign_mismatch_count"]=sign; out["reversal_sequence_mismatch_count"]=seq; out["reversal_timing_error_steps"]=timing
    out["history_signed_bottom_flux_bias_cm_per_day"]=float(np.mean(bias)); out["long_horizon_exchange_drift_cm"]=max(drift)
    return out

def pseudo_surface(ref):
    o={}
    for h in SURF:
        x=ref["histories"][h]
        o[h]={"surface_0_20_storage_cm":x["surface"].tolist(),"root_zone_0_40_storage_cm":x["root"].tolist(),"upper_0_80_storage_cm":x["upper"].tolist(),"theta_10cm":x["theta"].tolist(),"total_storage_cm":x["total"].tolist()}
    return o
def pseudo_gw(ref):
    o={}
    for h in GW:
        x=ref["histories"][h]
        o[h]={"cumulative_bottom_downward_cm":x["cum"].tolist(),"interval_average_bottom_downward_flux_cm_per_day":x["q"].tolist(),"total_storage_cm":x["total"].tolist()}
    return o

def componentwise(a,b,tol=1e-12):
    return all(float(a[k])<=float(b[k])+tol for k in a)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True); ap.add_argument("--material",required=True)
    ap.add_argument("--candidate",required=True,type=pathlib.Path); ap.add_argument("--r128",required=True,type=pathlib.Path); ap.add_argument("--r256",required=True,type=pathlib.Path)
    ap.add_argument("--r256-timing",required=True,type=pathlib.Path); ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    cand=json.loads(a.candidate.read_text())
    if a.purpose=="SURF_P":
        r128=parse_surface(a.r128); r256=parse_surface(a.r256)
        metrics=surface_metrics(cand["histories"],r256)
        comparator=surface_metrics(pseudo_surface(r128),r256)
        if metrics["storage_extremum_timing_error_steps"]>0: cls="TIMING_SENSITIVE"
        else: cls="ROBUST_RELATIVE" if componentwise(metrics,comparator) else "APPROXIMATE_TRANSFER"
    else:
        r128=parse_gw(a.r128); r256=parse_gw(a.r256)
        metrics=gw_metrics(cand["histories"],r256)
        comparator=gw_metrics(pseudo_gw(r128),r256)
        if metrics["bottom_flux_sign_mismatch_count"] or metrics["reversal_sequence_mismatch_count"] or metrics["reversal_timing_error_steps"]: cls="EVENT_SENSITIVE"
        else: cls="ROBUST_RELATIVE" if componentwise(metrics,comparator) else "APPROXIMATE_TRANSFER"
    rt=json.loads(a.r256_timing.read_text())
    refcpu=float(rt["user"])+float(rt["sys"]); refwall=float(rt["wall"])
    cwall=float(cand["timing"]["wall_s_median"]); ccpu=float(cand["timing"]["cpu_s_median"])
    out={
      "schema":"swap5.rom-practical.p2a.case-result.v1","purpose":a.purpose,"material":a.material,
      "classification":cls,"candidate_metrics":metrics,"reference_numerical_comparator":comparator,
      "candidate_reaches_comparator":componentwise(metrics,comparator),
      "performance":{"candidate_wall_s":cwall,"reference_R256_wall_s":refwall,"candidate_over_reference_wall_ratio":cwall/refwall if refwall>0 else None,"candidate_cpu_s":ccpu,"reference_R256_cpu_s":refcpu,"candidate_over_reference_cpu_ratio":ccpu/refcpu if refcpu>0 else None},
      "firewall":{"application_acceptance":False,"portable_speedup":False,"production_admission":False}
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"purpose":a.purpose,"material":a.material,"classification":cls,"wall_ratio":out["performance"]["candidate_over_reference_wall_ratio"]},sort_keys=True))
if __name__=="__main__": main()
