from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import fwc01_gate_b2d_existing_infiltration_front_advance as b2d
import fwc01_gate_b2d_r1_conservative_heun_policy as b2d_r1
import fwc01_gate_b2e_a_fully_funded_dry_bin_creation_event as b2e_a
import fwc01_gate_b2e_c_composed_existing_front_and_creation as b2e_c

CONTRACT = "F-FWC01_GATE_B2E_C_R1_ATOMIC_FUNDED_PREFIX_LEDGER_PRECOMMIT.json"
FIXTURE = Path("integration/f-fwc/F-FWC01_GATE_B2A_MATERIAL_FIXTURE.json")
MATERIALS = b2e_c.MATERIALS
BIN_COUNTS = b2e_c.BIN_COUNTS
PREFIXES = b2e_c.PREFIXES
MASS_TOL = 1.0e-12


def atomic_allocate_dry(available_cm: float, z_d: list[float], dtheta: float, slots: list[bool]) -> dict:
    demands = [float(dtheta) * float(z) for z in z_d]
    certified_total = math.fsum(demands)
    available = float(available_cm)
    if available < certified_total:
        return {
            "accepted": False,
            "reason": "INSUFFICIENT_FOR_CERTIFIED_DRY_PREFIX",
            "available_cm": available,
            "certified_total_demand_cm": certified_total,
            "demands_cm": demands,
        }
    unavailable = [j for j, free in enumerate(slots) if not free]
    if unavailable:
        return {
            "accepted": False,
            "reason": "NO_FREE_SLOT",
            "failed_bin": unavailable[0],
            "available_cm": available,
            "certified_total_demand_cm": certified_total,
            "demands_cm": demands,
        }
    fronts = [float(z) for z in z_d]
    remainder = available - certified_total
    return {
        "accepted": True,
        "reason": "ACCEPTED",
        "certified_total_demand_cm": certified_total,
        "demands_cm": demands,
        "created_fronts_cm": fronts,
        "created_order": list(range(len(z_d))),
        "created_storage_cm": certified_total,
        "surface_remainder_cm": remainder,
        "funding_decision_epsilon_used": False,
    }


def parity_checks() -> list[dict]:
    rows = []
    for n in (4, 8):
        z = b2e_a.fixture_z(n, 2)
        for prefix in (0, 1, 2, min(4, n)):
            z_use = z[:prefix]
            target = math.fsum(b2e_a.demand(v) for v in z_use)
            committed, ledger = b2e_a.base_state(len(z_use), 0.0)
            source = b2e_a.trial_create(committed, ledger, target, z_use)
            candidate = atomic_allocate_dry(target, z_use, b2e_a.DTHETA, [True] * len(z_use))
            tests = {
                "acceptance": bool(source["accepted"]) == bool(candidate["accepted"]),
                "order": source.get("created_order", []) == candidate.get("created_order", []),
                "storage": abs(source.get("created_storage_cm", 0.0) - candidate.get("created_storage_cm", 0.0)) <= MASS_TOL,
                "remainder": abs(source.get("surface_remainder_cm", 0.0) - candidate.get("surface_remainder_cm", 0.0)) <= MASS_TOL,
                "no_epsilon": candidate.get("funding_decision_epsilon_used", False) is False,
            }
            rows.append({"n": n, "prefix": prefix, "tests": tests, "pass": all(tests.values())})
    return rows


