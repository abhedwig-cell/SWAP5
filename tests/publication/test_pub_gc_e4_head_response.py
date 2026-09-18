from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

DELTAS=(1e-10,3e-10,1e-9,3e-9,1e-8,3e-8,1e-7,3e-7,1e-6,3e-6,1e-5)

def require(value:bool,message:str)->None:
    if not value:
        raise AssertionError(message)

def normalize_trial(head:float,raw:dict[str,float|bool|int])->dict[str,float|bool|int]:
    out=dict(raw)
    out["head_m"]=head
    if bool(out["valid"]):
        require(bool(out["mass_complete"]),"valid E4 head trial has incomplete mass")
        vals=[
            float(out["q_swap_m_per_s"]),
            float(out["bottom_outward_exchange_cm"]),
            float(out["terminal_bottom_outward_flux_native"]),
            float(out["storage_start_native"]),
            float(out["storage_end_native"]),
            float(out["storage_change_native"]),
            float(out["total_in_native"]),
            float(out["total_out_native"]),
            float(out["mass_residual_native"]),
        ]
        require(all(math.isfinite(v) for v in vals),"nonfinite valid E4 head trial")
        storage_identity=(
            float(out["storage_end_native"])
            -float(out["storage_start_native"])
            -float(out["storage_change_native"])
        )
        mass_identity=(
            float(out["storage_change_native"])
            -(float(out["total_in_native"])-float(out["total_out_native"]))
            -float(out["mass_residual_native"])
        )
        scale=max(1.0,*[abs(v) for v in vals])
        tol=256*np.finfo(float).eps*scale
        require(abs(storage_identity)<=tol,"E4 storage identity failed")
        require(abs(mass_identity)<=tol,"E4 mass identity failed")
        out["V_u_m"]=float(out["bottom_outward_exchange_cm"])*0.01
        out["storage_change_m"]=float(out["storage_change_native"])*0.01
        out["other_net_m"]=(
            float(out["total_in_native"])
            -float(out["total_out_native"])
            +float(out["bottom_outward_exchange_cm"])
        )*0.01
        response_balance=(
            float(out["storage_change_m"])
            -float(out["other_net_m"])
            +float(out["V_u_m"])
            -float(out["mass_residual_native"])*0.01
        )
        require(abs(response_balance)<=tol*0.01,"E4 response balance identity failed")
    return out

def main()->None:
    window=float(os.environ["E4_WINDOW_DAY"])
    q0=float(os.environ["E4_QBOT_CM_PER_DAY"])
    baseline_id=os.environ["E4_BASELINE_ID"]
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    swap=Fgc44RealSwap(lib)
    status,hcof,rhs,href=swap.try_initialize_configured(window,q0)
    rec={
        "schema":"pub-gc-e4-head-scan-v1",
        "baseline_id":baseline_id,
        "window_day":window,
        "qbot_cm_per_day":q0,
        "initialize_status":status,
        "ready":status==0,
    }
    if status!=0:
        print("E4_HEAD_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))
        return

    predictor=swap.e1_diagnostics()
    origin=swap.state()
    require(origin==(0,0.0,0,0.0),"E4 baseline not at immutable accepted origin")
    rec.update({
        "predictor_hcof_m2_per_day":hcof,
        "predictor_rhs_m3_per_day":rhs,
        "reference_head_m":href,
        "u_A":float(predictor["u"]),
        "predictor":predictor,
    })

    # Exact production-participant parity at H0. A bounded production
    # corrector failure is retained as baseline-local evidence rather than
    # crashing the complete five-baseline E4 study.
    try:
        q_prod=swap.trial(href)
    except RuntimeError as exc:
        rec.update({
            "head_response_status":"PRODUCTION_REFERENCE_FAILED",
            "message":str(exc),
            "authority_state_after":swap.state(),
        })
        require(tuple(rec["authority_state_after"])==origin,
                "failed E4 production reference changed authoritative state")
        print("E4_HEAD_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))
        return

    q_prod_diag,bottom_prod=swap.last_trial_diagnostics()
    require(abs(q_prod-q_prod_diag)<=128*np.finfo(float).eps*max(1.0,abs(q_prod)),
            "production trial diagnostic mismatch")
    require(swap.state()==origin,"production parity trial changed authority")
    swap.discard()
    require(swap.state()==origin,"production parity discard changed authority")

    obs0=normalize_trial(href,swap.e4_head_trial(href))
    if not bool(obs0["valid"]):
        rec.update({
            "head_response_status":"QUALIFICATION_OBSERVER_REFERENCE_FAILED",
            "reference_trial":obs0,
            "authority_state_after":swap.state(),
        })
        require(tuple(rec["authority_state_after"])==origin,
                "failed E4 observer reference changed authoritative state")
        print("E4_HEAD_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))
        return

    require(
        abs(float(obs0["q_swap_m_per_s"])-q_prod)
        <=128*np.finfo(float).eps*max(1.0,abs(q_prod)),
        "E4 observer q_swap differs from production participant",
    )
    require(
        abs(float(obs0["bottom_outward_exchange_cm"])-bottom_prod)
        <=128*np.finfo(float).eps*max(1.0,abs(bottom_prod)),
        "E4 observer bottom exchange differs from production participant",
    )
    require(swap.state()==origin,"E4 observer H0 changed authority")

    repeats=[]
    for _ in range(3):
        item=normalize_trial(href,swap.e4_head_trial(href))
        require(bool(item["valid"]),"E4 repeat failed at H0")
        require(swap.state()==origin,"E4 repeat changed authority")
        repeats.append(item)

    perturbations=[]
    for delta in DELTAS:
        minus=normalize_trial(href-delta,swap.e4_head_trial(href-delta))
        require(swap.state()==origin,"E4 minus perturbation changed authority")
        plus=normalize_trial(href+delta,swap.e4_head_trial(href+delta))
        require(swap.state()==origin,"E4 plus perturbation changed authority")
        perturbations.append({
            "delta_h_m":delta,
            "minus":minus,
            "plus":plus,
            "centered_available":bool(minus["valid"]) and bool(plus["valid"]),
        })

    rec.update({
        "head_response_status":"READY",
        "predictor_hcof_m2_per_day":hcof,
        "predictor_rhs_m3_per_day":rhs,
        "reference_head_m":href,
        "u_A":float(predictor["u"]),
        "predictor":predictor,
        "production_parity":{
            "q_swap_m_per_s":q_prod,
            "bottom_outward_exchange_cm":bottom_prod,
            "observer_q_swap_m_per_s":float(obs0["q_swap_m_per_s"]),
            "observer_bottom_outward_exchange_cm":float(obs0["bottom_outward_exchange_cm"]),
            "status":"PASS",
        },
        "reference_trial":obs0,
        "repeats":repeats,
        "perturbations":perturbations,
        "authority_state_after":swap.state(),
    })
    require(tuple(rec["authority_state_after"])==origin,"E4 head scan changed authoritative state")
    print("E4_HEAD_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
