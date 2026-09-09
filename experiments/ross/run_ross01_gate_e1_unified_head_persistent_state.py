from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1 as c1

CONTRACT = "F-ROSS01_GATE_E1_UNIFIED_HEAD_PERSISTENT_STATE_AND_MIXED_WORKER_TRANSITION_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
HEADS = (-10000.0, -1000.0, -100.0, -10.0, -1.0, -0.1, -0.001, -1.0e-9, 0.0, 1.0e-9, 0.001, 0.1, 1.0, 10.0, 100.0)
TRANSITIONS = (
    (-1.0, 1.0),
    (-0.1, 0.1),
    (-0.001, 0.001),
    (-1.0e-9, 1.0e-9),
    (1.0e-9, -1.0e-9),
    (0.001, -0.001),
    (0.1, -0.1),
    (1.0, -1.0),
)
THETA_TOL = 2.0e-15


def theta_of_h(h: float) -> float:
    if h >= 0.0:
        return float(c1.core.THETA_S)
    s = float(c1.core.s_of_h(h))
    return float(c1.core.THETA_R + (c1.core.THETA_S - c1.core.THETA_R) * s)


def mode_of_h(h: float) -> str:
    return "SATURATED" if h >= 0.0 else "UNSATURATED"


def encode_worker(h: float) -> dict:
    mode = mode_of_h(h)
    if mode == "UNSATURATED":
        return {"mode": mode, "value": float(c1.core.s_of_h(h)), "coordinate": "effective_saturation"}
    return {"mode": mode, "value": float(h), "coordinate": "pressure_head_cm"}


def decode_worker(worker: dict) -> float:
    if worker["mode"] == "UNSATURATED":
        return float(c1.core.h_of_s(float(worker["value"])))
    return float(worker["value"])


def head_tol(h: float) -> float:
    return max(1.0e-8, abs(h) * 1.0e-11)


