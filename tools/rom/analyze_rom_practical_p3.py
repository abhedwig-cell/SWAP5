#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib, math, statistics
import numpy as np

FACTOR=32
SURF=("SD01","SD02")
GWLOG=("D01","D02")
GWKEY={"D01":"GD01","D02":"GD02"}

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
    out={}
    for h in SURF:
        total=[]; theta=[]
        for d in range(1,61):
            total.append(states[(h,d)])
            bins=prof[(h,d)]; theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta,float)
        out[h]={"total":np.asarray(total),"theta":th,
                "surface":np.sum(th[:,:2]*10.,axis=1),
                "root":np.sum(th[:,:4]*10.,axis=1),
                "upper":np.sum(th[:,:8]*10.,axis=1)}
    return out

def parse_gw(path):
    rows={h:[] for h in GWLOG}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1]); h=r["HISTORY"]
            if h in rows:
                rows[h].append((int(r["STEP"]),float(r["TOTAL_STORAGE"]),float(r["BOTTOM_OUTWARD_EXCHANGE"])))
    out={}
    for h in GWLOG:
        rr=sorted(rows[h])
        if len(rr)!=1920: raise RuntimeError((h,len(rr)))
        total=[]; cum=[]; q=[]; acc=0.
        for i in range(0,1920,FACTOR):
            chunk=rr[i:i+FACTOR]; ex=sum(x[2] for x in chunk); acc+=ex
            total.append(chunk[-1][1]); cum.append(acc); q.append(ex)
        out[GWKEY[h]]={"total":np.asarray(total),"cum":np.asarray(cum),"q":np.asarray(q)}
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

def surf_metrics(candidate,ref):
    pools={k:[] for k in ("surface_0_20_storage_rmse_cm","root_zone_0_40_storage_rmse_cm","upper_0_80_storage_rmse_cm","mapped_10cm_theta_rmse","total_storage_rmse_cm")}
    timing=0; finals=[]
    for h in SURF:
        c=candidate[h]; r=ref[h]
        cs=np.asarray(c["surface_0_20_storage_cm"]); cr=np.asarray(c["root_zone_0_40_storage_cm"])
        cu=np.asarray(c["upper_0_80_storage_cm"]); ct=np.asarray(c["theta_10cm"]); ctot=np.asarray(c["total_storage_cm"])
        pools["surface_0_20_storage_rmse_cm"].append(cs-r["surface"])
        pools["root_zone_0_40_storage_rmse_cm"].append(cr-r["root"])
        pools["upper_0_80_storage_rmse_cm"].append(cu-r["upper"])
        pools["mapped_10cm_theta_rmse"].append((ct-r["theta"]).ravel())
        pools["total_storage_rmse_cm"].append(ctot-r["total"])
        for a,b in ((cr,r["root"]),(cu,r["upper"])):
            timing=max(timing,abs(int(np.argmax(a))-int(np.argmax(b))),abs(int(np.argmin(a))-int(np.argmin(b))))
        finals.append(abs(float(ctot[-1]-r["total"][-1])))
    out={k:rmse(np.concatenate(v)) for k,v in pools.items()}
    out["final_total_storage_bias_cm"]=float(max(finals))
    out["daily_storage_extremum_timing_error_days"]=int(timing)
    return out

def gw_metrics(candidate,ref):
    pc=[]; pq=[]; ps=[]; sign=seq=timing=0; drift=[]
    for h in ("GD01","GD02"):
        c=candidate[h]; r=ref[h]
        cc=np.asarray(c["cumulative_bottom_downward_cm"]); cq=np.asarray(c["interval_average_bottom_downward_flux_cm_per_day"]); cs=np.asarray(c["total_storage_cm"])
        pc.append(cc-r["cum"]); pq.append(cq-r["q"]); ps.append(cs-r["total"])
        sign+=int(np.count_nonzero(np.sign(cq)!=np.sign(r["q"])))
        ca,ra=reversals(cq),reversals(r["q"])
        if len(ca)!=len(ra): seq+=1; timing=max(timing,60)
        else: timing=max(timing,max([abs(a-b) for a,b in zip(ca,ra)] or [0]))
        drift.append(abs(float((cc-r["cum"])[-1])))
    return {
      "cumulative_bottom_exchange_rmse_cm":rmse(np.concatenate(pc)),
      "daily_bottom_flux_rmse_cm_per_day":rmse(np.concatenate(pq)),
      "bottom_flux_sign_mismatch_days":sign,
      "reversal_sequence_mismatch_count":seq,
      "reversal_timing_error_days":timing,
      "total_storage_rmse_cm":rmse(np.concatenate(ps)),
      "final_exchange_drift_cm":float(max(drift))
    }

