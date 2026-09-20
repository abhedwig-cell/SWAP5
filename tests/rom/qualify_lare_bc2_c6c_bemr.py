#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares
from scipy.special import expit, logit

THETA_R = 0.01
THETA_S = 0.416774
DELTA_THETA = THETA_S - THETA_R
ALPHA = 0.00541
N_VG = 1.301528
M_VG = 1.0 - 1.0 / N_VG
KS = 0.895023
LAMBDA = -0.334926

SE_LO = 0.02
SE_HI = 0.995
SE_SPAN = SE_HI - SE_LO

GL96_X, GL96_W = np.polynomial.legendre.leggauss(96)
GL192_X, GL192_W = np.polynomial.legendre.leggauss(192)


def theta_from_se(se):
    return THETA_R + DELTA_THETA * np.asarray(se, dtype=float)


def se_from_theta(theta):
    return (np.asarray(theta, dtype=float) - THETA_R) / DELTA_THETA


def psi_from_theta(theta):
    se = se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se <= 0.0) or np.any(se >= 1.0):
        raise ValueError("theta outside inverse-retention domain")
    a = np.power(se, -1.0 / M_VG) - 1.0
    return np.power(a, 1.0 / N_VG) / ALPHA


def dpsi_dtheta(theta):
    se = se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se <= 0.0) or np.any(se >= 1.0):
        raise ValueError("theta outside inverse-retention derivative domain")
    a = np.power(se, -1.0 / M_VG) - 1.0
    da = -(1.0 / M_VG) * np.power(se, -1.0 / M_VG - 1.0)
    dpsi_dse = (1.0 / ALPHA) * (1.0 / N_VG) * np.power(a, 1.0 / N_VG - 1.0) * da
    return dpsi_dse / DELTA_THETA


def k_from_theta(theta):
    se = se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se <= 0.0) or np.any(se >= 1.0):
        raise ValueError("theta outside conductivity domain")
    term = 1.0 - np.power(1.0 - np.power(se, 1.0 / M_VG), M_VG)
    k = KS * np.power(se, LAMBDA) * np.square(term)
    if np.any(~np.isfinite(k)) or np.any(k <= 0.0):
        raise ValueError("nonpositive/nonfinite conductivity")
    return k


def p2(x):
    x = np.asarray(x, dtype=float)
    return 0.5 * (3.0 * x * x - 1.0)


def p3(x):
    x = np.asarray(x, dtype=float)
    return 0.5 * (5.0 * x * x * x - 3.0 * x)


def dp2(x):
    return 3.0 * np.asarray(x, dtype=float)


def dp3(x):
    x = np.asarray(x, dtype=float)
    return 1.5 * (5.0 * x * x - 1.0)


def dual_poly(coeff, xi):
    b0, b1, b2, b3 = coeff
    xi = np.asarray(xi, dtype=float)
    return b0 + b1 * xi + b2 * p2(xi) + b3 * p3(xi)


def ddual_dxi(coeff, xi):
    _, b1, b2, b3 = coeff
    xi = np.asarray(xi, dtype=float)
    return b1 + b2 * dp2(xi) + b3 * dp3(xi)


def se_profile(coeff, xi):
    return SE_LO + SE_SPAN * expit(dual_poly(coeff, xi))


def theta_profile(coeff, xi):
    return theta_from_se(se_profile(coeff, xi))


def dtheta_dz(coeff, xi, d):
    xi = np.asarray(xi, dtype=float)
    v = dual_poly(coeff, xi)
    y = expit(v)
    dse_dv = SE_SPAN * y * (1.0 - y)
    dse_dz = dse_dv * (2.0 / float(d)) * ddual_dxi(coeff, xi)
    return DELTA_THETA * dse_dz


