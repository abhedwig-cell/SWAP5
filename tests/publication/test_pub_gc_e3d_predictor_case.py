from __future__ import annotations
import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

STAGE={
  0:"READY",
  101:"INVALID_CONFIGURED_INPUT",
  102:"COMMITTED_STATE_INITIALIZATION_FAILED",
  103:"CHECKPOINT_CAPTURE_FAILED",
  104:"PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE",
  105:"PREDICTOR_CANDIDATE_UNAVAILABLE",
  106:"ACCEPTED_TRAJECTORY_DIRECTION_UNAVAILABLE",
  107:"TANGENT_ENDPOINT_OR_PREREQUISITE_INVALID",
  108:"ORIGIN_BOTTOM_FACE_MAPPING_INVALID",
  109:"SWAP_INTERFACE_FLUX_CONVERSION_FAILED",
  110:"GROUNDWATER_FLUX_PAIRING_FAILED",
  111:"PREDICTOR_ORIGIN_CAPTURE_FAILED",
  112:"PREDICTOR_RESPONSE_ASSEMBLY_FAILED",
  113:"CELL_AFFINE_RESPONSE_COMPOSITION_FAILED",
  114:"MODFLOW_LINEAR_TERM_COMPOSITION_FAILED",
  115:"SWAP_PARTICIPANT_ORIGIN_CAPTURE_FAILED",
  116:"INTERFACE_LEDGER_IDENTITY_BIND_FAILED",
}

def main()->None:
    duration=float(os.environ["E3D_WINDOW_DAY"])
    q=float(os.environ["E3D_QBOT_CM_PER_DAY"])
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    swap=Fgc44RealSwap(lib)
    status,hcof,rhs,href=swap.try_initialize_configured(duration,q)
    rec={
      "window_day":duration,
      "predictor_qbot_cm_per_day":q,
      "status_code":status,
      "stage":STAGE.get(status,"UNREGISTERED_STATUS"),
      "ready":status==0,
    }
    if status==0:
        d=swap.e1_diagnostics()
        vals=[hcof,rhs,href,*[float(v) for k,v in d.items() if k!="mass_complete"]]
        if not all(math.isfinite(v) for v in vals):
            raise AssertionError("nonfinite successful predictor diagnostic")
        rec.update({
          "hcof_m2_per_day":hcof,
          "rhs_m3_per_day":rhs,
          "reference_head_m":href,
          "mass_complete":bool(d["mass_complete"]),
          "q_u_cm_per_day":float(d["q_u_cm_per_day"]),
          "u":float(d["u"]),
          "h_start_m":float(d["h_start_m"]),
          "h_end_m":float(d["h_end_m"]),
          "storage_start_native":float(d["storage_start_native"]),
          "storage_end_native":float(d["storage_end_native"]),
          "storage_change_native":float(d["storage_change_native"]),
          "mass_residual_native":float(d["mass_residual_native"]),
        })
        if swap.state()!=(0,0.0,0,0.0):
            raise AssertionError("predictor diagnosis changed authoritative state")
    elif status not in STAGE:
        raise AssertionError(f"unregistered configured-init status {status}")
    print("E3D_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
