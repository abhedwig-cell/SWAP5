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

b0 = load_module("bc2b0", "run_lare_bc2_b0_prescribed_geometry.py")
b3 = load_module("bc2b3", "analyze_lare_bc2_b3_operator_attribution.py")
b5 = load_module("bc2b5", "analyze_lare_bc2_b5_storage_linear_qh.py")
b6 = load_module("bc2b6", "analyze_lare_bc2_b6_terminal_storage.py")
b8 = load_module("bc2b8", "analyze_lare_bc2_b8_terminal_control_volume.py")

WIDTHS = (2.5, 5.0)
NFIXED = b0.NFIXED
FIXED_DZ = b0.FIXED_DZ
ANCHOR = b0.ANCHOR
PROFILE_DEPTH = b0.PROFILE_DEPTH
OBS_DT = b0.OBS_DT
HEUN_DT = b0.HEUN_DT
THETA_R = b0.THETA_R
THETA_S = b0.THETA_S
KS = b0.KS
CORRECTOR_TOL = b0.CORRECTOR_TOL
MAX_CORRECTOR = b0.MAX_CORRECTOR
LEDGER_GATE = b0.LEDGER_GATE
HISTORY_STEPS = b0.HISTORY_STEPS

IDX_WB = NFIXED
IDX_WT = NFIXED + 1
IDX_CUM_QH = NFIXED + 2
IDX_CUM_QI = NFIXED + 3
NSTATE = NFIXED + 4


def hydraulic_state(y: np.ndarray, H: float, d: float):
    B = H - ANCHOR - d
    if B <= 0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    fixed_theta = y[:NFIXED] / FIXED_DZ
    theta_b = y[IDX_WB] / B
    theta_t_mean = y[IDX_WT] / d
    all_mean = np.concatenate([fixed_theta, [theta_b, theta_t_mean]])
    b0.psi_k(all_mean)

    a_t, root_res = b5.solve_slope(float(y[IDX_WT]), d, 64)
    if abs(root_res) > 1.0e-10:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN terminal root residual")
    psi_i = a_t * d
    theta_i = float(b3.theta_from_psi(psi_i))
    _, Ki_arr = b3.psi_k(np.asarray([theta_i], dtype=float))
    Ki = float(Ki_arr[0])
    if not (THETA_R < theta_i < THETA_S):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN reconstructed interface theta")
    return {
        "B": B,
        "fixed_theta": fixed_theta,
        "theta_b": theta_b,
        "theta_t_mean": theta_t_mean,
        "a_t": a_t,
        "psi_i": psi_i,
        "theta_i": theta_i,
        "Ki": Ki,
    }


def rhs(y: np.ndarray, H: float, Hdot: float, d: float):
    hs = hydraulic_state(y, H, d)
    fixed_theta = hs["fixed_theta"]
    theta_b = hs["theta_b"]

    theta_for_q90 = np.concatenate([fixed_theta, [theta_b]])
    psi, kval = b0.psi_k(theta_for_q90)

    qff = np.empty(NFIXED - 1, dtype=float)
    for i in range(NFIXED - 1):
        kij = 0.5 * (kval[i] + kval[i + 1])
        qff[i] = kij * (1.0 + (psi[i + 1] - psi[i]) / FIXED_DZ)

    B = hs["B"]
    Kfixed = float(kval[NFIXED - 1])
    Kbulk = float(kval[NFIXED])
    psi_fixed = float(psi[NFIXED - 1])
    psi_bulk = float(psi[NFIXED])
    K90 = (B * Kfixed + FIXED_DZ * Kbulk) / (FIXED_DZ + B)
    q90 = K90 * (1.0 + 2.0 * (psi_bulk - psi_fixed) / (FIXED_DZ + B))

    q_i = hs["Ki"] * (1.0 - hs["a_t"])
    q_H = KS * (1.0 - hs["a_t"])

    dy = np.zeros(NSTATE, dtype=float)
    dy[0] = -qff[0]
    for i in range(1, NFIXED - 1):
        dy[i] = qff[i - 1] - qff[i]
    dy[NFIXED - 1] = qff[NFIXED - 2] - q90
    dy[IDX_WB] = q90 - q_i + hs["theta_i"] * Hdot
    dy[IDX_WT] = q_i - q_H + (THETA_S - hs["theta_i"]) * Hdot
    dy[IDX_CUM_QH] = q_H
    dy[IDX_CUM_QI] = q_i
    return dy, {"q90": q90, "qi": q_i, "qH": q_H, **hs}


