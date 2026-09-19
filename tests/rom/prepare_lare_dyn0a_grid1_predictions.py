#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

from scipy.integrate import quad
from scipy.optimize import brentq

LADDER=tuple(range(20,141,10))


def hydraulics(p):
    tr=float(p["theta_r"]);ts=float(p["theta_s"]);a=float(p["alpha_per_cm"])
    n=float(p["n"]);ks=float(p["Ksat_cm_per_day"]);lam=float(p["lambda"])
    m=1.0-1.0/n
    def theta(se): return tr+(ts-tr)*se
    def K(se):
        return ks*se**lam*(1.0-(1.0-se**(1.0/m))**m)**2
    def D(th):
        se=(th-tr)/(ts-tr)
        x=se**(-1.0/m)-1.0
        dhdse=(1.0/(a*n*m))*x**(1.0/n-1.0)*se**(-1.0/m-1.0)
        return K(se)*dhdse/(ts-tr)
    return theta,K,D,ks


def target_se(K,ks,se0,mult):
    target=mult*K(se0)
    if not 0.0<target<ks:
        raise ValueError("CONSTITUTIVE_TARGET_OUTSIDE_UNSATURATED_DOMAIN")
    lo,hi=(se0,1.0-1e-12) if mult>1.0 else (1e-10,se0)
    return brentq(lambda se:K(se)-target,lo,hi,xtol=1e-14,rtol=1e-14,maxiter=300)


def snap(value):
    chosen=min(LADDER,key=lambda L:(abs(L-value),L))
    if value<LADDER[0]:return chosen,"LEFT"
    if value>LADDER[-1]:return chosen,"RIGHT"
    return chosen,"NONE"


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    p=json.loads(args.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NEW_PATH_GUIDED_GRID_REFERENCE_TRAJECTORIES"
    T=float(p["experiment"]["pulse_duration_day"])
    c=float(p["trigger_authority"]["global_c"])

    materials={}
    for mid,mp in p["external_material_authority"]["materials"].items():
        theta,K,D,ks=hydraulics(mp)
        rows=[]
        for se0 in p["experiment"]["initial_effective_saturation"]:
            se0=float(se0)
            th0=theta(se0)
            for forcing,mult in (("WET",1.5),("DRY",0.5)):
                try:
                    se1=target_se(K,ks,se0,mult)
                    th1=theta(se1)
                    delta=abs(th1-th0)
                    integ=abs(quad(lambda th:math.log(D(th)),th0,th1,epsabs=1e-12,epsrel=1e-10,limit=400)[0])
                    dg=math.exp(integ/delta)
                    ell=math.sqrt(dg*T)
                    cont=c*ell
                    snapped,censor=snap(cont)
                    status="GRID_PREDICTION_OUTSIDE_DESIGN_DOMAIN" if censor!="NONE" else "GRID_PREDICTION_QUALIFIED"
                    boundaries=None if censor!="NONE" else [0,snapped-10,snapped,snapped+10,160]
                    rows.append({
                        "se0":se0,"forcing":forcing,
                        "status":status,
                        "se_target":se1,
                        "D_PATH_GEOMETRIC_cm2_per_day":dg,
                        "penetration_length_cm":ell,
                        "continuous_L_pred_cm":cont,
                        "snapped_L_star_cm":snapped,
                        "censoring":censor,
                        "PATH_R4_boundaries_cm":boundaries
                    })
                except ValueError as exc:
                    rows.append({
                        "se0":se0,"forcing":forcing,
                        "status":str(exc),
                        "PATH_R4_boundaries_cm":None
                    })
        materials[mid]=rows

    result={
        "schema":"swap5.lare.dyn0a.grid1.predictions.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-GRID1",
        "generated_before_new_reference_trajectory":True,
        "selected_scale":"PATH_GEOMETRIC_D",
        "global_c":c,
        "pulse_duration_day":T,
        "ladder_cm":list(LADDER),
        "materials":materials,
        "qualified_prediction_count":sum(row["status"]=="GRID_PREDICTION_QUALIFIED" for rows in materials.values() for row in rows),
        "censored_prediction_count":sum(row["status"]=="GRID_PREDICTION_OUTSIDE_DESIGN_DOMAIN" for rows in materials.values() for row in rows),
        "response_data_used":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
