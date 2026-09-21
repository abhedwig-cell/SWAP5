from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap


DURATIONS_DAY = (5.0e-5, 1.0e-4, 2.0e-4)
QBOTS_CM_PER_DAY = (5.0e-7, 1.0e-6, 2.0e-6)
MASS_TOL = 1.0e-12
U_FLOOR = 1.0e-12
EPS_FACTOR = 256.0

STAGE = {
    0: "READY",
    101: "INVALID_CONFIGURED_INPUT",
    102: "COMMITTED_STATE_INITIALIZATION_FAILED",
    103: "CHECKPOINT_CAPTURE_FAILED",
    104: "PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE",
    105: "PREDICTOR_CANDIDATE_UNAVAILABLE",
    106: "ACCEPTED_TRAJECTORY_DIRECTION_UNAVAILABLE",
    107: "TANGENT_ENDPOINT_OR_PREREQUISITE_INVALID",
    108: "ORIGIN_BOTTOM_FACE_MAPPING_INVALID",
    109: "SWAP_INTERFACE_FLUX_CONVERSION_FAILED",
    110: "GROUNDWATER_FLUX_PAIRING_FAILED",
    111: "PREDICTOR_ORIGIN_CAPTURE_FAILED",
    112: "PREDICTOR_RESPONSE_ASSEMBLY_FAILED",
    113: "CELL_AFFINE_RESPONSE_COMPOSITION_FAILED",
    114: "MODFLOW_LINEAR_TERM_COMPOSITION_FAILED",
    115: "SWAP_PARTICIPANT_ORIGIN_CAPTURE_FAILED",
    116: "INTERFACE_LEDGER_IDENTITY_BIND_FAILED",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def close_eps(a: float, b: float) -> bool:
    scale = max(1.0, abs(a), abs(b))
    return abs(a - b) <= EPS_FACTOR * np.finfo(float).eps * scale


def main() -> None:
    library = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(library.is_file(), "missing F-GC44 real-SWAP bridge library")
    swap = Fgc44RealSwap(library)

    records: list[dict[str, object]] = []

    for duration in DURATIONS_DAY:
        for qbot in QBOTS_CM_PER_DAY:
            status, hcof, rhs, href = swap.try_initialize_configured(duration, qbot)
            require(status in STAGE, f"unregistered configured-init status {status}")
            run_diag = swap.predictor_run_diagnostics()
            require(bool(run_diag["available"]), f"predictor diagnostics unavailable dt={duration} q={qbot}")

            rec: dict[str, object] = {
                "duration_day": duration,
                "qbot_cm_per_day": qbot,
                "status_code": status,
                "stage": STAGE[status],
                "ready": status == 0,
                "run": run_diag,
            }

            if status == 0:
                diag = swap.e1_diagnostics()
                require(bool(diag["mass_complete"]), f"incomplete mass diagnostics dt={duration} q={qbot}")

                u = float(diag["u"])
                q_u = float(diag["q_u_cm_per_day"])
                h_start = float(diag["h_start_m"])
                h_end = float(diag["h_end_m"])
                storage_change = float(diag["storage_change_native"])
                total_in = float(diag["total_in_native"])
                total_out = float(diag["total_out_native"])
                mass_residual = float(diag["mass_residual_native"])

                reconstructed_q_u = u * (h_end - h_start) * 100.0 / duration - qbot
                expected_hcof = u / duration
                expected_rhs = expected_hcof * href - 0.01 * q_u
                mass_identity = storage_change - (total_in - total_out)

                require(close_eps(reconstructed_q_u, q_u), f"q_u algebra dt={duration} q={qbot}")
                require(close_eps(hcof, expected_hcof), f"HCOF algebra dt={duration} q={qbot}")
                require(close_eps(rhs, expected_rhs), f"RHS algebra dt={duration} q={qbot}")
                require(abs(mass_identity - mass_residual) <= MASS_TOL, f"mass identity dt={duration} q={qbot}")
                require(abs(storage_change) <= MASS_TOL, f"storage-change gate dt={duration} q={qbot}")
                require(math.isfinite(u) and abs(u) > U_FLOOR, f"nonzero-u gate dt={duration} q={qbot}")

                rec["semantic"] = {
                    "u": u,
                    "q_u_cm_per_day": q_u,
                    "h_start_m": h_start,
                    "h_end_m": h_end,
                    "delta_h_m": h_end - h_start,
                    "storage_change_native": storage_change,
                    "total_in_native": total_in,
                    "total_out_native": total_out,
                    "mass_residual_native": mass_residual,
                    "hcof_m2_per_day": hcof,
                    "rhs_m3_per_day": rhs,
                    "reference_head_m": href,
                }

            records.append(rec)
            print("GC_DSW22D_CASE_JSON=" + json.dumps(rec, sort_keys=True, separators=(",", ":")))

    require(len(records) == 9, "diagnostic matrix incomplete")

    control = next(
        r for r in records
        if float(r["duration_day"]) == 1.0e-4 and float(r["qbot_cm_per_day"]) == 1.0e-6
    )
    require(bool(control["ready"]), "admitted F-GC44 reference point no longer READY")

    ready = [r for r in records if bool(r["ready"])]
    failed = [r for r in records if not bool(r["ready"])]
    require(len(failed) >= 1, "falsified first case unexpectedly disappeared")
    require(all(int(r["status_code"]) == 104 for r in failed), f"unexpected failure stage(s): {failed}")

    print(f"GC_DSW22D_READY_COUNT={len(ready)}")
    print(f"GC_DSW22D_FAILED_COUNT={len(failed)}")
    print("GC_DSW22D_REFERENCE_CONTROL=PASS")
    print("GC_DSW22D_SUCCESSFUL_CASE_ALGEBRA=PASS")
    print("GC_DSW22D_FAILURE_DIAGNOSTICS_COMPLETE=PASS")
    print("GC_DSW22D_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
