#!/usr/bin/env python3
from __future__ import annotations
import argparse,importlib.util,json,math,pathlib,sys
from typing import Any
import numpy as np
from scipy.integrate import solve_ivp

HISTS=("X01","X02","X03","X04")
DTL=(1e-4,5e-5,2.5e-5)
OBS_DT=0.001
STEPS=1024
BOUNDS=[float(x) for x in range(0,161,10)]


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod)
    return mod


def patch(c4v,mat,lams):
    c4v.TR=float(mat["theta_r"]);c4v.TS=float(mat["theta_s"])
    c4v.ALPHA=float(mat["alpha_per_cm"]);c4v.N=float(mat["n"])
    c4v.M=1.0-1.0/c4v.N;c4v.KS=float(mat["Ksat_cm_per_day"]);c4v.ELL=float(mat["lambda"])
    c4v.DTHETA=(c4v.TS-c4v.TR)/c4v.NBINS;c4v.THETA_I=c4v.TR+c4v.I*c4v.DTHETA
    c4v.HISTS={f"X{i:02d}":float(v) for i,v in enumerate(lams,1)}
    c4v.THETA=[c4v.TR+j*c4v.DTHETA for j in range(c4v.J0,c4v.J1+1)]
    c4v.PSI=[c4v.psi_scalar(t) for t in c4v.THETA]
    b=c4v.bc1
    b.THETA_R=c4v.TR;b.THETA_S=c4v.TS;b.ALPHA=c4v.ALPHA;b.N_VG=c4v.N
    b.M_VG=c4v.M;b.KS=c4v.KS;b.LAMBDA=c4v.ELL


def stats(xs):
    a=np.asarray(xs,dtype=float).reshape(-1)
    return {"count":int(a.size),"rms":float(np.sqrt(np.mean(a*a))),"max_abs":float(np.max(np.abs(a)))}


def map10(theta):
    return [float(x) for x in theta]


def standard_step(c4v,y,dt,dz):
    return c4v.heun_step(y,dt,dz)


def extended_rhs(c4v,y,dz):
    return np.asarray(c4v.rhs(np.asarray(y,dtype=float),dz),dtype=np.longdouble)


def extended_step(c4v,y,dt,dz):
    dtl=np.longdouble(dt);dzl=np.asarray(dz,dtype=np.longdouble)
    f0=extended_rhs(c4v,y,dz)
    guess=y+dtl*f0;n=len(dz)
    for it in range(1,c4v.bc1.HEUN_MAX_CORRECTOR+1):
        nxt=y+np.longdouble(0.5)*dtl*(f0+extended_rhs(c4v,guess,dz))
        if np.max(np.abs(nxt[:n]/dzl-guess[:n]/dzl))<=np.longdouble(c4v.bc1.HEUN_CORRECTOR_TOL_THETA):
            return nxt,it
        guess=nxt
    raise RuntimeError("extended Heun corrector did not converge")


def run_heun(c4v,dt,extended=False):
    sub=int(round(OBS_DT/dt))
    if abs(sub*dt-OBS_DT)>1e-15: raise RuntimeError("dt does not divide output interval")
    out={};max_it=0
    for h in HISTS:
        dz,y0=c4v.initial_state(c4v.HISTS[h],BOUNDS)
        if extended:
            y=np.asarray(y0,dtype=np.longdouble)
            init_ld=np.sum(y[:16],dtype=np.longdouble)
        else:
            y=np.asarray(y0,dtype=float)
            init_ld=np.longdouble(math.fsum(float(x) for x in y[:16]))
        rows=[]
        for step in range(STEPS):
            for _ in range(sub):
                if extended:y,it=extended_step(c4v,y,dt,dz)
                else:y,it=standard_step(c4v,y,dt,dz)
                max_it=max(max_it,int(it))
            yf=np.asarray(y,dtype=float)
            theta=yf[:16]/dz
            c4v.bc1.psi_k(theta)
            np_total=float(np.sum(yf[:16]))
            fsum_total=float(math.fsum(float(x) for x in yf[:16]))
            if extended:
                ext_total=np.sum(y[:16],dtype=np.longdouble)
                cum_ld=np.longdouble(y[17])
                invariant=float(ext_total+cum_ld-init_ld)
                total_for_error=float(ext_total)
            else:
                invariant=float(np.longdouble(fsum_total)+np.longdouble(yf[17])-init_ld)
                total_for_error=fsum_total
            rows.append({
                "storage":total_for_error,
                "storage_np":np_total,
                "storage_fsum":fsum_total,
                "cum":float(yf[17]),
                "theta":map10(theta),
                "invariant":invariant,
                "sum_order":np_total-fsum_total,
            })
        out[h]=rows
    return {"route":"HEUN_EXTENDED_ACCUM" if extended else "HEUN_FLOAT64","dt":dt,"histories":out,"max_iter":max_it}


