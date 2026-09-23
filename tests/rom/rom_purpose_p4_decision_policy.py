#!/usr/bin/env python3
"""Fail-closed reporting rules; no solver, metrics or numerical thresholds."""
from __future__ import annotations


def frontier(records: list[tuple[str, bool, bool]]) -> dict:
    """Separate first qualified comparator reach from an established minimum.

    Records are supplied in the frozen ladder order as (member, qualified,
    reached). A missing numerical qualification is unknown fidelity, not an
    observed failure of state information.
    """
    if not records or len({r[0] for r in records}) != len(records):
        raise ValueError("A nonempty, unique frozen ladder is required")
    for member, qualified, reached in records:
        if not isinstance(qualified, bool) or not isinstance(reached, bool):
            raise ValueError("Qualification and reach must be boolean")
        if reached and not qualified:
            raise ValueError(f"Unqualified comparator reach: {member}")
    first = next((i for i, (_, _, reached) in enumerate(records) if reached), None)
    missing = [m for m, qualified, _ in records if not qualified]
    lower_missing = [] if first is None else [m for m, q, _ in records[:first] if not q]
    first_member = None if first is None else records[first][0]
    minimum = first_member if first is not None and not lower_missing else None
    if minimum is not None:
        status = "MINIMUM_TESTED_REPRESENTATION_IDENTIFIED"
    elif first is not None:
        status = "COMPARATOR_REACHED_MINIMUM_UNRESOLVED_NUMERICAL_GAPS"
    elif missing:
        status = "FRONTIER_UNRESOLVED_NUMERICAL_GAPS"
    else:
        status = "REPRESENTATION_FRONTIER_NOT_REACHED"
    return {"first_comparator_reaching_member": first_member,
            "first_comparator_reaching_state_count": None if first_member is None else int(first_member[1:]),
            "minimum_tested_member": minimum,
            "minimum_tested_state_count": None if minimum is None else int(minimum[1:]),
            "unqualified_members": missing,
            "unqualified_lower_members": lower_missing,
            "frontier_status": status}


def attribution(layer_qualified: bool, layer_reaches: bool,
                richards_qualified: bool, richards_reaches: bool) -> str:
    """A clean closure comparison requires both methods to be qualified."""
    if any(not isinstance(x, bool) for x in
           (layer_qualified, layer_reaches, richards_qualified, richards_reaches)):
        raise ValueError("Qualification and reach must be boolean")
    if layer_reaches and not layer_qualified:
        raise ValueError("Unqualified Layer-ROM cannot reach the comparator")
    if richards_reaches and not richards_qualified:
        raise ValueError("Unqualified Richards cannot reach the comparator")
    if not layer_qualified:
        return "LAYER_ROM_NUMERICALLY_UNAVAILABLE"
    if not richards_qualified:
        return "MATCHED_RICHARDS_UNAVAILABLE"
    if richards_reaches and not layer_reaches:
        return "CLOSURE_DEFICIT_SUPPORTED_AT_RUNG"
    if richards_reaches and layer_reaches:
        return "BOTH_REACH_COMPARATOR"
    if not richards_reaches and not layer_reaches:
        return "REPRESENTATION_OR_RESOLUTION_LIMITING"
    return "LAYER_REACHES_WITHOUT_MATCHED_RICHARDS_REACH"
