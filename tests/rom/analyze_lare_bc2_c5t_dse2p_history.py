#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib
import numpy as np

THETA_R=0.01
THETA_S=0.416774
ALPHA=0.00541
N_VG=1.301528
M_VG=1.0-1.0/N_VG
KS=0.895023
LAMBDA=-0.334926
WIDTHS=np.asarray([70,10,10,10,10,10,10,10,10,5,2.5,2.5],dtype=float)
FACE_DEPTHS=np.asarray([70,80,90,100,110,120,130,140,150,155,157.5],dtype=float)
OBS=1024
NF=11
NL=12
ROOT_Q_TOL=1.0e-10
ENDPOINT_TOL=1.0e-8
VERIFY_ABS=1.0e-8
VERIFY_REL=1.0e-7
INITIAL_BRACKET_MULT=4.0
SCAN_MULT=np.asarray([
 -64,-32,-16,-8,-4,-2,-1,-0.5,-0.25,-0.1,-0.05,-0.01,-0.001,-0.0001,-0.000001,
 0.0,
 0.000001,0.0001,0.001,0.01,0.05,0.1,0.25,0.5,1,2,4,8,16,32,64
],dtype=float)
DIVERGENCE_CAP=1.0e12
K_FLOOR=np.finfo(float).tiny

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out

def k_suction(psi):
    x=np.asarray(psi,dtype=float)
    out=np.full_like(x,KS)
    mask=x>0.0
    if np.any(mask):
        p=np.minimum(x[mask],DIVERGENCE_CAP)
        se=np.power(1.0+np.power(ALPHA*p,N_VG),-M_VG)
        term=1.0-np.power(1.0-np.power(se,1.0/M_VG),M_VG)
        kval=KS*np.power(se,LAMBDA)*np.square(term)
        out[mask]=np.maximum(kval,K_FLOOR)
    return out

def k_pressure_head(h):
    h=np.asarray(h,dtype=float)
    return k_suction(np.maximum(-h,0.0))

def psi_from_theta(theta):
    th=np.asarray(theta,dtype=float)
    se=(th-THETA_R)/(THETA_S-THETA_R)
    ok=np.isfinite(se)&(se>0.0)&(se<1.0)
    psi=np.full_like(se,np.nan)
    if np.any(ok):
        psi[ok]=np.power(np.power(se[ok],-1.0/M_VG)-1.0,1.0/N_VG)/ALPHA
    return psi,ok&(psi>0.01)&np.isfinite(psi)

def integrate_endpoint(q,psi0,L,nsub):
    q=np.asarray(q,dtype=float)
    y=np.asarray(psi0,dtype=float).copy()
    ds=np.asarray(L,dtype=float)/float(nsub)
    def f(v):
        return q/k_suction(v)-1.0
    with np.errstate(over="ignore",invalid="ignore",divide="ignore",under="ignore"):
        for _ in range(nsub):
            k1=f(y)
            k2=f(y+0.5*ds*k1)
            k3=f(y+0.5*ds*k2)
            k4=f(y+ds*k3)
            y=y+(ds/6.0)*(k1+2.0*k2+2.0*k3+k4)
            y=np.nan_to_num(y,nan=DIVERGENCE_CAP,posinf=DIVERGENCE_CAP,neginf=-DIVERGENCE_CAP)
            y=np.clip(y,-DIVERGENCE_CAP,DIVERGENCE_CAP)
    return y

def residual(q,psi0,psi1,L,nsub):
    return integrate_endpoint(q,psi0,L,nsub)-psi1

def bracket(psi0,psi1,L,nsub):
    n=len(psi0)
    qlo=np.full(n,-INITIAL_BRACKET_MULT*KS)
    qhi=np.full(n, INITIAL_BRACKET_MULT*KS)
    flo=residual(qlo,psi0,psi1,L,nsub)
    fhi=residual(qhi,psi0,psi1,L,nsub)
    ok=np.isfinite(flo)&np.isfinite(fhi)&((flo==0.0)|(fhi==0.0)|(np.signbit(flo)!=np.signbit(fhi)))
    used_scan=np.zeros(n,dtype=bool)
    if np.all(ok):
        return qlo,qhi,flo,fhi,ok,used_scan

    idx=np.where(~ok)[0]
    prev_q=np.full(len(idx),SCAN_MULT[0]*KS)
    prev_f=residual(prev_q,psi0[idx],psi1[idx],L[idx],nsub)
    found=np.zeros(len(idx),dtype=bool)
    blo=np.zeros(len(idx));bhi=np.zeros(len(idx));bflo=np.zeros(len(idx));bfhi=np.zeros(len(idx))
    for mult in SCAN_MULT[1:]:
        q=np.full(len(idx),mult*KS)
        f=residual(q,psi0[idx],psi1[idx],L[idx],nsub)
        cross=(~found)&np.isfinite(prev_f)&np.isfinite(f)&((prev_f==0.0)|(f==0.0)|(np.signbit(prev_f)!=np.signbit(f)))
        if np.any(cross):
            blo[cross]=prev_q[cross];bhi[cross]=q[cross];bflo[cross]=prev_f[cross];bfhi[cross]=f[cross]
            found[cross]=True
        prev_q=q;prev_f=f
    if np.any(found):
        ii=idx[found]
        qlo[ii]=blo[found];qhi[ii]=bhi[found];flo[ii]=bflo[found];fhi[ii]=bfhi[found]
        ok[ii]=True;used_scan[ii]=True
    return qlo,qhi,flo,fhi,ok,used_scan

