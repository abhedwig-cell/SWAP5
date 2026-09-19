#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name, filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

DT=0.00005
EPSILONS=(1.0e-6,5.0e-7)
GATE=1.0e-10
WIDTHS=(2.5,5.0)
HISTORIES=tuple(c0.HISTORY_STEPS)

def rms(a):
    x=np.asarray(a,dtype=float)
    return float(np.sqrt(np.mean(x*x))) if x.size else 0.0

def thicknesses(H,d):
    B=H-c0.ANCHOR-d
    if B<=0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    return np.asarray([c0.FIXED_DZ]*c0.NFIXED+[B,d],dtype=float)

def shape_coordinates(delta_w,H,d):
    L=thicknesses(H,d)
    dw=np.asarray(delta_w,dtype=float)
    raw=dw/L
    uniform=float(np.sum(dw))/float(np.sum(L))
    shape=raw-uniform
    return {
        "raw":raw,
        "shape":shape,
        "shape_rms":rms(shape),
        "raw_rms":rms(raw),
        "total_storage_cm":float(np.sum(dw)),
        "mass_neutral_residual_cm":float(np.sum(L*shape)),
    }

def reference_H(history,step,d,init_meta,init_nodes,states,nodes):
    _,p,_=c1.exact_reference_state(history,step,d,init_meta,init_nodes,states,nodes)
    return float(p["H"])

