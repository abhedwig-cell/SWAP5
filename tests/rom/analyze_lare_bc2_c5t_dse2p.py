#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib
import numpy as np
from numpy.polynomial.legendre import leggauss

HISTS=("R01","R02","R03","R04")
BOUNDS=np.asarray([0.,70.,80.,90.,100.,110.,120.,130.,140.,150.,155.,157.5,160.])
WIDTHS=np.diff(BOUNDS)
DEPTHS=np.asarray([70.,80.,90.,100.,110.,120.,130.,140.,150.,155.,157.5])
PRIMARY={150.0,155.0,157.5}
DZ_FINE=0.078125
TR=.01; TS=.416774; ALPHA=.00541; NVG=1.301528; MVG=1.0-1.0/NVG; KS=.895023; LAMBDA=-.334926
EQ=1e-10

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out

def phase(hist:str,obs:int)->str:
    first=224 if hist in ("R01","R02") else 320
    if obs<=first:return "PHASE1"
    if obs<=576:return "PHASE2"
    return "HOLD"

def theta_to_psi(theta):
    x=np.asarray(theta,dtype=float)
    se=(x-TR)/(TS-TR)
    if np.any(~np.isfinite(se)) or np.any(se<=0.0) or np.any(se>=1.0):
        raise RuntimeError("C5T representative theta outside admitted B14 range")
    return np.power(np.power(se,-1.0/MVG)-1.0,1.0/NVG)/ALPHA

def k_from_theta(theta):
    x=np.asarray(theta,dtype=float)
    se=(x-TR)/(TS-TR)
    if np.any(~np.isfinite(se)) or np.any(se<=0.0) or np.any(se>=1.0):
        raise RuntimeError("C5T theta outside admitted B14 range")
    term=1.0-np.power(1.0-np.power(se,1.0/MVG),MVG)
    return KS*np.power(se,LAMBDA)*np.square(term)

def k_from_psi(psi):
    p=np.asarray(psi,dtype=float)
    out=np.empty_like(p)
    sat=p<=0.0
    out[sat]=KS
    u=~sat
    if np.any(u):
        se=np.power(1.0+np.power(ALPHA*p[u],NVG),-MVG)
        term=1.0-np.power(1.0-np.power(se,1.0/MVG),MVG)
        out[u]=KS*np.power(se,LAMBDA)*np.square(term)
    return out

def qstats(x):
    a=np.asarray(x,dtype=float)
    return {
      "rmse_cm_per_day":float(np.sqrt(np.mean(a*a))),
      "signed_mean_cm_per_day":float(np.mean(a)),
      "mean_abs_cm_per_day":float(np.mean(np.abs(a))),
      "max_abs_cm_per_day":float(np.max(np.abs(a))),
    }

