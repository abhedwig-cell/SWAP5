#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.optimize import least_squares
from numpy.polynomial.legendre import leggauss

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
PSI_MIN=0.0100000001
PARTITIONS={
    "L3":[0.0,140.0,150.0,160.0],
    "L4":[0.0,130.0,140.0,150.0,160.0],
}
PRIMARY={"S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3"}
GL_X,GL_W=leggauss(16)

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def se_from_psi(psi):
    psi=np.asarray(psi,dtype=float)
    return np.power(1.0+np.power(ALPHA*psi,N),-M)

def theta_from_psi(psi):
    return TR+(TS-TR)*se_from_psi(psi)

def psi_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not (0.0 < se < 1.0):
        raise ValueError(f"theta outside MvG domain: {theta}")
    return float(np.power(np.power(se,-1.0/M)-1.0,1.0/N)/ALPHA)

def k_from_psi(psi):
    se=se_from_psi(psi)
    term=1.0-np.power(1.0-np.power(se,1.0/M),M)
    return KS*np.power(se,LAM)*np.square(term)

def k_from_theta(theta:float)->float:
    return float(k_from_psi(psi_from_theta(theta)))

def load_case(path:pathlib.Path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),
            "z":abs(float(d["Z"])),
            "dz":float(d["DZ"]),
            "h":float(d["H"]),
            "theta":float(d["THETA"]),
        })
    if set(rows)!=set(range(1,1025)):
        raise ValueError(f"incomplete case {path}: {len(rows)} steps")
    for step in rows:
        rows[step].sort(key=lambda x:x["node"])
        if [r["node"] for r in rows[step]]!=list(range(1,17)):
            raise ValueError(f"incomplete nodes {path} step {step}")
    return rows

def layer_means(rows,bounds):
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        selected=[r for r in rows if r["z"]-0.5*r["dz"] >= lo-1e-9 and r["z"]+0.5*r["dz"] <= hi+1e-9]
        width=hi-lo
        covered=sum(r["dz"] for r in selected)
        if abs(covered-width)>1e-9:
            raise ValueError(f"coverage mismatch {lo}-{hi}: {covered}")
        out.append(sum(r["theta"]*r["dz"] for r in selected)/width)
    return out

def reference_flux(rows,boundary):
    upper_node=int(round(boundary/10.0))
    lower_node=upper_node+1
    ru=rows[upper_node-1]; rl=rows[lower_node-1]
    psi_u=-ru["h"]; psi_l=-rl["h"]
    if psi_u <= 0.01 or psi_l <= 0.01:
        raise ValueError("reference face outside strict unsaturated domain")
    ku=float(k_from_psi(psi_u)); kl=float(k_from_psi(psi_l))
    kface=0.5*(ku+kl)
    distance=0.5*(ru["dz"]+rl["dz"])
    return kface*(1.0+(psi_l-psi_u)/distance)

def q_lare(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u); pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u); kl=k_from_theta(theta_l)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))

def q_harmonic(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u); pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u); kl=k_from_theta(theta_l)
    if ku<=0.0 or kl<=0.0:
        raise ValueError("nonpositive conductivity")
    kface=(du+dl)/(du/ku+dl/kl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))

def integrate_theta_linear(psi_top,psi_bottom,z0,z1,total_length):
    mid=0.5*(z0+z1); half=0.5*(z1-z0)
    z=mid+half*GL_X
    psi=psi_top+(psi_bottom-psi_top)*(z/total_length)
    if np.any(psi<=0.01):
        raise ValueError("linear reconstruction crosses strict-unsaturated boundary")
    return float(half*np.sum(GL_W*theta_from_psi(psi))/(z1-z0))

