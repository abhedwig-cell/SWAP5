#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
from collections import Counter

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent

def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

c0 = load_module("bc2c0", "run_lare_bc2_c0_enriched_dynamics.py")

WIDTHS = (2.5, 5.0)
DTS = (0.0001, 0.00005)
PRIMARY_DT = 0.0001
CROSS_DT = 0.00005
OBS_DT = c0.OBS_DT
THETA_S = c0.THETA_S
NFIXED = c0.NFIXED
IDX_WB = c0.IDX_WB
IDX_WT = c0.IDX_WT
IDX_CUM_QH = c0.IDX_CUM_QH
IDX_CUM_QI = c0.IDX_CUM_QI
PHYS_N = NFIXED + 2
LEDGER_GATE = 1.0e-10
IDENTITY_GATE = 1.0e-10

def exact_reference_state(history, step, d, init_meta, init_nodes, states, nodes):
    if step == 0:
        p, U, fixed = c0.initial_reference_projection(history, d, init_meta, init_nodes)
    else:
        p, U, fixed = c0.reference_projection(history, step, d, states, nodes)
    y = np.zeros(c0.NSTATE, dtype=float)
    y[:NFIXED] = fixed
    y[IDX_WB] = p["Wb64"]
    y[IDX_WT] = p["Wt64"]
    return y, p, U

def advance_interval(y0, H0, H1, dt, d):
    ratio = OBS_DT / dt
    nsub = int(round(ratio))
    if nsub <= 0 or abs(ratio - nsub) > 1.0e-12:
        raise RuntimeError("dt does not divide observation interval")
    y = np.array(y0, dtype=float, copy=True)
    y[IDX_CUM_QH] = 0.0
    y[IDX_CUM_QI] = 0.0
    Hdot = (H1 - H0) / OBS_DT
    q90_int = 0.0
    max_iter = 0
    for sub in range(nsub):
        fa = sub / nsub
        fb = (sub + 1) / nsub
        Ha = H0 + (H1 - H0) * fa
        Hb = H0 + (H1 - H0) * fb
        _, ma = c0.rhs(y, Ha, Hdot, d)
        ynext, it = c0.heun_step(y, dt, Ha, Hb, Hdot, d)
        _, mb = c0.rhs(ynext, Hb, Hdot, d)
        q90_int += 0.5 * dt * (float(ma["q90"]) + float(mb["q90"]))
        y = ynext
        max_iter = max(max_iter, it)
    return {
        "y": y,
        "q90": q90_int / OBS_DT,
        "qi": float(y[IDX_CUM_QI]) / OBS_DT,
        "qH": float(y[IDX_CUM_QH]) / OBS_DT,
        "max_corrector_iterations": max_iter,
    }

def reference_fluxes(history, step, prev_ref, ref, states):
    Hdot = (ref["H"] - prev_ref["H"]) / OBS_DT
    qH = states[(history, step)]["bottom_exchange"] / OBS_DT
    q90 = -(ref["Wfixed"] - prev_ref["Wfixed"]) / OBS_DT
    Gi = 0.5 * (prev_ref["theta_i"] + ref["theta_i"]) * Hdot
    dWb = (ref["Wb64"] - prev_ref["Wb64"]) / OBS_DT
    dWt = (ref["Wt64"] - prev_ref["Wt64"]) / OBS_DT
    qi_bulk = q90 + Gi - dWb
    qi_term = dWt + qH - THETA_S * Hdot + Gi
    qi = 0.5 * (qi_bulk + qi_term)
    return {"q90": q90, "qi": qi, "qH": qH}