def run_material(row: dict) -> dict:
    c1.configure_core(row)
    witness_rows = []
    nonfinite = 0
    max_head_roundtrip_error = 0.0
    roundtrip_failures = 0
    checkpoint_failures = 0
    boundary_mode_failures = 0

    for h in HEADS:
        theta = theta_of_h(h)
        mode = mode_of_h(h)
        worker = encode_worker(h)
        restored_h = float(h)  # canonical checkpoint contains only persistent pressure head
        restored_theta = theta_of_h(restored_h)
        restored_mode = mode_of_h(restored_h)
        decoded_h = decode_worker(worker)
        head_error = abs(decoded_h - h)
        max_head_roundtrip_error = max(max_head_roundtrip_error, head_error)
        roundtrip_ok = math.isfinite(decoded_h) and head_error <= head_tol(h)
        checkpoint_ok = (
            restored_h == h
            and restored_theta == theta
            and restored_mode == mode
            and encode_worker(restored_h) == worker
        )
        boundary_ok = not (h == 0.0 and mode != "SATURATED")
        vals = (theta, float(worker["value"]), decoded_h, restored_theta)
        nonfinite += sum(not math.isfinite(v) for v in vals)
        roundtrip_failures += int(not roundtrip_ok)
        checkpoint_failures += int(not checkpoint_ok)
        boundary_mode_failures += int(not boundary_ok)
        witness_rows.append({
            "h_cm": h,
            "mode": mode,
            "theta": theta,
            "worker_coordinate": worker["coordinate"],
            "worker_value": worker["value"],
            "decoded_h_cm": decoded_h,
            "head_roundtrip_error_cm": head_error,
            "head_tolerance_cm": head_tol(h),
            "roundtrip_ok": roundtrip_ok,
            "checkpoint_restore_ok": checkpoint_ok,
            "boundary_mode_ok": boundary_ok,
        })

    transition_rows = []
    max_storage_representation_error = 0.0
    storage_representation_failures = 0
    rollback_failures = 0
    delta_map = {}
    for h0, h1 in TRANSITIONS:
        theta0 = theta_of_h(h0)
        theta1 = theta_of_h(h1)
        delta_persistent = theta1 - theta0
        w0 = encode_worker(h0)
        w1 = encode_worker(h1)
        dh0 = decode_worker(w0)
        dh1 = decode_worker(w1)
        delta_worker = theta_of_h(dh1) - theta_of_h(dh0)
        storage_error = abs(delta_worker - delta_persistent)
        max_storage_representation_error = max(max_storage_representation_error, storage_error)
        storage_ok = storage_error <= THETA_TOL

        committed_before = (h0, theta0, mode_of_h(h0))
        _trial = (h1, theta1, mode_of_h(h1), w1)
        committed_after_reject = (h0, theta_of_h(h0), mode_of_h(h0))
        rollback_ok = committed_after_reject == committed_before

        storage_representation_failures += int(not storage_ok)
        rollback_failures += int(not rollback_ok)
        delta_map[(h0, h1)] = delta_persistent
        transition_rows.append({
            "h_start_cm": h0,
            "h_end_cm": h1,
            "mode_start": mode_of_h(h0),
            "mode_end": mode_of_h(h1),
            "storage_delta_theta": delta_persistent,
            "worker_roundtrip_storage_delta_theta": delta_worker,
            "storage_representation_error_theta": storage_error,
            "storage_representation_ok": storage_ok,
            "rollback_identity_ok": rollback_ok,
        })

    max_antisymmetry_error = 0.0
    antisymmetry_failures = 0
    checked_pairs = set()
    for (h0, h1), delta in delta_map.items():
        if (h1, h0) not in delta_map or (h1, h0) in checked_pairs:
            continue
        err = abs(delta + delta_map[(h1, h0)])
        max_antisymmetry_error = max(max_antisymmetry_error, err)
        antisymmetry_failures += int(err > THETA_TOL)
        checked_pairs.add((h0, h1))

    passed = (
        roundtrip_failures == 0
        and checkpoint_failures == 0
        and boundary_mode_failures == 0
        and storage_representation_failures == 0
        and rollback_failures == 0
        and antisymmetry_failures == 0
        and nonfinite == 0
    )
    return {
        "material": row["sfu"],
        "pass": passed,
        "max_head_roundtrip_error_cm": max_head_roundtrip_error,
        "roundtrip_failure_count": roundtrip_failures,
        "checkpoint_failure_count": checkpoint_failures,
        "boundary_mode_failure_count": boundary_mode_failures,
        "max_storage_representation_error_theta": max_storage_representation_error,
        "storage_representation_failure_count": storage_representation_failures,
        "rollback_failure_count": rollback_failures,
        "max_forward_reverse_storage_antisymmetry_error_theta": max_antisymmetry_error,
        "antisymmetry_failure_count": antisymmetry_failures,
        "nonfinite_count": nonfinite,
        "witnesses": witness_rows,
        "transitions": transition_rows,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e1_unified_head_persistent_state.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    rows = [run_material(row) for row in catalog["rows"]]
    pass_count = sum(row["pass"] for row in rows)
    roundtrip_failures = sum(row["roundtrip_failure_count"] for row in rows)
    checkpoint_failures = sum(row["checkpoint_failure_count"] for row in rows)
    storage_failures = sum(row["storage_representation_failure_count"] for row in rows)
    rollback_failures = sum(row["rollback_failure_count"] for row in rows)
    boundary_failures = sum(row["boundary_mode_failure_count"] for row in rows)
    antisymmetry_failures = sum(row["antisymmetry_failure_count"] for row in rows)
    nonfinite = sum(row["nonfinite_count"] for row in rows)
    max_head_error = max(row["max_head_roundtrip_error_cm"] for row in rows)
    max_storage_error = max(row["max_storage_representation_error_theta"] for row in rows)
    max_antisymmetry = max(row["max_forward_reverse_storage_antisymmetry_error_theta"] for row in rows)
    passed = pass_count == len(rows)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E1_UNIFIED_HEAD_PERSISTENT_STATE_AND_MIXED_WORKER_TRANSITION",
        "contract": CONTRACT,
        "production_implementation": False,
        "material_count": len(rows),
        "material_pass_count": pass_count,
        "head_witnesses_cm": list(HEADS),
        "transition_pairs_cm": [list(x) for x in TRANSITIONS],
        "max_head_roundtrip_error_cm": max_head_error,
        "roundtrip_failure_count": roundtrip_failures,
        "checkpoint_failure_count": checkpoint_failures,
        "max_storage_representation_error_theta": max_storage_error,
        "storage_representation_failure_count": storage_failures,
        "rollback_failure_count": rollback_failures,
        "boundary_mode_failure_count": boundary_failures,
        "max_forward_reverse_storage_antisymmetry_error_theta": max_antisymmetry,
        "antisymmetry_failure_count": antisymmetry_failures,
        "nonfinite_count": nonfinite,
        "selected_persistent_state": (
            "UNIFIED_HEAD_PERSISTENT_STATE_WITH_ROSS_MIXED_WORKER_VARIABLES" if passed else "NOT_SELECTED"
        ),
        "rows": rows,
        "pass": passed,
        "decision": (
            "QUALIFIED_UNIFIED_HEAD_PERSISTENT_STATE_WITH_MIXED_ROSS_WORKER_VARIABLES_READY_FOR_E2_NEAR_SATURATION_FACE_GATE"
            if passed else
            "SATURATION_STATE_LAYOUT_NOT_QUALIFIED_RECONCILE_BEFORE_E2"
        ),
    }
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "rows"}, sort_keys=True), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
