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
AMPLITUDES=[1.0e-3,5.0e-4,2.0e-4,1.0e-4,5.0e-5,2.0e-5,1.0e-5]
TIME_GROUPS=[
    {"pulse_duration_day":0.05,"relax_duration_day":0.05,"total_duration_day":0.15},
    {"pulse_duration_day":0.10,"relax_duration_day":0.05,"total_duration_day":0.25},
    {"pulse_duration_day":0.05,"relax_duration_day":0.10,"total_duration_day":0.20},
    {"pulse_duration_day":0.02,"relax_duration_day":0.05,"total_duration_day":0.09},
]


def op(head: float, duration: float) -> dict:
    return {"head_m":float(head),"duration_day":float(duration),"top_flux_native_per_day":0.0}


def redact_diag(diag: dict) -> dict:
    # Construction evidence deliberately excludes scientific interface-response
    # quantities. Pair selection receives only transactional/admissibility data.
    keys=[
        "available","call_status","forcing_status","result_status","completed",
        "candidate_ready","mass_complete","committed","transaction_calls",
        "accepted_substeps","attempts","retries","trial_rollbacks",
        "solver_rejections","temporal_rejections",
        "temporal_unavailable_rejections","mass_rejections","internal_retries",
        "requested_top_flux_cm_per_day","requested_head_m","duration_day",
        "t0_day","t1_day","materialized_top_flux_cm_per_day",
        "materialized_bottom_head_cm","mass_residual_native",
    ]
    return {k:diag[k] for k in keys}


def child_construct(spec: dict) -> dict:
    s=Fgc44RealSwap(LIB)
    _,_,href=s.initialize()
    initial_state=s.state()
    initial_obs=s.committed_profile_observables()
    records=[]
    ok=True
    for interval in spec["trajectory"]:
        pre_state=s.state()
        pre_obs=s.committed_profile_observables()
        status,diag=s.research_interval(
            float(interval["top_flux_native_per_day"]),
            float(interval["head_m"]),
            float(interval["duration_day"]),
            commit=True,
        )
        post_state=s.state()
        post_obs=s.committed_profile_observables()
        record={
            "status":status,
            "diag":redact_diag(diag),
            "pre_state":pre_state,
            "post_state":post_state,
        }
        if status==0:
            assert diag["committed"] and diag["completed"] and diag["candidate_ready"] and diag["mass_complete"]
            assert abs(diag["mass_residual_native"])<=MASS_GATE
            assert post_state[0]==pre_state[0]+1
            assert math.isclose(post_state[1],pre_state[1]+float(interval["duration_day"]),rel_tol=0.0,abs_tol=1e-13)
            assert post_state[2:]==pre_state[2:]
        else:
            # Failed construction intervals are evidence and must not mutate
            # the latest committed origin.
            assert post_state==pre_state
            assert post_obs==pre_obs
            ok=False
        records.append(record)
        if status!=0:
            break
    return {
        "href_m":href,
        "initial_state":initial_state,
        "initial_obs":initial_obs,
        "accepted":ok and len(records)==len(spec["trajectory"]),
        "records":records,
        "endpoint_state":s.state(),
        "endpoint_obs":s.committed_profile_observables(),
    }


def child_probe(spec: dict) -> dict:
    s=Fgc44RealSwap(LIB)
    _,_,href=s.initialize()
    records=[]
    for interval in spec["trajectory"]:
        status,diag=s.research_interval(
            float(interval["top_flux_native_per_day"]),
            float(interval["head_m"]),
            float(interval["duration_day"]),
            commit=True,
        )
        records.append({"status":status,"diag":redact_diag(diag)})
        if status!=0:
            return {"accepted":False,"records":records}
        assert diag["committed"] and diag["mass_complete"]
        assert abs(diag["mass_residual_native"])<=MASS_GATE

    endpoint_state=s.state()
    endpoint_obs=s.committed_profile_observables()
    pre_state=s.state()
    pre_obs=s.committed_profile_observables()
    status,diag=s.research_interval(0.0,H_STAR,PROBE_DURATION,commit=False)
    post_state=s.state()
    post_obs=s.committed_profile_observables()
    valid=(
        status==0 and diag["completed"] and diag["candidate_ready"]
        and diag["mass_complete"] and not diag["committed"]
        and abs(diag["mass_residual_native"])<=MASS_GATE
        and pre_state==post_state and pre_obs==post_obs
    )
    return {
        "accepted":True,
        "records":records,
        "endpoint_state":endpoint_state,
        "endpoint_obs":endpoint_obs,
        "probe":{
            "status":status,
            "valid":valid,
            "diag":diag,
            "pre_state":pre_state,
            "post_state":post_state,
            "pre_obs":pre_obs,
            "post_obs":post_obs,
        },
    }


