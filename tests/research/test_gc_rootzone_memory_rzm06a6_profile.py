from __future__ import annotations

import json, math, os, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

LIB=os.environ["FGC44_REAL_SWAP_LIB"]
H_STAR=-0.7149999706136307
DT=0.01
MASS_GATE=1e-12
RECON_TOL=1e-13
EXPECTED_Z=[-0.25,-0.75,-1.50,-2.50]
EXPECTED_DZ=[0.50,0.50,1.00,1.00]

HISTORIES=[
    {"name":"BASELINE","top_flux":0.0,"pulse_count":0,"relax_count":0,"timing":"NONE"},
    {"name":"NEG_N100_R0_EARLY","top_flux":-1e-4,"pulse_count":100,"relax_count":0,"timing":"EARLY"},
    {"name":"NEG_N100_R0_LATE","top_flux":-1e-4,"pulse_count":100,"relax_count":0,"timing":"LATE"},
    {"name":"POS_N100_R0_EARLY","top_flux": 1e-4,"pulse_count":100,"relax_count":0,"timing":"EARLY"},
    {"name":"POS_N100_R0_LATE","top_flux": 1e-4,"pulse_count":100,"relax_count":0,"timing":"LATE"},
    {"name":"NEG_N100_R50_EARLY","top_flux":-1e-4,"pulse_count":100,"relax_count":50,"timing":"EARLY"},
    {"name":"NEG_N100_R50_LATE","top_flux":-1e-4,"pulse_count":100,"relax_count":50,"timing":"LATE"},
]
PAIRS=[
    ("NEG_N100_R0_EARLY","NEG_N100_R0_LATE"),
    ("POS_N100_R0_EARLY","POS_N100_R0_LATE"),
    ("NEG_N100_R50_EARLY","NEG_N100_R50_LATE"),
]

def sequence(spec):
    n=int(spec["pulse_count"]); r=int(spec["relax_count"]); q=float(spec["top_flux"])
    if spec["timing"]=="NONE":
        return []
    if spec["timing"]=="EARLY":
        return [q]*n+[0.0]*n+[0.0]*r
    if spec["timing"]=="LATE":
        return [0.0]*n+[q]*n+[0.0]*r
    raise ValueError(spec["timing"])

def reconstruct(nodes):
    theta=nodes["water_content"]; z=nodes["z_native"]; dz=nodes["dz_native"]
    w=sum(t*d for t,d in zip(theta,dz))
    weighted=sum(t*d*zz for t,d,zz in zip(theta,dz,z))
    m1=weighted/w
    root=0.0
    overlaps=[]
    for t,zz,d in zip(theta,z,dz):
        depth_top=max(0.0,-(zz+0.5*d))
        depth_bottom=max(0.0,-(zz-0.5*d))
        overlap=max(0.0,min(depth_bottom,0.30)-min(depth_top,0.30))
        overlaps.append(overlap)
        root+=t*overlap
    return {"profile_water":w,"root_water":root,"distribution_moment":m1,
            "root_overlap_by_node":overlaps}

def read_endpoint(s):
    state0=s.state(); obs0=s.committed_profile_observables()
    nodes1=s.committed_profile_nodes()
    state1=s.state(); obs1=s.committed_profile_observables()
    nodes2=s.committed_profile_nodes()
    state2=s.state(); obs2=s.committed_profile_observables()
    assert state0==state1==state2
    assert obs0==obs1==obs2
    assert nodes1==nodes2
    assert nodes1["active_nodes"]==4
    assert nodes1["z_native"]==EXPECTED_Z
    assert nodes1["dz_native"]==EXPECTED_DZ

    rr=reconstruct(nodes1)
    errors={
        "profile_water":rr["profile_water"]-obs0["profile_water_cm"],
        "root_water":rr["root_water"]-obs0["root_water_cm"],
        "distribution_moment":rr["distribution_moment"]-obs0["distribution_moment_cm"],
    }
    assert all(abs(v)<=RECON_TOL for v in errors.values()),(rr,obs0,errors)
    return {"state":state0,"aggregate_obs":obs0,"nodes":nodes1,
            "reconstructed":rr,"reconstruction_error":errors,
            "diagnostic_read_only":True}

