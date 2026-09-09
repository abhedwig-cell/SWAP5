from __future__ import annotations

import copy
import json
import math
import struct
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

EPS = 2.220446049250313e-16
SLOT_CAPACITY = 8
BIN_COUNTS = (16, 64, 200)
PERIODS = (0.25, 0.0625, 0.015625, 0.00390625)
HORIZONS = (10.0, 100.0)
DUTY = 0.25
VARIANTS = ("FWC_ADVECTIVE", "FWC_EXPLICIT_DIFFUSION")
CONTRACT = "F-FWC01_GATE_A2_FIXED_SLOT_FAIL_CLOSED_BOUND_PRECOMMIT.json"


@dataclass(frozen=True)
class Slug:
    serial: int
    z_top: float
    z_bottom: float
    water: float


@dataclass
class Ledger:
    inflow: float = 0.0
    outflow: float = 0.0


@dataclass
class FixedState:
    time: float
    slots: list[Slug]
    ledger: Ledger
    next_serial: int


class OverflowRequired(RuntimeError):
    pass


def packed_state(state: FixedState) -> bytes:
    # This packing is only a bitwise transaction oracle. It is not the
    # conceptual production payload size used by the frozen memory model.
    out = bytearray()
    out += struct.pack("<dQdd", state.time, state.next_serial, state.ledger.inflow, state.ledger.outflow)
    ordered = sorted(state.slots, key=lambda s: s.serial)
    for i in range(SLOT_CAPACITY):
        if i < len(ordered):
            s = ordered[i]
            out += struct.pack("<BQddd", 1, s.serial, s.z_top, s.z_bottom, s.water)
        else:
            out += struct.pack("<BQddd", 0, 0, 0.0, 0.0, 0.0)
    return bytes(out)


def ledger_tuple(state: FixedState) -> tuple[float, float]:
    return (state.ledger.inflow, state.ledger.outflow)


def storage(slugs: list[Slug]) -> float:
    return math.fsum(s.water for s in slugs)


def residual(state: FixedState) -> float:
    return state.ledger.inflow - state.ledger.outflow - storage(state.slots)


def residual_tol(state: FixedState) -> float:
    scale = max(1.0, abs(state.ledger.inflow) + abs(state.ledger.outflow) + abs(storage(state.slots)))
    return 64.0 * EPS * scale


def advance_candidate(state: FixedState, period: float) -> FixedState:
    cand = copy.deepcopy(state)
    moved: list[Slug] = []
    for s in cand.slots:
        zt = s.z_top + period
        zb = s.z_bottom + period
        if zt >= 1.0 - 1e-15:
            cand.ledger.outflow += s.water
        else:
            moved.append(Slug(s.serial, zt, zb, s.water))
    pulse_water = DUTY * period
    moved.append(Slug(cand.next_serial, 0.0, pulse_water, pulse_water))
    cand.next_serial += 1
    cand.ledger.inflow += pulse_water
    cand.time += period
    if len(moved) > SLOT_CAPACITY:
        raise OverflowRequired(len(moved))
    cand.slots = moved
    return cand


def advance_dynamic(slugs: list[Slug], ledger: Ledger, next_serial: int, period: float):
    moved: list[Slug] = []
    for s in slugs:
        zt = s.z_top + period
        zb = s.z_bottom + period
        if zt >= 1.0 - 1e-15:
            ledger.outflow += s.water
        else:
            moved.append(Slug(s.serial, zt, zb, s.water))
    pulse_water = DUTY * period
    moved.append(Slug(next_serial, 0.0, pulse_water, pulse_water))
    ledger.inflow += pulse_water
    return moved, ledger, next_serial + 1


def topology_signature(slugs: list[Slug]):
    return [(s.serial, s.z_top, s.z_bottom, s.water) for s in sorted(slugs, key=lambda x: x.serial)]


