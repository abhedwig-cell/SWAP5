from __future__ import annotations

import json
import math
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

LIB=os.environ["FGC44_REAL_SWAP_LIB"]

H_STAR=-0.7149999706136307
MASS_GATE=1.0e-12
WATER_TOL=1.0e-6
M1_MIN=1.0e-4
RESPONSE_THRESHOLD=1.0e-18
PROBE_DURATION=1.0e-4

DELTA_H_VALUES=[1.0e-4,5.0e-5,2.0e-5,1.0e-5,5.0e-6,2.0e-6,1.0e-6,5.0e-7]
DURATIONS=[1.0e-2,5.0e-3,2.0e-3,1.0e-3,5.0e-4,2.0e-4,1.0e-4]
REPEAT_COUNTS=[200,100,50,20,10]
RELAX_COUNTS=[1,5,20]


def redacted_diag(d: dict) -> dict:
    keys=[
        "available","call_status","forcing_status","result_status","completed",
        "candidate_ready","mass_complete","committed","transaction_calls",
        "accepted_substeps","attempts","retries","trial_rollbacks",
        "solver_rejections","temporal_rejections",
        "temporal_unavailable_rejections","mass_rejections","internal_retries",
        "requested_head_m","duration_day","t0_day","t1_day",
        "materialized_top_flux_cm_per_day","materialized_bottom_head_cm",
        "mass_residual_native",
    ]
    return {k:d[k] for k in keys}


