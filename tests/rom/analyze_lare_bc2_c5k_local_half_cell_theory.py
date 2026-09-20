#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib
import numpy as np

HISTS=("Z01","Z02","Z03","Z04")
FACTOR=16
BASE_DT=0.0008
STEP_DT=0.00005
BASE_STEPS=1024
HCRIT=-1.0e-2
TR=0.01
TS=0.416774
ALPHA=0.00541
N=1.301528
M=1.0-1.0/N
KS=0.895023
LAMBDA=-0.334926
C25=TS-TR
C26=TR+C25/((1.0+abs(ALPHA*HCRIT)**N)**M)
C27=(TS-C26)/(-HCRIT)

def fields(payload:str):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def phase_blocks(h):
    if h in ("Z01","Z02"):
        return ((1,256,"PHASE1"),(257,576,"PHASE2"),(577,1024,"HOLD"))
    return ((1,320,"PHASE1"),(321,576,"PHASE2"),(577,1024,"HOLD"))

def theta_b14(h):
    h=np.asarray(h,dtype=float)
    out=np.empty_like(h)
    sat=h>=0.0
    near=(h>HCRIT)&(~sat)
    far=~(sat|near)
    out[sat]=TS
    out[near]=np.minimum(TS,C26+C27*(h[near]-HCRIT))
    ah=np.abs(ALPHA*h[far])
    out[far]=TR+C25/(1.0+ah**N)**M
    return out

def k_b14(h):
    h=np.asarray(h,dtype=float)
    th=theta_b14(h)
    se=(th-TR)/C25
    out=np.empty_like(h)
    very=h < -1.0e14
    sat=h>=0.0
    almost=(se>(1.0-1.0e-6)) & (~sat) & (~very)
    normal=~(very|sat|almost)
    out[very]=1.0e-10
    out[sat]=KS
    out[almost]=KS
    x=np.clip(se[normal],1.0e-300,1.0)
    term=(1.0-x**(1.0/M))**M
    out[normal]=KS*(x**LAMBDA)*(1.0-term)**2
    out=np.minimum(out,KS)
    return out

