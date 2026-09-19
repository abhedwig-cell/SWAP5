#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

import numpy as np

OBS_DT=0.0008
TPULSE=256*OBS_DT
SE_BY_INDEX={1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX={1:"EQ",2:"WET",3:"DRY",4:"WET_DRY"}
LADDER=list(range(10,141,10))


def fields(payload):
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out


def make_hydraulics(mvg):
    tr=float(mvg["theta_r"]);ts=float(mvg["theta_s"]);a=float(mvg["alpha_per_cm"])
    n=float(mvg["n"]);ks=float(mvg["Ksat_cm_per_day"]);lam=float(mvg["lambda"])
    m=1.0-1.0/n
    def psi_from_theta(theta):
        se=(theta-tr)/(ts-tr)
        if not 0.0<se<1.0: raise ValueError(se)
        return ((se**(-1.0/m)-1.0)**(1.0/n))/a
    def k_from_theta(theta):
        se=(theta-tr)/(ts-tr)
        if not 0.0<se<1.0: raise ValueError(se)
        return ks*se**lam*(1.0-(1.0-se**(1.0/m))**m)**2
    def k_from_h(h):
        se=(1.0+(a*abs(h))**n)**(-m)
        return ks*se**lam*(1.0-(1.0-se**(1.0/m))**m)**2
    return psi_from_theta,k_from_theta,k_from_h


def load_case(path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"): continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),"z":float(d["Z"]),"dz":float(d["DZ"]),
            "h":float(d["H"]),"theta":float(d["THETA"])
        })
    if set(rows)!=set(range(1,1025)): raise ValueError(f"incomplete {path}")
    for step in rows: rows[step].sort(key=lambda r:r["node"])
    return dict(rows)


def layer_mean(rows,lo,hi):
    width=hi-lo;covered=0.0;th=0.0
    for r in rows:
        c=abs(r["z"]);a=max(lo,c-r["dz"]/2);b=min(hi,c+r["dz"]/2)
        if b<=a: continue
        w=b-a;covered+=w;th+=r["theta"]*w
    if abs(covered-width)>1e-9: raise ValueError((lo,hi,covered))
    return th/width


def flux_error(rows,L,psi_from_theta,k_from_theta,k_from_h):
    tu=layer_mean(rows,0.0,float(L))
    tl=layer_mean(rows,float(L),float(L+10))
    pu=psi_from_theta(tu);pl=psi_from_theta(tl)
    ku=k_from_theta(tu);kl=k_from_theta(tl)
    du=float(L);dl=10.0
    kface=(dl*ku+du*kl)/(du+dl)
    ql=kface*(1.0+2.0*(pl-pu)/(du+dl))
    iu=L//10;il=iu+1
    ru=rows[iu-1];rl=rows[il-1]
    kr=0.5*(k_from_h(ru["h"])+k_from_h(rl["h"]))
    qr=kr*(1.0+((-rl["h"])-(-ru["h"]))/10.0)
    return ql-qr


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def lookup_prediction(pred,material,se0,forcing):
    matches=[
        row for row in pred["materials"][material]
        if abs(float(row["se0"])-se0)<1e-12 and row["forcing"]==forcing
    ]
    if len(matches)!=1: raise ValueError((material,se0,forcing,len(matches)))
    return matches[0]


