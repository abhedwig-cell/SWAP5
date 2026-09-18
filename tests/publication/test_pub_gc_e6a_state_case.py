from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

WINDOW_DAY=float(os.environ.get("E6A_WINDOW_DAY","1e-3"))
H0_CM=float(os.environ["E6A_H0_CM"])
QBOT=float(os.environ["E6A_QBOT_CM_PER_DAY"])
SWAPLIB=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

OFFSETS_M=(1e-6,1e-5,1e-4,1e-3)

def finite(*xs:float)->bool:
    return all(math.isfinite(float(x)) for x in xs)

def main()->None:
    swap=Fgc44RealSwap(SWAPLIB)
    status,hcof,rhs,href=swap.try_initialize_state_configured(WINDOW_DAY,QBOT,H0_CM)
    rec={
        "schema":"pub-gc-e6a-state-case-v1",
        "window_day":WINDOW_DAY,
        "initial_h0_cm":H0_CM,
        "predictor_qbot_cm_per_day":QBOT,
        "predictor_status":int(status),
        "predictor_ready":status==0,
        "probes":[],
    }

    if status!=0:
        try:
            rec["predictor_run_diagnostics"]=swap.predictor_run_diagnostics()
        except Exception as exc:
            rec["predictor_diagnostics_error"]=f"{type(exc).__name__}:{exc}"
        print("E6A_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))
        return

    if not finite(hcof,rhs,href) or hcof==0.0:
        raise AssertionError("nonfinite/zero state-configured predictor")
    origin=swap.state()
    if origin!=(0,0.0,0,0.0):
        raise AssertionError(f"state screen not at zero-authority origin: {origin}")

    e1=swap.e1_diagnostics()
    rec.update({
        "predictor_hcof_m2_per_day":hcof,
        "predictor_rhs_m3_per_day":rhs,
        "reference_head_m":href,
        "predictor_mass_complete":bool(e1["mass_complete"]),
        "predictor_mass_residual_native":float(e1["mass_residual_native"]),
        "predictor_q_u_cm_per_day":float(e1["q_u_cm_per_day"]),
        "predictor_u":float(e1["u"]),
        "predictor_storage_change_native":float(e1["storage_change_native"]),
    })
    if not bool(e1["mass_complete"]):
        raise AssertionError("predictor mass accounting incomplete")
    if not finite(
        e1["mass_residual_native"],e1["q_u_cm_per_day"],
        e1["u"],e1["storage_change_native"]
    ):
        raise AssertionError("nonfinite predictor diagnostic")

    for delta in OFFSETS_M:
        for sign in (-1.0,1.0):
            offset=sign*delta
            head=href+offset
            probe={
                "delta_h_m":offset,
                "prescribed_head_m":head,
            }
            try:
                qswap=swap.trial(head)
            except RuntimeError as exc:
                probe.update({
                    "ready":False,
                    "status":"BOUNDED_TRIAL_FAILURE",
                    "message":str(exc),
                })
                if swap.state()!=origin:
                    raise AssertionError("failed corrector changed authoritative state")
            else:
                qdiag,bottom_cm=swap.last_trial_diagnostics()
                if not finite(qswap,qdiag,bottom_cm):
                    raise AssertionError("nonfinite successful corrector diagnostic")
                if abs(qswap-qdiag)>64*sys.float_info.epsilon*max(1.0,abs(qswap),abs(qdiag)):
                    raise AssertionError("corrector q diagnostic mismatch")
                if swap.state()!=origin:
                    raise AssertionError("successful corrector changed authoritative state before discard")
                probe.update({
                    "ready":True,
                    "status":"READY",
                    "q_swap_m_per_s":qswap,
                    "bottom_outward_exchange_cm":bottom_cm,
                    "bottom_outward_exchange_m":bottom_cm*0.01,
                })
                swap.discard()
                if swap.state()!=origin:
                    raise AssertionError("discarded corrector changed authoritative state")
            rec["probes"].append(probe)

    rec["authority_state_after"]=list(swap.state())
    print("E6A_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
