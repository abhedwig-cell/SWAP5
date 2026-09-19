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

spec5 = importlib.util.spec_from_file_location("bc2b5", HERE / "analyze_lare_bc2_b5_storage_linear_qh.py")
b5 = importlib.util.module_from_spec(spec5)
spec5.loader.exec_module(b5)

WIDTHS = (2.5, 5.0, 10.0)
GL = {
    64: np.polynomial.legendre.leggauss(64),
    128: np.polynomial.legendre.leggauss(128),
}
STORAGE_GATE = 1.0e-10


def profile_arrays(profile):
    pts = sorted((-row["z"], row["h"]) for row in profile.values())
    z = np.asarray([p[0] for p in pts], dtype=float)
    h = np.asarray([p[1] for p in pts], dtype=float)
    return z, h


def sample_h_array(profile, depth):
    z, h = profile_arrays(profile)
    d = np.asarray(depth, dtype=float)
    if np.any(d < z[0] - 1.0e-12) or np.any(d > z[-1] + 1.0e-12):
        raise ValueError("terminal-band pressure interpolation would extrapolate")
    return np.interp(d, z, h)


def terminal_storage(profile, H, d, nq):
    if d <= 0.0 or H - d < b3.ANCHOR - 1.0e-12:
        raise ValueError("terminal band is not fully inside moving layer")

    # The accepted Reference pressure head is piecewise linear between nodes.
    # Integrate each smooth interpolation segment independently so the 64/128
    # Gauss-Legendre crosscheck measures constitutive quadrature rather than
    # convergence across interpolation kinks.
    z_nodes, _ = profile_arrays(profile)
    lo = H - d
    cuts = [lo]
    cuts.extend(float(z) for z in z_nodes if lo + 1.0e-12 < z < H - 1.0e-12)
    cuts.append(H)
    cuts = sorted(set(cuts))

    x, w = GL[nq]
    total = 0.0
    for a, b in zip(cuts, cuts[1:]):
        half = 0.5 * (b - a)
        mid = 0.5 * (a + b)
        zq = mid + half * x
        hq = sample_h_array(profile, zq)
        if np.max(hq) > 1.0e-9:
            raise ValueError("terminal band includes positive-pressure sample")
        psi = -hq
        if np.min(psi) < -1.0e-9:
            raise ValueError("negative suction in terminal band")
        theta = b3.theta_from_psi(psi)
        total += float(half * np.sum(w * theta))
    return total


def terminal_candidate(profile, total, d, nq):
    H, storage, _ = b3.project(profile, total)
    L = H - b3.ANCHOR
    if d > L + 1.0e-12:
        raise ValueError("terminal width exceeds moving-layer thickness")
    Wm = float(storage[b3.NFIXED])
    Wt = terminal_storage(profile, H, d, nq)
    Wb = Wm - Wt
    theta_t = Wt / d
    psi, _ = b3.psi_k(np.asarray([theta_t], dtype=float))
    psi_t = float(psi[0])
    qh = b3.KS * (1.0 - 2.0 * psi_t / d)
    return {
        "H": H,
        "L": L,
        "Wm": Wm,
        "Wt": Wt,
        "Wb": Wb,
        "theta_t": theta_t,
        "psi_t": psi_t,
        "qH": qh,
        "closure": (Wb + Wt) - Wm,
    }


def endpoint(profile, total):
    H, qstd = b4.q_moving(profile, total)
    _, qlin, _, _ = b5.q_storage(profile, total, 64)
    qpoint, _ = b4.q_point(profile, H, 2.5)
    out = {
        "H": H,
        "MOVING_LAYER_AVERAGE": qstd,
        "LINEAR_STORAGE": qlin,
        "POINT_2_5CM": qpoint,
        "bands": {},
    }
    for d in WIDTHS:
        p64 = terminal_candidate(profile, total, d, 64)
        p128 = terminal_candidate(profile, total, d, 128)
        out["bands"][d] = {"p64": p64, "p128": p128}
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
    return {
        "count": int(len(rows)),
        "bias": float(np.mean(err)),
        "mae": float(np.mean(np.abs(err))),
        "rms": float(np.sqrt(np.mean(err * err))),
        "max_abs": float(np.max(np.abs(err))),
        "sign_mismatch": int(np.count_nonzero(np.sign(ref) != np.sign(pred))),
        "corr": corr,
    }


