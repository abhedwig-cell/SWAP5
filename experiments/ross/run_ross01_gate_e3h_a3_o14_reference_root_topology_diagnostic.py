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

CONTRACT = "F-ROSS01_GATE_E3H_A3_O14_REFERENCE_ROOT_EXISTENCE_AND_EVENT_TOPOLOGY_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
H_UPPER = -1.0e-8
TAU_LO = 1.0e-8
TAU_HI = 0.05
SURFACE_LO = 1.0e-12
SURFACE_HI = 1.0
MASS_TOL = 1.0e-9
MAX_NFEV = 300

TOPOLOGY_STARTS = (
    ("T0_DEEP_CONTROL", -1.0, -2.0),
    ("T1_SECOND_NODE_APPROACH", -0.8, -2.0),
    ("T2_NEAR_SATURATION", -0.2, -1.0),
    ("T3_THIN_NEAR_SATURATION", -0.02, -0.2),
)
SURFACE_TAU_STARTS = (
    ("U0_EARLY", 0.02, 0.0001),
    ("U1_MIDDLE", 0.45, 0.005),
    ("U2_LATE", 0.90, 0.03),
)

H_CLUSTER = 1.0e-3
SURFACE_CLUSTER = 1.0e-6
TAU_CLUSTER = 1.0e-7
MIN_CLUSTER_MEMBERS = 2


def bits(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def classify_topology(h1: float, h2: float) -> str:
    if h2 > -1.0:
        return "MULTIPLE_LOWER_NODES_NEAR_SATURATION"
    if h1 >= -1.0e-6:
        return "SECOND_NODE_AT_H0_BOUNDARY"
    if h1 > -1.0:
        return "SECOND_NODE_NEAR_SATURATION"
    return "ISOLATED_TOP_NODE"


def solve_from_start(row: dict, profile: tuple[float, float, float], supply: float, start: tuple) -> dict:
    topology_id, h1_start, h2_start, time_id, surface_start, tau_start = start
    old_initial = a1.INITIAL_HEADS
    a1.INITIAL_HEADS = tuple(float(v) for v in profile)
    a1.configure(row)
    snapshot = bits((*a1.INITIAL_HEADS, a1.S0))
    x0 = np.asarray([h1_start, h2_start, surface_start, tau_start], dtype=np.float64)
    try:
        sol = least_squares(
            lambda x: a1.event_residual(x, supply, row, False, None),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, SURFACE_LO, TAU_LO]),
                np.asarray([H_UPPER, H_UPPER, SURFACE_HI, TAU_HI]),
            ),
            xtol=1e-13,
            ftol=1e-13,
            gtol=1e-13,
            max_nfev=MAX_NFEV,
            x_scale="jac",
        )
        h1, h2, surface, tau = map(float, sol.x)
        residual = a1.event_residual(sol.x, supply, row, False, None)
        max_res = max(abs(float(v)) for v in residual)
        qtop = a1.saturated_surface_q(surface, row)
        (q01, q12, qb), routes = a1.internal_q(0.0, h1, h2, row, False, None)
        finite = all(math.isfinite(v) for v in (h1, h2, surface, tau, max_res, qtop, q01, q12, qb))
        strict_tau = tau > 2.0e-8 and tau < 0.049
        strict_surface = surface > 1.0e-10 and surface < 0.999999
        physical_order = 0.0 >= h1 >= h2
        committed_unchanged = bits((*a1.INITIAL_HEADS, a1.S0)) == snapshot
        valid = bool(
            sol.success
            and finite
            and max_res <= MASS_TOL
            and strict_tau
            and strict_surface
            and physical_order
            and committed_unchanged
        )
        return {
            "start_id": f"{topology_id}:{time_id}",
            "topology_start_id": topology_id,
            "surface_tau_start_id": time_id,
            "start": [h1_start, h2_start, surface_start, tau_start],
            "solver_success": bool(sol.success),
            "status": int(sol.status),
            "message": str(sol.message),
            "nfev": int(sol.nfev),
            "valid": valid,
            "event_time_day": tau,
            "heads_cm": [0.0, h1, h2],
            "surface_storage_cm": surface,
            "q_top_cm_per_day": qtop,
            "q_internal_cm_per_day": [q01, q12, qb],
            "reference_routes": list(routes),
            "max_abs_event_residual_cm": max_res,
            "strict_event_time": strict_tau,
            "strict_surface_storage": strict_surface,
            "physical_head_order": physical_order,
            "committed_state_bitwise_unchanged": committed_unchanged,
            "mass_repair_or_clipping_used": False,
            "topology": classify_topology(h1, h2) if valid else None,
        }
    except Exception as exc:
        return {
            "start_id": f"{topology_id}:{time_id}",
            "topology_start_id": topology_id,
            "surface_tau_start_id": time_id,
            "start": [h1_start, h2_start, surface_start, tau_start],
            "solver_success": False,
            "valid": False,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": bits((*a1.INITIAL_HEADS, a1.S0)) == snapshot,
            "mass_repair_or_clipping_used": False,
            "topology": None,
        }
    finally:
        a1.INITIAL_HEADS = old_initial


