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

c0 = load_module("bc2c0", "run_lare_bc2_c0_enriched_dynamics.py")
b0 = c0.b0
b8 = c0.b8

WIDTHS = (2.5, 5.0)
DTS = (0.0001, 0.00005)
NFIXED = c0.NFIXED
FIXED_DZ = c0.FIXED_DZ
ANCHOR = c0.ANCHOR
PROFILE_DEPTH = c0.PROFILE_DEPTH
OBS_DT = c0.OBS_DT
THETA_S = c0.THETA_S
LEDGER_GATE = 1.0e-10
IDENTITY_GATE = 1.0e-10
FLUX_IDENTITY_GATE = 1.0e-10
HISTORY_STEPS = c0.HISTORY_STEPS
IDX_WB = c0.IDX_WB
IDX_WT = c0.IDX_WT
IDX_CUM_QH = c0.IDX_CUM_QH
IDX_CUM_QI = c0.IDX_CUM_QI
NSTATE = c0.NSTATE
NPHYS = NFIXED + 2


def physical_state(y: np.ndarray) -> np.ndarray:
    return np.concatenate([y[:NFIXED], [y[IDX_WB], y[IDX_WT]]]).astype(float)


def projected_state(history, step, d, init_meta, init_nodes, states, nodes):
    if step == 0:
        p, U, fixed = c0.initial_reference_projection(history, d, init_meta, init_nodes)
    else:
        p, U, fixed = c0.reference_projection(history, step, d, states, nodes)
    y = np.zeros(NSTATE, dtype=float)
    y[:NFIXED] = fixed
    y[IDX_WB] = p["Wb64"]
    y[IDX_WT] = p["Wt64"]
    return y, p, U


def heun_step_with_flux(y, dt, H0, H1, Hdot, d):
    f0, m0 = c0.rhs(y, H0, Hdot, d)
    guess = y + dt * f0
    for iteration in range(1, c0.MAX_CORRECTOR + 1):
        f1, m1 = c0.rhs(guess, H1, Hdot, d)
        nxt = y + 0.5 * dt * (f0 + f1)
        old = c0.convergence_vector(guess, H1, d)
        new = c0.convergence_vector(nxt, H1, d)
        if np.max(np.abs(new - old)) <= c0.CORRECTOR_TOL:
            avg = {
                "q90": 0.5 * (m0["q90"] + m1["q90"]),
                "qi": 0.5 * (m0["qi"] + m1["qi"]),
                "qH": 0.5 * (m0["qH"] + m1["qH"]),
            }
            return nxt, iteration, avg
        guess = nxt
    raise RuntimeError("NUMERICAL_BLOCKED iterative Heun corrector")


def propagate_interval(y0, H0, H1, dt, d):
    ratio = OBS_DT / dt
    nsub = int(round(ratio))
    if nsub <= 0 or abs(ratio - nsub) > 1.0e-12:
        raise RuntimeError("dt does not divide observation interval")
    Hdot = (H1 - H0) / OBS_DT
    y = y0.copy()
    integrals = {"q90": 0.0, "qi": 0.0, "qH": 0.0}
    max_corrector = 0
    for sub in range(nsub):
        fa = sub / nsub
        fb = (sub + 1) / nsub
        Ha = H0 + (H1 - H0) * fa
        Hb = H0 + (H1 - H0) * fb
        y, iterations, avg = heun_step_with_flux(y, dt, Ha, Hb, Hdot, d)
        max_corrector = max(max_corrector, iterations)
        for key in integrals:
            integrals[key] += dt * avg[key]
    return y, {key: value / OBS_DT for key, value in integrals.items()}, max_corrector


def reference_fluxes(prev_ref, ref, bottom_exchange):
    Hdot = (ref["H"] - prev_ref["H"]) / OBS_DT
    qH = bottom_exchange / OBS_DT
    q90 = -(ref["Wfixed"] - prev_ref["Wfixed"]) / OBS_DT
    Gi = 0.5 * (prev_ref["theta_i"] + ref["theta_i"]) * Hdot
    dWb = (ref["Wb64"] - prev_ref["Wb64"]) / OBS_DT
    dWt = (ref["Wt64"] - prev_ref["Wt64"]) / OBS_DT
    qi_bulk = q90 + Gi - dWb
    qi_term = dWt + qH - THETA_S * Hdot + Gi
    return {
        "q90": q90,
        "qi": 0.5 * (qi_bulk + qi_term),
        "qH": qH,
    }