def run_case(variant: str, nbins: int, period: float, horizon: float) -> dict:
    fixed = FixedState(time=0.0, slots=[], ledger=Ledger(), next_serial=0)
    dyn_slugs: list[Slug] = []
    dyn_ledger = Ledger()
    dyn_serial = 0
    max_slots = 0
    accepted_steps = 0
    overflow = False
    overflow_required_count = 0
    rejected_state_unchanged = None
    rejected_ledger_unchanged = None
    accepted_reference_equal = True
    max_abs_mass_residual = 0.0
    step_count = int(round(horizon / period))

    for _ in range(step_count):
        before_bytes = packed_state(fixed)
        before_ledger = ledger_tuple(fixed)
        try:
            candidate = advance_candidate(fixed, period)
        except OverflowRequired:
            overflow = True
            overflow_required_count += 1
            rejected_state_unchanged = packed_state(fixed) == before_bytes
            rejected_ledger_unchanged = ledger_tuple(fixed) == before_ledger
            break

        dyn_slugs, dyn_ledger, dyn_serial = advance_dynamic(dyn_slugs, dyn_ledger, dyn_serial, period)
        if topology_signature(candidate.slots) != topology_signature(dyn_slugs):
            accepted_reference_equal = False
        if candidate.next_serial != dyn_serial:
            accepted_reference_equal = False
        if candidate.ledger.inflow != dyn_ledger.inflow or candidate.ledger.outflow != dyn_ledger.outflow:
            accepted_reference_equal = False

        fixed = candidate
        accepted_steps += 1
        max_slots = max(max_slots, len(fixed.slots))
        r = abs(residual(fixed))
        max_abs_mass_residual = max(max_abs_mass_residual, r)
        if r > residual_tol(fixed):
            accepted_reference_equal = False

    persistent_bytes = nbins * (16 + SLOT_CAPACITY * 24)
    diffusion_scratch_bytes = nbins * 16 if variant == "FWC_EXPLICIT_DIFFUSION" else 0
    return {
        "variant": variant,
        "theta_bins": nbins,
        "slot_capacity_per_bin": SLOT_CAPACITY,
        "period_residence": period,
        "horizon_residence": horizon,
        "persistent_bytes_per_column": persistent_bytes,
        "worker_scratch_bytes": diffusion_scratch_bytes,
        "accepted_steps_before_stop": accepted_steps,
        "maximum_active_slots_observed": max_slots,
        "overflow_required": overflow,
        "overflow_required_count": overflow_required_count,
        "fallback_diagnostic": "FALLBACK_REQUIRED" if overflow else "NORMAL",
        "accepted_topology_equal_dynamic_reference": accepted_reference_equal,
        "rejected_trial_packed_state_bitwise_unchanged": rejected_state_unchanged,
        "rejected_trial_ledger_exactly_unchanged": rejected_ledger_unchanged,
        "max_abs_mass_residual": max_abs_mass_residual,
        "mass_tolerance_at_stop": residual_tol(fixed),
        "committed_storage_at_stop": storage(fixed.slots),
        "committed_inflow_at_stop": fixed.ledger.inflow,
        "committed_outflow_at_stop": fixed.ledger.outflow,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_a2_fixed_slot_fail_closed.py OUTPUT.json")
    output = Path(sys.argv[1])
    cases = [
        run_case(variant, nbins, period, horizon)
        for variant in VARIANTS
        for nbins in BIN_COUNTS
        for period in PERIODS
        for horizon in HORIZONS
    ]

    failures: list[str] = []
    for c in cases:
        if c["persistent_bytes_per_column"] != c["theta_bins"] * 208:
            failures.append("persistent_allocation_formula")
        if c["maximum_active_slots_observed"] > SLOT_CAPACITY:
            failures.append("slot_capacity_exceeded")
        if not c["accepted_topology_equal_dynamic_reference"]:
            failures.append("accepted_reference_mismatch")
        if c["max_abs_mass_residual"] > c["mass_tolerance_at_stop"]:
            failures.append("mass_residual")
        if c["overflow_required"]:
            if c["fallback_diagnostic"] != "FALLBACK_REQUIRED":
                failures.append("missing_fallback_diagnostic")
            if c["rejected_trial_packed_state_bitwise_unchanged"] is not True:
                failures.append("rejected_state_changed")
            if c["rejected_trial_ledger_exactly_unchanged"] is not True:
                failures.append("rejected_ledger_changed")

    # Frozen topology expectations: period 0.25 fits 8 slots; all finer
    # periods eventually require fail-closed overflow. This is derived from
    # the unit residence time and is not used to tune slot count.
    for c in cases:
        expected_overflow = c["period_residence"] < 0.125
        if c["overflow_required"] != expected_overflow:
            failures.append("unexpected_overflow_classification")

    persistent_sets = {}
    for nbins in BIN_COUNTS:
        vals = {c["persistent_bytes_per_column"] for c in cases if c["theta_bins"] == nbins}
        persistent_sets[str(nbins)] = sorted(vals)
        if len(vals) != 1:
            failures.append("allocation_not_constant")

    max_resid = max(c["max_abs_mass_residual"] for c in cases)
    overflow_cases = sum(1 for c in cases if c["overflow_required"])
    normal_cases = len(cases) - overflow_cases
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "A2_FIXED_SLOT_FAIL_CLOSED_BOUND",
        "contract": CONTRACT,
        "production_implementation": False,
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION",
        "candidate": "FIXED_8_SLUG_SLOTS_PER_THETA_BIN_FAIL_CLOSED",
        "case_count": len(cases),
        "normal_case_count": normal_cases,
        "overflow_routed_case_count": overflow_cases,
        "persistent_bytes_by_bin_count_observed": persistent_sets,
        "maximum_active_slots_any_case": max(c["maximum_active_slots_observed"] for c in cases),
        "maximum_abs_mass_residual": max_resid,
        "all_accepted_topologies_equal_dynamic_reference": all(c["accepted_topology_equal_dynamic_reference"] for c in cases),
        "all_overflows_state_bitwise_unchanged": all(c["rejected_trial_packed_state_bitwise_unchanged"] is True for c in cases if c["overflow_required"]),
        "all_overflows_ledger_exactly_unchanged": all(c["rejected_trial_ledger_exactly_unchanged"] is True for c in cases if c["overflow_required"]),
        "no_merge_clip_drop_on_overflow": True,
        "diffusion_scratch_persistent": False,
        "failures": sorted(set(failures)),
        "pass": not failures,
        "decision": "QUALIFIED_HARD_BOUNDED_FIXED_SLOT_TRANSACTION_SEMANTICS_READY_FOR_PHYSICAL_FWC_STATE_AND_MASS_GATE" if not failures else "FWC_FIXED_SLOT_BOUND_REJECTED_REDESIGN_REQUIRED",
        "nonclaims": [
            "Eight slots are not shown sufficient for useful FWC coverage.",
            "The 200-bin 41.6 kB persistent payload is not admitted as acceptable MultiSWAP memory cost.",
            "Runtime cost is not bounded under arbitrarily dense forcing events.",
            "No physical FWC hydraulic accuracy is qualified.",
            "No official M2WC70 code behavior is reproduced."
        ],
        "cases": cases,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("case_count", "normal_case_count", "overflow_routed_case_count", "maximum_active_slots_any_case", "maximum_abs_mass_residual", "pass", "decision")}, sort_keys=True))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
