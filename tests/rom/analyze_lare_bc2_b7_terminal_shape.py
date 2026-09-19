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
b4 = load_module("bc2b4", "analyze_lare_bc2_b4_boundary_localization.py")
b5 = load_module("bc2b5", "analyze_lare_bc2_b5_storage_linear_qh.py")
b6 = load_module("bc2b6", "analyze_lare_bc2_b6_terminal_storage.py")

WIDTHS = (2.5, 5.0, 10.0)
ROOT_GATE = 1.0e-10
Q_CROSS_GATE = 1.0e-8
HYDRO_GATE = 1.0e-10


def local_shape_candidate(profile, total, d, nq):
    projected = b6.terminal_candidate(profile, total, d, 64)
    Wt = projected["Wt"]
    a, residual = b5.solve_slope(Wt, d, nq)
    return {
        "qH": b3.KS * (1.0 - a),
        "a": a,
        "root_residual": residual,
        "Wt": Wt,
        "theta_t": projected["theta_t"],
        "H": projected["H"],
    }


def endpoint(profile, total):
    H, qstd = b4.q_moving(profile, total)
    _, qglobal, _, _ = b5.q_storage(profile, total, 64)
    qpoint, _ = b4.q_point(profile, H, 2.5)
    out = {
        "H": H,
        "MOVING_LAYER_AVERAGE": qstd,
        "LINEAR_STORAGE": qglobal,
        "POINT_2_5CM": qpoint,
        "bands": {},
    }
    for d in WIDTHS:
        naive = b6.terminal_candidate(profile, total, d, 64)
        local64 = local_shape_candidate(profile, total, d, 64)
        local128 = local_shape_candidate(profile, total, d, 128)
        out["bands"][d] = {
            "TERMINAL_AVERAGE": naive["qH"],
            "LOCAL_LINEAR_64": local64,
            "LOCAL_LINEAR_128": local128,
        }
    return out


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
    corr = float(np.corrcoef(ref, pred)[0, 1]) if np.std(ref) > 0.0 and np.std(pred) > 0.0 else None
    out = {
        "count": int(len(rows)),
        "bias": float(np.mean(err)),
        "mae": float(np.mean(np.abs(err))),
        "rms": float(np.sqrt(np.mean(err * err))),
        "max_abs": float(np.max(np.abs(err))),
        "sign_mismatch": int(np.count_nonzero(np.sign(ref) != np.sign(pred))),
        "corr": corr,
    }
    if name.startswith("TERM_LINEAR_"):
        slopes = np.asarray([r[name + "_a"] for r in rows], dtype=float)
        out["slope_a"] = {
            "min": float(np.min(slopes)),
            "mean": float(np.mean(slopes)),
            "median": float(np.median(slopes)),
            "max": float(np.max(slopes)),
        }
    return out


def strictly_better(cand, comp):
    return (
        cand["rms"] < comp["rms"] - 1.0e-12
        and cand["mae"] < comp["mae"] - 1.0e-12
        and cand["sign_mismatch"] <= comp["sign_mismatch"]
    )


