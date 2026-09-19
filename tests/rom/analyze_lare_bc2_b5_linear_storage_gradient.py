#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
spec3 = importlib.util.spec_from_file_location("bc2b3", HERE / "analyze_lare_bc2_b3_operator_attribution.py")
b3 = importlib.util.module_from_spec(spec3)
spec3.loader.exec_module(b3)

spec4 = importlib.util.spec_from_file_location("bc2b4", HERE / "analyze_lare_bc2_b4_boundary_localization.py")
b4 = importlib.util.module_from_spec(spec4)
spec4.loader.exec_module(b4)

GL64 = np.polynomial.legendre.leggauss(64)
GL128 = np.polynomial.legendre.leggauss(128)
ROOT_GATE = 1.0e-10
SLOPE_GATE = 1.0e-10
Q_CROSS_GATE = 1.0e-8
CANDIDATES = ("MOVING_LAYER_AVERAGE", "LINEAR_STORAGE", "POINT_2_5CM")


def integrate_linear_storage(a: float, L: float, nq: int) -> float:
    xg, wg = GL64 if nq == 64 else GL128
    half = 0.5 * L
    x = half * (xg + 1.0)
    theta = b3.theta_from_psi(a * x)
    return float(half * np.sum(wg * theta))


def solve_slope(W: float, L: float, nq: int) -> tuple[float, float]:
    if not (L > 0.0 and math.isfinite(W)):
        raise ValueError("invalid moving storage geometry")
    max_storage = b3.THETA_S * L
    min_storage = b3.THETA_R * L
    if W > max_storage + ROOT_GATE or W <= min_storage:
        raise ValueError("moving storage outside nonnegative linear-profile constitutive range")
    if abs(W - max_storage) <= ROOT_GATE:
        return 0.0, max_storage - W

    lo = 0.0
    hi = 1.0
    f_lo = integrate_linear_storage(lo, L, nq) - W
    f_hi = integrate_linear_storage(hi, L, nq) - W
    while f_hi > 0.0 and hi < 1.0e12:
        hi *= 2.0
        f_hi = integrate_linear_storage(hi, L, nq) - W
    if f_hi > 0.0:
        raise ValueError("could not bracket nonnegative slope root")

    mid = 0.5 * (lo + hi)
    f_mid = integrate_linear_storage(mid, L, nq) - W
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        f_mid = integrate_linear_storage(mid, L, nq) - W
        if abs(f_mid) <= ROOT_GATE:
            break
        if f_mid > 0.0:
            lo = mid
        else:
            hi = mid
    residual = integrate_linear_storage(mid, L, nq) - W
    return mid, residual


def q_linear_storage(profile, total, nq: int):
    H, storage, _ = b3.project(profile, total)
    L = H - b3.ANCHOR
    Wm = float(storage[b3.NFIXED])
    slope, residual = solve_slope(Wm, L, nq)
    return H, b3.KS * (1.0 - slope), slope, residual


def endpoint_values(profile, total):
    H, qstd = b4.q_moving(profile, total)
    _, qlin64, a64, res64 = q_linear_storage(profile, total, 64)
    _, qlin128, a128, res128 = q_linear_storage(profile, total, 128)
    qpoint, _, = b4.q_point(profile, H, 2.5)
    return {
        "H": H,
        "MOVING_LAYER_AVERAGE": qstd,
        "LINEAR_STORAGE": qlin64,
        "LINEAR_STORAGE_128": qlin128,
        "POINT_2_5CM": qpoint,
        "a64": a64,
        "a128": a128,
        "res64": res64,
        "res128": res128,
    }


def direction(hdot):
    if hdot < -b3.HDOT_EPS:
        return "WATER_TABLE_RISING"
    if hdot > b3.HDOT_EPS:
        return "WATER_TABLE_FALLING"
    return "HOLD"


