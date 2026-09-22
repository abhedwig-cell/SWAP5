from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    AREA_M2,
    DAY_TO_S,
    initialize_case,
    reference_root,
    solve_term,
)
from test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d import run_policy
from test_gc_fixed_interface_fgc44_nonlinear_b4_g10 import fixed_scan, select_starts

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G10B_PREREGISTRATION.json"

DURATION_DAY = 1.0e-2
QBOT_CM_PER_DAY = 1.0e-6
HREF_EXPECTED = -0.7149999311459918
U_EXPECTED = 0.00119027208545508
DIRECT_ROOT_EXPECTED_M = -0.7149997332230622
LOCAL_PROBES = (
    -2.0e-9, -1.0e-9, -5.0e-10, -2.0e-10, -1.0e-10, -5.0e-11, 0.0,
    5.0e-11, 1.0e-10, 2.0e-10, 5.0e-10, 1.0e-9, 2.0e-9,
)
REGIME = {
    "id": "GW_MIXED",
    "k_m_per_day": 1.0,
    "ss_per_m": 0.02,
    "initial_head_bias_m": 0.0,
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> dict[str, object]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G10B", "wrong G10B preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION_AMENDED", "G10B preregistration not frozen/amended")
    require(tuple(float(x) for x in p["local_response_contract"]["q_probes_m_per_s"]) == LOCAL_PROBES,
            "G10B local probe ladder drifted")
    require(p["parent_falsification"] == "integration/research/GC_FIXED_INTERFACE_G10_FIRST_EXECUTION_RESULT.json",
            "G10B parent falsification provenance drifted")
    return p


def main() -> None:
    p = load_prereg()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP bridge library")

    swap = Fgc44RealSwap(swaplib)
    _, _, href, origin, diag = initialize_case(swap, DURATION_DAY, QBOT_CM_PER_DAY)
    require(origin == (0, 0.0, 0, 0.0), "G10B dirty SWAP origin")
    tol = 1.0e-14
    require(math.isclose(href, HREF_EXPECTED, rel_tol=0.0, abs_tol=tol), f"G10B href mismatch {href}")
    require(math.isclose(float(diag["u"]), U_EXPECTED, rel_tol=0.0, abs_tol=tol), f"G10B u mismatch {diag['u']}")
    require(math.isclose(float(diag["q_bot_predictor_cm_per_day"]), QBOT_CM_PER_DAY, rel_tol=0.0, abs_tol=tol),
            f"G10B qbot mismatch {diag['q_bot_predictor_cm_per_day']}")

    points: list[tuple[float, float]] = []
    probe_rows: list[dict[str, float | int]] = []
    for q in LOCAL_PROBES:
        h, qgw, iters = solve_term(
            libmf6, swaplib, DURATION_DAY, href,
            float(REGIME["k_m_per_day"]), float(REGIME["ss_per_m"]), 0.15,
            float(REGIME["initial_head_bias_m"]),
            0.0, -q * AREA_M2 * DAY_TO_S,
        )
        require(abs(qgw - q) <= 64.0 * np.finfo(float).eps * max(1.0, abs(q)),
                f"G10B constant-flux probe drift at {q}")
        points.append((float(h), q))
        row = {"q_m_per_s": q, "head_m": float(h), "mf_iterations": int(iters)}
        probe_rows.append(row)
        print("FGC44_G10B_GW_POINT=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    heads = np.asarray([x[0] for x in points], dtype=float)
    fluxes = np.asarray([x[1] for x in points], dtype=float)
    a, intercept = np.polyfit(heads, fluxes, 1)
    fit_error = float(np.max(np.abs(a * heads + intercept - fluxes)))
    max_allowed = float(p["local_response_contract"]["max_allowed_fit_error_m_per_s"])
    require(math.isfinite(a) and a > 0.0, "G10B local groundwater slope nonpositive/nonfinite")
    require(fit_error <= max_allowed, f"G10B local fit error {fit_error} > {max_allowed}")
    fit = {
        "a_per_s": float(a),
        "intercept": float(intercept),
        "max_fit_error_m_per_s": fit_error,
        "point_count": len(points),
    }
    print("FGC44_G10B_GW_FIT=" + json.dumps(fit, sort_keys=True, separators=(",", ":")))

    rows = fixed_scan(swap, origin, href)
    root = reference_root(swap, origin, rows, float(a), float(intercept))
    require(root is not None, "G10B local-affine coupled root unavailable")
    root_error = float(root) - DIRECT_ROOT_EXPECTED_M
    max_root_error = float(p["reference_root"]["max_root_head_difference_m"])
    require(abs(root_error) <= max_root_error,
            f"G10B local root does not reproduce G10A direct root: {root_error}")
    print("FGC44_G10B_ROOT=" + json.dumps({
        "local_affine_root_m": float(root),
        "g10a_direct_root_m": DIRECT_ROOT_EXPECTED_M,
        "head_difference_m": root_error,
    }, sort_keys=True, separators=(",", ":")))

    starts = select_starts(rows)
    expected_starts = {float(x) for x in p["frozen_carrier"]["starts_m"]}
    require({d for _, d in starts} == expected_starts, f"G10B start selection drifted: {starts}")

    policy_rows: list[dict[str, object]] = []
    for side, start_dh in starts:
        for policy in ("P1_E3", "P4_E3"):
            result = run_policy(
                policy,
                libmf6,
                swaplib,
                swap,
                DURATION_DAY,
                QBOT_CM_PER_DAY,
                REGIME,
                0.15,
                float(a),
                float(intercept),
                float(root),
                start_dh,
            )
            row = {
                "regime_id": "GW_MIXED",
                "start_side": side,
                "start_dh_m": start_dh,
                "policy": policy,
                "local_a_per_s": float(a),
                "local_intercept": float(intercept),
                "local_fit_error_m_per_s": fit_error,
                "reference_root_m": float(root),
                **result,
            }
            policy_rows.append(row)
            print("FGC44_G10B_POLICY_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
            if policy == "P4_E3":
                require(result["classification"] == "CONVERGED",
                        f"G10B P4 failed from {side}: {result}")

    require(swap.state() == origin, "G10B diagnostics mutated accepted SWAP/ledger authority")

    p1 = [x for x in policy_rows if x["policy"] == "P1_E3"]
    p4 = [x for x in policy_rows if x["policy"] == "P4_E3"]
    require(len(p4) == 2, "G10B P4 matrix incomplete")
    summary = {
        "local_response_fit": "PASS",
        "local_fit_error_m_per_s": fit_error,
        "local_fit_error_over_residual_tolerance": fit_error / 1.0e-15,
        "root_head_difference_from_g10a_m": root_error,
        "p1_case_count": len(p1),
        "p1_converged_count": sum(x["classification"] == "CONVERGED" for x in p1),
        "p4_case_count": len(p4),
        "p4_converged_count": sum(x["classification"] == "CONVERGED" for x in p4),
        "p4_total_contractions": sum(int(x.get("contractions", 0)) for x in p4),
        "p4_raw_inadmissible_total": sum(int(x.get("raw_inadmissible", 0)) for x in p4),
        "safeguard_activation": (
            "EXERCISED"
            if any(int(x.get("contractions", 0)) > 0 for x in p4)
            else "NOT_EXERCISED"
        ),
    }
    print("FGC44_G10B_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G10B_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G10B_LOCAL_GROUNDWATER_RESPONSE=PASS")
    print("GC_FIXED_INTERFACE_G10B_EXECUTION=PASS")


if __name__ == "__main__":
    main()