def run_child(spec):
    s=Fgc44RealSwap(LIB); s.initialize()
    aggregate={"intervals":0,"total_retries":0,"total_temporal_rejections":0,
               "total_solver_rejections":0,"max_abs_mass_residual_native":0.0}
    for i,top in enumerate(sequence(spec)):
        pre_state=s.state(); pre_obs=s.committed_profile_observables()
        status,d=s.research_interval(top,H_STAR,DT,commit=True)
        post_state=s.state(); post_obs=s.committed_profile_observables()
        # Response/exchange fields exist in the shared research diagnostic ABI but
        # are deliberately neither inspected, selected on, nor persisted in A6.
        if status!=0:
            assert pre_state==post_state and pre_obs==post_obs
            return {"name":spec["name"],"accepted":False,"failed_interval":i,
                    "status":status,"endpoint":read_endpoint(s)}
        assert d["completed"] and d["candidate_ready"] and d["mass_complete"] and d["committed"]
        assert abs(d["mass_residual_native"])<=MASS_GATE
        assert post_state[0]==pre_state[0]+1 and post_state[2:]==pre_state[2:]
        assert math.isclose(post_state[1],pre_state[1]+DT,rel_tol=0,abs_tol=1e-12)
        aggregate["intervals"]+=1
        aggregate["total_retries"]+=int(d["retries"])
        aggregate["total_temporal_rejections"]+=int(d["temporal_rejections"])
        aggregate["total_solver_rejections"]+=int(d["solver_rejections"])
        aggregate["max_abs_mass_residual_native"]=max(
            aggregate["max_abs_mass_residual_native"],abs(float(d["mass_residual_native"])))
    return {"name":spec["name"],"accepted":True,"aggregate":aggregate,
            "endpoint":read_endpoint(s)}

if "RZM06A6_CHILD_SPEC" in os.environ:
    spec=json.loads(os.environ["RZM06A6_CHILD_SPEC"])
    out=run_child(spec)
    print("RZM06A6_CHILD_JSON",json.dumps(out,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)

def fresh(spec):
    env=dict(os.environ)
    env["RZM06A6_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    rows=[x for x in p.stdout.splitlines() if x.startswith("RZM06A6_CHILD_JSON ")]
    assert len(rows)==1,(p.stdout,p.stderr)
    return json.loads(rows[0].split(" ",1)[1])

runs={}
for spec in HISTORIES:
    r=fresh(spec)
    assert r["accepted"],r
    runs[spec["name"]]=r

pair_evidence=[]
for a_name,b_name in PAIRS:
    a=runs[a_name]["endpoint"]; b=runs[b_name]["endpoint"]
    an=a["nodes"]; bn=b["nodes"]
    assert an["z_native"]==bn["z_native"] and an["dz_native"]==bn["dz_native"]
    dh=[bb-aa for aa,bb in zip(an["pressure_head_native"],bn["pressure_head_native"])]
    dt=[bb-aa for aa,bb in zip(an["water_content"],bn["water_content"])]
    ds=[x*d for x,d in zip(dt,an["dz_native"])]
    dW=b["aggregate_obs"]["profile_water_cm"]-a["aggregate_obs"]["profile_water_cm"]
    dM=b["aggregate_obs"]["distribution_moment_cm"]-a["aggregate_obs"]["distribution_moment_cm"]
    pair_evidence.append({
        "A":a_name,"B":b_name,
        "delta_pressure_head_native_by_node":dh,
        "delta_water_content_by_node":dt,
        "delta_storage_native_by_node":ds,
        "max_abs_delta_pressure_head_native":max(abs(x) for x in dh),
        "max_abs_delta_water_content":max(abs(x) for x in dt),
        "l1_redistributed_storage_native":sum(abs(x) for x in ds),
        "signed_node_storage_difference_native":sum(ds),
        "aggregate_delta_profile_water_native":dW,
        "aggregate_delta_M1_native":dM,
        "node_storage_minus_aggregate_delta_native":sum(ds)-dW,
    })

evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06a6.node_profile_audit.v1",
    "preregistration_commit":"bf201af7c604a94b3fe36bc5ef1eb7674156c8f6",
    "production_changes":False,
    "carrier":{
        "active_nodes":4,
        "z_native":EXPECTED_Z,
        "dz_native":EXPECTED_DZ,
        "geometry_semantics":"metre-scale per research bridge comment",
        "pressure_head_semantics":"native HeadCalc centimetre coordinate",
        "solver_scope":"real HeadCalc with explicit B110 constitutive provider on focused FSI fixture"
    },
    "reconstruction_tolerance_native":RECON_TOL,
    "runs":runs,
    "pair_evidence":pair_evidence,
    "disposition":"QUALIFIED_NODE_PROFILE_AUDIT",
    "nonclaims":[
        "no H2 support or falsification from A6 alone",
        "no production diagnostic ABI",
        "no production coupling admission",
        "no claim that the four-node fixture represents a full real-SWAP discretization"
    ]
}
print("RZM06A6_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A6_NODE_PROFILE_AUDIT=PASS")
