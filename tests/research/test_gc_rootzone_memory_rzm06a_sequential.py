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


def child_run(spec: dict) -> dict:
    s=Fgc44RealSwap(LIB)
    _,_,href=s.initialize()
    before_state=s.state()
    before_obs=s.committed_profile_observables()
    before_obs_repeat=s.committed_profile_observables()
    assert before_obs == before_obs_repeat
    records=[]
    for op in spec["ops"]:
        head=href if op.get("head_m") is None else float(op["head_m"])
        status,diag=s.research_interval(
            float(op["top_flux_cm_per_day"]),head,float(op["duration_day"]),commit=bool(op["commit"])
        )
        records.append({
            "status":status,
            "diag":diag,
            "state":s.state(),
            "obs":s.committed_profile_observables(),
        })
    return {
        "href_m":href,
        "before_state":before_state,
        "before_obs":before_obs,
        "records":records,
    }


def run_fresh(spec: dict) -> dict:
    env=dict(os.environ)
    env["RZM06A_CHILD_SPEC"]=json.dumps(spec,separators=(",",":"))
    p=subprocess.run([sys.executable,__file__],env=env,text=True,capture_output=True,check=True)
    lines=[line for line in p.stdout.splitlines() if line.startswith("RZM06A_CHILD_JSON ")]
    assert len(lines)==1,(p.stdout,p.stderr)
    return json.loads(lines[0].split(" ",1)[1])


if "RZM06A_CHILD_SPEC" in os.environ:
    result=child_run(json.loads(os.environ["RZM06A_CHILD_SPEC"]))
    print("RZM06A_CHILD_JSON",json.dumps(result,sort_keys=True,separators=(",",":")))
    raise SystemExit(0)


# Infrastructure-only admissibility characterization.  Enumeration is fixed
# before any H1-H4 scientific probe exists.  Negative top flux is into the
# profile; positive top flux is out of the profile, as audited from the real
# serialized-reference mass accounting.
durations=[1.0e-2,1.0e-3,1.0e-4]
# Amendment after infrastructure run 35724013765: the first non-zero grid
# (1e-1,1e-2 cm/day) was entirely rejected and was 4-5 orders above the
# carrier's existing 1e-6 cm/day top-flux scale.  No scientific probe response
# was used.  Extend characterization downward around that existing scale.
top_fluxes=[
    -1.0e-1,1.0e-1,-1.0e-2,1.0e-2,
    -1.0e-4,1.0e-4,-1.0e-5,1.0e-5,-1.0e-6,1.0e-6,0.0,
]
characterization=[]
for duration in durations:
    for top_flux in top_fluxes:
        out=run_fresh({"ops":[{
            "top_flux_cm_per_day":top_flux,
            "duration_day":duration,
            "head_m":None,
            "commit":False,
        }]})
        rec=out["records"][0]
        characterization.append({
            "top_flux_cm_per_day":top_flux,
            "duration_day":duration,
            "head_m":out["href_m"],
            "status":rec["status"],
            "diag":rec["diag"],
        })
        # A read-only research probe must never mutate the committed origin.
        assert rec["state"]==out["before_state"]
        assert rec["obs"]==out["before_obs"]
        if rec["status"]==0:
            assert rec["diag"]["completed"]
            assert rec["diag"]["candidate_ready"]
            assert rec["diag"]["mass_complete"]
            assert abs(rec["diag"]["mass_residual_native"])<=1.0e-12

accepted=[c for c in characterization if c["status"]==0 and c["top_flux_cm_per_day"]!=0.0]
assert accepted,characterization
chosen=accepted[0]

# Accepted antecedent commit: exact revision/time semantics and a physically
# observable state change for the first admissible non-zero case.
commit_case=run_fresh({"ops":[{
    "top_flux_cm_per_day":chosen["top_flux_cm_per_day"],
    "duration_day":chosen["duration_day"],
    "head_m":None,
    "commit":True,
}]})
crec=commit_case["records"][0]
assert crec["status"]==0 and crec["diag"]["committed"]
assert crec["state"][0]==commit_case["before_state"][0]+1
assert math.isclose(
    crec["state"][1],commit_case["before_state"][1]+chosen["duration_day"],
    rel_tol=0.0,abs_tol=1.0e-14,
)
assert crec["obs"]!=commit_case["before_obs"]
assert crec["diag"]["mass_complete"]
assert abs(crec["diag"]["mass_residual_native"])<=1.0e-12

# Accepted-but-discarded and invalid trials are exact negative controls.
discard_case=run_fresh({"ops":[{
    "top_flux_cm_per_day":chosen["top_flux_cm_per_day"],
    "duration_day":chosen["duration_day"],
    "head_m":None,
    "commit":False,
}]})
drec=discard_case["records"][0]
assert drec["status"]==0 and not drec["diag"]["committed"]
assert drec["state"]==discard_case["before_state"]
assert drec["obs"]==discard_case["before_obs"]

failed_case=run_fresh({"ops":[{
    "top_flux_cm_per_day":chosen["top_flux_cm_per_day"],
    "duration_day":-1.0,
    "head_m":None,
    "commit":True,
}]})
frec=failed_case["records"][0]
assert frec["status"]!=0
assert frec["state"]==failed_case["before_state"]
assert frec["obs"]==failed_case["before_obs"]

# Deterministic replay from fresh identical initialization.
replay_a=run_fresh({"ops":[{
    "top_flux_cm_per_day":chosen["top_flux_cm_per_day"],
    "duration_day":chosen["duration_day"],
    "head_m":None,
    "commit":True,
}]})
replay_b=run_fresh({"ops":[{
    "top_flux_cm_per_day":chosen["top_flux_cm_per_day"],
    "duration_day":chosen["duration_day"],
    "head_m":None,
    "commit":True,
}]})
assert replay_a==replay_b

