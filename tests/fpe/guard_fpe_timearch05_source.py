#!/usr/bin/env python3
from pathlib import Path

checks = {
    "docs/integration/F-CI13_RECOVERABLE_TRIAL_STATUS.md": [
        "Nonconvergence above `dtmin` restores the current soil-water step",
        "This remains an internal SWAP retry.",
        "RETRYABLE_NUMERICAL",
    ],
    "src/adapter/mod_b1_10_recoverable_reference_model.f90": [
        "if (status%retryable()) then",
        "outcome%internal_retries = worker%diagnostics%internal_retries",
    ],
    "src/transaction/mod_transaction_reference.f90": [
        "result%internal_retries = result%internal_retries + outcome%internal_retries",
        "result%solver_rejections = result%solver_rejections + 1",
        "result%temporal_rejections = result%temporal_rejections + 1",
        "result%retries = result%retries + 1",
        "attempt_dt = attempt_dt * policy%retry_scale",
    ],
    "docs/integration/F-GC41_WHOLE_WINDOW_ACCEPTANCE_RETRY.md": [
        "Any failure here is retryable",
        "fresh smaller window",
        "After all preflights pass, the coordinator crosses a publication point",
    ],
}
for path, patterns in checks.items():
    text=Path(path).read_text()
    for pattern in patterns:
        if pattern not in text:
            raise SystemExit(f"F_PE_TIMEARCH05_SOURCE_GUARD_FAIL {path}: {pattern}")
print("F_PE_TIMEARCH05_SOURCE_GUARD=PASS")
