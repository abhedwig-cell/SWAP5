#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

b9=load_module("bc2b9_c4l","analyze_lare_bc2_b9_internal_flux.py")
b8=b9.b8
b7=b9.b5
b3=b9.b3

GL={64:np.polynomial.legendre.leggauss(64),128:np.polynomial.legendre.leggauss(128)}
ROOT_GATE=1.0e-10
PSI_TOL=1.0e-10
UNIQ=1.0e-8
QX=1.0e-8
QH_ID=1.0e-12
QI_ID=1.0e-10
HYD=1.0e-9
NQS=(64,128)
CMP=1.0e-12

def psi(x,a,u,v,L):
    x=np.asarray(x,dtype=float)
    return a*x+u*x*x/L+v*x*x*x/(L*L)

def min_psi(a,u,v,L):
    pts=[0.0,L]
    # dpsi/dx = a + 2u x/L + 3v x^2/L^2
    A=3.0*v/(L*L); B=2.0*u/L; C=a
    if abs(A)<1e-30:
        if abs(B)>1e-30:
            r=-C/B
            if 0.0<r<L: pts.append(r)
    else:
        disc=B*B-4.0*A*C
        if disc>=0.0:
            s=math.sqrt(disc)
            for r in ((-B-s)/(2.0*A),(-B+s)/(2.0*A)):
                if 0.0<r<L: pts.append(r)
    return float(min(psi(np.asarray(pts),a,u,v,L)))

def integ(a,u,v,L,x0,x1,nq):
    xg,wg=GL[nq]
    half=0.5*(x1-x0)
    xx=x0+half*(xg+1.0)
    pp=psi(xx,a,u,v,L)
    if np.min(pp)<-PSI_TOL:
        raise ValueError("cubic profile enters positive-pressure domain")
    th=b3.theta_from_psi(np.maximum(pp,0.0))
    return float(half*np.sum(wg*th))

def residual(z,a,Wt,Wb,L,d,nq):
    u,v=map(float,z)
    mn=min_psi(a,u,v,L)
    if mn<-PSI_TOL:
        bad=abs(mn)
        return np.asarray([1.0+1e3*bad,1.0+1e3*bad])
    try:
        return np.asarray([integ(a,u,v,L,0.0,d,nq)-Wt,integ(a,u,v,L,d,L,nq)-Wb])
    except ValueError:
        return np.asarray([1e6,1e6])

def close_uv(p,q):
    return all(abs(float(x)-float(y))<=UNIQ*(1.0+max(abs(float(x)),abs(float(y)))) for x,y in zip(p,q))

def starts(a,b_bulk,L,d):
    u2=(b_bulk-a)*L/(2.0*d)
    delta=a-b_bulk
    u3=delta*L/d
    v3=-delta*L*L/(d*d)
    return [
        np.asarray([0.0,0.0]),
        np.asarray([u2,0.0]),
        np.asarray([u3,v3]),
        0.5*np.asarray([u3,v3]),
    ]

