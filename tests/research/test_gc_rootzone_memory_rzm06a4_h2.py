from __future__ import annotations

import json, math, os, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

LIB=os.environ["FGC44_REAL_SWAP_LIB"]
H_STAR=-0.7149999706136307
MASS_GATE=1e-12
WATER_TOL=1e-6
M1_MIN=1e-4
RESPONSE_THRESHOLD=1e-18
PROBE_DURATION=1e-4
AMPLITUDES=[0.1,0.05,0.02,0.01,0.005,0.002,0.001]
DURATIONS=[0.01,0.005,0.002]
REPEAT_COUNTS=[10,5,2,1]
RELAX_COUNTS=[0,1,5,20]

def redact(d):
    keys=["available","call_status","forcing_status","result_status","completed","candidate_ready",
          "mass_complete","committed","transaction_calls","accepted_substeps","attempts","retries",
          "trial_rollbacks","solver_rejections","temporal_rejections","temporal_unavailable_rejections",
          "mass_rejections","internal_retries","requested_top_flux_cm_per_day","requested_head_m",
          "duration_day","t0_day","t1_day","materialized_top_flux_cm_per_day",
          "materialized_bottom_head_cm","mass_residual_native"]
    return {k:d[k] for k in keys}

def fresh(mode,spec):
    env=dict(os.environ)
    env["RZM06A4_CHILD_MODE"]=mode
    env["RZM06A4_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    rows=[x for x in p.stdout.splitlines() if x.startswith("RZM06A4_CHILD_JSON ")]
    assert len(rows)==1,(p.stdout,p.stderr)
    return json.loads(rows[0].split(" ",1)[1])

def stage1_child(spec):
    s=Fgc44RealSwap(LIB); s.initialize()
    q=float(spec["top_flux"]); dt=float(spec["duration_day"])
    pre_s=s.state(); pre_o=s.committed_profile_observables()
    status,d=s.research_interval(q,H_STAR,dt,commit=False)
    post_s=s.state(); post_o=s.committed_profile_observables()
    assert pre_s==post_s and pre_o==post_o
    ok=(status==0 and d["completed"] and d["candidate_ready"] and d["mass_complete"]
        and not d["committed"] and abs(d["mass_residual_native"])<=MASS_GATE)
    return {"top_flux":q,"duration_day":dt,"status":status,"accepted":ok,
            "diag":redact(d),"origin_preserved":True}

def sequence(q,dt,n,r,order):
    neg=-abs(q); pos=abs(q)
    if order=="NEG_POS_ZERO": vals=[neg]*n+[pos]*n+[0.0]*r
    elif order=="POS_NEG_ZERO": vals=[pos]*n+[neg]*n+[0.0]*r
    else: raise ValueError(order)
    return [(v,dt) for v in vals]

def construct_child(spec,probe=False):
    s=Fgc44RealSwap(LIB); s.initialize()
    q=float(spec["amplitude"]); dt=float(spec["duration_day"])
    n=int(spec["repeat_count"]); r=int(spec["relax_count"]); order=spec["order"]
    seq=sequence(q,dt,n,r,order)
    agg={"total_retries":0,"total_temporal_rejections":0,"total_solver_rejections":0,
         "total_trial_rollbacks":0,"max_attempts":0,"max_accepted_substeps":0,
         "max_abs_mass_residual_native":0.0}
    fail=None; committed=0
    for i,(top,duration) in enumerate(seq):
        pre_s=s.state(); pre_o=s.committed_profile_observables()
        status,d=s.research_interval(top,H_STAR,duration,commit=True)
        post_s=s.state(); post_o=s.committed_profile_observables()
        agg["total_retries"]+=int(d["retries"]); agg["total_temporal_rejections"]+=int(d["temporal_rejections"])
        agg["total_solver_rejections"]+=int(d["solver_rejections"]); agg["total_trial_rollbacks"]+=int(d["trial_rollbacks"])
        agg["max_attempts"]=max(agg["max_attempts"],int(d["attempts"]))
        agg["max_accepted_substeps"]=max(agg["max_accepted_substeps"],int(d["accepted_substeps"]))
        agg["max_abs_mass_residual_native"]=max(agg["max_abs_mass_residual_native"],abs(float(d["mass_residual_native"])))
        if status!=0:
            assert pre_s==post_s and pre_o==post_o
            fail={"interval_index":i,"top_flux":top,"status":status,"diag":redact(d)}
            break
        assert d["committed"] and d["completed"] and d["candidate_ready"] and d["mass_complete"]
        assert abs(d["mass_residual_native"])<=MASS_GATE
        assert post_s[0]==pre_s[0]+1 and post_s[2:]==pre_s[2:]
        assert math.isclose(post_s[1],pre_s[1]+duration,rel_tol=0,abs_tol=1e-12)
        committed+=1
    accepted=(fail is None and committed==len(seq))
    out={"accepted":accepted,"amplitude":q,"duration_day":dt,"repeat_count":n,"relax_count":r,
         "order":order,"requested_intervals":len(seq),"committed_intervals":committed,
         "failure":fail,"aggregate":agg,"endpoint_state":s.state(),
         "endpoint_obs":s.committed_profile_observables()}
    if not probe or not accepted: return out
    pre_s=s.state(); pre_o=s.committed_profile_observables()
    status,d=s.research_interval(0.0,H_STAR,PROBE_DURATION,commit=False)
    post_s=s.state(); post_o=s.committed_profile_observables()
    valid=(status==0 and d["completed"] and d["candidate_ready"] and d["mass_complete"]
           and not d["committed"] and abs(d["mass_residual_native"])<=MASS_GATE
           and pre_s==post_s and pre_o==post_o)
    out["probe"]={"status":status,"valid":valid,"diag":d,"pre_state":pre_s,"post_state":post_s,
                  "pre_obs":pre_o,"post_obs":post_o}
    return out

if "RZM06A4_CHILD_MODE" in os.environ:
    mode=os.environ["RZM06A4_CHILD_MODE"]; spec=json.loads(os.environ["RZM06A4_CHILD_SPEC"])
    if mode=="stage1": out=stage1_child(spec)
    elif mode=="construct": out=construct_child(spec,False)
    elif mode=="probe": out=construct_child(spec,True)
    else: raise RuntimeError(mode)
    print("RZM06A4_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)

# Stage 1: forcing admissibility without state-observable or response access.
stage1=[]; admitted=[]
for amp in AMPLITUDES:
    for dt in DURATIONS:
        neg=fresh("stage1",{"top_flux":-amp,"duration_day":dt})
        pos=fresh("stage1",{"top_flux": amp,"duration_day":dt})
        both=neg["accepted"] and pos["accepted"]
        p={"amplitude":amp,"duration_day":dt,"impulse":amp*dt,"both_signs_admitted":both,
           "negative_into_profile":neg,"positive_outward":pos}
        stage1.append(p)
        if both: admitted.append(p)

selected=None
if admitted:
    x=max(admitted,key=lambda p:(p["impulse"],p["amplitude"],p["duration_day"]))
    selected={"amplitude":x["amplitude"],"duration_day":x["duration_day"],"impulse":x["impulse"]}

# Stage 2: opposite-order equal-integral histories. E_c remains unavailable.
construction=[]; pair=None
if selected is not None:
    for n in REPEAT_COUNTS:
        for r in RELAX_COUNTS:
            base={"amplitude":selected["amplitude"],"duration_day":selected["duration_day"],
                  "repeat_count":n,"relax_count":r}
            a=fresh("construct",{**base,"order":"NEG_POS_ZERO"})
            b=fresh("construct",{**base,"order":"POS_NEG_ZERO"})
            rec={"repeat_count":n,"relax_count":r,"A":a,"B":b,
                 "pair_admitted":a["accepted"] and b["accepted"],
                 "delta_profile_water_native":None,"delta_M1_native":None,
                 "meets_h2_endpoint_criteria":False}
            if rec["pair_admitted"]:
                dw=abs(b["endpoint_obs"]["profile_water_cm"]-a["endpoint_obs"]["profile_water_cm"])
                dm=abs(b["endpoint_obs"]["distribution_moment_cm"]-a["endpoint_obs"]["distribution_moment_cm"])
                rec["delta_profile_water_native"]=dw; rec["delta_M1_native"]=dm
                rec["meets_h2_endpoint_criteria"]=(dw<=WATER_TOL and dm>=M1_MIN)
                if rec["meets_h2_endpoint_criteria"]:
                    pair={"amplitude":selected["amplitude"],"duration_day":selected["duration_day"],
                          "repeat_count":n,"relax_count":r,
                          "A_endpoint_state":a["endpoint_state"],"B_endpoint_state":b["endpoint_state"],
                          "A_endpoint_obs":a["endpoint_obs"],"B_endpoint_obs":b["endpoint_obs"],
                          "delta_profile_water_native":dw,"delta_M1_native":dm}
            construction.append(rec)
            if pair is not None: break
        if pair is not None: break

probe=None
if selected is None:
    disposition="NO_SYMMETRIC_TOP_FORCING"
elif pair is None:
    disposition="NO_MATCH"
else:
    probe={}
    base={"amplitude":pair["amplitude"],"duration_day":pair["duration_day"],
          "repeat_count":pair["repeat_count"],"relax_count":pair["relax_count"]}
    for label,order in (("A","NEG_POS_ZERO"),("B","POS_NEG_ZERO")):
        first=fresh("probe",{**base,"order":order}); replay=fresh("probe",{**base,"order":order})
        exact=(first==replay)
        valid=(first["accepted"] and first["probe"]["valid"] and exact
               and first["endpoint_obs"]==pair[f"{label}_endpoint_obs"])
        probe[label]={"valid":valid,"exact_replay":exact,"endpoint_state":first["endpoint_state"],
                      "endpoint_obs":first["endpoint_obs"],"probe":first.get("probe")}
    if probe["A"]["valid"] and probe["B"]["valid"]:
        ea=probe["A"]["probe"]["diag"]["bottom_outward_exchange_native"]
        eb=probe["B"]["probe"]["diag"]["bottom_outward_exchange_native"]
        de=eb-ea
        probe.update(E_A_native=ea,E_B_native=eb,delta_E_native=de,abs_delta_E_native=abs(de))
        disposition="SUPPORTED" if abs(de)>RESPONSE_THRESHOLD else "NOT_SUPPORTED_AT_FROZEN_RESOLUTION"
    else:
        disposition="PROBE_OR_REPEATABILITY_FAILURE"

evidence={
 "schema":"swap5.gc_rootzone_memory.rzm06a4.strong_top_forcing_h2_experiment.v1",
 "preregistration_commit":"67e6cf09aa870c77cbb5059a834c2c6e14632a93",
 "production_changes":False,
 "sign_convention":{"negative_top_flux":"into-profile/infiltration","positive_top_flux":"outward/top extraction"},
 "frozen":{"H_star_m":H_STAR,"amplitudes_cm_per_day":AMPLITUDES,"durations_day":DURATIONS,
           "repeat_counts":REPEAT_COUNTS,"relax_counts":RELAX_COUNTS,
           "profile_water_tolerance_native":WATER_TOL,"M1_separation_native":M1_MIN,
           "response_threshold_native":RESPONSE_THRESHOLD,"mass_gate_native":MASS_GATE},
 "stage1_admissibility":stage1,"selected_forcing":selected,
 "stage2_construction":construction,"selected_pair":pair,"probe_evidence":probe,
 "disposition":disposition,
 "nonclaims":["no production coupling admission","no second MODFLOW hydraulic state variable admission",
              "no production forcing recommendation","no H5 management conclusion"]
}
print("RZM06A4_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A4_STRONG_TOP_FORCING_H2_EXPERIMENT=PASS")
