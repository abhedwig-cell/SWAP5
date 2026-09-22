from __future__ import annotations

import itertools
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
ANTECEDENT_DURATION=1.0e-2
WET=-1.0e-5
DRY=1.0e-5
ZERO=0.0
PRIMARY_PROBE_DURATION=1.0e-4
TANGENT_DURATIONS=(1.0e-4,1.0e-3)
DELTA_H=1.0e-6
MASS_GATE=1.0e-12
RESPONSE_THRESHOLD=1.0e-18
TANGENT_THRESHOLD=1.0e-12
H2_WATER_TOL=1.0e-6
H2_M1_MIN=1.0e-4


def interval(top: float, duration: float=ANTECEDENT_DURATION, head: float=H_STAR) -> dict:
    return {
        "top_flux_native_per_day":float(top),
        "duration_day":float(duration),
        "head_m":float(head),
    }


def child_run(spec: dict) -> dict:
    s=Fgc44RealSwap(LIB)
    hcof,rhs,href=s.initialize()
    init_state=s.state()
    init_obs=s.committed_profile_observables()
    init_e1=s.e1_diagnostics()
    antecedent_records=[]
    antecedent_ok=True
    for op in spec.get("antecedent",[]):
        status,diag=s.research_interval(
            float(op["top_flux_native_per_day"]),
            float(op["head_m"]),
            float(op["duration_day"]),
            commit=True,
        )
        rec={
            "status":status,
            "diag":diag,
            "state":s.state(),
            "obs":s.committed_profile_observables(),
        }
        antecedent_records.append(rec)
        if status!=0:
            antecedent_ok=False
            break

    endpoint_state=s.state()
    endpoint_obs=s.committed_profile_observables()
    probe_record=None
    probe=spec.get("probe")
    if antecedent_ok and probe is not None:
        pre_state=s.state()
        pre_obs=s.committed_profile_observables()
        status,diag=s.research_interval(
            float(probe["top_flux_native_per_day"]),
            float(probe["head_m"]),
            float(probe["duration_day"]),
            commit=False,
        )
        post_state=s.state()
        post_obs=s.committed_profile_observables()
        probe_record={
            "status":status,
            "diag":diag,
            "pre_state":pre_state,
            "post_state":post_state,
            "pre_obs":pre_obs,
            "post_obs":post_obs,
        }

    return {
        "initialize":{
            "hcof_m2_per_day":hcof,
            "rhs_m3_per_day":rhs,
            "reference_head_m":href,
            "e1":init_e1,
        },
        "initial_state":init_state,
        "initial_obs":init_obs,
        "antecedent_ok":antecedent_ok,
        "antecedent_records":antecedent_records,
        "endpoint_state":endpoint_state,
        "endpoint_obs":endpoint_obs,
        "probe":probe_record,
    }