def q_head_linear(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u); pl=psi_from_theta(theta_l)
    slope0=(pl-pu)/(0.5*(du+dl))
    pint=pu+slope0*0.5*du
    ptop=max(PSI_MIN,pint-slope0*du)
    pbot=max(PSI_MIN,pint+slope0*dl)
    x0=np.log(np.asarray([max(ptop-0.01,1e-9),max(pbot-0.01,1e-9)]))
    total=du+dl

    def residual(x):
        top=0.01+math.exp(float(x[0]))
        bot=0.01+math.exp(float(x[1]))
        try:
            mu=integrate_theta_linear(top,bot,0.0,du,total)
            ml=integrate_theta_linear(top,bot,du,total,total)
        except ValueError:
            return np.asarray([1.0,1.0])
        return np.asarray([mu-theta_u,ml-theta_l])

    sol=least_squares(residual,x0,xtol=1e-13,ftol=1e-13,gtol=1e-13,max_nfev=100)
    top=0.01+math.exp(float(sol.x[0]))
    bot=0.01+math.exp(float(sol.x[1]))
    res=residual(sol.x)
    if not sol.success or float(np.max(np.abs(res)))>1e-11:
        raise ValueError(f"linear-head storage reconstruction failed residual={res.tolist()}")
    b=(bot-top)/total
    pint=top+b*du
    if min(top,pint,bot)<=0.01:
        raise ValueError("linear-head solution outside strict-unsaturated domain")
    return float(k_from_psi(pint))*(1.0+b), float(np.max(np.abs(res)))

def structural_tests():
    for theta in (0.25,0.32,0.39):
        k=k_from_theta(theta)
        for du,dl in ((140.0,10.0),(10.0,10.0),(130.0,10.0)):
            assert abs(q_lare(theta,theta,du,dl)-k)<=1e-12*max(1.0,k)
            assert abs(q_harmonic(theta,theta,du,dl)-k)<=1e-12*max(1.0,k)
            q,res=q_head_linear(theta,theta,du,dl)
            assert abs(q-k)<=1e-9*max(1.0,k), (theta,du,dl,q,k)
            assert res<=1e-11
    # Synthetic linear-head identity: reconstruct means generated from a known linear profile.
    for du,dl,top,bot in ((140.0,10.0,80.0,40.0),(130.0,10.0,45.0,20.0),(10.0,10.0,30.0,35.0)):
        total=du+dl
        mu=integrate_theta_linear(top,bot,0.0,du,total)
        ml=integrate_theta_linear(top,bot,du,total,total)
        q,res=q_head_linear(mu,ml,du,dl)
        b=(bot-top)/total
        pint=top+b*du
        expected=float(k_from_psi(pint))*(1.0+b)
        assert abs(q-expected)<=2e-9*max(1.0,abs(expected)), (du,dl,q,expected)
        assert res<=1e-11

