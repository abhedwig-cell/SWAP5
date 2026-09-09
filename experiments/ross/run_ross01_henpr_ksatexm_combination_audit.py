from __future__ import annotations

import json
import math
import sys
from pathlib import Path

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
H_THR = -2.0
H_CRIT = -1.0e-2
H_ENPR_VALUES = (-2.0, -4.0, -10.0)
CONTINUITY_TOL = 1.0e-10


def mpar(row: dict) -> float:
    return 1.0 - 1.0 / float(row["n"])


def base_f(h: float, row: dict) -> float:
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    return (1.0 + abs(alpha * h) ** n) ** (-m)


def base_k_from_s(s: float, row: dict) -> float:
    m = mpar(row)
    lam = float(row["lambda"])
    kfit = float(row["ksatfit_cm_per_day"])
    term = (1.0 - s ** (1.0 / m)) ** m
    return kfit * s**lam * (1.0 - term) ** 2


def modified_retention_constants(row: dict, h_enpr: float) -> dict:
    if not h_enpr <= H_CRIT:
        raise ValueError("audit only covers source branch H_ENPR<=h_crit")
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    dtheta = ts - tr
    sc = base_f(h_enpr, row)
    h105 = 1.05 * h_enpr
    t105 = tr + dtheta * ((1.0 + abs(alpha * h_enpr) ** n) ** m) / ((1.0 + abs(alpha * h105) ** n) ** m)
    c105 = (
        dtheta
        * alpha
        * m
        * n
        * abs(alpha * h105) ** (n - 1.0)
        * ((1.0 + abs(alpha * h_enpr) ** n) ** m)
        / ((1.0 + abs(alpha * h105) ** n) ** (m + 1.0))
    )
    a = (t105 - ts - c105 * h105) / (c105 * h105**2)
    b = (t105**2 - 2.0 * t105 * ts + ts**2) / (t105 - ts - c105 * h105)
    return {"sc": sc, "h105": h105, "a": a, "ab": a * b}


def modified_relsat(h: float, row: dict, h_enpr: float, constants: dict) -> float:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    if h >= 0.0:
        return 1.0
    if h >= constants["h105"]:
        theta = ts + constants["ab"] * h / (1.0 + constants["a"] * h)
        return (theta - tr) / (ts - tr)
    return base_f(h, row) / constants["sc"]


def modified_k_before_extension(h: float, row: dict, h_enpr: float, constants: dict) -> float:
    kfit = float(row["ksatfit_cm_per_day"])
    if h >= h_enpr:
        return kfit
    m = mpar(row)
    lam = float(row["lambda"])
    sc = constants["sc"]
    se = base_f(h, row) / sc
    term1 = (1.0 - (se * sc) ** (1.0 / m)) ** m
    term2 = (1.0 - sc ** (1.0 / m)) ** m
    return kfit * se**lam * ((1.0 - term1) / (1.0 - term2)) ** 2


def activation_head(row: dict, h_enpr: float, constants: dict, s_thr: float) -> float:
    lo = -10000.0
    hi = 0.0
    if modified_relsat(lo, row, h_enpr, constants) >= s_thr:
        raise ValueError("lower bracket already above KSATEXM activation threshold")
    if modified_relsat(hi, row, h_enpr, constants) <= s_thr:
        raise ValueError("upper bracket does not reach KSATEXM activation threshold")
    for _ in range(180):
        mid = 0.5 * (lo + hi)
        if modified_relsat(mid, row, h_enpr, constants) < s_thr:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def audit_case(row: dict, h_enpr: float) -> dict:
    kfit = float(row["ksatfit_cm_per_day"])
    kext = float(row["ksatexm_cm_per_day"])
    if not kext > kfit:
        raise ValueError("catalog row does not activate legacy KSATEXM")
    s_thr = base_f(H_THR, row)
    k_thr = base_k_from_s(s_thr, row)
    constants = modified_retention_constants(row, h_enpr)
    h_act = activation_head(row, h_enpr, constants, s_thr)
    rel_act = modified_relsat(h_act, row, h_enpr, constants)
    k_pre = modified_k_before_extension(h_act, row, h_enpr, constants)
    k_post = k_thr
    scale = max(kfit, abs(k_pre), abs(k_post), 1.0e-300)
    relative_jump = (k_post - k_pre) / scale
    discontinuity_metric = abs(k_post - k_pre) / scale
    continuous = discontinuity_metric <= CONTINUITY_TOL
    return {
        "material": row["sfu"],
        "h_enpr_cm": h_enpr,
        "legacy_h_thr_cm": H_THR,
        "legacy_s_thr": s_thr,
        "activation_head_cm": h_act,
        "activation_head_minus_legacy_h_thr_cm": h_act - H_THR,
        "modified_relsat_at_activation": rel_act,
        "ksatfit_cm_per_day": kfit,
        "ksatexm_cm_per_day": kext,
        "ksatexm_over_ksatfit": kext / kfit,
        "legacy_k_thr_cm_per_day": k_thr,
        "k_pre_h_enpr_branch_cm_per_day": k_pre,
        "k_post_ksatexm_branch_cm_per_day": k_post,
        "k_pre_over_ksatfit": k_pre / kfit,
        "k_post_over_ksatfit": k_post / kfit,
        "relative_jump": relative_jump,
        "discontinuity_metric": discontinuity_metric,
        "continuous_within_frozen_tolerance": continuous,
        "monotone_across_activation": k_post >= k_pre,
    }


