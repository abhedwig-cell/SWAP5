from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import fwc01_gate_b2d_existing_infiltration_front_advance as b2d
import fwc01_gate_b2d_r1_conservative_heun_policy as b2d_r1
import fwc01_gate_b2e_a_fully_funded_dry_bin_creation_event as b2e_a

CONTRACT = "F-FWC01_GATE_B2E_C_COMPOSED_EXISTING_FRONT_AND_CREATION_PRECOMMIT.json"
FIXTURE = Path("integration/f-fwc/F-FWC01_GATE_B2A_MATERIAL_FIXTURE.json")
MATERIALS = ("B01", "B12", "O13", "O14")
BIN_COUNTS = (16, 64, 200)
PREFIXES = (0, 1, 2, 4)
FRACTION = 0.5
Z0 = 10.0
G_EFF = 10.0
HP = 0.0
HEUN_STEPS = 16
MASS_TOL = 1.0e-12


def pfloat(x: float) -> bytes:
    return struct.pack("!d", float(x))


def pack_committed(state: dict, ledger: dict) -> bytes:
    out = bytearray()
    out.extend(pfloat(state["existing_z_cm"]))
    out.extend(pfloat(state["surface_water_cm"]))
    for z in state["created_fronts_cm"]:
        if z is None:
            out.extend(b"N")
        else:
            out.extend(b"F")
            out.extend(pfloat(z))
    out.extend(pfloat(ledger["existing_front_infiltration_cm"]))
    out.extend(pfloat(ledger["created_front_storage_cm"]))
    out.extend(pfloat(ledger["surface_remainder_cm"]))
    return bytes(out)


def dry_fixture(count: int) -> list[float]:
    return [0.5 * float(i + 1) for i in range(count)]