def solve_dse(psi0,psi1,L,nsub):
    qlo,qhi,flo,fhi,ok,used_scan=bracket(psi0,psi1,L,nsub)
    q=np.full(len(psi0),np.nan)
    endpoint=np.full(len(psi0),np.nan)
    if not np.all(ok):
        return q,endpoint,ok,used_scan,0
    for iteration in range(1,48):
        mid=0.5*(qlo+qhi)
        fm=residual(mid,psi0,psi1,L,nsub)
        left=(flo==0.0)|(fm==0.0)|(np.signbit(flo)!=np.signbit(fm))
        qhi=np.where(left,mid,qhi)
        fhi=np.where(left,fm,fhi)
        qlo=np.where(left,qlo,mid)
        flo=np.where(left,flo,fm)
        if float(np.max(qhi-qlo))<=2.0*ROOT_Q_TOL:
            break
    q=0.5*(qlo+qhi)
    endpoint=np.abs(residual(q,psi0,psi1,L,nsub))
    ok=ok&np.isfinite(q)&np.isfinite(endpoint)&(endpoint<=ENDPOINT_TOL)&((qhi-qlo)<=2.0*ROOT_Q_TOL)
    return q,endpoint,ok,used_scan,iteration

def parse(path:pathlib.Path,history:str):
    layers={}
    faces={}
    state_symbols={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            if r.get("HISTORY")==history:
                step=int(r["STEP"])
                if step%16==0:
                    state_symbols[step//16]=r["SYMBOL"]
        elif line.startswith("LAREGW1_C5T_LAYER|"):
            r=fields(line.split("|",1)[1])
            if r.get("HISTORY")==history:
                layers[(int(r["OBS_STEP"]),int(r["LAYER"]))]=float(r["STORAGE"])
        elif line.startswith("LAREGW1_C5T_FACE|"):
            r=fields(line.split("|",1)[1])
            if r.get("HISTORY")==history:
                faces[(int(r["OBS_STEP"]),int(r["FACE"]))]={
                  "symbol":r["SYMBOL"],
                  "depth":float(r["DEPTH"]),
                  "h_up":float(r["H_UP"]),"h_dn":float(r["H_DN"]),
                  "theta_up":float(r["THETA_UP"]),"theta_dn":float(r["THETA_DN"])
                }
    if len(layers)!=OBS*NL or len(faces)!=OBS*NF or len(state_symbols)!=OBS:
        raise RuntimeError(f"incomplete C5T diagnostics layers={len(layers)} faces={len(faces)} states={len(state_symbols)}")
    storage=np.empty((OBS,NL),float)
    hup=np.empty((OBS,NF),float);hdn=np.empty((OBS,NF),float)
    phases=[]
    for obs in range(1,OBS+1):
        phases.append(state_symbols[obs])
        for layer in range(1,NL+1):
            storage[obs-1,layer-1]=layers[(obs,layer)]
        for face in range(1,NF+1):
            row=faces[(obs,face)]
            if row["symbol"]!=state_symbols[obs] or abs(row["depth"]-FACE_DEPTHS[face-1])>1e-12:
                raise RuntimeError("C5T face metadata mismatch")
            hup[obs-1,face-1]=row["h_up"];hdn[obs-1,face-1]=row["h_dn"]
    return storage,hup,hdn,phases

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--instrumented-log",required=True,type=pathlib.Path)
    ap.add_argument("--history",required=True,choices=("R01","R02","R03","R04"))
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_C5T_INSTRUMENTED_RESPONSE_OR_OPERATOR_METRICS"
    assert pre["operators"]["DSE2P"]["free_parameters"]==0
    assert pre["workload"]["solver_feedback_from_candidate"] is False

    storage,hup,hdn,phases=parse(a.instrumented_log,a.history)
    theta=storage/WIDTHS[None,:]
    psi,endpoint_ok=psi_from_theta(theta)
    physical_endpoints=bool(np.all(endpoint_ok))

    kup=k_pressure_head(hup);kdn=k_pressure_head(hdn)
    qref=0.5*(kup+kdn)*(1.0+(hup-hdn)/0.078125)

    psi_up=psi[:,:-1];psi_dn=psi[:,1:]
    k_up=k_suction(psi_up);k_dn=k_suction(psi_dn)
    di=WIDTHS[:-1][None,:];dj=WIDTHS[1:][None,:]
    L=0.5*(di+dj)
    kij=(dj*k_up+di*k_dn)/(di+dj)
    qcurrent=kij*(1.0+(psi_dn-psi_up)/L)

    flat0=psi_up.reshape(-1);flat1=psi_dn.reshape(-1)
    flatL=np.broadcast_to(L,(OBS,NF)).reshape(-1)
    numerical={}
    q128=np.full_like(flat0,np.nan);q256=np.full_like(flat0,np.nan)
    qualified=False
    if physical_endpoints:
        q128,e128,ok128,scan128,it128=solve_dse(flat0,flat1,flatL,128)
        q256,e256,ok256,scan256,it256=solve_dse(flat0,flat1,flatL,256)
        verify=np.abs(q128-q256)
        verify_tol=np.maximum(VERIFY_ABS,VERIFY_REL*np.maximum(1.0,np.abs(q128)))
        qualified=bool(np.all(ok128)&np.all(ok256)&np.all(np.isfinite(verify))&np.all(verify<=verify_tol))
        numerical={
          "physical_endpoints_qualified":physical_endpoints,
          "all_128_roots_qualified":bool(np.all(ok128)),
          "all_256_roots_qualified":bool(np.all(ok256)),
          "all_128_256_fluxes_agree":bool(np.all(np.isfinite(verify))&np.all(verify<=verify_tol)),
          "all_points_qualified":qualified,
          "point_count":int(len(flat0)),
          "scan_fallback_count_128":int(np.count_nonzero(scan128)),
          "scan_fallback_count_256":int(np.count_nonzero(scan256)),
          "bisection_iterations_128":int(it128),
          "bisection_iterations_256":int(it256),
          "max_endpoint_residual_cm_128":float(np.nanmax(e128)),
          "max_endpoint_residual_cm_256":float(np.nanmax(e256)),
          "max_abs_q128_minus_q256_cm_per_day":float(np.nanmax(verify)),
          "max_verification_tolerance_cm_per_day":float(np.nanmax(verify_tol)),
          "minimum_representative_suction_cm":float(np.nanmin(psi)),
          "maximum_representative_suction_cm":float(np.nanmax(psi))
        }
    else:
        numerical={
          "physical_endpoints_qualified":False,
          "all_points_qualified":False,
          "point_count":int(len(flat0)),
          "minimum_representative_suction_cm":None,
          "maximum_representative_suction_cm":None
        }

    qdse=q128.reshape(OBS,NF) if qualified else np.full((OBS,NF),np.nan)
    out={
      "schema":"swap5.lare.bc2.c5t.history-diagnostic.v1",
      "history":a.history,
      "status":"QUALIFIED" if qualified else "DSE2P_NUMERICAL_OR_PHYSICAL_BLOCKED",
      "phase_by_observation":phases,
      "face_depths_cm":FACE_DEPTHS.tolist(),
      "q_reference_cm_per_day":qref.tolist(),
      "q_current_layer_face_cm_per_day":qcurrent.tolist(),
      "q_dse2p_cm_per_day":qdse.tolist() if qualified else None,
      "numerical_qualification":numerical,
      "implementation":{
        "root_method":"bracketed bisection",
        "initial_bracket_cm_per_day":[-INITIAL_BRACKET_MULT*KS,INITIAL_BRACKET_MULT*KS],
        "fallback_scan_multipliers_of_Ksat":SCAN_MULT.tolist(),
        "primary_RK4_substeps":128,
        "verification_RK4_substeps":256,
        "root_absolute_flux_tolerance_cm_per_day":ROOT_Q_TOL,
        "endpoint_suction_tolerance_cm":ENDPOINT_TOL,
        "divergent_trial_suction_cap_cm":DIVERGENCE_CAP,
        "divergent_trial_cap_role":"Bracket-search numerical guard only; every accepted root must satisfy endpoint and 128/256 qualification."
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True,allow_nan=False)+"\n")
    print(json.dumps({"history":a.history,"status":out["status"],"numerical":numerical},sort_keys=True))

if __name__=="__main__":
    main()
