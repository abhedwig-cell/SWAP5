from __future__ import annotations

import json, math, os, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"publication"))
from pub_gc_e6_ctypes import E6ActiveDrainageSwap

lib=Path(os.environ["PUB_GC_E6_SWAP_LIB"]).resolve()
swap=E6ActiveDrainageSwap(lib)
hcof,rhs,href=swap.initialize()
pred=swap.predictor()
assert swap.drainage_coverage()
assert bool(pred["mass_complete"])
assert all(math.isfinite(float(v)) for k,v in pred.items() if k!="mass_complete")
origin=swap.state()
assert origin==(0,0.0,0,0.0), origin

fixture={"fixture":"FGC31_ACTIVE_DRAINAGE","duration_day":0.01,"predictor_qbot_cm_per_day":0.002,
         "initial_pressure_head_cm":[-2.2,-1.2,-0.2,0.8],
         "drainage_levels":[{"depth":[0.5,2.5],"exchange":[0.004,0.001]},
                            {"depth":[0.5,2.5],"exchange":[0.002,-0.001]}],
         "hcof":hcof,"rhs":rhs,"href":href,**pred}
print("PUB_GC_E6_PREDICTOR="+json.dumps(fixture,sort_keys=True))

status,q=swap.try_trial(href)
if status==0:
    assert math.isfinite(q)
    assert swap.state()==origin
    swap.discard()
    assert swap.state()==origin
    print(f"PUB_GC_E6_REFERENCE_Q_SWAP_M_PER_S={q:.17g}")
    print("PUB_GC_E6_PARTICIPANT_REFERENCE_TRIAL=PASS")
    print("PUB_GC_E6_REFERENCE_CORRECTOR_AVAILABLE=PASS")
else:
    assert status==6, f"unexpected participant failure status: {status}"
    assert swap.state()==origin
    diag=swap.corrector_diagnostics(href)
    assert swap.state()==origin
    print("PUB_GC_E6_REFERENCE_CORRECTOR_DIAGNOSTICS="+json.dumps({
        "participant_status":status,"reference_head_m":href,**diag
    },sort_keys=True))
    print("PUB_GC_E6_REFERENCE_CORRECTOR_BOUNDED_FAILURE=PASS")

print("PUB_GC_E6_ACTIVE_DRAINAGE_INITIALIZE=PASS")
print("PUB_GC_E6_ACTIVE_DRAINAGE_TANGENT_COVERAGE=PASS")
print("PUB_GC_E6_ZERO_AUTHORITY_AFTER_REFERENCE_PROBE=PASS")