def face_state(coeff, d, xi):
    th = float(theta_profile(coeff, xi))
    se = float(se_from_theta(th))
    if not (math.isfinite(se) and SE_LO - 1e-14 <= se <= SE_HI + 1e-14):
        raise ValueError("entropy map left constitutive qualification domain")
    psi = float(psi_from_theta(th))
    dpsidz = float(dpsi_dtheta(th)) * float(dtheta_dz(coeff, xi, d))
    k = float(k_from_theta(th))
    q = k * (1.0 + dpsidz)
    if not all(math.isfinite(v) for v in (psi, dpsidz, k, q)):
        raise ValueError("nonfinite face hydraulic state")
    return {"theta": th, "se": se, "psi": psi, "q": q}


def mmax_full(se, d):
    return 0.5 * DELTA_THETA * d * d * se * (1.0 - se)


def mmax_bounded(se, d):
    if not (SE_LO <= se <= SE_HI):
        return -math.inf
    shape = ((se - SE_LO) * (SE_HI - se)) / SE_SPAN
    return 0.5 * DELTA_THETA * d * d * shape


def moment_values(pattern, nlayers, ses, widths):
    mode = pattern["mode"]
    if mode == "uniform_mu":
        mus = [float(pattern["mu"])] * nlayers
    elif mode == "alternating":
        a = float(pattern["mu_abs"])
        mus = [a if i % 2 == 0 else -a for i in range(nlayers)]
    elif mode == "bottom_focused":
        mus = [0.0] * nlayers
        n = int(pattern["layers_from_bottom"])
        for i in range(max(0, nlayers - n), nlayers):
            mus[i] = float(pattern["mu"])
    elif mode == "linear_mu":
        a = float(pattern["mu_top"])
        b = float(pattern["mu_bottom"])
        mus = [a + (b - a) * i / (nlayers - 1) if nlayers > 1 else 0.5 * (a + b)
                for i in range(nlayers)]
    else:
        raise ValueError(mode)
    return [mu * mmax_full(se, d) for mu, se, d in zip(mus, ses, widths)], mus


def profile_se(profile, nlayers):
    mode = profile["mode"]
    if mode == "uniform":
        return [float(profile["Se"])] * nlayers
    if mode == "linear":
        a = float(profile["Se_top"])
        b = float(profile["Se_bottom"])
        return [a + (b - a) * i / (nlayers - 1) if nlayers > 1 else 0.5 * (a + b)
                for i in range(nlayers)]
    if mode == "piecewise":
        bulk = float(profile["Se_bulk"])
        bot = float(profile["Se_bottom"])
        out = [bulk] * nlayers
        out[-1] = bot
        if nlayers >= 2:
            out[-2] = 0.5 * (bulk + bot)
        return out
    raise ValueError(mode)


def build_case(partition_name, bounds, profile, pattern, boundary):
    widths = [float(b - a) for a, b in zip(bounds, bounds[1:])]
    ses = profile_se(profile, len(widths))
    means = [float(theta_from_se(se)) for se in ses]
    storages = [mean * d for mean, d in zip(means, widths)]
    moments, mus = moment_values(pattern, len(widths), ses, widths)
    psi_bottom_mean = float(psi_from_theta(means[-1]))
    psi_bottom = float(boundary["bottom_head_multiplier"]) * psi_bottom_mean
    qtop = float(k_from_theta(means[0]))
    return {
        "partition": partition_name,
        "profile": profile["id"],
        "moment_pattern": pattern["id"],
        "boundary": boundary["id"],
        "bounds": bounds,
        "widths": widths,
        "ses": ses,
        "means": means,
        "storages": storages,
        "moments": moments,
        "mus": mus,
        "psi_bottom": psi_bottom,
        "qtop": qtop,
    }


def layer_state(coeff, d, quad_x=GL96_X, quad_w=GL96_W):
    th = theta_profile(coeff, quad_x)
    storage = 0.5 * d * float(np.dot(quad_w, th))
    moment = 0.25 * d * d * float(np.dot(quad_w, quad_x * th))
    return storage, moment


