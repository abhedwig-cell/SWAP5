from __future__ import annotations

import json, math, os, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

LIB=os.environ["FGC44_REAL_SWAP_LIB"]
EXPECTED_Z=[-2.5,-7.5,-12.5,-17.5,-22.5,-27.5,-35.0,-45.0,-55.0,-65.0,-75.0,-85.0,-95.0,-125.0,-175.0,-225.0,-275.0]
EXPECTED_DZ=[5.0,5.0,5.0,5.0,5.0,5.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,50.0,50.0,50.0,50.0]
MASS_GATE=1e-12
RECON_TOL=1e-12
HYDRO_TOL=1e-12
DURATIONS=[0.01,0.001,0.0001]
AMPLITUDES=[1.0,0.1,0.01,0.001]

def reconstruct(nodes):
    theta=nodes["water_content"]; z=nodes["z_native"]; dz=nodes["dz_native"]
    profile=sum(t*d for t,d in zip(theta,dz))
    weighted=sum(t*d*zz for t,d,zz in zip(theta,dz,z))
    m1=weighted/profile
    root=0.0
    overlaps=[]
    for t,zz,d in zip(theta,z,dz):
        depth_top=max(0.0,-(zz+0.5*d))
        depth_bottom=max(0.0,-(zz-0.5*d))
        overlap=max(0.0,min(depth_bottom,30.0)-min(depth_top,30.0))
        overlaps.append(overlap)
        root+=t*overlap
    return {
        "profile_water_native":profile,
        "root_water_native":root,
        "distribution_moment_native":m1,
        "root_overlap_by_node":overlaps,
        "root_positive_node_count":sum(1 for x in overlaps if x>0.0),
    }

def redact_diag(d):
    keep=[
        "available","call_status","forcing_status","result_status","completed","candidate_ready",
        "mass_complete","committed","transaction_calls","accepted_substeps","attempts","retries",
        "trial_rollbacks","solver_rejections","temporal_rejections","temporal_unavailable_rejections",
        "mass_rejections","internal_retries","requested_top_flux_cm_per_day","requested_head_m",
        "duration_day","t0_day","t1_day","materialized_top_flux_cm_per_day",
        "materialized_bottom_head_cm","mass_residual_native",
    ]
    return {k:d[k] for k in keep}

def baseline():
    s=Fgc44RealSwap(LIB)
    hcof,rhs,href=s.initialize()
    state0=s.state(); obs0=s.committed_profile_observables(); nodes0=s.committed_profile_nodes()
    state1=s.state(); obs1=s.committed_profile_observables(); nodes1=s.committed_profile_nodes()
    assert state0==state1 and obs0==obs1 and nodes0==nodes1
    assert nodes0["active_nodes"]==17
    assert nodes0["z_native"]==EXPECTED_Z
    assert nodes0["dz_native"]==EXPECTED_DZ

    total_heads=[h+z for h,z in zip(nodes0["pressure_head_native"],nodes0["z_native"])]
    assert max(total_heads)-min(total_heads)<=HYDRO_TOL, total_heads
    assert abs(total_heads[0]+77.5)<=HYDRO_TOL, total_heads

    rr=reconstruct(nodes0)
    assert rr["root_positive_node_count"]==6
    errs={
        "profile_water":rr["profile_water_native"]-obs0["profile_water_cm"],
        "root_water":rr["root_water_native"]-obs0["root_water_cm"],
        "distribution_moment":rr["distribution_moment_native"]-obs0["distribution_moment_cm"],
    }
    assert all(abs(x)<=RECON_TOL for x in errs.values()),(rr,obs0,errs)
    assert math.isfinite(href) and -0.79<=href<=-0.76,href

    pre_state=s.state(); pre_obs=s.committed_profile_observables(); pre_nodes=s.committed_profile_nodes()
    status,d=s.research_interval(0.0,href,1e-4,commit=False)
    post_state=s.state(); post_obs=s.committed_profile_observables(); post_nodes=s.committed_profile_nodes()
    zero_ok=(status==0 and d["completed"] and d["candidate_ready"] and d["mass_complete"]
             and not d["committed"] and abs(d["mass_residual_native"])<=MASS_GATE
             and pre_state==post_state and pre_obs==post_obs and pre_nodes==post_nodes)
    assert zero_ok,(status,d)
    return {
        "hcof":hcof,"rhs":rhs,"reference_head_m":href,
        "state":state0,"aggregate_obs":obs0,"nodes":nodes0,
        "hydrostatic_total_head_native":total_heads,
        "reconstructed":rr,"reconstruction_error":errs,
        "zero_probe":{"status":status,"accepted":zero_ok,"diag":redact_diag(d)},
        "diagnostics_read_only":True,
    }

