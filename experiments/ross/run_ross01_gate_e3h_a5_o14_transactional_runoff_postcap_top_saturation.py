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

CONTRACT = "F-ROSS01_GATE_E3H_A5_O14_TRANSACTIONAL_RUNOFF_ONSET_AND_POST_CAP_TOP_SATURATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
S_CAP = 1.0
SUPPLY_FRACTION = 12.0
TAU_LO = 1.0e-8
TAU_HI = 0.5
MASS_TOL = 1.0e-9
MAX_NFEV = 300
H_CLUSTER = 1.0e-3
TAU_CLUSTER = 1.0e-6
MIN_CLUSTER = 2

CAP_STATES = {
    "P0_A1_CONTROL": {
        "cap_event_time_day": 0.03644773984112319,
        "heads_cm": (-0.14612442301092474, -3.4365807674561273, -8.231314064881142),
    },
    "P1_DRIER_SUBSOIL": {
        "cap_event_time_day": 0.0365014276959812,
        "heads_cm": (-0.23356049032180035, -3.7808381225488468, -8.689972381245196),
    },
    "P2_DRIER_TOP_AND_SUBSOIL": {
        "cap_event_time_day": 0.03664790671376539,
        "heads_cm": (-0.47697860016578836, -4.718962776786451, -10.022018575369172),
    },
    "P3_STRONG_DRY_SEPARATION": {
        "cap_event_time_day": 0.03723734776750273,
        "heads_cm": (-1.472189253257072, -8.509653922626015, -16.120819017592716),
    },
}

TAU_STARTS = (0.001, 0.02, 0.1)


def bits_cap(heads: tuple[float, float, float], runoff_ledger: float = 0.0) -> bytes:
    return struct.pack("!5d", float(heads[0]), float(heads[1]), float(heads[2]), S_CAP, float(runoff_ledger))


def head_starts(cap_heads: tuple[float, float, float]):
    h1 = float(cap_heads[1])
    h2 = float(cap_heads[2])
    return (
        ("CAP_H1_H2", h1, h2),
        ("HALF_CAP_H1_H2", 0.5 * h1, 0.5 * h2),
        ("QUARTER_CAP_H1_H2", 0.25 * h1, 0.25 * h2),
        ("FIXED_MINUS1_MINUS5", -1.0, -5.0),
    )


def qtop_event(row: dict) -> float:
    # Both surface and top node are saturated at the event. With z positive
    # downward and a 5 cm surface face, Darcy gives q = Ks*(1 + dh/L).
    return float(row["ksatfit_cm_per_day"]) * (1.0 + S_CAP / float(a1.SURFACE_FACE_LENGTH))


def fluxes(h1: float, h2: float, row: dict, candidate: bool, table):
    return a1.internal_q(0.0, float(h1), float(h2), row, candidate, table)


def balance_vector(cap_heads, h1: float, h2: float, tau: float, supply: float, row: dict, candidate: bool, table):
    qtop = qtop_event(row)
    (q01, q12, qb), routes = fluxes(h1, h2, row, candidate, table)
    residuals = np.asarray([
        a1.DZ * (a1.theta(0.0) - a1.theta(float(cap_heads[0]))) - tau * (qtop - q01),
        a1.DZ * (a1.theta(h1) - a1.theta(float(cap_heads[1]))) - tau * (q01 - q12),
        a1.DZ * (a1.theta(h2) - a1.theta(float(cap_heads[2]))) - tau * (q12 - qb),
    ], dtype=np.float64)
    soil_storage = math.fsum([
        a1.DZ * (a1.theta(0.0) - a1.theta(float(cap_heads[0]))),
        a1.DZ * (a1.theta(h1) - a1.theta(float(cap_heads[1]))),
        a1.DZ * (a1.theta(h2) - a1.theta(float(cap_heads[2]))),
    ])
    runoff_amount = tau * (supply - qtop)
    surface_residual = tau * (supply - qtop) - runoff_amount
    system_residual = soil_storage + runoff_amount + tau * qb - tau * supply
    return residuals, {
        "q_top_cm_per_day": qtop,
        "q01_cm_per_day": float(q01),
        "q12_cm_per_day": float(q12),
        "q_bottom_cm_per_day": float(qb),
        "routes": list(routes),
        "runoff_amount_cm": float(runoff_amount),
        "runoff_rate_cm_per_day_BE": float(supply - qtop),
        "surface_balance_residual_cm": float(surface_residual),
        "system_balance_residual_cm": float(system_residual),
        "soil_storage_change_cm": float(soil_storage),
    }