def solve_endpoint(profile,total,d,nq):
    p=b8.projected(profile,total,d)
    H=float(p["H"]); L=H-b3.ANCHOR; B=L-d
    base=b9.endpoint_candidates(profile,total,d)
    a=float(base["a_t"]); bb=float(base["b_bulk"])
    roots=[]; diag=[]
    for idx,st in enumerate(starts(a,bb,L,d)):
        sol=least_squares(residual,st,args=(a,float(p["Wt64"]),float(p["Wb64"]),L,d,nq),
                          xtol=1e-13,ftol=1e-13,gtol=1e-13,max_nfev=400)
        u,v=map(float,sol.x)
        rr=residual(sol.x,a,float(p["Wt64"]),float(p["Wb64"]),L,d,nq)
        rmax=float(np.max(np.abs(rr)))
        mn=min_psi(a,u,v,L)
        valid=bool(sol.success and rmax<=ROOT_GATE and mn>=-PSI_TOL and math.isfinite(u) and math.isfinite(v))
        row={"start_index":idx,"valid":valid,"success":bool(sol.success),"u":u,"v":v,
             "max_storage_residual_cm":rmax,"minimum_psi_cm":mn,"nfev":int(sol.nfev)}
        diag.append(row)
        if valid: roots.append((u,v))
    if len(roots)<2:
        raise ValueError(f"insufficient valid cubic roots nq={nq} valid={len(roots)}")
    if not all(close_uv(roots[0],r) for r in roots[1:]):
        raise ValueError(f"AMBIGUOUS_CUBIC_RECONSTRUCTION nq={nq}")
    u=float(np.mean([r[0] for r in roots])); v=float(np.mean([r[1] for r in roots]))
    rr=residual(np.asarray([u,v]),a,float(p["Wt64"]),float(p["Wb64"]),L,d,nq)
    rmax=float(np.max(np.abs(rr))); mn=min_psi(a,u,v,L)
    if rmax>ROOT_GATE or mn<-PSI_TOL: raise ValueError("reconciled cubic failed hard gate")
    psi_i=float(psi(d,a,u,v,L))
    theta_i=float(b3.theta_from_psi(psi_i))
    _,kk=b3.psi_k(np.asarray([theta_i]))
    Ki=float(kk[0])
    slope_i=a+2.0*u*d/L+3.0*v*d*d/(L*L)
    return {
        "H":H,"L":L,"B":B,"a":a,"u":u,"v":v,"psi_i":psi_i,"theta_i":theta_i,"Ki":Ki,
        "slope_i":slope_i,"qi":Ki*(1.0-slope_i),"qH":b3.KS*(1.0-a),
        "max_storage_residual_cm":rmax,"minimum_psi_cm":mn,"valid_root_count":len(roots),
        "base_qi":float(base["TERMINAL_SIDE_LINEAR"]),"base_qH":b3.KS*(1.0-a),
        "diagnostics":diag
    }

def metrics(rows,key,ref):
    r=np.asarray([x[ref] for x in rows]); p=np.asarray([x[key] for x in rows]); e=p-r
    corr=float(np.corrcoef(r,p)[0,1]) if np.std(r)>0 and np.std(p)>0 else None
    return {"count":len(rows),"bias":float(np.mean(e)),"mae":float(np.mean(np.abs(e))),
            "rms":float(np.sqrt(np.mean(e*e))),"max_abs":float(np.max(np.abs(e))),
            "sign_mismatch":int(np.count_nonzero(np.sign(r)!=np.sign(p))),"corr":corr}