def convergence_vector(y: np.ndarray, H: float, d: float):
    hs = hydraulic_state(y, H, d)
    # C0 inherits B0's theta-based Heun corrector criterion. The reconstructed
    # terminal slope a_t is a deterministic diagnostic/closure quantity, not
    # an independent prognostic state and therefore is not part of the
    # corrector convergence norm.
    return np.concatenate([
        hs["fixed_theta"],
        [hs["theta_b"], hs["theta_t_mean"]],
    ])


def heun_step(y, dt, H0, H1, Hdot, d):
    f0, _ = rhs(y, H0, Hdot, d)
    guess = y + dt * f0
    for iteration in range(1, MAX_CORRECTOR + 1):
        f1, _ = rhs(guess, H1, Hdot, d)
        nxt = y + 0.5 * dt * (f0 + f1)
        old = convergence_vector(guess, H1, d)
        new = convergence_vector(nxt, H1, d)
        if np.max(np.abs(new - old)) <= CORRECTOR_TOL:
            return nxt, iteration
        guess = nxt
    raise RuntimeError("NUMERICAL_BLOCKED iterative Heun corrector")


def initial_state(history, d, init_meta, init_nodes):
    profile = init_nodes[history]
    H0 = b0.diagnose_H(profile)
    fixed = np.asarray(
        [profile[i]["theta"] * FIXED_DZ for i in range(1, NFIXED + 1)],
        dtype=float,
    )
    U0 = init_meta[history]["total"] - THETA_S * (PROFILE_DEPTH - H0)
    Wm = U0 - float(np.sum(fixed))
    Wt = b6.terminal_storage(profile, H0, d, 64)
    Wb = Wm - Wt
    y = np.zeros(NSTATE, dtype=float)
    y[:NFIXED] = fixed
    y[IDX_WB] = Wb
    y[IDX_WT] = Wt
    y[IDX_CUM_QH] = 0.0
    y[IDX_CUM_QI] = 0.0
    hydraulic_state(y, H0, d)
    return y, H0, U0


def reference_projection(history, step, d, states, nodes):
    profile = nodes[(history, step)]
    total = states[(history, step)]["total"]
    p = b8.projected(profile, total, d)
    U = total - THETA_S * (PROFILE_DEPTH - p["H"])
    fixed = np.asarray(
        [profile[i]["theta"] * FIXED_DZ for i in range(1, NFIXED + 1)],
        dtype=float,
    )
    return p, U, fixed


def initial_reference_projection(history, d, init_meta, init_nodes):
    profile = init_nodes[history]
    p = b8.projected(profile, init_meta[history]["total"], d)
    U = init_meta[history]["total"] - THETA_S * (PROFILE_DEPTH - p["H"])
    fixed = np.asarray(
        [profile[i]["theta"] * FIXED_DZ for i in range(1, NFIXED + 1)],
        dtype=float,
    )
    return p, U, fixed


def reversals(values):
    out = []
    prev = 0
    for step, value in enumerate(values, 1):
        s = 1 if value > 0.0 else -1 if value < 0.0 else 0
        if s == 0:
            continue
        if prev and s != prev:
            out.append(step)
        prev = s
    return out


