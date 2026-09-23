#!/usr/bin/env python3
"""Exhaustive small truth tables with synthetic labels, not model response."""
from __future__ import annotations
import itertools
import json
from rom_purpose_p4_decision_policy import attribution, frontier


def check() -> dict:
    states = ((False, False), (True, False), (True, True))
    frontier_cases = 0
    for prefix in ("S", "G"):
        names = [f"{prefix}{n}" for n in (8, 12, 16)]
        for state in itertools.product(states, repeat=3):
            records = [(m, q, r) for m, (q, r) in zip(names, state)]
            result = frontier(records)
            first = next((i for i, (_, reached) in enumerate(state) if reached), None)
            expected_first = None if first is None else names[first]
            expected_minimum = (expected_first if first is not None
                                and all(q for q, _ in state[:first]) else None)
            assert result["first_comparator_reaching_member"] == expected_first
            assert result["minimum_tested_member"] == expected_minimum
            assert result["unqualified_members"] == [m for m, (q, _) in zip(names, state) if not q]
            frontier_cases += 1
    attribution_cases = 0
    rejected = 0
    for lq, lr, rq, rr in itertools.product((False, True), repeat=4):
        invalid = (lr and not lq) or (rr and not rq)
        try:
            label = attribution(lq, lr, rq, rr)
        except ValueError:
            assert invalid
            rejected += 1
        else:
            assert not invalid
            assert (label == "CLOSURE_DEFICIT_SUPPORTED_AT_RUNG") == (lq and not lr and rq and rr)
            if not lq:
                assert label == "LAYER_ROM_NUMERICALLY_UNAVAILABLE"
            elif not rq:
                assert label == "MATCHED_RICHARDS_UNAVAILABLE"
        attribution_cases += 1
    return {"status": "PASS", "frontier_truth_table_cases": frontier_cases,
            "attribution_truth_table_cases": attribution_cases,
            "inconsistent_qualification_rejections": rejected,
            "model_response_generated": False, "numerical_threshold_changed": False}


if __name__ == "__main__":
    print(json.dumps(check(), sort_keys=True))