def better(c,b):
    return c["rms"]<b["rms"]-CMP and c["mae"]<b["mae"]-CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def noninferior(c,b):
    return c["rms"]<=b["rms"]+CMP and c["mae"]<=b["mae"]+CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b7-result",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text()); c4k=json.loads(args.c4k_closeout.read_text()); c4h=json.loads(args.c4h_closeout.read_text())
    r7=json.loads(args.b7_result.read_text()); r8=json.loads(args.b8_result.read_text()); r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4K_BEFORE_QH_PRESERVING_CUBIC_RECONSTRUCTION"
    assert pre["pre_execution_solver_clarification"]["before_first_C4L_execution"] is True
    assert c4k["status"]==pre["predecessors"]["C4K"]["required_status"]
    assert c4h["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert r7["decision"]==pre["predecessors"]["B7"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    if args.width not in (2.5,5.0) or args.history not in ("WT_HOLD","WT_RISE","WT_FALL"): raise SystemExit("unauthorized case")

    im,inodes,states,nodes=b3.load_reference(args.reference)
    fail=[]; rows=[]; max_store=0.0; max_qx=0.0; max_qh_id=0.0; max_qi_id=0.0; minpsi=float("inf"); minroots=99

    try:
        e0={n:solve_endpoint(inodes[args.history],im[args.history]["total"],args.width,n) for n in NQS}
    except Exception as exc:
        fail.append({"step":0,"error":str(exc)}); e0=None

    if e0 is not None:
        for step in range(1,b3.HISTORY_STEPS[args.history]+1):
            try:
                e1={n:solve_endpoint(nodes[(args.history,step)],states[(args.history,step)]["total"],args.width,n) for n in NQS}
            except Exception as exc:
                fail.append({"step":step,"error":str(exc)}); break
            p0=b8.projected(inodes[args.history] if step==1 else nodes[(args.history,step-1)],
                            im[args.history]["total"] if step==1 else states[(args.history,step-1)]["total"],args.width)
            p1=b8.projected(nodes[(args.history,step)],states[(args.history,step)]["total"],args.width)
            qH_ref=states[(args.history,step)]["bottom_exchange"]/b3.OBS_DT
            q90=-(p1["Wfixed"]-p0["Wfixed"])/b3.OBS_DT
            Hdot=(p1["H"]-p0["H"])/b3.OBS_DT
            Gi=0.5*(p0["theta_i"]+p1["theta_i"])*Hdot
            dWb=(p1["Wb64"]-p0["Wb64"])/b3.OBS_DT
            dWt=(p1["Wt64"]-p0["Wt64"])/b3.OBS_DT
            qi_b=q90+Gi-dWb; qi_t=dWt+qH_ref-b3.THETA_S*Hdot+Gi
            max_qi_id=max(max_qi_id,abs(qi_b-qi_t)); qi_ref=0.5*(qi_b+qi_t)

            base_qi=0.5*(e0[64]["base_qi"]+e1[64]["base_qi"])
            cand_qi=0.5*(e0[64]["qi"]+e1[64]["qi"])
            cand_qi_x=0.5*(e0[128]["qi"]+e1[128]["qi"])
            base_qH=0.5*(e0[64]["base_qH"]+e1[64]["base_qH"])
            cand_qH=0.5*(e0[64]["qH"]+e1[64]["qH"])
            max_qx=max(max_qx,abs(cand_qi-cand_qi_x)); max_qh_id=max(max_qh_id,abs(cand_qH-base_qH))
            for ep in (e0[64],e0[128],e1[64],e1[128]):
                max_store=max(max_store,ep["max_storage_residual_cm"]); minpsi=min(minpsi,ep["minimum_psi_cm"]); minroots=min(minroots,ep["valid_root_count"])
            rows.append({"step":step,"qi_ref":qi_ref,"qH_ref":qH_ref,"BASE_qi":base_qi,"CUBIC_qi":cand_qi,"BASE_qH":base_qH,"CUBIC_qH":cand_qH,
                         "u":0.5*(e0[64]["u"]+e1[64]["u"]),"v":0.5*(e0[64]["v"]+e1[64]["v"])})
            e0=e1

    complete=(not fail and len(rows)==b3.HISTORY_STEPS[args.history])
    qi_base=metrics(rows,"BASE_qi","qi_ref") if rows else None
    qi_cub=metrics(rows,"CUBIC_qi","qi_ref") if rows else None
    qh_base=metrics(rows,"BASE_qH","qH_ref") if rows else None
    qh_cub=metrics(rows,"CUBIC_qH","qH_ref") if rows else None
    hard=complete and max_store<=ROOT_GATE and minpsi>=-PSI_TOL and minroots>=2 and max_qx<=QX and max_qh_id<=QH_ID and max_qi_id<=QI_ID

    if not hard:
        decision="C4L_CASE_BLOCKED"
    elif args.history=="WT_HOLD":
        decision="C4L_CASE_SUPPORTED" if noninferior(qi_cub,qi_base) else "C4L_CASE_NOT_SUPPORTED"
    else:
        decision="C4L_CASE_SUPPORTED" if better(qi_cub,qi_base) else "C4L_CASE_NOT_SUPPORTED"

    result={"schema":"swap5.lare.bc2.c4l.case-result.v1","work_unit":"LARE-BC2-C4L","width_cm":args.width,"history":args.history,
            "decision":decision,"complete":complete,"hard_checks":{"max_storage_residual_cm":max_store,"minimum_psi_cm":minpsi,
            "minimum_valid_roots":minroots,"max_qi_64_vs_128_cm_per_day":max_qx,"max_qH_candidate_vs_baseline_cm_per_day":max_qh_id,
            "max_B8_qi_identity_cm_per_day":max_qi_id,"failure_count":len(fail)},
            "qi":{"BASE":qi_base,"CUBIC":qi_cub},"qH":{"BASE":qh_base,"CUBIC":qh_cub},
            "shape":{"u_rms":float(np.sqrt(np.mean([r["u"]**2 for r in rows]))) if rows else None,
                     "v_rms":float(np.sqrt(np.mean([r["v"]**2 for r in rows]))) if rows else None},
            "failures":fail[:20],"propagated_dynamics_authorized":False,"production_rom_authorized":False}
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