def selected_boundaries(history,d,init_meta,init_nodes,states,nodes):
    n=c0.HISTORY_STEPS[history]
    out={0,n//4,n//2,(3*n)//4}
    H=[reference_H(history,s,d,init_meta,init_nodes,states,nodes) for s in range(n+1)]
    signs=[]
    for s in range(n):
        dh=H[s+1]-H[s]
        signs.append(1 if dh>0 else -1 if dh<0 else 0)
    prev_nonzero=None
    for idx,sgn in enumerate(signs):
        if sgn==0:
            continue
        if prev_nonzero is not None and sgn!=prev_nonzero:
            # A direction change between increments idx-1 and idx occurs at
            # state idx. The preregistered blind panel adds the start state of
            # the interval immediately preceding that switch: idx-1.
            out.add(max(0,idx-1))
        prev_nonzero=sgn
    return sorted(s for s in out if 0<=s<n)

def perturbation(y,H,d,i,epsilon,sign):
    L=thicknesses(H,d)
    j=i+1
    delta=np.zeros(c1.PHYS_N,dtype=float)
    delta[i]=sign*epsilon*L[i]
    delta[j]=-sign*epsilon*L[i]
    yp=np.array(y,dtype=float,copy=True)
    yp[:c1.PHYS_N]+=delta
    yp[c1.IDX_CUM_QH]=0.0
    yp[c1.IDX_CUM_QI]=0.0
    # Validate the exact starting state before any integration.
    c0.hydraulic_state(yp,H,d)
    return yp,delta

def branch_ledger(y0,y1,qH,H0,H1):
    return (
        float(np.sum(y1[:c1.PHYS_N]))
        -float(np.sum(y0[:c1.PHYS_N]))
        +float(qH)*c1.OBS_DT
        -c1.THETA_S*(H1-H0)
    )

def run_case(history,d,init_meta,init_nodes,states,nodes):
    boundaries=selected_boundaries(history,d,init_meta,init_nodes,states,nodes)
    records=[]
    skips=[]
    runtime_failures=[]
    max_ledger=0.0
    max_mass_neutral=0.0

    for start in boundaries:
        yref,p0,_=c1.exact_reference_state(history,start,d,init_meta,init_nodes,states,nodes)
        _,p1,_=c1.exact_reference_state(history,start+1,d,init_meta,init_nodes,states,nodes)
        H0=float(p0["H"]); H1=float(p1["H"])

        for mode in range(c1.PHYS_N-1):
            by_eps={}
            for eps in EPSILONS:
                try:
                    yp,dp=perturbation(yref,H0,d,mode,eps,+1.0)
                    ym,dm=perturbation(yref,H0,d,mode,eps,-1.0)
                    rp=c1.advance_interval(yp,H0,H1,DT,d)
                    rm=c1.advance_interval(ym,H0,H1,DT,d)
                except ValueError as exc:
                    skips.append({
                        "history":history,"width_cm":d,"start_step":start,
                        "mode":[mode,mode+1],"epsilon_theta":eps,
                        "reason":str(exc),
                    })
                    continue
                except (RuntimeError,FloatingPointError) as exc:
                    runtime_failures.append({
                        "history":history,"width_cm":d,"start_step":start,
                        "mode":[mode,mode+1],"epsilon_theta":eps,
                        "reason":str(exc),
                    })
                    continue

                ledp=branch_ledger(yp,rp["y"],rp["qH"],H0,H1)
                ledm=branch_ledger(ym,rm["y"],rm["qH"],H0,H1)
                max_ledger=max(max_ledger,abs(ledp),abs(ledm))

                input_half=0.5*(dp-dm)
                output_half=0.5*(
                    rp["y"][:c1.PHYS_N]-rm["y"][:c1.PHYS_N]
                )
                inp=shape_coordinates(input_half,H0,d)
                out=shape_coordinates(output_half,H1,d)
                max_mass_neutral=max(
                    max_mass_neutral,
                    abs(float(inp["mass_neutral_residual_cm"])),
                    abs(float(out["mass_neutral_residual_cm"])),
                )
                if float(inp["shape_rms"])<=0.0:
                    raise RuntimeError("zero tangent input norm")
                gain=float(out["shape_rms"])/float(inp["shape_rms"])
                by_eps[f"{eps:.8g}"]={
                    "epsilon_theta":eps,
                    "input_shape_theta_rms":float(inp["shape_rms"]),
                    "output_shape_theta_rms":float(out["shape_rms"]),
                    "directional_shape_gain":gain,
                    "differential_total_storage_response_cm":float(out["total_storage_cm"]),
                    "plus_ledger_residual_cm":ledp,
                    "minus_ledger_residual_cm":ledm,
                }

            if by_eps:
                gains=[v["directional_shape_gain"] for v in by_eps.values()]
                consistency=None
                if len(gains)==2:
                    consistency=abs(gains[0]-gains[1])/max(abs(gains[0]),abs(gains[1]),1.0e-300)
                records.append({
                    "history":history,
                    "width_cm":d,
                    "start_step":start,
                    "H_start_cm":H0,
                    "H_end_cm":H1,
                    "adjacent_mode":[mode,mode+1],
                    "amplitudes":by_eps,
                    "amplitude_consistency_relative_difference":consistency,
                    "max_directional_shape_gain":max(gains),
                })

    by_state={}
    for row in records:
        key=str(row["start_step"])
        s=by_state.setdefault(key,{
            "start_step":row["start_step"],
            "max_directional_shape_gain":0.0,
            "dominant_adjacent_mode":None,
            "record_count":0,
        })
        s["record_count"]+=1
        if row["max_directional_shape_gain"]>s["max_directional_shape_gain"]:
            s["max_directional_shape_gain"]=row["max_directional_shape_gain"]
            s["dominant_adjacent_mode"]=row["adjacent_mode"]

    return {
        "status":"QUALIFIED" if not runtime_failures and max_ledger<=GATE and max_mass_neutral<=GATE else "NUMERICAL_DIAGNOSTIC_BLOCKED",
        "history":history,
        "width_cm":d,
        "selected_start_steps":boundaries,
        "perturbation_amplitudes_theta":list(EPSILONS),
        "records":records,
        "skipped_constitutive_directions":skips,
        "runtime_failures":runtime_failures,
        "state_summaries":list(by_state.values()),
        "max_abs_branch_ledger_residual_cm":max_ledger,
        "max_abs_mass_neutral_projection_residual_cm":max_mass_neutral,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1r-result",required=True,type=pathlib.Path)
    ap.add_argument("--c2a-result",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c1r=json.loads(args.c1r_result.read_text())
    c2a=json.loads(args.c2a_result.read_text())
    binding=json.loads(args.binding.read_text())
    assert pre["phase"]=="PREREGISTERED_CONDITIONALLY_BEFORE_C1R_RESULT_EXPOSURE"
    assert tuple(pre["diagnostic_B_blind_tangent_panel"]["perturbation_amplitudes_theta"])==EPSILONS
    assert c1r["decision"]=="BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED"
    assert c2a["decision"]=="BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED"
    assert c2a["diagnostic_B_authorized"] is True
    assert binding["required_C2A_decision"]==c2a["decision"]
    assert binding["C2B_execution_authorized"] is True

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    cases={}
    failures={}
    for d in WIDTHS:
        cases[str(d)]={}
        for h in HISTORIES:
            try:
                row=run_case(h,d,init_meta,init_nodes,states,nodes)
                cases[str(d)][h]=row
                if row["status"]!="QUALIFIED":
                    failures[f"{d}:{h}"]="NUMERICAL_DIAGNOSTIC_BLOCKED"
            except (RuntimeError,FloatingPointError) as exc:
                failures[f"{d}:{h}"]=str(exc)

    hard=max([
        max(row["max_abs_branch_ledger_residual_cm"],row["max_abs_mass_neutral_projection_residual_cm"])
        for hrows in cases.values() for row in hrows.values()
    ] or [math.inf])
    complete=not failures and hard<=GATE
    result={
        "schema":"swap5.lare.bc2.c2b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2B",
        "decision":"BC2_C2B_BLIND_TANGENT_PANEL_MAPPED" if complete else "BC2_C2B_NUMERICAL_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "diagnostic":"FROZEN_MASS_NEUTRAL_ADJACENT_MODE_TANGENT_PANEL",
        "hard_checks":{
            "failure_count":len(failures),
            "max_ledger_or_mass_neutral_residual":hard,
            "gate":GATE,
        },
        "failures":failures,
        "cases":cases,
        "interpretation":[
            "Directional gains are one-observation-interval symmetric finite-difference responses around frozen exact Reference-projected reduced states.",
            "Input perturbations transfer water only between adjacent reduced compartments and conserve total water storage to roundoff.",
            "Output gains use the preregistered mass-neutral theta-shape component; differential total-storage response is reported separately.",
            "Skipped directions are only strict constitutive-domain exits; epsilon is never retuned from the result.",
            "No stabilizer, state enrichment, closure change, fitting, H feedback or application threshold is introduced."
        ],
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "summary":{
            d:{h:{
                "selected_start_steps":r["selected_start_steps"],
                "record_count":len(r["records"]),
                "skip_count":len(r["skipped_constitutive_directions"]),
                "max_gain":max([x["max_directional_shape_gain"] for x in r["records"]] or [None])
            } for h,r in rows.items()}
            for d,rows in cases.items()
        }
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())