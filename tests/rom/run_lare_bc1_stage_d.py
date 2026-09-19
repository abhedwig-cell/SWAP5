#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import sys

import numpy as np

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
import run_lare_bc1_stage_b as bc1

R16_BOUNDS=[float(x) for x in range(0,161,10)]
R16_DZ=np.diff(np.asarray(R16_BOUNDS,dtype=float))
CLOSURES=("CURRENT_LAYER_FACE","OBSERVATION_LAGGED_BOTTOM_FACE")


def lagged_bottom_flux(theta:np.ndarray,k0:float,psi0:float,history:str,sym:str,lagged_k:float)->float:
    psib=bc1.boundary_psi(history,sym,psi0)
    if psib is None:
        return k0
    psi,_=bc1.psi_k(theta)
    grad=1.0+2.0*(psib-float(psi[-1]))/float(R16_DZ[-1])
    return lagged_k*grad


def rhs_lagged(y:np.ndarray,k0:float,psi0:float,history:str,sym:str,lagged_k:float)->np.ndarray:
    n=len(R16_DZ)
    theta=y[:n]/R16_DZ
    qint=bc1.interface_fluxes(theta,R16_DZ)
    qt=bc1.qtop_downward(sym,k0)
    qb=lagged_bottom_flux(theta,k0,psi0,history,sym,lagged_k)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=qt if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn
    dy[n]=qt
    dy[n+1]=qb
    return dy


def heun_step_lagged(y,dt,k0,psi0,history,sym,lagged_k):
    f0=rhs_lagged(y,k0,psi0,history,sym,lagged_k)
    guess=y+dt*f0
    n=len(R16_DZ)
    for iteration in range(1,bc1.HEUN_MAX_CORRECTOR+1):
        nxt=y+0.5*dt*(f0+rhs_lagged(guess,k0,psi0,history,sym,lagged_k))
        if np.max(np.abs(nxt[:n]/R16_DZ-guess[:n]/R16_DZ))<=bc1.HEUN_CORRECTOR_TOL_THETA:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")


def solve_lagged(history:str,dt:float)->dict[str,object]:
    ratio=bc1.OBS_DT/dt
    substeps=int(round(ratio))
    if substeps<=0 or abs(ratio-substeps)>1e-12:
        raise ValueError("dt must divide observation interval")
    bc1.PARTITIONS["R16D"]=R16_DZ.copy()
    _,y,k0,psi0=bc1.initial(history,"R16D")
    n=len(R16_DZ)
    initial_total=float(np.sum(y[:n]))
    storage=[];cumb=[];qavg=[]
    max_iter=0;max_ledger=0.0;prev_b=0.0
    for step in range(1,bc1.STEPS+1):
        sym=bc1.symbol(history,step)
        theta_start=y[:n]/R16_DZ
        _,k_start=bc1.psi_k(theta_start)
        lagged_k=float(k_start[-1])
        for _ in range(substeps):
            y,it=heun_step_lagged(y,dt,k0,psi0,history,sym,lagged_k)
            max_iter=max(max_iter,it)
        theta=y[:n]/R16_DZ
        bc1.psi_k(theta)
        total=float(np.sum(y[:n]))
        ledger=total-initial_total-(float(y[n])-float(y[n+1]))
        max_ledger=max(max_ledger,abs(ledger))
        storage.append(y[:n].copy())
        b=float(y[n+1]); cumb.append(b); qavg.append((b-prev_b)/bc1.OBS_DT); prev_b=b
    return {
        "status":"QUALIFIED",
        "dt_day":dt,
        "layer_storage_cm":np.asarray(storage).tolist(),
        "cumulative_bottom_downward_cm":cumb,
        "interval_average_bottom_downward_flux_cm_per_day":qavg,
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_iter,
    }


def solve_current(history:str,dt:float)->dict[str,object]:
    bc1.PARTITIONS["R16D"]=R16_DZ.copy()
    return bc1.solve(bc1.Case("R16D",history,"CURRENT_LAYER_FACE"),dt)


def run_route(history:str,closure:str,dt:float)->dict[str,object]:
    if closure=="CURRENT_LAYER_FACE":
        return solve_current(history,dt)
    if closure=="OBSERVATION_LAGGED_BOTTOM_FACE":
        return solve_lagged(history,dt)
    raise ValueError(closure)


def floor(a:dict[str,object],b:dict[str,object])->dict[str,float]:
    return bc1.numerical_floor(a,b)