def residual_vector(x, case, prereg):
    n = len(case["widths"])
    penalty = float(prereg["numerical_contract"]["invalid_trial_handling"]["penalty_scaled_residual"])
    scales = prereg["numerical_contract"]["residual_scaling"]
    pscale = float(scales["interface_pressure_cm"])
    qscale = float(scales["interface_flux_cm_per_day"])
    bpscale = max(1.0, abs(case["psi_bottom"]))
    try:
        coeffs = [np.asarray(x[4 * i:4 * i + 4], dtype=float) for i in range(n)]
        if any(np.any(~np.isfinite(c)) for c in coeffs):
            return np.full(4 * n, penalty, dtype=float)
        r = []
        top = []
        bottom = []
        for coeff, d, starget, mtarget in zip(
                coeffs, case["widths"], case["storages"], case["moments"]):
            srec, mrec = layer_state(coeff, d)
            r.append((srec - starget) / max(1e-12, DELTA_THETA * d))
            r.append((mrec - mtarget) / max(1e-12, DELTA_THETA * d * d))
            top.append(face_state(coeff, d, -1.0))
            bottom.append(face_state(coeff, d, 1.0))
        for i in range(n - 1):
            r.append((bottom[i]["psi"] - top[i + 1]["psi"]) / pscale)
            r.append((bottom[i]["q"] - top[i + 1]["q"]) / qscale)
        r.append((top[0]["q"] - case["qtop"]) / float(scales["top_flux_cm_per_day"]))
        r.append((bottom[-1]["psi"] - case["psi_bottom"]) / bpscale)
        arr = np.asarray(r, dtype=float)
        if arr.shape != (4 * n,) or np.any(~np.isfinite(arr)):
            return np.full(4 * n, penalty, dtype=float)
        return arr
    except (ValueError, FloatingPointError, OverflowError):
        return np.full(4 * n, penalty, dtype=float)


def physical_diagnostics(x, case, prereg):
    n = len(case["widths"])
    coeffs = [np.asarray(x[4 * i:4 * i + 4], dtype=float) for i in range(n)]
    sample_n = int(prereg["numerical_contract"]["admissibility_sampling_points_per_layer"])
    xis = np.linspace(-1.0, 1.0, sample_n)
    all_theta = []
    all_se = []
    top = []
    bottom = []
    storage_errors = []
    moment_errors = []
    quad_storage_deltas = []
    quad_moment_deltas = []
    for coeff, d, starget, mtarget in zip(
            coeffs, case["widths"], case["storages"], case["moments"]):
        vals = theta_profile(coeff, xis)
        ses = se_from_theta(vals)
        all_theta.extend(np.asarray(vals).tolist())
        all_se.extend(np.asarray(ses).tolist())
        top.append(face_state(coeff, d, -1.0))
        bottom.append(face_state(coeff, d, 1.0))
        s96, m96 = layer_state(coeff, d, GL96_X, GL96_W)
        s192, m192 = layer_state(coeff, d, GL192_X, GL192_W)
        storage_errors.append(abs(s192 - starget))
        moment_errors.append(abs(m192 - mtarget))
        quad_storage_deltas.append(abs(s192 - s96))
        quad_moment_deltas.append(abs(m192 - m96))
    pressure_jumps = [bottom[i]["psi"] - top[i + 1]["psi"] for i in range(n - 1)]
    flux_jumps = [bottom[i]["q"] - top[i + 1]["q"] for i in range(n - 1)]
    return {
        "coeffs": [c.tolist() for c in coeffs],
        "theta_min": float(np.min(all_theta)),
        "theta_max": float(np.max(all_theta)),
        "Se_min": float(np.min(all_se)),
        "Se_max": float(np.max(all_se)),
        "max_abs_interface_pressure_jump_cm": max([abs(v) for v in pressure_jumps] or [0.0]),
        "max_abs_interface_flux_jump_cm_per_day": max([abs(v) for v in flux_jumps] or [0.0]),
        "abs_top_flux_residual_cm_per_day": abs(top[0]["q"] - case["qtop"]),
        "abs_bottom_pressure_residual_cm": abs(bottom[-1]["psi"] - case["psi_bottom"]),
        "max_abs_storage_recovery_cm": max(storage_errors or [0.0]),
        "max_abs_moment_recovery_cm2": max(moment_errors or [0.0]),
        "max_abs_96_192_storage_delta_cm": max(quad_storage_deltas or [0.0]),
        "max_abs_96_192_moment_delta_cm2": max(quad_moment_deltas or [0.0]),
        "top_faces": top,
        "bottom_faces": bottom,
    }


