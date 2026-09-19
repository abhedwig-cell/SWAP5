#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib
import statistics
import sys

THETA_R = 0.02
THETA_S = 0.427494
MASS_GATE_CM = 1.0e-12
TRAIN_HIST = tuple(f"D{i:02d}" for i in range(1, 9))
VALID_HIST = tuple(f"V{i:02d}" for i in range(1, 5))


def fields(payload: str) -> dict[str, str]:
    out = {}
    for part in payload.split("|"):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k] = v
    return out


def qstats(values):
    vals = [float(x) for x in values]
    if not vals:
        return {"count": 0, "mean": None, "mean_abs": None, "rmse": None,
                "p95_abs": None, "max_abs": None}
    av = [abs(x) for x in vals]
    ordered = sorted(av)
    p95 = ordered[min(len(ordered) - 1, math.ceil(0.95 * len(ordered)) - 1)]
    return {
        "count": len(vals),
        "mean": sum(vals) / len(vals),
        "mean_abs": sum(av) / len(vals),
        "rmse": math.sqrt(sum(x*x for x in vals) / len(vals)),
        "p95_abs": p95,
        "max_abs": max(av),
    }


def sign(x: float) -> int:
    return 1 if x > 0.0 else -1 if x < 0.0 else 0


def reversal_steps(flux_by_step: dict[int, float]) -> list[int]:
    out = []
    previous = None
    for step in sorted(flux_by_step):
        s = sign(flux_by_step[step])
        if s == 0:
            continue
        if previous is not None and s != previous:
            out.append(step)
        previous = s
    return out


def c2_of(state, nodes):
    theta = [float(nodes[i]["THETA"]) for i in range(1, 17)]
    s_total = float(state["TOTAL_STORAGE"])
    c80 = sum(theta[:8]) / 8.0 - sum(theta[8:]) / 8.0
    return (s_total, c80)


def mean_sd(points):
    means = []
    sds = []
    for j in range(2):
        col = [p[j] for p in points]
        m = sum(col) / len(col)
        v = sum((x - m) ** 2 for x in col) / len(col)
        sd = math.sqrt(v)
        if not (math.isfinite(sd) and sd > 0.0):
            raise SystemExit(f"nonpositive C2 training scale coordinate {j}")
        means.append(m)
        sds.append(sd)
    return tuple(means), tuple(sds)


def standardize(p, means, sds):
    return ((p[0] - means[0]) / sds[0], (p[1] - means[1]) / sds[1])


def cross(o, a, b):
    return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])


def convex_hull(points):
    pts = sorted(set(points))
    if len(pts) <= 1:
        return pts
    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0.0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0.0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def geom_tol(*pts):
    scale = 1.0
    for p in pts:
        scale = max(scale, abs(p[0]), abs(p[1]))
    return 256.0 * sys.float_info.epsilon * scale * scale


def on_segment(a, b, p):
    tol = geom_tol(a, b, p)
    if abs(cross(a, b, p)) > tol:
        return False
    return (min(a[0], b[0]) - tol <= p[0] <= max(a[0], b[0]) + tol and
            min(a[1], b[1]) - tol <= p[1] <= max(a[1], b[1]) + tol)


def inside_closed_hull(hull, p):
    if not hull:
        return False
    if len(hull) == 1:
        tol = geom_tol(hull[0], p)
        return abs(hull[0][0]-p[0]) <= tol and abs(hull[0][1]-p[1]) <= tol
    if len(hull) == 2:
        return on_segment(hull[0], hull[1], p)
    for a, b in zip(hull, hull[1:] + hull[:1]):
        if cross(a, b, p) < -geom_tol(a, b, p):
            return False
    return True


def nearest(rows, q):
    return min(rows, key=lambda r: (r["z"][0]-q[0])**2 + (r["z"][1]-q[1])**2)