def point(spec):
    s=Fgc44RealSwap(LIB); _,_,href=s.initialize()
    q=float(spec["top_flux"]); dt=float(spec["duration_day"])
    pre_state=s.state(); pre_obs=s.committed_profile_observables(); pre_nodes=s.committed_profile_nodes()
    status,d=s.research_interval(q,href,dt,commit=False)
    post_state=s.state(); post_obs=s.committed_profile_observables(); post_nodes=s.committed_profile_nodes()
    preserved=(pre_state==post_state and pre_obs==post_obs and pre_nodes==post_nodes)
    assert preserved
    accepted=(status==0 and d["completed"] and d["candidate_ready"] and d["mass_complete"]
              and not d["committed"] and abs(d["mass_residual_native"])<=MASS_GATE)
    return {
        "top_flux_cm_per_day":q,"duration_day":dt,"status":status,
        "accepted":accepted,"origin_preserved":preserved,"diag":redact_diag(d),
    }

if "RZM06C02_CHILD_SPEC" in os.environ:
    out=point(json.loads(os.environ["RZM06C02_CHILD_SPEC"]))
    print("RZM06C02_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)

def fresh(spec):
    env=dict(os.environ)
    env["RZM06C02_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    rows=[x for x in p.stdout.splitlines() if x.startswith("RZM06C02_CHILD_JSON ")]
    assert len(rows)==1,(p.stdout,p.stderr)
    return json.loads(rows[0].split(" ",1)[1])

base=baseline()
mapping=[]
two_sided=[]
for amp in AMPLITUDES:
    for dt in DURATIONS:
        neg=fresh({"top_flux":-amp,"duration_day":dt})
        pos=fresh({"top_flux": amp,"duration_day":dt})
        both=neg["accepted"] and pos["accepted"]
        rec={
            "amplitude_abs_cm_per_day":amp,"duration_day":dt,
            "negative_into_profile":neg,"positive_outward":pos,
            "both_signs_admitted":both,
        }
        mapping.append(rec)
        if both:
            two_sided.append({"amplitude_abs_cm_per_day":amp,"duration_day":dt,
                              "impulse_abs_cm":amp*dt})

if two_sided:
    disposition="QUALIFIED_NATIVE_CM_CARRIER_WITH_NONZERO_TWO_SIDED_ENVELOPE"
    strongest=max(two_sided,key=lambda x:(x["impulse_abs_cm"],x["amplitude_abs_cm_per_day"],x["duration_day"]))
else:
    disposition="QUALIFIED_CARRIER_BUT_NO_NONZERO_FORCING_ENVELOPE"
    strongest=None

evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06c02.native_cm_resolution_bridge.v1",
    "preregistration_commit":"337d32821a25aaebf5eddc9d84f5724c94d249e9",
    "production_changes":False,
    "classification":"real HeadCalc/B110 research carrier; synthetic native-cm 17-node profile; not Hupsel",
    "baseline":base,
    "forcing_map":mapping,
    "two_sided_admitted_points":two_sided,
    "strongest_two_sided_point":strongest,
    "disposition":disposition,
    "nonclaims":[
        "no H2 support or falsification",
        "no Hupsel equivalence",
        "no production coupling admission",
        "no production vertical-grid recommendation",
    ],
}
print("RZM06C02_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06C02_NATIVE_CM_RESOLUTION_BRIDGE=PASS")
