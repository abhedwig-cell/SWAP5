from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "tests" / "research" / "support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import AREA_M2, DAY_TO_S
from test_gc_fixed_interface_map09_active_drainage_g12 import (
    HREF_EXPECTED,
    QREF_EXPECTED,
    initialize_checked,
    estimate_e3_map,
    solve_term_map09,
    trial_discard,
)
from test_gc_fixed_interface_map09_groundwater_calibration_g12a import local_fit

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G12B_PREREGISTRATION.json"
G12A_RESULT = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G12A_RESULT.json"

STARTS = (-1.0e-6, 1.0e-6)
FLUX_TOL = 1.0e-15
MERIT_ABS_TOL = 1.0e-18
HEAD_TOL = 5.0e-10
MAX_OUTER = 12
MAX_BACKTRACK = 12
ROOT_BISECTIONS = 50
SLOPE_REL_TOL = 1.0e-8
QHREF_ABS_TOL = 2.0e-16


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def load_authority() -> tuple[dict[str, object], list[dict[str, object]]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G12B", "wrong G12B preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G12B preregistration not frozen")
    require(tuple(float(x) for x in p["frozen_carrier"]["starts_dh_m"]) == STARTS,
            "G12B starts drifted")
    require(int(p["convergence"]["max_outer"]) == MAX_OUTER, "G12B outer budget drifted")
    require(int(p["convergence"]["max_backtracks"]) == MAX_BACKTRACK, "G12B backtrack budget drifted")
    g12a = json.loads(G12A_RESULT.read_text())
    require(g12a["decision"] == "QUALIFIED_DIAGNOSTIC_G12_MISS_IS_ONE_SHOT_BIAS_ANCHORING_NOT_LOCAL_AFFINE_FIT_ERROR",
            "G12B parent G12A authority not qualified")
    rows = [dict(x) for x in g12a["regime_results"]]
    require([x["regime_id"] for x in rows] == ["GW_R05_STORAGE","GW_R2_STORAGE","GW_MIXED"],
            "G12B G12A regime order/identity drifted")
    return p, rows


def remeasure_groundwater(
    libmf6: Path,
    swaplib: Path,
    href: float,
    qref: float,
    authority: dict[str, object],
) -> dict[str, object]:
    regime = {
        "id": authority["regime_id"],
        "k_m_per_day": authority["k_m_per_day"],
        "ss_per_m": authority["ss_per_m"],
    }
    sy = float(authority["sy"])
    bias = float(authority["one_shot_calibration"]["frozen_bias_m"])
    measured = local_fit(libmf6, swaplib, href, qref, regime, sy, bias)

    a_ref = float(authority["local_fit"]["a_per_s"])
    q_ref_href = float(authority["local_fit"]["q_at_href_m_per_s"])
    a = float(measured["a_per_s"])
    q_at_href = float(measured["q_at_href_m_per_s"])
    a_rel = abs(a - a_ref) / max(abs(a), abs(a_ref))
    q_abs = abs(q_at_href - q_ref_href)
    require(a_rel <= SLOPE_REL_TOL,
            f"G12B slope authority drift {authority['regime_id']}: {a_rel}")
    require(q_abs <= QHREF_ABS_TOL,
            f"G12B q_at_href authority drift {authority['regime_id']}: {q_abs}")
    return {
        "regime_id": authority["regime_id"],
        "k_m_per_day": float(authority["k_m_per_day"]),
        "ss_per_m": float(authority["ss_per_m"]),
        "sy": sy,
        "head_bias_m": bias,
        "a_per_s": a,
        "q_at_href_m_per_s": q_at_href,
        "fit_error_m_per_s": float(measured["max_fit_error_m_per_s"]),
        "slope_relative_difference_from_g12a": a_rel,
        "q_at_href_abs_difference_from_g12a_m_per_s": q_abs,
        "points": measured["points"],
    }


def residual_at(
    swap: Map09ActiveDrainageSwap,
    origin: tuple[int, float, int, float],
    head: float,
    href: float,
    a: float,
    q_at_href: float,
) -> tuple[int, float | None, float | None]:
    status, q = trial_discard(swap, origin, head)
    if status != 0:
        return status, None, None
    qgw = a * (head - href) + q_at_href
    return 0, q, q - qgw


def reference_root(
    swap: Map09ActiveDrainageSwap,
    origin: tuple[int, float, int, float],
    href: float,
    a: float,
    q_at_href: float,
) -> dict[str, object]:
    lo = href - 1.0e-6
    hi = href + 1.0e-6
    slo, qlo, rlo = residual_at(swap, origin, lo, href, a, q_at_href)
    shi, qhi, rhi = residual_at(swap, origin, hi, href, a, q_at_href)
    require(slo == 0 and shi == 0 and rlo is not None and rhi is not None,
            "G12B reference-root bracket head inadmissible")
    require(rlo == 0.0 or rhi == 0.0 or rlo * rhi < 0.0,
            f"G12B reference-root bracket has no sign change: {rlo}, {rhi}")

    history = [{
        "iteration": 0, "lo_m": lo, "hi_m": hi,
        "rlo_m_per_s": rlo, "rhi_m_per_s": rhi,
        "qswap_lo_m_per_s": qlo, "qswap_hi_m_per_s": qhi,
    }]
    for i in range(1, ROOT_BISECTIONS + 1):
        mid = 0.5 * (lo + hi)
        sm, qm, rm = residual_at(swap, origin, mid, href, a, q_at_href)
        require(sm == 0 and rm is not None, f"G12B bisection midpoint inadmissible at {i}")
        history.append({"iteration": i, "head_m": mid, "residual_m_per_s": rm, "q_swap_m_per_s": qm})
        if rm == 0.0:
            lo = hi = mid
            rlo = rhi = 0.0
            continue
        if rlo == 0.0:
            hi = lo
            rhi = rlo
            continue
        if rlo * rm <= 0.0:
            hi, rhi = mid, rm
        else:
            lo, rlo = mid, rm

    root = 0.5 * (lo + hi)
    sr, qr, rr = residual_at(swap, origin, root, href, a, q_at_href)
    require(sr == 0 and rr is not None, "G12B final reference root inadmissible")
    return {
        "head_m": root,
        "dh_m": root - href,
        "residual_m_per_s": rr,
        "q_swap_m_per_s": qr,
        "final_bracket_width_m": abs(hi - lo),
        "history": history,
    }


def run_policy(
    policy: str,
    libmf6: Path,
    swaplib: Path,
    swap: Map09ActiveDrainageSwap,
    origin: tuple[int, float, int, float],
    href: float,
    start_dh: float,
    gw: dict[str, object],
    root_head: float,
) -> dict[str, object]:
    head = href + start_dh
    contractions = 0
    raw_inadmissible = 0
    merit_increases = 0
    modes: list[str] = []
    trace: list[dict[str, object]] = []
    a = float(gw["a_per_s"])
    q_at_href = float(gw["q_at_href_m_per_s"])

    for outer in range(1, MAX_OUTER + 1):
        status, q, res = residual_at(swap, origin, head, href, a, q_at_href)
        if status != 0 or q is None or res is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer,"status":status}

        if abs(res) <= FLUX_TOL and abs(head - root_head) <= HEAD_TOL:
            return {
                "classification":"CONVERGED","outer":outer-1,
                "final_head_m":head,"final_dh_m":head-href,
                "final_residual_m_per_s":res,"head_error_m":head-root_head,
                "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                "merit_increases":merit_increases,"modes":modes,"trace":trace,
            }

        est = estimate_e3_map(swap, origin, head)
        if est["classification"] != "AVAILABLE":
            return {"classification":"TANGENT_UNAVAILABLE","outer":outer,"estimator":est}
        p = float(est["slope_per_s"])
        modes.append(str(est["mode"]))

        slope_day = p * AREA_M2 * DAY_TO_S
        rhs = slope_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, _, mf_iters = solve_term_map09(
            libmf6, swaplib, href,
            float(gw["k_m_per_day"]), float(gw["ss_per_m"]), float(gw["sy"]),
            float(gw["head_bias_m"]), slope_day, rhs,
        )
        raw_status, _, raw_res = residual_at(swap, origin, raw_head, href, a, q_at_href)
        if raw_status != 0:
            raw_inadmissible += 1

        if policy == "P1_E3_MAP":
            if raw_status != 0 or raw_res is None:
                return {
                    "classification":"RAW_PROPOSAL_INADMISSIBLE","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "modes":modes,"trace":trace,
                }
            candidate = raw_head
            candidate_res = raw_res
            if abs(candidate_res) > abs(res) + MERIT_ABS_TOL:
                merit_increases += 1

        elif policy == "P4_E3_MAP":
            candidate = raw_head
            candidate_status = raw_status
            candidate_res = raw_res
            accepted = (
                candidate_status == 0 and candidate_res is not None
                and abs(candidate_res) <= abs(res) + MERIT_ABS_TOL
            )
            local = 0
            while not accepted and local < MAX_BACKTRACK:
                candidate = head + 0.5 * (candidate - head)
                local += 1
                candidate_status, _, candidate_res = residual_at(
                    swap, origin, candidate, href, a, q_at_href
                )
                accepted = (
                    candidate_status == 0 and candidate_res is not None
                    and abs(candidate_res) <= abs(res) + MERIT_ABS_TOL
                )
            contractions += local
            if not accepted or candidate_res is None:
                return {
                    "classification":"SAFEGUARD_EXHAUSTED","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "modes":modes,"trace":trace,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer": outer,
            "current_head_m": head,
            "current_residual_m_per_s": res,
            "raw_head_m": raw_head,
            "raw_status": raw_status,
            "raw_residual_m_per_s": raw_res,
            "accepted_head_m": candidate,
            "accepted_residual_m_per_s": candidate_res,
            "tangent_per_s": p,
            "tangent_mode": est["mode"],
            "tangent_d_m": est["selected_d_m"],
            "confirming_mode": est["confirming_mode"],
            "confirming_d_m": est["confirming_d_m"],
            "tangent_relative_difference": est["relative_difference"],
            "cumulative_contractions": contractions,
            "mf_iterations": mf_iters,
        })
        head = candidate

    status, _, res = residual_at(swap, origin, head, href, a, q_at_href)
    return {
        "classification":"OUTER_BUDGET_EXHAUSTED","outer":MAX_OUTER,
        "status":status,"final_head_m":head,"final_dh_m":head-href,
        "final_residual_m_per_s":res,"head_error_m":head-root_head,
        "contractions":contractions,"raw_inadmissible":raw_inadmissible,
        "merit_increases":merit_increases,"modes":modes,"trace":trace,
    }


