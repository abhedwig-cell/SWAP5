#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

from scipy.integrate import quad
from scipy.optimize import brentq

LADDER=tuple(range(10,141,10))


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
        raise ValueError((se0,mult,target,ks))
    lo,hi=(se0,1.0-1e-12) if mult>1 else (1e-10,se0)
    return brentq(lambda se:K(se)-target,lo,hi,xtol=1e-14,rtol=1e-14,maxiter=300)


def nearest_ladder(value):
    chosen=min(LADDER,key=lambda L:(abs(L-value),L))
    censored="NONE"
    if value<LADDER[0]: censored="LEFT"
    elif value>LADDER[-1]: censored="RIGHT"
    return chosen,censored


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    p=json.loads(args.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NEW_CARSEL_PARRISH_DYN0A_TRAJECTORY_GENERATION"
    T=float(p["unchanged_experiment"]["pulse_duration_day"])
    csel=float(p["trigger_authority"]["selected_discovery_global_c"])
    cbase=float(p["trigger_authority"]["baseline_discovery_global_c"])
    out={}
    for mid,mp in p["external_parameter_authority"]["materials"].items():
        theta,K,D,ks=hydraulics(mp)
        rows=[]
        for se0 in p["unchanged_experiment"]["initial_effective_saturation"]:
            se0=float(se0)
            th0=theta(se0);d0=D(th0)
            for forcing,mult in (("WET",1.5),("DRY",0.5)):
                se1=target_se(K,ks,se0,mult);th1=theta(se1);delta=abs(th1-th0)
                integ=abs(quad(lambda th:math.log(D(th)),th0,th1,epsabs=1e-12,epsrel=1e-10,limit=400)[0])
                dg=math.exp(integ/delta)
                ellg=math.sqrt(dg*T);ell0=math.sqrt(d0*T)
                contg=csel*ellg;cont0=cbase*ell0
                snapg,censg=nearest_ladder(contg)
                snap0,cens0=nearest_ladder(cont0)
                rows.append({
                    "se0":se0,"forcing":forcing,
                    "se_target":se1,
                    "ell_PATH_GEOMETRIC_D_cm":ellg,
                    "ell_LOCAL_D0_cm":ell0,
                    "PATH_GEOMETRIC_D":{
                        "continuous_peak_prediction_cm":contg,
                        "snapped_peak_prediction_cm":snapg,
                        "censoring":censg
                    },
                    "LOCAL_D0":{
                        "continuous_peak_prediction_cm":cont0,
                        "snapped_peak_prediction_cm":snap0,
                        "censoring":cens0
                    }
                })
        out[mid]=rows
    result={
        "schema":"swap5.lare.dyn0a.mech3b.predictions.v1",
        "work_unit":"LARE-DYN0A-MECH3B",
        "generated_before_new_reference_trajectory":True,
        "selected_scale":"PATH_GEOMETRIC_D",
        "selected_global_c":csel,
        "baseline_scale":"LOCAL_D0",
        "baseline_global_c":cbase,
        "ladder_cm":list(LADDER),
        "materials":out,
        "response_data_used":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
