from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp
import numpy as np

CONTRACT = "F-ROSS01_GATE_E3E_R2R1_ENDPOINT_LIMIT_AND_INTERIOR_ROOT_ORACLE_REPAIR_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
LENGTH = mp.mpf("5")
Y_MIN = -24.0
Y_SAMPLES = 289
UPPER_SAFETY = mp.mpf("0.999999999999")
BISECTION_STEPS = 120
ENDPOINT_AGREE_CM = mp.mpf("1e-9")
ENDPOINT_CLASS_TOL_CM = mp.mpf("1e-9")
Q_AGREE_OVER_KSAT = mp.mpf("1e-9")
A_RES_TOL_CM = mp.mpf("1e-10")
B_RES_TOL_CM = mp.mpf("1e-8")
GL_N = 256

COMMON = (
    {"id": "DEEP_ZERO_SURFACE_CONTROL", "h_surface_cm": 0.0, "h_top_node_cm": -100.0},
    {"id": "NEAR_SATURATION_POSITIVE_SURFACE_CONTROL", "h_surface_cm": 0.9, "h_top_node_cm": -0.01},
)
SPECIFIC = {
    "B01": ({"id": "R2_B01_WORST_LEGACY", "h_surface_cm": 0.924612096320944, "h_top_node_cm": -0.010519765794413582, "known_legacy_q_cm_per_day": 37.0649174713324},),
    "B12": ({"id": "R1_B12_WORST", "h_surface_cm": 0.8837919082381909, "h_top_node_cm": -0.009962848502903649, "known_r1_candidate_q_cm_per_day": 2.6432032548322555, "known_inherited_reference_q_cm_per_day": 2.647350867878214},),
    "O13": ({"id": "R1_O13_WORST", "h_surface_cm": 0.7833053261466696, "h_top_node_cm": -0.013722375623542532, "known_r1_candidate_q_cm_per_day": 11.208432753954423, "known_inherited_reference_q_cm_per_day": 11.23381766750256},),
    "O14": (),
}

_XGL, _WGL = np.polynomial.legendre.leggauss(GL_N)
_TGL = 0.5 * (_XGL + 1.0)
_WTGL = 0.5 * _WGL


def mpv(value) -> mp.mpf:
    return mp.mpf(str(value))


def mp_k(h: mp.mpf, row: dict) -> mp.mpf:
    h = mp.mpf(h)
    ks = mpv(row["ksatfit_cm_per_day"])
    if h >= 0:
        return ks
    alpha = mpv(row["alpha_per_cm"])
    n = mpv(row["n"])
    m = 1 - 1 / n
    lam = mpv(row["lambda"])
    se = (1 + abs(alpha * h) ** n) ** (-m)
    term = (1 - se ** (1 / m)) ** m
    return ks * se ** lam * (1 - term) ** 2


def saturated_part(hs: mp.mpf, q: mp.mpf, ks: mp.mpf) -> mp.mpf:
    if hs <= 0:
        return mp.mpf("0")
    return (-hs) * ks / (ks - q)


def path_a(hs: mp.mpf, ht: mp.mpf, q: mp.mpf, row: dict) -> mp.mpf:
    """100-digit adaptive t^8 endpoint-regularized path."""
    with mp.workdps(100):
        ks = mpv(row["ksatfit_cm_per_day"])
        sat = saturated_part(hs, q, ks)
        if ht >= 0:
            return +sat

        power = 8

        def f(t):
            t = mp.mpf(t)
            if t == 0:
                # For the four frozen materials n<2 and power=8 makes the
                # transformed q=KSAT endpoint singularity integrable with a
                # zero point limit. A single endpoint value does not affect
                # the integral but prevents 0/0 evaluation.
                return mp.mpf("0")
            h = ht * t ** power
            dhdt = ht * power * t ** (power - 1)
            k = mp_k(h, row)
            return dhdt * k / (k - q)

        # Multiple fixed subintervals keep the adaptive method from treating
        # the whole transformed interval as one smooth panel.
        unsat = mp.quad(f, [mp.mpf("0"), mp.mpf("0.01"), mp.mpf("0.1"), mp.mpf("0.5"), mp.mpf("1")])
        return +(sat + unsat)


