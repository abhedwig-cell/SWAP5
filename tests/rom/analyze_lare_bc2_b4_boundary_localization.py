#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("bc2b3", HERE/"analyze_lare_bc2_b3_operator_attribution.py")
b3=importlib.util.module_from_spec(spec); spec.loader.exec_module(b3)

DISTANCES=(20.0,10.0,5.0,2.5)
NAMES=("MOVING_LAYER_AVERAGE","ANCHOR_90_POINT")+tuple(f"POINT_{str(d).replace('.','_')}CM" for d in DISTANCES)

def sample_h(profile,depth):
    pts=sorted((-v["z"],v["h"]) for v in profile.values())
    z=np.asarray([x[0] for x in pts]); h=np.asarray([x[1] for x in pts])
    if depth<z[0]-1e-12 or depth>z[-1]+1e-12:
        raise ValueError(f"no extrapolation: {depth}")
    return float(np.interp(depth,z,h))

def q_moving(profile,total):
    H,S,_=b3.project(profile,total)
    _,qH=b3.standard_fluxes(S,H)
    return H,qH

def q_point(profile,H,d):
    hp=sample_h(profile,H-d)
    return b3.KS*(1.0+hp/d),hp

def q_anchor(profile,H):
    d=H-b3.ANCHOR; hp=sample_h(profile,b3.ANCHOR)
    return b3.KS*(1.0+hp/d),hp,d

def direction(hdot):
    if hdot < -b3.HDOT_EPS: return "WATER_TABLE_RISING"
    if hdot > b3.HDOT_EPS: return "WATER_TABLE_FALLING"
    return "HOLD"

def metrics(rows,name):
    ref=np.array([r["qref"] for r in rows]); pred=np.array([r[name] for r in rows]); e=pred-ref
    corr=float(np.corrcoef(ref,pred)[0,1]) if np.std(ref)>0 and np.std(pred)>0 else None
    out={"count":len(rows),"bias":float(e.mean()),"mae":float(np.abs(e).mean()),
         "rms":float(np.sqrt(np.mean(e*e))),"max_abs":float(np.abs(e).max()),
         "sign_mismatch":int(np.count_nonzero(np.sign(ref)!=np.sign(pred))),"corr":corr}
    hk=name+"_h"; dk=name+"_d"
    if hk in rows[0]:
        h=np.array([r[hk] for r in rows]); d=np.array([r[dk] for r in rows])
        hreq=d*(ref/b3.KS-1.0); he=h-hreq
        out["head_info"]={"mae_h_minus_required":float(np.abs(he).mean()),
                          "rms_h_minus_required":float(np.sqrt(np.mean(he*he))),
                          "max_abs_h_minus_required":float(np.abs(he).max())}
    return out