def aggregate(rows:list[dict[str,object]])->dict[str,object]:
    return {
        "case_count":len(rows),
        "max_abs_layer_storage_error_cm":max(r["max_abs_layer_storage_error_cm"] for r in rows),
        "mean_of_case_mean_abs_layer_storage_error_cm":sum(r["mean_abs_layer_storage_error_cm"] for r in rows)/len(rows),
        "max_abs_cumulative_bottom_exchange_error_cm":max(r["max_abs_cumulative_bottom_exchange_error_cm"] for r in rows),
        "max_abs_interval_bottom_flux_error_cm_per_day":max(r["max_abs_interval_bottom_flux_error_cm_per_day"] for r in rows),
        "bottom_flux_sign_mismatch_count":sum(r["bottom_flux_sign_mismatch_count"] for r in rows),
        "reversal_sequence_mismatch_case_count":sum(not r["reversal_sequence_length_match"] for r in rows),
        "max_reversal_step_difference":max([r["max_reversal_step_difference"] for r in rows if r["max_reversal_step_difference"] is not None] or [0]),
        "max_abs_water_ledger_cm":max(r["max_abs_water_ledger_cm"] for r in rows),
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_R16_TIME_LEVEL_ATTRIBUTION"
    assert pre["fixed_geometry"]["boundaries_cm"]==[int(x) for x in R16_BOUNDS]
    ref=bc1.load_reference(args.reference)

    cases={}
    aggs={}
    for closure in CLOSURES:
        rows=[]
        for history in pre["histories"]:
            refinements={};failures={}
            for dt in bc1.HEUN_DT:
                key=f"{dt:.7f}"
                try:
                    refinements[key]=run_route(history,closure,dt)
                except ValueError as exc:
                    failures[key]=f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError,FloatingPointError) as exc:
                    failures[key]=f"NUMERICAL_BLOCKED: {exc}"
            finest=refinements.get("0.0001000")
            if finest is not None:
                status="QUALIFIED"
                metrics=bc1.compare(finest,ref[history]["steps"],R16_BOUNDS)
                rows.append(metrics)
            elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000",""):
                status="OUTSIDE_QUALIFIED_DOMAIN";metrics=None
            else:
                status="NUMERICAL_BLOCKED";metrics=None
            nf=None
            if "0.0002000" in refinements and "0.0001000" in refinements:
                nf=floor(refinements["0.0002000"],refinements["0.0001000"])
            cases[f"{closure}_{history}"]={
                "closure":closure,"history":history,"status":status,
                "metrics":metrics,"numerical_floor":nf,"failures":failures,
            }
        aggs[closure]=aggregate(rows) if rows else {"case_count":0}

    if any(aggs[c]["case_count"]!=len(pre["histories"]) for c in CLOSURES):
        decision="BC1_R16_ATTRIBUTION_BLOCKED"
        noninferior=False;improve_exchange=False;improve_flux=False
    else:
        cur=aggs["CURRENT_LAYER_FACE"]; lag=aggs["OBSERVATION_LAGGED_BOTTOM_FACE"]
        keys=[
            "max_abs_layer_storage_error_cm",
            "mean_of_case_mean_abs_layer_storage_error_cm",
            "max_abs_cumulative_bottom_exchange_error_cm",
            "max_abs_interval_bottom_flux_error_cm_per_day",
            "bottom_flux_sign_mismatch_count",
            "reversal_sequence_mismatch_case_count",
            "max_reversal_step_difference",
        ]
        noninferior=all(lag[k]<=cur[k]+1e-15 for k in keys)
        improve_exchange=lag["max_abs_cumulative_bottom_exchange_error_cm"]<cur["max_abs_cumulative_bottom_exchange_error_cm"]-1e-15
        improve_flux=lag["max_abs_interval_bottom_flux_error_cm_per_day"]<cur["max_abs_interval_bottom_flux_error_cm_per_day"]-1e-15
        if noninferior and improve_exchange and improve_flux:
            decision="BC1_R16_BOUNDARY_TIME_LEVEL_DOMINANT"
        elif improve_exchange and improve_flux:
            decision="BC1_R16_BOUNDARY_TIME_LEVEL_PARTIAL"
        else:
            decision="BC1_R16_BOUNDARY_TIME_LEVEL_NOT_DOMINANT"

    result={
        "schema":"swap5.lare.bc1.stage-d.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC1-D",
        "decision":decision,
        "geometry":"R16 16x10cm no-spatial-reduction control",
        "cases":cases,
        "aggregate":aggs,
        "adjudication":{
            "lagged_noninferior_all_preregistered_components":noninferior,
            "lagged_strictly_improves_max_cumulative_exchange":improve_exchange,
            "lagged_strictly_improves_max_interval_flux":improve_flux,
        },
        "interpretation":[
            "OBSERVATION_LAGGED_BOTTOM_FACE is a Reference-time-level attribution control only and is not promoted to LARE physics.",
            "All internal interfaces remain standard current-state LARE; any residual after lower-face lagging can include interior time-level/operator differences and Heun-versus-Reference integration semantics.",
            "No spatial grid, forcing, coefficient or application threshold is changed inside Stage D."
        ],
        "physical_closure_selected":"CURRENT_LAYER_FACE",
        "application_acceptance_adjudicated":False,
        "moving_water_table_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,"aggregate":aggs,"adjudication":result["adjudication"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
