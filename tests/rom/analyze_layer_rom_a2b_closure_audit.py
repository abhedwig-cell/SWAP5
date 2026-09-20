#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.integrate import solve_ivp
from scipy.optimize import least_squares

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
PSI_MIN=0.010000001
PRIMARY=("S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3")
PARTITIONS={
    "L3":{"bounds":[0.0,140.0,150.0,160.0],"long_interface":140.0},
    "L4":{"bounds":[0.0,130.0,140.0,150.0,160.0],"long_interface":130.0},
}
RTOL=2.0e-10
ATOL_PSI=1.0e-10
ATOL_INT=1.0e-11
XTOL=1.0e-12
FTOL=1.0e-12
GTOL=1.0e-12
MAX_NFEV=40


def fields(payload:str)->dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
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
    ru=rows[upper_node-1]
    rl=rows[lower_node-1]
    pu=-ru["h"]
    pl=-rl["h"]
    if pu<=0.01 or pl<=0.01:
        raise ValueError("Reference face outside strict unsaturated domain")
    ku=float(k_from_psi(pu))
    kl=float(k_from_psi(pl))
    return 0.5*(ku+kl)*(1.0+(pl-pu)/(0.5*(ru["dz"]+rl["dz"])))


def q_lare(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u)
    kl=k_from_theta(theta_l)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def integrate_profile(psi0,q,length):
    def rhs(z,y):
        psi=float(y[0])
        if not math.isfinite(psi) or psi<=PSI_MIN:
            return [1.0e12,0.0]
        kval=float(k_from_psi(psi))
        if not math.isfinite(kval) or kval<=0.0:
            return [1.0e12,0.0]
        return [q/kval-1.0,float(theta_from_psi(psi))]
    sol=solve_ivp(
        rhs,(0.0,length),(psi0,0.0),method="DOP853",
        rtol=RTOL,atol=[ATOL_PSI,ATOL_INT],
    )
    if not sol.success or sol.y.shape[1] < 2:
        raise ValueError("profile integration failed")
    if np.min(sol.y[0])<=PSI_MIN or not np.all(np.isfinite(sol.y)):
        raise ValueError("profile outside strict unsaturated domain")
    return float(sol.y[0,-1]),float(sol.y[1,-1])


