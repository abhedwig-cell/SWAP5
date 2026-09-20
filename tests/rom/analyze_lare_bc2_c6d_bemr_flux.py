#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares


def load_module(name: str, path: pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def raw_history_lines(path: pathlib.Path, history: str, prefix: str):
    token=f"|HISTORY={history}|"
    return [line for line in path.read_text(errors="replace").splitlines()
            if line.startswith(prefix) and token in line]


def parse_new(path: pathlib.Path, history: str, c5t):
    layers={}; faces={}; moments={}; bounds={}
    raw={"state":[],"profile":[],"layer":[],"face":[]}
    for line in path.read_text(errors="replace").splitlines():
        if f"|HISTORY={history}|" not in line:
            continue
        if line.startswith("LAREGW1_STATE|"):
            raw["state"].append(line)
        elif line.startswith("LAREGW1_PROFILE|"):
            raw["profile"].append(line)
        elif line.startswith("LAREGW1_C5T_LAYER|"):
            raw["layer"].append(line)
            r=c5t.fields(line.split("|",1)[1])
            layers[(int(r["OBS_STEP"]),int(r["LAYER"]))]=float(r["STORAGE_CM"])
        elif line.startswith("LAREGW1_C5T_FACE|"):
            raw["face"].append(line)
            r=c5t.fields(line.split("|",1)[1])
            faces[(int(r["OBS_STEP"]),float(r["DEPTH_CM"]))]={k:float(r[k]) for k in ("H_UP","H_DOWN","THETA_UP","THETA_DOWN")}
        elif line.startswith("LAREGW1_C6D_MOMENT|"):
            r=c5t.fields(line.split("|",1)[1])
            moments[(int(r["OBS_STEP"]),int(r["LAYER"]))]=float(r["MOMENT_CM2"])
        elif line.startswith("LAREGW1_C6D_BOUNDARY|"):
            r=c5t.fields(line.split("|",1)[1])
            bounds[int(r["OBS_STEP"])]={
                "top_flux_native":float(r["TOP_FLUX_NATIVE"]),
                "bottom_head_native":float(r["BOTTOM_HEAD_NATIVE"]),
                "bottom_mode":int(r["BOTTOM_MODE"]),
            }
    return layers,faces,moments,bounds,raw


def baseline_raw(path: pathlib.Path, history: str):
    out={}
    for key,prefix in (
        ("state","LAREGW1_STATE|"),
        ("profile","LAREGW1_PROFILE|"),
        ("layer","LAREGW1_C5T_LAYER|"),
        ("face","LAREGW1_C5T_FACE|")):
        out[key]=raw_history_lines(path,history,prefix)
    return out


def strict_moment_realizable(core, ses, moments, widths):
    for se,m,d in zip(ses,moments,widths):
        if not (core.SE_LO <= se <= core.SE_HI):
            return False
        if abs(m)>core.mmax_bounded(float(se),float(d))+1e-12:
            return False
    return True


def base_start(core, ses, moments, widths):
    return np.concatenate([
        core.base_coeff_for_layer(float(se),float(m),float(d))
        for se,m,d in zip(ses,moments,widths)
    ])


def solve(core, c6c, case, x0):
    opts=c6c["numerical_contract"]["solver_options"]
    res=least_squares(
        lambda x: core.residual_vector(x,case,c6c),
        x0,
        method="trf",
        xtol=float(opts["xtol"]),
        ftol=float(opts["ftol"]),
        gtol=float(opts["gtol"]),
        max_nfev=int(opts["max_nfev"]),
    )
    diag=None
    try:
        diag=core.physical_diagnostics(res.x,case,c6c)
    except Exception:
        pass
    return res,diag


def qualified(res,diag,c6c):
    if not res.success or diag is None:
        return False
    g=c6c["numerical_contract"]["physical_residual_gates"]
    q=c6c["numerical_contract"]["quadrature_consistency_gates"]
    return (
        core_bounds(diag)
        and diag["max_abs_interface_pressure_jump_cm"]<=float(g["max_abs_interface_pressure_jump_cm"])
        and diag["max_abs_interface_flux_jump_cm_per_day"]<=float(g["max_abs_interface_flux_jump_cm_per_day"])
        and diag["abs_top_flux_residual_cm_per_day"]<=float(g["max_abs_top_flux_residual_cm_per_day"])
        and diag["abs_bottom_pressure_residual_cm"]<=float(g["max_abs_bottom_pressure_residual_cm"])
        and diag["max_abs_storage_recovery_cm"]<=float(g["max_abs_storage_recovery_cm"])
        and diag["max_abs_moment_recovery_cm2"]<=float(g["max_abs_moment_recovery_cm2"])
        and diag["max_abs_96_192_storage_delta_cm"]<=float(q["max_abs_storage_delta_cm"])
        and diag["max_abs_96_192_moment_delta_cm2"]<=float(q["max_abs_moment_delta_cm2"])
    )


def core_bounds(diag):
    return 0.02-1e-14<=diag["Se_min"] and diag["Se_max"]<=0.995+1e-14


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--instrumented",required=True,type=pathlib.Path)
    ap.add_argument("--c5t-baseline",required=True,type=pathlib.Path)
    ap.add_argument("--history",required=True,choices=("R01","R02","R03","R04"))
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6c-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6c-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c6c-core",required=True,type=pathlib.Path)
    ap.add_argument("--c5t-analyzer",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c6c=json.loads(a.c6c_prereg.read_text())
    close=json.loads(a.c6c_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C6D_INSTRUMENTED_RESPONSE_OR_OPERATOR_METRICS"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    assert close["adjudication"]["BEMR_MATHEMATICALLY_QUALIFIED"] is True

    core=load_module("c6c_core",a.c6c_core)
    c5t=load_module("c5t_base",a.c5t_analyzer)
    global core_bounds

    layers,faces,moments,bounds,raw=parse_new(a.instrumented,a.history,c5t)
    brow=baseline_raw(a.c5t_baseline,a.history)
    identity={k:raw[k]==brow[k] for k in raw}
    identity.update({f"{k}_count":len(raw[k]) for k in raw})
    expected={"state":16384,"profile":16384,"layer":12288,"face":11264}
    for k,n in expected.items():
        if len(raw[k])!=n:
            raise RuntimeError(f"{a.history} wrong {k} count {len(raw[k])} != {n}")
    if not all(identity[k] for k in ("state","profile","layer","face")):
        raise RuntimeError(f"{a.history} C6D logging changed C5T/C5R trajectory or prior diagnostics")
    if len(moments)!=12288 or len(bounds)!=1024:
        raise RuntimeError(f"{a.history} wrong C6D diagnostic counts moments={len(moments)} bounds={len(bounds)}")

    widths=np.asarray(p["retained_representation"]["widths_cm"],dtype=float)
    depths=np.asarray(p["primary_interfaces_cm"]+p["secondary_interfaces_cm"],dtype=float)
    depths=np.asarray(sorted(set(float(x) for x in depths)),dtype=float)
    records=[]
    failures=[]
    warm=None
    maxima={
      "max_branch_theta":0.0,"max_branch_pressure_cm":0.0,"max_branch_flux_cm_per_day":0.0,
      "max_interface_pressure_jump_cm":0.0,"max_interface_flux_jump_cm_per_day":0.0,
      "max_storage_recovery_cm":0.0,"max_moment_recovery_cm2":0.0,
      "min_Se":math.inf,"max_Se":-math.inf,
    }
    qualified_obs=0
    realizable_obs=0

    for obs in range(1,577):
        b=bounds[obs]
        if b["bottom_mode"]!=5:
            failures.append({"obs":obs,"class":"BOTTOM_MODE_NOT_PRESCRIBED_HEAD","bottom_mode":b["bottom_mode"]})
            warm=None
            continue
        stor=np.asarray([layers[(obs,i)] for i in range(1,13)],dtype=float)
        moms=np.asarray([moments[(obs,i)] for i in range(1,13)],dtype=float)
        means=stor/widths
        ses=np.asarray(core.se_from_theta(means),dtype=float)
        if strict_moment_realizable(core,ses,moms,widths):
            realizable_obs+=1
        else:
            failures.append({"obs":obs,"class":"STATE_MOMENT_NOT_REALIZABLE"})
            warm=None
            continue
        case={
          "widths":widths.tolist(),
          "storages":stor.tolist(),
          "moments":moms.tolist(),
          "ses":ses.tolist(),
          "means":means.tolist(),
          "psi_bottom":-float(b["bottom_head_native"]),
          "qtop":-float(b["top_flux_native"]),
        }
        base=base_start(core,ses,moms,widths)
        primary0=base if warm is None else warm
        r1,d1=solve(core,c6c,case,primary0)
        r2,d2=solve(core,c6c,case,base)
        q1=qualified(r1,d1,c6c)
        q2=qualified(r2,d2,c6c)
        agree=False
        dt=dp=dq=math.inf
        if q1 and q2:
            dt,dp,dq=core.solution_distance(r1.x,r2.x,case,c6c)
            ag=c6c["numerical_contract"]["solution_agreement_across_starts"]
            agree=(dt<=float(ag["max_abs_theta_difference"]) and
                   dp<=float(ag["max_abs_face_pressure_difference_cm"]) and
                   dq<=float(ag["max_abs_face_flux_difference_cm_per_day"]))
        if not(q1 and q2 and agree):
            failures.append({
              "obs":obs,"class":"BEMR_NUMERICAL_QUALIFICATION_FAILURE",
              "primary_success":bool(r1.success),"independent_success":bool(r2.success),
              "primary_qualified":bool(q1),"independent_qualified":bool(q2),
              "branch_theta":dt,"branch_pressure_cm":dp,"branch_flux_cm_per_day":dq
            })
            warm=None
            continue

        warm=r1.x.copy()
        qualified_obs+=1
        maxima["max_branch_theta"]=max(maxima["max_branch_theta"],dt)
        maxima["max_branch_pressure_cm"]=max(maxima["max_branch_pressure_cm"],dp)
        maxima["max_branch_flux_cm_per_day"]=max(maxima["max_branch_flux_cm_per_day"],dq)
        maxima["max_interface_pressure_jump_cm"]=max(maxima["max_interface_pressure_jump_cm"],d1["max_abs_interface_pressure_jump_cm"])
        maxima["max_interface_flux_jump_cm_per_day"]=max(maxima["max_interface_flux_jump_cm_per_day"],d1["max_abs_interface_flux_jump_cm_per_day"])
        maxima["max_storage_recovery_cm"]=max(maxima["max_storage_recovery_cm"],d1["max_abs_storage_recovery_cm"])
        maxima["max_moment_recovery_cm2"]=max(maxima["max_moment_recovery_cm2"],d1["max_abs_moment_recovery_cm2"])
        maxima["min_Se"]=min(maxima["min_Se"],d1["Se_min"])
        maxima["max_Se"]=max(maxima["max_Se"],d1["Se_max"])

        ph=c5t.phase(a.history,obs)
        for iface,dep in enumerate(depths):
            original_index=int(np.where(np.isclose(np.asarray([70.,80.,90.,100.,110.,120.,130.,140.,150.,155.,157.5]),dep))[0][0])
            di=float(widths[original_index]); dj=float(widths[original_index+1]); L=0.5*(di+dj)
            tu=float(means[original_index]); td=float(means[original_index+1])
            pu=float(c5t.theta_to_psi([tu])[0]); pd=float(c5t.theta_to_psi([td])[0])
            ku=float(c5t.k_from_theta([tu])[0]); kd=float(c5t.k_from_theta([td])[0])
            kb=(dj*ku+di*kd)/(di+dj)
            qcurrent=kb*(1.0+(pd-pu)/L)
            fr=faces[(obs,float(dep))]
            kfu=float(c5t.k_from_theta([fr["THETA_UP"]])[0]); kfd=float(c5t.k_from_theta([fr["THETA_DOWN"]])[0])
            qref=0.5*(kfu+kfd)*(1.0+(fr["H_UP"]-fr["H_DOWN"])/0.078125)
            qb=0.5*(float(d1["bottom_faces"][original_index]["q"])+float(d1["top_faces"][original_index+1]["q"]))
            records.append({
              "history":a.history,"obs":obs,"phase":ph,"depth":float(dep),
              "q_ref":qref,"q_current":qcurrent,"q_bemr":qb,
              "e_current":qcurrent-qref,"e_bemr":qb-qref
            })

    out={
      "schema":"swap5.lare.bc2.c6d.history-result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6D",
      "history":a.history,
      "identity":identity,
      "moving_observation_count":576,
      "strict_state_moment_realizable_count":realizable_obs,
      "numerically_qualified_observation_count":qualified_obs,
      "numerical_qualification_pass":qualified_obs==576 and not failures,
      "failure_count":len(failures),
      "failures":failures[:50],
      "diagnostic_extrema":maxima,
      "records":records,
      "scientific_firewall":{
        "blind_validation":False,"candidate_feedback":False,
        "production_reference_changed":False,"free_running_bemr_implemented":False,
        "moment_fitting":False,"moment_localization":False,"c6c_retuning":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "history":a.history,
      "identity":identity,
      "realizable":realizable_obs,
      "qualified":qualified_obs,
      "failures":len(failures),
      "extrema":maxima,
    },sort_keys=True))


if __name__=="__main__":
    main()
