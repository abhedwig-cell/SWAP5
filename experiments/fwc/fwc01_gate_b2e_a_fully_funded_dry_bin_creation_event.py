from __future__ import annotations

import json
import math
import struct
import sys
from copy import deepcopy
from pathlib import Path

CONTRACT = "F-FWC01_GATE_B2E_A_FULLY_FUNDED_DRY_BIN_CREATION_EVENT_PRECOMMIT.json"
BIN_COUNTS = (16, 64, 200)
PREFIXES = (0, 1, 2, 4)
REPETITIONS = 8
MASS_TOL = 1.0e-12
DTHETA = 2.0 ** -10
Z_UNIT = 2.0 ** -10


def pack_float(x: float) -> bytes:
    return struct.pack("!d", float(x))


def pack_state(state: dict) -> bytes:
    out = bytearray()
    out.extend(pack_float(state["surface_water_cm"]))
    for value in state["fronts_cm"]:
        if value is None:
            out.extend(b"N")
        else:
            out.extend(b"F")
            out.extend(pack_float(value))
    for free in state["slot_free"]:
        out.extend(b"1" if free else b"0")
    return bytes(out)


def pack_ledger(ledger: dict) -> bytes:
    return b"".join(pack_float(ledger[k]) for k in ("created_front_storage_cm", "surface_remainder_cm"))


def fixture_z(n: int, repetition: int) -> list[float]:
    # Immutable fixture data. Exact binary fractions avoid hiding event semantics behind roundoff.
    scale = 1 + repetition
    return [float((j + 1) * scale * Z_UNIT) for j in range(n)]


def demand(z: float) -> float:
    return DTHETA * float(z)


def trial_create(committed: dict, committed_ledger: dict, rainfall_cm: float, z_d: list[float]) -> dict:
    state_before = pack_state(committed)
    ledger_before = pack_ledger(committed_ledger)
    trial = deepcopy(committed)
    trial_ledger = dict(committed_ledger)
    available = float(committed["surface_water_cm"]) + float(rainfall_cm)
    created_order = []
    created_storage = 0.0

    for j, z in enumerate(z_d):
        if available == 0.0:
            break
        if trial["fronts_cm"][j] is not None:
            raise RuntimeError("B2E-A fixture forbids pre-existing fronts")
        need = demand(z)
        if available < need:
            return {
                "accepted": False,
                "fallback_required": True,
                "reason": "INSUFFICIENT_FOR_NEXT_DRY_BIN",
                "failed_bin": j,
                "required_cm": need,
                "available_cm": available,
                "committed_state_bitwise_unchanged": pack_state(committed) == state_before,
                "committed_ledger_bitwise_unchanged": pack_ledger(committed_ledger) == ledger_before,
                "created_order_trial_only": created_order,
            }
        if not trial["slot_free"][j]:
            return {
                "accepted": False,
                "fallback_required": True,
                "reason": "NO_FREE_SLOT",
                "failed_bin": j,
                "required_cm": need,
                "available_cm": available,
                "committed_state_bitwise_unchanged": pack_state(committed) == state_before,
                "committed_ledger_bitwise_unchanged": pack_ledger(committed_ledger) == ledger_before,
                "created_order_trial_only": created_order,
            }
        trial["fronts_cm"][j] = float(z)
        trial["slot_free"][j] = False
        available -= need
        created_storage += need
        created_order.append(j)

    trial["surface_water_cm"] = available
    trial_ledger["created_front_storage_cm"] += created_storage
    trial_ledger["surface_remainder_cm"] = available
    initial_total = float(committed["surface_water_cm"]) + float(rainfall_cm)
    final_total = created_storage + available
    mass_residual = final_total - initial_total
    accepted = bool(available >= 0.0 and abs(mass_residual) <= MASS_TOL)
    return {
        "accepted": accepted,
        "fallback_required": False,
        "reason": "ACCEPTED" if accepted else "MASS_CERTIFICATE_FAILURE",
        "trial_state": trial,
        "trial_ledger": trial_ledger,
        "created_order": created_order,
        "created_storage_cm": created_storage,
        "surface_remainder_cm": available,
        "initial_available_cm": initial_total,
        "mass_residual_cm": mass_residual,
        "committed_state_bitwise_unchanged_before_commit": pack_state(committed) == state_before,
        "committed_ledger_bitwise_unchanged_before_commit": pack_ledger(committed_ledger) == ledger_before,
    }