def run_fresh(mode: str, spec: dict) -> dict:
    env=dict(os.environ)
    env["RZM06A2_CHILD_MODE"]=mode
    env["RZM06A2_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    lines=[line for line in p.stdout.splitlines() if line.startswith("RZM06A2_CHILD_JSON ")]
    assert len(lines)==1,(p.stdout,p.stderr)
    return json.loads(lines[0].split(" ",1)[1])


if "RZM06A2_CHILD_MODE" in os.environ:
    spec=json.loads(os.environ["RZM06A2_CHILD_SPEC"])
    mode=os.environ["RZM06A2_CHILD_MODE"]
    result=child_construct(spec) if mode=="construct" else child_probe(spec)
    print("RZM06A2_CHILD_JSON",json.dumps(result,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)


def trajectory(delta_h: float, pulse: float, relax: float, order: str) -> list[dict]:
    up=H_STAR+delta_h
    down=H_STAR-delta_h
    if order=="UP_DOWN_BASE":
        heads=[up,down,H_STAR]
    elif order=="DOWN_UP_BASE":
        heads=[down,up,H_STAR]
    else:
        raise ValueError(order)
    return [op(heads[0],pulse),op(heads[1],pulse),op(heads[2],relax)]


groups=[]
selected=None
selected_pair=None
for group_index,g in enumerate(TIME_GROUPS):
    candidates=[]
    for amp in AMPLITUDES:
        for order in ("UP_DOWN_BASE","DOWN_UP_BASE"):
            traj=trajectory(amp,g["pulse_duration_day"],g["relax_duration_day"],order)
            out=run_fresh("construct",{"trajectory":traj})
            candidate={
                "name":f"G{group_index+1}:{amp:.1e}:{order}",
                "group_index":group_index,
                "delta_h_m":amp,
                "order":order,
                "trajectory":traj,
                "accepted":out["accepted"],
                "records":out["records"],
                "endpoint_state":out["endpoint_state"],
                "endpoint_obs":out["endpoint_obs"],
            }
            if candidate["accepted"]:
                expected_time=g["total_duration_day"]
                assert candidate["endpoint_state"][0]==3
                assert math.isclose(candidate["endpoint_state"][1],expected_time,rel_tol=0.0,abs_tol=1e-13)
                assert candidate["endpoint_state"][2:]==[0,0.0]
            candidates.append(candidate)

    match=None
    accepted=[c for c in candidates if c["accepted"]]
    for i in range(len(accepted)):
        for j in range(i+1,len(accepted)):
            a=accepted[i]; b=accepted[j]
            dw=abs(b["endpoint_obs"]["profile_water_cm"]-a["endpoint_obs"]["profile_water_cm"])
            dm=abs(b["endpoint_obs"]["distribution_moment_cm"]-a["endpoint_obs"]["distribution_moment_cm"])
            if dw<=WATER_TOL and dm>=M1_MIN:
                match={
                    "a_name":a["name"],
                    "b_name":b["name"],
                    "a_trajectory":a["trajectory"],
                    "b_trajectory":b["trajectory"],
                    "delta_profile_water_native":dw,
                    "delta_M1_native":dm,
                    "a_endpoint_obs":a["endpoint_obs"],
                    "b_endpoint_obs":b["endpoint_obs"],
                    "endpoint_time_day":g["total_duration_day"],
                }
                break
        if match is not None:
            break

    groups.append({
        "group_index":group_index,
        "time_group":g,
        "candidate_count":len(candidates),
        "accepted_count":sum(1 for c in candidates if c["accepted"]),
        "candidates":candidates,
        "selected_match":match,
    })
    if match is not None:
        selected={"group_index":group_index,"time_group":g}
        selected_pair=match
        break


probe_evidence=None
if selected_pair is None:
    disposition="NO_MATCH"
else:
    probe_evidence={}
    for label in ("a","b"):
        traj=selected_pair[f"{label}_trajectory"]
        first=run_fresh("probe",{"trajectory":traj})
        replay=run_fresh("probe",{"trajectory":traj})
        exact=(first==replay)
        valid=(
            first.get("accepted",False)
            and first["probe"]["valid"]
            and exact
            and first["endpoint_obs"]==selected_pair[f"{label}_endpoint_obs"]
        )
        probe_evidence[label]={
            "valid":valid,
            "exact_replay":exact,
            "endpoint_state":first.get("endpoint_state"),
            "endpoint_obs":first.get("endpoint_obs"),
            "probe":first.get("probe"),
        }
    if probe_evidence["a"]["valid"] and probe_evidence["b"]["valid"]:
        ea=probe_evidence["a"]["probe"]["diag"]["bottom_outward_exchange_native"]
        eb=probe_evidence["b"]["probe"]["diag"]["bottom_outward_exchange_native"]
        delta=eb-ea
        probe_evidence["E_a_native"]=ea
        probe_evidence["E_b_native"]=eb
        probe_evidence["delta_E_native"]=delta
        probe_evidence["abs_delta_E_native"]=abs(delta)
        disposition=("SUPPORTED" if abs(delta)>RESPONSE_THRESHOLD
                     else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION")
    else:
        disposition="PROBE_OR_REPEATABILITY_FAILURE"


evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06a2.h2_state_pair_experiment.v1",
    "preregistration_commit":"ae06b69b7b861b30934a0591958666d95726ff49",
    "production_changes":False,
    "frozen":{
        "H_star_m":H_STAR,
        "amplitudes_m":AMPLITUDES,
        "time_groups":TIME_GROUPS,
        "top_flux_native_per_day":0.0,
        "profile_water_tolerance_native":WATER_TOL,
        "M1_separation_native":M1_MIN,
        "probe_duration_day":PROBE_DURATION,
        "response_threshold_native":RESPONSE_THRESHOLD,
        "mass_gate_native":MASS_GATE,
    },
    "construction_groups":groups,
    "selected_group":selected,
    "selected_pair":selected_pair,
    "probe_evidence":probe_evidence,
    "disposition":disposition,
    "nonclaims":[
        "no production coupling admission",
        "no second MODFLOW hydraulic state variable admission",
        "no claim that antecedent head pulses are a production strategy",
        "no H5 management conclusion",
    ],
}
print("RZM06A2_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A2_H2_STATE_PAIR_EXPERIMENT=PASS")