def parse_instrumented(path:pathlib.Path):
    pre={}; post={}; state={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_C5K_PRE|"):
            r=fields(line.split("|",1)[1]); pre[(r["HISTORY"],int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_C5K_POST|"):
            r=fields(line.split("|",1)[1]); post[(r["HISTORY"],int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1]); state[(r["HISTORY"],int(r["STEP"]))]=r
    out={}
    expected=BASE_STEPS*FACTOR
    for h in HISTS:
        rows=[]
        for step in range(1,expected+1):
            key=(h,step)
            if key not in pre or key not in post or key not in state:
                raise RuntimeError(f"incomplete C5K instrumentation {path} {key}")
            a,b,s=pre[key],post[key],state[key]
            if a["SYMBOL"]!=b["SYMBOL"] or b["SYMBOL"]!=s["SYMBOL"]:
                raise RuntimeError(f"symbol mismatch {key}")
            if abs(float(b["BOTTOM_OUTWARD_EXCHANGE"])-float(s["BOTTOM_OUTWARD_EXCHANGE"]))>0.0:
                raise RuntimeError(f"post/state exchange mismatch {key}")
            if abs(float(b["BOTTOM_FLUX"])-float(s["BOTTOM_FLUX"]))>0.0:
                raise RuntimeError(f"post/state terminal flux mismatch {key}")
            rows.append((
              float(a["H_LAST"]),float(b["H_LAST"]),float(a["H_BOT"]),
              int(s["BOTTOM_MODE"]),float(s["BOTTOM_OUTWARD_EXCHANGE"]),
              float(s["BOTTOM_FLUX"])
            ))
        arr=np.asarray(rows,dtype=float)
        out[h]={
          "h_pre":arr[:,0],"h_post":arr[:,1],"hbot":arr[:,2],
          "mode":arr[:,3].astype(int),"exchange":arr[:,4],"terminal":arr[:,5]
        }
    return out

def integrated_k_mean(hc,hb,nq=24):
    hc=np.asarray(hc); hb=np.asarray(hb)
    out=np.empty_like(hc)
    same=np.abs(hb-hc)<=1.0e-13*np.maximum(1.0,np.maximum(np.abs(hc),np.abs(hb)))
    out[same]=k_b14(hc[same])
    idx=np.where(~same)[0]
    if idx.size:
        x,w=np.polynomial.legendre.leggauss(nq)
        a=hc[idx]; b=hb[idx]
        mid=0.5*(a+b); half=0.5*(b-a)
        heads=mid[:,None]+half[:,None]*x[None,:]
        integ=half*np.sum(w[None,:]*k_b14(heads),axis=1)
        out[idx]=integ/(b-a)
    return out

def exact_steady_half_cell(hc,hb,delta,nq=32,iters=70):
    hc=np.asarray(hc,dtype=float); hb=np.asarray(hb,dtype=float)
    delta=np.asarray(delta,dtype=float)
    q=np.empty_like(hc); resid=np.zeros_like(hc)
    scaleh=np.maximum(1.0,np.maximum(np.abs(hc),np.abs(hb)))
    same=np.abs(hb-hc)<=1.0e-13*scaleh
    q[same]=k_b14(hc[same])
    idx=np.where(~same)[0]
    if idx.size==0:return q,resid

    x,w=np.polynomial.legendre.leggauss(nq)
    a=np.minimum(hc[idx],hb[idx]); b=np.maximum(hc[idx],hb[idx])
    mid=0.5*(a+b); half=0.5*(b-a)
    heads=mid[:,None]+half[:,None]*x[None,:]
    kval=k_b14(heads)
    kend=np.column_stack((k_b14(a),k_b14(b)))
    kmin=np.minimum(np.min(kval,axis=1),np.min(kend,axis=1))
    kmax=np.maximum(np.max(kval,axis=1),np.max(kend,axis=1))
    d=delta[idx]
    inc=hb[idx]>hc[idx]

    def J(qv,incmask):
        if incmask:
            return half*np.sum(w[None,:]*kval/(kval-qv[:,None]),axis=1)
        return half*np.sum(w[None,:]*kval/(qv[:,None]-kval),axis=1)

    # hbot > hcell: Q < min(K), J increases with Q.
    ii=np.where(inc)[0]
    if ii.size:
        kmn=kmin[ii]; kmx=kmax[ii]; dd=d[ii]
        eps=np.maximum(1.0e-14,1.0e-12*np.maximum(1.0,kmn))
        hi=kmn-eps
        span=np.maximum(1.0,10.0*np.maximum(kmx,1.0e-12))
        lo=kmn-span
        def ji(v):
            return half[ii]*np.sum(w[None,:]*kval[ii]/(kval[ii]-v[:,None]),axis=1)
        flo=ji(lo)-dd
        for _ in range(24):
            bad=flo>=0.0
            if not np.any(bad):break
            span[bad]*=2.0; lo[bad]=kmn[bad]-span[bad]; flo[bad]=ji(lo)[bad]-dd[bad]
        fhi=ji(hi)-dd
        for _ in range(10):
            bad=fhi<=0.0
            if not np.any(bad):break
            eps[bad]*=0.01; hi[bad]=kmn[bad]-eps[bad]; fhi[bad]=ji(hi)[bad]-dd[bad]
        if np.any(flo>=0.0) or np.any(fhi<=0.0):
            raise RuntimeError("C5K steady lower-branch bracketing failure")
        for _ in range(iters):
            md=0.5*(lo+hi); fm=ji(md)-dd
            high=fm>0.0
            hi[high]=md[high]; lo[~high]=md[~high]
        qq=0.5*(lo+hi); rr=np.abs(ji(qq)-dd)
        q[idx[ii]]=qq; resid[idx[ii]]=rr

    # hbot < hcell: Q > max(K), J decreases with Q.
    ii=np.where(~inc)[0]
    if ii.size:
        kmn=kmin[ii]; kmx=kmax[ii]; dd=d[ii]
        eps=np.maximum(1.0e-14,1.0e-12*np.maximum(1.0,kmx))
        lo=kmx+eps
        span=np.maximum(1.0,10.0*np.maximum(kmx,1.0e-12))
        hi=kmx+span
        def jd(v):
            return half[ii]*np.sum(w[None,:]*kval[ii]/(v[:,None]-kval[ii]),axis=1)
        flo=jd(lo)-dd
        for _ in range(10):
            bad=flo<=0.0
            if not np.any(bad):break
            eps[bad]*=0.01; lo[bad]=kmx[bad]+eps[bad]; flo[bad]=jd(lo)[bad]-dd[bad]
        fhi=jd(hi)-dd
        for _ in range(24):
            bad=fhi>=0.0
            if not np.any(bad):break
            span[bad]*=2.0; hi[bad]=kmx[bad]+span[bad]; fhi[bad]=jd(hi)[bad]-dd[bad]
        if np.any(flo<=0.0) or np.any(fhi>=0.0):
            raise RuntimeError("C5K steady upper-branch bracketing failure")
        for _ in range(iters):
            md=0.5*(lo+hi); fm=jd(md)-dd
            high=fm>0.0
            lo[high]=md[high]; hi[~high]=md[~high]
        qq=0.5*(lo+hi); rr=np.abs(jd(qq)-dd)
        q[idx[ii]]=qq; resid[idx[ii]]=rr
    return q,resid

def aggregate(x):
    return np.asarray([np.mean(x[i*FACTOR:(i+1)*FACTOR]) for i in range(BASE_STEPS)])

def metrics_vector(v):
    x=np.concatenate([v[h] for h in HISTS])
    return {
      "signed_mean_cm_per_day":float(np.mean(x)),
      "rmse_cm_per_day":float(np.sqrt(np.mean(x*x))),
      "max_abs_cm_per_day":float(np.max(np.abs(x)))
    }

def gap_diag(r512,r1024):
    d={h:r512[h]-r1024[h] for h in HISTS}
    pooled=metrics_vector(d)
    by_history={}; by_phase={}
    for h in HISTS:
        xh=d[h]
        by_history[h]={
          "signed_mean_cm_per_day":float(np.mean(xh)),
          "rmse_cm_per_day":float(np.sqrt(np.mean(xh*xh))),
          "max_abs_cm_per_day":float(np.max(np.abs(xh)))
        }
        phases={}
        for lo,hi,label in phase_blocks(h):
            x=d[h][lo-1:hi]
            phases[label]={
              "signed_mean_cm_per_day":float(np.mean(x)),
              "rmse_cm_per_day":float(np.sqrt(np.mean(x*x))),
              "max_abs_cm_per_day":float(np.max(np.abs(x))),
              "step_start":lo,"step_end":hi
            }
        by_phase[h]=phases
    pooled["by_history"]=by_history; pooled["by_phase"]=by_phase
    return pooled,d

def dot(a,b):
    return float(sum(np.dot(a[h],b[h]) for h in HISTS))

def correction_diag(var_gap,current_gap):
    c={h:var_gap[h]-current_gap[h] for h in HISTS}
    m=metrics_vector(c)
    den=dot(current_gap,current_gap)
    m["projection_on_current_local_gap"]=None if den==0 else dot(c,current_gap)/den
    return m

def build_theory(route,dz,identity_tol,steady_tol):
    delta=0.5*dz
    out={k:{} for k in ("published","current_face","postK","arithmetic_pre","arithmetic_post","integrated","steady")}
    local_identity=[]
    terminal_identity=[]
    steady_residual=[]
    localization={"postK_minus_current":[],"arithmetic_pre_minus_current":[],
                  "arithmetic_post_minus_postK":[],"integrated_minus_postK":[],"steady_minus_postK":[]}
    for h in HISTS:
        r=route[h]
        mode=r["mode"]
        qpub=r["exchange"]/STEP_DT
        if np.max(np.abs(qpub-r["terminal"]))>1.0e-12:
            raise RuntimeError(f"{h}: exchange/terminal outward flux mismatch")
        qcur=qpub.copy(); qpost=qpub.copy(); qarpre=qpub.copy(); qarpost=qpub.copy()
        qint=qpub.copy(); qsteady=qpub.copy()
        active=np.where(mode==5)[0]
        if active.size:
            hp=r["h_pre"][active]; hc=r["h_post"][active]; hb=r["hbot"][active]
            grad=1.0+(hc-hb)/delta
            kp=k_b14(hp); kc=k_b14(hc); kb=k_b14(hb)
            qc=kp*grad
            qp=kc*grad
            qapre=0.5*(kp+kb)*grad
            qapost=0.5*(kc+kb)*grad
            ki=integrated_k_mean(hc,hb)
            qi=ki*grad
            qs,rr=exact_steady_half_cell(hc,hb,np.full_like(hc,delta))
            qcur[active]=qc; qpost[active]=qp; qarpre[active]=qapre; qarpost[active]=qapost
            qint[active]=qi; qsteady[active]=qs
            local_identity.extend((qc-qpub[active]).tolist())
            steady_residual.extend(rr.tolist())
            localization["postK_minus_current"].extend((qp-qc).tolist())
            localization["arithmetic_pre_minus_current"].extend((qapre-qc).tolist())
            localization["arithmetic_post_minus_postK"].extend((qapost-qp).tolist())
            localization["integrated_minus_postK"].extend((qi-qp).tolist())
            localization["steady_minus_postK"].extend((qs-qp).tolist())
        out["published"][h]=aggregate(qpub)
        out["current_face"][h]=aggregate(qcur)
        out["postK"][h]=aggregate(qpost)
        out["arithmetic_pre"][h]=aggregate(qarpre)
        out["arithmetic_post"][h]=aggregate(qarpost)
        out["integrated"][h]=aggregate(qint)
        out["steady"][h]=aggregate(qsteady)
        terminal_identity.extend((qpub-r["terminal"]).tolist())
    li=np.asarray(local_identity)
    sr=np.asarray(steady_residual)
    if li.size and np.max(np.abs(li))>identity_tol:
        raise RuntimeError(f"current local face versus published flux exceeds prebound residual identity gate: {np.max(np.abs(li))}")
    if sr.size and np.max(sr)>steady_tol:
        raise RuntimeError(f"steady half-cell root residual exceeds prebound gate: {np.max(sr)}")
    loc={k:{
      "signed_mean_cm_per_day":float(np.mean(v)),
      "rmse_cm_per_day":float(np.sqrt(np.mean(np.asarray(v)**2))),
      "max_abs_cm_per_day":float(np.max(np.abs(v)))
    } for k,v in localization.items()}
    return out,{
      "max_abs_current_face_minus_published_cm_per_day":float(np.max(np.abs(li))) if li.size else 0.0,
      "rms_current_face_minus_published_cm_per_day":float(np.sqrt(np.mean(li*li))) if li.size else 0.0,
      "max_abs_exchange_rate_minus_terminal_flux_cm_per_day":float(np.max(np.abs(terminal_identity))),
      "max_steady_distance_residual_cm":float(np.max(sr)) if sr.size else 0.0,
      "temporal_and_spatial_localization":loc
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r512",required=True,type=pathlib.Path)
    ap.add_argument("--r1024",required=True,type=pathlib.Path)
    ap.add_argument("--c5i-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5k-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.c5k_prereg.read_text())
    c5i=json.loads(a.c5i_result.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_BOTTOM_STATE_INSTRUMENTATION_RESPONSE"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    identity_tol=float(p["numerical_qualification"]["local_flux_reconstruction_tolerance_cm_per_day"])
    steady_tol=float(p["numerical_qualification"]["exact_steady_half_cell_distance_residual_cm"])

    raw512=parse_instrumented(a.r512); raw1024=parse_instrumented(a.r1024)
    th512,q512=build_theory(raw512,0.3125,identity_tol,steady_tol)
    th1024,q1024=build_theory(raw1024,0.15625,identity_tol,steady_tol)

    gaps={}; vectors={}
    for key in th512:
        gaps[key],vectors[key]=gap_diag(th512[key],th1024[key])
    frozen=float(c5i["spatial"]["T16"]["rmse_cm_per_day"])
    baseline_identity=abs(gaps["published"]["rmse_cm_per_day"]-frozen)<=1e-15
    if not baseline_identity:
        raise RuntimeError("C5K published baseline does not reproduce C5I T16")

    corrections={key:correction_diag(vectors[key],vectors["current_face"])
                 for key in ("postK","arithmetic_pre","arithmetic_post","integrated","steady")}
    ratios={key:gaps[key]["rmse_cm_per_day"]/gaps["current_face"]["rmse_cm_per_day"]
            for key in ("published","postK","arithmetic_pre","arithmetic_post","integrated","steady")}

    lag=max(q512["temporal_and_spatial_localization"]["postK_minus_current"]["rmse_cm_per_day"],
            q1024["temporal_and_spatial_localization"]["postK_minus_current"]["rmse_cm_per_day"])
    spatial=max(q512["temporal_and_spatial_localization"]["integrated_minus_postK"]["rmse_cm_per_day"],
                q1024["temporal_and_spatial_localization"]["integrated_minus_postK"]["rmse_cm_per_day"])
    if spatial>0 and lag < 0.1*spatial:
        lag_descriptor="PRE_STEP_K_LAG_SMALL_RELATIVE_TO_SPATIAL_CORRECTION"
    else:
        lag_descriptor="PRE_STEP_K_LAG_NONNEGLIGIBLE"

    current_gap=gaps["current_face"]["rmse_cm_per_day"]
    steady_gap=gaps["steady"]["rmse_cm_per_day"]
    if steady_gap<current_gap:
        steady_direction="LOCAL_STEADY_THEORY_REDUCES_FROZEN_STATE_GRID_GAP"
    elif steady_gap>current_gap:
        steady_direction="LOCAL_STEADY_THEORY_INCREASES_FROZEN_STATE_GRID_GAP"
    else:
        steady_direction="LOCAL_STEADY_THEORY_LEAVES_FROZEN_STATE_GRID_GAP_UNCHANGED"

    out={
      "schema":"swap5.lare.bc2.c5k.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5K",
      "role":"LOCAL_NONLINEAR_HALF_CELL_THEORY_ON_FROZEN_REFERENCE_TRAJECTORIES",
      "status":"C5K_LOCAL_HALF_CELL_THEORY_CHARACTERIZED",
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "published_baseline_identity_to_C5I_T16":baseline_identity,
      "grid_gap_diagnostics":gaps,
      "grid_gap_rmse_ratio_to_current_local_face":ratios,
      "corrections_to_current_local_face_grid_gap":corrections,
      "R512_local_operator_consistency":q512,
      "R1024_local_operator_consistency":q1024,
      "descriptors":{
        "pre_step_K_lag":lag_descriptor,
        "local_steady_grid_direction":steady_direction
      },
      "interpretation_boundaries":[
        "All alternative flux series are postprocessed on the exact frozen current-Reference state trajectory; none feeds back into the state.",
        "Published qbot is the adapter's mass-balance materialization and is distinct from the local face term by the accepted summed equation residual.",
        "Q_exact_steady is a local steady half-cell boundary-value diagnostic and does not assert that the dynamically evolving half-cell is steady.",
        "A smaller frozen-state inter-grid gap is diagnostic only and cannot establish continuum truth or justify production admission.",
        "Any dynamic test of a theory-derived operator requires a fresh preregistration."
      ],
      "scientific_firewall":{
        "production_reference_changed":False,
        "new_reference_physics_admitted":False,
        "dynamic_reference_counterfactual_executed":False,
        "new_lare_run":False,
        "new_lare_closure":False,
        "C5A_formal_decision_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":out["status"],
      "published_gap":gaps["published"]["rmse_cm_per_day"],
      "current_local_gap":gaps["current_face"]["rmse_cm_per_day"],
      "postK_gap":gaps["postK"]["rmse_cm_per_day"],
      "arithmetic_pre_gap":gaps["arithmetic_pre"]["rmse_cm_per_day"],
      "arithmetic_post_gap":gaps["arithmetic_post"]["rmse_cm_per_day"],
      "integrated_gap":gaps["integrated"]["rmse_cm_per_day"],
      "steady_gap":gaps["steady"]["rmse_cm_per_day"],
      "ratios":ratios,
      "correction_projection":{k:v["projection_on_current_local_gap"] for k,v in corrections.items()},
      "R512_consistency":q512,
      "R1024_consistency":q1024,
      "descriptors":out["descriptors"]
    },sort_keys=True))

if __name__=="__main__":
    main()
