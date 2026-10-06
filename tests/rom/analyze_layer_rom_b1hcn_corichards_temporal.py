#!/usr/bin/env python3
from __future__ import annotations

import argparse,importlib.util,json,math,pathlib,sys
from collections import defaultdict
from typing import Any
import numpy as np

HISTS=("X01","X02","X03","X04")
OBS_DT=0.001
OBS_STEPS=1024
COMPONENTS={
 "storage_rms":"storage","cumulative_bottom_rms":"cumulative_bottom",
 "qavg_rms":"qavg","qend_rms":"qend","mapped_theta_rms":"mapped_theta"
}

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None: raise RuntimeError(path)
    m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m

def fields(payload):
    out={}
    for x in payload.split("|"):
        if "=" in x:
            k,v=x.split("=",1);out[k]=v
    return out

def map_piecewise(theta,bounds):
    out=[]
    for node in range(16):
        lo=node*10.0;hi=(node+1)*10.0;v=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0:v+=float(t)*w
        out.append(v/10.0)
    return out

def parse_history(path:pathlib.Path,substeps:int,bounds:list[float],c4v)->dict[str,Any]:
    states={};nodes=defaultdict(dict);initial={};geom=None;maxmass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D13_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D13_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_INITIAL|",1)[1]);initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
            maxmass=max(maxmass,abs(float(r["MASS"])))
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    expected=OBS_STEPS*substeps
    if geom is None or len(initial)!=1 or len(states)!=expected or len(nodes)!=expected:
        raise RuntimeError(f"comparator structure mismatch {path} states={len(states)} nodes={len(nodes)}")
    n=int(geom["N"]); hist=next(iter(initial))
    if n!=len(bounds)-1: raise RuntimeError("geometry dimension drift")
    if set(states)!={(hist,s) for s in range(1,expected+1)}: raise RuntimeError("state identity drift")
    if any(set(nodes[(hist,s)])!=set(range(1,n+1)) for s in range(1,expected+1)): raise RuntimeError("node identity drift")
    S=[];C=[];QAVG=[];QEND=[];theta=[];cum=0.0;block=0.0
    for step in range(1,expected+1):
        rr=states[(hist,step)]
        ex=float(rr["BOTTOM_OUTWARD_EXCHANGE"]);cum+=ex;block+=ex
        if step%substeps: continue
        tv=[float(nodes[(hist,step)][i]["THETA"]) for i in range(1,n+1)]
        qend=float(c4v.qbottom_zero_head(np.asarray([tv[-1]]),np.asarray([bounds[-1]-bounds[-2]])))
        S.append(float(rr["TOTAL_STORAGE"]));C.append(cum);QAVG.append(block/OBS_DT);QEND.append(qend)
        theta.append(map_piecewise(tv,bounds));block=0.0
    return {"hist":hist,"series":{"S":S,"C":C,"QAVG":QAVG,"QEND":QEND,"theta":theta},"maxmass":maxmass}

def load_route(root:pathlib.Path,member:str,substeps:int,bounds:list[float],c4v,prefix:str|None=None):
    series={};maxmass=0.0
    for h in HISTS:
        if prefix is None:
            p=root/member/f"{member}-{h}-o0.txt"
        else:
            p=root/f"{prefix}_{member}_{h}.txt"
        z=parse_history(p,substeps,bounds,c4v)
        if z["hist"]!=h: raise RuntimeError(f"history mismatch {h} {z['hist']}")
        series[h]=z["series"];maxmass=max(maxmass,z["maxmass"])
    return {"series":series,"maxmass":maxmass}

def linear_route(a,b,wa,wb):
    out={}
    for h in HISTS:
        out[h]={}
        for k in ("S","C","QAVG","QEND","theta"):
            x=np.asarray(a["series"][h][k],float);y=np.asarray(b["series"][h][k],float)
            if x.shape!=y.shape: raise RuntimeError(f"shape drift {h} {k}")
            out[h][k]=(wa*x+wb*y).tolist()
    return {"series":out}

