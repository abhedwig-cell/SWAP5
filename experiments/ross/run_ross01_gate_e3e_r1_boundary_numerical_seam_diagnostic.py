from __future__ import annotations

import json
import math
import multiprocessing as mp
import sys
from collections import Counter
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e2c_bounded_local_face_solve as e2c
import run_ross01_gate_e2c_r1_segmented_local_face as r1
import run_ross01_gate_e3e_5cm_surface_boundary_face as e3e

CONTRACT = "F-ROSS01_GATE_E3E_R1_BOUNDARY_NUMERICAL_SEAM_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = e3e.MATERIALS
LENGTH = 5.0
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
CTX = mp.get_context("fork")

_t8 = 0.5 * (r1._x8 + 1.0)
_wt8 = 0.5 * r1._w8


def safe_ref(pair):
    hs, ht = pair
    try:
        return pair, float(e2c.c1.core.steady_q(float(hs), float(ht))), None
    except Exception as exc:
        return pair, None, repr(exc)


def zero_adjacent_residual_factory(h_above: float, h_below: float):
    lo = min(h_above, h_below)
    hi = max(h_above, h_below)
    points = [float(h_above), float(h_below)]
    if lo < 0.0 < hi or lo == 0.0 or hi == 0.0:
        points.append(0.0)
    for value in r1.LOG_BREAKS:
        if lo < value < hi:
            points.append(value)
    ordered = r1._unique_sorted(points)
    if h_above > h_below:
        ordered = list(reversed(ordered))
    if len(ordered) - 1 > r1.MAX_SEGMENTS:
        raise RuntimeError(("segment_bound_exceeded", len(ordered) - 1))

    all_k = []
    all_w = []
    zero_clustered_segments = 0
    for a, b in zip(ordered[:-1], ordered[1:]):
        if a == 0.0 and b < 0.0:
            dh = b - a
            heads = a + dh * (_t8 ** 8)
            weights = _wt8 * (dh * 8.0 * (_t8 ** 7))
            zero_clustered_segments += 1
        elif b == 0.0 and a < 0.0:
            heads = b + (a - b) * ((1.0 - _t8) ** 8)
            weights = _wt8 * (8.0 * (b - a) * ((1.0 - _t8) ** 7))
            zero_clustered_segments += 1
        else:
            mid = 0.5 * (a + b)
            half = 0.5 * (b - a)
            heads = mid + half * r1._x8
            weights = half * r1._w8
        kvals = np.asarray([e2c.c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)
        if not np.all(np.isfinite(kvals)) or np.any(kvals <= 0.0):
            raise FloatingPointError("nonfinite_or_nonpositive_constitutive_value")
        all_k.append(kvals)
        all_w.append(weights)

    kvals = np.concatenate(all_k) if all_k else np.empty(0, dtype=np.float64)
    weights = np.concatenate(all_w) if all_w else np.empty(0, dtype=np.float64)
    if len(kvals) > r1.MAX_SEGMENTS * r1.GL_SEGMENT_N:
        raise RuntimeError(("quadrature_lane_bound_exceeded", len(kvals)))

    def residual(q: float) -> float:
        den = kvals - q
        if np.any(den == 0.0):
            return math.copysign(math.inf, float(np.sum(weights)))
        return float(np.sum(weights * kvals / den)) - LENGTH

    residual.k_eval_count = int(len(kvals))
    residual.zero_clustered_segments = int(zero_clustered_segments)
    return residual


def candidate(h_above: float, h_below: float, dual_endpoint: bool):
    scale = max(1.0, abs(h_above), abs(h_below))
    if abs(h_above - h_below) <= 2.0e-14 * scale:
        q = float(e2c.c1.core.k_of_h(0.5 * (h_above + h_below)))
        return q, {"branch": "EQUAL_HEAD_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 1}

    dh = h_below - h_above
    if abs(dh - LENGTH) <= 2.0e-13 * max(1.0, LENGTH, abs(dh)):
        return 0.0, {"branch": "HYDROSTATIC_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 0}

    if h_above >= 0.0 and h_below >= 0.0:
        q = float(e2c.c1.core.KSAT) * (1.0 - dh / LENGTH)
        return q, {"branch": "SAT_SAT_ANALYTIC_5CM", "root_residual_evaluations": 0, "constitutive_K_evaluations": 0}

    residual = zero_adjacent_residual_factory(h_above, h_below)
    k_above = float(e2c.c1.core.k_of_h(h_above))
    ksat = float(e2c.c1.core.KSAT)

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
        lo = math.nextafter(k_above, math.inf)
        hi = math.nextafter(ksat * (1.0 + drop / LENGTH), math.inf)

    f_lo = residual(lo)
    f_hi = residual(hi)
    evals = 2
    if not (math.isfinite(f_lo) and math.isfinite(f_hi)):
        raise FloatingPointError(("nonfinite_bracket_residual", f_lo, f_hi))

    if f_lo == 0.0:
        return lo, {"branch": "LOWER_EXACT", "root_residual_evaluations": evals, "constitutive_K_evaluations": residual.k_eval_count + 2}
    if f_hi == 0.0:
        return hi, {"branch": "UPPER_EXACT", "root_residual_evaluations": evals, "constitutive_K_evaluations": residual.k_eval_count + 2}

    if f_lo * f_hi > 0.0:
        payload = {
            "lo": lo,
            "hi": hi,
            "f_lo": f_lo,
            "f_hi": f_hi,
            "residual_selected_endpoint": "LOWER" if abs(f_lo) <= abs(f_hi) else "UPPER",
            "zero_clustered_segments": residual.zero_clustered_segments,
        }
        if not dual_endpoint:
            raise RuntimeError(("bracket_failure", payload))
        if abs(f_lo) <= abs(f_hi):
            q = lo
            branch = "DUAL_ENDPOINT_LOWER_RESIDUAL_PROXIMITY"
        else:
            q = hi
            branch = "DUAL_ENDPOINT_UPPER_RESIDUAL_PROXIMITY"
        return q, {
            "branch": branch,
            "root_residual_evaluations": evals,
            "constitutive_K_evaluations": residual.k_eval_count + 2,
            "endpoint_payload": payload,
        }

    for _ in range(e2c.BISECTION_STEPS):
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
    return q, {
        "branch": "ZERO_ADJACENT_CLUSTERED_BISECTION",
        "root_residual_evaluations": evals,
        "constitutive_K_evaluations": residual.k_eval_count + 2,
        "zero_clustered_segments": residual.zero_clustered_segments,
    }


def evaluate_variant(probes, refs, ksat: float, dual_endpoint: bool):
    rows = []
    unresolved = []
    nonfinite = 0
    endpoint_agree = []
    max_k = 0
    max_root = 0

    for p in probes:
        hs = float(p["h_surface"])
        ht = float(p["h_top_node"])
        q_ref = refs.get((hs, ht))
        if q_ref is None:
            continue
        try:
            q, cost = candidate(hs, ht, dual_endpoint=dual_endpoint)
        except RuntimeError as exc:
            payload = exc.args[0] if exc.args else None
            entry = {"probe_id": p["id"], "h_surface": hs, "h_top_node": ht, "q_ref": q_ref, "error": repr(exc)}
            if isinstance(payload, tuple) and len(payload) == 2 and payload[0] == "bracket_failure":
                d = payload[1]
                q_nearest = "LOWER" if abs(q_ref - d["lo"]) <= abs(q_ref - d["hi"]) else "UPPER"
                entry.update({"bracket": d, "reference_nearest_endpoint": q_nearest})
            unresolved.append(entry)
            continue
        except (FloatingPointError, OverflowError, ValueError):
            nonfinite += 1
            continue

        if not (math.isfinite(q_ref) and math.isfinite(q)):
            nonfinite += 1
            continue
        hybrid, absolute, wrong_sign = e2c._metric(float(q_ref), float(q), ksat)
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        row = {
            "probe_id": p["id"], "probe_set": p["probe_set"], "family": p["family"],
            "h_surface": hs, "h_top_node": ht, "q_ref": q_ref, "q_candidate": q,
            "branch": cost["branch"], "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute, "wrong_sign": wrong_sign,
        }
        ep = cost.get("endpoint_payload")
        if ep is not None:
            q_nearest = "LOWER" if abs(q_ref - ep["lo"]) <= abs(q_ref - ep["hi"]) else "UPPER"
            selected = ep["residual_selected_endpoint"]
            agree = selected == q_nearest
            endpoint_agree.append(agree)
            row["endpoint_reference_nearest"] = q_nearest
            row["endpoint_residual_selected"] = selected
            row["endpoint_selection_agrees_with_reference"] = agree
            row["endpoint_lo"] = ep["lo"]
            row["endpoint_hi"] = ep["hi"]
            row["endpoint_f_lo"] = ep["f_lo"]
            row["endpoint_f_hi"] = ep["f_hi"]
        rows.append(row)

    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))] if hybrids else math.inf
    max_hybrid = max(hybrids) if hybrids else math.inf
    max_abs = max((r["abs_error_over_ksatfit"] for r in rows), default=math.inf)
    wrong = sum(r["wrong_sign"] for r in rows)
    tests = {
        "unresolved_count": len(unresolved) == 0,
        "nonfinite_count": nonfinite == 0,
        "wrong_sign_count": wrong == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "endpoint_selection_agreement": all(endpoint_agree) if endpoint_agree else True,
    }
    return {
        "variant": "B_DUAL_ENDPOINT_RESIDUAL_PROXIMITY" if dual_endpoint else "A_ZERO_ADJACENT_UNSAT_CLUSTERING",
        "valid_probe_count": len(rows),
        "unresolved_count": len(unresolved),
        "unresolved": unresolved,
        "nonfinite_count": nonfinite,
        "wrong_sign_count": wrong,
        "max_hybrid_metric": max_hybrid,
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max_abs,
        "max_constitutive_K_evaluations": max_k,
        "max_root_residual_evaluations": max_root,
        "branch_counts": dict(sorted(Counter(r["branch"] for r in rows).items())),
        "endpoint_selection_count": len(endpoint_agree),
        "endpoint_selection_agreement_count": sum(endpoint_agree),
        "tests": tests,
        "indicator_pass": all(tests.values()),
        "worst_probe": max(rows, key=lambda r: r["hybrid_metric"]) if rows else None,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r1_boundary_numerical_seam_diagnostic.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    old_e2c_length = float(e2c.LENGTH)
    old_c1_length = float(e2c.c1.LENGTH_CM)
    old_core_length = float(e2c.c1.core.LENGTH_CM)
    try:
        e3e.configure_5cm(row)
        probes = e3e.build_probes(material)
        pairs = sorted({(float(p["h_surface"]), float(p["h_top_node"])) for p in probes})
        refs = {}
        ref_errors = []
        with CTX.Pool(min(8, mp.cpu_count())) as pool:
            for pair, value, error in pool.imap_unordered(safe_ref, pairs, chunksize=4):
                if error is None:
                    refs[pair] = float(value)
                else:
                    ref_errors.append({"pair": list(pair), "error": error})
        ksat = float(e2c.c1.core.KSAT)
        variant_a = evaluate_variant(probes, refs, ksat, dual_endpoint=False)
        variant_b = evaluate_variant(probes, refs, ksat, dual_endpoint=True)
    finally:
        e2c.LENGTH = old_e2c_length
        e2c.c1.LENGTH_CM = old_c1_length
        e2c.c1.core.LENGTH_CM = old_core_length

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "diagnostic": "E3E_R1_5CM_BOUNDARY_NUMERICAL_SEAM_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "qualification_use": False,
        "production_implementation": False,
        "reference_failure_count": len(ref_errors),
        "probe_count": len(probes),
        "variants": [variant_a, variant_b],
        "decision": (
            "BOUNDARY_NUMERICAL_HYPOTHESES_SUPPORTED_READY_FOR_INDEPENDENT_REQUALIFICATION_DESIGN"
            if len(ref_errors) == 0 and variant_b["indicator_pass"]
            else "BOUNDARY_NUMERICAL_HYPOTHESES_NOT_SUFFICIENT_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No qualification on reused E3E probes.",
            "No production implementation.",
            "No error-threshold relaxation.",
            "No ponding or surface-ledger qualification."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "decision": result["decision"],
        "A_indicator_pass": variant_a["indicator_pass"],
        "A_unresolved": variant_a["unresolved_count"],
        "A_max_abs": variant_a["max_abs_error_over_ksatfit"],
        "B_indicator_pass": variant_b["indicator_pass"],
        "B_unresolved": variant_b["unresolved_count"],
        "B_max_abs": variant_b["max_abs_error_over_ksatfit"],
        "B_endpoint_selection_count": variant_b["endpoint_selection_count"],
        "B_endpoint_selection_agreement_count": variant_b["endpoint_selection_agreement_count"],
        "B_branch_counts": variant_b["branch_counts"],
    }, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
