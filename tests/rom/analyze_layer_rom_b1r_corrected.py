#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("V01","V02","V03","V04")
ORDER=("L2","L3","L4","L6")
GW=("storage_rmse_cm","cumulative_bottom_rmse_cm","qavg_rmse_cm_per_day","qavg_sign_errors",
    "abs_mean_signed_qavg_error_cm_per_day","qend_rmse_cm_per_day","qend_sign_errors",
    "abs_mean_signed_qend_error_cm_per_day","max_abs_final_cumulative_bottom_error_cm")
PROFILE=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);return mod

def stats(v):
    a=np.asarray(v,dtype=float)
    return {"rmse":float(np.sqrt(np.mean(a*a))),"mean":float(np.mean(a)),
            "mean_abs":float(np.mean(np.abs(a))),"max_abs":float(np.max(np.abs(a)))}

def sign(x): return 1 if x>0 else (-1 if x<0 else 0)

def ref_qend(b1,r16,h,s):
    theta=float(r16["nodes"][(h,s,16)]["THETA"])
    return float(b1.qbottom_zero_head(np.asarray([theta]),np.asarray([10.0])))

def run_candidate(b1,mid,bounds,r16):
    es=[];ec=[];eqa=[];eqe=[];et=[];eu=[];el=[];sa=se=0;finals=[];maxledger=0.;maxiter=0
    for h in HISTS:
        lam=b1.HISTS[h];dz,y,initial=b1.initial(lam,bounds,r16["initial"][h]);prev=0.;refcum=0.
        h_ec=[]
        for step in range(1,b1.NSTEPS+1):
            for _ in range(b1.SUBSTEPS):
                y,it=b1.heun_step(y,dz);maxiter=max(maxiter,it)
            theta=y[:len(dz)]/dz;b1.psi_k(theta)
            total=float(np.sum(y[:len(dz)]));cum=float(y[len(dz)+1])
            qavg=(cum-prev)/b1.OBS_DT;prev=cum
            qend=b1.qbottom_zero_head(theta,dz)
            rr=r16["states"][(h,step)]
            refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            rqavg=float(rr["BOTTOM_OUTWARD_EXCHANGE"])/b1.OBS_DT
            if abs(rqavg-float(rr["BOTTOM_FLUX"]))>1e-10: raise RuntimeError("Reference QAVG identity")
            rqend=ref_qend(b1,r16,h,step)
            es.append(total-float(rr["TOTAL_STORAGE"]));ec.append(cum-refcum);h_ec.append(cum-refcum)
            eqa.append(qavg-rqavg);eqe.append(qend-rqend)
            sa+=int(sign(rqavg)!=0 and sign(qavg)!=sign(rqavg))
            se+=int(sign(rqend)!=0 and sign(qend)!=sign(rqend))
            mapped=b1.map_piecewise_to_10cm(theta,bounds)
            for node,t in enumerate(mapped,1):et.append(float(t)-float(r16["nodes"][(h,step,node)]["THETA"]))
            ru=sum(float(r16["nodes"][(h,step,node)]["THETA"])*10. for node in range(1,9))
            rl=sum(float(r16["nodes"][(h,step,node)]["THETA"])*10. for node in range(9,17))
            eu.append(b1.integrated_storage(theta,bounds,0.,80.)-ru)
            el.append(b1.integrated_storage(theta,bounds,80.,160.)-rl)
            ledger=total-initial+cum;maxledger=max(maxledger,abs(ledger))
            if abs(ledger)>b1.LEDGER_GATE: raise RuntimeError("ledger gate")
        finals.append(h_ec[-1])
    S,C,QA,QE,T,U,L=map(stats,(es,ec,eqa,eqe,et,eu,el))
    return {
      "id":mid,"dimension":len(bounds)-1,"boundaries_cm":bounds,
      "storage_rmse_cm":S["rmse"],"cumulative_bottom_rmse_cm":C["rmse"],
      "qavg_rmse_cm_per_day":QA["rmse"],"qavg_sign_errors":sa,
      "abs_mean_signed_qavg_error_cm_per_day":abs(QA["mean"]),
      "qend_rmse_cm_per_day":QE["rmse"],"qend_sign_errors":se,
      "abs_mean_signed_qend_error_cm_per_day":abs(QE["mean"]),
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "mapped_theta_rmse":T["rmse"],"upper_storage_rmse_cm":U["rmse"],"lower_storage_rmse_cm":L["rmse"],
      "max_abs_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter
    }