def solve(history, d, dt, init_meta, init_nodes, states, nodes):
    ratio = OBS_DT / dt
    nsub = int(round(ratio))
    if nsub <= 0 or abs(ratio - nsub) > 1.0e-12:
        raise RuntimeError("dt does not divide observation interval")

    y, Hprev, U0 = initial_state(history, d, init_meta, init_nodes)
    Hinitial = Hprev
    prev_ref, _, _ = initial_reference_projection(history, d, init_meta, init_nodes)
    max_ledger = 0.0
    max_corrector = 0
    cum_ref_qH = 0.0
    rows = []
    qH_candidate = []
    qH_reference = []

    for step in range(1, HISTORY_STEPS[history] + 1):
        ref, Uref, fixed_ref = reference_projection(history, step, d, states, nodes)
        Hend = ref["H"]
        Hdot = (Hend - Hprev) / OBS_DT
        cum_qH_start = float(y[IDX_CUM_QH])
        cum_qi_start = float(y[IDX_CUM_QI])

        for sub in range(nsub):
            fa = sub / nsub
            fb = (sub + 1) / nsub
            Ha = Hprev + (Hend - Hprev) * fa
            Hb = Hprev + (Hend - Hprev) * fb
            y, iterations = heun_step(y, dt, Ha, Hb, Hdot, d)
            max_corrector = max(max_corrector, iterations)

        hs = hydraulic_state(y, Hend, d)
        U = float(np.sum(y[:NFIXED])) + float(y[IDX_WB]) + float(y[IDX_WT])
        cum_qH = float(y[IDX_CUM_QH])
        cum_qi = float(y[IDX_CUM_QI])
        bex = states[(history, step)]["bottom_exchange"]
        cum_ref_qH += bex
        qH_interval = (cum_qH - cum_qH_start) / OBS_DT
        qH_ref = bex / OBS_DT
        qi_interval = (cum_qi - cum_qi_start) / OBS_DT

        q90_ref = -(ref["Wfixed"] - prev_ref["Wfixed"]) / OBS_DT
        Gi_ref = 0.5 * (prev_ref["theta_i"] + ref["theta_i"]) * Hdot
        dWb_ref = (ref["Wb64"] - prev_ref["Wb64"]) / OBS_DT
        dWt_ref = (ref["Wt64"] - prev_ref["Wt64"]) / OBS_DT
        qi_bulk_ref = q90_ref + Gi_ref - dWb_ref
        qi_term_ref = dWt_ref + qH_ref - THETA_S * Hdot + Gi_ref
        qi_ref = 0.5 * (qi_bulk_ref + qi_term_ref)

        physical_ledger = U - U0 + cum_qH - THETA_S * (Hend - Hinitial)
        max_ledger = max(max_ledger, abs(physical_ledger))

        rows.append({
            "step": step,
            "H_cm": Hend,
            "fixed_storage_error_cm": (y[:NFIXED] - fixed_ref).tolist(),
            "Wb_error_cm": float(y[IDX_WB]) - ref["Wb64"],
            "Wt_error_cm": float(y[IDX_WT]) - ref["Wt64"],
            "total_unsaturated_storage_error_cm": U - Uref,
            "cumulative_qH_error_cm": cum_qH - cum_ref_qH,
            "interval_qH_error_cm_per_day": qH_interval - qH_ref,
            "interval_qi_error_cm_per_day": qi_interval - qi_ref,
            "qH_candidate_cm_per_day": qH_interval,
            "qH_reference_cm_per_day": qH_ref,
            "qi_candidate_cm_per_day": qi_interval,
            "qi_reference_cm_per_day": qi_ref,
            "physical_ledger_residual_cm": physical_ledger,
            "theta_b": hs["theta_b"],
            "theta_t_mean": hs["theta_t_mean"],
            "a_t": hs["a_t"],
        })
        qH_candidate.append(qH_interval)
        qH_reference.append(qH_ref)
        Hprev = Hend
        prev_ref = ref

    fixed_errors = np.asarray([r["fixed_storage_error_cm"] for r in rows], dtype=float)
    Wb_errors = np.asarray([r["Wb_error_cm"] for r in rows], dtype=float)
    Wt_errors = np.asarray([r["Wt_error_cm"] for r in rows], dtype=float)
    total_errors = np.asarray([r["total_unsaturated_storage_error_cm"] for r in rows], dtype=float)
    cum_errors = np.asarray([r["cumulative_qH_error_cm"] for r in rows], dtype=float)
    qH_errors = np.asarray([r["interval_qH_error_cm_per_day"] for r in rows], dtype=float)
    qi_errors = np.asarray([r["interval_qi_error_cm_per_day"] for r in rows], dtype=float)
    crev = reversals(qH_candidate)
    rrev = reversals(qH_reference)
    rev_match = len(crev) == len(rrev)
    max_rev = None if not rev_match else max([abs(a - b) for a, b in zip(crev, rrev)] or [0])

    return {
        "status": "QUALIFIED",
        "dt_day": dt,
        "max_abs_fixed_layer_storage_error_cm": float(np.max(np.abs(fixed_errors))),
        "max_abs_Wb_error_cm": float(np.max(np.abs(Wb_errors))),
        "max_abs_Wt_error_cm": float(np.max(np.abs(Wt_errors))),
        "max_abs_total_unsaturated_storage_error_cm": float(np.max(np.abs(total_errors))),
        "max_abs_cumulative_qH_error_cm": float(np.max(np.abs(cum_errors))),
        "final_signed_cumulative_qH_error_cm": float(cum_errors[-1]),
        "max_abs_interval_qH_error_cm_per_day": float(np.max(np.abs(qH_errors))),
        "max_abs_interval_qi_error_cm_per_day": float(np.max(np.abs(qi_errors))),
        "qH_sign_mismatch_count": int(np.count_nonzero(np.sign(qH_candidate) != np.sign(qH_reference))),
        "candidate_reversal_steps": crev,
        "reference_reversal_steps": rrev,
        "reversal_sequence_length_match": rev_match,
        "max_reversal_step_difference": max_rev,
        "max_reversal_time_difference_minutes": None if max_rev is None else max_rev * OBS_DT * 24.0 * 60.0,
        "max_abs_physical_moving_ledger_residual_cm": max_ledger,
        "max_corrector_iterations": max_corrector,
        "theta_b_range": [float(min(r["theta_b"] for r in rows)), float(max(r["theta_b"] for r in rows))],
        "theta_t_mean_range": [float(min(r["theta_t_mean"] for r in rows)), float(max(r["theta_t_mean"] for r in rows))],
        "a_t_range": [float(min(r["a_t"] for r in rows)), float(max(r["a_t"] for r in rows))],
        "trajectory": rows,
    }


