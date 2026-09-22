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
    DURATION_DAY,
    HREF_EXPECTED,
    QREF_EXPECTED,
    initialize_checked,
    estimate_e3_map,
    solve_term_map09,
)

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G12A_PREREGISTRATION.json"
G12_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G12_PREREGISTRATION.json"

LOCAL_Q_OFFSETS = (-2e-10, -1e-10, -5e-11, 0.0, 5e-11, 1e-10, 2e-10)
BISECTION_ITERS = 20
FIT_TOL = 1.0e-16


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def load_prereg() -> tuple[dict[str, object], list[dict[str, object]]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G12A", "wrong G12A preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G12A preregistration not frozen")
    require(tuple(float(x) for x in p["local_probe_offsets_m_per_s"]) == LOCAL_Q_OFFSETS,
            "G12A local q offsets drifted")
    require(int(p["direct_href_inversion"]["fixed_bisection_iterations"]) == BISECTION_ITERS,
            "G12A bisection count drifted")
    g12 = json.loads(G12_PREREG.read_text())
    return p, [dict(x) for x in g12["groundwater_regimes"]]


def resolve_sy(rule: str, p_href: float) -> float:
    duration_s = DURATION_DAY * DAY_TO_S
    if rule == "0.5*abs(p_href)*duration_seconds":
        return 0.5 * abs(p_href) * duration_s
    if rule == "2.0*abs(p_href)*duration_seconds":
        return 2.0 * abs(p_href) * duration_s
    if rule == "0.15":
        return 0.15
    raise AssertionError(f"unknown G12A sy rule {rule}")


def solve_q(
    libmf6: Path,
    swaplib: Path,
    href: float,
    regime: dict[str, object],
    sy: float,
    bias: float,
    q: float,
) -> tuple[float, float, int]:
    return solve_term_map09(
        libmf6,
        swaplib,
        href,
        float(regime["k_m_per_day"]),
        float(regime["ss_per_m"]),
        sy,
        bias,
        0.0,
        -q * AREA_M2 * DAY_TO_S,
    )


def one_shot_bias(
    libmf6: Path,
    swaplib: Path,
    href: float,
    qref: float,
    regime: dict[str, object],
    sy: float,
) -> dict[str, object]:
    h0, q0, it0 = solve_q(libmf6, swaplib, href, regime, sy, 0.0, qref)
    require(abs(q0 - qref) <= 64 * np.finfo(float).eps * max(1.0, abs(qref)),
            "G12A zero-bias imposed flux drift")
    bias = href - h0
    h1, q1, it1 = solve_q(libmf6, swaplib, href, regime, sy, bias, qref)
    require(abs(q1 - qref) <= 64 * np.finfo(float).eps * max(1.0, abs(qref)),
            "G12A translated imposed flux drift")
    return {
        "zero_bias_head_m": h0,
        "zero_bias_iterations": it0,
        "frozen_bias_m": bias,
        "translated_qref_head_m": h1,
        "translated_head_error_m": h1 - href,
        "translated_iterations": it1,
    }


def local_fit(
    libmf6: Path,
    swaplib: Path,
    href: float,
    qref: float,
    regime: dict[str, object],
    sy: float,
    bias: float,
) -> dict[str, object]:
    pts = []
    for dq in LOCAL_Q_OFFSETS:
        q = qref + dq
        h, qgw, iters = solve_q(libmf6, swaplib, href, regime, sy, bias, q)
        require(abs(qgw - q) <= 64 * np.finfo(float).eps * max(1.0, abs(q)),
                "G12A local imposed flux drift")
        pts.append({"dq_m_per_s": dq, "q_m_per_s": q, "head_m": h, "mf_iterations": iters})
    heads = np.asarray([x["head_m"] for x in pts], dtype=float)
    qs = np.asarray([x["q_m_per_s"] for x in pts], dtype=float)
    x = heads - href
    a, q_at_href = np.polyfit(x, qs, 1)
    a = float(a)
    q_at_href = float(q_at_href)
    fit = a * x + q_at_href
    err = float(np.max(np.abs(fit - qs)))
    require(math.isfinite(a) and a > 0.0, "G12A nonpositive/nonfinite local slope")
    require(err <= FIT_TOL, f"G12A local fit error too large: {err}")
    return {
        "a_per_s": a,
        "q_at_href_m_per_s": q_at_href,
        "qref_minus_q_at_href_m_per_s": qref - q_at_href,
        "max_fit_error_m_per_s": err,
        "points": pts,
    }


def direct_href_q(
    libmf6: Path,
    swaplib: Path,
    href: float,
    qref: float,
    regime: dict[str, object],
    sy: float,
    bias: float,
) -> dict[str, object]:
    qlo = qref - 2.0e-10
    qhi = qref + 2.0e-10
    hlo, _, ilo = solve_q(libmf6, swaplib, href, regime, sy, bias, qlo)
    hhi, _, ihi = solve_q(libmf6, swaplib, href, regime, sy, bias, qhi)
    flo = hlo - href
    fhi = hhi - href
    require(flo == 0.0 or fhi == 0.0 or flo * fhi < 0.0,
            f"G12A q bracket does not contain href: {flo}, {fhi}")

    history = [{
        "iteration": 0,
        "qlo_m_per_s": qlo,
        "qhi_m_per_s": qhi,
        "hlo_minus_href_m": flo,
        "hhi_minus_href_m": fhi,
        "mf_iterations_lo": ilo,
        "mf_iterations_hi": ihi,
    }]
    for i in range(1, BISECTION_ITERS + 1):
        qmid = 0.5 * (qlo + qhi)
        hmid, _, it = solve_q(libmf6, swaplib, href, regime, sy, bias, qmid)
        fmid = hmid - href
        history.append({
            "iteration": i,
            "qmid_m_per_s": qmid,
            "head_m": hmid,
            "head_minus_href_m": fmid,
            "mf_iterations": it,
        })
        if fmid == 0.0:
            qlo = qhi = qmid
            flo = fhi = 0.0
            continue
        if flo == 0.0:
            qhi = qlo
            fhi = flo
            continue
        if flo * fmid <= 0.0:
            qhi, fhi = qmid, fmid
        else:
            qlo, flo = qmid, fmid

    qfinal = 0.5 * (qlo + qhi)
    hfinal, _, itfinal = solve_q(libmf6, swaplib, href, regime, sy, bias, qfinal)
    return {
        "q_direct_href_m_per_s": qfinal,
        "qref_minus_q_direct_href_m_per_s": qref - qfinal,
        "head_at_q_direct_m": hfinal,
        "head_error_m": hfinal - href,
        "final_mf_iterations": itfinal,
        "final_q_bracket_width_m_per_s": abs(qhi - qlo),
        "history": history,
    }


def main() -> None:
    _, regimes = load_prereg()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing libmf6 for G12A")
    require(swaplib.is_file(), "missing MAP09 SWAP library for G12A")

    swap = Map09ActiveDrainageSwap(swaplib)
    href, pred, origin = initialize_checked(swap)
    require(abs(href - HREF_EXPECTED) <= 1e-14, "G12A href authority drift")
    status, qref = swap.try_trial(href)
    require(status == 0 and math.isfinite(qref), "G12A href corrector unavailable")
    swap.discard()
    require(swap.state() == origin, "G12A href trial mutated authority")
    require(abs(qref - QREF_EXPECTED) <= 1e-18, "G12A qref authority drift")

    e3 = estimate_e3_map(swap, origin, href)
    require(e3["classification"] == "AVAILABLE", "G12A E3 href unavailable")
    p_href = float(e3["slope_per_s"])

    rows = []
    for regime in regimes:
        sy = resolve_sy(str(regime["sy_rule"]), p_href)
        cal = one_shot_bias(libmf6, swaplib, href, qref, regime, sy)
        fit = local_fit(libmf6, swaplib, href, qref, regime, sy, float(cal["frozen_bias_m"]))
        direct = direct_href_q(libmf6, swaplib, href, qref, regime, sy, float(cal["frozen_bias_m"]))
        row = {
            "regime_id": regime["id"],
            "k_m_per_day": float(regime["k_m_per_day"]),
            "ss_per_m": float(regime["ss_per_m"]),
            "sy": sy,
            "one_shot_calibration": cal,
            "local_fit": fit,
            "direct_href_inversion": direct,
            "fit_minus_direct_href_q_m_per_s": float(fit["q_at_href_m_per_s"]) - float(direct["q_direct_href_m_per_s"]),
        }
        rows.append(row)
        print("GC_G12A_REGIME_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    require(len(rows) == 3, "G12A groundwater matrix incomplete")
    require(swap.state() == origin, "G12A changed accepted MAP09 authority")

    summary = {
        "regime_count": len(rows),
        "max_local_fit_error_m_per_s": max(float(x["local_fit"]["max_fit_error_m_per_s"]) for x in rows),
        "max_abs_qref_minus_fit_href_m_per_s": max(abs(float(x["local_fit"]["qref_minus_q_at_href_m_per_s"])) for x in rows),
        "max_abs_qref_minus_direct_href_m_per_s": max(abs(float(x["direct_href_inversion"]["qref_minus_q_direct_href_m_per_s"])) for x in rows),
        "max_abs_fit_minus_direct_href_q_m_per_s": max(abs(float(x["fit_minus_direct_href_q_m_per_s"])) for x in rows),
        "regimes_missing_g12_href_gate": [
            x["regime_id"] for x in rows
            if abs(float(x["local_fit"]["qref_minus_q_at_href_m_per_s"])) > 1.0e-15
        ],
    }
    print("GC_G12A_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("GC_G12A_LOCAL_FITS=PASS")
    print("GC_G12A_DIRECT_HREF_INVERSION=PASS")
    print("GC_G12A_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12A_DIAGNOSTIC=PASS")


if __name__ == "__main__":
    main()