def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--reference-status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_NEW_CLOSURE_FLUX_RESULTS"
    assert [c["id"] for c in prereg["closures"]]==["C_LARE_TAYLOR","C_DARCY_HARMONIC","C_HEAD_LINEAR"]
    structural_tests()

    status=json.loads(args.reference_status.read_text())
    qualified=sorted(k for k,v in status["geometries"]["fine"].items() if v["status"]=="QUALIFIED")
    if not PRIMARY.issubset(set(qualified)):
        raise SystemExit(f"primary cohort not fully qualified: {sorted(PRIMARY-set(qualified))}")

    closures=("C_LARE_TAYLOR","C_DARCY_HARMONIC","C_HEAD_LINEAR")
    details={}
    pooled={pid:{cid:[] for cid in closures} for pid in PARTITIONS}
    pooled_sign={pid:{cid:0 for cid in closures} for pid in PARTITIONS}
    pooled_fail={pid:{cid:0 for cid in closures} for pid in PARTITIONS}
    primary_blocks={pid:{cid:defaultdict(list) for cid in closures} for pid in PARTITIONS}
    max_storage_residual=0.0

    for case in qualified:
        trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
        details[case]={}
        for pid,bounds in PARTITIONS.items():
            details[case][pid]={}
            for step in range(1,1025):
                rows=trajectory[step]
                means=layer_means(rows,bounds)
                for iface,boundary in enumerate(bounds[1:-1]):
                    du=bounds[iface+1]-bounds[iface]
                    dl=bounds[iface+2]-bounds[iface+1]
                    ref=reference_flux(rows,boundary)
                    predictions={}
                    failures={}
                    try: predictions["C_LARE_TAYLOR"]=q_lare(means[iface],means[iface+1],du,dl)
                    except Exception as exc: failures["C_LARE_TAYLOR"]=str(exc)
                    try: predictions["C_DARCY_HARMONIC"]=q_harmonic(means[iface],means[iface+1],du,dl)
                    except Exception as exc: failures["C_DARCY_HARMONIC"]=str(exc)
                    try:
                        q,res=q_head_linear(means[iface],means[iface+1],du,dl)
                        predictions["C_HEAD_LINEAR"]=q
                        max_storage_residual=max(max_storage_residual,res)
                    except Exception as exc: failures["C_HEAD_LINEAR"]=str(exc)

                    key=str(int(boundary))
                    block=details[case][pid].setdefault(key,{cid:[] for cid in closures})
                    for cid in closures:
                        if cid in failures:
                            pooled_fail[pid][cid]+=1
                            continue
                        err=predictions[cid]-ref
                        block[cid].append(err)
                        if case in PRIMARY:
                            pooled[pid][cid].append(err)
                            primary_blocks[pid][cid][(case,key)].append(err)
                            pooled_sign[pid][cid]+=int((predictions[cid]>0)!=(ref>0))

    case_summary={}
    for case in qualified:
        case_summary[case]={}
        for pid in PARTITIONS:
            case_summary[case][pid]={}
            for iface,byclosure in details[case][pid].items():
                case_summary[case][pid][iface]={}
                for cid,errors in byclosure.items():
                    case_summary[case][pid][iface][cid]={
                        "sample_count":len(errors),
                        "rms_error_cm_per_day":rms(errors),
                        "max_abs_error_cm_per_day":max((abs(x) for x in errors),default=None)
                    }

    pooled_summary={}
    for pid in PARTITIONS:
        pooled_summary[pid]={}
        for cid in closures:
            errs=pooled[pid][cid]
            pooled_summary[pid][cid]={
                "sample_count":len(errs),
                "rms_error_cm_per_day":rms(errs),
                "max_abs_error_cm_per_day":max((abs(x) for x in errs),default=None),
                "flux_sign_mismatch_count":pooled_sign[pid][cid],
                "solve_failure_count":pooled_fail[pid][cid],
            }

    adjudication={}
    baseline=pooled_summary["L3"]["C_LARE_TAYLOR"]
    for cid in ("C_DARCY_HARMONIC","C_HEAD_LINEAR"):
        row=pooled_summary["L3"][cid]
        component_noninferior={
            "rms":row["rms_error_cm_per_day"]<=baseline["rms_error_cm_per_day"]+1e-15,
            "max_abs":row["max_abs_error_cm_per_day"]<=baseline["max_abs_error_cm_per_day"]+1e-15,
            "sign_mismatch":row["flux_sign_mismatch_count"]<=baseline["flux_sign_mismatch_count"],
            "solve_failure":row["solve_failure_count"]==0,
        }
        strict=(row["rms_error_cm_per_day"]<baseline["rms_error_cm_per_day"]-1e-15 or
                row["max_abs_error_cm_per_day"]<baseline["max_abs_error_cm_per_day"]-1e-15 or
                row["flux_sign_mismatch_count"]<baseline["flux_sign_mismatch_count"])
        broad=True
        worse_blocks=[]
        for block,errs in primary_blocks["L3"][cid].items():
            base_errs=primary_blocks["L3"]["C_LARE_TAYLOR"][block]
            if rms(errs)>rms(base_errs)+1e-15 and max(abs(x) for x in errs)>max(abs(x) for x in base_errs)+1e-15:
                broad=False; worse_blocks.append({"case":block[0],"interface_cm":int(block[1])})
        adjudication[cid]={
            "component_noninferiority":component_noninferior,
            "strict_improvement":strict,
            "storage_only_closure_improvement":all(component_noninferior.values()) and strict,
            "broad_support":broad,
            "worse_on_both_rms_and_max_blocks":worse_blocks,
        }

    result={
        "schema":"swap5.layer-rom.phase-a2.closure-audit-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-A2",
        "decision":"LAYER_ROM_A2_STORAGE_ONLY_CLOSURE_AUDIT_COMPLETE",
        "qualified_reference_cases":qualified,
        "primary_high_state_dynamic_cases":sorted(PRIMARY),
        "structural_tests":"PASS",
        "max_head_linear_storage_reconstruction_residual_theta":max_storage_residual,
        "pooled_primary":pooled_summary,
        "adjudication":adjudication,
        "case_interface_summary":case_summary,
        "interpretation_firewalls":[
            "Teacher-forced operator audit only; no reduced-state propagation is executed.",
            "All closures receive the same exact projected layer-storage state.",
            "No coefficient is fitted to Reference response.",
            "L4 is a closure-resolution control because A1 found no additional common-cohort state-information value over L3.",
            "No application acceptance or speed claim follows."
        ],
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "qualified_reference_cases":qualified,
        "max_head_linear_storage_reconstruction_residual_theta":max_storage_residual,
        "pooled_primary":pooled_summary,
        "adjudication":adjudication,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