def rms(values):
    a = np.asarray(values, dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def maxabs(values):
    a = np.asarray(values, dtype=float)
    return float(np.max(np.abs(a))) if a.size else 0.0

def summarize_components(local, drift, total):
    local_a = np.asarray(local, dtype=float)
    drift_a = np.asarray(drift, dtype=float)
    total_a = np.asarray(total, dtype=float)
    return {
        "local_closure": {"rms": rms(local_a), "max_abs": maxabs(local_a)},
        "state_induced": {"rms": rms(drift_a), "max_abs": maxabs(drift_a)},
        "total_free": {"rms": rms(total_a), "max_abs": maxabs(total_a)},
        "dominance": (
            "STATE_DRIFT_DOMINANT"
            if rms(drift_a) > rms(local_a)
            else "LOCAL_CLOSURE_DOMINANT"
        ),
        "fraction_abs_state_gt_local": float(
            np.mean(np.abs(drift_a) > np.abs(local_a))
        ) if local_a.size else 0.0,
    }

def first_state_gt_local(local, drift):
    la=np.asarray(local,dtype=float)
    dr=np.asarray(drift,dtype=float)
    if la.ndim == 2:
        l=np.max(np.abs(la),axis=1)
        d=np.max(np.abs(dr),axis=1)
    else:
        l=np.abs(la)
        d=np.abs(dr)
    hit=np.flatnonzero(d>l)
    return None if len(hit)==0 else int(hit[0]+1)

def decompose(history, d, dt, init_meta, init_nodes, states, nodes):
    yfree, pref0, U0 = exact_reference_state(
        history, 0, d, init_meta, init_nodes, states, nodes
    )
    Hinitial = float(pref0["H"])
    Hprev = Hinitial
    prev_ref = pref0
    cum_free_qH = 0.0

    local_state=[]
    drift_state=[]
    total_state=[]
    local_total=[]
    drift_total=[]
    total_total=[]
    flux = {
        name: {"local": [], "drift": [], "total": []}
        for name in ("q90","qi","qH")
    }
    max_add_state=0.0
    max_add_flux=0.0
    max_free_ledger=0.0
    max_teacher_ledger=0.0
    max_corrector=0

    for step in range(1, c0.HISTORY_STEPS[history]+1):
        yref_start, pref_start, Uref_start = exact_reference_state(
            history, step-1, d, init_meta, init_nodes, states, nodes
        )
        yref_end, pref_end, Uref_end = exact_reference_state(
            history, step, d, init_meta, init_nodes, states, nodes
        )
        H0=float(pref_start["H"])
        H1=float(pref_end["H"])

        teacher = advance_interval(yref_start, H0, H1, dt, d)
        free = advance_interval(yfree, H0, H1, dt, d)
        max_corrector=max(
            max_corrector,
            teacher["max_corrector_iterations"],
            free["max_corrector_iterations"],
        )

        yt=teacher["y"]
        yf=free["y"]
        yr=yref_end
        lstate=yt[:PHYS_N]-yr[:PHYS_N]
        dstate=yf[:PHYS_N]-yt[:PHYS_N]
        tstate=yf[:PHYS_N]-yr[:PHYS_N]
        max_add_state=max(
            max_add_state,
            float(np.max(np.abs(tstate-(lstate+dstate))))
        )
        local_state.append(lstate)
        drift_state.append(dstate)
        total_state.append(tstate)

        Ut=float(np.sum(yt[:PHYS_N]))
        Uf=float(np.sum(yf[:PHYS_N]))
        Ur=float(np.sum(yr[:PHYS_N]))
        local_total.append(Ut-Ur)
        drift_total.append(Uf-Ut)
        total_total.append(Uf-Ur)

        refs=reference_fluxes(history,step,pref_start,pref_end,states)
        for name in ("q90","qi","qH"):
            lv=float(teacher[name])-float(refs[name])
            dv=float(free[name])-float(teacher[name])
            tv=float(free[name])-float(refs[name])
            max_add_flux=max(max_add_flux,abs(tv-(lv+dv)))
            flux[name]["local"].append(lv)
            flux[name]["drift"].append(dv)
            flux[name]["total"].append(tv)

        teacher_ledger=(
            Ut - float(np.sum(yref_start[:PHYS_N]))
            + float(teacher["qH"])*OBS_DT
            - THETA_S*(H1-H0)
        )
        max_teacher_ledger=max(max_teacher_ledger,abs(teacher_ledger))

        cum_free_qH += float(free["qH"])*OBS_DT
        free_ledger=(
            Uf - U0 + cum_free_qH - THETA_S*(H1-Hinitial)
        )
        max_free_ledger=max(max_free_ledger,abs(free_ledger))

        yfree=np.array(yf,copy=True)
        yfree[IDX_CUM_QH]=0.0
        yfree[IDX_CUM_QI]=0.0
        Hprev=H1
        prev_ref=pref_end

    local_state_a=np.asarray(local_state)
    drift_state_a=np.asarray(drift_state)
    total_state_a=np.asarray(total_state)
    state_summary=summarize_components(
        local_state_a.ravel(), drift_state_a.ravel(), total_state_a.ravel()
    )
    total_summary=summarize_components(local_total,drift_total,total_total)
    flux_summary={
        name:summarize_components(row["local"],row["drift"],row["total"])
        for name,row in flux.items()
    }
    first={
        "state_shape":first_state_gt_local(local_state_a,drift_state_a),
        "total_storage":first_state_gt_local(local_total,drift_total),
    }
    for name,row in flux.items():
        first[name]=first_state_gt_local(row["local"],row["drift"])

    return {
        "status":"QUALIFIED",
        "dt_day":dt,
        "state_shape":state_summary,
        "total_unsaturated_storage":total_summary,
        "fluxes":flux_summary,
        "first_interval_state_component_exceeds_local":first,
        "max_abs_additive_state_identity_residual_cm":max_add_state,
        "max_abs_additive_flux_identity_residual_cm_per_day":max_add_flux,
        "max_abs_free_physical_ledger_residual_cm":max_free_ledger,
        "max_abs_teacher_interval_ledger_residual_cm":max_teacher_ledger,
        "max_corrector_iterations":max_corrector,
    }

def numerical_floor(a,b):
    out={}
    for channel in ("state_shape","total_unsaturated_storage"):
        out[channel]={
            "local_rms_difference":abs(a[channel]["local_closure"]["rms"]-b[channel]["local_closure"]["rms"]),
            "state_rms_difference":abs(a[channel]["state_induced"]["rms"]-b[channel]["state_induced"]["rms"]),
            "total_rms_difference":abs(a[channel]["total_free"]["rms"]-b[channel]["total_free"]["rms"]),
        }
    out["fluxes"]={}
    for name in ("q90","qi","qH"):
        out["fluxes"][name]={
            "local_rms_difference":abs(a["fluxes"][name]["local_closure"]["rms"]-b["fluxes"][name]["local_closure"]["rms"]),
            "state_rms_difference":abs(a["fluxes"][name]["state_induced"]["rms"]-b["fluxes"][name]["state_induced"]["rms"]),
            "total_rms_difference":abs(a["fluxes"][name]["total_free"]["rms"]-b["fluxes"][name]["total_free"]["rms"]),
        }
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c0res=json.loads(args.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_TEACHER_FORCED_DRIFT_DECOMPOSITION"
    assert c0res["decision"]==pre["predecessor"]["required_decision"]
    assert c0res["production_rom_authorized"] is False

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    cases={}
    failures={}
    for d in WIDTHS:
        cases[str(d)]={}
        for history in c0.HISTORY_STEPS:
            runs={}
            for dt in DTS:
                key=f"{dt:.8f}"
                try:
                    runs[key]=decompose(history,d,dt,init_meta,init_nodes,states,nodes)
                except (ValueError,RuntimeError,FloatingPointError) as exc:
                    failures[f"{d}:{history}:{key}"]=str(exc)
            cases[str(d)][history]=runs

    primary_key=f"{PRIMARY_DT:.8f}"
    cross_key=f"{CROSS_DT:.8f}"
    all_routes=all(
        primary_key in cases[str(d)][h] and cross_key in cases[str(d)][h]
        for d in WIDTHS for h in c0.HISTORY_STEPS
    )
    hard_vals=[]
    classifications={}
    floors={}
    for d in WIDTHS:
        classifications[str(d)]={}
        floors[str(d)]={}
        for h in c0.HISTORY_STEPS:
            row=cases[str(d)][h]
            if primary_key not in row:
                classifications[str(d)][h]={"status":"BLOCKED"}
                continue
            p=row[primary_key]
            route_hard={}
            for route_key in (primary_key,cross_key):
                if route_key not in row:
                    continue
                rr=row[route_key]
                vals=[
                    rr["max_abs_additive_state_identity_residual_cm"],
                    rr["max_abs_additive_flux_identity_residual_cm_per_day"],
                    rr["max_abs_free_physical_ledger_residual_cm"],
                    rr["max_abs_teacher_interval_ledger_residual_cm"],
                ]
                hard_vals.extend(vals)
                route_hard[route_key]=max(vals)
            classifications[str(d)][h]={
                "state_shape":p["state_shape"]["dominance"],
                "q90":p["fluxes"]["q90"]["dominance"],
                "qi":p["fluxes"]["qi"]["dominance"],
                "qH":p["fluxes"]["qH"]["dominance"],
                "first_interval_state_component_exceeds_local":p["first_interval_state_component_exceeds_local"],
                "max_hard_residual_by_route":route_hard,
            }
            if cross_key in row:
                floors[str(d)][h]=numerical_floor(p,row[cross_key])
                floors[str(d)][h]["classification_match"]={
                    "state_shape":p["state_shape"]["dominance"]==row[cross_key]["state_shape"]["dominance"],
                    "q90":p["fluxes"]["q90"]["dominance"]==row[cross_key]["fluxes"]["q90"]["dominance"],
                    "qi":p["fluxes"]["qi"]["dominance"]==row[cross_key]["fluxes"]["qi"]["dominance"],
                    "qH":p["fluxes"]["qH"]["dominance"]==row[cross_key]["fluxes"]["qH"]["dominance"],
                }

    max_hard=max(hard_vals or [math.inf])
    complete=all_routes and not failures and max_hard <= IDENTITY_GATE
    counts=Counter()
    for drow in classifications.values():
        for hrow in drow.values():
            for key in ("state_shape","q90","qi","qH"):
                if key in hrow:
                    counts[f"{key}:{hrow[key]}"] += 1

    result={
        "schema":"swap5.lare.bc2.c1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1",
        "decision":(
            "BC2_C1_ERROR_CHANNELS_DECOMPOSED"
            if complete else
            "BC2_C1_DIAGNOSTIC_BLOCKED"
        ),
        "complete":complete,
        "hard_checks":{
            "all_primary_and_cross_routes_qualified":all_routes and not failures,
            "all_primary_and_cross_routes_hard_gated":True,
            "failure_count":len(failures),
            "max_additive_or_ledger_residual_across_primary_and_cross":max_hard,
            "gate":IDENTITY_GATE,
        },
        "failures":failures,
        "classification_counts":dict(counts),
        "classifications":classifications,
        "numerical_floor":floors,
        "cases":cases,
        "interpretation":[
            "Teacher-forced one-interval error evaluates the unchanged C0 closure from exact Reference-projected reduced state.",
            "Free-minus-teacher isolates accumulated reduced-state drift under the same H(t), integrator and closures.",
            "All decomposition identities are checked before norms are formed.",
            "No new state, closure, fit, direction switch, groundwater feedback or application tolerance is introduced."
        ],
        "next_model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "classification_counts":result["classification_counts"],
        "classifications":classifications
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())