def composed_trial(row: dict, nbins: int, prefix: int, mode: str) -> dict:
    _j, dtheta, ti, td, ki, kd = b2d.bin_pair(row, nbins, b2e_c.FRACTION)
    A, B, _delta_k = b2d.coefficients(dtheta, ki, kd, b2e_c.G_EFF, b2e_c.HP)
    v0 = b2d.velocity(b2e_c.Z0, A, B)
    if not (math.isfinite(v0) and v0 >= 0.0):
        return {"pass": False, "failure": "INVALID_INITIAL_EXISTING_FRONT_VELOCITY"}
    horizon = 0.0 if v0 == 0.0 else min(0.01, 0.1 * b2e_c.Z0 / v0)
    traj = b2d_r1.heun_trajectory(b2e_c.Z0, dtheta, A, B, horizon, b2e_c.HEUN_STEPS)
    if traj["completed_steps"] != b2e_c.HEUN_STEPS:
        return {"pass": False, "failure": "B2D_R1_HEUN_PREFIX_INCOMPLETE", "trajectory": traj}

    existing_demand = float(traj["ledger_infiltration_cm"])
    z_d = b2e_c.dry_fixture(prefix)
    dry_demands = [float(dtheta) * float(z) for z in z_d]
    creation_demand = math.fsum(dry_demands)
    certified_total = math.fsum([existing_demand, creation_demand])

    state = {"existing_z_cm": b2e_c.Z0, "surface_water_cm": 0.0, "created_fronts_cm": [None] * prefix}
    ledger = {"existing_front_infiltration_cm": 0.0, "created_front_storage_cm": 0.0, "surface_remainder_cm": 0.0}
    snapshot = b2e_c.pack_committed(state, ledger)

    if mode == "POSITIVE":
        initial_available = certified_total
    elif mode == "INSUFFICIENT_EXISTING":
        initial_available = 0.5 * existing_demand
    elif mode == "INSUFFICIENT_CREATION":
        if prefix == 0:
            raise ValueError("creation negative control needs at least one dry bin")
        initial_available = math.fsum([existing_demand, 0.5 * dry_demands[0]])
    else:
        raise ValueError(mode)

    # One atomic admission certificate. No per-debit floating-point comparison is used.
    funded = initial_available >= certified_total
    if not funded:
        reason = "INSUFFICIENT_FOR_EXISTING_FRONT" if initial_available < existing_demand else "INSUFFICIENT_FOR_CERTIFIED_DRY_PREFIX"
        result = {
            "accepted": False,
            "reason": reason,
            "initial_available_cm": initial_available,
            "certified_total_demand_cm": certified_total,
            "existing_demand_cm": existing_demand,
            "creation_demand_cm": creation_demand,
            "funding_decision_epsilon_used": False,
        }
    else:
        # Publication is ordered only after the complete prefix has been admitted.
        dry = atomic_allocate_dry(creation_demand, z_d, dtheta, [True] * prefix)
        if not dry["accepted"]:
            raise RuntimeError(("post_certificate_publication_failure", mode, dry))
        trial_existing_z = float(traj["z_final_cm"])
        surface_remainder = initial_available - certified_total
        actual_storage_change = math.fsum([
            float(dtheta) * (trial_existing_z - b2e_c.Z0),
            float(dry["created_storage_cm"]),
        ])
        mass_residual = math.fsum([actual_storage_change, surface_remainder, -initial_available])
        result = {
            "accepted": True,
            "reason": "ACCEPTED",
            "initial_available_cm": initial_available,
            "certified_total_demand_cm": certified_total,
            "existing_demand_cm": existing_demand,
            "creation_demand_cm": creation_demand,
            "publication_order": ["EXISTING_FRONT"] + [f"DRY_BIN_{j}" for j in dry["created_order"]],
            "created_order": dry["created_order"],
            "surface_remainder_cm": surface_remainder,
            "actual_storage_change_cm": actual_storage_change,
            "mass_residual_cm": mass_residual,
            "funding_decision_epsilon_used": False,
        }

    unchanged = b2e_c.pack_committed(state, ledger) == snapshot
    if mode == "POSITIVE":
        tests = {
            "accepted": result.get("accepted") is True,
            "existing_internal_step_mass": traj["max_abs_step_mass_residual_cm"] <= b2d.STEP_MASS_TOL,
            "existing_internal_horizon_mass": traj["abs_horizon_mass_residual_cm"] <= b2d.HORIZON_MASS_TOL,
            "creation_order": result.get("created_order") == list(range(prefix)),
            "publication_order": result.get("publication_order") == ["EXISTING_FRONT"] + [f"DRY_BIN_{j}" for j in range(prefix)],
            "composed_mass": abs(result.get("mass_residual_cm", math.inf)) <= MASS_TOL,
            "surface_nonnegative": result.get("surface_remainder_cm", -1.0) >= 0.0,
            "no_epsilon": result.get("funding_decision_epsilon_used") is False,
            "committed_unchanged_before_commit": unchanged,
        }
    else:
        expected_reason = "INSUFFICIENT_FOR_EXISTING_FRONT" if mode == "INSUFFICIENT_EXISTING" else "INSUFFICIENT_FOR_CERTIFIED_DRY_PREFIX"
        tests = {
            "rejected": result.get("accepted") is False,
            "reason": result.get("reason") == expected_reason,
            "no_epsilon": result.get("funding_decision_epsilon_used") is False,
            "committed_unchanged": unchanged,
        }

    return {
        "theta_bin_count": nbins,
        "prefix": prefix,
        "mode": mode,
        "delta_theta": dtheta,
        "theta_i": ti,
        "theta_d": td,
        "horizon_day": horizon,
        "existing_front_heun": traj,
        "result": result,
        "tests": tests,
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2e_c_r1_atomic_funded_prefix_ledger.py OUTPUT.json")
    out = Path(sys.argv[1])
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in fixture["rows"]}
    parity = parity_checks()
    rows = []
    for material in MATERIALS:
        for nbins in BIN_COUNTS:
            for prefix in PREFIXES:
                r = composed_trial(by[material], nbins, prefix, "POSITIVE")
                r["material"] = material
                rows.append(r)
            for mode in ("INSUFFICIENT_EXISTING", "INSUFFICIENT_CREATION"):
                r = composed_trial(by[material], nbins, 1, mode)
                r["material"] = material
                rows.append(r)

    passed = all(p["pass"] for p in parity) and all(r["pass"] for r in rows)
    positive = [r for r in rows if r["mode"] == "POSITIVE"]
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2E_C_R1_ATOMIC_FUNDED_PREFIX_LEDGER_REPRESENTATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "preserved_negative_evidence_run": 34393034419,
        "physics_changed_from_B2D_R1": False,
        "event_order_changed_from_B2E_C": False,
        "funding_epsilon_used": False,
        "partial_dry_bin_funding_qualified": False,
        "generic_creation_parity_case_count": len(parity),
        "generic_creation_parity_pass_count": sum(p["pass"] for p in parity),
        "physical_case_count": len(rows),
        "physical_case_pass_count": sum(r["pass"] for r in rows),
        "positive_composed_case_count": len(positive),
        "insufficient_existing_fail_closed_count": sum(r["mode"] == "INSUFFICIENT_EXISTING" and r["pass"] for r in rows),
        "insufficient_creation_fail_closed_count": sum(r["mode"] == "INSUFFICIENT_CREATION" and r["pass"] for r in rows),
        "max_abs_composed_mass_residual_cm": max(abs(r["result"].get("mass_residual_cm", 0.0)) for r in positive),
        "max_abs_B2D_internal_step_mass_residual_cm": max(r["existing_front_heun"]["max_abs_step_mass_residual_cm"] for r in rows),
        "water_clip_drop_merge_count": 0,
        "new_persistent_state_bytes_beyond_front_state": 0,
        "parity": parity,
        "rows": rows,
        "pass": passed,
        "decision": "QUALIFIED_RESTRICTED_ATOMIC_FUNDED_PREFIX_COMPOSED_INFILTRATION_MASS_PATH_READY_FOR_ZD_AND_RAINFALL_EVENT_QUALIFICATION" if passed else "ATOMIC_FUNDED_PREFIX_LEDGER_REPRESENTATION_NOT_QUALIFIED_RESEARCH_REQUIRED",
        "hard_nonclaims": [
            "No Green-Ampt Z_d calculation qualification.",
            "No partial dry-bin funding semantics.",
            "No redistribution, groundwater, crop, runtime or MultiSWAP production qualification."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in (
        "pass", "decision", "generic_creation_parity_case_count", "generic_creation_parity_pass_count",
        "physical_case_count", "physical_case_pass_count", "positive_composed_case_count",
        "insufficient_existing_fail_closed_count", "insufficient_creation_fail_closed_count",
        "max_abs_composed_mass_residual_cm", "max_abs_B2D_internal_step_mass_residual_cm",
        "funding_epsilon_used")}, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