def sign_mismatch(a,b,key):
    n=0
    for h in HISTS:
        x=np.asarray(a["series"][h][key],float);y=np.asarray(b["series"][h][key],float)
        n+=int(np.count_nonzero(np.sign(x)!=np.sign(y)))
    return n

def final_cumulative_max(a,b):
    return max(abs(float(a["series"][h]["C"][-1])-float(b["series"][h]["C"][-1])) for h in HISTS)

def vector_relation(layer,cor,tol=1e-12):
    keys=["storage_rms_cm","cumulative_bottom_rms_cm","qavg_rms_cm_per_day","qavg_sign_mismatch",
          "qend_rms_cm_per_day","qend_sign_mismatch","max_abs_final_cumulative_bottom_error_cm"]
    cor_nw=True;lay_nw=True;cor_strict=False;lay_strict=False
    for k in keys:
        a=layer[k];b=cor[k]
        if "sign_mismatch" in k:
            if b>a: cor_nw=False
            if b<a: cor_strict=True
            if a>b: lay_nw=False
            if a<b: lay_strict=True
        else:
            if b>float(a)+tol: cor_nw=False
            if b<float(a)-tol: cor_strict=True
            if float(a)>float(b)+tol: lay_nw=False
            if float(a)<float(b)-tol: lay_strict=True
    if cor_nw and cor_strict:return "COR_COMPONENTWISE_NO_WORSE"
    if lay_nw and lay_strict:return "LAYER_ROM_COMPONENTWISE_NO_WORSE"
    if cor_nw and lay_nw:return "NUMERICALLY_EQUIVALENT"
    return "TRADEOFF"

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True);ap.add_argument("--member",required=True)
    ap.add_argument("--coarse-dir",required=True,type=pathlib.Path)
    ap.add_argument("--mid-dir",required=True,type=pathlib.Path)
    ap.add_argument("--fine-dir",required=True,type=pathlib.Path)
    ap.add_argument("--ref-fine",required=True,type=pathlib.Path)
    ap.add_argument("--ref-ultra",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcm-result",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_NEW_CORICHARDS_TEMPORAL_RESPONSE": raise SystemExit("wrong B1HCN phase")
    specs={x["id"]:x for x in pre["cohort"]["members"]}
    if a.member not in specs or a.material not in pre["cohort"]["materials"]: raise SystemExit("cohort drift")
    spec=specs[a.member];bounds=[0.0]
    for x in spec["thickness_cm"]: bounds.append(bounds[-1]+float(x))

    b1h=json.loads(a.b1h_result.read_text());bp=json.loads(a.b1h_prereg.read_text())
    b1hcm=json.loads(a.b1hcm_result.read_text())
    if b1h["material"]!=a.material or b1hcm["material"]!=a.material: raise SystemExit("material identity drift")
    lambdas=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]
    if max(abs(x-y) for x,y in zip(lambdas,[float(x) for x in b1h["scaled_lambdas"]]))>1e-15: raise SystemExit("lambda drift")

    ci=load_module("b1hcn_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    hcl=load_module("b1hcn_hcl",pathlib.Path("tests/rom/analyze_layer_rom_b1hcl_richardson.py"))
    c4v=ci.load("b1hcn_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],lambdas)

    coarse=load_route(a.coarse_dir,a.member,1,bounds,c4v)
    mid=load_route(a.mid_dir,a.member,2,bounds,c4v,prefix="COR_MID")
    fine=load_route(a.fine_dir,a.member,4,bounds,c4v,prefix="COR_FINE")
    pred=linear_route(mid,coarse,1.5,-0.5)
    cstar=linear_route(fine,mid,2.0,-1.0)
    rf=hcl.parse_reference(a.ref_fine,4);ru=hcl.parse_reference(a.ref_ultra,8)
    rstar=hcl.linear_route(ru,rf,2.0,-1.0)

    cm=ci.pooled_stats(coarse,mid);mf=ci.pooled_stats(mid,fine);pf=ci.pooled_stats(pred,fine)
    cr=ci.pooled_stats(cstar,rstar)
    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    temporal={}
    for comp,obs in COMPONENTS.items():
        floor=floors[comp];e1=float(cm[obs]["rms"]);e2=float(mf[obs]["rms"]);ep=float(pf[obs]["rms"])
        conv=e2<=e1+floor;pb=max(floor,0.10*e2);pp=ep<=pb
        order=None if e1<=floor or e2<=floor else math.log(e1/e2,2.0)
        temporal[comp]={
          "coarse_mid_rms":e1,"mid_fine_rms":e2,"fine_prediction_rms":ep,"prediction_bound":pb,
          "continued_convergence":conv,"prediction_pass":pp,"observed_order":order,"pass":conv and pp
        }
    temporal_supported=all(x["pass"] for x in temporal.values())

    cor={
      "storage_rms_cm":float(cr["storage"]["rms"]),
      "cumulative_bottom_rms_cm":float(cr["cumulative_bottom"]["rms"]),
      "qavg_rms_cm_per_day":float(cr["qavg"]["rms"]),
      "qavg_sign_mismatch":sign_mismatch(cstar,rstar,"QAVG"),
      "qend_rms_cm_per_day":float(cr["qend"]["rms"]),
      "qend_sign_mismatch":sign_mismatch(cstar,rstar,"QEND"),
      "mapped_theta_rms":float(cr["mapped_theta"]["rms"]),
      "max_abs_final_cumulative_bottom_error_cm":final_cumulative_max(cstar,rstar)
    }
    lr=b1hcm["representations"][a.member]
    layer={
      "storage_rms_cm":float(lr["fidelity"]["storage"]["rms"]),
      "cumulative_bottom_rms_cm":float(lr["fidelity"]["cumulative_bottom"]["rms"]),
      "qavg_rms_cm_per_day":float(lr["fidelity"]["qavg"]["rms"]),
      "qavg_sign_mismatch":int(lr["sign_mismatch"]["QAVG"]),
      "qend_rms_cm_per_day":float(lr["fidelity"]["qend"]["rms"]),
      "qend_sign_mismatch":int(lr["sign_mismatch"]["QEND"]),
      "mapped_theta_rms":float(lr["fidelity"]["mapped_theta"]["rms"]),
      "max_abs_final_cumulative_bottom_error_cm":float(lr["max_abs_final_cumulative_bottom_error_cm"])
    }
    relation=vector_relation(layer,cor)
    decision=("B1HCN_MEMBER_TEMPORAL_LIMIT_SUPPORTED" if temporal_supported else "B1HCN_MEMBER_TEMPORAL_LIMIT_UNRESOLVED")
    result={
      "schema":"swap5.layer-rom.phase-b1hcn.member-result.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCN",
      "material":a.material,"member":a.member,"decision":decision,
      "temporal":temporal,
      "max_mass_residual_cm":{"mid":mid["maxmass"],"fine":fine["maxmass"]},
      "continuous_time_fidelity":{"LayerROM":layer,"CoRichards":cor},
      "groundwater_relation":relation,
      "profile_relation":{
        "LayerROM_mapped_theta_rms":layer["mapped_theta_rms"],
        "CoRichards_mapped_theta_rms":cor["mapped_theta_rms"],
        "lower_error_route":"LayerROM" if layer["mapped_theta_rms"]<cor["mapped_theta_rms"]-1e-12 else ("CoRichards" if cor["mapped_theta_rms"]<layer["mapped_theta_rms"]-1e-12 else "NUMERICALLY_EQUAL")
      },
      "integrity":{"pass":True,"temporal_supported":temporal_supported,"new_fine_reference_generated":False,
                   "hydrological_model_changed":False},
      "interpretation_firewalls":[
        "CoRichards temporal order is tested prospectively on the exact nonuniform member before Richardson extrapolation is interpreted.",
        "Layer-ROM and CoRichards are compared against the same B1HCL-qualified Reference temporal limit.",
        "The error gap is descriptive and is not an additive closure-error estimate."
      ],
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"material":a.material,"member":a.member,"decision":decision,"temporal":temporal,
                      "LayerROM":layer,"CoRichards":cor,"groundwater_relation":relation,
                      "profile_relation":result["profile_relation"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
