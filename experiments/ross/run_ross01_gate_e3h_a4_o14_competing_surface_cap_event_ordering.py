from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a_top_node_saturation_event_fixture_characterization as a1
import run_ross01_gate_e3h_a2_bounded_initial_profile_fixture_characterization as a2

CONTRACT = "F-ROSS01_GATE_E3H_A4_O14_COMPETING_SURFACE_CAP_EVENT_ORDERING_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
S_CAP = 1.0
S0 = 0.02
H_UPPER = -1.0e-8
TAU_LO = 1.0e-8
TAU_HI = 0.05
MASS_TOL = 1.0e-9
MAX_NFEV = 250

HEAD_STARTS = (
    ("H0_PROFILE_LIKE", -0.2, -1.5, -5.0),
    ("H1_NEAR_SURFACE", -0.05, -0.5, -2.0),
    ("H2_INTERMEDIATE", -0.8, -2.0, -5.0),
    ("H3_DRY", -2.0, -10.0, -20.0),
)
TAU_STARTS = (
    ("T0_EARLY", 0.001),
    ("T1_MIDDLE", 0.01),
    ("T2_LATE", 0.04),
)

H_CLUSTER = 1.0e-3
TAU_CLUSTER = 1.0e-7
MIN_CLUSTER_MEMBERS = 2