def main() -> None:
    _, authorities = load_authority()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing libmf6 for G12B")
    require(swaplib.is_file(), "missing MAP09 SWAP library for G12B")

    swap = Map09ActiveDrainageSwap(swaplib)
    href, pred, origin = initialize_checked(swap)
    require(abs(href - HREF_EXPECTED) <= 1e-14, "G12B href authority drift")
    sref, qref = trial_discard(swap, origin, href)
    require(sref == 0 and abs(qref - QREF_EXPECTED) <= 1e-18, "G12B qref authority drift")

    estimator_rows = []
    for label, dh in (("HREF",0.0),("NEG",STARTS[0]),("POS",STARTS[1])):
        e3 = estimate_e3_map(swap, origin, href + dh)
        require(e3["classification"] == "AVAILABLE", f"G12B E3_MAP unavailable {label}")
        estimator_rows.append({"label":label,"dh_m":dh,"e3":e3})
        print("GC_G12B_ESTIMATOR_JSON=" + json.dumps(estimator_rows[-1], sort_keys=True, separators=(",", ":")))

    gw_rows = []
    root_rows = []
    policy_rows = []

    for authority in authorities:
        gw = remeasure_groundwater(libmf6, swaplib, href, qref, authority)
        gw_rows.append(gw)
        print("GC_G12B_GROUNDWATER_JSON=" + json.dumps(gw, sort_keys=True, separators=(",", ":")))

        root = reference_root(
            swap, origin, href, float(gw["a_per_s"]), float(gw["q_at_href_m_per_s"])
        )
        root_row = {"regime_id":gw["regime_id"], **root}
        root_rows.append(root_row)
        print("GC_G12B_ROOT_JSON=" + json.dumps(root_row, sort_keys=True, separators=(",", ":")))

        for side, dh in (("NEG",STARTS[0]),("POS",STARTS[1])):
            for policy in ("P1_E3_MAP","P4_E3_MAP"):
                result = run_policy(
                    policy, libmf6, swaplib, swap, origin, href, dh, gw, float(root["head_m"])
                )
                row = {
                    "regime_id":gw["regime_id"],"start_side":side,
                    "start_dh_m":dh,"policy":policy,**result,
                }
                policy_rows.append(row)
                print("GC_G12B_POLICY_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    p1 = [x for x in policy_rows if x["policy"] == "P1_E3_MAP"]
    p4 = [x for x in policy_rows if x["policy"] == "P4_E3_MAP"]
    require(all(x["classification"] == "CONVERGED" for x in p4),
            f"G12B P4 did not converge all active-drainage replays: {p4}")
    require(all(abs(float(x["head_error_m"])) <= HEAD_TOL for x in p4),
            "G12B P4 final head misses independent reference root")
    require(swap.state() == origin, "G12B changed accepted MAP09 authority")

    summary = {
        "groundwater_regime_count": len(gw_rows),
        "reference_root_count": len(root_rows),
        "policy_case_count": len(policy_rows),
        "p1_converged_count": sum(x["classification"] == "CONVERGED" for x in p1),
        "p1_failure_classes": sorted({x["classification"] for x in p1 if x["classification"] != "CONVERGED"}),
        "p4_converged_count": sum(x["classification"] == "CONVERGED" for x in p4),
        "p4_total_contractions": sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total": sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "max_p4_head_error_m": max(abs(float(x["head_error_m"])) for x in p4),
        "max_groundwater_fit_error_m_per_s": max(float(x["fit_error_m_per_s"]) for x in gw_rows),
        "max_groundwater_slope_rel_drift": max(float(x["slope_relative_difference_from_g12a"]) for x in gw_rows),
        "max_groundwater_qhref_abs_drift_m_per_s": max(float(x["q_at_href_abs_difference_from_g12a_m_per_s"]) for x in gw_rows),
    }
    print("GC_G12B_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("GC_G12B_GROUNDWATER_AUTHORITY=PASS")
    print("GC_G12B_REFERENCE_ROOTS=PASS")
    print("GC_G12B_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12B_EXECUTION=PASS")


if __name__ == "__main__":
    main()