def noninferior(cand, comp):
    return (
        cand["rms"] <= comp["rms"] + 1.0e-12
        and cand["mae"] <= comp["mae"] + 1.0e-12
        and cand["sign_mismatch"] <= comp["sign_mismatch"]
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b4-result", required=True, type=pathlib.Path)
    ap.add_argument("--b5-result", required=True, type=pathlib.Path)
    ap.add_argument("--b6-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    r4 = json.loads(args.b4_result.read_text())
    r5 = json.loads(args.b5_result.read_text())
    r6 = json.loads(args.b6_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_TERMINAL_STORAGE_SHAPE_RECONSTRUCTION_DIAGNOSTIC"
    assert r4["decision"] == pre["predecessors"]["required_B4_decision"]
    assert r5["decision"] == pre["predecessors"]["required_B5_decision"]
    assert r6["decision"] == pre["predecessors"]["required_B6_decision"]

    init_meta, init_nodes, states, nodes = b3.load_reference(args.reference)

    rows = []
    failures = []
    max_root = 0.0
    max_q_cross = 0.0
    max_hydro = 0.0

    for d in WIDTHS:
        Weq = b5.storage_for_slope(1.0, d, 64)
        ah, rh = b5.solve_slope(Weq, d, 64)
        max_hydro = max(max_hydro, abs(ah - 1.0), abs(rh))

    for hist, nsteps in b3.HISTORY_STEPS.items():
        pp = init_nodes[hist]
        pt = init_meta[hist]["total"]
        try:
            prev = endpoint(pp, pt)
        except ValueError as exc:
            failures.append({"history": hist, "step": 0, "error": str(exc)})
            continue

        for step in range(1, nsteps + 1):
            p = nodes[(hist, step)]
            total = states[(hist, step)]["total"]
            try:
                cur = endpoint(p, total)
            except ValueError as exc:
                failures.append({"history": hist, "step": step, "error": str(exc)})
                break

            hdot = (cur["H"] - prev["H"]) / b3.OBS_DT
            row = {
                "history": hist,
                "step": step,
                "direction": direction(hdot),
                "qref": states[(hist, step)]["bottom_exchange"] / b3.OBS_DT,
                "MOVING_LAYER_AVERAGE": 0.5 * (prev["MOVING_LAYER_AVERAGE"] + cur["MOVING_LAYER_AVERAGE"]),
                "LINEAR_STORAGE": 0.5 * (prev["LINEAR_STORAGE"] + cur["LINEAR_STORAGE"]),
                "POINT_2_5CM": 0.5 * (prev["POINT_2_5CM"] + cur["POINT_2_5CM"]),
            }

            for d in WIDTHS:
                suffix = str(d).replace(".", "_")
                naive_name = f"TERMINAL_AVERAGE_{suffix}CM"
                cand_name = f"TERM_LINEAR_{suffix}CM"
                a0 = prev["bands"][d]
                a1 = cur["bands"][d]
                row[naive_name] = 0.5 * (a0["TERMINAL_AVERAGE"] + a1["TERMINAL_AVERAGE"])
                row[cand_name] = 0.5 * (a0["LOCAL_LINEAR_64"]["qH"] + a1["LOCAL_LINEAR_64"]["qH"])
                row[cand_name + "_a"] = 0.5 * (a0["LOCAL_LINEAR_64"]["a"] + a1["LOCAL_LINEAR_64"]["a"])

                for ep in (a0, a1):
                    max_root = max(
                        max_root,
                        abs(ep["LOCAL_LINEAR_64"]["root_residual"]),
                        abs(ep["LOCAL_LINEAR_128"]["root_residual"]),
                    )
                    max_q_cross = max(
                        max_q_cross,
                        abs(ep["LOCAL_LINEAR_64"]["qH"] - ep["LOCAL_LINEAR_128"]["qH"]),
                    )

            rows.append(row)
            prev = cur
            pp, pt = p, total

    expected = sum(b3.HISTORY_STEPS.values())
    names = ["MOVING_LAYER_AVERAGE", "LINEAR_STORAGE", "POINT_2_5CM"]
    for d in WIDTHS:
        suffix = str(d).replace(".", "_")
        names.extend([f"TERMINAL_AVERAGE_{suffix}CM", f"TERM_LINEAR_{suffix}CM"])

    complete = len(rows) == expected and not failures
    hard_ok = (
        complete
        and max_root <= ROOT_GATE
        and max_q_cross <= Q_CROSS_GATE
        and max_hydro <= HYDRO_GATE
        and all(math.isfinite(r[k]) for r in rows for k in names)
    )

    report = {"by_direction": {}, "by_history": {}}
    for axis, groups in (
        ("by_direction", ["HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"]),
        ("by_history", list(b3.HISTORY_STEPS)),
    ):
        for group in groups:
            rr = [r for r in rows if (r["direction"] == group if axis == "by_direction" else r["history"] == group)]
            report[axis][group] = {name: metrics(rr, name) for name in names}

    support = {}
    supported = []
    for d in WIDTHS:
        suffix = str(d).replace(".", "_")
        cand_name = f"TERM_LINEAR_{suffix}CM"
        naive_name = f"TERMINAL_AVERAGE_{suffix}CM"
        moving_support = {}
        moving_recovery = {}
        for g in ("WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
            cand = report["by_direction"][g][cand_name]
            std = report["by_direction"][g]["MOVING_LAYER_AVERAGE"]
            global_linear = report["by_direction"][g]["LINEAR_STORAGE"]
            naive = report["by_direction"][g][naive_name]
            moving_support[g] = strictly_better(cand, std) and strictly_better(cand, global_linear)
            moving_recovery[g] = strictly_better(cand, naive)

        hold_cand = report["by_direction"]["HOLD"][cand_name]
        hold_global = report["by_direction"]["HOLD"]["LINEAR_STORAGE"]
        hold_naive = report["by_direction"]["HOLD"][naive_name]
        hold_ok = noninferior(hold_cand, hold_global)
        hold_recovery = strictly_better(hold_cand, hold_naive)

        support[cand_name] = {
            "WATER_TABLE_RISING": moving_support["WATER_TABLE_RISING"],
            "WATER_TABLE_FALLING": moving_support["WATER_TABLE_FALLING"],
            "HOLD_NONINFERIOR_TO_GLOBAL_B5": hold_ok,
            "B6_RECOVERY_RISING": moving_recovery["WATER_TABLE_RISING"],
            "B6_RECOVERY_FALLING": moving_recovery["WATER_TABLE_FALLING"],
            "B6_RECOVERY_HOLD": hold_recovery,
        }
        if (
            all(moving_support.values())
            and hold_ok
            and all(moving_recovery.values())
            and hold_recovery
        ):
            supported.append(cand_name)

    preferred = []
    for name in supported:
        ok = True
        for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
            pool = [report["by_direction"][g][n] for n in supported]
            cur = report["by_direction"][g][name]
            min_rms = min(x["rms"] for x in pool)
            min_mae = min(x["mae"] for x in pool)
            ok &= cur["rms"] <= min_rms + 1.0e-12 and cur["mae"] <= min_mae + 1.0e-12
        if ok:
            preferred.append(name)

    direction_dependent = any(
        v["WATER_TABLE_RISING"] != v["WATER_TABLE_FALLING"]
        for v in support.values()
    )

    if not hard_ok:
        decision = "BC2_B7_TERMINAL_STORAGE_SHAPE_BLOCKED"
    elif supported and preferred:
        decision = "BC2_B7_TERMINAL_STORAGE_SHAPE_SUPPORTED"
    elif supported:
        decision = "BC2_B7_TERMINAL_STORAGE_SHAPE_SUPPORTED_WIDTH_UNRESOLVED"
    elif direction_dependent:
        decision = "BC2_B7_TERMINAL_STORAGE_SHAPE_DIRECTION_DEPENDENT"
    else:
        decision = "BC2_B7_TERMINAL_STORAGE_SHAPE_NOT_SUPPORTED"

    point_gap = {}
    for d in WIDTHS:
        suffix = str(d).replace(".", "_")
        name = f"TERM_LINEAR_{suffix}CM"
        point_gap[name] = {}
        for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
            cand = report["by_direction"][g][name]
            point = report["by_direction"][g]["POINT_2_5CM"]
            point_gap[name][g] = {
                "rms_excess_cm_per_day": cand["rms"] - point["rms"],
                "mae_excess_cm_per_day": cand["mae"] - point["mae"],
                "sign_mismatch_excess": cand["sign_mismatch"] - point["sign_mismatch"],
            }

    result = {
        "schema": "swap5.lare.bc2.b7.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-B7",
        "decision": decision,
        "complete": complete,
        "hard_checks": {
            "max_abs_shape_root_storage_residual_cm": max_root,
            "root_storage_residual_gate_cm": ROOT_GATE,
            "max_abs_qH_64_vs_128_cm_per_day": max_q_cross,
            "qH_crosscheck_gate_cm_per_day": Q_CROSS_GATE,
            "max_hydrostatic_slope_or_storage_residual": max_hydro,
            "hydrostatic_slope_gate": HYDRO_GATE,
            "failure_count": len(failures),
        },
        "support": support,
        "supported_candidates": supported,
        "preferred_candidate": preferred,
        "point_2_5cm_information_gap": point_gap,
        "failures": failures[:20],
        **report,
        "interpretation": [
            "B7 uses exactly the B6 terminal storage state and changes only the state-to-gradient reconstruction.",
            "No local full-order pressure head enters TERM_LINEAR; POINT_2_5CM remains diagnostic context only.",
            "Hydrostatic terminal storage maps to a_t=1 and qH=0 by construction.",
            "Positive operator support would justify deriving a prognostic conservation law for Wt, not immediate production dynamics."
        ],
        "added_state_dimension": 1,
        "propagated_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "support": support,
        "supported_candidates": supported,
        "preferred_candidate": preferred,
        "by_direction": report["by_direction"]
    }, sort_keys=True))
    return 0 if hard_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
