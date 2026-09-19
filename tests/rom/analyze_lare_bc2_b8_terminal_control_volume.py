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
b6 = load_module("bc2b6", "analyze_lare_bc2_b6_terminal_storage.py")

WIDTHS = (2.5, 5.0)
DT = b3.OBS_DT
STORAGE_GATE = 1.0e-10
QI_GATE = 1.0e-10


def theta_interface(profile, H, d):
    h = float(b6.sample_h_array(profile, H - d))
    if h > 1.0e-9:
        raise ValueError("terminal top interface is below zero-pressure crossing")
    psi = -h
    if psi < -1.0e-9:
        raise ValueError("negative suction at terminal top interface")
    return float(b3.theta_from_psi(psi))


def projected(profile, total, d):
    H, storage, _ = b3.project(profile, total)
    Wm = float(storage[b3.NFIXED])
    Wt64 = b6.terminal_storage(profile, H, d, 64)
    Wt128 = b6.terminal_storage(profile, H, d, 128)
    Wb64 = Wm - Wt64
    return {
        "H": H,
        "Wfixed": float(np.sum(storage[:b3.NFIXED])),
        "Wm": Wm,
        "Wt64": Wt64,
        "Wt128": Wt128,
        "Wb64": Wb64,
        "theta_i": theta_interface(profile, H, d),
        "split_closure": (Wb64 + Wt64) - Wm,
    }


def direction(Hdot):
    if Hdot < -b3.HDOT_EPS:
        return "WATER_TABLE_RISING"
    if Hdot > b3.HDOT_EPS:
        return "WATER_TABLE_FALLING"
    return "HOLD"


def scalar_stats(values):
    a = np.asarray(values, dtype=float)
    return {
        "count": int(len(a)),
        "min": float(np.min(a)),
        "mean": float(np.mean(a)),
        "max": float(np.max(a)),
        "rms": float(np.sqrt(np.mean(a * a))),
    }