def run_r2(b1,r2,r16):
    es=[];ec=[];eqa=[];eqe=[];et=[];eu=[];el=[];sa=se=0;finals=[]
    for h in HISTS:
        cc=rc=0.;hec=[]
        for step in range(1,b1.NSTEPS+1):
            c=r2["states"][(h,step)];r=r16["states"][(h,step)]
            ce=float(c["BOTTOM_OUTWARD_EXCHANGE"]);re=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            cc+=ce;rc+=re
            cqa=ce/b1.OBS_DT;rqa=re/b1.OBS_DT
            if abs(cqa-float(c["BOTTOM_FLUX"]))>1e-10 or abs(rqa-float(r["BOTTOM_FLUX"]))>1e-10:
                raise RuntimeError("QAVG identity")
            ctheta=float(r2["nodes"][(h,step,2)]["THETA"])
            cqend=float(b1.qbottom_zero_head(np.asarray([ctheta]),np.asarray([80.0])))
            rqend=ref_qend(b1,r16,h,step)
            es.append(float(c["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"]));ec.append(cc-rc);hec.append(cc-rc)
            eqa.append(cqa-rqa);eqe.append(cqend-rqend)
            sa+=int(sign(rqa)!=0 and sign(cqa)!=sign(rqa));se+=int(sign(rqend)!=0 and sign(cqend)!=sign(rqend))
            t1=float(r2["nodes"][(h,step,1)]["THETA"]);t2=ctheta
            for node,t in enumerate([t1]*8+[t2]*8,1):et.append(t-float(r16["nodes"][(h,step,node)]["THETA"]))
            ru=sum(float(r16["nodes"][(h,step,node)]["THETA"])*10. for node in range(1,9))
            rl=sum(float(r16["nodes"][(h,step,node)]["THETA"])*10. for node in range(9,17))
            eu.append(t1*80.-ru);el.append(t2*80.-rl)
        finals.append(hec[-1])
    S,C,QA,QE,T,U,L=map(stats,(es,ec,eqa,eqe,et,eu,el))
    return {"storage_rmse_cm":S["rmse"],"cumulative_bottom_rmse_cm":C["rmse"],
      "qavg_rmse_cm_per_day":QA["rmse"],"qavg_sign_errors":sa,"abs_mean_signed_qavg_error_cm_per_day":abs(QA["mean"]),
      "qend_rmse_cm_per_day":QE["rmse"],"qend_sign_errors":se,"abs_mean_signed_qend_error_cm_per_day":abs(QE["mean"]),
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "mapped_theta_rmse":T["rmse"],"upper_storage_rmse_cm":U["rmse"],"lower_storage_rmse_cm":L["rmse"]}

def relation(a,b,k,tol):
    x=int(a) if k.endswith("_sign_errors") else float(a);y=int(b) if k.endswith("_sign_errors") else float(b)
    if x<y-tol:return "A_STRICTLY_BETTER"
    if y<x-tol:return "B_STRICTLY_BETTER"
    return "NUMERICALLY_EQUAL"

def vector(a,b,keys,tol):
    r={k:relation(a[k],b[k],k,tol) for k in keys}
    ano=all(x in ("A_STRICTLY_BETTER","NUMERICALLY_EQUAL") for x in r.values())
    bno=all(x in ("B_STRICTLY_BETTER","NUMERICALLY_EQUAL") for x in r.values())
    label="A_COMPONENTWISE_NO_WORSE" if ano and any(x=="A_STRICTLY_BETTER" for x in r.values()) else (
      "B_COMPONENTWISE_NO_WORSE" if bno and any(x=="B_STRICTLY_BETTER" for x in r.values()) else (
      "NUMERICALLY_EQUIVALENT" if all(x=="NUMERICALLY_EQUAL" for x in r.values()) else "TRADEOFF"))
    return {"vector_relation":label,"component_relation":r}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path);ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--old-b1",required=True,type=pathlib.Path);ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path);a=ap.parse_args()
    pre=json.loads(a.prereg.read_text());old=json.loads(a.old_b1.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_B01_FIXED_HEAD_FRONTIER_REPAIR":raise SystemExit("wrong B1R phase")
    b1=load("layer_rom_b1r_b1",HERE/"analyze_layer_rom_b1_fixed_head_ladder.py")
    r16=b1.parse_d13(a.r16);r2=b1.parse_d13(a.r2)
    cmp=run_r2(b1,r2,r16)
    cand={mid:run_candidate(b1,mid,[float(x) for x in b1.LADDER[mid]],r16) for mid in ORDER}
    # retained-component reproduction against old B1
    maxrep=0.
    mapold={"storage_rmse_cm":"total_storage_rmse_cm","cumulative_bottom_rmse_cm":"cumulative_bottom_exchange_rmse_cm",
            "mapped_theta_rmse":"mapped_R16_theta_rmse"}
    for mid,row in cand.items():
        for nk,ok in mapold.items():maxrep=max(maxrep,abs(float(row[nk])-float(old["members"][mid][ok])))
    if maxrep>1e-11:raise SystemExit(f"retained B1 reproduction drift {maxrep}")
    tol=float(pre["comparator_rule"]["relation_tolerance"])
    rel={mid:{"GW":vector(row,cmp,GW,tol),"PROFILE":vector(row,cmp,PROFILE,tol)} for mid,row in cand.items()}
    crossing=[mid for mid in ORDER if rel[mid]["GW"]["vector_relation"]=="A_COMPONENTWISE_NO_WORSE"]
    mindim=min((cand[x]["dimension"] for x in crossing),default=None)
    decision="B1R_CORRECTED_R2_FRONTIER_PRESENT" if mindim is not None else "B1R_CORRECTED_R2_FRONTIER_NOT_REACHED"
    out={"schema":"swap5.layer-rom.phase-b1r.result.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1R",
      "decision":decision,"R2_comparator":cmp,"members":cand,"relations":rel,
      "corrected_R2_GW_frontier":{"minimum_dimension":mindim,"crossing_members":crossing},
      "FMC_corrected_flux_frontier":"HELD_RAW_TERMINAL_STATE_UNAVAILABLE",
      "integrity":{"pass":True,"max_retained_B1_reproduction_delta":maxrep,
                   "maximum_water_ledger_cm":max(x["max_abs_water_ledger_cm"] for x in cand.values())},
      "supersession":["B1 old R2/FMC GW frontier decisions using mixed-semantics bottom flux are superseded.",
                      "B1 retained storage/cumulative/profile values remain reproduced."],
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"frontier":out["corrected_R2_GW_frontier"],"relations":rel,"R2":cmp},sort_keys=True))
    return 0
if __name__=="__main__":raise SystemExit(main())