def run_dop(c4v):
    out={};t_eval=np.arange(1,STEPS+1,dtype=float)*OBS_DT
    for h in HISTS:
        dz,y0=c4v.initial_state(c4v.HISTS[h],BOUNDS)
        init=math.fsum(float(x) for x in y0[:16])
        sol=solve_ivp(lambda _t,y:np.asarray(c4v.rhs(y,dz),dtype=float),(0.0,STEPS*OBS_DT),y0,
                      method="DOP853",t_eval=t_eval,rtol=1e-11,atol=1e-13,max_step=OBS_DT)
        if not sol.success or sol.y.shape!=(18,STEPS):
            raise RuntimeError(sol.message)
        rows=[]
        for j in range(STEPS):
            y=sol.y[:,j];theta=y[:16]/dz;c4v.bc1.psi_k(theta)
            total=math.fsum(float(x) for x in y[:16])
            rows.append({
                "storage":total,"cum":float(y[17]),"theta":map10(theta),
                "invariant":total+float(y[17])-init,
            })
        out[h]=rows
    return {"route":"DOP853_STRICT","histories":out}


def compare(route,oracle):
    se=[];ce=[];te=[];inv=[];oinv=[];sumorder=[];decomp=[]
    for h in HISTS:
        for a,b in zip(route["histories"][h],oracle["histories"][h]):
            es=a["storage"]-b["storage"]
            ec=a["cum"]-b["cum"]
            ei=a["invariant"]-b["invariant"]
            se.append(es);ce.append(ec);inv.append(ei);oinv.append(b["invariant"])
            te.extend(np.asarray(a["theta"])-np.asarray(b["theta"]))
            if "sum_order" in a: sumorder.append(a["sum_order"])
            decomp.append(es-(ei-ec))
    return {
      "storage_to_oracle":stats(se),
      "cumulative_to_oracle":stats(ce),
      "mapped_theta_to_oracle":stats(te),
      "invariant_difference_to_oracle":stats(inv),
      "oracle_invariant":stats(oinv),
      "np_sum_minus_fsum":stats(sumorder) if sumorder else None,
      "decomposition_residual":stats(decomp),
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--b1h-result",type=pathlib.Path,required=True)
    ap.add_argument("--b1h-prereg",type=pathlib.Path,required=True)
    ap.add_argument("--basis-dir",type=pathlib.Path,required=True)
    ap.add_argument("--prereg",type=pathlib.Path,required=True)
    ap.add_argument("--output",type=pathlib.Path,required=True)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text());assert pre["phase"]=="PREREGISTERED_BEFORE_B12_INVARIANT_DRIFT_RESULT"
    b1h=json.loads(a.b1h_result.read_text());assert b1h["material"]=="B12"
    bp=json.loads(a.b1h_prereg.read_text())
    lams=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"]["B12"]]
    assert max(abs(x-y) for x,y in zip(lams,[float(x) for x in b1h["scaled_lambdas"]]))<=1e-15
    c4v=load("b1hcj_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch(c4v,b1h["material_parameters"],lams)

    oracle=run_dop(c4v)
    routes={}
    for dt in DTL:
        routes[f"F64_{dt:.8f}"]=run_heun(c4v,dt,False)
        routes[f"EXT_{dt:.8f}"]=run_heun(c4v,dt,True)
    cmp={k:compare(v,oracle) for k,v in routes.items()}
    fine=cmp["F64_0.00002500"];ext=cmp["EXT_0.00002500"]
    s=float(fine["storage_to_oracle"]["rms"])
    c=float(fine["cumulative_to_oracle"]["rms"])
    t=float(fine["mapped_theta_to_oracle"]["rms"])
    i=float(fine["invariant_difference_to_oracle"]["rms"])
    so=float(fine["np_sum_minus_fsum"]["rms"])
    es=float(ext["storage_to_oracle"]["rms"])
    ei=float(ext["invariant_difference_to_oracle"]["rms"])
    storage_factor=(s/es) if es>0 else float("inf")
    invariant_factor=(i/ei) if ei>0 else float("inf")
    rules={
      "cumulative_floor":c<=1e-12,
      "mapped_theta_floor":t<=1e-13,
      "invariant_explains_storage":i>=0.80*s,
      "extended_storage_factor4":storage_factor>=4.0,
      "extended_invariant_factor4":invariant_factor>=4.0,
      "diagnostic_sum_subdominant":so<=0.25*i,
    }
    decision=pre["decision_gate"]["label_confirmed"] if all(rules.values()) else pre["decision_gate"]["label_not_confirmed"]
    result={
      "schema":"swap5.layer-rom.phase-b1hcj.result.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCJ",
      "decision":decision,"material":"B12","representation":"R16_OP",
      "comparisons":cmp,"gate_components":rules,
      "fine_dt_factors":{"extended_storage_reduction_factor":storage_factor,"extended_invariant_reduction_factor":invariant_factor},
      "scientific_interpretation":(
        ["The sole B12 storage exception is quantitatively dominated by loss of the exact linear water invariant in repeated float64 state accumulation.",
         "Changing only accumulation precision suppresses both invariant drift and storage error while retaining the same float64 constitutive flux calculation.",
         "This does not motivate a hydrological state or closure change."]
        if decision==pre["decision_gate"]["label_confirmed"] else
        ["The frozen floating-accumulation mechanism gate is not fully satisfied; the B12 numerical exception remains unresolved."]
      ),
      "reference_trajectory_used":False,"hydrological_model_changed":False,
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"gate_components":rules,"fine_float64":fine,"fine_extended":ext,"factors":result["fine_dt_factors"]},sort_keys=True))
if __name__=="__main__": main()