def base_state(n: int, initial_surface: float = 0.0) -> tuple[dict, dict]:
    return (
        {"surface_water_cm": float(initial_surface), "fronts_cm": [None] * n, "slot_free": [True] * n},
        {"created_front_storage_cm": 0.0, "surface_remainder_cm": float(initial_surface)},
    )


def run_case(n: int, repetition: int, kind: str, prefix: int | None = None) -> dict:
    z = fixture_z(n, repetition)
    initial_surface = (repetition % 4) * (2.0 ** -24)
    committed, ledger = base_state(n, initial_surface)
    state_snapshot = pack_state(committed)
    ledger_snapshot = pack_ledger(ledger)

    if kind == "FULLY_FUNDED_PREFIX":
        p = min(int(prefix or 0), n)
        target = math.fsum(demand(x) for x in z[:p])
        rainfall = target - initial_surface
        if rainfall < 0.0:
            initial_surface = 0.0
            committed, ledger = base_state(n, initial_surface)
            state_snapshot = pack_state(committed); ledger_snapshot = pack_ledger(ledger)
            rainfall = target
        result = trial_create(committed, ledger, rainfall, z)
        expected_order = list(range(p))
        tests = {
            "accepted": result["accepted"] is True,
            "created_order": result.get("created_order") == expected_order,
            "zero_surface_remainder": abs(result.get("surface_remainder_cm", math.inf)) <= MASS_TOL,
            "mass": abs(result.get("mass_residual_cm", math.inf)) <= MASS_TOL,
            "surface_nonnegative": result.get("surface_remainder_cm", -1.0) >= 0.0,
            "trial_did_not_mutate_committed_state": pack_state(committed) == state_snapshot,
            "trial_did_not_mutate_committed_ledger": pack_ledger(ledger) == ledger_snapshot,
        }
    elif kind == "FULLY_FUNDED_ALL_WITH_PONDING":
        target = math.fsum(demand(x) for x in z)
        pond = (repetition + 1) * (2.0 ** -18)
        rainfall = target + pond - initial_surface
        result = trial_create(committed, ledger, rainfall, z)
        tests = {
            "accepted": result["accepted"] is True,
            "created_order": result.get("created_order") == list(range(n)),
            "ponding_preserved": abs(result.get("surface_remainder_cm", math.inf) - pond) <= MASS_TOL,
            "mass": abs(result.get("mass_residual_cm", math.inf)) <= MASS_TOL,
            "surface_nonnegative": result.get("surface_remainder_cm", -1.0) >= 0.0,
            "trial_did_not_mutate_committed_state": pack_state(committed) == state_snapshot,
            "trial_did_not_mutate_committed_ledger": pack_ledger(ledger) == ledger_snapshot,
        }
    elif kind == "INSUFFICIENT_FOR_NEXT_DRY_BIN":
        first = demand(z[0])
        second = demand(z[1])
        target = first + 0.5 * second
        rainfall = target - initial_surface
        if rainfall < 0.0:
            committed, ledger = base_state(n, 0.0)
            state_snapshot = pack_state(committed); ledger_snapshot = pack_ledger(ledger)
            rainfall = target
        result = trial_create(committed, ledger, rainfall, z)
        tests = {
            "rejected": result["accepted"] is False,
            "fallback": result["fallback_required"] is True,
            "reason": result["reason"] == "INSUFFICIENT_FOR_NEXT_DRY_BIN",
            "failed_at_second_bin": result["failed_bin"] == 1,
            "committed_state_unchanged": pack_state(committed) == state_snapshot and result["committed_state_bitwise_unchanged"],
            "committed_ledger_unchanged": pack_ledger(ledger) == ledger_snapshot and result["committed_ledger_bitwise_unchanged"],
        }
    elif kind == "NO_FREE_SLOT":
        need = demand(z[0])
        rainfall = need - initial_surface
        if rainfall < 0.0:
            committed, ledger = base_state(n, 0.0)
            state_snapshot = pack_state(committed); ledger_snapshot = pack_ledger(ledger)
            rainfall = need
        committed["slot_free"][0] = False
        state_snapshot = pack_state(committed)
        result = trial_create(committed, ledger, rainfall, z)
        tests = {
            "rejected": result["accepted"] is False,
            "fallback": result["fallback_required"] is True,
            "reason": result["reason"] == "NO_FREE_SLOT",
            "failed_at_first_bin": result["failed_bin"] == 0,
            "committed_state_unchanged": pack_state(committed) == state_snapshot and result["committed_state_bitwise_unchanged"],
            "committed_ledger_unchanged": pack_ledger(ledger) == ledger_snapshot and result["committed_ledger_bitwise_unchanged"],
        }
    else:
        raise ValueError(kind)

    return {
        "bin_count": n, "repetition": repetition, "kind": kind, "prefix": prefix,
        "pass": all(tests.values()), "tests": tests,
        "mass_residual_cm": result.get("mass_residual_cm"),
        "created_count": len(result.get("created_order", [])),
        "surface_remainder_cm": result.get("surface_remainder_cm"),
        "reason": result["reason"],
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2e_a_fully_funded_dry_bin_creation_event.py OUTPUT.json")
    out = Path(sys.argv[1])
    cases = []
    for n in BIN_COUNTS:
        for r in range(REPETITIONS):
            for p in PREFIXES:
                cases.append(run_case(n, r, "FULLY_FUNDED_PREFIX", p))
            cases.append(run_case(n, r, "FULLY_FUNDED_ALL_WITH_PONDING"))
            cases.append(run_case(n, r, "INSUFFICIENT_FOR_NEXT_DRY_BIN"))
            cases.append(run_case(n, r, "NO_FREE_SLOT"))
    passed = all(c["pass"] for c in cases)
    mass_values = [abs(c["mass_residual_cm"]) for c in cases if c["mass_residual_cm"] is not None]
    result = {
        "schema_version": 1, "workstream": "F-FWC", "work_unit": "F-FWC01",
        "gate": "B2E_A_FULLY_FUNDED_DRY_BIN_CREATION_MASS_EVENT", "contract": CONTRACT,
        "production_implementation": False, "case_count": len(cases), "case_pass_count": sum(c["pass"] for c in cases),
        "max_abs_mass_residual_cm": max(mass_values, default=0.0),
        "accepted_case_count": sum(c["reason"] == "ACCEPTED" for c in cases),
        "insufficient_fallback_count": sum(c["reason"] == "INSUFFICIENT_FOR_NEXT_DRY_BIN" for c in cases),
        "slot_fallback_count": sum(c["reason"] == "NO_FREE_SLOT" for c in cases),
        "water_clip_drop_merge_count": 0,
        "new_persistent_state_bytes_beyond_front_state": 0,
        "Z_d_owner": "immutable_fixture_not_per_column_persistent_state",
        "partial_dry_bin_funding_qualified": False,
        "cases": cases, "pass": passed,
        "decision": "QUALIFIED_RESTRICTED_FULLY_FUNDED_DRY_BIN_CREATION_MASS_EVENT_READY_FOR_ZD_PROVENANCE_AND_COMPOSED_INFILTRATION_GATE" if passed else "DRY_BIN_CREATION_MASS_EVENT_NOT_QUALIFIED_RESEARCH_REQUIRED",
        "hard_nonclaims": ["No Green-Ampt Z_d computation qualification.", "No partial dry-bin funding semantics.", "No redistribution, groundwater, runtime or MultiSWAP production qualification."]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("pass","decision","case_count","case_pass_count","max_abs_mass_residual_cm","accepted_case_count","insufficient_fallback_count","slot_fallback_count")}, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