def rms(values):
    a = np.asarray(values, dtype=float)
    return float(np.sqrt(np.mean(a * a))) if a.size else 0.0


def maxabs(values):
    a = np.asarray(values, dtype=float)
    return float(np.max(np.abs(a))) if a.size else 0.0


def first_state_exceeds(local_norms, drift_norms):
    for idx, (loc, drift) in enumerate(zip(local_norms, drift_norms), 1):
        if drift > loc:
            return idx
    return None


def first_flux_exceeds(local_values, drift_values):
    for idx, (loc, drift) in enumerate(zip(local_values, drift_values), 1):
        if abs(drift) > abs(loc):
            return idx
    return None


def classify(local_rms, drift_rms):
    return "STATE_DRIFT_DOMINANT" if drift_rms > local_rms else "LOCAL_CLOSURE_DOMINANT"


def solve(history, d, dt, init_meta, init_nodes, states, nodes):
    free, Hprev, Uinitial = c0.initial_state(history, d, init_meta, init_nodes)
    Hinitial = Hprev
    prev_ref, _, _ = c0.initial_reference_projection(history, d, init_meta, init_nodes)

    max_free_ledger = 0.0
    max_teacher_ledger = 0.0
    max_state_identity = 0.0
    max_flux_identity = 0.0
    max_corrector = 0

    state_local_flat = []
    state_drift_flat = []
    state_total_flat = []
    state_local_norms = []
    state_drift_norms = []
    total_storage_local = []
    total_storage_drift = []
    total_storage_total = []

    flux_local = {k: [] for k in ("q90", "qi", "qH")}
    flux_drift = {k: [] for k in ("q90", "qi", "qH")}
    flux_total = {k: [] for k in ("q90", "qi", "qH")}

    rows = []
    cum_free_qH = 0.0

    for step in range(1, HISTORY_STEPS[history] + 1):
        ref, Uref, _ = c0.reference_projection(history, step, d, states, nodes)
        H = ref["H"]

        # Free branch: identical C0 propagation from its previous reduced end state.
        free_start = free.copy()
        free, free_flux, it_free = propagate_interval(free_start, Hprev, H, dt, d)
        max_corrector = max(max_corrector, it_free)
        cum_free_qH += free_flux["qH"] * OBS_DT

        # Teacher branch: exact conservative Reference projection at the interval start.
        teacher_start, teacher_start_ref, Ustart_ref = projected_state(
            history, step - 1, d, init_meta, init_nodes, states, nodes
        )
        if abs(teacher_start_ref["H"] - Hprev) > 1.0e-12:
            raise RuntimeError("teacher start H mismatch")
        teacher, teacher_flux, it_teacher = propagate_interval(
            teacher_start, Hprev, H, dt, d
        )
        max_corrector = max(max_corrector, it_teacher)

        ref_end, _, _ = projected_state(
            history, step, d, init_meta, init_nodes, states, nodes
        )
        ref_flux = reference_fluxes(prev_ref, ref, states[(history, step)]["bottom_exchange"])

        free_phys = physical_state(free)
        teacher_phys = physical_state(teacher)
        ref_phys = physical_state(ref_end)

        local_state = teacher_phys - ref_phys
        drift_state = free_phys - teacher_phys
        total_state = free_phys - ref_phys
        state_identity = total_state - (local_state + drift_state)
        max_state_identity = max(max_state_identity, maxabs(state_identity))

        state_local_flat.extend(local_state.tolist())
        state_drift_flat.extend(drift_state.tolist())
        state_total_flat.extend(total_state.tolist())
        state_local_norms.append(float(np.sqrt(np.mean(local_state * local_state))))
        state_drift_norms.append(float(np.sqrt(np.mean(drift_state * drift_state))))

        Ufree = float(np.sum(free_phys))
        Uteacher = float(np.sum(teacher_phys))
        local_U = Uteacher - Uref
        drift_U = Ufree - Uteacher
        total_U = Ufree - Uref
        total_storage_local.append(local_U)
        total_storage_drift.append(drift_U)
        total_storage_total.append(total_U)

        for key in ("q90", "qi", "qH"):
            local = teacher_flux[key] - ref_flux[key]
            drift = free_flux[key] - teacher_flux[key]
            total = free_flux[key] - ref_flux[key]
            ident = total - (local + drift)
            max_flux_identity = max(max_flux_identity, abs(ident))
            flux_local[key].append(local)
            flux_drift[key].append(drift)
            flux_total[key].append(total)

        # Structural ledgers for both branches.
        free_ledger = Ufree - Uinitial + cum_free_qH - THETA_S * (H - Hinitial)
        teacher_qH_exchange = teacher_flux["qH"] * OBS_DT
        teacher_ledger = (
            Uteacher - Ustart_ref + teacher_qH_exchange
            - THETA_S * (H - Hprev)
        )
        max_free_ledger = max(max_free_ledger, abs(free_ledger))
        max_teacher_ledger = max(max_teacher_ledger, abs(teacher_ledger))

        rows.append({
            "step": step,
            "H_cm": H,
            "state_shape_local_rms_cm": state_local_norms[-1],
            "state_shape_drift_rms_cm": state_drift_norms[-1],
            "total_storage_local_cm": local_U,
            "total_storage_drift_cm": drift_U,
            "total_storage_total_cm": total_U,
            "q90_local_cm_per_day": flux_local["q90"][-1],
            "q90_drift_cm_per_day": flux_drift["q90"][-1],
            "q90_total_cm_per_day": flux_total["q90"][-1],
            "qi_local_cm_per_day": flux_local["qi"][-1],
            "qi_drift_cm_per_day": flux_drift["qi"][-1],
            "qi_total_cm_per_day": flux_total["qi"][-1],
            "qH_local_cm_per_day": flux_local["qH"][-1],
            "qH_drift_cm_per_day": flux_drift["qH"][-1],
            "qH_total_cm_per_day": flux_total["qH"][-1],
        })
        Hprev = H
        prev_ref = ref

    channel = {}
    state_local_r = rms(state_local_flat)
    state_drift_r = rms(state_drift_flat)
    state_total_r = rms(state_total_flat)
    channel["state_shape"] = {
        "classification": classify(state_local_r, state_drift_r),
        "local_closure_rms_cm": state_local_r,
        "state_drift_rms_cm": state_drift_r,
        "total_free_rms_cm": state_total_r,
        "local_closure_max_abs_cm": maxabs(state_local_flat),
        "state_drift_max_abs_cm": maxabs(state_drift_flat),
        "total_free_max_abs_cm": maxabs(state_total_flat),
        "fraction_intervals_state_dominant": float(np.mean(
            np.asarray(state_drift_norms) > np.asarray(state_local_norms)
        )),
        "first_state_dominant_interval": first_state_exceeds(
            state_local_norms, state_drift_norms
        ),
    }

    for key in ("q90", "qi", "qH"):
        lr = rms(flux_local[key])
        dr = rms(flux_drift[key])
        tr = rms(flux_total[key])
        channel[key] = {
            "classification": classify(lr, dr),
            "local_closure_rms_cm_per_day": lr,
            "state_drift_rms_cm_per_day": dr,
            "total_free_rms_cm_per_day": tr,
            "local_closure_max_abs_cm_per_day": maxabs(flux_local[key]),
            "state_drift_max_abs_cm_per_day": maxabs(flux_drift[key]),
            "total_free_max_abs_cm_per_day": maxabs(flux_total[key]),
            "fraction_intervals_state_dominant": float(np.mean(
                np.abs(np.asarray(flux_drift[key])) >
                np.abs(np.asarray(flux_local[key]))
            )),
            "first_state_dominant_interval": first_flux_exceeds(
                flux_local[key], flux_drift[key]
            ),
        }

    total = {
        "local_closure_rms_cm": rms(total_storage_local),
        "state_drift_rms_cm": rms(total_storage_drift),
        "total_free_rms_cm": rms(total_storage_total),
        "local_closure_max_abs_cm": maxabs(total_storage_local),
        "state_drift_max_abs_cm": maxabs(total_storage_drift),
        "total_free_max_abs_cm": maxabs(total_storage_total),
        "first_state_dominant_interval": first_flux_exceeds(
            total_storage_local, total_storage_drift
        ),
    }

    return {
        "status": "QUALIFIED",
        "dt_day": dt,
        "max_abs_free_physical_ledger_cm": max_free_ledger,
        "max_abs_teacher_interval_ledger_cm": max_teacher_ledger,
        "max_abs_additive_state_identity_cm": max_state_identity,
        "max_abs_additive_flux_identity_cm_per_day": max_flux_identity,
        "max_corrector_iterations": max_corrector,
        "channels": channel,
        "total_unsaturated_storage": total,
        "trajectory": rows,
    }