def parse(path):
    states = {}
    nodes = collections.defaultdict(dict)
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_V1_STATE|" in line:
            r = fields(line.split("F_ROMV2_V1_STATE|", 1)[1])
            states[(r["HISTORY"], int(r["STEP"]))] = r
        elif "F_ROMV2_V1_NODE|" in line:
            r = fields(line.split("F_ROMV2_V1_NODE|", 1)[1])
            nodes[(r["HISTORY"], int(r["STEP"]))][int(r["NODE"])] = r
    return states, nodes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--prereg", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    prereg = json.loads(pathlib.Path(args.prereg).read_text())
    states, nodes = parse(args.input)

    expected = {(h, s) for h in TRAIN_HIST + VALID_HIST for s in range(1, 65)}
    structure_ok = set(states) == expected and set(nodes) == expected and all(
        set(nodes[k]) == set(range(1, 17)) for k in expected
    )
    if not structure_ok:
        raise SystemExit("F-ROMV2 V1 state/node structure mismatch")

    c2 = {k: c2_of(states[k], nodes[k]) for k in expected}

    training = []
    for h in TRAIN_HIST:
        for step in range(1, 64):
            a = c2[(h, step)]
            b = c2[(h, step + 1)]
            target = states[(h, step + 1)]
            training.append({
                "history": h,
                "input_step": step,
                "target_step": step + 1,
                "symbol": target["SYMBOL"].strip(),
                "x": a,
                "dC": b[1] - a[1],
                "bex": float(target["BOTTOM_OUTWARD_EXCHANGE"]),
                "bflux": float(target["BOTTOM_FLUX"]),
            })

    means, sds = mean_sd([r["x"] for r in training])
    by_symbol = collections.defaultdict(list)
    for r in training:
        r["z"] = standardize(r["x"], means, sds)
        by_symbol[r["symbol"]].append(r)

    hulls = {sym: convex_hull([r["z"] for r in rows]) for sym, rows in by_symbol.items()}
    forcing_means = {}
    for sym, rows in by_symbol.items():
        forcing_means[sym] = {
            "dC": sum(r["dC"] for r in rows)/len(rows),
            "bex": sum(r["bex"] for r in rows)/len(rows),
            "bflux": sum(r["bflux"] for r in rows)/len(rows),
            "count": len(rows),
        }

    global_integrity = collections.Counter()
    pooled_c2_total = []
    pooled_c2_cum = []
    pooled_base_total = []
    pooled_base_cum = []
    pooled_c2_bflux = []
    pooled_nn_dist = []
    per_history = {}
    total_reduced = 0

    for h in VALID_HIST:
        cur_s, cur_c = c2[(h, 1)]
        base_s, base_c = cur_s, cur_c
        pred_cum = 0.0
        base_cum = 0.0
        actual_cum = 0.0
        c2_flux = {1: float(states[(h, 1)]["BOTTOM_FLUX"])}
        base_flux = {1: float(states[(h, 1)]["BOTTOM_FLUX"])}
        actual_flux = {1: float(states[(h, 1)]["BOTTOM_FLUX"])}
        c2_total_err = []
        c2_cum_err = []
        base_total_err = []
        base_cum_err = []
        bflux_err = []
        fallback_steps = []
        forcing_ood = []
        state_ood = []
        nn_dists = []
        reentries = 0
        prev_fallback = False

        for step in range(2, 65):
            actual = states[(h, step)]
            sym = actual["SYMBOL"].strip()
            actual_s = float(actual["TOTAL_STORAGE"])
            actual_bex = float(actual["BOTTOM_OUTWARD_EXCHANGE"])
            actual_bflux = float(actual["BOTTOM_FLUX"])
            top = float(actual["TOP_EXCHANGE"])
            actual_cum += actual_bex
            actual_flux[step] = actual_bflux

            fallback = False
            if sym not in by_symbol:
                fallback = True
                forcing_ood.append(step)
            else:
                qz = standardize((cur_s, cur_c), means, sds)
                if not inside_closed_hull(hulls[sym], qz):
                    fallback = True
                    state_ood.append(step)

            if fallback:
                next_s, next_c = c2[(h, step)]
                pred_bex, pred_bflux = actual_bex, actual_bflux
                next_base_s, next_base_c = next_s, next_c
                base_bex, base_bflux = actual_bex, actual_bflux
                fallback_steps.append(step)
            else:
                qz = standardize((cur_s, cur_c), means, sds)
                row = nearest(by_symbol[sym], qz)
                dist = math.sqrt((row["z"][0]-qz[0])**2 + (row["z"][1]-qz[1])**2)
                nn_dists.append(dist)
                pooled_nn_dist.append(dist)

                pred_bex = row["bex"]
                pred_bflux = row["bflux"]
                next_s = cur_s - top - pred_bex
                next_c = cur_c + row["dC"]

                fm = forcing_means[sym]
                base_bex = fm["bex"]
                base_bflux = fm["bflux"]
                next_base_s = base_s - top - base_bex
                next_base_c = base_c + fm["dC"]
                total_reduced += 1
                if prev_fallback:
                    reentries += 1

                if not all(math.isfinite(x) for x in (next_s,next_c,pred_bex,pred_bflux)):
                    global_integrity["nonfinite"] += 1
                theta_upper = next_s/160.0 + next_c/2.0
                theta_lower = next_s/160.0 - next_c/2.0
                if not (THETA_R <= theta_upper <= THETA_S and THETA_R <= theta_lower <= THETA_S):
                    global_integrity["theta_bounds"] += 1
                mass_residual = (next_s-cur_s) + top + pred_bex
                if abs(mass_residual) > MASS_GATE_CM:
                    global_integrity["mass"] += 1

            if (sym not in by_symbol or (sym in by_symbol and step in state_ood)) and not fallback:
                global_integrity["ood_failopen"] += 1

            if h == "V04" and sym not in by_symbol and not fallback:
                global_integrity["v04_expected_forcing_ood_missed"] += 1

            pred_cum += pred_bex
            base_cum += base_bex
            c2_flux[step] = pred_bflux
            base_flux[step] = base_bflux

            ce = next_s - actual_s
            cume = pred_cum - actual_cum
            be = next_base_s - actual_s
            bcume = base_cum - actual_cum
            c2_total_err.append(ce)
            c2_cum_err.append(cume)
            base_total_err.append(be)
            base_cum_err.append(bcume)
            bflux_err.append(pred_bflux - actual_bflux)

            if h in ("V01","V02","V03"):
                pooled_c2_total.append(ce)
                pooled_c2_cum.append(cume)
                pooled_base_total.append(be)
                pooled_base_cum.append(bcume)
                pooled_c2_bflux.append(pred_bflux - actual_bflux)

            cur_s, cur_c = next_s, next_c
            base_s, base_c = next_base_s, next_base_c
            prev_fallback = fallback

        actual_rev = reversal_steps(actual_flux)
        c2_rev = reversal_steps(c2_flux)
        base_rev = reversal_steps(base_flux)
        sign_errors = sum(sign(c2_flux[s]) != sign(actual_flux[s]) for s in range(2,65)
                          if sign(actual_flux[s]) != 0)
        per_history[h] = {
            "fallback_steps": fallback_steps,
            "fallback_count": len(fallback_steps),
            "fallback_fraction": len(fallback_steps)/63.0,
            "forcing_ood_steps": forcing_ood,
            "state_ood_steps": state_ood,
            "reentry_count": reentries,
            "reduced_count": 63-len(fallback_steps),
            "nearest_neighbor_distance": qstats(nn_dists),
            "total_storage_error_cm": qstats(c2_total_err),
            "cumulative_bottom_exchange_error_cm": qstats(c2_cum_err),
            "forcing_only_total_storage_error_cm": qstats(base_total_err),
            "forcing_only_cumulative_bottom_exchange_error_cm": qstats(base_cum_err),
            "terminal_bottom_flux_error_cm_per_day": qstats(bflux_err),
            "bottom_flux_sign_error_count": sign_errors,
            "actual_reversal_steps": actual_rev,
            "c2_reversal_steps": c2_rev,
            "forcing_only_reversal_steps": base_rev,
            "final_cumulative_bottom_exchange_error_cm": c2_cum_err[-1],
            "forcing_only_final_cumulative_bottom_exchange_error_cm": base_cum_err[-1],
            "actual_cumulative_bottom_exchange_cm": actual_cum,
        }

    c2_total = qstats(pooled_c2_total)
    c2_cum = qstats(pooled_c2_cum)
    base_total = qstats(pooled_base_total)
    base_cum_stats = qstats(pooled_base_cum)
    integrity_pass = not any(global_integrity.values())
    v04_failclosed = (
        global_integrity["v04_expected_forcing_ood_missed"] == 0
        and all(step in per_history["V04"]["fallback_steps"]
                for step in per_history["V04"]["forcing_ood_steps"])
    )
    value_pass = (
        c2_total["rmse"] < base_total["rmse"]
        and c2_cum["rmse"] < base_cum_stats["rmse"]
        and sum(per_history[h]["reduced_count"] for h in ("V01","V02","V03")) > 0
    )

    if not integrity_pass or not v04_failclosed:
        decision = "V2_V1_INTEGRITY_NO_GO"
    elif not value_pass:
        decision = "V2_V1_C2_NO_GENERALIZATION_VALUE"
    else:
        decision = "V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS"

    result = {
        "schema":"swap5.f-romv2-v1.c2-blind-result.v1",
        "workstream":"F-ROM",
        "work_unit":"F-ROMV2-V1",
        "decision":decision,
        "training":{
            "transition_count":len(training),
            "symbols":{k:len(v) for k,v in sorted(by_symbol.items())},
            "standardization_mean":means,
            "standardization_sd":sds,
            "convex_hull_vertices":{k:len(v) for k,v in sorted(hulls.items())},
        },
        "integrity":{
            "pass":integrity_pass,
            "nonfinite_count":global_integrity["nonfinite"],
            "reconstructed_theta_bounds_failure_count":global_integrity["theta_bounds"],
            "structural_mass_failure_count":global_integrity["mass"],
            "ood_failopen_count":global_integrity["ood_failopen"],
            "v04_expected_forcing_ood_missed_count":global_integrity["v04_expected_forcing_ood_missed"],
            "v04_failclosed":v04_failclosed,
        },
        "pooled_V01_V03":{
            "c2_total_storage_error_cm":c2_total,
            "c2_cumulative_bottom_exchange_error_cm":c2_cum,
            "forcing_only_total_storage_error_cm":base_total,
            "forcing_only_cumulative_bottom_exchange_error_cm":base_cum_stats,
            "c2_terminal_bottom_flux_error_cm_per_day":qstats(pooled_c2_bflux),
            "value_screen_pass":value_pass,
        },
        "domain":{
            "total_reduced_transitions":total_reduced,
            "in_domain_nearest_neighbor_distance":qstats(pooled_nn_dist),
        },
        "by_history":per_history,
        "purpose_dependent_interpretation":{
            "application_acceptance_established":False,
            "long_term_balance_threshold_applied":False,
            "groundwater_coupling_threshold_applied":False,
            "event_threshold_applied":False,
            "rule":"V1 tests blind integrity and state-information value only. Absolute application acceptance requires separately justified thresholds and/or decision criteria frozen before later final validation.",
        },
        "production_rom_authorized":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "integrity":result["integrity"],
        "pooled_V01_V03":result["pooled_V01_V03"],
        "domain":result["domain"],
        "by_history":result["by_history"],
    },sort_keys=True))
    return 0 if decision == "V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