def run_child(mode: str, spec: dict) -> dict:
    env=dict(os.environ)
    env["RZM06A3_CHILD_MODE"]=mode
    env["RZM06A3_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    lines=[line for line in p.stdout.splitlines() if line.startswith("RZM06A3_CHILD_JSON ")]
    assert len(lines)==1,(p.stdout,p.stderr)
    return json.loads(lines[0].split(" ",1)[1])


def stage1_child(spec: dict) -> dict:
    s=Fgc44RealSwap(LIB)
    _,_,href=s.initialize()
    delta=float(spec["delta_h_m"])
    duration=float(spec["duration_day"])
    sign=int(spec["sign"])
    head=H_STAR+sign*delta

    pre_state=s.state()
    pre_obs=s.committed_profile_observables()
    status,diag=s.research_interval(0.0,head,duration,commit=False)
    post_state=s.state()
    post_obs=s.committed_profile_observables()

    # Read-only characterization must never alter the authoritative origin.
    assert pre_state==post_state
    assert pre_obs==post_obs

    accepted=(
        status==0
        and diag["completed"]
        and diag["candidate_ready"]
        and diag["mass_complete"]
        and not diag["committed"]
        and abs(diag["mass_residual_native"])<=MASS_GATE
    )
    return {
        "delta_h_m":delta,
        "duration_day":duration,
        "sign":sign,
        "requested_head_m":head,
        "reference_head_m":href,
        "status":status,
        "accepted":accepted,
        "diag":redacted_diag(diag),
        "origin_preserved":True,
    }


def history_heads(delta: float, n: int, r: int, order: str) -> list[tuple[str,float]]:
    plus=("PLUS",H_STAR+delta)
    minus=("MINUS",H_STAR-delta)
    base=("BASE",H_STAR)
    if order=="PLUS_MINUS_BASE":
        return [plus]*n+[minus]*n+[base]*r
    if order=="MINUS_PLUS_BASE":
        return [minus]*n+[plus]*n+[base]*r
    raise ValueError(order)


def construct_child(spec: dict, *, probe: bool) -> dict:
    s=Fgc44RealSwap(LIB)
    _,_,href=s.initialize()
    delta=float(spec["delta_h_m"])
    duration=float(spec["duration_day"])
    n=int(spec["repeat_count"])
    r=int(spec["relax_count"])
    order=str(spec["order"])
    heads=history_heads(delta,n,r,order)

    total_retries=0
    total_temporal_rejections=0
    total_solver_rejections=0
    total_trial_rollbacks=0
    max_attempts=0
    max_accepted_substeps=0
    max_abs_mass_residual=0.0
    committed_intervals=0
    failure=None

    for idx,(phase,head) in enumerate(heads):
        pre_state=s.state()
        pre_obs=s.committed_profile_observables()
        status,diag=s.research_interval(0.0,head,duration,commit=True)
        post_state=s.state()
        post_obs=s.committed_profile_observables()

        total_retries+=int(diag["retries"])
        total_temporal_rejections+=int(diag["temporal_rejections"])
        total_solver_rejections+=int(diag["solver_rejections"])
        total_trial_rollbacks+=int(diag["trial_rollbacks"])
        max_attempts=max(max_attempts,int(diag["attempts"]))
        max_accepted_substeps=max(max_accepted_substeps,int(diag["accepted_substeps"]))
        max_abs_mass_residual=max(max_abs_mass_residual,abs(float(diag["mass_residual_native"])))

        if status!=0:
            # A failed transition/trial is calculation-only and must preserve
            # the latest accepted origin exactly.
            assert post_state==pre_state
            assert post_obs==pre_obs
            failure={
                "interval_index":idx,
                "phase":phase,
                "requested_head_m":head,
                "status":status,
                "diag":redacted_diag(diag),
            }
            break

        assert diag["committed"] and diag["completed"] and diag["candidate_ready"]
        assert diag["mass_complete"]
        assert abs(diag["mass_residual_native"])<=MASS_GATE
        assert post_state[0]==pre_state[0]+1
        assert math.isclose(post_state[1],pre_state[1]+duration,rel_tol=0.0,abs_tol=1.0e-12)
        assert post_state[2:]==pre_state[2:]
        committed_intervals+=1

    accepted=(failure is None and committed_intervals==len(heads))
    endpoint_state=s.state()
    endpoint_obs=s.committed_profile_observables()

    if accepted:
        expected_intervals=2*n+r
        expected_time=expected_intervals*duration
        assert endpoint_state[0]==expected_intervals
        assert math.isclose(endpoint_state[1],expected_time,rel_tol=0.0,abs_tol=1.0e-11)
        assert endpoint_state[2:]==[0,0.0]

    result={
        "reference_head_m":href,
        "accepted":accepted,
        "delta_h_m":delta,
        "duration_day":duration,
        "repeat_count":n,
        "relax_count":r,
        "order":order,
        "requested_intervals":len(heads),
        "committed_intervals":committed_intervals,
        "failure":failure,
        "aggregate":{
            "total_retries":total_retries,
            "total_temporal_rejections":total_temporal_rejections,
            "total_solver_rejections":total_solver_rejections,
            "total_trial_rollbacks":total_trial_rollbacks,
            "max_attempts":max_attempts,
            "max_accepted_substeps":max_accepted_substeps,
            "max_abs_mass_residual_native":max_abs_mass_residual,
        },
        "endpoint_state":endpoint_state,
        "endpoint_obs":endpoint_obs,
    }

    if not probe or not accepted:
        return result

    pre_state=s.state()
    pre_obs=s.committed_profile_observables()
    status,diag=s.research_interval(0.0,H_STAR,PROBE_DURATION,commit=False)
    post_state=s.state()
    post_obs=s.committed_profile_observables()
    valid=(
        status==0
        and diag["completed"]
        and diag["candidate_ready"]
        and diag["mass_complete"]
        and not diag["committed"]
        and abs(diag["mass_residual_native"])<=MASS_GATE
        and pre_state==post_state
        and pre_obs==post_obs
    )
    result["probe"]={
        "status":status,
        "valid":valid,
        "diag":diag,
        "pre_state":pre_state,
        "post_state":post_state,
        "pre_obs":pre_obs,
        "post_obs":post_obs,
    }
    return result


if "RZM06A3_CHILD_MODE" in os.environ:
    mode=os.environ["RZM06A3_CHILD_MODE"]
    spec=json.loads(os.environ["RZM06A3_CHILD_SPEC"])
    if mode=="stage1":
        out=stage1_child(spec)
    elif mode=="construct":
        out=construct_child(spec,probe=False)
    elif mode=="probe":
        out=construct_child(spec,probe=True)
    else:
        raise RuntimeError(f"unknown child mode {mode}")
    print("RZM06A3_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)


# ---------------------------------------------------------------------------
# Stage 1: two-sided short-window admissibility map.  No endpoint observables or
# E_c are returned by the child or used by this selector.
# ---------------------------------------------------------------------------
stage1=[]
admitted=[]
for delta in DELTA_H_VALUES:
    for duration in DURATIONS:
        plus=run_child("stage1",{"delta_h_m":delta,"duration_day":duration,"sign":1})
        minus=run_child("stage1",{"delta_h_m":delta,"duration_day":duration,"sign":-1})
        both=bool(plus["accepted"] and minus["accepted"])
        point={
            "delta_h_m":delta,
            "duration_day":duration,
            "score_delta_times_duration":delta*duration,
            "both_signs_admitted":both,
            "plus":plus,
            "minus":minus,
        }
        stage1.append(point)
        if both:
            admitted.append(point)

selected_microstep=None
selected_replay=None
if admitted:
    selected=max(
        admitted,
        key=lambda x:(x["score_delta_times_duration"],x["delta_h_m"],x["duration_day"]),
    )
    selected_microstep={
        "delta_h_m":selected["delta_h_m"],
        "duration_day":selected["duration_day"],
        "score_delta_times_duration":selected["score_delta_times_duration"],
    }
    # Re-characterize the chosen point from fresh baselines and demand exact
    # deterministic replay before it can seed committed histories.
    selected_replay={}
    for sign_name,sign in (("plus",1),("minus",-1)):
        first=run_child("stage1",{
            "delta_h_m":selected["delta_h_m"],
            "duration_day":selected["duration_day"],
            "sign":sign,
        })
        second=run_child("stage1",{
            "delta_h_m":selected["delta_h_m"],
            "duration_day":selected["duration_day"],
            "sign":sign,
        })
        selected_replay[sign_name]={
            "exact_replay":first==second,
            "run":first,
        }
        assert first==second and first["accepted"]


# ---------------------------------------------------------------------------
# Stage 2: assemble only the selected admitted microstep into longer committed
# histories. Pair selection sees endpoint W_profile and M1, never E_c.
# ---------------------------------------------------------------------------
construction=[]
selected_pair=None
if selected_microstep is not None:
    delta=selected_microstep["delta_h_m"]
    duration=selected_microstep["duration_day"]
    for n in REPEAT_COUNTS:
        for r in RELAX_COUNTS:
            spec_base={
                "delta_h_m":delta,
                "duration_day":duration,
                "repeat_count":n,
                "relax_count":r,
            }
            a=run_child("construct",{**spec_base,"order":"PLUS_MINUS_BASE"})
            b=run_child("construct",{**spec_base,"order":"MINUS_PLUS_BASE"})
            record={
                "repeat_count":n,
                "relax_count":r,
                "duration_day":duration,
                "delta_h_m":delta,
                "A":a,
                "B":b,
                "pair_admitted":bool(a["accepted"] and b["accepted"]),
                "delta_profile_water_native":None,
                "delta_M1_native":None,
                "meets_h2_endpoint_criteria":False,
            }
            if a["accepted"] and b["accepted"]:
                dw=abs(b["endpoint_obs"]["profile_water_cm"]-a["endpoint_obs"]["profile_water_cm"])
                dm=abs(b["endpoint_obs"]["distribution_moment_cm"]-a["endpoint_obs"]["distribution_moment_cm"])
                record["delta_profile_water_native"]=dw
                record["delta_M1_native"]=dm
                record["meets_h2_endpoint_criteria"]=bool(dw<=WATER_TOL and dm>=M1_MIN)
                if record["meets_h2_endpoint_criteria"]:
                    selected_pair={
                        "repeat_count":n,
                        "relax_count":r,
                        "duration_day":duration,
                        "delta_h_m":delta,
                        "A_order":"PLUS_MINUS_BASE",
                        "B_order":"MINUS_PLUS_BASE",
                        "A_endpoint_state":a["endpoint_state"],
                        "B_endpoint_state":b["endpoint_state"],
                        "A_endpoint_obs":a["endpoint_obs"],
                        "B_endpoint_obs":b["endpoint_obs"],
                        "delta_profile_water_native":dw,
                        "delta_M1_native":dm,
                    }
            construction.append(record)
            if selected_pair is not None:
                break
        if selected_pair is not None:
            break


# ---------------------------------------------------------------------------
# Scientific H2 response is opened only after endpoint selection.
# ---------------------------------------------------------------------------
probe_evidence=None
if selected_microstep is None:
    disposition="NO_ADMISSIBLE_MICROSTEP"
elif selected_pair is None:
    disposition="NO_MATCH"
else:
    probe_evidence={}
    base_spec={
        "delta_h_m":selected_pair["delta_h_m"],
        "duration_day":selected_pair["duration_day"],
        "repeat_count":selected_pair["repeat_count"],
        "relax_count":selected_pair["relax_count"],
    }
    for label,order in (("A","PLUS_MINUS_BASE"),("B","MINUS_PLUS_BASE")):
        first=run_child("probe",{**base_spec,"order":order})
        replay=run_child("probe",{**base_spec,"order":order})
        exact=(first==replay)
        expected_obs=selected_pair[f"{label}_endpoint_obs"]
        valid=(
            first["accepted"]
            and first.get("probe",{}).get("valid",False)
            and exact
            and first["endpoint_obs"]==expected_obs
        )
        probe_evidence[label]={
            "valid":valid,
            "exact_replay":exact,
            "endpoint_state":first["endpoint_state"],
            "endpoint_obs":first["endpoint_obs"],
            "probe":first.get("probe"),
        }

    if probe_evidence["A"]["valid"] and probe_evidence["B"]["valid"]:
        ea=probe_evidence["A"]["probe"]["diag"]["bottom_outward_exchange_native"]
        eb=probe_evidence["B"]["probe"]["diag"]["bottom_outward_exchange_native"]
        delta_e=eb-ea
        probe_evidence["E_A_native"]=ea
        probe_evidence["E_B_native"]=eb
        probe_evidence["delta_E_native"]=delta_e
        probe_evidence["abs_delta_E_native"]=abs(delta_e)
        disposition=("SUPPORTED" if abs(delta_e)>RESPONSE_THRESHOLD
                     else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION")
    else:
        disposition="PROBE_OR_REPEATABILITY_FAILURE"


evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06a3.microstepped_h2_experiment.v1",
    "preregistration_commit":"c41b702dd2a87b6c94a482f0d384454b745a0f44",
    "production_changes":False,
    "frozen":{
        "H_star_m":H_STAR,
        "delta_h_values_m":DELTA_H_VALUES,
        "durations_day":DURATIONS,
        "repeat_counts":REPEAT_COUNTS,
        "relax_counts":RELAX_COUNTS,
        "profile_water_tolerance_native":WATER_TOL,
        "M1_separation_native":M1_MIN,
        "response_threshold_native":RESPONSE_THRESHOLD,
        "mass_gate_native":MASS_GATE,
    },
    "stage1_admissibility_map":stage1,
    "selected_microstep":selected_microstep,
    "selected_microstep_replay":selected_replay,
    "stage2_construction":construction,
    "selected_pair":selected_pair,
    "probe_evidence":probe_evidence,
    "disposition":disposition,
    "nonclaims":[
        "no production coupling admission",
        "no second MODFLOW hydraulic state variable admission",
        "no production recommendation to microstep H_c",
        "no H5 management conclusion",
    ],
}
print("RZM06A3_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A3_MICROSTEPPED_H2_EXPERIMENT=PASS")