def metrics(rows, name):
    ref = np.asarray([r["qref"] for r in rows], dtype=float)
    pred = np.asarray([r[name] for r in rows], dtype=float)
    err = pred - ref
    corr = float(np.corrcoef(ref, pred)[0, 1]) if np.std(ref) > 0 and np.std(pred) > 0 else None
    out = {
        "count": len(rows),
        "bias": float(np.mean(err)),
        "mae": float(np.mean(np.abs(err))),
        "rms": float(np.sqrt(np.mean(err * err))),
        "max_abs": float(np.max(np.abs(err))),
        "sign_mismatch": int(np.count_nonzero(np.sign(ref) != np.sign(pred))),
        "corr": corr,
    }
    if name == "LINEAR_STORAGE":
        slopes = np.asarray([r["a"] for r in rows], dtype=float)
        out["slope_a"] = {
            "min": float(np.min(slopes)),
            "max": float(np.max(slopes)),
            "mean": float(np.mean(slopes)),
            "median": float(np.median(slopes)),
        }
    return out


def component_improves(cand, base):
    return (
        cand["rms"] < base["rms"] - 1.0e-12
        and cand["mae"] < base["mae"] - 1.0e-12
        and cand["sign_mismatch"] <= base["sign_mismatch"]
    )


def noninferior(cand, base):
    return (
        cand["rms"] <= base["rms"] + 1.0e-12
        and cand["mae"] <= base["mae"] + 1.0e-12
        and cand["sign_mismatch"] <= base["sign_mismatch"]
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b4-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    b4res = json.loads(args.b4_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_MASS_CONSISTENT_LINEAR_PROFILE_QH_DIAGNOSTIC"
    assert b4res["decision"] == pre["predecessors"]["required_B4_decision"]

    init_meta, init_nodes, states, nodes = b3.load_reference(args.reference)
    rows = []
    failures = []
    max_root_res64 = 0.0
    max_root_res128 = 0.0
    max_q_cross = 0.0
    max_hydro_slope = 0.0

    # Independent hydrostatic property check over all distinct accepted H values.
    Hvals = []
    for hist, nsteps in b3.HISTORY_STEPS.items():
        Hvals.append(b3.diagnose_H(init_nodes[hist]))
        Hvals.extend(b3.diagnose_H(nodes[(hist, s)]) for s in range(1, nsteps + 1))
    for H in Hvals:
        L = H - b3.ANCHOR
        Weq = b3.integrate_eq(b3.ANCHOR, H, H, 64)
        aeq, req = solve_slope(Weq, L, 64)
        max_hydro_slope = max(max_hydro_slope, abs(aeq - 1.0), abs(req))

    for hist, nsteps in b3.HISTORY_STEPS.items():
        pp = init_nodes[hist]
        pt = init_meta[hist]["total"]
        try:
            prev = endpoint_values(pp, pt)
        except ValueError as exc:
            failures.append({"history": hist, "step": 0, "error": str(exc)})
            continue
        for step in range(1, nsteps + 1):
            p = nodes[(hist, step)]
            total = states[(hist, step)]["total"]
            try:
                cur = endpoint_values(p, total)
            except ValueError as exc:
                failures.append({"history": hist, "step": step, "error": str(exc)})
                pp, pt = p, total
                continue

            hdot = (cur["H"] - prev["H"]) / b3.OBS_DT
            row = {
                "history": hist,
                "step": step,
                "direction": direction(hdot),
                "qref": states[(hist, step)]["bottom_exchange"] / b3.OBS_DT,
                "MOVING_LAYER_AVERAGE": 0.5 * (prev["MOVING_LAYER_AVERAGE"] + cur["MOVING_LAYER_AVERAGE"]),
                "LINEAR_STORAGE": 0.5 * (prev["LINEAR_STORAGE"] + cur["LINEAR_STORAGE"]),
                "POINT_2_5CM": 0.5 * (prev["POINT_2_5CM"] + cur["POINT_2_5CM"]),
                "a": 0.5 * (prev["a64"] + cur["a64"]),
            }
            rows.append(row)
            max_root_res64 = max(max_root_res64, abs(prev["res64"]), abs(cur["res64"]))
            max_root_res128 = max(max_root_res128, abs(prev["res128"]), abs(cur["res128"]))
            max_q_cross = max(
                max_q_cross,
                abs(prev["LINEAR_STORAGE"] - prev["LINEAR_STORAGE_128"]),
                abs(cur["LINEAR_STORAGE"] - cur["LINEAR_STORAGE_128"]),
            )
            prev = cur
            pp, pt = p, total

    complete = not failures and len(rows) == sum(b3.HISTORY_STEPS.values())
    hard_ok = (
        complete
        and max_root_res64 <= ROOT_GATE
        and max_root_res128 <= ROOT_GATE
        and max_hydro_slope <= SLOPE_GATE
        and max_q_cross <= Q_CROSS_GATE
        and all(math.isfinite(r[k]) for r in rows for k in ("qref",) + CANDIDATES)
    )

    report = {"by_direction": {}, "by_history": {}}
    for axis, groups in (
        ("by_direction", ["HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"]),
        ("by_history", list(b3.HISTORY_STEPS)),
    ):
        for group in groups:
            rr = [r for r in rows if (r["direction"] == group if axis == "by_direction" else r["history"] == group)]
            report[axis][group] = {name: metrics(rr, name) for name in CANDIDATES}

    support = {
        d: component_improves(
            report["by_direction"][d]["LINEAR_STORAGE"],
            report["by_direction"][d]["MOVING_LAYER_AVERAGE"],
        )
        for d in ("WATER_TABLE_RISING", "WATER_TABLE_FALLING")
    }
    hold_noninferior = noninferior(
        report["by_direction"]["HOLD"]["LINEAR_STORAGE"],
        report["by_direction"]["HOLD"]["MOVING_LAYER_AVERAGE"],
    )
    if not hard_ok:
        decision = "BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_BLOCKED"
    elif all(support.values()) and hold_noninferior:
        decision = "BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_SUPPORTED"
    elif support["WATER_TABLE_RISING"] != support["WATER_TABLE_FALLING"]:
        decision = "BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_DIRECTION_DEPENDENT"
    else:
        decision = "BC2_B5_STORAGE_ONLY_BOUNDARY_GRADIENT_NOT_SUPPORTED"

    gap = {}
    for d in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
        lin = report["by_direction"][d]["LINEAR_STORAGE"]
        point = report["by_direction"][d]["POINT_2_5CM"]
        gap[d] = {
            "rms_excess_over_point_cm_per_day": lin["rms"] - point["rms"],
            "mae_excess_over_point_cm_per_day": lin["mae"] - point["mae"],
            "sign_mismatch_excess_over_point": lin["sign_mismatch"] - point["sign_mismatch"],
        }

    result = {
        "schema": "swap5.lare.bc2.b5.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-B5",
        "decision": decision,
        "complete": complete,
        "hard_checks": {
            "max_abs_root_storage_residual_64_cm": max_root_res64,
            "max_abs_root_storage_residual_128_cm": max_root_res128,
            "root_storage_residual_gate_cm": ROOT_GATE,
            "max_hydrostatic_slope_or_storage_residual": max_hydro_slope,
            "hydrostatic_slope_residual_gate": SLOPE_GATE,
            "max_abs_qH_64_vs_128_cm_per_day": max_q_cross,
            "qH_crosscheck_gate_cm_per_day": Q_CROSS_GATE,
            "failure_count": len(failures),
        },
        "support_by_direction": support,
        "hold_noninferior": hold_noninferior,
        "local_information_gap": gap,
        "failures": failures[:20],
        **report,
        "interpretation": [
            "LINEAR_STORAGE uses only the existing moving-layer storage Wm, geometry L and frozen constitutive parameters.",
            "The reconstructed slope is mass-consistent and contains no local full-order pressure-head input.",
            "POINT_2_5CM is retained only as the frozen full-order local-information diagnostic upper benchmark from B4.",
            "Support is operator-level evidence only; no reduced dynamics or added state is authorized by this result.",
        ],
        "added_state_dimension": 0,
        "propagated_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "support_by_direction": support,
        "hold_noninferior": hold_noninferior,
        "local_information_gap": gap,
        "by_direction": report["by_direction"],
    }, sort_keys=True))
    return 0 if hard_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