def bits(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def configure_profile(row: dict, profile: tuple[float, float, float]) -> tuple[float, float, float]:
    old = a1.INITIAL_HEADS
    a1.INITIAL_HEADS = tuple(float(v) for v in profile)
    a1.configure(row)
    return old


def restore_profile(old: tuple[float, float, float]) -> None:
    a1.INITIAL_HEADS = old


def search_surface_q(h0: float, row: dict) -> tuple[float, str]:
    q, route, _ = a1.e3g.surface_face(S_CAP, float(h0), row, True)
    return float(q), str(route)


def exact_surface_q(h0: float, row: dict) -> tuple[float, str, float]:
    ref = a1.e3g.exact_surface_reference(S_CAP, float(h0), row)
    return float(ref["q"]), str(ref["branch"]), float(ref["residual_cm"])


def balances(x, supply: float, row: dict, qtop: float) -> tuple[np.ndarray, dict]:
    h0, h1, h2, tau = map(float, x)
    (q01, q12, qb), routes = a1.internal_q(h0, h1, h2, row, False, None)
    residual = np.asarray([
        a1.DZ * (a1.theta(h0) - a1.theta(a1.INITIAL_HEADS[0])) - tau * (qtop - q01),
        a1.DZ * (a1.theta(h1) - a1.theta(a1.INITIAL_HEADS[1])) - tau * (q01 - q12),
        a1.DZ * (a1.theta(h2) - a1.theta(a1.INITIAL_HEADS[2])) - tau * (q12 - qb),
        (S_CAP - S0) - tau * (supply - qtop),
    ], dtype=np.float64)
    return residual, {
        "q01": float(q01),
        "q12": float(q12),
        "qb": float(qb),
        "routes": list(routes),
    }


def search_residual(x, supply: float, row: dict) -> np.ndarray:
    h0 = float(x[0])
    qtop, _ = search_surface_q(h0, row)
    residual, _ = balances(x, supply, row, qtop)
    return residual


def classify_event(h0: float) -> str:
    if h0 < -1.0e-6:
        return "SURFACE_CAP_PRECEDES_TOP_SATURATION"
    return "SURFACE_CAP_AND_TOP_SATURATION_COEVENT"


def solve_from_start(row: dict, profile: tuple[float, float, float], supply: float, start: tuple) -> dict:
    head_id, h0s, h1s, h2s, tau_id, taus = start
    old_profile = configure_profile(row, profile)
    snapshot = bits((*a1.INITIAL_HEADS, S0))
    x0 = np.asarray([h0s, h1s, h2s, taus], dtype=np.float64)
    try:
        sol = least_squares(
            lambda x: search_residual(x, supply, row),
            x0,
            bounds=(np.full(4, [-10000.0, -10000.0, -10000.0, TAU_LO]),
                    np.asarray([H_UPPER, H_UPPER, H_UPPER, TAU_HI])),
            xtol=1e-13,
            ftol=1e-13,
            gtol=1e-13,
            max_nfev=MAX_NFEV,
            x_scale="jac",
        )
        h0, h1, h2, tau = map(float, sol.x)
        q_search, search_route = search_surface_q(h0, row)
        search_res, search_fluxes = balances(sol.x, supply, row, q_search)
        q_exact, exact_branch, exact_face_residual = exact_surface_q(h0, row)
        exact_res, exact_fluxes = balances(sol.x, supply, row, q_exact)
        max_search = max(abs(float(v)) for v in search_res)
        max_exact = max(abs(float(v)) for v in exact_res)
        finite = all(math.isfinite(v) for v in (
            h0, h1, h2, tau, q_search, q_exact, exact_face_residual,
            max_search, max_exact, search_fluxes["q01"], search_fluxes["q12"], search_fluxes["qb"]
        ))
        strict_tau = tau > 2.0e-8 and tau < 0.049
        physical_order = h0 >= h1 >= h2
        committed_unchanged = bits((*a1.INITIAL_HEADS, S0)) == snapshot
        valid = bool(
            sol.success and finite and max_exact <= MASS_TOL and strict_tau
            and physical_order and committed_unchanged
        )
        return {
            "start_id": f"{head_id}:{tau_id}",
            "start": [h0s, h1s, h2s, taus],
            "solver_success": bool(sol.success),
            "status": int(sol.status),
            "message": str(sol.message),
            "nfev": int(sol.nfev),
            "valid": valid,
            "event_time_day": tau,
            "heads_cm": [h0, h1, h2],
            "surface_storage_cm": S_CAP,
            "q_supply_cm_per_day": supply,
            "q_top_search_cm_per_day": q_search,
            "q_top_exact_reference_cm_per_day": q_exact,
            "search_surface_route": search_route,
            "exact_surface_reference_branch": exact_branch,
            "exact_surface_reference_path_residual_cm": exact_face_residual,
            "internal_reference_fluxes_cm_per_day": [exact_fluxes["q01"], exact_fluxes["q12"], exact_fluxes["qb"]],
            "internal_reference_routes": exact_fluxes["routes"],
            "max_abs_search_balance_residual_cm": max_search,
            "max_abs_independent_reference_balance_residual_cm": max_exact,
            "strict_event_time": strict_tau,
            "physical_head_order": physical_order,
            "committed_state_bitwise_unchanged": committed_unchanged,
            "mass_repair_or_clipping_used": False,
            "classification": classify_event(h0) if valid else None,
        }
    except Exception as exc:
        return {
            "start_id": f"{head_id}:{tau_id}",
            "start": [h0s, h1s, h2s, taus],
            "solver_success": False,
            "valid": False,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": bits((*a1.INITIAL_HEADS, S0)) == snapshot,
            "mass_repair_or_clipping_used": False,
            "classification": None,
        }
    finally:
        restore_profile(old_profile)


def close_roots(a: dict, b: dict) -> bool:
    return (
        max(abs(float(x) - float(y)) for x, y in zip(a["heads_cm"], b["heads_cm"])) <= H_CLUSTER
        and abs(float(a["event_time_day"]) - float(b["event_time_day"])) <= TAU_CLUSTER
    )


def clusters(valid: list[dict]) -> list[dict]:
    n = len(valid)
    parent = list(range(n))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i: int, j: int) -> None:
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[rj] = ri

    for i in range(n):
        for j in range(i + 1, n):
            if close_roots(valid[i], valid[j]):
                union(i, j)

    groups: dict[int, list[dict]] = {}
    for i, root in enumerate(valid):
        groups.setdefault(find(i), []).append(root)

    out = []
    for members in groups.values():
        classes = sorted(set(str(x["classification"]) for x in members))
        rep = min(members, key=lambda x: x["start_id"])
        out.append({
            "member_count": len(members),
            "reproducible": len(members) >= MIN_CLUSTER_MEMBERS,
            "classification": classes[0] if len(classes) == 1 else "MIXED_THRESHOLD_CLUSTER",
            "start_ids": sorted(x["start_id"] for x in members),
            "representative": {
                "start_id": rep["start_id"],
                "heads_cm": rep["heads_cm"],
                "event_time_day": rep["event_time_day"],
                "q_top_exact_reference_cm_per_day": rep["q_top_exact_reference_cm_per_day"],
                "max_abs_independent_reference_balance_residual_cm": rep["max_abs_independent_reference_balance_residual_cm"],
            },
            "max_member_independent_reference_residual_cm": max(float(x["max_abs_independent_reference_balance_residual_cm"]) for x in members),
        })
    out.sort(key=lambda x: (-int(x["reproducible"]), -x["member_count"], x["classification"]))
    return out


