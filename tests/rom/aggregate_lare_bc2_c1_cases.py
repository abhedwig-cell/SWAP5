#!/usr/bin/env python3
from __future__ import annotations
import argparse,importlib.util,json,math,pathlib
from collections import Counter

HERE=pathlib.Path(__file__).resolve().parent
def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--cases-dir",required=True,type=pathlib.Path)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    c0res=json.loads(a.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_TEACHER_FORCED_DRIFT_DECOMPOSITION"
    assert c0res["decision"]==pre["predecessor"]["required_decision"]

    # Reference finiteness is an independent authority check. Do not conflate a
    # reduced-route domain exit with a non-finite accepted Reference projection.
    init_meta,init_nodes,states,nodes=c0.b0.load_reference(a.reference)
    reference_finite=True
    reference_failure=None
    try:
        for d in c1.WIDTHS:
            for h,nsteps in c0.HISTORY_STEPS.items():
                for step in range(0,nsteps+1):
                    y,p,U=c1.exact_reference_state(
                        h,step,d,init_meta,init_nodes,states,nodes
                    )
                    vals=list(y[:c1.PHYS_N])+[float(p["H"]),float(U)]
                    if not all(math.isfinite(float(v)) for v in vals):
                        raise RuntimeError(f"NONFINITE_REFERENCE_PROJECTION {d} {h} {step}")
                    if step>0:
                        y0,p0,U0=c1.exact_reference_state(
                            h,step-1,d,init_meta,init_nodes,states,nodes
                        )
                        refs=c1.reference_fluxes(h,step,p0,p,states)
                        if not all(math.isfinite(float(refs[k])) for k in ("q90","qi","qH")):
                            raise RuntimeError(f"NONFINITE_REFERENCE_FLUX {d} {h} {step}")
    except Exception as exc:
        reference_finite=False
        reference_failure=str(exc)

    primary_key=f"{c1.PRIMARY_DT:.8f}"
    cross_key=f"{c1.CROSS_DT:.8f}"
    cases={}
    failures={}
    for d in c1.WIDTHS:
        for h in c0.HISTORY_STEPS:
            p=a.cases_dir/f"c1_w{str(d).replace('.','p')}_{h}.json"
            if not p.exists():
                failures[f"{d}:{h}:MISSING_CASE"]="missing shard artifact"
                cases[(d,h)]={"runs":{},"failures":{"MISSING":"missing shard artifact"}}
                continue
            row=json.loads(p.read_text())
            assert float(row["width_cm"])==d and row["history"]==h
            cases[(d,h)]={"runs":row["runs"],"failures":row["failures"]}
            for k,v in row["failures"].items():
                failures[f"{d}:{h}:{k}"]=v

    all_routes=all(
        primary_key in cases[(d,h)]["runs"] and cross_key in cases[(d,h)]["runs"]
        for d in c1.WIDTHS for h in c0.HISTORY_STEPS
    )
    hard_vals=[]
    classifications={}
    floors={}
    full_cases={}
    for d in c1.WIDTHS:
        classifications[str(d)]={}
        floors[str(d)]={}
        full_cases[str(d)]={}
        for h in c0.HISTORY_STEPS:
            row=cases[(d,h)]["runs"]
            full_cases[str(d)][h]=row
            if primary_key not in row:
                classifications[str(d)][h]={"status":"BLOCKED"}
                continue
            p=row[primary_key]
            route_hard={}
            for route_key in (primary_key,cross_key):
                if route_key not in row: continue
                rr=row[route_key]
                vals=[
                    rr["max_abs_additive_state_identity_residual_cm"],
                    rr["max_abs_additive_flux_identity_residual_cm_per_day"],
                    rr["max_abs_free_physical_ledger_residual_cm"],
                    rr["max_abs_teacher_interval_ledger_residual_cm"],
                ]
                hard_vals.extend(vals);route_hard[route_key]=max(vals)
            classifications[str(d)][h]={
                "state_shape":p["state_shape"]["dominance"],
                "q90":p["fluxes"]["q90"]["dominance"],
                "qi":p["fluxes"]["qi"]["dominance"],
                "qH":p["fluxes"]["qH"]["dominance"],
                "first_interval_state_component_exceeds_local":p["first_interval_state_component_exceeds_local"],
                "max_hard_residual_by_route":route_hard,
            }
            if cross_key in row:
                floors[str(d)][h]=c1.numerical_floor(p,row[cross_key])
                floors[str(d)][h]["classification_match"]={
                    "state_shape":p["state_shape"]["dominance"]==row[cross_key]["state_shape"]["dominance"],
                    "q90":p["fluxes"]["q90"]["dominance"]==row[cross_key]["fluxes"]["q90"]["dominance"],
                    "qi":p["fluxes"]["qi"]["dominance"]==row[cross_key]["fluxes"]["qi"]["dominance"],
                    "qH":p["fluxes"]["qH"]["dominance"]==row[cross_key]["fluxes"]["qH"]["dominance"],
                }

    max_hard=max(hard_vals or [math.inf])
    complete=all_routes and not failures and reference_finite and max_hard<=c1.IDENTITY_GATE
    counts=Counter()
    for drow in classifications.values():
        for hrow in drow.values():
            for key in ("state_shape","q90","qi","qH"):
                if key in hrow: counts[f"{key}:{hrow[key]}"]+=1

    result={
        "schema":"swap5.lare.bc2.c1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1",
        "decision":"BC2_C1_ERROR_CHANNELS_DECOMPOSED" if complete else "BC2_C1_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "execution_topology":"SHARDED_WIDTH_X_HISTORY_EXACT_SAME_DECOMPOSE_FUNCTION",
        "hard_checks":{
            "all_primary_and_cross_routes_qualified":all_routes and not failures,
            "all_primary_and_cross_routes_hard_gated":True,
            "all_reference_projections_finite":reference_finite,
            "reference_projection_failure":reference_failure,
            "failure_count":len(failures),
            "max_additive_or_ledger_residual_across_primary_and_cross":max_hard,
            "gate":c1.IDENTITY_GATE,
        },
        "failures":failures,
        "classification_counts":dict(counts),
        "classifications":classifications,
        "numerical_floor":floors,
        "cases":full_cases,
        "interpretation":[
            "Teacher-forced one-interval error evaluates the unchanged C0 closure from exact Reference-projected reduced state.",
            "Free-minus-teacher isolates accumulated reduced-state drift under the same H(t), integrator and closures.",
            "All decomposition identities are checked before norms are formed.",
            "No new state, closure, fit, direction switch, groundwater feedback or application tolerance is introduced.",
            "Sharding changes execution topology only; each case calls the same decompose function as the serial authority implementation."
        ],
        "next_model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "classification_counts":result["classification_counts"],
        "classifications":classifications,
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())