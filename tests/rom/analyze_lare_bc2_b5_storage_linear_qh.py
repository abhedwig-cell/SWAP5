#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("bc2b3",HERE/"analyze_lare_bc2_b3_operator_attribution.py")
b3=importlib.util.module_from_spec(spec);spec.loader.exec_module(b3)

_GL={64:np.polynomial.legendre.leggauss(64),128:np.polynomial.legendre.leggauss(128)}
STORAGE_GATE=1e-10
SLOPE_GATE=1e-10
Q_CROSS_GATE=1e-8

def storage_for_slope(a,L,nq):
    x,w=_GL[nq]; xx=0.5*L*(x+1.0)
    return float(0.5*L*np.sum(w*b3.theta_from_psi(a*xx)))

def solve_slope(W,L,nq):
    lo=0.0; flo=storage_for_slope(lo,L,nq)-W
    if flo < -STORAGE_GATE:
        raise ValueError("storage exceeds saturated bound")
    hi=1.0; fhi=storage_for_slope(hi,L,nq)-W
    while fhi>0.0 and hi<1e8:
        hi*=2.0;fhi=storage_for_slope(hi,L,nq)-W
    if fhi>0.0:
        raise ValueError("no nonnegative slope bracket")
    for _ in range(120):
        mid=0.5*(lo+hi);fm=storage_for_slope(mid,L,nq)-W
        if abs(fm)<=1e-13: lo=hi=mid;break
        if fm>0.0: lo=mid
        else: hi=mid
    a=0.5*(lo+hi);res=storage_for_slope(a,L,nq)-W
    return a,res

def q_storage(profile,total,nq):
    H,S,_=b3.project(profile,total);L=H-b3.ANCHOR
    a,res=solve_slope(float(S[b3.NFIXED]),L,nq)
    return H,b3.KS*(1.0-a),a,res

def q_standard(profile,total):
    H,S,_=b3.project(profile,total);_,q=b3.standard_fluxes(S,H);return H,q

def sample_h(profile,depth):
    pts=sorted((-r["z"],r["h"]) for r in profile.values())
    return float(np.interp(depth,[p[0] for p in pts],[p[1] for p in pts]))

def q_point_2p5(profile,H):
    d=2.5;return b3.KS*(1.0+sample_h(profile,H-d)/d)

def direction(hdot):
    if hdot < -b3.HDOT_EPS:return "WATER_TABLE_RISING"
    if hdot > b3.HDOT_EPS:return "WATER_TABLE_FALLING"
    return "HOLD"

def metrics(rows,key):
    ref=np.array([r["qref"] for r in rows]);pred=np.array([r[key] for r in rows]);e=pred-ref
    corr=float(np.corrcoef(ref,pred)[0,1]) if np.std(ref)>0 and np.std(pred)>0 else None
    return {"count":len(rows),"bias":float(e.mean()),"mae":float(np.abs(e).mean()),
      "rms":float(np.sqrt(np.mean(e*e))),"max_abs":float(np.abs(e).max()),
      "sign_mismatch":int(np.count_nonzero(np.sign(ref)!=np.sign(pred))),"corr":corr}

