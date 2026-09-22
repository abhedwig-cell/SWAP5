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
    solve_term,
    trial_discard,
)

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G10A_PREREGISTRATION.json"

DURATION_DAY = 1.0e-2
QBOT_CM_PER_DAY = 1.0e-6
HREF_EXPECTED = -0.7149999311459918
U_EXPECTED = 0.00119027208545508
K_M_PER_DAY = 1.0
SS_PER_M = 0.02
SY = 0.15
HEAD_BIAS_M = 0.0
BROAD_PROBES = (-4.0e-8, -2.0e-8, 2.0e-8, 4.0e-8)
LOCAL_LADDER = (
    -2.0e-9, -1.0e-9, -5.0e-10, -2.0e-10, -1.0e-10, -5.0e-11, 0.0,
    5.0e-11, 1.0e-10, 2.0e-10, 5.0e-10, 1.0e-9, 2.0e-9,
)
FAILURE_HEADS = {
    "outer1_accepted": -0.7149997334398905,
    "outer2_raw": -0.7149997332233566,
    "broad_affine_reference_root": -0.7149997350308794,
}
DIRECT_Q_LO = -2.0e-9
DIRECT_Q_HI = 2.0e-9
DIRECT_HEAD_TOL = 1.0e-12
DIRECT_MAX_BISECT = 60
ROOT_Q_TOL = 1.0e-16
ROOT_MAX_BISECT = 80
MERIT_ABS_TOL = 1.0e-18


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> dict[str, object]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G10A", "wrong G10A preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G10A preregistration not frozen")
    require(tuple(float(x) for x in p["local_flux_ladder_m_per_s"]) == LOCAL_LADDER, "G10A local ladder drifted")
    require(tuple(float(x) for x in p["groundwater_regime"]["broad_affine_probes_m_per_s"]) == BROAD_PROBES,
            "G10A broad probes drifted")
    return p


def fit_affine(points: list[tuple[float, float]]) -> dict[str, float]:
    heads = np.asarray([x[0] for x in points], dtype=float)
    fluxes = np.asarray([x[1] for x in points], dtype=float)
    a, b = np.polyfit(heads, fluxes, 1)
    err = float(np.max(np.abs(a * heads + b - fluxes)))
    return {"a_per_s": float(a), "intercept": float(b), "max_fit_error_m_per_s": err}