def solution_distance(a, b, case, prereg):
    sample_n = int(prereg["numerical_contract"]["admissibility_sampling_points_per_layer"])
    xis = np.linspace(-1.0, 1.0, sample_n)
    max_theta = 0.0
    max_psi = 0.0
    max_q = 0.0
    for i, d in enumerate(case["widths"]):
        ca = np.asarray(a[4 * i:4 * i + 4], dtype=float)
        cb = np.asarray(b[4 * i:4 * i + 4], dtype=float)
        max_theta = max(max_theta, float(np.max(np.abs(theta_profile(ca, xis) - theta_profile(cb, xis)))))
        for xi in (-1.0, 1.0):
            fa = face_state(ca, d, xi)
            fb = face_state(cb, d, xi)
            max_psi = max(max_psi, abs(fa["psi"] - fb["psi"]))
            max_q = max(max_q, abs(fa["q"] - fb["q"]))
    return max_theta, max_psi, max_q


def condition_number(result):
    try:
        s = np.linalg.svd(result.jac, compute_uv=False)
        if len(s) == 0 or s[-1] <= 0.0:
            return math.inf
        return float(s[0] / s[-1])
    except Exception:
        return math.inf


def base_coeff_for_layer(se, M, d):
    ybar = (se - SE_LO) / SE_SPAN
    if not (0.0 < ybar < 1.0):
        raise ValueError("mean Se outside entropy interval")
    b0 = float(logit(ybar))
    j = 2.0 * float(M) / (DELTA_THETA * d * d)
    denom = SE_SPAN * ybar * (1.0 - ybar)
    b1 = 3.0 * j / denom if denom > 0.0 else 0.0
    return np.array([b0, b1, 0.0, 0.0], dtype=float)


def starts_for_case(case, prereg):
    base = np.concatenate([
        base_coeff_for_layer(se, M, d)
        for se, M, d in zip(case["ses"], case["moments"], case["widths"])
    ])
    out = []
    for spec in prereg["numerical_contract"]["fixed_initial_starts"]:
        x = base.copy()
        x[2::4] += float(spec["p2_dual_delta"])
        x[3::4] += float(spec["p3_dual_delta"])
        out.append((spec["id"], x))
    return out


def moment_bound_gate(case):
    for se, M, d in zip(case["ses"], case["moments"], case["widths"]):
        if abs(M) > mmax_bounded(se, d) + 1e-12:
            return False
    return True