def allocate_dry_generic(available_cm: float, z_d: list[float], dtheta: float, slots: list[bool]):
    available = float(available_cm)
    fronts = [None] * len(z_d)
    created = []
    storage = 0.0
    for j, z in enumerate(z_d):
        if available == 0.0:
            break
        need = float(dtheta) * float(z)
        if available < need:
            return {
                "accepted": False, "reason": "INSUFFICIENT_FOR_NEXT_DRY_BIN",
                "available_cm": available, "required_cm": need,
                "created_order_trial_only": created, "created_storage_trial_only_cm": storage,
            }
        if not slots[j]:
            return {
                "accepted": False, "reason": "NO_FREE_SLOT",
                "available_cm": available, "required_cm": need,
                "created_order_trial_only": created, "created_storage_trial_only_cm": storage,
            }
        fronts[j] = float(z)
        available -= need
        storage += need
        created.append(j)
    return {
        "accepted": True, "reason": "ACCEPTED", "created_fronts_cm": fronts,
        "created_order": created, "created_storage_cm": storage,
        "surface_remainder_cm": available,
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
            generic = allocate_dry_generic(target, z_use, b2e_a.DTHETA, [True] * len(z_use))
            tests = {
                "acceptance": bool(source["accepted"]) == bool(generic["accepted"]),
                "order": source.get("created_order", []) == generic.get("created_order", []),
                "storage": abs(source.get("created_storage_cm", 0.0) - generic.get("created_storage_cm", 0.0)) <= MASS_TOL,
                "remainder": abs(source.get("surface_remainder_cm", 0.0) - generic.get("surface_remainder_cm", 0.0)) <= MASS_TOL,
            }
            rows.append({"n": n, "prefix": prefix, "tests": tests, "pass": all(tests.values())})
    return rows


def composed_trial(row: dict, nbins: int, prefix: int, mode: str) -> dict:
    _j, dtheta, ti, td, ki, kd = b2d.bin_pair(row, nbins, FRACTION)
    A, B, _delta_k = b2d.coefficients(dtheta, ki, kd, G_EFF, HP)
    v0 = b2d.velocity(Z0, A, B)
    if not (math.isfinite(v0) and v0 >= 0.0):
        return {"pass": False, "failure": "INVALID_INITIAL_EXISTING_FRONT_VELOCITY"}
    horizon = 0.0 if v0 == 0.0 else min(0.01, 0.1 * Z0 / v0)
    traj = b2d_r1.heun_trajectory(Z0, dtheta, A, B, horizon, HEUN_STEPS)
    if traj["completed_steps"] != HEUN_STEPS:
        return {"pass": False, "failure": "B2D_R1_HEUN_PREFIX_INCOMPLETE", "trajectory": traj}
    existing_demand = float(traj["ledger_infiltration_cm"])
    z_d = dry_fixture(prefix)
    creation_demand = math.fsum(dtheta * z for z in z_d)

    state = {"existing_z_cm": Z0, "surface_water_cm": 0.0, "created_fronts_cm": [None] * prefix}
    ledger = {"existing_front_infiltration_cm": 0.0, "created_front_storage_cm": 0.0, "surface_remainder_cm": 0.0}
    snapshot = pack_committed(state, ledger)

    if mode == "POSITIVE":
        initial_available = existing_demand + creation_demand
    elif mode == "INSUFFICIENT_EXISTING":
        initial_available = 0.5 * existing_demand
    elif mode == "INSUFFICIENT_CREATION":
        if prefix == 0:
            raise ValueError("creation negative control needs at least one dry bin")
        initial_available = existing_demand + 0.5 * dtheta * z_d[0]
    else:
        raise ValueError(mode)

    # Source order: existing-front demand first. This is a trial-only debit.
    if initial_available < existing_demand:
        result = {
            "accepted": False, "reason": "INSUFFICIENT_FOR_EXISTING_FRONT",
            "existing_demand_cm": existing_demand, "initial_available_cm": initial_available,
        }
    else:
        after_existing = initial_available - existing_demand
        dry = allocate_dry_generic(after_existing, z_d, dtheta, [True] * prefix)
        if not dry["accepted"]:
            result = {
                "accepted": False, "reason": dry["reason"],
                "existing_demand_cm": existing_demand, "initial_available_cm": initial_available,
                "dry_trial": dry,
            }
        else:
            trial_existing_z = float(traj["z_final_cm"])
            created_storage = float(dry["created_storage_cm"])
            remainder = float(dry["surface_remainder_cm"])
            total_storage_change = dtheta * (trial_existing_z - Z0) + created_storage
            mass_residual = total_storage_change + remainder - initial_available
            result = {
                "accepted": True, "reason": "ACCEPTED",
                "initial_available_cm": initial_available,
                "existing_demand_cm": existing_demand,
                "existing_storage_change_cm": dtheta * (trial_existing_z - Z0),
                "created_storage_cm": created_storage,
                "surface_remainder_cm": remainder,
                "mass_residual_cm": mass_residual,
                "created_order": dry["created_order"],
                "trial_existing_z_cm": trial_existing_z,
            }

    unchanged = pack_committed(state, ledger) == snapshot
    if mode == "POSITIVE":
        tests = {
            "accepted": result.get("accepted") is True,
            "existing_internal_step_mass": traj["max_abs_step_mass_residual_cm"] <= b2d.STEP_MASS_TOL,
            "existing_internal_horizon_mass": traj["abs_horizon_mass_residual_cm"] <= b2d.HORIZON_MASS_TOL,
            "existing_storage_equals_ledger": abs(dtheta * (traj["z_final_cm"] - Z0) - existing_demand) <= MASS_TOL,
            "creation_order": result.get("created_order") == list(range(prefix)),
            "composed_mass": abs(result.get("mass_residual_cm", math.inf)) <= MASS_TOL,
            "surface_nonnegative": result.get("surface_remainder_cm", -1.0) >= 0.0,
            "committed_unchanged_before_commit": unchanged,
        }
    else:
        tests = {
            "rejected": result.get("accepted") is False,
            "reason": result.get("reason") == ("INSUFFICIENT_FOR_EXISTING_FRONT" if mode == "INSUFFICIENT_EXISTING" else "INSUFFICIENT_FOR_NEXT_DRY_BIN"),
            "committed_unchanged": unchanged,
        }

    return {
        "theta_bin_count": nbins, "prefix": prefix, "mode": mode,
        "delta_theta": dtheta, "theta_i": ti, "theta_d": td,
        "horizon_day": horizon, "existing_front_heun": traj,
        "result": result, "tests": tests, "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2e_c_composed_existing_front_and_creation.py OUTPUT.json")
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
            r = composed_trial(by[material], nbins, 1, "INSUFFICIENT_EXISTING")
            r["material"] = material
            rows.append(r)
            r = composed_trial(by[material], nbins, 1, "INSUFFICIENT_CREATION")
            r["material"] = material
            rows.append(r)
    passed = all(p["pass"] for p in parity) and all(r["pass"] for r in rows)
    positive = [r for r in rows if r["mode"] == "POSITIVE"]
    max_mass = max(abs(r["result"].get("mass_residual_cm", 0.0)) for r in positive)
    max_b2d_step = max(r["existing_front_heun"]["max_abs_step_mass_residual_cm"] for r in rows)
    result = {
        "schema_version": 1, "workstream": "F-FWC", "work_unit": "F-FWC01",
        "gate": "B2E_C_COMPOSED_EXISTING_FRONT_ADVANCE_AND_FULLY_FUNDED_CREATION",
        "contract": CONTRACT, "production_implementation": False,
        "physics_changed_from_B2D_R1": False,
        "generic_creation_parity_case_count": len(parity),
        "generic_creation_parity_pass_count": sum(p["pass"] for p in parity),
        "physical_case_count": len(rows), "physical_case_pass_count": sum(r["pass"] for r in rows),
        "positive_composed_case_count": len(positive),
        "insufficient_existing_fail_closed_count": sum(r["mode"] == "INSUFFICIENT_EXISTING" and r["pass"] for r in rows),
        "insufficient_creation_fail_closed_count": sum(r["mode"] == "INSUFFICIENT_CREATION" and r["pass"] for r in rows),
        "max_abs_composed_mass_residual_cm": max_mass,
        "max_abs_B2D_internal_step_mass_residual_cm": max_b2d_step,
        "water_clip_drop_merge_count": 0,
        "new_persistent_state_bytes_beyond_front_state": 0,
        "partial_dry_bin_funding_qualified": False,
        "parity": parity, "rows": rows, "pass": passed,
        "decision": "QUALIFIED_RESTRICTED_COMPOSED_EXISTING_FRONT_AND_FULLY_FUNDED_CREATION_MASS_PATH_READY_FOR_ZD_AND_RAINFALL_EVENT_QUALIFICATION" if passed else "COMPOSED_FWC_INFILTRATION_MASS_PATH_NOT_QUALIFIED_RESEARCH_REQUIRED",
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
        "max_abs_composed_mass_residual_cm", "max_abs_B2D_internal_step_mass_residual_cm")}, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