def main() -> None:
    prereg = load_prereg()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP bridge library")

    swap = Fgc44RealSwap(swaplib)
    _, _, href, origin, diag = initialize_case(swap, DURATION_DAY, QBOT_CM_PER_DAY)
    require(origin == (0, 0.0, 0, 0.0), "G10A dirty SWAP origin")
    tol = float(prereg["carrier"]["binding_abs_tolerance"])
    require(math.isclose(href, HREF_EXPECTED, rel_tol=0.0, abs_tol=tol), "G10A B4 href mismatch")
    require(math.isclose(float(diag["u"]), U_EXPECTED, rel_tol=0.0, abs_tol=tol), "G10A B4 u mismatch")
    require(math.isclose(float(diag["q_bot_predictor_cm_per_day"]), QBOT_CM_PER_DAY, rel_tol=0.0, abs_tol=tol),
            "G10A B4 qbot mismatch")

    head_cache: dict[str, tuple[float, int]] = {}

    def head_for_q(q: float) -> tuple[float, int]:
        key = float(q).hex()
        if key not in head_cache:
            h, qgw, iters = solve_term(
                libmf6, swaplib, DURATION_DAY, href,
                K_M_PER_DAY, SS_PER_M, SY, HEAD_BIAS_M,
                0.0, -q * AREA_M2 * DAY_TO_S,
            )
            require(abs(qgw - q) <= 64.0 * np.finfo(float).eps * max(1.0, abs(q)),
                    f"G10A constant-flux probe drift: requested {q}, got {qgw}")
            head_cache[key] = (float(h), int(iters))
        return head_cache[key]

    broad_points: list[tuple[float, float]] = []
    for q in BROAD_PROBES:
        h, iters = head_for_q(q)
        broad_points.append((h, q))
        print("FGC44_G10A_BROAD_POINT=" + json.dumps({
            "q_m_per_s": q, "head_m": h, "mf_iterations": iters
        }, sort_keys=True, separators=(",", ":")))
    broad_fit = fit_affine(broad_points)
    observed = prereg["groundwater_regime"]["broad_affine_observed_from_g10"]
    require(math.isclose(broad_fit["a_per_s"], float(observed["slope_per_s"]), rel_tol=1.0e-8, abs_tol=0.0),
            f"G10A broad slope did not reproduce G10: {broad_fit}")
    require(abs(broad_fit["intercept"] - float(observed["intercept"])) <= 1.0e-11,
            f"G10A broad intercept did not reproduce G10: {broad_fit}")
    require(broad_fit["max_fit_error_m_per_s"] <= 5.0e-12, "G10A broad fit violated frozen G10 fit gate")
    print("FGC44_G10A_BROAD_FIT=" + json.dumps(broad_fit, sort_keys=True, separators=(",", ":")))

    ladder_rows: list[dict[str, float | int | None]] = []
    for q in LOCAL_LADDER:
        h, iters = head_for_q(q)
        status, qswap = trial_discard(swap, origin, h)
        row = {
            "q_groundwater_m_per_s": q,
            "head_m": h,
            "mf_iterations": iters,
            "swap_status": status,
            "q_swap_m_per_s": qswap if status == 0 else None,
            "coupled_residual_m_per_s": (qswap - q) if status == 0 else None,
        }
        ladder_rows.append(row)
        print("FGC44_G10A_LOCAL_POINT=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
    require(swap.state() == origin, "G10A ladder mutated accepted authority")

    nested_fits: list[dict[str, float | int]] = []
    for qmax in (2.0e-10, 5.0e-10, 1.0e-9, 2.0e-9):
        pts = [
            (float(r["head_m"]), float(r["q_groundwater_m_per_s"]))
            for r in ladder_rows
            if abs(float(r["q_groundwater_m_per_s"])) <= qmax
        ]
        fit = fit_affine(pts)
        fit["qmax_m_per_s"] = qmax
        fit["point_count"] = len(pts)
        nested_fits.append(fit)
        print("FGC44_G10A_LOCAL_FIT=" + json.dumps(fit, sort_keys=True, separators=(",", ":")))

    hlo, _ = head_for_q(DIRECT_Q_LO)
    hhi, _ = head_for_q(DIRECT_Q_HI)
    require(hlo < hhi, "G10A groundwater H(q) is not increasing over direct bracket")

    direct_cache: dict[str, dict[str, float | int]] = {}

    def direct_q_at_head(target_h: float) -> dict[str, float | int]:
        key = float(target_h).hex()
        if key in direct_cache:
            return direct_cache[key]
        require(hlo <= target_h <= hhi, f"G10A target head outside direct q bracket: {target_h}")
        lo, hi = DIRECT_Q_LO, DIRECT_Q_HI
        h_lo, h_hi = hlo, hhi
        iterations = 0
        for iterations in range(1, DIRECT_MAX_BISECT + 1):
            mid = 0.5 * (lo + hi)
            h_mid, _ = head_for_q(mid)
            if abs(h_mid - target_h) <= DIRECT_HEAD_TOL:
                lo = hi = mid
                h_lo = h_hi = h_mid
                break
            if h_mid < target_h:
                lo, h_lo = mid, h_mid
            else:
                hi, h_hi = mid, h_mid
        q = 0.5 * (lo + hi)
        h, _ = head_for_q(q)
        out = {
            "target_head_m": target_h,
            "q_groundwater_m_per_s": q,
            "resolved_head_m": h,
            "head_error_m": h - target_h,
            "bisections": iterations,
        }
        require(abs(h - target_h) <= 2.0 * DIRECT_HEAD_TOL,
                f"G10A direct q inversion did not meet head tolerance: {out}")
        direct_cache[key] = out
        return out

    frozen_head_rows = []
    for name, h in FAILURE_HEADS.items():
        direct = direct_q_at_head(h)
        status, qswap = trial_discard(swap, origin, h)
        require(status == 0, f"G10A frozen failure head no longer SWAP-admissible: {name}")
        q_broad = broad_fit["a_per_s"] * h + broad_fit["intercept"]
        row = {
            "name": name,
            "head_m": h,
            "q_swap_m_per_s": qswap,
            "q_groundwater_broad_m_per_s": q_broad,
            "q_groundwater_direct_m_per_s": direct["q_groundwater_m_per_s"],
            "broad_minus_direct_qgw_m_per_s": q_broad - float(direct["q_groundwater_m_per_s"]),
            "broad_residual_m_per_s": qswap - q_broad,
            "direct_residual_m_per_s": qswap - float(direct["q_groundwater_m_per_s"]),
            "direct_inversion": direct,
        }
        frozen_head_rows.append(row)
        print("FGC44_G10A_FAILURE_HEAD=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    # Direct coupled root in groundwater-flux space.
    valid = [r for r in ladder_rows if int(r["swap_status"]) == 0]
    valid.sort(key=lambda r: float(r["q_groundwater_m_per_s"]))
    bracket = None
    for left, right in zip(valid[:-1], valid[1:]):
        fl = float(left["coupled_residual_m_per_s"])
        fr = float(right["coupled_residual_m_per_s"])
        if fl == 0.0:
            bracket = (float(left["q_groundwater_m_per_s"]),) * 2
            break
        if fl * fr <= 0.0:
            bracket = (float(left["q_groundwater_m_per_s"]), float(right["q_groundwater_m_per_s"]))
            break

    direct_root = None
    if bracket is not None:
        qlo, qhi = bracket
        def residual_in_q(q: float) -> tuple[float, float, float]:
            h, _ = head_for_q(q)
            st, qs = trial_discard(swap, origin, h)
            require(st == 0, f"G10A direct-root bisection hit SWAP failure at q={q}")
            return qs - q, h, qs

        if qlo == qhi:
            froot, hroot, qsroot = residual_in_q(qlo)
            direct_root = {
                "q_groundwater_m_per_s": qlo, "head_m": hroot,
                "q_swap_m_per_s": qsroot, "residual_m_per_s": froot, "bisections": 0,
            }
        else:
            flo, _, _ = residual_in_q(qlo)
            fhi, _, _ = residual_in_q(qhi)
            require(flo * fhi <= 0.0, "G10A direct root bracket lost sign change")
            n = 0
            for n in range(1, ROOT_MAX_BISECT + 1):
                qm = 0.5 * (qlo + qhi)
                fm, hm, qsm = residual_in_q(qm)
                if abs(fm) <= ROOT_Q_TOL or abs(qhi - qlo) <= ROOT_Q_TOL:
                    qlo = qhi = qm
                    break
                if flo * fm <= 0.0:
                    qhi, fhi = qm, fm
                else:
                    qlo, flo = qm, fm
            qroot = 0.5 * (qlo + qhi)
            froot, hroot, qsroot = residual_in_q(qroot)
            direct_root = {
                "q_groundwater_m_per_s": qroot, "head_m": hroot,
                "q_swap_m_per_s": qsroot, "residual_m_per_s": froot, "bisections": n,
            }
        print("FGC44_G10A_DIRECT_ROOT=" + json.dumps(direct_root, sort_keys=True, separators=(",", ":")))

    # Replay exactly the failed P4 line in diagnostic-only mode.
    hcur = float(prereg["line_search_replay"]["current_head_m"])
    hraw = float(prereg["line_search_replay"]["raw_head_m"])
    contractions = [int(x) for x in prereg["line_search_replay"]["contractions"]]

    cur_status, cur_qswap = trial_discard(swap, origin, hcur)
    require(cur_status == 0, "G10A current line-search head not SWAP-admissible")
    cur_direct = direct_q_at_head(hcur)
    cur_broad_q = broad_fit["a_per_s"] * hcur + broad_fit["intercept"]
    current_broad_merit = abs(cur_qswap - cur_broad_q)
    current_direct_merit = abs(cur_qswap - float(cur_direct["q_groundwater_m_per_s"]))

    line_rows = []
    first_broad_nonincrease = None
    first_direct_nonincrease = None
    for k in contractions:
        h = hcur + (0.5 ** k) * (hraw - hcur)
        st, qs = trial_discard(swap, origin, h)
        q_broad = broad_fit["a_per_s"] * h + broad_fit["intercept"]
        direct = direct_q_at_head(h)
        broad_res = (qs - q_broad) if st == 0 else None
        direct_res = (qs - float(direct["q_groundwater_m_per_s"])) if st == 0 else None
        row = {
            "contractions": k,
            "head_m": h,
            "swap_status": st,
            "q_swap_m_per_s": qs if st == 0 else None,
            "q_groundwater_broad_m_per_s": q_broad,
            "q_groundwater_direct_m_per_s": direct["q_groundwater_m_per_s"],
            "broad_residual_m_per_s": broad_res,
            "direct_residual_m_per_s": direct_res,
            "broad_merit_m_per_s": abs(broad_res) if broad_res is not None else None,
            "direct_merit_m_per_s": abs(direct_res) if direct_res is not None else None,
            "direct_inversion_head_error_m": direct["head_error_m"],
        }
        line_rows.append(row)
        if st == 0 and first_broad_nonincrease is None and abs(broad_res) <= current_broad_merit + MERIT_ABS_TOL:
            first_broad_nonincrease = k
        if st == 0 and first_direct_nonincrease is None and abs(direct_res) <= current_direct_merit + MERIT_ABS_TOL:
            first_direct_nonincrease = k
        print("FGC44_G10A_LINE_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

    require(swap.state() == origin, "G10A diagnostic mutated accepted SWAP/ledger authority")

    summary = {
        "broad_fit_error_m_per_s": broad_fit["max_fit_error_m_per_s"],
        "broad_fit_error_over_g10_residual_tolerance": broad_fit["max_fit_error_m_per_s"] / 1.0e-15,
        "smallest_local_fit_error_m_per_s": min(float(x["max_fit_error_m_per_s"]) for x in nested_fits),
        "direct_root_available": direct_root is not None,
        "direct_root_head_m": direct_root["head_m"] if direct_root else None,
        "broad_affine_root_head_m": FAILURE_HEADS["broad_affine_reference_root"],
        "root_head_difference_m": (
            float(direct_root["head_m"]) - FAILURE_HEADS["broad_affine_reference_root"]
            if direct_root else None
        ),
        "current_broad_merit_m_per_s": current_broad_merit,
        "current_direct_merit_m_per_s": current_direct_merit,
        "first_broad_nonincrease_contraction": first_broad_nonincrease,
        "first_direct_nonincrease_contraction": first_direct_nonincrease,
        "merit_ordering_differs": first_broad_nonincrease != first_direct_nonincrease,
    }
    print("FGC44_G10A_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G10A_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G10A_DIAGNOSTIC=PASS")


if __name__ == "__main__":
    main()