def summarize(cases: list[dict], h_enpr: float) -> dict:
    subset = [c for c in cases if c["h_enpr_cm"] == h_enpr]
    worst = max(subset, key=lambda c: c["discontinuity_metric"])
    return {
        "h_enpr_cm": h_enpr,
        "case_count": len(subset),
        "discontinuity_count": sum(not c["continuous_within_frozen_tolerance"] for c in subset),
        "nonmonotone_activation_count": sum(not c["monotone_across_activation"] for c in subset),
        "activation_head_range_cm": [min(c["activation_head_cm"] for c in subset), max(c["activation_head_cm"] for c in subset)],
        "relative_jump_range": [min(c["relative_jump"] for c in subset), max(c["relative_jump"] for c in subset)],
        "worst_discontinuity": {
            "material": worst["material"],
            "metric": worst["discontinuity_metric"],
            "relative_jump": worst["relative_jump"],
            "activation_head_cm": worst["activation_head_cm"],
            "k_pre_over_ksatfit": worst["k_pre_over_ksatfit"],
            "k_post_over_ksatfit": worst["k_post_over_ksatfit"],
        },
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_henpr_ksatexm_combination_audit.py OUTPUT.json")
    output = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    rows = catalog["rows"]
    if len(rows) != 36:
        raise RuntimeError("frozen Staringreeks catalog must contain 36 rows")

    cases = [audit_case(row, h_enpr) for h_enpr in H_ENPR_VALUES for row in rows]
    summaries = [summarize(cases, h) for h in H_ENPR_VALUES]
    discontinuity_count = sum(not c["continuous_within_frozen_tolerance"] for c in cases)
    nonmonotone_count = sum(not c["monotone_across_activation"] for c in cases)

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2X_LEGACY_H_ENPR_PLUS_KSATEXM_COMBINATION_AUDIT",
        "contract": "F-ROSS01_HENPR_KSATEXM_COMBINATION_AUDIT_CONTRACT.json",
        "catalog_source_sha256": catalog["source_sha256"],
        "continuity_tolerance": CONTINUITY_TOL,
        "case_count": len(cases),
        "material_count": len(rows),
        "h_enpr_values_cm": list(H_ENPR_VALUES),
        "discontinuity_count": discontinuity_count,
        "nonmonotone_activation_count": nonmonotone_count,
        "summaries": summaries,
        "cases": cases,
        "finding_confirmed": discontinuity_count > 0,
        "decision": "LEGACY_H_ENPR_PLUS_ACTIVE_KSATEXM_IS_NOT_A_CONSTITUTIVELY_CONTINUOUS_COMPOSITION" if discontinuity_count else "NO_DISCONTINUITY_FOUND_IN_FROZEN_DIAGNOSTIC_MATRIX",
        "policy_consequence": "Do not silently compose these two legacy options in SWAP5. Preserve exact legacy behavior only through an explicitly named compatibility route if required, or define and qualify a new physical near-saturation closure shared by FullRichards and RossFast.",
        "scope_guard": "Diagnostic source-semantics audit only; imposed H_ENPR values are not claims about the catalog defaults and no RossFast production qualification follows."
    }
    output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "case_count": len(cases),
        "discontinuity_count": discontinuity_count,
        "nonmonotone_activation_count": nonmonotone_count,
        "summaries": summaries,
        "decision": evidence["decision"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