def floor_difference(primary, cross):
    out = {}
    for channel in ("state_shape", "q90", "qi", "qH"):
        a = primary["channels"][channel]
        b = cross["channels"][channel]
        keys = [k for k in a if isinstance(a[k], (int, float)) and not isinstance(a[k], bool)]
        out[channel] = {
            key: abs(float(a[key]) - float(b[key]))
            for key in keys
            if key in b and isinstance(b[key], (int, float)) and not isinstance(b[key], bool)
        }
        out[channel]["classification_match"] = (
            a["classification"] == b["classification"]
        )
    out["total_unsaturated_storage"] = {
        key: abs(float(primary["total_unsaturated_storage"][key]) - float(cross["total_unsaturated_storage"][key]))
        for key in primary["total_unsaturated_storage"]
        if isinstance(primary["total_unsaturated_storage"][key], (int, float))
        and not isinstance(primary["total_unsaturated_storage"][key], bool)
        and key in cross["total_unsaturated_storage"]
        and isinstance(cross["total_unsaturated_storage"][key], (int, float))
        and not isinstance(cross["total_unsaturated_storage"][key], bool)
    }
    return out


def compact(run):
    return {k: v for k, v in run.items() if k != "trajectory"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--c0-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    c0_result = json.loads(args.c0_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_TEACHER_FORCED_DRIFT_DECOMPOSITION"
    assert c0_result["decision"] == pre["predecessor"]["required_decision"]
    assert pre["unchanged_model"]["no_new_state"] is True
    assert pre["unchanged_model"]["no_fit"] is True
    assert pre["production_rom_authorized"] is False

    init_meta, init_nodes, states, nodes = b0.load_reference(args.reference)

    cases = {}
    failures = {}
    for d in WIDTHS:
        for history in HISTORY_STEPS:
            runs = {}
            case_failures = {}
            for dt in DTS:
                key = f"{dt:.8f}"
                try:
                    runs[key] = solve(
                        history, d, dt, init_meta, init_nodes, states, nodes
                    )
                except ValueError as exc:
                    case_failures[key] = f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError, FloatingPointError) as exc:
                    case_failures[key] = f"NUMERICAL_BLOCKED: {exc}"
            cases[(d, history)] = {
                "primary": runs.get("0.00010000"),
                "cross": runs.get("0.00005000"),
                "failures": case_failures,
            }

    all_runs = [
        run
        for case in cases.values()
        for run in (case["primary"], case["cross"])
        if run is not None
    ]
    both_routes = all(
        case["primary"] is not None and case["cross"] is not None
        for case in cases.values()
    )
    max_free_ledger = max(
        [r["max_abs_free_physical_ledger_cm"] for r in all_runs] or [math.inf]
    )
    max_teacher_ledger = max(
        [r["max_abs_teacher_interval_ledger_cm"] for r in all_runs] or [math.inf]
    )
    max_state_identity = max(
        [r["max_abs_additive_state_identity_cm"] for r in all_runs] or [math.inf]
    )
    max_flux_identity = max(
        [r["max_abs_additive_flux_identity_cm_per_day"] for r in all_runs] or [math.inf]
    )
    hard_ok = (
        both_routes
        and max_free_ledger <= LEDGER_GATE
        and max_teacher_ledger <= LEDGER_GATE
        and max_state_identity <= IDENTITY_GATE
        and max_flux_identity <= FLUX_IDENTITY_GATE
    )

    by_width = {}
    classification_summary = {}
    for d in WIDTHS:
        by_width[str(d)] = {}
        classification_summary[str(d)] = {}
        for history in HISTORY_STEPS:
            case = cases[(d, history)]
            primary = case["primary"]
            cross = case["cross"]
            if primary is None or cross is None:
                by_width[str(d)][history] = {
                    "status": "NOT_QUALIFIED",
                    "failures": case["failures"],
                }
                continue
            by_width[str(d)][history] = {
                "status": "QUALIFIED",
                "primary": compact(primary),
                "cross": compact(cross),
                "numerical_floor": floor_difference(primary, cross),
                "failures": case["failures"],
            }
            classification_summary[str(d)][history] = {
                channel: primary["channels"][channel]["classification"]
                for channel in ("state_shape", "q90", "qi", "qH")
            }

    if not both_routes:
        decision = "BC2_C1_DECOMPOSITION_NOT_FULLY_QUALIFIED"
    elif not hard_ok:
        decision = "BC2_C1_DECOMPOSITION_IDENTITY_OR_LEDGER_FAILED"
    else:
        decision = "BC2_C1_TEACHER_FORCED_DRIFT_DECOMPOSITION_QUALIFIED"

    result = {
        "schema": "swap5.lare.bc2.c1.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C1",
        "decision": decision,
        "hard_checks": {
            "both_primary_and_cross_routes_required": both_routes,
            "max_abs_free_physical_ledger_cm": max_free_ledger,
            "max_abs_teacher_interval_ledger_cm": max_teacher_ledger,
            "max_abs_additive_state_identity_cm": max_state_identity,
            "max_abs_additive_flux_identity_cm_per_day": max_flux_identity,
            "ledger_gate_cm": LEDGER_GATE,
            "state_identity_gate_cm": IDENTITY_GATE,
            "flux_identity_gate_cm_per_day": FLUX_IDENTITY_GATE,
        },
        "classifications": classification_summary,
        "widths": by_width,
        "interpretation": [
            "Teacher-reference is the local-closure component on exact Reference-projected reduced states.",
            "Free-teacher is the accumulated reduced-state contribution while keeping the unchanged C0 closure.",
            "No scalar aggregate classification is used across state shape, q90, qi and qH.",
            "Total unsaturated storage is reported separately because conservative cancellation can hide internal shape drift.",
            "C1 changes no state dimension, closure, prescribed H trajectory, forcing or groundwater feedback."
        ],
        "groundwater_feedback_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "classifications": classification_summary,
        "primary_metrics": {
            str(d): {
                h: {
                    ch: {
                        "class": cases[(d,h)]["primary"]["channels"][ch]["classification"],
                        "local_rms": cases[(d,h)]["primary"]["channels"][ch].get(
                            "local_closure_rms_cm",
                            cases[(d,h)]["primary"]["channels"][ch].get("local_closure_rms_cm_per_day")
                        ),
                        "drift_rms": cases[(d,h)]["primary"]["channels"][ch].get(
                            "state_drift_rms_cm",
                            cases[(d,h)]["primary"]["channels"][ch].get("state_drift_rms_cm_per_day")
                        ),
                    }
                    for ch in ("state_shape","q90","qi","qH")
                }
                for h in HISTORY_STEPS
                if cases[(d,h)]["primary"] is not None
            }
            for d in WIDTHS
        }
    }, sort_keys=True))
    return 0 if decision == "BC2_C1_TEACHER_FORCED_DRIFT_DECOMPOSITION_QUALIFIED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
