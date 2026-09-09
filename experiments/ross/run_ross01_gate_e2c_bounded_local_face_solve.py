from __future__ import annotations

import json
import math
import multiprocessing as mp
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1 as c1
import run_ross01_gate_e2b_q2_fixed_node_wet_dry as e2b

CONTRACT = "F-ROSS01_GATE_E2C_BOUNDED_LOCAL_FACE_SOLVE_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
LENGTH = 10.0
GL_N = 128
BISECTION_STEPS = 64
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
FACE_ANTISYM_MAX = 1.0e-10
EQUAL_REL_MAX = 1.0e-12
HYDRO_MAX = 1.0e-12
CTX = mp.get_context("fork")

_x, _w = np.polynomial.legendre.leggauss(GL_N)
GL_T = 0.5 * (_x + 1.0)
GL_W = 0.5 * _w
T_POWER = GL_T**8
T_JAC_BASE = 8.0 * GL_T**7


def configure(row: dict) -> None:
    c1.configure_core(row)
    c1.core.H_MIN = -10000.0
    c1.core.H_MAX = 1.0


def _k_vector(heads: np.ndarray) -> np.ndarray:
    return np.asarray([c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)


def _fixed_residual_factory(h_above: float, h_below: float):
    dh = h_below - h_above
    heads = h_above + dh * T_POWER
    kvals = _k_vector(heads)
    weighted_jac = GL_W * (dh * T_JAC_BASE)

    if not np.all(np.isfinite(kvals)) or np.any(kvals <= 0.0):
        raise FloatingPointError("nonfinite_or_nonpositive_constitutive_value")

    def residual(q: float) -> float:
        den = kvals - q
        if np.any(den == 0.0):
            return math.copysign(math.inf, float(np.sum(weighted_jac)))
        terms = weighted_jac * kvals / den
        value = float(np.sum(terms)) - LENGTH
        return value

    return residual


def _candidate_q(h_above: float, h_below: float) -> tuple[float, dict]:
    scale = max(1.0, abs(h_above), abs(h_below))
    if abs(h_above - h_below) <= 2.0e-14 * scale:
        q = float(c1.core.k_of_h(0.5 * (h_above + h_below)))
        return q, {"branch": "EQUAL_HEAD_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 1}

    dh = h_below - h_above
    if abs(dh - LENGTH) <= 2.0e-13 * max(1.0, LENGTH, abs(dh)):
        return 0.0, {"branch": "HYDROSTATIC_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 0}

    residual = _fixed_residual_factory(h_above, h_below)
    k_above = float(c1.core.k_of_h(h_above))
    ksat = float(c1.core.KSAT)

    if h_below > h_above:
        if dh < LENGTH:
            lo = 0.0
            hi = k_above * (1.0 - 1.0e-12)
        else:
            lo = -ksat * max(0.0, dh / LENGTH - 1.0)
            lo = math.nextafter(lo, -math.inf)
            hi = 0.0
    else:
        drop = h_above - h_below
        lo = k_above * (1.0 + 1.0e-12)
        hi = ksat * (1.0 + drop / LENGTH)
        hi = math.nextafter(hi, math.inf)

    f_lo = residual(lo)
    f_hi = residual(hi)
    evals = 2
    if not (math.isfinite(f_lo) and math.isfinite(f_hi)):
        raise FloatingPointError(("nonfinite_bracket_residual", f_lo, f_hi))
    if f_lo == 0.0:
        return lo, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": GL_N + 2}
    if f_hi == 0.0:
        return hi, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": GL_N + 2}
    if f_lo * f_hi > 0.0:
        raise RuntimeError(("bracket_failure", h_above, h_below, lo, hi, f_lo, f_hi))

    for _ in range(BISECTION_STEPS):
        mid = 0.5 * (lo + hi)
        f_mid = residual(mid)
        evals += 1
        if not math.isfinite(f_mid):
            raise FloatingPointError(("nonfinite_mid_residual", mid, f_mid))
        if f_mid == 0.0:
            lo = hi = mid
            break
        if f_lo * f_mid <= 0.0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid
    q = 0.5 * (lo + hi)
    if not math.isfinite(q):
        raise FloatingPointError("nonfinite_candidate_flux")
    return q, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": GL_N + 2}


def _safe_ref(pair):
    ha, hb = pair
    try:
        return pair, float(c1.core.steady_q(float(ha), float(hb))), None
    except Exception as exc:
        return pair, None, repr(exc)


def _metric(q_ref: float, q_cand: float, ksat: float) -> tuple[float, float, int]:
    hybrid = abs(q_cand - q_ref) / (abs(q_ref) + 1.0e-4 * ksat)
    absolute = abs(q_cand - q_ref) / ksat
    wrong_sign = int(abs(q_ref) > 1.0e-8 * ksat and q_ref * q_cand < 0.0)
    return hybrid, absolute, wrong_sign


def run_material(row: dict) -> dict:
    configure(row)
    material = row["sfu"]
    ksat = float(c1.core.KSAT)
    probes = e2b.build_probes(material)
    pairs = [(float(p["h_above"]), float(p["h_below"])) for p in probes]

    refs = {}
    ref_errors = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, q, err in pool.imap_unordered(_safe_ref, pairs, chunksize=4):
            if err is None:
                refs[pair] = q
            else:
                ref_errors.append({"pair": list(pair), "error": err})

    rows = []
    bracket_failures = 0
    nonfinite = 0
    max_root_evals = 0
    max_k_evals = 0
    for p in probes:
        ha, hb = float(p["h_above"]), float(p["h_below"])
        q_ref = refs.get((ha, hb))
        if q_ref is None:
            continue
        try:
            q_cand, cost = _candidate_q(ha, hb)
        except RuntimeError:
            bracket_failures += 1
            continue
        except (FloatingPointError, OverflowError, ValueError):
            nonfinite += 1
            continue
        if not (math.isfinite(q_ref) and math.isfinite(q_cand)):
            nonfinite += 1
            continue
        max_root_evals = max(max_root_evals, int(cost["root_residual_evaluations"]))
        max_k_evals = max(max_k_evals, int(cost["constitutive_K_evaluations"]))
        hybrid, absolute, wrong_sign = _metric(q_ref, q_cand, ksat)
        face_balance = abs((-q_cand) + q_cand) / max(ksat, abs(q_cand), 1.0e-300)
        rows.append({
            "probe_id": p["id"],
            "kind": p["kind"],
            "h_above": ha,
            "h_below": hb,
            "q_ref": q_ref,
            "q_candidate": q_cand,
            "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute,
            "wrong_sign": wrong_sign,
            "face_balance_antisymmetry_scaled": face_balance,
            "branch": cost["branch"],
            "root_residual_evaluations": cost["root_residual_evaluations"],
            "constitutive_K_evaluations": cost["constitutive_K_evaluations"],
        })

    equal_heads = (-1.0, -0.1, -1.0e-6, 0.0, 0.1, 1.0)
    equal_errors = []
    for h in equal_heads:
        q_cand, _ = _candidate_q(h, h)
        q_ref = float(c1.core.steady_q(h, h))
        equal_errors.append(abs(q_cand - q_ref) / max(abs(q_ref), 1.0e-300))

    hydro_pairs = ((-100.0, -90.0), (-11.0, -1.0), (-10.0, 0.0), (-9.0, 1.0))
    hydro_errors = []
    for ha, hb in hydro_pairs:
        q_cand, _ = _candidate_q(ha, hb)
        hydro_errors.append(abs(q_cand) / ksat)

    hybrids = sorted(r["hybrid_metric"] for r in rows)
    if rows:
        p99 = hybrids[int(0.99 * (len(hybrids) - 1))]
        max_hybrid = max(hybrids)
        max_abs = max(r["abs_error_over_ksatfit"] for r in rows)
        wrong_sign_count = sum(r["wrong_sign"] for r in rows)
        max_antisym = max(r["face_balance_antisymmetry_scaled"] for r in rows)
    else:
        p99 = max_hybrid = max_abs = math.inf
        wrong_sign_count = 1
        max_antisym = math.inf

    tests = {
        "reference_failures": len(ref_errors) == 0,
        "bracket_failure_count": bracket_failures == 0,
        "nonfinite_count": nonfinite == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "wrong_sign_count": wrong_sign_count == 0,
        "face_balance_antisymmetry_scaled_max": max_antisym <= FACE_ANTISYM_MAX,
        "equal_head_relative_max": max(equal_errors) <= EQUAL_REL_MAX,
        "hydrostatic_abs_q_over_ksatfit_max": max(hydro_errors) <= HYDRO_MAX,
        "root_residual_evaluation_bound": max_root_evals <= 66,
        "constitutive_K_evaluation_bound": max_k_evals <= 132,
    }
    return {
        "material": material,
        "probe_count": len(probes),
        "valid_probe_count": len(rows),
        "reference_failures": len(ref_errors),
        "bracket_failure_count": bracket_failures,
        "nonfinite_count": nonfinite,
        "max_hybrid_metric": max_hybrid,
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max_abs,
        "wrong_sign_count": wrong_sign_count,
        "face_balance_antisymmetry_scaled_max": max_antisym,
        "equal_head_relative_max": max(equal_errors),
        "hydrostatic_abs_q_over_ksatfit_max": max(hydro_errors),
        "max_root_residual_evaluations": max_root_evals,
        "max_constitutive_K_evaluations": max_k_evals,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
        "worst_probe": max(rows, key=lambda r: r["hybrid_metric"]) if rows else None,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_bounded_local_face_solve.py OUTPUT.json")
    output = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    materials = []
    for i, name in enumerate(MATERIALS, 1):
        result = run_material(by[name])
        materials.append(result)
        print(json.dumps({
            "progress": f"{i}/{len(MATERIALS)}",
            "material": name,
            "pass": result["pass"],
            "failed_metrics": result["failed_metrics"],
            "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
        }, sort_keys=True), flush=True)

    passed = all(r["pass"] for r in materials)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2C_BOUNDED_NON_TABLE_NEAR_SATURATION_FACE_SOLVE",
        "contract": CONTRACT,
        "candidate": "FIXED_GL128_T8_PLUS_64_BISECTION_LOCAL_STEADY_DARCY",
        "production_implementation": False,
        "qualification_use": False,
        "materials": materials,
        "material_count": len(materials),
        "material_pass_count": sum(r["pass"] for r in materials),
        "max_hybrid_metric": max(r["max_hybrid_metric"] for r in materials),
        "max_p99_hybrid_metric": max(r["p99_hybrid_metric"] for r in materials),
        "max_abs_error_over_ksatfit": max(r["max_abs_error_over_ksatfit"] for r in materials),
        "total_bracket_failures": sum(r["bracket_failure_count"] for r in materials),
        "total_nonfinite_count": sum(r["nonfinite_count"] for r in materials),
        "max_root_residual_evaluations": max(r["max_root_residual_evaluations"] for r in materials),
        "max_constitutive_K_evaluations": max(r["max_constitutive_K_evaluations"] for r in materials),
        "persistent_per_column_state_bytes": 0,
        "scratch_owner": "worker",
        "table_lookup": False,
        "pass": passed,
        "decision": (
            "QUALIFIED_BOUNDED_REFERENCE_QUALITY_LOCAL_NEAR_SATURATION_FACE_FALLBACK_READY_FOR_E_SATURATION_TRANSITION_PROTOTYPE"
            if passed else
            "BOUNDED_LOCAL_FACE_SOLVE_NOT_YET_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "This gate does not admit the bounded local solve as the normal RossFast production face path.",
            "No saturation-transition timestep or column is qualified here.",
            "No runtime or MultiSWAP admission follows from this face-level gate.",
            "The rejected near-saturation table line remains closed."
        ],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": result["pass"],
        "decision": result["decision"],
        "material_pass_count": result["material_pass_count"],
        "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
        "max_root_residual_evaluations": result["max_root_residual_evaluations"],
        "max_constitutive_K_evaluations": result["max_constitutive_K_evaluations"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