def better_than(candidate, comparator):
    return (
        candidate["rms"] < comparator["rms"] - 1.0e-12
        and candidate["mae"] < comparator["mae"] - 1.0e-12
        and candidate["sign_mismatch"] <= comparator["sign_mismatch"]
    )


def noninferior(candidate, comparator):
    return (
        candidate["rms"] <= comparator["rms"] + 1.0e-12
        and candidate["mae"] <= comparator["mae"] + 1.0e-12
        and candidate["sign_mismatch"] <= comparator["sign_mismatch"]
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--b4-result", required=True, type=pathlib.Path)
    ap.add_argument("--b5-result", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    r4 = json.loads(args.b4_result.read_text())
    r5 = json.loads(args.b5_result.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_CONSERVATIVE_TERMINAL_BAND_STATE_DIAGNOSTIC"
    assert r4["decision"] == pre["predecessors"]["required_B4_decision"]
    assert r5["decision"] == pre["predecessors"]["required_B5_decision"]

    init_meta, init_nodes, states, nodes = b3.load_reference(args.reference)

    rows = []
    failures = []
    max_projection_closure = 0.0
    max_storage_cross = 0.0
    terminal_ranges = {
        d: {"theta_min": math.inf, "theta_max": -math.inf, "psi_min": math.inf, "psi_max": -math.inf}
        for d in WIDTHS
    }

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
                name = f"TERMINAL_{str(d).replace('.', '_')}CM"
                a64 = prev["bands"][d]["p64"]
                b64 = cur["bands"][d]["p64"]
                a128 = prev["bands"][d]["p128"]
                b128 = cur["bands"][d]["p128"]
                row[name] = 0.5 * (a64["qH"] + b64["qH"])

                max_projection_closure = max(
                    max_projection_closure,
                    abs(a64["closure"]), abs(b64["closure"]),
                    abs(a128["closure"]), abs(b128["closure"]),
                )
                max_storage_cross = max(
                    max_storage_cross,
                    abs(a64["Wt"] - a128["Wt"]),
                    abs(b64["Wt"] - b128["Wt"]),
                )
                for state in (a64, b64):
                    tr = terminal_ranges[d]
                    tr["theta_min"] = min(tr["theta_min"], state["theta_t"])
                    tr["theta_max"] = max(tr["theta_max"], state["theta_t"])
                    tr["psi_min"] = min(tr["psi_min"], state["psi_t"])
                    tr["psi_max"] = max(tr["psi_max"], state["psi_t"])

            rows.append(row)
            prev = cur
            pp, pt = p, total

    expected = sum(b3.HISTORY_STEPS.values())
    finite_names = ["qref", "MOVING_LAYER_AVERAGE", "LINEAR_STORAGE", "POINT_2_5CM"] + [
        f"TERMINAL_{str(d).replace('.', '_')}CM" for d in WIDTHS
    ]
    complete = len(rows) == expected and not failures
    hard_ok = (
        complete
        and max_projection_closure <= STORAGE_GATE
        and max_storage_cross <= STORAGE_GATE
        and all(math.isfinite(r[k]) for r in rows for k in finite_names)
    )

    report = {"by_direction": {}, "by_history": {}}
    candidate_names = ["MOVING_LAYER_AVERAGE", "LINEAR_STORAGE", "POINT_2_5CM"] + [
        f"TERMINAL_{str(d).replace('.', '_')}CM" for d in WIDTHS
    ]
    for axis, groups in (
        ("by_direction", ["HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"]),
        ("by_history", list(b3.HISTORY_STEPS)),
    ):
        for group in groups:
            rr = [r for r in rows if (r["direction"] == group if axis == "by_direction" else r["history"] == group)]
            report[axis][group] = {name: metrics(rr, name) for name in candidate_names}

    support = {}
    supported = []
    for d in WIDTHS:
        name = f"TERMINAL_{str(d).replace('.', '_')}CM"
        moving = {}
        for g in ("WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
            cand = report["by_direction"][g][name]
            std = report["by_direction"][g]["MOVING_LAYER_AVERAGE"]
            lin = report["by_direction"][g]["LINEAR_STORAGE"]
            moving[g] = better_than(cand, std) and better_than(cand, lin)
        hold = noninferior(
            report["by_direction"]["HOLD"][name],
            report["by_direction"]["HOLD"]["LINEAR_STORAGE"],
        )
        support[name] = {
            "WATER_TABLE_RISING": moving["WATER_TABLE_RISING"],
            "WATER_TABLE_FALLING": moving["WATER_TABLE_FALLING"],
            "HOLD_NONINFERIOR_TO_B5": hold,
        }
        if all(moving.values()) and hold:
            supported.append(name)

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
        support[n]["WATER_TABLE_RISING"] != support[n]["WATER_TABLE_FALLING"]
        for n in support
    )

    if not hard_ok:
        decision = "BC2_B6_TERMINAL_STORAGE_DIAGNOSTIC_BLOCKED"
    elif supported and preferred:
        decision = "BC2_B6_TERMINAL_STORAGE_STATE_SUPPORTED"
    elif supported:
        decision = "BC2_B6_TERMINAL_STORAGE_STATE_SUPPORTED_WIDTH_UNRESOLVED"
    elif direction_dependent:
        decision = "BC2_B6_TERMINAL_STORAGE_DIRECTION_DEPENDENT"
    else:
        decision = "BC2_B6_TERMINAL_STORAGE_NOT_SUPPORTED"

    gap = {}
    for d in WIDTHS:
        name = f"TERMINAL_{str(d).replace('.', '_')}CM"
        gap[name] = {}
        for g in ("HOLD", "WATER_TABLE_RISING", "WATER_TABLE_FALLING"):
            c = report["by_direction"][g][name]
            p = report["by_direction"][g]["POINT_2_5CM"]
            gap[name][g] = {
                "rms_excess_over_point_cm_per_day": c["rms"] - p["rms"],
                "mae_excess_over_point_cm_per_day": c["mae"] - p["mae"],
                "sign_mismatch_excess_over_point": c["sign_mismatch"] - p["sign_mismatch"],
            }

    result = {
        "schema": "swap5.lare.bc2.b6.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-B6",
        "decision": decision,
        "complete": complete,
        "hard_checks": {
            "max_abs_Wb_plus_Wt_minus_Wm_cm": max_projection_closure,
            "projection_storage_closure_gate_cm": STORAGE_GATE,
            "max_abs_terminal_storage_64_vs_128_cm": max_storage_cross,
            "quadrature_crosscheck_gate_cm": STORAGE_GATE,
            "failure_count": len(failures),
        },
        "support": support,
        "supported_terminal_states": supported,
        "preferred_terminal_state": preferred,
        "terminal_state_ranges": {str(d): terminal_ranges[d] for d in WIDTHS},
        "local_information_gap": gap,
        "failures": failures[:20],
        **report,
        "interpretation": [
            "Each terminal candidate adds exactly one conservative moving storage state; no point pressure head enters the candidate closure.",
            "The candidate qH is the standard LARE water-table face formula applied to the terminal-band average water content.",
            "POINT_2_5CM remains a full-order diagnostic context only.",
            "This is state/operator evidence only. The moving internal boundary H-d has not yet been given a prognostic conservation law.",
        ],
        "added_state_dimension": 1,
        "propagated_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "hard_checks": result["hard_checks"],
        "support": support,
        "supported_terminal_states": supported,
        "preferred_terminal_state": preferred,
        "by_direction": report["by_direction"],
    }, sort_keys=True))
    return 0 if hard_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())