def setup_b(ht: mp.mpf, row: dict):
    """60-digit fixed GL256 representation with an independent t^12 map."""
    with mp.workdps(60):
        power = 12
        terms = []
        for td, wd in zip(_TGL, _WTGL):
            t = mp.mpf(repr(float(td)))
            w = mp.mpf(repr(float(wd)))
            h = ht * t ** power
            dhdt = ht * power * t ** (power - 1)
            terms.append((w * dhdt, mp_k(h, row)))
        return terms


def path_b(hs: mp.mpf, q: mp.mpf, row: dict, setup) -> mp.mpf:
    with mp.workdps(60):
        ks = mpv(row["ksatfit_cm_per_day"])
        sat = saturated_part(hs, q, ks)
        unsat = mp.fsum(weight * k / (k - q) for weight, k in setup)
        return +(sat + unsat)


def endpoint_path_a(ht: mp.mpf, row: dict) -> mp.mpf:
    return path_a(mp.mpf("0"), ht, mpv(row["ksatfit_cm_per_day"]), row)


def endpoint_path_b(ht: mp.mpf, row: dict, setup) -> mp.mpf:
    return path_b(mp.mpf("0"), mpv(row["ksatfit_cm_per_day"]), row, setup)


def endpoint_class(length_value: mp.mpf) -> str:
    if length_value < LENGTH - ENDPOINT_CLASS_TOL_CM:
        return "ENDPOINT_KSAT_PLATEAU"
    if abs(length_value - LENGTH) <= ENDPOINT_CLASS_TOL_CM:
        return "ENDPOINT_KSAT_EXACT"
    return "INTERIOR_ROOT"


def q_from_y(y: mp.mpf, ks: mp.mpf) -> mp.mpf:
    return ks * (1 + mp.power(10, y))


def scan_bracket(residual, y_hi: mp.mpf):
    y_lo = mp.mpf(str(Y_MIN))
    if y_hi <= y_lo:
        raise RuntimeError(("invalid_logdelta_domain", str(y_lo), str(y_hi)))
    prev_y = y_lo
    prev_f = residual(prev_y)
    if not mp.isfinite(prev_f):
        raise RuntimeError(("nonfinite_low_scan_residual", str(prev_f)))
    for i in range(1, Y_SAMPLES):
        y = y_lo + (y_hi - y_lo) * mp.mpf(i) / mp.mpf(Y_SAMPLES - 1)
        f = residual(y)
        if not mp.isfinite(f):
            raise RuntimeError(("nonfinite_scan_residual", i, str(y), str(f)))
        if f == 0:
            return y, y, f, f
        if prev_f * f < 0:
            return prev_y, y, prev_f, f
        prev_y, prev_f = y, f
    raise RuntimeError(("no_logdelta_sign_change", str(y_lo), str(y_hi), str(prev_f)))


def solve_interior_a(hs: mp.mpf, ht: mp.mpf, row: dict):
    with mp.workdps(100):
        ks = mpv(row["ksatfit_cm_per_day"])
        delta_upper = (hs - ht) / LENGTH
        y_hi = mp.log10(delta_upper * UPPER_SAFETY)

        def ry(y):
            return path_a(hs, ht, q_from_y(y, ks), row) - LENGTH

        lo, hi, flo, fhi = scan_bracket(ry, y_hi)
        if lo == hi:
            y = lo
        else:
            for _ in range(BISECTION_STEPS):
                mid = (lo + hi) / 2
                fm = ry(mid)
                if flo * fm <= 0:
                    hi, fhi = mid, fm
                else:
                    lo, flo = mid, fm
            y = (lo + hi) / 2
        q = q_from_y(y, ks)
        residual = path_a(hs, ht, q, row) - LENGTH
        return +q, +y, +residual


