from __future__ import annotations
import json,math,os,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

STATUS_NAMES={
  0:"CANONICAL_STATUS_COMPLETED",
  1:"CANONICAL_STATUS_INVALID_REQUEST",
  2:"CANONICAL_STATUS_TRANSACTION_FAILED",
  3:"CANONICAL_STATUS_NO_PROGRESS",
  4:"CANONICAL_STATUS_SUBSTEP_LIMIT",
  100:"KERNEL_STATUS_NOT_BOUND",
  101:"KERNEL_STATUS_NOT_ADMITTED",
  102:"KERNEL_STATUS_UNGUARDED_STATE",
  103:"KERNEL_STATUS_TIME_MISMATCH",
  104:"KERNEL_STATUS_CHECKPOINT_MISMATCH",
}

def main()->None:
    window=float(os.environ["E3D2_WINDOW_DAY"])
    q=float(os.environ["E3D2_QBOT_CM_PER_DAY"])
    swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]).resolve())
    init_status,hcof,rhs,href=swap.try_initialize_configured(window,q)
    d=swap.predictor_run_diagnostics()
    if not d["available"]:
        raise AssertionError("predictor run diagnostics unavailable")
    rec={
      "window_day":window,
      "predictor_qbot_cm_per_day":q,
      "configured_init_status":init_status,
      "predictor_ready":init_status==0,
      **d,
      "result_status_name":STATUS_NAMES.get(int(d["result_status"]),"OTHER_STATUS"),
    }
    vals=[d["max_temporal_indicator"],d["min_accepted_substep_duration"],d["max_accepted_substep_duration"]]
    if not all(math.isfinite(float(v)) for v in vals):
        # huge finite sentinel is acceptable; NaN/Inf is not.
        raise AssertionError("nonfinite predictor-run diagnostic")
    if init_status==0 and (not d["completed"] or int(d["result_status"])!=0):
        raise AssertionError("ready predictor has non-completed kernel result")
    if init_status==104 and d["completed"]:
        raise AssertionError("stage-104 initializer marked completed predictor")
    print("E3D2_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