def qi_stats(rows):
    qi = np.asarray([r["qi"] for r in rows], dtype=float)
    return {
        "count": int(len(qi)),
        "min_cm_per_day": float(np.min(qi)),
        "mean_cm_per_day": float(np.mean(qi)),
        "max_cm_per_day": float(np.max(qi)),
        "rms_cm_per_day": float(np.sqrt(np.mean(qi * qi))),
        "sign_change_count": int(np.count_nonzero(np.sign(qi[1:]) != np.sign(qi[:-1]))) if len(qi) > 1 else 0,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b7-result", required=True, type=pathlib.Path)
    ap.add_argument("--a2-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    r7 = json.loads(args.b7_result.read_text())
    a2 = json.loads(args.a2_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_TERMINAL_BAND_MOVING_CONTROL_VOLUME_AUDIT"
    assert r7["decision"] == pre["predecessors"]["required_B7_decision"]
    assert a2["decision"] == pre["predecessors"]["required_A2_decision"]

    init_meta, init_nodes, states, nodes = b3.load_reference(args.reference)

    rows_by_width = {d: [] for d in WIDTHS}
    failures = []
    max_split = 0.0
    max_quad = 0.0
    max_qi_identity = 0.0
    max_total_ledger = 0.0

    for history, nsteps in b3.HISTORY_STEPS.items():
        prev = {}
        for d in WIDTHS:
            try:
                prev[d] = projected(init_nodes[history], init_meta[history]["total"], d)
            except ValueError as exc:
                failures.append({"history": history, "step": 0, "width_cm": d, "error": str(exc)})

        if len(prev) != len(WIDTHS):
            continue

        for step in range(1, nsteps + 1):
            cur = {}
            bad = False
            for d in WIDTHS:
                try:
                    cur[d] = projected(nodes[(history, step)], states[(history, step)]["total"], d)
                except ValueError as exc:
                    failures.append({"history": history, "step": step, "width_cm": d, "error": str(exc)})
                    bad = True
            if bad:
                break

            qH = states[(history, step)]["bottom_exchange"] / DT

            # q90 is independently diagnosed from the fixed 0..90 cm column,
            # identical to the already qualified BC2-B3 Reference identity.
            q90 = -(cur[WIDTHS[0]]["Wfixed"] - prev[WIDTHS[0]]["Wfixed"]) / DT
            Hdot = (cur[WIDTHS[0]]["H"] - prev[WIDTHS[0]]["H"]) / DT

            # Total moving-layer identity, independent of terminal split width.
            total_tendency = (cur[WIDTHS[0]]["Wm"] - prev[WIDTHS[0]]["Wm"]) / DT
            total_ledger = total_tendency - (q90 - qH + b3.THETA_S * Hdot)
            max_total_ledger = max(max_total_ledger, abs(total_ledger))

            for d in WIDTHS:
                p0 = prev[d]
                p1 = cur[d]
                Gi = 0.5 * (p0["theta_i"] + p1["theta_i"]) * Hdot
                dWb = (p1["Wb64"] - p0["Wb64"]) / DT
                dWt = (p1["Wt64"] - p0["Wt64"]) / DT

                qi_bulk = q90 + Gi - dWb
                qi_terminal = dWt + qH - b3.THETA_S * Hdot + Gi
                qi = 0.5 * (qi_bulk + qi_terminal)
                residual = qi_bulk - qi_terminal

                max_qi_identity = max(max_qi_identity, abs(residual))
                max_split = max(max_split, abs(p0["split_closure"]), abs(p1["split_closure"]))
                max_quad = max(
                    max_quad,
                    abs(p0["Wt64"] - p0["Wt128"]),
                    abs(p1["Wt64"] - p1["Wt128"]),
                )

                rows_by_width[d].append({
                    "history": history,
                    "step": step,
                    "direction": direction(Hdot),
                    "H": p1["H"],
                    "Hdot": Hdot,
                    "theta_i": 0.5 * (p0["theta_i"] + p1["theta_i"]),
                    "Gi": Gi,
                    "q90": q90,
                    "qH": qH,
                    "qi_bulk": qi_bulk,
                    "qi_terminal": qi_terminal,
                    "qi": qi,
                    "qi_identity_residual": residual,
                    "total_moving_ledger_residual": total_ledger,
                })

            prev = cur

    expected = sum(b3.HISTORY_STEPS.values())
    complete = (
        not failures
        and all(len(rows_by_width[d]) == expected for d in WIDTHS)
    )
    finite = all(
        math.isfinite(row[key])
        for d in WIDTHS
        for row in rows_by_width[d]
        for key in ("H", "Hdot", "theta_i", "Gi", "q90", "qH", "qi_bulk", "qi_terminal", "qi")
    )
    hard_ok = (
        complete
        and finite
        and max_split <= STORAGE_GATE
        and max_quad <= STORAGE_GATE
        and max_qi_identity <= QI_GATE
    )

    report = {}
    for d in WIDTHS:
        report[str(d)] = {"by_direction": {}, "by_history": {}}
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
                    "qi": qi_stats(rr),
                    "Gi_cm_per_day": scalar_stats([r["Gi"] for r in rr]),
                    "theta_i": scalar_stats([r["theta_i"] for r in rr]),
                    "H_cm": scalar_stats([r["H"] for r in rr]),
                    "Hdot_cm_per_day": scalar_stats([r["Hdot"] for r in rr]),
                    "max_abs_qi_identity_residual_cm_per_day": float(max(abs(r["qi_identity_residual"]) for r in rr)),
                }

    # The width difference is diagnostic only; conservation must not select d.
    common = zip(rows_by_width[2.5], rows_by_width[5.0])
    width_diff = [
        abs(a["qi"] - b["qi"])
        for a, b in common
    ]

    qualified_widths = []
    if hard_ok:
        qualified_widths = [2.5, 5.0]

    if not hard_ok:
        decision = "BC2_B8_TERMINAL_MOVING_CONTROL_VOLUME_BLOCKED"
    elif len(qualified_widths) == len(WIDTHS):
        decision = "BC2_B8_TERMINAL_MOVING_CONTROL_VOLUME_QUALIFIED"
    else:
        decision = "BC2_B8_WIDTH_SPECIFIC_GEOMETRY_QUALIFICATION"

    result = {
        "schema": "swap5.lare.bc2.b8.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-B8",
        "decision": decision,
        "complete": complete,
        "hard_checks": {
            "all_terms_finite": finite,
            "max_abs_Wb_plus_Wt_minus_Wm_cm": max_split,
            "storage_gate_cm": STORAGE_GATE,
            "max_abs_terminal_storage_64_vs_128_cm": max_quad,
            "quadrature_gate_cm": STORAGE_GATE,
            "max_abs_qi_bulk_minus_terminal_cm_per_day": max_qi_identity,
            "qi_identity_gate_cm_per_day": QI_GATE,
            "max_abs_total_moving_ledger_residual_cm_per_day": max_total_ledger,
            "failure_count": len(failures),
        },
        "qualified_widths_cm": qualified_widths,
        "width_to_width_qi_difference": {
            "max_abs_cm_per_day": float(max(width_diff)) if width_diff else None,
            "mean_abs_cm_per_day": float(np.mean(width_diff)) if width_diff else None,
            "rms_cm_per_day": float(np.sqrt(np.mean(np.square(width_diff)))) if width_diff else None,
        },
        "widths": report,
        "failures": failures[:20],
        "interpretation": [
            "The terminal and bulk balances independently reconstruct the same internal moving-interface flux qi up to the already-qualified total moving-volume ledger residual.",
            "The reference theta_i enters only the geometry-transfer diagnostic Gi; no qi closure is proposed in B8.",
            "Both B7-supported widths are evaluated identically and conservation is not used to choose between them.",
            "Qualification authorizes only a later response-blind qi-closure diagnostic, not propagated reduced dynamics."
        ],
        "interface_flux_closure_authorized": False,
        "propagated_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "qualified_widths_cm": qualified_widths,
        "width_to_width_qi_difference": result["width_to_width_qi_difference"],
    }, sort_keys=True))
    return 0 if hard_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