def solve_interior_b(hs: mp.mpf, ht: mp.mpf, row: dict, setup):
    with mp.workdps(60):
        ks = mpv(row["ksatfit_cm_per_day"])
        delta_upper = (hs - ht) / LENGTH
        y_hi = mp.log10(delta_upper * UPPER_SAFETY)

        def ry(y):
            return path_b(hs, q_from_y(y, ks), row, setup) - LENGTH

        lo, hi, flo, fhi = scan_bracket(ry, y_hi)
        if lo == hi:
            y = lo
        else:
            for _ in range(BISECTION_STEPS):
                mid = (lo + hi) / 2
                fm = ry(mid)
                if flo * fm <= 0:
                    hi, fhi = mid, fm
                else:
                    lo, flo = mid, fm
            y = (lo + hi) / 2
        q = q_from_y(y, ks)
        residual = path_b(hs, q, row, setup) - LENGTH
        return +q, +y, +residual


def known_residuals(witness: dict, hs: mp.mpf, ht: mp.mpf, row: dict, setup):
    rows = {}
    for key in ("known_legacy_q_cm_per_day", "known_inherited_reference_q_cm_per_day", "known_r1_candidate_q_cm_per_day"):
        if key not in witness:
            continue
        q = mpv(witness[key])
        rows[key] = {
            "oracle_a_path_residual_cm": float(path_a(hs, ht, q, row) - LENGTH),
            "oracle_b_path_residual_cm": float(path_b(hs, q, row, setup) - LENGTH),
        }
    return rows