def numerical_floor(coarse, fine):
    def arr(key, row):
        return np.asarray([r[key] for r in row["trajectory"]], dtype=float)
    metrics = {}
    for key, label in (
        ("Wb_error_cm", "Wb_cm"),
        ("Wt_error_cm", "Wt_cm"),
        ("total_unsaturated_storage_error_cm", "total_unsaturated_storage_cm"),
        ("cumulative_qH_error_cm", "cumulative_qH_cm"),
        ("interval_qH_error_cm_per_day", "interval_qH_cm_per_day"),
        ("interval_qi_error_cm_per_day", "interval_qi_cm_per_day"),
    ):
        metrics["max_abs_" + label + "_difference"] = float(np.max(np.abs(arr(key, coarse) - arr(key, fine))))
    return metrics


def compact(run):
    if run is None:
        return None
    return {k: v for k, v in run.items() if k != "trajectory"}


def no_worse(candidate, baseline):
    tol = 1.0e-12
    comps = {
        "total": candidate["max_abs_total_unsaturated_storage_error_cm"] <= baseline["max_total_unsat_error_cm"] + tol,
        "cum_qH": candidate["max_abs_cumulative_qH_error_cm"] <= baseline["max_cum_qH_error_cm"] + tol,
        "interval_qH": candidate["max_abs_interval_qH_error_cm_per_day"] <= baseline["max_interval_qH_error_cm_per_day"] + tol,
        "sign": candidate["qH_sign_mismatch_count"] <= baseline["sign_mismatch_count"],
    }
    strict = (
        candidate["max_abs_total_unsaturated_storage_error_cm"] < baseline["max_total_unsat_error_cm"] - tol
        or candidate["max_abs_cumulative_qH_error_cm"] < baseline["max_cum_qH_error_cm"] - tol
        or candidate["max_abs_interval_qH_error_cm_per_day"] < baseline["max_interval_qH_error_cm_per_day"] - tol
    )
    return comps, strict


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b0-result", required=True, type=pathlib.Path)
    ap.add_argument("--b7-result", required=True, type=pathlib.Path)
    ap.add_argument("--b8-result", required=True, type=pathlib.Path)
    ap.add_argument("--b9-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    r0 = json.loads(args.b0_result.read_text())
    r7 = json.loads(args.b7_result.read_text())
    r8 = json.loads(args.b8_result.read_text())
    r9 = json.loads(args.b9_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_ENRICHED_PRESCRIBED_H_DYNAMICS"
    assert r0["decision"] == pre["predecessors"]["required_B0_decision"]
    assert r7["decision"] == pre["predecessors"]["required_B7_decision"]
    assert r8["decision"] == pre["predecessors"]["required_B8_decision"]
    assert r9["decision"] == pre["predecessors"]["required_B9_decision"]
    assert r9["preferred_operator"] == ["TERMINAL_SIDE_LINEAR"]

    init_meta, init_nodes, states, nodes = b0.load_reference(args.reference)
    cases = {}
    for d in WIDTHS:
        for history in HISTORY_STEPS:
            refinements = {}
            failures = {}
            for dt in HEUN_DT:
                key = f"{dt:.7f}"
                try:
                    refinements[key] = solve(history, d, dt, init_meta, init_nodes, states, nodes)
                except ValueError as exc:
                    failures[key] = f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError, FloatingPointError) as exc:
                    failures[key] = f"NUMERICAL_BLOCKED: {exc}"
            fine = refinements.get("0.0001000")
            coarse = refinements.get("0.0002000")
            if fine is not None:
                status = "QUALIFIED"
            elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000", ""):
                status = "OUTSIDE_QUALIFIED_DOMAIN"
            else:
                status = "NUMERICAL_BLOCKED"
            floor = numerical_floor(coarse, fine) if coarse is not None and fine is not None else None
            cases[(d, history)] = {
                "status": status,
                "fine": fine,
                "coarse": coarse,
                "numerical_floor": floor,
                "failures": failures,
            }

    baseline = pre["baseline_comparison"]["B0_metrics"]
    support = {}
    supported = []
    for d in WIDTHS:
        support[str(d)] = {}
        width_ok = True
        for history in HISTORY_STEPS:
            row = cases[(d, history)]
            if row["status"] != "QUALIFIED" or row["numerical_floor"] is None:
                support[str(d)][history] = {"qualified": False}
                width_ok = False
                continue
            fine = row["fine"]
            base = baseline[history]
            comps, strict = no_worse(fine, base)
            history_ok = all(comps.values()) and (strict if history != "WT_HOLD" else True)
            support[str(d)][history] = {
                "qualified": True,
                "component_noninferiority_vs_B0": comps,
                "strict_magnitude_improvement": strict,
                "progression_pass": history_ok,
            }
            width_ok &= history_ok
        if width_ok:
            supported.append(d)

    preferred = []
    if supported:
        for d in supported:
            other_widths = [x for x in supported if x != d]
            if not other_widths:
                preferred.append(d)
                continue
            ok = True
            strict_any = False
            for other in other_widths:
                for history in HISTORY_STEPS:
                    a = cases[(d, history)]["fine"]
                    b = cases[(other, history)]["fine"]
                    for key in (
                        "max_abs_fixed_layer_storage_error_cm",
                        "max_abs_Wb_error_cm",
                        "max_abs_Wt_error_cm",
                        "max_abs_total_unsaturated_storage_error_cm",
                        "max_abs_cumulative_qH_error_cm",
                        "max_abs_interval_qH_error_cm_per_day",
                        "max_abs_interval_qi_error_cm_per_day",
                        "qH_sign_mismatch_count",
                    ):
                        av, bv = a[key], b[key]
                        ok &= av <= bv + 1.0e-12
                        strict_any |= av < bv - 1.0e-12
            if ok and strict_any:
                preferred.append(d)

    all_status = [cases[(d, h)]["status"] for d in WIDTHS for h in HISTORY_STEPS]
    all_ledgers = [
        cases[(d, h)]["fine"]["max_abs_physical_moving_ledger_residual_cm"]
        for d in WIDTHS for h in HISTORY_STEPS
        if cases[(d, h)]["fine"] is not None
    ]
    ledger_ok = bool(all_ledgers) and max(all_ledgers) <= LEDGER_GATE

    if any(s == "NUMERICAL_BLOCKED" for s in all_status):
        decision = "BC2_C0_ENRICHED_DYNAMICS_NUMERICALLY_BLOCKED"
    elif any(s == "OUTSIDE_QUALIFIED_DOMAIN" for s in all_status):
        decision = "BC2_C0_ENRICHED_DYNAMICS_OUTSIDE_DOMAIN"
    elif not ledger_ok:
        decision = "BC2_C0_ENRICHED_DYNAMICS_NUMERICALLY_BLOCKED"
    elif supported and preferred:
        decision = "BC2_C0_ENRICHED_PRESCRIBED_H_DYNAMICS_SUPPORTED"
    elif supported:
        decision = "BC2_C0_ENRICHED_PRESCRIBED_H_DYNAMICS_SUPPORTED_WIDTH_UNRESOLVED"
    else:
        decision = "BC2_C0_ENRICHED_DYNAMICS_MIXED_RESPONSE"

    result = {
        "schema": "swap5.lare.bc2.c0.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C0",
        "decision": decision,
        "hard_checks": {
            "max_abs_physical_moving_ledger_residual_cm": max(all_ledgers) if all_ledgers else None,
            "ledger_gate_cm": LEDGER_GATE,
            "all_primary_histories_qualified": all(s == "QUALIFIED" for s in all_status),
            "all_numerical_floors_available": all(cases[(d, h)]["numerical_floor"] is not None for d in WIDTHS for h in HISTORY_STEPS),
        },
        "support_vs_B0": support,
        "supported_widths_cm": supported,
        "preferred_width_cm": preferred,
        "widths": {
            str(d): {
                h: {
                    "status": cases[(d, h)]["status"],
                    "primary": compact(cases[(d, h)]["fine"]),
                    "numerical_floor": cases[(d, h)]["numerical_floor"],
                    "failures": cases[(d, h)]["failures"],
                }
                for h in HISTORY_STEPS
            }
            for d in WIDTHS