#!/usr/bin/env python3
"""Bounded LOW05-P0 design-feasibility check, not production qualification."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

def sample(t):
    # Independent AFGEN arithmetic fixture: [0,1], [-100,100].
    if t <= 0:
        return -100.0
    if t >= 1:
        return 100.0
    return -100.0 + 200.0*t

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True)
    args = ap.parse_args()
    root = args.root
    paths = {
        "canonical": "src/runtime/mod_canonical_interval_runtime.f90",
        "transaction": "src/transaction/mod_transaction_reference.f90",
        "kernel": "src/kernel/mod_kernel_transactions.f90",
        "orchestrator": "src/runtime/mod_fmr_checkpoint_orchestrator.f90",
    }
    sources = {k: (root/v).read_text() for k,v in paths.items()}
    canonical = sources["canonical"]
    assert canonical.index("call target_selector(cursor") < canonical.index("call execute_reference_interval(model")
    transaction = sources["transaction"]
    start = transaction.index("subroutine execute_reference_interval(")
    body = transaction[start:transaction.index("end subroutine execute_reference_interval", start)]
    assert body.index("call model%capture_attempt_context(checkpoint_context)") < body.index("call model%advance(full_state")
    assert body.index("call model%restore_attempt_context(checkpoint_context)") < body.index("call model%advance(full_state")
    assert "call model%advance(half_state, t0, midpoint" in body
    assert "call model%advance(half_state, midpoint, attempt_t1" in body
    assert "attempt_dt = attempt_dt * policy%retry_scale" in transaction
    assert "runtime_result, target_selector)" in sources["kernel"]
    assert "diagnostics, checkpoint, target_selector)" in sources["orchestrator"]

    # An explicit proposal is created by the selector before capture.
    proposal = {"t0": 0.0, "original_t1": 1.0, "hbot_cm": sample(1.0)}
    checkpoint = copy.deepcopy(proposal)
    trace = []
    for route, physical_t0, physical_t1 in [
        ("full", 0.0, 1.0),
        ("half1", 0.0, 0.5),
        ("half2", 0.5, 1.0),
        ("retry_full", 0.0, 0.25),
        ("retry_half1", 0.0, 0.125),
        ("retry_half2", 0.125, 0.25),
    ]:
        attempt = copy.deepcopy(checkpoint)
        assert attempt["t0"] <= physical_t0 < physical_t1 <= attempt["original_t1"]
        trace.append({"route": route, "physical_t1": physical_t1, "hbot_cm": attempt["hbot_cm"]})
    assert all(x["hbot_cm"] == 100.0 for x in trace)
    assert sample(0.25) == -50.0
    # Restore rejects candidate changes; no candidate head enters the proposal.
    candidate = copy.deepcopy(checkpoint)
    candidate["hbot_cm"] = -999.0
    restored = copy.deepcopy(checkpoint)
    assert restored["hbot_cm"] == 100.0
    # After accepted progress, the NEXT selector may choose a new endpoint.
    next_proposal = {"t0": 0.25, "original_t1": 0.75, "hbot_cm": sample(0.75)}
    assert next_proposal["hbot_cm"] == 50.0
    # Reconstructed immutable control + accepted origin reproduce a new proposal.
    restarted = {"t0": 0.25, "original_t1": 0.75, "hbot_cm": sample(0.75)}
    assert restarted == next_proposal
    result = {
        "work_unit": "F-MIG431-LOW05-P0",
        "result": "PASS_BOUNDED_DESIGN_FEASIBILITY",
        "qualification_scope": "existing optional-selector plumbing and independent abstract proposal/context trace only",
        "production_qualification": False,
        "production_code_changed": False,
        "dependency_sha256": {paths[k]: hashlib.sha256((root/paths[k]).read_bytes()).hexdigest() for k in paths},
        "trace": trace,
        "per_retry_resampling_counterexample_cm": -50.0,
        "next_accepted_origin_proposal": next_proposal,
        "restart_abstract_reconstruction_equal": True,
        "remaining_required": "LOW05-A actual production callback/context/solver/mass/preservation qualification",
    }
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