def improves(x,g):
    return x["rms"] < g["rms"]-1e-12 and x["mae"] < g["mae"]-1e-12

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b3-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text()); prior=json.loads(a.b3_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_WATER_TABLE_BOUNDARY_LOCALIZATION_DIAGNOSTIC"
    assert prior["decision"]==pre["predecessor"]["required_decision"]
    assert prior["standard_face_consistency"]["qH_consistently_larger_error"] is True
    im,inodes,states,nodes=b3.load_reference(a.reference)
    rows=[]; failures=[]
    for hist,nsteps in b3.HISTORY_STEPS.items():
        pp=inodes[hist]; pt=im[hist]["total"]; Hp=b3.diagnose_H(pp)
        for step in range(1,nsteps+1):
            p=nodes[(hist,step)]; total=states[(hist,step)]["total"]; H=b3.diagnose_H(p)
            hdot=(H-Hp)/b3.OBS_DT; r={"history":hist,"direction":direction(hdot),
                "qref":states[(hist,step)]["bottom_exchange"]/b3.OBS_DT}
            _,q0=q_moving(pp,pt); _,q1=q_moving(p,total); r["MOVING_LAYER_AVERAGE"]=0.5*(q0+q1)
            qa0,ha0,da0=q_anchor(pp,Hp); qa1,ha1,da1=q_anchor(p,H)
            r["ANCHOR_90_POINT"]=0.5*(qa0+qa1); r["ANCHOR_90_POINT_h"]=0.5*(ha0+ha1); r["ANCHOR_90_POINT_d"]=0.5*(da0+da1)
            for d in DISTANCES:
                name=f"POINT_{str(d).replace('.','_')}CM"
                try:
                    qd0,hd0=q_point(pp,Hp,d); qd1,hd1=q_point(p,H,d)
                    r[name]=0.5*(qd0+qd1); r[name+"_h"]=0.5*(hd0+hd1); r[name+"_d"]=d
                except ValueError as exc:
                    failures.append({"history":hist,"step":step,"distance":d,"error":str(exc)})
            rows.append(r); pp=p;pt=total;Hp=H
    complete=not failures and all(all(n in r for n in NAMES) for r in rows)
    report={"by_direction":{},"by_history":{}}
    for axis,groups in (("by_direction",["HOLD","WATER_TABLE_RISING","WATER_TABLE_FALLING"]),("by_history",list(b3.HISTORY_STEPS))):
        for g in groups:
            rr=[r for r in rows if (r["direction"]==g if axis=="by_direction" else r["history"]==g)]
            report[axis][g]={n:metrics(rr,n) for n in NAMES}
    support={}
    for d in DISTANCES:
        n=f"POINT_{str(d).replace('.','_')}CM"
        support[n]={g:improves(report["by_direction"][g][n],report["by_direction"][g]["MOVING_LAYER_AVERAGE"])
                    for g in ("WATER_TABLE_RISING","WATER_TABLE_FALLING")}
    supported=[n for n,v in support.items() if all(v.values())]
    best=[]
    for d in DISTANCES:
        n=f"POINT_{str(d).replace('.','_')}CM"; ok=True
        for g in ("WATER_TABLE_RISING","WATER_TABLE_FALLING"):
            rms=min(report["by_direction"][g][f"POINT_{str(x).replace('.','_')}CM"]["rms"] for x in DISTANCES)
            mae=min(report["by_direction"][g][f"POINT_{str(x).replace('.','_')}CM"]["mae"] for x in DISTANCES)
            cur=report["by_direction"][g][n]; ok &= cur["rms"]<=rms+1e-12 and cur["mae"]<=mae+1e-12
        if ok: best.append(n)
    dirdep=any(v["WATER_TABLE_RISING"]!=v["WATER_TABLE_FALLING"] for v in support.values())
    if not complete: decision="BC2_B4_BOUNDARY_LOCALIZATION_DIAGNOSTIC_BLOCKED"
    elif supported: decision="BC2_B4_LOCAL_WATER_TABLE_INFORMATION_SUPPORTED"
    elif dirdep: decision="BC2_B4_LOCAL_INFORMATION_DIRECTION_DEPENDENT"
    else: decision="BC2_B4_GLOBAL_AVERAGE_NOT_DISADVANTAGED"
    result={"schema":"swap5.lare.bc2.b4.result.v1","decision":decision,"complete":complete,
      "support":support,"supported_local_points":supported,"consistent_best":best,
      "failures":failures[:20],**report,
      "interpretation":["Local point pressure head is full-order diagnostic information, not a proposed reduced state.",
        "Support means localized hydraulic information is more informative for qH than one global moving-layer average in both movement directions.",
        "No distance fitting, direction switch or conductivity retuning is performed."],
      "reduced_state_change_authorized":False,"application_acceptance_adjudicated":False,"production_rom_authorized":False}
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"support":support,"consistent_best":best,"by_direction":report["by_direction"]},sort_keys=True))
    return 0 if complete else 2
if __name__=="__main__": raise SystemExit(main())