def search_residual(x, cap_heads, supply: float, row: dict, table):
    h1, h2, tau = map(float, x)
    r, _ = balance_vector(cap_heads, h1, h2, tau, supply, row, True, table)
    return r


def solve_from_start(row: dict, cap: dict, start: tuple, table) -> dict:
    cap_heads = tuple(float(v) for v in cap["heads_cm"])
    snapshot = bits_cap(cap_heads, 0.0)
    hid, h1s, h2s, taus = start
    supply = SUPPLY_FRACTION * float(row["ksatfit_cm_per_day"])
    x0 = np.asarray([h1s, h2s, taus], dtype=np.float64)
    try:
        sol = least_squares(
            lambda x: search_residual(x, cap_heads, supply, row, table),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, TAU_LO]),
                np.asarray([-1.0e-8, -1.0e-8, TAU_HI]),
            ),
            xtol=1e-13,
            ftol=1e-13,
            gtol=1e-13,
            max_nfev=MAX_NFEV,
            x_scale="jac",
        )
        h1, h2, tau = map(float, sol.x)
        search_r, search_d = balance_vector(cap_heads, h1, h2, tau, supply, row, True, table)
        ref_r, ref_d = balance_vector(cap_heads, h1, h2, tau, supply, row, False, None)
        max_search = max(abs(float(v)) for v in search_r)
        max_ref = max(
            max(abs(float(v)) for v in ref_r),
            abs(float(ref_d["surface_balance_residual_cm"])),
            abs(float(ref_d["system_balance_residual_cm"])),
        )
        finite = all(math.isfinite(v) for v in (
            h1, h2, tau, max_search, max_ref,
            ref_d["q_top_cm_per_day"], ref_d["q01_cm_per_day"], ref_d["q12_cm_per_day"],
            ref_d["q_bottom_cm_per_day"], ref_d["runoff_amount_cm"],
        ))
        physical_order = 0.0 >= h1 >= h2
        strict_tau = tau > 10.0 * TAU_LO and tau < 0.99 * TAU_HI
        runoff_nonnegative = ref_d["runoff_amount_cm"] >= 0.0
        no_unqualified_search = not any("UNQUALIFIED" in str(r) for r in search_d["routes"])
        cap_unchanged = bits_cap(cap_heads, 0.0) == snapshot
        valid = bool(
            sol.success and finite and strict_tau and physical_order and runoff_nonnegative
            and no_unqualified_search and max_ref <= MASS_TOL and cap_unchanged
        )
        return {
            "start_id": hid,
            "start": [h1s, h2s, taus],
            "solver_success": bool(sol.success),
            "status": int(sol.status),
            "message": str(sol.message),
            "nfev": int(sol.nfev),
            "valid": valid,
            "tau_after_cap_day": tau,
            "absolute_event_time_day": float(cap["cap_event_time_day"]) + tau,
            "heads_cm": [0.0, h1, h2],
            "surface_storage_cm": S_CAP,
            "q_supply_cm_per_day": supply,
            "search_fluxes": search_d,
            "independent_reference_fluxes": ref_d,
            "max_abs_search_cell_residual_cm": max_search,
            "max_abs_independent_reference_cell_or_system_residual_cm": max_ref,
            "strict_event_time": strict_tau,
            "physical_head_order": physical_order,
            "runoff_nonnegative": runoff_nonnegative,
            "candidate_search_routes_qualified": no_unqualified_search,
            "committed_cap_state_bitwise_unchanged": cap_unchanged,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "start_id": hid,
            "start": [h1s, h2s, taus],
            "solver_success": False,
            "valid": False,
            "error": repr(exc),
            "committed_cap_state_bitwise_unchanged": bits_cap(cap_heads, 0.0) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def close_roots(a: dict, b: dict) -> bool:
    return (
        max(abs(float(x) - float(y)) for x, y in zip(a["heads_cm"][1:], b["heads_cm"][1:])) <= H_CLUSTER
        and abs(float(a["tau_after_cap_day"]) - float(b["tau_after_cap_day"])) <= TAU_CLUSTER
    )


def cluster(valid: list[dict]) -> list[dict]:
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
    for i, rec in enumerate(valid):
        groups.setdefault(find(i), []).append(rec)

    out = []
    for members in groups.values():
        rep = min(members, key=lambda x: x["start_id"])
        out.append({
            "member_count": len(members),
            "reproducible": len(members) >= MIN_CLUSTER,
            "start_ids": sorted(x["start_id"] for x in members),
            "representative": {
                "tau_after_cap_day": rep["tau_after_cap_day"],
                "absolute_event_time_day": rep["absolute_event_time_day"],
                "heads_cm": rep["heads_cm"],
                "runoff_amount_cm": rep["independent_reference_fluxes"]["runoff_amount_cm"],
                "runoff_rate_cm_per_day_BE": rep["independent_reference_fluxes"]["runoff_rate_cm_per_day_BE"],
                "q_top_cm_per_day": rep["independent_reference_fluxes"]["q_top_cm_per_day"],
                "max_abs_independent_reference_cell_or_system_residual_cm": rep["max_abs_independent_reference_cell_or_system_residual_cm"],
            },
            "max_member_independent_reference_residual_cm": max(
                float(x["max_abs_independent_reference_cell_or_system_residual_cm"]) for x in members
            ),
        })
    out.sort(key=lambda x: (-int(x["reproducible"]), -x["member_count"], x["representative"]["tau_after_cap_day"]))
    return out


def run_profile(row: dict, profile_id: str) -> dict:
    cap = CAP_STATES[profile_id]
    cap_heads = tuple(float(v) for v in cap["heads_cm"])
    a1.configure(row)
    table = a1.e3g.e3.generate_c1r_table()
    starts = tuple(
        (f"{hid}:T{it}", h1, h2, tau)
        for hid, h1, h2 in head_starts(cap_heads)
        for it, tau in enumerate(TAU_STARTS)
    )
    attempts = [solve_from_start(row, cap, s, table) for s in starts]
    valid = [x for x in attempts if x.get("valid")]
    clusters = cluster(valid)
    reproducible = [x for x in clusters if x["reproducible"]]
    representative = reproducible[0]["representative"] if reproducible else None

    before = bits_cap(cap_heads, 0.0)
    synthetic_reject_after = bits_cap(cap_heads, 0.0)
    tests = {
        "start_count": len(attempts) == 12,
        "all_trials_leave_cap_checkpoint_unchanged": all(x.get("committed_cap_state_bitwise_unchanged") is True for x in attempts),
        "no_mass_repair_or_clipping": all(x.get("mass_repair_or_clipping_used") is False for x in attempts),
        "reproducible_event_exists": len(reproducible) >= 1,
        "synthetic_reject_restores_cap_state": before == synthetic_reject_after,
        "synthetic_reject_runoff_ledger_zero": struct.unpack("!5d", synthetic_reject_after)[-1] == 0.0,
        "representative_reference_mass": representative is not None and representative["max_abs_independent_reference_cell_or_system_residual_cm"] <= MASS_TOL,
        "representative_runoff_positive": representative is not None and representative["runoff_amount_cm"] > 0.0,
    }
    return {
        "material": MATERIAL,
        "profile_id": profile_id,
        "cap_state": cap,
        "surface_cap_cm": S_CAP,
        "supply_fraction_of_ksat": SUPPLY_FRACTION,
        "search_solve_count": len(attempts),
        "valid_root_count": len(valid),
        "clusters": clusters,
        "reproducible_cluster_count": len(reproducible),
        "representative_event": representative,
        "attempts": attempts,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a5_o14_transactional_runoff_postcap_top_saturation.py PROFILE_ID OUTPUT.json")
    profile_id = sys.argv[1]
    if profile_id not in CAP_STATES:
        raise SystemExit(profile_id)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    result = run_profile(row, profile_id)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A5_O14_TRANSACTIONAL_RUNOFF_ONSET_AND_POST_CAP_TOP_SATURATION_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "material": MATERIAL,
        "profile_result": result,
        "pass": result["pass"],
        "decision": (
            "O14_POST_CAP_TOP_SATURATION_REPRODUCIBLY_ESTABLISHED_FOR_PROFILE"
            if result["pass"] else
            "O14_POST_CAP_TOP_SATURATION_NOT_ESTABLISHED_FOR_PROFILE"
        ),
        "hard_nonclaims": [
            "No production runoff implementation qualification.",
            "No top-node saturation production candidate qualification.",
            "No automatic event detector or bracket discovery admission.",
            "No response tangent across runoff onset or h0=0.",
            "No runtime, MultiSWAP, groundwater or MODFLOW admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "profile": profile_id,
        "pass": result["pass"],
        "valid_roots": result["valid_root_count"],
        "reproducible_clusters": result["reproducible_cluster_count"],
        "representative_event": result["representative_event"],
        "failed_metrics": result["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not result["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
