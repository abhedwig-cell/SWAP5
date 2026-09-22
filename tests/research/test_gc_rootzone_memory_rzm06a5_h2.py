from __future__ import annotations

import json, math, os, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

LIB=os.environ["FGC44_REAL_SWAP_LIB"]
H_STAR=-0.7149999706136307
PULSE_ABS=1e-4
DT=0.01
PULSE_COUNTS=[100,50,20,10]
RELAX_COUNTS=[0,50]
DIRECTIONS=[
    ("NEG_INTO_PROFILE",-PULSE_ABS),
    ("POS_OUTWARD", PULSE_ABS),
]
MASS_GATE=1e-12
WATER_TOL=1e-6
M1_MIN=1e-4
RESPONSE_THRESHOLD=1e-18
PROBE_DURATION=1e-4

def redact(d):
    keys=["available","call_status","forcing_status","result_status","completed","candidate_ready",
          "mass_complete","committed","transaction_calls","accepted_substeps","attempts","retries",
          "trial_rollbacks","solver_rejections","temporal_rejections","temporal_unavailable_rejections",
          "mass_rejections","internal_retries","requested_top_flux_cm_per_day","requested_head_m",
          "duration_day","t0_day","t1_day","materialized_top_flux_cm_per_day",
          "materialized_bottom_head_cm","mass_residual_native"]
    return {k:d[k] for k in keys}