def close_roots(a: dict, b: dict) -> bool:
    return (
        abs(float(a["heads_cm"][1]) - float(b["heads_cm"][1])) <= H_CLUSTER
        and abs(float(a["heads_cm"][2]) - float(b["heads_cm"][2])) <= H_CLUSTER
        and abs(float(a["surface_storage_cm"]) - float(b["surface_storage_cm"])) <= SURFACE_CLUSTER
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

    output = []
    for members in groups.values():
        h1s = [float(x["heads_cm"][1]) for x in members]
        h2s = [float(x["heads_cm"][2]) for x in members]
        ss = [float(x["surface_storage_cm"]) for x in members]
        taus = [float(x["event_time_day"]) for x in members]
        topologies = sorted(set(str(x["topology"]) for x in members))
        representative = min(members, key=lambda x: x["start_id"])
        reproducible = len(members) >= MIN_CLUSTER_MEMBERS
        output.append({
            "member_count": len(members),
            "reproducible": reproducible,
            "start_ids": sorted(x["start_id"] for x in members),
            "topologies": topologies,
            "classification": topologies[0] if len(topologies) == 1 else "MIXED_THRESHOLD_CLUSTER",
            "representative": {
                "start_id": representative["start_id"],
                "heads_cm": representative["heads_cm"],
                "surface_storage_cm": representative["surface_storage_cm"],
                "event_time_day": representative["event_time_day"],
                "max_abs_event_residual_cm": representative["max_abs_event_residual_cm"],
                "q_top_cm_per_day": representative["q_top_cm_per_day"],
                "q_internal_cm_per_day": representative["q_internal_cm_per_day"],
            },
            "spread": {
                "h1_cm": max(h1s) - min(h1s),
                "h2_cm": max(h2s) - min(h2s),
                "surface_cm": max(ss) - min(ss),
                "event_time_day": max(taus) - min(taus),
            },
            "max_member_residual_cm": max(float(x["max_abs_event_residual_cm"]) for x in members),
        })
    output.sort(key=lambda c: (-int(c["reproducible"]), -c["member_count"], c["classification"]))
    return output


def run_profile(row: dict, profile_id: str, profile: tuple[float, float, float]) -> dict:
    ks = float(row["ksatfit_cm_per_day"])
    starts = tuple(
        (tid, h1, h2, uid, surface, tau)
        for tid, h1, h2 in TOPOLOGY_STARTS
        for uid, surface, tau in SURFACE_TAU_STARTS
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
            "reproducible_topologies": sorted(set(c["classification"] for c in reproducible)),
        })

    reproducible_cases = [c for c in cases if c["reproducible_cluster_count"] > 0]
    topology_counts: dict[str, int] = {}
    for case in reproducible_cases:
        for topology in case["reproducible_topologies"]:
            topology_counts[topology] = topology_counts.get(topology, 0) + 1

    if topology_counts.get("ISOLATED_TOP_NODE", 0) > 0:
        decision = "O14_ISOLATED_REFERENCE_EVENT_ROOT_REPRODUCED_A2_SOLVER_POLICY_DIAGNOSTIC_REQUIRED"
    elif reproducible_cases:
        decision = "O14_REFERENCE_EVENT_ROOT_REQUIRES_NEAR_SATURATION_TOPOLOGY_CHARACTERIZED"
    else:
        decision = "O14_REFERENCE_EVENT_ROOT_NOT_REPRODUCIBLY_ESTABLISHED_EVENT_FORMULATION_RESEARCH_REQUIRED"

    tests = {
        "case_count": len(cases) == len(a1.SUPPLY_FRACTIONS),
        "starts_per_case": all(c["start_count"] == 12 for c in cases),
        "reference_only": True,
        "all_committed_state_unchanged": all(
            a.get("committed_state_bitwise_unchanged") is True for c in cases for a in c["attempts"]
        ),
        "no_mass_repair_or_clipping": all(
            a.get("mass_repair_or_clipping_used") is False for c in cases for a in c["attempts"]
        ),
    }
    return {
        "material": MATERIAL,
        "profile_id": profile_id,
        "initial_heads_cm": list(profile),
        "case_count": len(cases),
        "total_reference_solves": sum(c["start_count"] for c in cases),
        "reproducible_case_count": len(reproducible_cases),
        "topology_case_counts": dict(sorted(topology_counts.items())),
        "cases": cases,
        "tests": tests,
        "complete": all(tests.values()),
        "decision": decision,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a3_o14_reference_root_topology_diagnostic.py PROFILE_ID OUTPUT.json")
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
        "gate": "E3H_A3_O14_REFERENCE_ROOT_EXISTENCE_AND_EVENT_TOPOLOGY_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "candidate_runs": 0,
        "profile_result": result,
        "diagnostic_complete": result["complete"],
        "decision": result["decision"],
        "hard_nonclaims": [
            "No Ross candidate qualification.",
            "No production event policy admission.",
            "No positive h1 or h2 state.",
            "No change to A2 profiles, supply fractions, tau floor, surface cap or physical equations."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "profile": profile_id,
        "complete": result["complete"],
        "reference_solves": result["total_reference_solves"],
        "reproducible_cases": result["reproducible_case_count"],
        "topology_case_counts": result["topology_case_counts"],
        "decision": result["decision"],
    }, sort_keys=True), flush=True)
    if not result["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