def summarize(rows,scale):
    if not rows: return None
    logs=np.asarray([math.log(row[f"lambda_{scale}"]) for row in rows],float)
    errors=np.asarray([abs(row[f"log_prediction_error_{scale}"]) for row in rows],float)
    material_means=[]
    by_material={}
    for material in sorted({row["material"] for row in rows}):
        vals=np.asarray([math.log(row[f"lambda_{scale}"]) for row in rows if row["material"]==material],float)
        mean=float(np.mean(vals));by_material[material]=mean;material_means.append(mean)
    return {
        "case_count":len(rows),
        "pooled_ln_lambda_std":float(np.std(logs,ddof=0)),
        "between_material_mean_ln_lambda_std":float(np.std(np.asarray(material_means),ddof=0)),
        "material_mean_ln_lambda":by_material,
        "rms_log_prediction_error":float(math.sqrt(float(np.mean(errors**2)))),
        "median_abs_log_prediction_error":float(np.median(errors)),
        "max_abs_log_prediction_error":float(np.max(errors)),
        "exact_snapped_L_hit_count":sum(int(row[f"snapped_hit_{scale}"]) for row in rows),
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--predictions",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    p=json.loads(args.prereg.read_text())
    status=json.loads(args.status.read_text())
    pred=json.loads(args.predictions.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NEW_CARSEL_PARRISH_DYN0A_TRAJECTORY_GENERATION"
    assert pred["generated_before_new_reference_trajectory"] is True
    assert pred["response_data_used"] is False
    materials=p["external_parameter_authority"]["materials"]

    rows=[]
    exclusions=[]
    usable_material={}
    for material,mvg in materials.items():
        psi_from_theta,k_from_theta,k_from_h=make_hydraulics(mvg)
        qcases=0;has_wet=False;has_dry=False
        for si,se0 in SE_BY_INDEX.items():
            for fi,forcing in ((2,"WET"),(3,"DRY")):
                cid=f"S{si}_B1_F{fi}"
                st=status["materials"][material][cid]["status"]
                if st!="QUALIFIED":
                    exclusions.append({"material":material,"case":cid,"se0":se0,"forcing":forcing,"status":st})
                    continue
                qcases+=1;has_wet|=forcing=="WET";has_dry|=forcing=="DRY"
                traj=load_case(args.reference_dir/f"fine-{material}-{cid}-o2.txt")
                ladder={}
                for L in LADDER:
                    errs=[flux_error(traj[step],L,psi_from_theta,k_from_theta,k_from_h) for step in range(1,257)]
                    ladder[L]={
                        "pulse_rms_flux_error_cm_per_day":rms(errs),
                        "pulse_max_abs_flux_error_cm_per_day":max(abs(x) for x in errs)
                    }
                peak=max(LADDER,key=lambda L:ladder[L]["pulse_rms_flux_error_cm_per_day"])
                pr=lookup_prediction(pred,material,se0,forcing)
                ellg=float(pr["ell_PATH_GEOMETRIC_D_cm"]);ell0=float(pr["ell_LOCAL_D0_cm"])
                cg=float(pr["PATH_GEOMETRIC_D"]["continuous_peak_prediction_cm"])
                c0=float(pr["LOCAL_D0"]["continuous_peak_prediction_cm"])
                sg=int(pr["PATH_GEOMETRIC_D"]["snapped_peak_prediction_cm"])
                s0=int(pr["LOCAL_D0"]["snapped_peak_prediction_cm"])
                rows.append({
                    "material":material,"case":cid,"se0":se0,"forcing":forcing,
                    "observed_peak_L_cm":peak,
                    "observed_peak_rms_flux_error_cm_per_day":ladder[peak]["pulse_rms_flux_error_cm_per_day"],
                    "lambda_PATH_GEOMETRIC_D":peak/ellg,
                    "lambda_LOCAL_D0":peak/ell0,
                    "continuous_prediction_PATH_GEOMETRIC_D_cm":cg,
                    "continuous_prediction_LOCAL_D0_cm":c0,
                    "snapped_prediction_PATH_GEOMETRIC_D_cm":sg,
                    "snapped_prediction_LOCAL_D0_cm":s0,
                    "snapped_hit_PATH_GEOMETRIC_D":peak==sg,
                    "snapped_hit_LOCAL_D0":peak==s0,
                    "log_prediction_error_PATH_GEOMETRIC_D":math.log(peak/cg),
                    "log_prediction_error_LOCAL_D0":math.log(peak/c0),
                    "selected_prediction_censoring":pr["PATH_GEOMETRIC_D"]["censoring"],
                    "baseline_prediction_censoring":pr["LOCAL_D0"]["censoring"],
                })
        usable_material[material]={
            "qualified_WET_DRY_case_count":qcases,
            "has_WET":has_wet,
            "has_DRY":has_dry,
            "usable_for_minimum":qcases>=2 and has_wet and has_dry
        }

    usable_count=sum(int(v["usable_for_minimum"]) for v in usable_material.values())
    panel_ok=usable_count>=2 and len(rows)>=10
    selected=summarize(rows,"PATH_GEOMETRIC_D") if panel_ok else None
    baseline=summarize(rows,"LOCAL_D0") if panel_ok else None
    checks={}
    if panel_ok:
        checks={
            "pooled_ln_lambda_std_improved":selected["pooled_ln_lambda_std"]<baseline["pooled_ln_lambda_std"],
            "between_material_mean_ln_lambda_std_improved":selected["between_material_mean_ln_lambda_std"]<baseline["between_material_mean_ln_lambda_std"],
            "rms_log_prediction_error_improved":selected["rms_log_prediction_error"]<baseline["rms_log_prediction_error"],
        }
        n=sum(checks.values())
        decision=(
            "NONLINEAR_SCALE_TRANSFER_SUPPORTED" if n==3 else
            "NONLINEAR_SCALE_TRANSFER_PARTIAL" if n>0 else
            "NONLINEAR_SCALE_TRANSFER_NOT_SUPPORTED"
        )
    else:
        decision="BLIND_PANEL_REFERENCE_INSUFFICIENT"

    result={
        "schema":"swap5.lare.dyn0a.mech3b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH3B",
        "decision":decision,
        "reference_panel_sufficient":panel_ok,
        "usable_materials":usable_material,
        "qualified_WET_DRY_case_count":len(rows),
        "excluded_WET_DRY_cases":exclusions,
        "case_results":rows,
        "selected_scale_metrics":selected,
        "baseline_scale_metrics":baseline,
        "primary_transfer_checks":checks,
        "interpretation_firewall":[
            "Carsel-Parrish SAND, LOAM and CLAY were frozen before their DYN0A trajectories were generated.",
            "The selected PATH_GEOMETRIC_D formula and global discovery constant were frozen from MECH3A; no blind-panel refit is allowed.",
            "Reference-domain exclusions follow the preregistered unchanged numerical authority and are reported rather than repaired.",
            "This is a mechanism scaling test only, not application acceptance or LARE production qualification."
        ],
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "qualified_WET_DRY_case_count":len(rows),
        "usable_materials":usable_material,
        "selected_scale_metrics":selected,
        "baseline_scale_metrics":baseline,
        "primary_transfer_checks":checks,
        "excluded_WET_DRY_cases":exclusions
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
