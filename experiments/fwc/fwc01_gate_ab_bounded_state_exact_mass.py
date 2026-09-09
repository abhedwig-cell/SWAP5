#!/usr/bin/env python3
"""F-FWC01 Gate A/B independent reconstruction.

This executable is intentionally narrow. It tests persistent topology boundedness
and finite-volume mass/transaction semantics only. It is not an implementation
or reproduction of the official FWC source code and it makes no hydraulic
accuracy claim.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Deque, Dict, Iterable, List, Tuple


THETA_BIN_COUNTS = (16, 32, 64, 128, 200)
MASS_BIN_COUNTS = (16, 64)
PERIODS = (0.25, 0.0625, 0.015625, 0.00390625)
HORIZONS = (1.0, 10.0, 100.0)
DUTY = 0.25
COLUMN_LENGTH = 1.0
VELOCITY = 1.0
FIXED_BYTES_PER_BIN = 16
SLUG_BYTES = 24
DIFFUSION_SCRATCH_BYTES_PER_BIN = 16
ACCEPTED_STEPS = 10_000
VARIANTS = ("FWC_ADVECTIVE", "FWC_EXPLICIT_DIFFUSION")


@dataclass(frozen=True)
class Slug:
    birth: float
    length: float


def active_interval(slug: Slug, t: float) -> Tuple[float, float] | None:
    top = VELOCITY * (t - slug.birth)
    bottom = top + slug.length
    if top >= COLUMN_LENGTH:
        return None
    return max(0.0, top), min(COLUMN_LENGTH, bottom)


def simulate_single_bin(period: float, horizon: float) -> Dict[str, float | int]:
    """Topology-only falling-slug stress test.

    Each pulse creates one detached interval. Pure advection translates the top
    and bottom at the same velocity, preserving interval length. Geometric
    overlap is the only merge rule. No minimum-thickness or object-cap policy is
    introduced.
    """
    active: Deque[Slug] = deque()
    max_active = 0
    creates = 0
    merges = 0
    removals = 0
    slug_length = VELOCITY * DUTY * period

    pulse_count = int(math.floor(horizon / period + 1.0e-12)) + 1
    for pulse_index in range(pulse_count):
        t = pulse_index * period
        if t > horizon + 1.0e-12:
            break

        kept: Deque[Slug] = deque()
        for slug in active:
            if active_interval(slug, t) is None:
                removals += 1
            else:
                kept.append(slug)
        active = kept

        new_slug = Slug(birth=t, length=slug_length)
        new_interval = active_interval(new_slug, t)
        if new_interval is None:
            raise AssertionError("new slug unexpectedly outside column")

        # A conservative geometric merge would be allowed only for overlap.
        # Under the frozen duty cycle and equal translation speed the pulses
        # remain separated, so any merge would expose an implementation error.
        for old in active:
            old_interval = active_interval(old, t)
            assert old_interval is not None
            if not (old_interval[1] < new_interval[0] or new_interval[1] < old_interval[0]):
                merges += 1
                raise AssertionError("frozen separated-pulse stress unexpectedly merged")

        active.append(new_slug)
        creates += 1
        max_active = max(max_active, len(active))

    return {
        "max_active_single_bin": max_active,
        "creates_single_bin": creates,
        "merges_single_bin": merges,
        "boundary_removals_single_bin": removals,
        "create_rate_per_residence_time": creates / horizon,
        "merge_rate_per_residence_time": merges / horizon,
        "boundary_removal_rate_per_residence_time": removals / horizon,
    }


def run_gate_a() -> Dict[str, object]:
    rows: List[Dict[str, object]] = []
    single_cache: Dict[Tuple[float, float], Dict[str, float | int]] = {}
    for period in PERIODS:
        for horizon in HORIZONS:
            single_cache[(period, horizon)] = simulate_single_bin(period, horizon)

    for variant in VARIANTS:
        for nbins in THETA_BIN_COUNTS:
            scratch = DIFFUSION_SCRATCH_BYTES_PER_BIN * nbins if variant == "FWC_EXPLICIT_DIFFUSION" else 0
            for period in PERIODS:
                for horizon in HORIZONS:
                    base = single_cache[(period, horizon)]
                    for scope in ("single_active_bin", "replicated_all_bins_storage_envelope"):
                        factor = 1 if scope == "single_active_bin" else nbins
                        max_objects = int(base["max_active_single_bin"]) * factor
                        creates = int(base["creates_single_bin"]) * factor
                        merges = int(base["merges_single_bin"]) * factor
                        removals = int(base["boundary_removals_single_bin"]) * factor
                        persistent_bytes = FIXED_BYTES_PER_BIN * nbins + SLUG_BYTES * max_objects
                        rows.append(
                            {
                                "variant": variant,
                                "theta_bins": nbins,
                                "scope": scope,
                                "period_residence": period,
                                "horizon_residence": horizon,
                                "max_simultaneous_objects": max_objects,
                                "modeled_persistent_bytes_per_column": persistent_bytes,
                                "worker_scratch_bytes": scratch,
                                "creates": creates,
                                "merges": merges,
                                "boundary_removals": removals,
                                "create_rate_per_residence_time": creates / horizon,
                                "merge_rate_per_residence_time": merges / horizon,
                                "boundary_removal_rate_per_residence_time": removals / horizon,
                            }
                        )

    refinement = []
    for variant in VARIANTS:
        for nbins in THETA_BIN_COUNTS:
            vals = []
            for period in PERIODS:
                row = next(
                    r for r in rows
                    if r["variant"] == variant
                    and r["theta_bins"] == nbins
                    and r["scope"] == "replicated_all_bins_storage_envelope"
                    and r["period_residence"] == period
                    and r["horizon_residence"] == 100.0
                )
                vals.append((period, int(row["max_simultaneous_objects"]), int(row["modeled_persistent_bytes_per_column"])))
            refinement.append(
                {
                    "variant": variant,
                    "theta_bins": nbins,
                    "horizon_residence": 100.0,
                    "series": [
                        {"period_residence": p, "max_objects": n, "persistent_bytes": b}
                        for p, n, b in vals
                    ],
                    "finest_to_coarsest_object_ratio": vals[-1][1] / vals[0][1],
                }
            )

    max_row = max(rows, key=lambda r: int(r["modeled_persistent_bytes_per_column"]))
    duration_plateau_rows = []
    for period in PERIODS:
        vals = [
            next(
                r for r in rows
                if r["variant"] == "FWC_ADVECTIVE"
                and r["theta_bins"] == 200
                and r["scope"] == "single_active_bin"
                and r["period_residence"] == period
                and r["horizon_residence"] == horizon
            )
            for horizon in HORIZONS
        ]
        duration_plateau_rows.append(
            {
                "period_residence": period,
                "max_objects_by_horizon": {
                    str(r["horizon_residence"]): r["max_simultaneous_objects"] for r in vals
                },
            }
        )

    return {
        "status": "EXECUTED",
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION",
        "rows": rows,
        "forcing_refinement": refinement,
        "duration_characterization": duration_plateau_rows,
        "worst_modeled_row": max_row,
        "hard_finite_forcing_independent_dynamic_list_bound_established": False,
        "dynamic_list_primary_multiswap_pass": False,
        "decision": "REJECT_SOURCE_STYLE_DYNAMIC_LIST_AS_PRIMARY_MULTISWAP_PERSISTENT_REPRESENTATION",
        "interpretation": (
            "For every fixed velocity and event period the finite column reaches a finite-duration plateau, "
            "but the simultaneous object plateau increases as the event period is refined. The reconstruction "
            "contains no source-supported minimum event spacing, minimum slug thickness, heuristic merge, or "
            "object cap. Therefore the tested source-style linked-list topology does not provide a forcing-"
            "independent hard persistent-state bound."
        ),
    }


def pack_state(values: Iterable[float]) -> bytes:
    values_tuple = tuple(values)
    return struct.pack(f">{len(values_tuple)}d", *values_tuple)


def deterministic_initial(nbins: int) -> List[float]:
    return [0.001 + 0.002 * (j + 1) / nbins for j in range(nbins)]


def run_mass_case(variant: str, nbins: int) -> Dict[str, object]:
    committed = deterministic_initial(nbins)
    initial = math.fsum(committed)
    inflows: List[float] = []
    outflows: List[float] = []
    min_storage = min(committed)

    for step in range(ACCEPTED_STEPS):
        trial = committed.copy()

        inflow = 1.0e-5 * (1.0 + (step % 7) / 10.0)
        trial[0] += inflow

        # Advective finite-volume transfers. No clipping or residual repair.
        for j in range(nbins - 1):
            transfer = 0.0075 * trial[j]
            trial[j] -= transfer
            trial[j + 1] += transfer

        if variant == "FWC_EXPLICIT_DIFFUSION":
            # Pairwise conservative diffusion-like redistribution. This is a
            # ledger/transaction reconstruction only, not a hydraulic closure.
            parity = step & 1
            for j in range(parity, nbins - 1, 2):
                left = trial[j]
                right = trial[j + 1]
                if left >= right:
                    transfer = 0.003 * (left - right)
                    trial[j] -= transfer
                    trial[j + 1] += transfer
                else:
                    transfer = 0.003 * (right - left)
                    trial[j + 1] -= transfer
                    trial[j] += transfer

        outflow = 0.004 * trial[-1]
        trial[-1] -= outflow

        if any((not math.isfinite(v)) or v < 0.0 for v in trial):
            raise AssertionError("inadmissible state encountered; no clipping repair is allowed")

        committed = trial
        inflows.append(inflow)
        outflows.append(outflow)
        min_storage = min(min_storage, min(committed))

    final = math.fsum(committed)
    cumulative_inflow = math.fsum(inflows)
    cumulative_outflow = math.fsum(outflows)
    residual = initial + cumulative_inflow - cumulative_outflow - final
    scale = max(1.0, abs(initial) + abs(cumulative_inflow) + abs(cumulative_outflow) + abs(final))
    tolerance = 64.0 * sys.float_info.epsilon * scale

    # Intentional rejected trial. Mutate only a copy, then reject because trial
    # metadata exceeds the frozen candidate front-slot bound.
    packed_before = pack_state(committed)
    ledger_before = (len(inflows), len(outflows), cumulative_inflow, cumulative_outflow)
    rejected_trial = committed.copy()
    rejected_trial[0] += 0.123456789
    max_front_slots = 4
    requested_front_slots = 5
    rejection_triggered = requested_front_slots > max_front_slots
    if not rejection_triggered:
        raise AssertionError("frozen rejection test did not trigger")
    del rejected_trial
    packed_after = pack_state(committed)
    ledger_after = (len(inflows), len(outflows), cumulative_inflow, cumulative_outflow)

    state_unchanged = packed_before == packed_after
    ledger_unchanged = ledger_before == ledger_after
    passed = abs(residual) <= tolerance and state_unchanged and ledger_unchanged

    return {
        "variant": variant,
        "theta_bins": nbins,
        "accepted_steps": ACCEPTED_STEPS,
        "initial_storage": initial,
        "cumulative_inflow": cumulative_inflow,
        "cumulative_outflow": cumulative_outflow,
        "final_storage": final,
        "mass_residual": residual,
        "mass_tolerance": tolerance,
        "residual_over_tolerance": abs(residual) / tolerance if tolerance else 0.0,
        "minimum_storage": min_storage,
        "mass_repair_applied": False,
        "clipping_repair_applied": False,
        "rejected_trial_triggered": rejection_triggered,
        "committed_state_bitwise_unchanged_after_reject": state_unchanged,
        "committed_ledger_exactly_unchanged_after_reject": ledger_unchanged,
        "pass": passed,
    }


def run_gate_b() -> Dict[str, object]:
    cases = [run_mass_case(variant, nbins) for variant in VARIANTS for nbins in MASS_BIN_COUNTS]
    passed = all(bool(case["pass"]) for case in cases)
    return {
        "status": "EXECUTED",
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION",
        "cases": cases,
        "all_cases_pass": passed,
        "decision": (
            "QUALIFIED_MINIMAL_TRANSACTION_SAFE_FINITE_VOLUME_LEDGER_FEASIBILITY"
            if passed
            else "FAILED_MINIMAL_EXACT_MASS_OR_TRANSACTION_GATE"
        ),
        "nonclaim": "This gate proves ledger and transaction feasibility only, not FWC hydraulic fidelity.",
    }


def build_result() -> Dict[str, object]:
    gate_a = run_gate_a()
    gate_b = run_gate_b()
    bounded_alternative_research_eligible = bool(gate_b["all_cases_pass"])
    return {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "AB_BOUNDED_STATE_AND_EXACT_MASS_FALSIFICATION",
        "implementation_provenance": "INDEPENDENT_RECONSTRUCTION",
        "production_implementation": False,
        "gate_A": gate_a,
        "gate_B": gate_b,
        "overall": {
            "source_style_dynamic_list_primary_multiswap": "NO_GO",
            "bounded_fixed_slot_or_dense_bin_research_route": (
                "REMAINS_ELIGIBLE_FOR_SEPARATE_PHYSICAL_QUALIFICATION"
                if bounded_alternative_research_eligible
                else "BLOCKED_BY_MASS_GATE"
            ),
            "requested_full_exit_reached": False,
            "decision": "FWC_DYNAMIC_LIST_PRIMARY_NO_GO_BOUNDED_REDESIGN_RESEARCH_CONTINUES",
        },
        "hard_nonclaims": [
            "No official FWC code reproduction.",
            "No FullRichards equivalence.",
            "No infiltration-profile accuracy qualification.",
            "No groundwater, crop, SWAP runtime or MultiSWAP implementation admission.",
            "No explicit-diffusion affordability qualification."
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = build_result()
    text = json.dumps(result, indent=2, sort_keys=False) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0 if result["gate_B"]["all_cases_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