def noninferior_and_strict(cand,base):
    ni=(cand["rms"]<=base["rms"]+1e-14 and cand["mae"]<=base["mae"]+1e-14 and cand["sign_mismatch"]<=base["sign_mismatch"])
    strict=(cand["rms"]<base["rms"]-1e-12 and cand["mae"]<base["mae"]-1e-12)
    return ni,strict

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b3-result",required=True,type=pathlib.Path)
    ap.add_argument("--b4-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text());r3=json.loads(a.b3_result.read_text());r4=json.loads(a.b4_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_MASS_CONSISTENT_LINEAR_PROFILE_QH_DIAGNOSTIC"
    assert r3["decision"]==pre["predecessors"]["required_B3_decision"]
    assert r4["decision"]==pre["predecessors"]["required_B4_decision"]
    im,inodes,states,nodes=b3.load_reference(a.reference)

    rows=[];max_res=0.0;max_q_cross=0.0;fail=[]
    for hist,nsteps in b3.HISTORY_STEPS.items():
        pp=inodes[hist];pt=im[hist]["total"];Hp=b3.diagnose_H(pp)
        try:q0_64=q_storage(pp,pt,64);q0_128=q_storage(pp,pt,128)
        except ValueError as e:fail.append({"history":hist,"step":0,"error":str(e)});continue
        max_res=max(max_res,abs(q0_64[3]),abs(q0_128[3]));max_q_cross=max(max_q_cross,abs(q0_64[1]-q0_128[1]))
        for step in range(1,nsteps+1):
            p=nodes[(hist,step)];total=states[(hist,step)]["total"];H=b3.diagnose_H(p);hdot=(H-Hp)/b3.OBS_DT
            try:q1_64=q_storage(p,total,64);q1_128=q_storage(p,total,128)
            except ValueError as e:fail.append({"history":hist,"step":step,"error":str(e)});break
            max_res=max(max_res,abs(q1_64[3]),abs(q1_128[3]));max_q_cross=max(max_q_cross,abs(q1_64[1]-q1_128[1]))
            _,std0=q_standard(pp,pt);_,std1=q_standard(p,total)
            row={"history":hist,"direction":direction(hdot),"qref":states[(hist,step)]["bottom_exchange"]/b3.OBS_DT,
              "LINEAR_STORAGE":0.5*(q0_64[1]+q1_64[1]),"MOVING_LAYER_AVERAGE":0.5*(std0+std1),
              "POINT_2_5CM":0.5*(q_point_2p5(pp,Hp)+q_point_2p5(p,H)),
              "slope_a":0.5*(q0_64[2]+q1_64[2])}
            rows.append(row);pp=p;pt=total;Hp=H;q0_64=q1_64;q0_128=q1_128

    # Manufactured hydrostatic a=1 recovery over observed L.
    Hvals=[b3.diagnose_H(inodes[h]) for h in b3.HISTORY_STEPS]
    Hvals += [b3.diagnose_H(nodes[(h,s)]) for h,n in b3.HISTORY_STEPS.items() for s in range(1,n+1,64)]
    max_hydro=0.0
    for H in Hvals:
        L=H-b3.ANCHOR;W=storage_for_slope(1.0,L,64);aa,_=solve_slope(W,L,64);max_hydro=max(max_hydro,abs(aa-1.0))

    complete=(not fail and max_res<=STORAGE_GATE and max_q_cross<=Q_CROSS_GATE and max_hydro<=SLOPE_GATE)
    report={"by_direction":{},"by_history":{}}
    for axis,groups in (("by_direction",["HOLD","WATER_TABLE_RISING","WATER_TABLE_FALLING"]),("by_history",list(b3.HISTORY_STEPS))):
        for g in groups:
            rr=[x for x in rows if (x["direction"]==g if axis=="by_direction" else x["history"]==g)]
            slopes=np.array([x["slope_a"] for x in rr])
            report[axis][g]={
              k:metrics(rr,k) for k in ("LINEAR_STORAGE","MOVING_LAYER_AVERAGE","POINT_2_5CM")}
            report[axis][g]["slope_a"]={"min":float(slopes.min()),"mean":float(slopes.mean()),"max":float(slopes.max())}

    support={}
    for d in ("WATER_TABLE_RISING","WATER_TABLE_FALLING","HOLD"):
        cand=report["by_direction"][d]["LINEAR_STORAGE"];base=report["by_direction"][d]["MOVING_LAYER_AVERAGE"]
        ni,strict=noninferior_and_strict(cand,base);support[d]={"noninferior":ni,"strict_magnitude_improvement":strict}
    moving_supported=all(support[d]["noninferior"] and support[d]["strict_magnitude_improvement"] for d in ("WATER_TABLE_RISING","WATER_TABLE_FALLING"))
    hold_ok=support["HOLD"]["noninferior"]
    if not complete:decision="BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_BLOCKED"
    elif moving_supported and hold_ok:decision="BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_SUPPORTED"
    elif support["WATER_TABLE_RISING"]["noninferior"] != support["WATER_TABLE_FALLING"]["noninferior"]:decision="BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_DIRECTION_DEPENDENT"
    else:decision="BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_NOT_SUPPORTED"

    result={"schema":"swap5.lare.bc2.b5.result.v1","decision":decision,
      "hard_checks":{"complete":complete,"max_storage_root_residual_cm":max_res,"storage_gate_cm":STORAGE_GATE,
        "max_primary_crosscheck_qH_difference_cm_per_day":max_q_cross,"qH_crosscheck_gate_cm_per_day":Q_CROSS_GATE,
        "max_hydrostatic_slope_abs_a_minus_1":max_hydro,"hydrostatic_slope_gate":SLOPE_GATE,"failures":fail[:20]},
      "support_relative_to_moving_average":support,**report,
      "interpretation":["LINEAR_STORAGE uses only Wm and L; no local full-order pressure head enters the candidate.",
        "POINT_2_5CM is reported only as the previously frozen full-order information diagnostic.",
        "Operator support does not authorize propagated reduced dynamics."],
      "propagated_dynamics_authorized":False,"application_acceptance_adjudicated":False,"production_rom_authorized":False}
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"hard_checks":result["hard_checks"],"support":support,"by_direction":report["by_direction"]},sort_keys=True))
    return 0 if complete else 2
if __name__=="__main__":raise SystemExit(main())