def qualify_case(case, prereg):
    opts = prereg["numerical_contract"]["solver_options"]
    starts = starts_for_case(case, prereg)
    solutions = []
    runs = []
    for sid, x0 in starts:
        res = least_squares(
            lambda x: residual_vector(x, case, prereg),
            x0,
            method="trf",
            xtol=float(opts["xtol"]),
            ftol=float(opts["ftol"]),
            gtol=float(opts["gtol"]),
            max_nfev=int(opts["max_nfev"]),
        )
        row = {
            "start": sid,
            "success": bool(res.success),
            "status": int(res.status),
            "nfev": int(res.nfev),
            "cost": float(res.cost),
            "optimality": float(res.optimality),
            "message": str(res.message),
            "condition_number": condition_number(res),
        }
        try:
            diag = physical_diagnostics(res.x, case, prereg)
            row["diagnostics"] = {k: v for k, v in diag.items() if k not in ("coeffs", "top_faces", "bottom_faces")}
            solutions.append((sid, res.x.copy(), diag))
        except (ValueError, FloatingPointError, OverflowError) as exc:
            row["diagnostic_error"] = str(exc)
        runs.append(row)

    gates = prereg["numerical_contract"]["physical_residual_gates"]
    agreement = prereg["numerical_contract"]["solution_agreement_across_starts"]
    qgate = prereg["numerical_contract"]["quadrature_consistency_gates"]
    all_converged = len(solutions) == len(starts) and all(r["success"] for r in runs)
    all_admissible = False
    hydraulic = False
    state_recovery = False
    quadrature_consistent = False
    unique = False
    max_pair_theta = 0.0
    max_pair_psi = 0.0
    max_pair_q = 0.0

    if len(solutions) == len(runs) and solutions:
        all_admissible = all(
            SE_LO - 1e-14 <= d["Se_min"] and d["Se_max"] <= SE_HI + 1e-14
            for _, _, d in solutions
        )
        hydraulic = all(
            d["max_abs_interface_pressure_jump_cm"] <= float(gates["max_abs_interface_pressure_jump_cm"])
            and d["max_abs_interface_flux_jump_cm_per_day"] <= float(gates["max_abs_interface_flux_jump_cm_per_day"])
            and d["abs_top_flux_residual_cm_per_day"] <= float(gates["max_abs_top_flux_residual_cm_per_day"])
            and d["abs_bottom_pressure_residual_cm"] <= float(gates["max_abs_bottom_pressure_residual_cm"])
            for _, _, d in solutions
        )
        state_recovery = all(
            d["max_abs_storage_recovery_cm"] <= float(gates["max_abs_storage_recovery_cm"])
            and d["max_abs_moment_recovery_cm2"] <= float(gates["max_abs_moment_recovery_cm2"])
            for _, _, d in solutions
        )
        quadrature_consistent = all(
            d["max_abs_96_192_storage_delta_cm"] <= float(qgate["max_abs_storage_delta_cm"])
            and d["max_abs_96_192_moment_delta_cm2"] <= float(qgate["max_abs_moment_delta_cm2"])
            for _, _, d in solutions
        )
        unique = True
        for i in range(len(solutions)):
            for k in range(i + 1, len(solutions)):
                dt, dp, dq = solution_distance(solutions[i][1], solutions[k][1], case, prereg)
                max_pair_theta = max(max_pair_theta, dt)
                max_pair_psi = max(max_pair_psi, dp)
                max_pair_q = max(max_pair_q, dq)
                if not (
                    dt <= float(agreement["max_abs_theta_difference"])
                    and dp <= float(agreement["max_abs_face_pressure_difference_cm"])
                    and dq <= float(agreement["max_abs_face_flux_difference_cm_per_day"])
                ):
                    unique = False

    return {
        "id": "|".join([case["partition"], case["profile"], case["moment_pattern"], case["boundary"]]),
        "partition": case["partition"],
        "profile": case["profile"],
        "moment_pattern": case["moment_pattern"],
        "boundary": case["boundary"],
        "moment_bound_gate": moment_bound_gate(case),
        "all_starts_converged": all_converged,
        "unique_numerical_branch": unique,
        "theta_admissible": all_admissible,
        "hydraulic_continuity": hydraulic,
        "state_recovery": state_recovery,
        "quadrature_consistency": quadrature_consistent,
        "max_pair_theta_difference": max_pair_theta,
        "max_pair_face_pressure_difference_cm": max_pair_psi,
        "max_pair_face_flux_difference_cm_per_day": max_pair_q,
        "runs": runs,
    }