def dse_root_order(psi_u,psi_d,L,order):
    u=np.asarray(psi_u,dtype=float);d=np.asarray(psi_d,dtype=float)
    if u.shape!=d.shape:raise RuntimeError("DSE shape mismatch")
    n=u.size
    q=np.empty(n,dtype=float)
    resid=np.zeros(n,dtype=float)
    x,w=leggauss(order)
    delta=d-u
    equal=np.abs(delta)<=1e-12
    if np.any(equal):
        q[equal]=k_from_psi(u[equal])
        resid[equal]=0.0

    def solve(mask,increasing):
        if not np.any(mask):return
        uu=u[mask];dd=d[mask];half=0.5*(dd-uu);mid=0.5*(dd+uu)
        ps=mid[:,None]+half[:,None]*x[None,:]
        kval=k_from_psi(ps)
        kup=k_from_psi(uu);kdn=k_from_psi(dd)
        if increasing:
            lo=np.maximum(kup,kdn)*(1.0+1e-13)+1e-14
            hi=lo+KS
        else:
            hi=np.minimum(kup,kdn)*(1.0-1e-13)-1e-14
            lo=-np.full_like(hi,KS)
        def F(qq):
            integ=half*np.sum(w[None,:]*(kval/(qq[:,None]-kval)),axis=1)
            return integ-L
        flo=F(lo);fhi=F(hi)
        for _ in range(40):
            bad=(flo*fhi>0.0)|(~np.isfinite(flo))|(~np.isfinite(fhi))
            if not np.any(bad):break
            if increasing:
                hi[bad]=lo[bad]+2.0*(hi[bad]-lo[bad])
                fhi=F(hi)
            else:
                lo[bad]=2.0*lo[bad]-KS
                flo=F(lo)
        if np.any((flo*fhi>0.0)|(~np.isfinite(flo))|(~np.isfinite(fhi))):
            raise RuntimeError(f"DSE2P failed to bracket {int(np.count_nonzero(flo*fhi>0.0))} cases")
        # Keep orientation explicit: increasing branch flo>0,fhi<0; decreasing flo<0,fhi>0.
        for _ in range(80):
            md=0.5*(lo+hi);fm=F(md)
            if increasing:
                take_lo=fm>0.0
            else:
                take_lo=fm<0.0
            lo=np.where(take_lo,md,lo)
            flo=np.where(take_lo,fm,flo)
            hi=np.where(take_lo,hi,md)
            fhi=np.where(take_lo,fhi,fm)
            if np.max(hi-lo)<=1e-11:break
        qq=0.5*(lo+hi);fr=F(qq)
        q[mask]=qq;resid[mask]=fr

    solve((~equal)&(delta>0.0),True)
    solve((~equal)&(delta<0.0),False)
    return q,resid

def dse_flux(psi_u,psi_d,L):
    q64,r64=dse_root_order(psi_u,psi_d,L,64)
    q128,r128=dse_root_order(psi_u,psi_d,L,128)
    gate=np.maximum(1e-8,1e-7*np.maximum(1.0,np.abs(q128)))
    ok=(np.abs(q64-q128)<=gate)&(np.abs(r128)<=1e-8)&np.isfinite(q128)
    return q128,{
      "all_qualified":bool(np.all(ok)),
      "failed_count":int(np.count_nonzero(~ok)),
      "max_abs_q64_minus_q128_cm_per_day":float(np.max(np.abs(q64-q128))),
      "max_abs_length_residual_cm":float(np.max(np.abs(r128))),
    }

def parse_instrumented(path):
    layers={};faces={}
    state_lines=[];profile_lines=[]
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"): state_lines.append(line)
        elif line.startswith("LAREGW1_PROFILE|"): profile_lines.append(line)
        elif line.startswith("LAREGW1_C5T_LAYER|"):
            r=fields(line.split("|",1)[1]); key=(r["HISTORY"],int(r["OBS_STEP"]),int(r["LAYER"]))
            layers[key]=float(r["STORAGE_CM"])
        elif line.startswith("LAREGW1_C5T_FACE|"):
            r=fields(line.split("|",1)[1]); key=(r["HISTORY"],int(r["OBS_STEP"]),float(r["DEPTH_CM"]))
            faces[key]={k:float(r[k]) for k in ("H_UP","H_DOWN","THETA_UP","THETA_DOWN")}
    return layers,faces,state_lines,profile_lines

def extract_baseline(path):
    state=[];prof=[]
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):state.append(line)
        elif line.startswith("LAREGW1_PROFILE|"):prof.append(line)
    return state,prof

def summarize_errors(err,ref,cand):
    e=np.asarray(err);r=np.asarray(ref);c=np.asarray(cand)
    out=qstats(e)
    out["sign_mismatch_count"]=int(np.count_nonzero(np.sign(c)!=np.sign(r)))
    return out