# Top forcing is an independent scalar: opposite top forcing at one H_c leaves
# the materialized bottom head unchanged while the materialized top flux changes.
amp=abs(chosen["top_flux_cm_per_day"])
neg=run_fresh({"ops":[{"top_flux_cm_per_day":-amp,"duration_day":chosen["duration_day"],"head_m":None,"commit":False}]})
pos=run_fresh({"ops":[{"top_flux_cm_per_day": amp,"duration_day":chosen["duration_day"],"head_m":None,"commit":False}]})
nd=neg["records"][0]["diag"]; pd=pos["records"][0]["diag"]
assert nd["materialized_top_flux_cm_per_day"]==-amp
assert pd["materialized_top_flux_cm_per_day"]== amp
assert nd["materialized_bottom_head_cm"]==pd["materialized_bottom_head_cm"]
assert nd["requested_head_m"]==pd["requested_head_m"]

# Sequential antecedent admissibility, still response-blind.  Enumerate the
# already ordered symmetric single-window admissible candidates and retain every
# rejected sequence.  Select the first candidate for which both forcing orders
# complete and commit.  No post-antecedent interface probe is executed here.
sequential_characterization=[]
selected_sequential=None
selected_wet_dry=None
selected_dry_wet=None
for duration in durations:
    for magnitude in [1.0e-1,1.0e-2,1.0e-4,1.0e-5,1.0e-6]:
        neg_case=next(c for c in characterization if c["duration_day"]==duration and c["top_flux_cm_per_day"]==-magnitude)
        pos_case=next(c for c in characterization if c["duration_day"]==duration and c["top_flux_cm_per_day"]== magnitude)
        if neg_case["status"]!=0 or pos_case["status"]!=0:
            continue
        wet={"top_flux_cm_per_day":-magnitude,"duration_day":duration,"head_m":None,"commit":True}
        dry={"top_flux_cm_per_day": magnitude,"duration_day":duration,"head_m":None,"commit":True}
        wet_dry=run_fresh({"ops":[wet,dry]})
        dry_wet=run_fresh({"ops":[dry,wet]})
        accepted_wet_dry=all(r["status"]==0 and r["diag"]["committed"] and r["diag"]["mass_complete"] for r in wet_dry["records"])
        accepted_dry_wet=all(r["status"]==0 and r["diag"]["committed"] and r["diag"]["mass_complete"] for r in dry_wet["records"])
        sequential_characterization.append({
            "duration_day":duration,
            "magnitude_cm_per_day":magnitude,
            "wet_then_dry":wet_dry,
            "dry_then_wet":dry_wet,
            "accepted_both_orders":bool(accepted_wet_dry and accepted_dry_wet),
        })
        if accepted_wet_dry and accepted_dry_wet:
            selected_sequential={"duration_day":duration,"magnitude_cm_per_day":magnitude}
            selected_wet_dry=wet_dry
            selected_dry_wet=dry_wet
            break
    if selected_sequential is not None:
        break
assert selected_sequential is not None,sequential_characterization

duration=selected_sequential["duration_day"]; magnitude=selected_sequential["magnitude_cm_per_day"]
wet={"top_flux_cm_per_day":-magnitude,"duration_day":duration,"head_m":None,"commit":True}
dry={"top_flux_cm_per_day": magnitude,"duration_day":duration,"head_m":None,"commit":True}
for trajectory in [selected_wet_dry,selected_dry_wet]:
    assert len(trajectory["records"])==2
    assert all(abs(r["diag"]["mass_residual_native"])<=1.0e-12 for r in trajectory["records"])
    assert trajectory["records"][-1]["state"][0]==2
    assert math.isclose(trajectory["records"][-1]["state"][1],2.0*duration,rel_tol=0.0,abs_tol=1.0e-14)
    # Research state preparation deliberately does not publish interface mass.
    assert trajectory["records"][-1]["state"][2:]==[0,0.0]
wet_dry_replay=run_fresh({"ops":[wet,dry]})
dry_wet_replay=run_fresh({"ops":[dry,wet]})
assert selected_wet_dry==wet_dry_replay
assert selected_dry_wet==dry_wet_replay

evidence={
    "schema":"swap5.gc_rootzone_memory.rzm06a.infrastructure_characterization.v1",
    "top_flux_sign_convention":"negative_into_profile_positive_out_of_profile",
    "enumeration":{"durations_day":durations,"top_flux_cm_per_day":top_fluxes},
    "cases":characterization,
    "transaction_case":chosen,
    "transaction_commit":crec,
    "repeatability":"exact_json_equality",
    "sequential_characterization":sequential_characterization,
    "first_sequential_admissible_pair":selected_sequential,
    "sequential_antecedents":{
        "wet_then_dry_endpoint":selected_wet_dry["records"][-1],
        "dry_then_wet_endpoint":selected_dry_wet["records"][-1],
        "replay":"exact_json_equality"
    },
    "top_bottom_independence":{
        "negative_top":nd["materialized_top_flux_cm_per_day"],
        "positive_top":pd["materialized_top_flux_cm_per_day"],
        "common_bottom_head_cm":nd["materialized_bottom_head_cm"],
        "common_interface_head_m":nd["requested_head_m"],
    },
}
print("RZM06A_INFRASTRUCTURE_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
print("GC_RZM06A_SEQUENTIAL_INTERVAL_INFRASTRUCTURE=PASS")