def run_profile(row: dict, profile_id: str, profile: tuple[float, float, float]) -> dict:
    ks = float(row["ksatfit_cm_per_day"])
    starts = tuple(
        (hid, h0, h1, h2, tid, tau)
        for hid, h0, h1, h2 in HEAD_STARTS
        for tid, tau in TAU_STARTS
    )
    cases = []
    for frac in a1.SUPPLY_FRACTIONS:
        supply = float(frac) * ks
        attempts = [solve_from_start(row, profile, supply, s) for s in starts]
        valid = [x for x in attempts if x.get("valid")]
        cls = clusters(valid)
        reproducible = [c for c in cls if c["reproducible"]]
        cases.append({
            "profile_id": profile_id,
            "initial_heads_cm": list(profile),
            "supply_fraction_ksat": float(frac),
            "q_supply_cm_per_day": supply,
            "start_count": len(attempts),
            "valid_start_count": len(valid),
            "attempts": attempts,
            "clusters": cls,
            "reproducible_cluster_count": len(reproducible),
            "reproducible_event_classes": sorted(set(c["classification"] for c in reproducible)),
        })

    reproducible_cases = [c for c in cases if c["reproducible_cluster_count"] > 0]
    class_counts: dict[str, int] = {}
    for case in reproducible_cases:
        for cls in case["reproducible_event_classes"]:
            class_counts[cls] = class_counts.get(cls, 0) + 1

    if class_counts.get("SURFACE_CAP_PRECEDES_TOP_SATURATION", 0) > 0:
        decision = "O14_SURFACE_CAP_PRECEDES_TOP_SATURATION_CHARACTERIZED"
    elif class_counts.get("SURFACE_CAP_AND_TOP_SATURATION_COEVENT", 0) > 0:
        decision = "O14_SURFACE_CAP_AND_TOP_SATURATION_COEVENT_CHARACTERIZED"
    else:
        decision = "O14_NO_REPRODUCIBLE_SURFACE_CAP_ROOT_GENERAL_COMPLEMENTARITY_TRAJECTORY_RESEARCH_REQUIRED"

    tests = {
        "case_count": len(cases) == len(a1.SUPPLY_FRACTIONS),
        "starts_per_case": all(c["start_count"] == 12 for c in cases),
        "all_committed_state_unchanged": all(a.get("committed_state_bitwise_unchanged") is True for c in cases for a in c["attempts"]),
        "no_mass_repair_or_clipping": all(a.get("mass_repair_or_clipping_used") is False for c in cases for a in c["attempts"]),
    }
    return {
        "material": MATERIAL,
        "profile_id": profile_id,
        "initial_heads_cm": list(profile),
        "case_count": len(cases),
        "total_search_solves": sum(c["start_count"] for c in cases),
        "reproducible_case_count": len(reproducible_cases),
        "event_class_counts": dict(sorted(class_counts.items())),
        "cases": cases,
        "tests": tests,
        "complete": all(tests.values()),
        "decision": decision,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a4_o14_competing_surface_cap_event_ordering.py PROFILE_ID OUTPUT.json")
    profile_id = sys.argv[1]
    profiles = dict(a2.PROFILES)
    if profile_id not in profiles:
        raise SystemExit(profile_id)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    result = run_profile(row, profile_id, tuple(float(v) for v in profiles[profile_id]))
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A4_O14_COMPETING_SURFACE_CAP_EVENT_ORDERING_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "material": MATERIAL,
        "surface_cap_cm": S_CAP,
        "profile_result": result,
        "diagnostic_complete": result["complete"],
        "decision": result["decision"],
        "hard_nonclaims": [
            "No Ross production candidate qualification.",
            "No runoff continuation after cap onset.",
            "No automatic event detector admission.",
            "The bounded surface-face candidate is a search aid only; independent-reference recomputed balances control root validity."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "profile": profile_id,
        "complete": result["complete"],
        "search_solves": result["total_search_solves"],
        "reproducible_cases": result["reproducible_case_count"],
        "event_class_counts": result["event_class_counts"],
        "decision": result["decision"],
    }, sort_keys=True), flush=True)
    if not result["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
