#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent

def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

b3 = load_module("bc2b3", "analyze_lare_bc2_b3_operator_attribution.py")
b5 = load_module("bc2b5", "analyze_lare_bc2_b5_storage_linear_qh.py")
b8 = load_module("bc2b8", "analyze_lare_bc2_b8_terminal_control_volume.py")

WIDTHS = (2.5, 5.0)
OPS = ("STANDARD_SPLIT_LARE", "TERMINAL_SIDE_LINEAR", "BULK_SIDE_LINEAR")
GL = {
    64: np.polynomial.legendre.leggauss(64),
    128: np.polynomial.legendre.leggauss(128),
}
ROOT_GATE = 1.0e-10
HYDRO_GATE = 1.0e-10


def bulk_storage_for_slope(b: float, B: float, psi_i: float, nq: int) -> float:
    x, w = GL[nq]
    half = 0.5 * B
    y = half * (x + 1.0)
    psi = psi_i + b * y
    if np.min(psi) < -1.0e-10:
        raise ValueError("bulk reconstruction enters positive-pressure domain")
    theta = b3.theta_from_psi(np.maximum(psi, 0.0))
    return float(half * np.sum(w * theta))


def solve_bulk_slope(Wb: float, B: float, psi_i: float, nq: int):
    if B <= 0.0:
        raise ValueError("nonpositive bulk thickness")
    lo = -psi_i / B
    flo = bulk_storage_for_slope(lo, B, psi_i, nq) - Wb
    if flo < -ROOT_GATE:
        raise ValueError("bulk storage exceeds admissible profile maximum")

    hi = max(1.0, lo + 1.0)
    fhi = bulk_storage_for_slope(hi, B, psi_i, nq) - Wb
    while fhi > 0.0 and hi < 1.0e10:
        hi = max(2.0 * hi, hi + 1.0)
        fhi = bulk_storage_for_slope(hi, B, psi_i, nq) - Wb
    if fhi > 0.0:
        raise ValueError("could not bracket bulk slope")

    for _ in range(180):
        mid = 0.5 * (lo + hi)
        fm = bulk_storage_for_slope(mid, B, psi_i, nq) - Wb
        if abs(fm) <= 1.0e-13:
            lo = hi = mid
            break
        if fm > 0.0:
            lo = mid
        else:
            hi = mid

    b = 0.5 * (lo + hi)
    residual = bulk_storage_for_slope(b, B, psi_i, nq) - Wb
    return b, residual


def endpoint_candidates(profile, total, d):
    p = b8.projected(profile, total, d)
    H = p["H"]
    B = H - b3.ANCHOR - d
    if B <= 0.0:
        raise ValueError("terminal width leaves no bulk layer")

    Wb = p["Wb64"]
    Wt = p["Wt64"]
    theta_b = Wb / B
    theta_t = Wt / d
    psi, kval = b3.psi_k(np.asarray([theta_b, theta_t], dtype=float))
    psi_b, psi_t = float(psi[0]), float(psi[1])
    Kb, Kt = float(kval[0]), float(kval[1])
    Kint = (d * Kb + B * Kt) / (B + d)
    q_standard = Kint * (1.0 + 2.0 * (psi_t - psi_b) / (B + d))

    a_t, a_res = b5.solve_slope(Wt, d, 64)
    psi_i = a_t * d
    theta_i_recon = float(b3.theta_from_psi(psi_i))
    _, Ki_arr = b3.psi_k(np.asarray([theta_i_recon], dtype=float))
    Ki = float(Ki_arr[0])
    q_terminal = Ki * (1.0 - a_t)

    b_bulk, b_res = solve_bulk_slope(Wb, B, psi_i, 64)
    q_bulk = Ki * (1.0 - b_bulk)

    return {
        "projected": p,
        "B": B,
        "psi_i": psi_i,
        "Ki": Ki,
        "a_t": a_t,
        "a_res": a_res,
        "b_bulk": b_bulk,
        "b_res": b_res,
        "STANDARD_SPLIT_LARE": q_standard,
        "TERMINAL_SIDE_LINEAR": q_terminal,
        "BULK_SIDE_LINEAR": q_bulk,
    }


def direction(Hdot):
    if Hdot < -b3.HDOT_EPS:
        return "WATER_TABLE_RISING"
    if Hdot > b3.HDOT_EPS:
        return "WATER_TABLE_FALLING"
    return "HOLD"