def pseudo_surface(ref):
    o={}
    for h,x in ref.items():
        o[h]={"surface_0_20_storage_cm":x["surface"].tolist(),"root_zone_0_40_storage_cm":x["root"].tolist(),"upper_0_80_storage_cm":x["upper"].tolist(),"theta_10cm":x["theta"].tolist(),"total_storage_cm":x["total"].tolist()}
    return o
def pseudo_gw(ref):
    o={}
    for h,x in ref.items():
        o[h]={"cumulative_bottom_downward_cm":x["cum"].tolist(),"interval_average_bottom_downward_flux_cm_per_day":x["q"].tolist(),"total_storage_cm":x["total"].tolist()}
    return o

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True)
    ap.add_argument("--candidate",required=True,type=pathlib.Path)
    ap.add_argument("--r64",required=True,type=pathlib.Path)
    ap.add_argument("--r128",required=True,type=pathlib.Path)
    ap.add_argument("--r128-timing",required=True,type=pathlib.Path)
    ap.add_argument("--split",required=True,choices=("development","validation"))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    cand=json.loads(a.candidate.read_text())
    if cand["status"]!="QUALIFIED":
        rt=json.loads(a.r128_timing.read_text()); wall=float(rt["wall"])
        out={"schema":"swap5.rom-practical.p3.case-result.v1","purpose":a.purpose,"material":a.material,"split":a.split,
             "classification":"STRUCTURALLY_UNRELIABLE","candidate_status":cand["status"],"candidate_failure":cand.get("failure"),
             "candidate_metrics":None,"reference_comparator":None,"reference_observable_for_primary_discrete_claim":False,
             "performance":{"candidate_wall_s":None,"reference_R128_wall_s":wall,"candidate_over_reference_wall_ratio":None},
             "firewall":{"seasonal_claim":False,"application_acceptance":False,"production_admission":False}}
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({"purpose":a.purpose,"material":a.material,"split":a.split,"classification":"STRUCTURALLY_UNRELIABLE"},sort_keys=True))
        return
    if a.purpose=="SURF_P":
        r64=parse_surface(a.r64); r128=parse_surface(a.r128)
        metrics=surf_metrics(cand["histories"],r128); comparator=surf_metrics(pseudo_surface(r64),r128)
        observable=not (metrics["daily_storage_extremum_timing_error_days"]>0 and comparator["daily_storage_extremum_timing_error_days"]>=metrics["daily_storage_extremum_timing_error_days"])
        cls="DAILY_TIMING_SENSITIVE" if observable and metrics["daily_storage_extremum_timing_error_days"]>0 else "DAILY_APPROXIMATE"
    else:
        r64=parse_gw(a.r64); r128=parse_gw(a.r128)
        metrics=gw_metrics(cand["histories"],r128); comparator=gw_metrics(pseudo_gw(r64),r128)
        discrete=max(metrics["bottom_flux_sign_mismatch_days"],metrics["reversal_sequence_mismatch_count"],metrics["reversal_timing_error_days"])
        compdisc=max(comparator["bottom_flux_sign_mismatch_days"],comparator["reversal_sequence_mismatch_count"],comparator["reversal_timing_error_days"])
        observable=discrete>compdisc
        cls="DAILY_GW_EVENT_SENSITIVE" if observable and discrete>0 else "DAILY_APPROXIMATE"
    rt=json.loads(a.r128_timing.read_text()); wall=float(rt["wall"])
    out={"schema":"swap5.rom-practical.p3.case-result.v1","purpose":a.purpose,"material":a.material,"split":a.split,
         "classification":cls,"candidate_metrics":metrics,"reference_comparator":comparator,
         "reference_observable_for_primary_discrete_claim":observable,
         "performance":{"candidate_wall_s":cand["timing"]["wall_s_median"],"reference_R128_wall_s":wall,
                        "candidate_over_reference_wall_ratio":cand["timing"]["wall_s_median"]/wall if wall>0 else None},
         "firewall":{"seasonal_claim":False,"application_acceptance":False,"production_admission":False}}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"purpose":a.purpose,"material":a.material,"split":a.split,"classification":cls,"wall_ratio":out["performance"]["candidate_over_reference_wall_ratio"]},sort_keys=True))
if __name__=="__main__": main()