def fresh(spec,probe=False):
    env=dict(os.environ)
    env["RZM06A5_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    env["RZM06A5_CHILD_PROBE"]="1" if probe else "0"
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    rows=[x for x in p.stdout.splitlines() if x.startswith("RZM06A5_CHILD_JSON ")]
    assert len(rows)==1,(p.stdout,p.stderr)
    return json.loads(rows[0].split(" ",1)[1])

def sequence(q,n,r,timing):
    if timing=="EARLY":
        vals=[q]*n+[0.0]*n+[0.0]*r
    elif timing=="LATE":
        vals=[0.0]*n+[q]*n+[0.0]*r
    else:
        raise ValueError(timing)
    return vals

def construct_child(spec,probe=False):
    s=Fgc44RealSwap(LIB); s.initialize()
    q=float(spec["top_flux"]); n=int(spec["pulse_count"]); r=int(spec["relax_count"])
    timing=spec["timing"]; vals=sequence(q,n,r,timing)
    aggregate={"total_retries":0,"total_temporal_rejections":0,"total_solver_rejections":0,
               "total_trial_rollbacks":0,"max_attempts":0,"max_accepted_substeps":0,
               "max_abs_mass_residual_native":0.0}
    fail=None; committed=0
    for i,top in enumerate(vals):
        pre_s=s.state(); pre_o=s.committed_profile_observables()
        status,d=s.research_interval(top,H_STAR,DT,commit=True)
        post_s=s.state(); post_o=s.committed_profile_observables()
        aggregate["total_retries"]+=int(d["retries"])
        aggregate["total_temporal_rejections"]+=int(d["temporal_rejections"])
        aggregate["total_solver_rejections"]+=int(d["solver_rejections"])
        aggregate["total_trial_rollbacks"]+=int(d["trial_rollbacks"])
        aggregate["max_attempts"]=max(aggregate["max_attempts"],int(d["attempts"]))
        aggregate["max_accepted_substeps"]=max(aggregate["max_accepted_substeps"],int(d["accepted_substeps"]))
        aggregate["max_abs_mass_residual_native"]=max(
            aggregate["max_abs_mass_residual_native"],abs(float(d["mass_residual_native"])))
        if status!=0:
            assert pre_s==post_s and pre_o==post_o
            fail={"interval_index":i,"top_flux":top,"status":status,"diag":redact(d)}
            break
        assert d["committed"] and d["completed"] and d["candidate_ready"] and d["mass_complete"]
        assert abs(d["mass_residual_native"])<=MASS_GATE
        assert post_s[0]==pre_s[0]+1 and post_s[2:]==pre_s[2:]
        assert math.isclose(post_s[1],pre_s[1]+DT,rel_tol=0,abs_tol=1e-12)
        committed+=1

    accepted=(fail is None and committed==len(vals))
    out={"accepted":accepted,"top_flux":q,"pulse_count":n,"relax_count":r,"timing":timing,
         "requested_intervals":len(vals),"committed_intervals":committed,"failure":fail,
         "aggregate":aggregate,"endpoint_state":s.state(),
         "endpoint_obs":s.committed_profile_observables()}

    if not probe or not accepted:
        return out

    pre_s=s.state(); pre_o=s.committed_profile_observables()
    status,d=s.research_interval(0.0,H_STAR,PROBE_DURATION,commit=False)
    post_s=s.state(); post_o=s.committed_profile_observables()
    valid=(status==0 and d["completed"] and d["candidate_ready"] and d["mass_complete"]
           and not d["committed"] and abs(d["mass_residual_native"])<=MASS_GATE
           and pre_s==post_s and pre_o==post_o)
    out["probe"]={"status":status,"valid":valid,"diag":d,
                  "pre_state":pre_s,"post_state":post_s,
                  "pre_obs":pre_o,"post_obs":post_o}
    return out

if "RZM06A5_CHILD_SPEC" in os.environ:
    spec=json.loads(os.environ["RZM06A5_CHILD_SPEC"])
    out=construct_child(spec,os.environ.get("RZM06A5_CHILD_PROBE")=="1")
    print("RZM06A5_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)

construction=[]
selected=None

for n in PULSE_COUNTS:
    for r in RELAX_COUNTS:
        for direction,q in DIRECTIONS:
            base={"top_flux":q,"pulse_count":n,"relax_count":r}
            early=fresh({**base,"timing":"EARLY"})
            late=fresh({**base,"timing":"LATE"})
            pair_admitted=early["accepted"] and late["accepted"]
            rec={"direction":direction,"top_flux":q,"pulse_count":n,"relax_count":r,
                 "pair_admitted":pair_admitted,"EARLY":early,"LATE":late,
                 "delta_profile_water_native":None,"delta_M1_native":None,
                 "meets_h2_endpoint_criteria":False}
            if not pair_admitted:
                # Failed trajectories are useful numerical evidence, but their endpoint
                # observables are not exposed to the endpoint selector or persisted.
                rec["EARLY"].pop("endpoint_obs",None)
                rec["LATE"].pop("endpoint_obs",None)
            else:
                dw=abs(late["endpoint_obs"]["profile_water_cm"]-early["endpoint_obs"]["profile_water_cm"])
                dm=abs(late["endpoint_obs"]["distribution_moment_cm"]-early["endpoint_obs"]["distribution_moment_cm"])
                rec["delta_profile_water_native"]=dw
                rec["delta_M1_native"]=dm
                rec["meets_h2_endpoint_criteria"]=(dw<=WATER_TOL and dm>=M1_MIN)
                if rec["meets_h2_endpoint_criteria"]:
                    selected={"direction":direction,"top_flux":q,"pulse_count":n,"relax_count":r,
                              "EARLY_endpoint_state":early["endpoint_state"],
                              "LATE_endpoint_state":late["endpoint_state"],
                              "EARLY_endpoint_obs":early["endpoint_obs"],
                              "LATE_endpoint_obs":late["endpoint_obs"],
                              "delta_profile_water_native":dw,"delta_M1_native":dm,
                              "integrated_prescribed_top_flux_native":q*DT*n,
                              "endpoint_time_day":early["endpoint_state"][1]}
            construction.append(rec)
            if selected is not None:
                break
        if selected is not None:
            break
    if selected is not None:
        break

probe=None
if selected is None:
    disposition="NO_MATCH"
else:
    probe={}
    base={"top_flux":selected["top_flux"],"pulse_count":selected["pulse_count"],
          "relax_count":selected["relax_count"]}
    for label,timing in (("EARLY","EARLY"),("LATE","LATE")):
        first=fresh({**base,"timing":timing},probe=True)
        replay=fresh({**base,"timing":timing},probe=True)
        exact=(first==replay)
        valid=(first["accepted"] and first["probe"]["valid"] and exact
               and first["endpoint_state"]==selected[f"{label}_endpoint_state"]
               and first["endpoint_obs"]==selected[f"{label}_endpoint_obs"])
        probe[label]={"valid":valid,"exact_replay":exact,
                      "endpoint_state":first["endpoint_state"],
                      "endpoint_obs":first["endpoint_obs"],
                      "probe":first.get("probe")}
    if probe["EARLY"]["valid"] and probe["LATE"]["valid"]:
        ee=probe["EARLY"]["probe"]["diag"]["bottom_outward_exchange_native"]
        el=probe["LATE"]["probe"]["diag"]["bottom_outward_exchange_native"]
        de=el-ee
        probe.update(E_EARLY_native=ee,E_LATE_native=el,
                     delta_E_native=de,abs_delta_E_native=abs(de))
        disposition="SUPPORTED" if abs(de)>RESPONSE_THRESHOLD else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION"
    else:
        disposition="PROBE_OR_REPEATABILITY_FAILURE"

evidence={
 "schema":"swap5.gc_rootzone_memory.rzm06a5.timing_redistribution_h2_experiment.v1",
 "preregistration_commit":"503b943b72de6f5d3c5d447781cd4605b8334eb4",
 "production_changes":False,
 "frozen":{"H_star_m":H_STAR,"pulse_abs_cm_per_day":PULSE_ABS,"duration_day":DT,
           "pulse_counts":PULSE_COUNTS,"relax_counts":RELAX_COUNTS,
           "direction_order":[x[0] for x in DIRECTIONS],
           "profile_water_tolerance_native":WATER_TOL,"M1_separation_native":M1_MIN,
           "response_threshold_native":RESPONSE_THRESHOLD,"mass_gate_native":MASS_GATE},
 "construction":construction,"selected_pair":selected,"probe_evidence":probe,
 "disposition":disposition,
 "nonclaims":["no production coupling admission","no second MODFLOW state-variable admission",
              "no production top-boundary recommendation","no H5 management conclusion"]
}
print("RZM06A5_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A5_TIMING_REDISTRIBUTION_H2_EXPERIMENT=PASS")