def mean_abs_group_bias(records,operator,selector):
    vals=[]
    for h in HISTS:
      for dep in DEPTHS:
        subset=[x for x in records if x["history"]==h and x["depth"]==float(dep) and selector(x)]
        if subset:
          vals.append(abs(float(np.mean([x[f"e_{operator}"] for x in subset]))))
    return float(np.mean(vals)) if vals else 0.0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--instrumented",required=True,type=pathlib.Path)
    ap.add_argument("--c5r-baseline",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c5s",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text());s=json.loads(a.c5s.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5T_INSTRUMENTED_RESPONSE_OR_OPERATOR_METRICS"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    assert s["decision"]=="PREREGISTER_FROZEN_STATE_DARCIAN_TWO_POINT_INTERFACE_FLUX_DISCRIMINATOR_BEFORE_FREE_RUNNING_IMPLEMENTATION"

    layers,faces,st,pr=parse_instrumented(a.instrumented)
    bst,bpr=extract_baseline(a.c5r_baseline)
    identity={"state_lines":st==bst,"profile_lines":pr==bpr,
              "state_count":len(st),"profile_count":len(pr)}
    if not(identity["state_lines"] and identity["profile_lines"]):
        raise RuntimeError("C5T instrumentation changed authoritative C5R state/profile trajectory")
    if len(layers)!=4*1024*12 or len(faces)!=4*1024*11:
        raise RuntimeError(f"C5T diagnostic counts wrong layers={len(layers)} faces={len(faces)}")

    records=[];numerics=[]
    for iface,dep in enumerate(DEPTHS):
        iu=iface;idn=iface+1
        di=float(WIDTHS[iu]);dj=float(WIDTHS[idn]);L=0.5*(di+dj)
        psiu=[];psid=[];meta=[];qref=[];qbase=[]
        for h in HISTS:
          for obs in range(1,1025):
            su=layers[(h,obs,iu+1)];sd=layers[(h,obs,idn+1)]
            tu=su/di;td=sd/dj
            pu=float(theta_to_psi([tu])[0]);pd=float(theta_to_psi([td])[0])
            ku=float(k_from_theta([tu])[0]);kd=float(k_from_theta([td])[0])
            kb=(dj*ku+di*kd)/(di+dj)
            qb=kb*(1.0+(pd-pu)/L)
            fr=faces[(h,obs,float(dep))]
            kfu=float(k_from_theta([fr["THETA_UP"]])[0]);kfd=float(k_from_theta([fr["THETA_DOWN"]])[0])
            qr=0.5*(kfu+kfd)*(1.0+(fr["H_UP"]-fr["H_DOWN"])/DZ_FINE)
            psiu.append(pu);psid.append(pd);meta.append((h,obs,phase(h,obs)));qref.append(qr);qbase.append(qb)
        try:
            qdse,num=dse_flux(np.asarray(psiu),np.asarray(psid),L)
        except RuntimeError as exc:
            numerical_failure={
              "depth_cm":float(dep),
              "failure_class":"DSE2P_BRACKET_OR_NUMERICAL_QUALIFICATION_FAILURE",
              "message":str(exc)
            }
            numerics.append({
              "depth_cm":float(dep),
              "all_qualified":False,
              "failure_class":numerical_failure["failure_class"],
              "message":numerical_failure["message"]
            })
            break
        num["depth_cm"]=float(dep);numerics.append(num)
        for idx,(h,obs,ph) in enumerate(meta):
            records.append({
              "history":h,"obs":obs,"phase":ph,"depth":float(dep),
              "q_ref":float(qref[idx]),"q_current":float(qbase[idx]),"q_dse2p":float(qdse[idx]),
              "e_current":float(qbase[idx]-qref[idx]),"e_dse2p":float(qdse[idx]-qref[idx])
            })
    else:
        numerical_failure=None

    numerical_ok=numerical_failure is None and all(x["all_qualified"] for x in numerics)

    if not numerical_ok:
        out={
          "schema":"swap5.lare.bc2.c5t.result.v1",
          "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5T",
          "status":"C5T_DSE2P_NOT_SUPPORTED_NUMERICAL_QUALIFICATION_FAILED",
          "role":"EXPOSED_FROZEN_STATE_MECHANISM_DIAGNOSTIC",
          "instrumentation_identity":identity,
          "numerical_qualification":{
            "pass":False,
            "by_interface":numerics,
            "failure":numerical_failure
          },
          "primary_interfaces_cm":sorted(PRIMARY),
          "primary":{},
          "per_interface_phase":{},
          "all_interface_secondary":{},
          "adjudication":{
            "DSE2P_PRIMARY_MOVING_COMPONENTWISE_NO_WORSE":False,
            "DSE2P_EACH_PRIMARY_MOVING_RMSE_NO_WORSE":False,
            "DSE2P_PRIMARY_MOVING_RMSE_STRICTLY_IMPROVED":False,
            "DSE2P_HOLD_GUARD_PASS":False,
            "DSE2P_NUMERICAL_QUALIFICATION_PASS":False,
            "DSE2P_SUPPORTED_FOR_FREE_RUNNING_TEST":False
          },
          "interpretation_boundaries":[
            "The preregistered DSE2P numerical method failed its all-points qualification gate before operator metrics could be fully adjudicated.",
            "No quadrature order, physical branch, bracket rule, root tolerance or residual tolerance is changed after response.",
            "This outcome does not authorize a free-running DSE2P implementation or any scalar/branch retuning.",
            "The R01-R04 workload was exposed in C5R; C5T is mechanism evidence and cannot count as blind validation."
          ],
          "scientific_firewall":{
            "blind_validation":False,
            "candidate_feedback":False,
            "production_reference_changed":False,
            "free_running_closure_implemented":False,
            "scalar_tuning_reopened":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "speed_claim_authorized":False,
            "production_rom_authorized":False
          }
        }
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({
          "status":out["status"],
          "identity":identity,
          "numerical_qualification":out["numerical_qualification"],
          "adjudication":out["adjudication"]
        },sort_keys=True))
        return

    per={}
    for dep in DEPTHS:
      per[str(float(dep))]={}
      for ph in ("PHASE1","PHASE2","HOLD","MOVING"):
        sel=[x for x in records if x["depth"]==float(dep) and ((x["phase"] in ("PHASE1","PHASE2")) if ph=="MOVING" else x["phase"]==ph)]
        per[str(float(dep))][ph]={
          "CURRENT_LAYER_FACE":summarize_errors([x["e_current"] for x in sel],[x["q_ref"] for x in sel],[x["q_current"] for x in sel]),
          "DSE2P":summarize_errors([x["e_dse2p"] for x in sel],[x["q_ref"] for x in sel],[x["q_dse2p"] for x in sel])
        }

    def select_primary(x,moving):
        return x["depth"] in PRIMARY and ((x["phase"] in ("PHASE1","PHASE2")) if moving else x["phase"]=="HOLD")
    mov=[x for x in records if select_primary(x,True)]
    hold=[x for x in records if select_primary(x,False)]
    primary={
      "moving":{
        "CURRENT_LAYER_FACE":summarize_errors([x["e_current"] for x in mov],[x["q_ref"] for x in mov],[x["q_current"] for x in mov]),
        "DSE2P":summarize_errors([x["e_dse2p"] for x in mov],[x["q_ref"] for x in mov],[x["q_dse2p"] for x in mov])
      },
      "hold":{
        "CURRENT_LAYER_FACE":summarize_errors([x["e_current"] for x in hold],[x["q_ref"] for x in hold],[x["q_current"] for x in hold]),
        "DSE2P":summarize_errors([x["e_dse2p"] for x in hold],[x["q_ref"] for x in hold],[x["q_dse2p"] for x in hold])
      }
    }
    primary["moving"]["CURRENT_LAYER_FACE"]["mean_abs_interface_history_signed_bias_cm_per_day"]=mean_abs_group_bias(records,"current",lambda x:x["depth"] in PRIMARY and x["phase"] in ("PHASE1","PHASE2"))
    primary["moving"]["DSE2P"]["mean_abs_interface_history_signed_bias_cm_per_day"]=mean_abs_group_bias(records,"dse2p",lambda x:x["depth"] in PRIMARY and x["phase"] in ("PHASE1","PHASE2"))

    b=primary["moving"]["CURRENT_LAYER_FACE"];d=primary["moving"]["DSE2P"]
    h0=primary["hold"]["CURRENT_LAYER_FACE"];h1=primary["hold"]["DSE2P"]
    componentwise=(d["rmse_cm_per_day"]<=b["rmse_cm_per_day"]+EQ and
                   d["mean_abs_interface_history_signed_bias_cm_per_day"]<=b["mean_abs_interface_history_signed_bias_cm_per_day"]+EQ and
                   d["sign_mismatch_count"]<=b["sign_mismatch_count"])
    interface_ok=all(per[str(dep)]["MOVING"]["DSE2P"]["rmse_cm_per_day"]<=per[str(dep)]["MOVING"]["CURRENT_LAYER_FACE"]["rmse_cm_per_day"]+EQ for dep in sorted(PRIMARY))
    strict=d["rmse_cm_per_day"]<b["rmse_cm_per_day"]-EQ
    hold_ok=(h1["sign_mismatch_count"]<=h0["sign_mismatch_count"] and h1["rmse_cm_per_day"]<=h0["rmse_cm_per_day"]+EQ)
    supported=numerical_ok and componentwise and interface_ok and strict and hold_ok
    any_worse=(not componentwise) or (not interface_ok) or (not hold_ok)
    if not numerical_ok:
        status="C5T_DSE2P_NOT_SUPPORTED_NUMERICAL_QUALIFICATION_FAILED"
    elif supported:
        status="C5T_DSE2P_SUPPORTED_FOR_FRESH_BLIND_FREE_RUNNING_TEST"
    elif any_worse and d["rmse_cm_per_day"]<b["rmse_cm_per_day"]:
        status="C5T_DSE2P_MIXED_NO_IMPLEMENTATION"
    else:
        status="C5T_DSE2P_NOT_SUPPORTED"

    allsel=records
    secondary={
      "CURRENT_LAYER_FACE":summarize_errors([x["e_current"] for x in allsel],[x["q_ref"] for x in allsel],[x["q_current"] for x in allsel]),
      "DSE2P":summarize_errors([x["e_dse2p"] for x in allsel],[x["q_ref"] for x in allsel],[x["q_dse2p"] for x in allsel])
    }

    out={
      "schema":"swap5.lare.bc2.c5t.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5T",
      "status":status,
      "role":"EXPOSED_FROZEN_STATE_MECHANISM_DIAGNOSTIC",
      "instrumentation_identity":identity,
      "numerical_qualification":{"pass":numerical_ok,"by_interface":numerics},
      "primary_interfaces_cm":sorted(PRIMARY),
      "primary":primary,
      "per_interface_phase":per,
      "all_interface_secondary":secondary,
      "adjudication":{
        "DSE2P_PRIMARY_MOVING_COMPONENTWISE_NO_WORSE":componentwise,
        "DSE2P_EACH_PRIMARY_MOVING_RMSE_NO_WORSE":interface_ok,
        "DSE2P_PRIMARY_MOVING_RMSE_STRICTLY_IMPROVED":strict,
        "DSE2P_HOLD_GUARD_PASS":hold_ok,
        "DSE2P_NUMERICAL_QUALIFICATION_PASS":numerical_ok,
        "DSE2P_SUPPORTED_FOR_FREE_RUNNING_TEST":supported
      },
      "interpretation_boundaries":[
        "The R01-R04 workload was exposed in C5R; C5T is mechanism evidence and cannot count as blind validation.",
        "Both candidate fluxes are evaluated on the exact same Reference-projected layer storages; neither flux feeds back into the trajectory.",
        "The fine Reference interface flux is reconstructed with the frozen swkmean=1 arithmetic conductivity mean and exact adjacent fine-node head gradient.",
        "A positive C5T only authorizes a separate fresh blind free-running test; it does not admit DSE2P for production or application acceptance.",
        "A mixed/negative result does not authorize coefficient fitting or direction-dependent switching."
      ],
      "scientific_firewall":{
        "blind_validation":False,
        "candidate_feedback":False,
        "production_reference_changed":False,
        "free_running_closure_implemented":False,
        "scalar_tuning_reopened":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "identity":identity,
      "numerical_pass":numerical_ok,
      "primary_moving":primary["moving"],
      "primary_hold":primary["hold"],
      "adjudication":out["adjudication"],
      "all_interface_secondary":secondary
    },sort_keys=True))

if __name__=="__main__":
    main()