def run_fresh(spec: dict) -> dict:
    env=dict(os.environ)
    env["RZM06A_EXPERIMENT_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    lines=[line for line in p.stdout.splitlines() if line.startswith("RZM06A_EXPERIMENT_CHILD_JSON ")]
    assert len(lines)==1,(p.stdout,p.stderr)
    return json.loads(lines[0].split(" ",1)[1])


if "RZM06A_EXPERIMENT_CHILD_SPEC" in os.environ:
    out=child_run(json.loads(os.environ["RZM06A_EXPERIMENT_CHILD_SPEC"]))
    print("RZM06A_EXPERIMENT_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)


def validate_origin(out: dict, expected_intervals: int) -> bool:
    if not out["antecedent_ok"] or len(out["antecedent_records"])!=expected_intervals:
        return False
    if any(r["status"]!=0 or not r["diag"]["committed"] or not r["diag"]["mass_complete"]
           for r in out["antecedent_records"]):
        return False
    if any(abs(r["diag"]["mass_residual_native"])>MASS_GATE for r in out["antecedent_records"]):
        return False
    if out["endpoint_state"][0]!=expected_intervals:
        return False
    if not math.isclose(out["endpoint_state"][1],expected_intervals*ANTECEDENT_DURATION,
                        rel_tol=0.0,abs_tol=1.0e-14):
        return False
    # Antecedent preparation is research state construction, not publication.
    if out["endpoint_state"][2:]!=[0,0.0]:
        return False
    return True


def validate_probe(out: dict) -> bool:
    p=out["probe"]
    if p is None or p["status"]!=0:
        return False
    d=p["diag"]
    if not d["completed"] or not d["candidate_ready"] or not d["mass_complete"]:
        return False
    if d["committed"]:
        return False
    if abs(d["mass_residual_native"])>MASS_GATE:
        return False
    if p["pre_state"]!=p["post_state"] or p["pre_obs"]!=p["post_obs"]:
        return False
    return True


def run_origin_probe(sequence: list[float], duration: float, head: float=H_STAR) -> dict:
    spec={
        "antecedent":[interval(v) for v in sequence],
        "probe":interval(ZERO,duration,head),
    }
    return run_fresh(spec)


# H1: fixed, response-blind antecedent pair from preregistration.
h1_sequences={
    "WET_THEN_DRY":[WET,DRY],
    "DRY_THEN_WET":[DRY,WET],
}
h1={}
for name,seq in h1_sequences.items():
    first=run_origin_probe(seq,PRIMARY_PROBE_DURATION,H_STAR)
    replay=run_origin_probe(seq,PRIMARY_PROBE_DURATION,H_STAR)
    exact_replay=(first==replay)
    valid=validate_origin(first,2) and validate_probe(first) and exact_replay
    h1[name]={"run":first,"exact_replay":exact_replay,"valid":valid}

h1_state_different=(
    h1["WET_THEN_DRY"]["run"]["endpoint_obs"]!=h1["DRY_THEN_WET"]["run"]["endpoint_obs"]
)
if all(x["valid"] for x in h1.values()) and h1_state_different:
    e_a=h1["WET_THEN_DRY"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
    e_b=h1["DRY_THEN_WET"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
    h1_delta=e_b-e_a
    h1_abs_delta=abs(h1_delta)
    h1_disposition=("SUPPORTED" if h1_abs_delta>RESPONSE_THRESHOLD
                    else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION")
else:
    e_a=e_b=h1_delta=h1_abs_delta=None
    h1_disposition="PRECONDITION_OR_REPEATABILITY_FAILURE"


# H2: enumerate endpoints only. Probe response is not executed until a pair is
# selected by the preregistered W_profile and M1 criteria.
alphabet=[
    ("W10",-1.0e-4),
    ("D10", 1.0e-4),
    ("W",WET),
    ("D",DRY),
    ("Z",ZERO),
]
h2_candidates=[]
for (s1,v1),(s2,v2) in itertools.product(alphabet,repeat=2):
    name=f"{s1}->{s2}"
    out=run_fresh({"antecedent":[interval(v1),interval(v2)]})
    accepted=validate_origin(out,2)
    h2_candidates.append({
        "name":name,
        "symbols":[s1,s2],
        "accepted":accepted,
        "statuses":[r["status"] for r in out["antecedent_records"]],
        "endpoint_state":out["endpoint_state"],
        "endpoint_obs":out["endpoint_obs"],
    })

accepted_h2=[c for c in h2_candidates if c["accepted"]]
h2_match=None
for i in range(len(accepted_h2)):
    for j in range(i+1,len(accepted_h2)):
        a=accepted_h2[i]; b=accepted_h2[j]
        dw=abs(b["endpoint_obs"]["profile_water_cm"]-a["endpoint_obs"]["profile_water_cm"])
        dm=abs(b["endpoint_obs"]["distribution_moment_cm"]-a["endpoint_obs"]["distribution_moment_cm"])
        if dw<=H2_WATER_TOL and dm>=H2_M1_MIN:
            h2_match={"a":a,"b":b,"delta_profile_water_native":dw,"delta_M1_native":dm}
            break
    if h2_match is not None:
        break

h2_probe=None
if h2_match is None:
    h2_disposition="NO_MATCH"
else:
    def values_from_symbols(symbols: list[str]) -> list[float]:
        table=dict(alphabet)
        return [table[s] for s in symbols]
    h2_probe={}
    for label in ("a","b"):
        candidate=h2_match[label]
        seq=values_from_symbols(candidate["symbols"])
        first=run_origin_probe(seq,PRIMARY_PROBE_DURATION,H_STAR)
        replay=run_origin_probe(seq,PRIMARY_PROBE_DURATION,H_STAR)
        exact=(first==replay)
        valid=validate_origin(first,2) and validate_probe(first) and exact
        h2_probe[label]={"run":first,"exact_replay":exact,"valid":valid}
    if all(v["valid"] for v in h2_probe.values()):
        e2a=h2_probe["a"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
        e2b=h2_probe["b"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
        delta2=e2b-e2a
        h2_probe["delta_exchange_native"]=delta2
        h2_probe["abs_delta_exchange_native"]=abs(delta2)
        h2_disposition=("SUPPORTED" if abs(delta2)>RESPONSE_THRESHOLD
                        else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION")
    else:
        h2_disposition="PROBE_OR_REPEATABILITY_FAILURE"


# H3: central differences from immutable replayed H1 origins.
h3={"origins":{}}
for origin_name,seq in h1_sequences.items():
    h3["origins"][origin_name]={}
    for duration in TANGENT_DURATIONS:
        signs={}
        for sign,offset in (("minus",-DELTA_H),("plus",DELTA_H)):
            first=run_origin_probe(seq,duration,H_STAR+offset)
            replay=run_origin_probe(seq,duration,H_STAR+offset)
            exact=(first==replay)
            valid=validate_origin(first,2) and validate_probe(first) and exact
            signs[sign]={"run":first,"exact_replay":exact,"valid":valid}
        if signs["minus"]["valid"] and signs["plus"]["valid"]:
            em=signs["minus"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
            ep=signs["plus"]["run"]["probe"]["diag"]["bottom_outward_exchange_native"]
            derivative=(ep-em)/(2.0*DELTA_H)
        else:
            derivative=None
        h3["origins"][origin_name][str(duration)]={
            "minus":signs["minus"],
            "plus":signs["plus"],
            "derivative_native_per_m":derivative,
        }

state_comparisons={}
for duration in TANGENT_DURATIONS:
    key=str(duration)
    da=h3["origins"]["WET_THEN_DRY"][key]["derivative_native_per_m"]
    db=h3["origins"]["DRY_THEN_WET"][key]["derivative_native_per_m"]
    if da is None or db is None:
        diff=None; supported=False
    else:
        diff=db-da; supported=abs(diff)>TANGENT_THRESHOLD
    state_comparisons[key]={
        "difference_native_per_m":diff,
        "above_threshold":supported,
    }

window_comparisons={}
for origin_name in h1_sequences:
    ds=h3["origins"][origin_name][str(TANGENT_DURATIONS[0])]["derivative_native_per_m"]
    dl=h3["origins"][origin_name][str(TANGENT_DURATIONS[1])]["derivative_native_per_m"]
    if ds is None or dl is None:
        diff=None; supported=False
    else:
        diff=dl-ds; supported=abs(diff)>TANGENT_THRESHOLD
    window_comparisons[origin_name]={
        "difference_native_per_m":diff,
        "above_threshold":supported,
    }

h3["state_comparisons"]=state_comparisons
h3["window_comparisons"]=window_comparisons
h3_state=any(v["above_threshold"] for v in state_comparisons.values())
h3_window=any(v["above_threshold"] for v in window_comparisons.values())
if h3_state and h3_window:
    h3_disposition="SUPPORTED_STATE_AND_WINDOW_DEPENDENCE"
elif h3_state:
    h3_disposition="PARTIAL_STATE_DEPENDENCE_ONLY"
elif h3_window:
    h3_disposition="PARTIAL_WINDOW_DEPENDENCE_ONLY"
else:
    valid_derivatives=all(
        h3["origins"][o][str(d)]["derivative_native_per_m"] is not None
        for o in h1_sequences for d in TANGENT_DURATIONS
    )
    h3_disposition=("NOT_SUPPORTED_AT_FROZEN_RESOLUTION" if valid_derivatives
                    else "PROBE_OR_REPEATABILITY_FAILURE")


# H4: provenance-preserving semantic audit. Use H1 origin A for a concrete
# whole-window result, but retain baseline predictor provenance explicitly.
h4_reference=h1["WET_THEN_DRY"]["run"]
h4_probe=h4_reference["probe"]["diag"] if h4_reference["probe"] is not None else None
h4={
    "baseline_predictor_provenance":"fresh initialization before antecedent state construction",
    "baseline_hcof_m2_per_day":h4_reference["initialize"]["hcof_m2_per_day"],
    "baseline_rhs_m3_per_day":h4_reference["initialize"]["rhs_m3_per_day"],
    "baseline_predictor_u":h4_reference["initialize"]["e1"]["u"],
    "baseline_predictor_qbot_native_per_day":h4_reference["initialize"]["e1"]["q_bot_predictor_cm_per_day"],
    "antecedent_origin":"WET_THEN_DRY",
    "accepted_whole_window_bottom_outward_exchange_native":(
        h4_probe["bottom_outward_exchange_native"] if h4_probe else None
    ),
    "terminal_bottom_outward_flux_native":(
        h4_probe["terminal_bottom_outward_flux_native"] if h4_probe else None
    ),
    "q_swap_m_per_s_from_whole_window_exchange":(
        h4_probe["q_swap_m_per_s"] if h4_probe else None
    ),
    "physical_local_derivative_native_per_m":(
        h3["origins"]["WET_THEN_DRY"][str(PRIMARY_PROBE_DURATION)]["derivative_native_per_m"]
    ),
    "production_defect_claim":False,
}
if h4_probe is not None and validate_probe(h4_reference):
    reconstructed=(h4_probe["bottom_outward_exchange_native"]/PRIMARY_PROBE_DURATION)*0.01/86400.0
    h4["q_swap_reconstructed_m_per_s"]=reconstructed
    h4["q_swap_conversion_abs_error"]=abs(reconstructed-h4_probe["q_swap_m_per_s"])
    h4_valid=math.isclose(reconstructed,h4_probe["q_swap_m_per_s"],rel_tol=1e-12,abs_tol=1e-30)
else:
    h4_valid=False
h4_disposition=("SUPPORTED_SEMANTIC_SEPARATION" if h4_valid
                else "PROVENANCE_OR_CONVERSION_FAILURE")


evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06a.h1_h4_experiment.v1",
    "preregistration_commit":"562853f7dd1a53c8301b0d4648f474084cfd2734",
    "production_changes":False,
    "frozen_parameters":{
        "H_star_m":H_STAR,
        "antecedent_duration_day":ANTECEDENT_DURATION,
        "wet_top_flux_native_per_day":WET,
        "dry_top_flux_native_per_day":DRY,
        "primary_probe_duration_day":PRIMARY_PROBE_DURATION,
        "tangent_probe_durations_day":list(TANGENT_DURATIONS),
        "delta_H_m":DELTA_H,
        "mass_gate_native":MASS_GATE,
        "response_threshold_native":RESPONSE_THRESHOLD,
        "tangent_threshold_native_per_m":TANGENT_THRESHOLD,
        "H2_profile_water_tolerance_native":H2_WATER_TOL,
        "H2_M1_separation_native":H2_M1_MIN,
    },
    "H1":{
        "origins":{
            name:{
                "endpoint_state":data["run"]["endpoint_state"],
                "endpoint_obs":data["run"]["endpoint_obs"],
                "probe_diag":data["run"]["probe"]["diag"] if data["run"]["probe"] else None,
                "valid":data["valid"],
                "exact_replay":data["exact_replay"],
            } for name,data in h1.items()
        },
        "endpoint_states_different":h1_state_different,
        "E_A_native":e_a,
        "E_B_native":e_b,
        "delta_E_native":h1_delta,
        "abs_delta_E_native":h1_abs_delta,
        "disposition":h1_disposition,
    },
    "H2":{
        "candidate_order":[c["name"] for c in h2_candidates],
        "candidates":h2_candidates,
        "selected_match":h2_match,
        "probe":h2_probe,
        "disposition":h2_disposition,
    },
    "H3":{
        "origins":h3["origins"],
        "state_comparisons":state_comparisons,
        "window_comparisons":window_comparisons,
        "disposition":h3_disposition,
    },
    "H4":{
        "evidence":h4,
        "disposition":h4_disposition,
    },
    "nonclaims":[
        "no production coupling admission",
        "no production sign-flip admission",
        "no second MODFLOW hydraulic state variable",
        "no H5 management conclusion",
        "baseline predictor coefficients are not antecedent-origin physical tangents",
    ],
}
print("RZM06A_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A_H1_H4_EXPERIMENT=PASS")