def build_cases(prereg):
    dom = prereg["synthetic_domain"]
    cases = []
    for pname, bounds in dom["partitions"].items():
        for profile in dom["mean_Se_profiles"]:
            for pattern in dom["moment_patterns"]:
                for boundary in dom["boundary_cases"]:
                    cases.append(build_case(pname, bounds, profile, pattern, boundary))
    return cases


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--c6b", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    a = ap.parse_args()

    p = json.loads(a.prereg.read_text())
    b = json.loads(a.c6b.read_text())
    assert p["phase"] == "PREREGISTERED_BEFORE_BEMR_NUMERICAL_RESPONSE"
    assert b["decision"] == "PREREGISTER_BOUNDED_ENTROPY_MOMENT_RECONSTRUCTION_ON_UNCHANGED_C5Z_DOMAIN_BEFORE_ANY_HYDROLOGICAL_RESPONSE"
    assert p["scientific_firewall"]["hydrological_response_used"] is False
    assert p["reconstruction"]["Se_lower"] == SE_LO
    assert p["reconstruction"]["Se_upper"] == SE_HI

    cases = build_cases(p)
    rows = [qualify_case(case, p) for case in cases]
    gates = {
        "G1_STRICT_STATE_MOMENT_REALIZABILITY": all(r["moment_bound_gate"] for r in rows),
        "G2_ALL_CASES_CONVERGE": all(r["all_starts_converged"] for r in rows),
        "G3_UNIQUE_NUMERICAL_BRANCH": all(r["unique_numerical_branch"] for r in rows),
        "G4_BOUNDED_REALIZABILITY": all(r["theta_admissible"] for r in rows),
        "G5_HYDRAULIC_CONTINUITY": all(r["hydraulic_continuity"] for r in rows),
        "G6_STATE_RECOVERY": all(r["state_recovery"] for r in rows),
        "G7_QUADRATURE_CONSISTENCY": all(r["quadrature_consistency"] for r in rows),
        "G8_NO_RESPONSE_DATA": True,
    }

    if all(gates.values()):
        status = "C6C_BEMR_MATHEMATICALLY_QUALIFIED"
    elif gates["G1_STRICT_STATE_MOMENT_REALIZABILITY"] and gates["G4_BOUNDED_REALIZABILITY"]:
        status = "C6C_BEMR_NUMERICALLY_NONUNIQUE_OR_HYDRAULICALLY_INADMISSIBLE"
    else:
        status = "C6C_BEMR_STATE_DOMAIN_NOT_REALIZABLE"

    def count(key):
        return sum(bool(r[key]) for r in rows)

    conds = []
    for r in rows:
        for run in r["runs"]:
            if math.isfinite(run["condition_number"]):
                conds.append(run["condition_number"])

    out = {
        "schema": "swap5.lare.bc2.c6c.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C6C",
        "status": status,
        "role": "NO_HYDROLOGICAL_RESPONSE_BEMR_MATHEMATICAL_QUALIFICATION",
        "case_count": len(rows),
        "gates": gates,
        "qualification_counts": {
            "moment_bound_pass": count("moment_bound_gate"),
            "all_starts_converged": count("all_starts_converged"),
            "unique_numerical_branch": count("unique_numerical_branch"),
            "theta_admissible": count("theta_admissible"),
            "hydraulic_continuity": count("hydraulic_continuity"),
            "state_recovery": count("state_recovery"),
            "quadrature_consistency": count("quadrature_consistency"),
        },
        "conditioning": {
            "finite_jacobian_condition_count": len(conds),
            "median_condition_number": float(np.median(conds)) if conds else None,
            "max_condition_number": max(conds) if conds else None,
            "hard_gate": False,
        },
        "cases": rows,
        "scientific_firewall": {
            "hydrological_response_used": False,
            "model_run_executed": False,
            "moment_state_implemented_in_hydrological_model": False,
            "moment_localization_selected": False,
            "response_based_profile_fit": False,
            "c5z_post_result_retuning": False,
            "application_acceptance_adjudicated": False,
            "performance_comparison_authorized": False,
            "speed_claim_authorized": False,
            "production_rom_authorized": False,
        },
    }
    a.output.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "status": status,
        "case_count": len(rows),
        "gates": gates,
        "counts": out["qualification_counts"],
        "conditioning": out["conditioning"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