def flux_metrics(rows, key):
    ref = np.asarray([r["qi_ref"] for r in rows], dtype=float)
    pred = np.asarray([r[key] for r in rows], dtype=float)
    err = pred - ref
    corr = float(np.corrcoef(ref, pred)[0, 1]) if np.std(ref) > 0.0 and np.std(pred) > 0.0 else None
    return {
        "count": int(len(rows)),
        "bias": float(np.mean(err)),
        "mae": float(np.mean(np.abs(err))),
        "rms": float(np.sqrt(np.mean(err * err))),
        "max_abs": float(np.max(np.abs(err))),
        "sign_mismatch": int(np.count_nonzero(np.sign(ref) != np.sign(pred))),
        "corr": corr,
    }


def scalar_stats(values):
    a = np.asarray(values, dtype=float)
    return {
        "count": int(len(a)),
        "min": float(np.min(a)),
        "mean": float(np.mean(a)),
        "max": float(np.max(a)),
        "rms": float(np.sqrt(np.mean(a * a))),
    }


def better(cand, std):
    return (
        cand["rms"] < std["rms"] - 1.0e-12
        and cand["mae"] < std["mae"] - 1.0e-12
        and cand["sign_mismatch"] <= std["sign_mismatch"]
    )


def noninferior(cand, std):
    return (
        cand["rms"] <= std["rms"] + 1.0e-12
        and cand["mae"] <= std["mae"] + 1.0e-12
        and cand["sign_mismatch"] <= std["sign_mismatch"]
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b7-result", required=True, type=pathlib.Path)
    ap.add_argument("--b8-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    r7 = json.loads(args.b7_result.read_text())
    r8 = json.loads(args.b8_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_ENRICHED_STATE_INTERNAL_FLUX_CLOSURE_DIAGNOSTIC"
    assert r7["decision"] == pre["predecessors"]["required_B7_decision"]
    assert r8["decision"] == pre["predecessors"]["required_B8_decision"]

    init_meta, init_nodes, states, nodes = b3.load_reference(args.reference)

    rows_by_width = {d: [] for d in WIDTHS}
    failures = {d: {op: [] for op in OPS} for d in WIDTHS}
    max_qi_identity = 0.0
    max_hydro = 0.0
    max_root = 0.0

    # Manufactured hydrostatic invariants for both one-sided shape operators.
    for d in WIDTHS:
        for H in (105.0, 120.0, 138.0):
            L = H - b3.ANCHOR
            B = L - d
            Wt = b5.storage_for_slope(1.0, d, 64)
            a, ar = b5.solve_slope(Wt, d, 64)
            psi_i = a * d
            Wb = bulk_storage_for_slope(1.0, B, psi_i, 64)
            b, br = solve_bulk_slope(Wb, B, psi_i, 64)
            max_hydro = max(max_hydro, abs(a - 1.0), abs(b - 1.0))
            max_root = max(max_root, abs(ar), abs(br))

    for history, nsteps in b3.HISTORY_STEPS.items():
        prev_proj = {}
        prev_cand = {}
        for d in WIDTHS:
            prev_proj[d] = b8.projected(init_nodes[history], init_meta[history]["total"], d)
            try:
                prev_cand[d] = endpoint_candidates(init_nodes[history], init_meta[history]["total"], d)
            except ValueError as exc:
                for op in OPS:
                    failures[d][op].append({"history": history, "step": 0, "error": str(exc)})
                prev_cand[d] = None

        for step in range(1, nsteps + 1):
            qH = states[(history, step)]["bottom_exchange"] / b3.OBS_DT
            cur_proj = {
                d: b8.projected(nodes[(history, step)], states[(history, step)]["total"], d)
                for d in WIDTHS
            }
            q90 = -(cur_proj[WIDTHS[0]]["Wfixed"] - prev_proj[WIDTHS[0]]["Wfixed"]) / b3.OBS_DT
            Hdot = (cur_proj[WIDTHS[0]]["H"] - prev_proj[WIDTHS[0]]["H"]) / b3.OBS_DT

            for d in WIDTHS:
                p0 = prev_proj[d]
                p1 = cur_proj[d]
                Gi = 0.5 * (p0["theta_i"] + p1["theta_i"]) * Hdot
                dWb = (p1["Wb64"] - p0["Wb64"]) / b3.OBS_DT
                dWt = (p1["Wt64"] - p0["Wt64"]) / b3.OBS_DT
                qi_bulk_ref = q90 + Gi - dWb
                qi_term_ref = dWt + qH - b3.THETA_S * Hdot + Gi
                max_qi_identity = max(max_qi_identity, abs(qi_bulk_ref - qi_term_ref))
                qi_ref = 0.5 * (qi_bulk_ref + qi_term_ref)

                try:
                    cur = endpoint_candidates(nodes[(history, step)], states[(history, step)]["total"], d)
                except ValueError as exc:
                    for op in OPS:
                        failures[d][op].append({"history": history, "step": step, "error": str(exc)})
                    prev_cand[d] = None
                    continue

                if prev_cand[d] is None:
                    prev_cand[d] = cur
                    continue

                row = {
                    "history": history,
                    "step": step,
                    "direction": direction(Hdot),
                    "qi_ref": qi_ref,
                }
                for op in OPS:
                    row[op] = 0.5 * (prev_cand[d][op] + cur[op])
                row["one_sided_mismatch"] = row["TERMINAL_SIDE_LINEAR"] - row["BULK_SIDE_LINEAR"]
                row["a_t"] = 0.5 * (prev_cand[d]["a_t"] + cur["a_t"])
                row["b_bulk"] = 0.5 * (prev_cand[d]["b_bulk"] + cur["b_bulk"])
                rows_by_width[d].append(row)
                max_root = max(
                    max_root,
                    abs(prev_cand[d]["a_res"]), abs(cur["a_res"]),
                    abs(prev_cand[d]["b_res"]), abs(cur["b_res"]),
                )
                prev_cand[d] = cur

            prev_proj = cur_proj

    hard_ok = (
        max_qi_identity <= 1.0e-10
        and max_hydro <= HYDRO_GATE
        and max_root <= ROOT_GATE
    )

    report = {}
    support = {}
    supported_pairs = []
    for d in WIDTHS:
        report[str(d)] = {"by_direction": {}, "by_history": {}}
        complete_ops = {
            op: len(failures[d][op]) == 0 and len(rows_by_width[d]) == sum(b3.HISTORY_STEPS.values())
            for op in OPS
        }

        for axis, groups in (
            ("by_direction", ["HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"]),
            ("by_history", list(b3.HISTORY_STEPS)),
        ):
            for group in groups:
                rr = [
                    r for r in rows_by_width[d]
                    if (r["direction"] == group if axis == "by_direction" else r["history"] == group)
                ]
                report[str(d)][axis][group] = {
                    op: flux_metrics(rr, op) for op in OPS
                }
                report[str(d)][axis][group]["one_sided_mismatch_cm_per_day"] = scalar_stats(
                    [r["one_sided_mismatch"] for r in rr]
                )
                report[str(d)][axis][group]["a_t"] = scalar_stats([r["a_t"] for r in rr])
                report[str(d)][axis][group]["b_bulk"] = scalar_stats([r["b_bulk"] for r in rr])

        support[str(d)] = {}
        std_by_dir = {
            g: report[str(d)]["by_direction"][g]["STANDARD_SPLIT_LARE"]
            for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING")
        }
        for op in ("TERMINAL_SIDE_LINEAR", "BULK_SIDE_LINEAR"):
            moving = {
                g: complete_ops[op] and better(
                    report[str(d)]["by_direction"][g][op],
                    std_by_dir[g],
                )
                for g in ("WATER_TABLE_RISING", "WATER_TABLE_FALLING")
            }
            hold = complete_ops[op] and noninferior(
                report[str(d)]["by_direction"]["HOLD"][op],
                std_by_dir["HOLD"],
            )
            support[str(d)][op] = {
                "defined_on_all_states": complete_ops[op],
                "WATER_TABLE_RISING": moving["WATER_TABLE_RISING"],
                "WATER_TABLE_FALLING": moving["WATER_TABLE_FALLING"],
                "HOLD_NONINFERIOR": hold,
            }
            if all(moving.values()) and hold:
                supported_pairs.append((d, op))

    preferred_ops = []
    supported_ops = sorted({op for _, op in supported_pairs})
    for op in supported_ops:
        ok = True
        for d in WIDTHS:
            if (d, op) not in supported_pairs:
                ok = False
                break
            for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
                candidates = [
                    report[str(d)]["by_direction"][g][other]
                    for other in supported_ops
                    if (d, other) in supported_pairs
                ]
                cur = report[str(d)]["by_direction"][g][op]
                if candidates:
                    min_rms = min(x["rms"] for x in candidates)
                    min_mae = min(x["mae"] for x in candidates)
                    min_sign = min(x["sign_mismatch"] for x in candidates)
                    ok &= (
                        cur["rms"] <= min_rms + 1.0e-12
                        and cur["mae"] <= min_mae + 1.0e-12
                        and cur["sign_mismatch"] <= min_sign
                    )
        if ok:
            preferred_ops.append(op)

    preferred_widths = []
    if len(preferred_ops) == 1:
        op = preferred_ops[0]
        for d in WIDTHS:
            if (d, op) not in supported_pairs:
                continue
            ok = True
            for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
                cur = report[str(d)]["by_direction"][g][op]
                pool = [
                    report[str(dd)]["by_direction"][g][op]
                    for dd in WIDTHS if (dd, op) in supported_pairs
                ]
                min_rms = min(x["rms"] for x in pool)
                min_mae = min(x["mae"] for x in pool)
                min_sign = min(x["sign_mismatch"] for x in pool)
                ok &= (
                    cur["rms"] <= min_rms + 1.0e-12
                    and cur["mae"] <= min_mae + 1.0e-12
                    and cur["sign_mismatch"] <= min_sign
                )
            if ok:
                preferred_widths.append(d)

    direction_dependent = any(
        v["WATER_TABLE_RISING"] != v["WATER_TABLE_FALLING"]
        for d in support.values()
        for v in d.values()
    )

    if not hard_ok:
        decision = "BC2_B9_ENRICHED_STATE_QI_DIAGNOSTIC_BLOCKED"
    elif supported_pairs and len(preferred_ops) == 1 and preferred_widths:
        decision = "BC2_B9_ENRICHED_STATE_QI_CLOSURE_SUPPORTED"
    elif supported_pairs:
        decision = "BC2_B9_ENRICHED_STATE_QI_CLOSURE_SUPPORTED_OPERATOR_OR_WIDTH_UNRESOLVED"
    elif direction_dependent:
        decision = "BC2_B9_ENRICHED_STATE_QI_DIRECTION_DEPENDENT"
    else:
        decision = "BC2_B9_ENRICHED_STATE_QI_NOT_SUPPORTED"

    result = {
        "schema": "swap5.lare.bc2.b9.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-B9",
        "decision": decision,
        "hard_checks": {
            "max_abs_reference_qi_bulk_minus_terminal_cm_per_day": max_qi_identity,
            "reference_qi_identity_gate_cm_per_day": 1.0e-10,
            "max_hydrostatic_abs_slope_minus_1": max_hydro,
            "hydrostatic_slope_gate": HYDRO_GATE,
            "max_abs_shape_root_storage_residual_cm": max_root,
            "root_storage_residual_gate_cm": ROOT_GATE,
        },
        "candidate_failures": {
            str(d): {op: failures[d][op][:20] for op in OPS}
            for d in WIDTHS
        },
        "support": support,
        "supported_width_operator_pairs": [
            {"width_cm": d, "operator": op} for d, op in supported_pairs
        ],
        "preferred_operator": preferred_ops,
        "preferred_width_cm": preferred_widths,
        "widths": report,
        "interpretation": [
            "Reference qi is fixed by the qualified B8 split moving-control-volume ledger, not by a fitted local flux target.",
            "All candidate qi closures use only Wb, Wt, H and frozen constitutive functions.",
            "The terminal-vs-bulk one-sided flux mismatch is reported without empirical blending.",
            "Positive operator support would still require a separately preregistered propagated-dynamics experiment."
        ],
        "propagated_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "support": support,
        "supported_pairs": result["supported_width_operator_pairs"],
        "preferred_operator": preferred_ops,
        "preferred_width_cm": preferred_widths,
        "by_direction": {
            d: report[str(d)]["by_direction"] for d in WIDTHS
        },
    }, sort_keys=True))
    return 0 if hard_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