def evaluate(witness: dict, row: dict) -> dict:
    hs = mpv(witness["h_surface_cm"])
    ht = mpv(witness["h_top_node_cm"])
    ks = mpv(row["ksatfit_cm_per_day"])
    setup = setup_b(ht, row)
    q_upper = ks * (1 + (hs - ht) / LENGTH)

    endpoint_a = endpoint_b = None
    plateau_a = plateau_b = None
    if hs == 0:
        endpoint_a = endpoint_path_a(ht, row)
        endpoint_b = endpoint_path_b(ht, row, setup)
        class_a = endpoint_class(endpoint_a)
        class_b = endpoint_class(endpoint_b)
    else:
        class_a = class_b = "INTERIOR_ROOT"

    same_class = class_a == class_b
    if not same_class:
        return {
            "id": witness["id"], "h_surface_cm": float(hs), "h_top_node_cm": float(ht),
            "branch_classification_oracle_a": class_a,
            "branch_classification_oracle_b": class_b,
            "endpoint_path_length_oracle_a_cm": None if endpoint_a is None else float(endpoint_a),
            "endpoint_path_length_oracle_b_cm": None if endpoint_b is None else float(endpoint_b),
            "pass": False,
            "failure": "endpoint_branch_classification_disagreement",
        }

    branch = class_a
    if branch.startswith("ENDPOINT_KSAT"):
        qa = qb = ks
        ya = yb = None
        ra = rb = mp.mpf("0")
        plateau_a = max(mp.mpf("0"), LENGTH - endpoint_a)
        plateau_b = max(mp.mpf("0"), LENGTH - endpoint_b)
    else:
        qa, ya, ra = solve_interior_a(hs, ht, row)
        qb, yb, rb = solve_interior_b(hs, ht, row, setup)

    endpoint_diff = mp.mpf("0") if endpoint_a is None else abs(endpoint_a - endpoint_b)
    q_diff = abs(qa - qb) / ks
    plateau_diff = mp.mpf("0") if plateau_a is None else abs(plateau_a - plateau_b)
    finite = all(mp.isfinite(v) for v in (qa, qb, ra, rb, q_upper))
    tests = {
        "same_branch_classification": same_class,
        "endpoint_path_agreement": endpoint_diff <= ENDPOINT_AGREE_CM,
        "q_agreement": q_diff <= Q_AGREE_OVER_KSAT,
        "oracle_a_path_residual": abs(ra) <= A_RES_TOL_CM,
        "oracle_b_path_residual": abs(rb) <= B_RES_TOL_CM,
        "plateau_agreement": plateau_diff <= ENDPOINT_AGREE_CM,
        "finite": finite,
        "q_not_above_saturated_darcy_upper": qa <= q_upper * (1 + mp.mpf("1e-20")) and qb <= q_upper * (1 + mp.mpf("1e-20")),
        "interior_strictly_above_ksat": branch.startswith("ENDPOINT_KSAT") or (qa > ks and qb > ks),
    }
    return {
        "id": witness["id"],
        "h_surface_cm": float(hs),
        "h_top_node_cm": float(ht),
        "branch_classification": branch,
        "endpoint_path_length_oracle_a_cm": None if endpoint_a is None else float(endpoint_a),
        "endpoint_path_length_oracle_b_cm": None if endpoint_b is None else float(endpoint_b),
        "endpoint_path_length_difference_cm": float(endpoint_diff),
        "saturated_plateau_length_oracle_a_cm": None if plateau_a is None else float(plateau_a),
        "saturated_plateau_length_oracle_b_cm": None if plateau_b is None else float(plateau_b),
        "q_oracle_a_cm_per_day": float(qa),
        "q_oracle_b_cm_per_day": float(qb),
        "q_saturated_darcy_upper_cm_per_day": float(q_upper),
        "oracle_pair_abs_error_over_ksat": float(q_diff),
        "log10_delta_oracle_a": None if ya is None else float(ya),
        "log10_delta_oracle_b": None if yb is None else float(yb),
        "oracle_a_path_residual_cm": float(ra),
        "oracle_b_path_residual_cm": float(rb),
        "known_q_path_residuals": known_residuals(witness, hs, ht, row, setup),
        "tests": tests,
        "pass": all(tests.values()),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2r1_endpoint_limit_oracle_repair.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    witnesses = [dict(w) for w in COMMON] + [dict(w) for w in SPECIFIC[material]]
    results = []
    for witness in witnesses:
        try:
            result = evaluate(witness, row)
        except Exception as exc:
            result = {
                "id": witness["id"],
                "h_surface_cm": witness["h_surface_cm"],
                "h_top_node_cm": witness["h_top_node_cm"],
                "pass": False,
                "error": repr(exc),
            }
        results.append(result)
        print(json.dumps({
            "material": material,
            "id": result["id"],
            "pass": result["pass"],
            "branch": result.get("branch_classification"),
            "q_pair_error_over_ksat": result.get("oracle_pair_abs_error_over_ksat"),
            "endpoint_path_difference_cm": result.get("endpoint_path_length_difference_cm"),
            "error": result.get("error"),
        }, sort_keys=True), flush=True)

    passed = all(r["pass"] for r in results)
    endpoint_count = sum(str(r.get("branch_classification", "")).startswith("ENDPOINT_KSAT") for r in results)
    interior_count = sum(r.get("branch_classification") == "INTERIOR_ROOT" for r in results)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_R2R1_ENDPOINT_LIMIT_AND_INTERIOR_ROOT_ORACLE_REPAIR",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_target": "REFERENCE_ORACLE_NUMERICS_ONLY",
        "results": results,
        "endpoint_branch_count": endpoint_count,
        "interior_root_count": interior_count,
        "pass": passed,
        "decision": (
            "QUALIFIED_ENDPOINT_LIMIT_AWARE_REFERENCE_ORACLE_WITNESSES_READY_FOR_FRESH_5CM_REFERENCE_CHARACTERIZATION"
            if passed else
            "ENDPOINT_LIMIT_AWARE_ORACLES_DISAGREE_OR_UNRESOLVED_FURTHER_ORACLE_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No Ross candidate-face qualification.",
            "No inherited steady_q qualification outside frozen witnesses.",
            "No finite-positive ponding, runoff, production, runtime or MultiSWAP admission.",
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"material": material, "pass": passed, "decision": payload["decision"], "endpoint_branch_count": endpoint_count, "interior_root_count": interior_count}, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
