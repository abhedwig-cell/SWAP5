#!/usr/bin/env python3
"""Validate and reconstruct the F-VZAA02 accepted-step water ledger.

For the D0-A FullRichards fixtures, source and sink are zero.  Internal face
fluxes are therefore reconstructed from accepted layer storage changes and the
accepted top flux.  The reconstruction is diagnostic only and does not expose
or persist Richards worker scratch.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

EPS = sys.float_info.epsilon
EXPECTED_CASES = 6
EXPECTED_REFINEMENTS = 2
EXPECTED_NODES = 4


def numerical_tol(*values: float) -> float:
    """Roundoff/serialization guard, not a physical acceptance tolerance."""
    scale = max([1.0, *(abs(v) for v in values if math.isfinite(v))])
    return 4096.0 * EPS * scale


def parse(path: Path):
    steps = {}
    nodes = defaultdict(dict)
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        parts = raw.split()
        if not parts:
            continue
        if parts[0] == "VZAA02_STEP":
            if len(parts) != 10:
                raise ValueError(f"line {lineno}: malformed VZAA02_STEP")
            key = tuple(map(int, parts[1:4]))
            if key in steps:
                raise ValueError(f"line {lineno}: duplicate step {key}")
            vals = list(map(float, parts[4:]))
            if not all(math.isfinite(v) for v in vals):
                raise ValueError(f"line {lineno}: non-finite step value")
            steps[key] = {
                "t0": vals[0],
                "t1": vals[1],
                "dt": vals[2],
                "q_top": vals[3],
                "q_bottom": vals[4],
                "reported_residual": vals[5],
            }
        elif parts[0] == "VZAA02_NODE":
            if len(parts) != 10:
                raise ValueError(f"line {lineno}: malformed VZAA02_NODE")
            case_id, refinement, step, node = map(int, parts[1:5])
            key = (case_id, refinement, step)
            if node in nodes[key]:
                raise ValueError(f"line {lineno}: duplicate node {node} for {key}")
            vals = list(map(float, parts[5:]))
            if not all(math.isfinite(v) for v in vals):
                raise ValueError(f"line {lineno}: non-finite node value")
            nodes[key][node] = {
                "dz": vals[0],
                "h_before": vals[1],
                "theta_before": vals[2],
                "h_after": vals[3],
                "theta_after": vals[4],
            }
    return steps, nodes


def analyze(steps, nodes):
    expected_series = {(case_id, refinement) for case_id in range(1, EXPECTED_CASES + 1)
                       for refinement in range(1, EXPECTED_REFINEMENTS + 1)}
    actual_series = {(k[0], k[1]) for k in steps}
    if actual_series != expected_series:
        raise ValueError(f"series mismatch: got {sorted(actual_series)}, expected {sorted(expected_series)}")
    if set(nodes) != set(steps):
        raise ValueError("STEP/NODE key sets differ")

    max_reported_residual = 0.0
    max_residual_recompute_mismatch = 0.0
    max_bottom_identity_mismatch = 0.0
    max_time_identity_mismatch = 0.0
    max_state_chain_mismatch = 0.0
    accepted_steps = 0
    reconstructed_faces = 0
    series_summary = []

    for series in sorted(expected_series):
        series_keys = sorted((k for k in steps if k[:2] == series), key=lambda k: k[2])
        indices = [k[2] for k in series_keys]
        if indices != list(range(1, len(indices) + 1)):
            raise ValueError(f"non-contiguous steps for series {series}: {indices}")
        previous_t1 = None
        previous_after = None
        series_max_residual = 0.0

        for key in series_keys:
            record = steps[key]
            by_node = nodes[key]
            if set(by_node) != set(range(1, EXPECTED_NODES + 1)):
                raise ValueError(f"node set mismatch for {key}: {sorted(by_node)}")
            dt = record["dt"]
            if not dt > 0.0:
                raise ValueError(f"non-positive dt for {key}")

            time_identity = abs((record["t1"] - record["t0"]) - dt)
            time_tol = numerical_tol(record["t0"], record["t1"], dt)
            if time_identity > time_tol:
                raise ValueError(f"time identity mismatch for {key}: {time_identity} > {time_tol}")
            max_time_identity_mismatch = max(max_time_identity_mismatch, time_identity)
            if previous_t1 is not None:
                continuity = abs(record["t0"] - previous_t1)
                if continuity > numerical_tol(record["t0"], previous_t1):
                    raise ValueError(f"time discontinuity for {key}: {continuity}")
            previous_t1 = record["t1"]

            if previous_after is not None:
                for node in range(1, EXPECTED_NODES + 1):
                    current = by_node[node]
                    prior = previous_after[node]
                    mismatch = max(abs(current["h_before"] - prior["h_after"]),
                                   abs(current["theta_before"] - prior["theta_after"]))
                    tol = numerical_tol(current["h_before"], prior["h_after"],
                                        current["theta_before"], prior["theta_after"])
                    if mismatch > tol:
                        raise ValueError(f"committed-state chain mismatch for {key}, node {node}: {mismatch} > {tol}")
                    max_state_chain_mismatch = max(max_state_chain_mismatch, mismatch)

            delta_storage = []
            for node in range(1, EXPECTED_NODES + 1):
                item = by_node[node]
                if not item["dz"] > 0.0:
                    raise ValueError(f"non-positive dz for {key}, node {node}")
                delta_storage.append(item["dz"] * (item["theta_after"] - item["theta_before"]))

            q_face = record["q_top"]
            faces = [q_face]
            for d_storage in delta_storage:
                q_face = q_face + d_storage / dt
                faces.append(q_face)
            reconstructed_faces += len(faces)

            recomputed_residual = sum(delta_storage) + dt * (record["q_top"] - record["q_bottom"])
            residual_mismatch = abs(recomputed_residual - record["reported_residual"])
            residual_tol = numerical_tol(recomputed_residual, record["reported_residual"],
                                         sum(abs(v) for v in delta_storage),
                                         dt * record["q_top"], dt * record["q_bottom"])
            if residual_mismatch > residual_tol:
                raise ValueError(f"residual reconstruction mismatch for {key}: {residual_mismatch} > {residual_tol}")

            bottom_identity = abs((faces[-1] - record["q_bottom"]) - record["reported_residual"] / dt)
            bottom_tol = numerical_tol(faces[-1], record["q_bottom"], record["reported_residual"] / dt)
            if bottom_identity > bottom_tol:
                raise ValueError(f"bottom ledger identity mismatch for {key}: {bottom_identity} > {bottom_tol}")

            max_reported_residual = max(max_reported_residual, abs(record["reported_residual"]))
            series_max_residual = max(series_max_residual, abs(record["reported_residual"]))
            max_residual_recompute_mismatch = max(max_residual_recompute_mismatch, residual_mismatch)
            max_bottom_identity_mismatch = max(max_bottom_identity_mismatch, bottom_identity)
            accepted_steps += 1
            previous_after = by_node

        series_summary.append({
            "case_id": series[0],
            "refinement": series[1],
            "accepted_steps": len(series_keys),
            "max_abs_reported_residual": series_max_residual,
        })

    return {
        "workunit": "F-VZAA02",
        "scope": "D0-A accepted-step FullRichards ledger reconstruction",
        "reference_semantics": "internal faces reconstructed from accepted storage changes and accepted top flux; source/sink zero in fixture",
        "physical_mass_tolerance_defined_here": False,
        "structural_pass": True,
        "series_count": len(expected_series),
        "accepted_steps": accepted_steps,
        "reconstructed_face_samples": reconstructed_faces,
        "max_abs_reported_step_residual": max_reported_residual,
        "max_abs_residual_recompute_mismatch": max_residual_recompute_mismatch,
        "max_abs_bottom_ledger_identity_mismatch": max_bottom_identity_mismatch,
        "max_abs_time_identity_mismatch": max_time_identity_mismatch,
        "max_abs_committed_state_chain_mismatch": max_state_chain_mismatch,
        "series": series_summary,
        "architecture": {
            "public_solver_contract_changed": False,
            "persistent_column_state_added": False,
            "headcalc_internal_scratch_exposed": False,
            "qualified_lmfp04_driver_modified": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trajectory", type=Path)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()

    steps, nodes = parse(args.trajectory)
    evidence = analyze(steps, nodes)
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    print("F-VZAA02_TRAJECTORY_LEDGER_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