def fresh_interface_guess(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    pif=pu+(pl-pu)*du/(du+dl)
    q0=q_lare(theta_u,theta_l,du,dl)
    return np.asarray([
        math.log(max(pif-0.01,1.0e-9)),
        math.asinh(q0/KS),
    ],dtype=float)


def q_integrated_centroid(theta_u,theta_l,du,dl,warm=None):
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    distance=0.5*(du+dl)
    q0=q_lare(theta_u,theta_l,du,dl)
    starts=[]
    if warm is not None:
        starts.append(np.asarray(warm,dtype=float))
    starts.append(np.asarray([math.asinh(q0/KS)],dtype=float))

    def residual(x):
        q=KS*math.sinh(float(x[0]))
        try:
            pup,_=integrate_profile(pl,q,-distance)
        except Exception:
            return np.asarray([1.0e3])
        return np.asarray([(pup-pu)/max(1.0,abs(pu),abs(pl))])

    last=None
    for start in starts:
        sol=least_squares(residual,start,xtol=XTOL,ftol=FTOL,gtol=GTOL,max_nfev=MAX_NFEV)
        last=sol
        rr=residual(sol.x)
        if sol.success and abs(float(rr[0]))<=1.0e-10:
            return KS*math.sinh(float(sol.x[0])),sol.x,int(sol.nfev)
    raise ValueError(f"centroid shooting failed: {None if last is None else last.message}")


def q_qs_storage(theta_u,theta_l,du,dl,warm=None):
    starts=[]
    if warm is not None:
        starts.append(np.asarray(warm,dtype=float))
    starts.append(fresh_interface_guess(theta_u,theta_l,du,dl))

    def simulate(x):
        pif=0.01+math.exp(float(x[0]))
        q=KS*math.sinh(float(x[1]))
        try:
            _,iupper=integrate_profile(pif,q,-du)
            _,ilower=integrate_profile(pif,q,dl)
        except Exception:
            return None
        mean_upper=-iupper/du
        mean_lower=ilower/dl
        return q,np.asarray([mean_upper-theta_u,mean_lower-theta_l])

    def residual(x):
        sim=simulate(x)
        if sim is None:
            return np.asarray([1.0,1.0])
        return sim[1]

    last=None
    for start in starts:
        sol=least_squares(residual,start,xtol=XTOL,ftol=FTOL,gtol=GTOL,max_nfev=MAX_NFEV)
        last=sol
        sim=simulate(sol.x)
        if sim is not None and sol.success and float(np.max(np.abs(sim[1])))<=1.0e-10:
            return sim[0],sol.x,int(sol.nfev),float(np.max(np.abs(sim[1])))
    raise ValueError(f"storage QS shooting failed: {None if last is None else last.message}")


def structural_tests():
    for theta in (0.25,0.32,0.39):
        kval=k_from_theta(theta)
        for du,dl in ((140.0,10.0),(130.0,10.0)):
            qint,_,_=q_integrated_centroid(theta,theta,du,dl)
            qqs,_,_,res=q_qs_storage(theta,theta,du,dl)
            assert abs(q_lare(theta,theta,du,dl)-kval)<=1e-12*max(1.0,kval)
            assert abs(qint-kval)<=1e-8*max(1.0,kval)
            assert abs(qqs-kval)<=1e-8*max(1.0,kval)
            assert res<=1e-10

    # Synthetic constant-flux centroid identity.
    lower_psi=30.0
    q_true=3.0
    upper_psi,_=integrate_profile(lower_psi,q_true,-75.0)
    tu=float(theta_from_psi(upper_psi))
    tl=float(theta_from_psi(lower_psi))
    qgot,_,_=q_integrated_centroid(tu,tl,140.0,10.0)
    assert abs(qgot-q_true)<=1e-7*max(1.0,abs(q_true))

    # Synthetic storage-constrained steady-profile identity.
    pif=30.0
    q_true=3.0
    _,iu=integrate_profile(pif,q_true,-140.0)
    _,il=integrate_profile(pif,q_true,10.0)
    tu=-iu/140.0
    tl=il/10.0
    qgot,_,_,res=q_qs_storage(tu,tl,140.0,10.0)
    assert abs(qgot-q_true)<=1e-7*max(1.0,abs(q_true))
    assert res<=1e-10


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else None


def summarize(errors,sign_mismatch,failures,nfev):
    return {
        "sample_count":len(errors),
        "rms_error_cm_per_day":rms(errors),
        "max_abs_error_cm_per_day":max((abs(x) for x in errors),default=None),
        "mean_signed_error_cm_per_day":float(np.mean(errors)) if errors else None,
        "flux_sign_mismatch_count":sign_mismatch,
        "solve_failure_count":failures,
        "mean_nonlinear_evaluations":float(np.mean(nfev)) if nfev else None,
        "max_nonlinear_evaluations":max(nfev) if nfev else None,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_QUASI_STEADY_CLOSURE_RESULTS"
    assert prereg["pre_execution_numerical_amendment"]["before_first_A2B_result"] is True
    assert prereg["pre_execution_numerical_amendment"]["observation_set"].startswith("all 1024")
    structural_tests()

    closures=("C_LARE_TAYLOR","C_INT_CENTROID_LONG_ONLY","C_QS_STORAGE_LONG_ONLY")
    pooled={pid:{cid:[] for cid in closures} for pid in PARTITIONS}
    signs={pid:{cid:0 for cid in closures} for pid in PARTITIONS}
    failures={pid:{cid:0 for cid in closures} for pid in PARTITIONS}
    nfev={pid:{cid:[] for cid in closures} for pid in PARTITIONS}
    bycase={case:{pid:{cid:[] for cid in closures} for pid in PARTITIONS} for case in PRIMARY}
    bycase_sign={case:{pid:{cid:0 for cid in closures} for pid in PARTITIONS} for case in PRIMARY}
    bycase_fail={case:{pid:{cid:0 for cid in closures} for pid in PARTITIONS} for case in PRIMARY}
    max_storage_residual=0.0

    for case in PRIMARY:
        trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
        for pid,spec in PARTITIONS.items():
            bounds=spec["bounds"]
            boundary=spec["long_interface"]
            iface=bounds.index(boundary)-1
            du=bounds[iface+1]-bounds[iface]
            dl=bounds[iface+2]-bounds[iface+1]
            warm_int=None
            warm_qs=None
            for step in range(1,1025):
                rows=trajectory[step]
                means=layer_means(rows,bounds)
                tu=means[iface]
                tl=means[iface+1]
                ref=reference_flux(rows,boundary)

                preds={}
                try:
                    preds["C_LARE_TAYLOR"]=q_lare(tu,tl,du,dl)
                except Exception:
                    failures[pid]["C_LARE_TAYLOR"]+=1
                    bycase_fail[case][pid]["C_LARE_TAYLOR"]+=1

                try:
                    q,warm_int,nev=q_integrated_centroid(tu,tl,du,dl,warm_int)
                    preds["C_INT_CENTROID_LONG_ONLY"]=q
                    nfev[pid]["C_INT_CENTROID_LONG_ONLY"].append(nev)
                except Exception:
                    warm_int=None
                    failures[pid]["C_INT_CENTROID_LONG_ONLY"]+=1
                    bycase_fail[case][pid]["C_INT_CENTROID_LONG_ONLY"]+=1

                try:
                    q,warm_qs,nev,res=q_qs_storage(tu,tl,du,dl,warm_qs)
                    preds["C_QS_STORAGE_LONG_ONLY"]=q
                    nfev[pid]["C_QS_STORAGE_LONG_ONLY"].append(nev)
                    max_storage_residual=max(max_storage_residual,res)
                except Exception:
                    warm_qs=None
                    failures[pid]["C_QS_STORAGE_LONG_ONLY"]+=1
                    bycase_fail[case][pid]["C_QS_STORAGE_LONG_ONLY"]+=1

                for cid,q in preds.items():
                    err=q-ref
                    pooled[pid][cid].append(err)
                    bycase[case][pid][cid].append(err)
                    mismatch=int((q>0)!=(ref>0))
                    signs[pid][cid]+=mismatch
                    bycase_sign[case][pid][cid]+=mismatch

    pooled_summary={
        pid:{
            cid:summarize(pooled[pid][cid],signs[pid][cid],failures[pid][cid],nfev[pid][cid])
            for cid in closures
        }
        for pid in PARTITIONS
    }
    case_summary={
        case:{
            pid:{
                cid:summarize(
                    bycase[case][pid][cid],
                    bycase_sign[case][pid][cid],
                    bycase_fail[case][pid][cid],
                    []
                )
                for cid in closures
            }
            for pid in PARTITIONS
        }
        for case in PRIMARY
    }

    baseline=pooled_summary["L3"]["C_LARE_TAYLOR"]
    adjudication={}
    for cid in ("C_INT_CENTROID_LONG_ONLY","C_QS_STORAGE_LONG_ONLY"):
        row=pooled_summary["L3"][cid]
        noninferior={
            "rms":row["rms_error_cm_per_day"] is not None and row["rms_error_cm_per_day"]<=baseline["rms_error_cm_per_day"]+1e-15,
            "max_abs":row["max_abs_error_cm_per_day"] is not None and row["max_abs_error_cm_per_day"]<=baseline["max_abs_error_cm_per_day"]+1e-15,
            "sign":row["flux_sign_mismatch_count"]<=baseline["flux_sign_mismatch_count"],
            "failures":row["solve_failure_count"]==0,
        }
        strict=(
            row["rms_error_cm_per_day"] is not None and row["rms_error_cm_per_day"]<baseline["rms_error_cm_per_day"]-1e-15
        ) or (
            row["max_abs_error_cm_per_day"] is not None and row["max_abs_error_cm_per_day"]<baseline["max_abs_error_cm_per_day"]-1e-15
        ) or row["flux_sign_mismatch_count"]<baseline["flux_sign_mismatch_count"]
        worse=[]
        for case in PRIMARY:
            a=case_summary[case]["L3"][cid]
            b=case_summary[case]["L3"]["C_LARE_TAYLOR"]
            if a["rms_error_cm_per_day"] is None:
                worse.append({"case":case,"reason":"solve_failure"})
            elif a["rms_error_cm_per_day"]>b["rms_error_cm_per_day"]+1e-15 and a["max_abs_error_cm_per_day"]>b["max_abs_error_cm_per_day"]+1e-15:
                worse.append({"case":case,"reason":"worse_rms_and_max"})
        adjudication[cid]={
            "component_noninferiority":noninferior,
            "strict_improvement":strict,
            "pooled_support":all(noninferior.values()) and strict,
            "broad_support":len(worse)==0,
            "supported_for_propagation":all(noninferior.values()) and strict and len(worse)==0,
            "worse_primary_cases":worse,
        }

    supported=[cid for cid,row in adjudication.items() if row["supported_for_propagation"]]
    if supported:
        decision="A2B_STORAGE_ONLY_CLOSURE_SUPPORTS_FIXED_FLUX_PROPAGATION_GATE"
        next_step="Preregister reduced-state propagation for the supported closure(s), preserving L3 as primary and L4 as resolution control."
    else:
        decision="A2B_STORAGE_ONLY_CLOSURES_NOT_BROADLY_SUPPORTED_A3_STATE_AUGMENTATION_AUTHORIZED"
        next_step="Preregister A3 with one minimal physically interpretable gradient/moment state before any new propagation or empirical correction."

    result={
        "schema":"swap5.layer-rom.phase-a2b.result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-A2B",
        "decision":decision,
        "primary_cases":list(PRIMARY),
        "observations_per_case":1024,
        "operator_scope":"long-to-local interface only; local-local interfaces retain C_LARE_TAYLOR by construction",
        "pooled_primary":pooled_summary,
        "by_case":case_summary,
        "adjudication":adjudication,
        "supported_for_propagation":supported,
        "max_qs_storage_residual_theta":max_storage_residual,
        "structural_tests":"PASS",
        "interpretation_firewalls":[
            "Teacher-forced exact projected state only; no reduced-state propagation.",
            "No fitted closure coefficient or response-dependent partition/state change.",
            "A2B changes only the unresolved long-to-local interface closure; the 10 cm to 10 cm fine-grid limit remains the source-anchored LARE closure.",
            "Application acceptance, performance and production use remain unadjudicated."
        ],
        "next":next_step,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "pooled_primary":pooled_summary,
        "adjudication":adjudication,
        "supported_for_propagation":supported,
        "max_qs_storage_residual_theta":max_storage_residual,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
