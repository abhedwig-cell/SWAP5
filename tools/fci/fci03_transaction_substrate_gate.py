#!/usr/bin/env python3
"""Fail-closed provenance/architecture gate for the F-CI03 substrate.

F-CI03 originally imported byte-identical qualified A23 transaction/worker
sources. Later canonical work units may evolve the transaction source, but only
through an explicitly pinned forward-evolution provenance record. The worker
source and retained A23 regression artifacts remain byte-identical here.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

EXPECTED_GIT_BLOBS = {
    "src/transaction/mod_transaction_reference.f90": "5614ff261c9078def61959944aa57fd04c0d324a",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "2a190d206200ad201c37c9a82d3e32e651d37a37",
    "tests/transaction/test_transaction_reference.f90": "e7959bdce0f217a6600e08dd8e28f284d977f3f2",
    "tests/runtime/test_a23bu_worker_context.f90": "774c2c4b36f479da302eb1574bbc3a9536cf291d",
    "tests/transaction/run_a23bl_gate.sh": "de4d7c23e4c3cee47fb160204a5e332bd42763c6",
}

TX_PATH = "src/transaction/mod_transaction_reference.f90"
FORWARD_PROVENANCE = ROOT / "integration/f-ci/F-CI08_TRANSACTION_CONTEXT_PROVENANCE.json"
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
FORBIDDEN_WHOLESALE_ADAPTER = ROOT / "src/adapter/mod_a23bu_hupsel_worker_component.f90"


def git_blob(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "hash-object", str(path)], text=True
    ).strip()


def admitted_tx_evolution(actual: str) -> tuple[bool, dict]:
    if actual == EXPECTED_GIT_BLOBS[TX_PATH]:
        return True, {"mode": "BYTE_IDENTICAL_A23"}
    if not FORWARD_PROVENANCE.is_file():
        return False, {"mode": "UNPINNED_FORWARD_EVOLUTION"}
    try:
        record = json.loads(FORWARD_PROVENANCE.read_text(encoding="utf-8"))
    except Exception as exc:
        return False, {"mode": "INVALID_FORWARD_PROVENANCE", "error": str(exc)}
    ok = (
        record.get("work_unit") == "F-CI08"
        and record.get("source_path") == TX_PATH
        and record.get("fci03_parent_git_blob") == EXPECTED_GIT_BLOBS[TX_PATH]
        and record.get("fci08_candidate_git_blob") == actual
        and record.get("physics_formula_changed") is False
        and record.get("numerical_policy_changed") is False
        and record.get("persistent_column_state_expanded_with_attempt_context") is False
        and record.get("file_io_added") is False
    )
    return ok, record


def main() -> int:
    checks: dict[str, bool] = {}
    actual_blobs: dict[str, str] = {}
    evolution: dict = {}

    for relative, expected in EXPECTED_GIT_BLOBS.items():
        path = ROOT / relative
        exists = path.is_file()
        checks[f"exists:{relative}"] = exists
        if not exists:
            continue
        actual = git_blob(path)
        actual_blobs[relative] = actual
        if relative == TX_PATH:
            admitted, evolution = admitted_tx_evolution(actual)
            checks[f"qualified_provenance:{relative}"] = admitted
        else:
            checks[f"byte_identical_to_a23:{relative}"] = actual == expected

    checks["a23bu_wholesale_adapter_absent"] = not FORBIDDEN_WHOLESALE_ADAPTER.exists()

    tx = (ROOT / TX_PATH).read_text(encoding="utf-8")
    checks["transaction_has_explicit_checkpoint"] = "allocatable :: checkpoint" in tx
    checks["transaction_commit_is_move_alloc"] = "move_alloc(half_state, committed)" in tx
    checks["transaction_generic_t0_t1"] = "real(real64), intent(in) :: t0, t1" in tx
    checks["transaction_no_file_io"] = not any(token in tx.lower() for token in ("open(", "read(", "write("))

    worker = (ROOT / "src/runtime/mod_a23bu_worker_execution_context.f90").read_text(encoding="utf-8")
    checks["worker_owns_headcalc_scratch"] = "type, public :: a23bu_headcalc_scratch_t" in worker
    checks["worker_scratch_allocatable"] = "real(real64), allocatable :: dfdhl(:)" in worker
    checks["worker_owns_numerical_control"] = "type(a23bu_numerical_control_t) :: control" in worker
    checks["reporting_not_column_state"] = "type(a23bu_reporting_progress_t) :: reporting" in worker

    snapshot = (ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml").read_text(encoding="utf-8")
    checks["b1_10_manifest_pinned"] = B1_10_MANIFEST in snapshot
    for patch in ("SWAP-010", "SWAP-013", "SWAP-012", "SWAP-002"):
        checks[f"b1_10_contains:{patch}"] = f'id: "{patch}"' in snapshot

    failed = sorted(name for name, passed in checks.items() if not passed)
    result = {
        "work_unit": "F-CI03",
        "status": "PASS" if not failed else "FAIL",
        "a23_source_commit": "763f276a96ee1722a465bacd3a710172a5f38107",
        "a23_merge_base": "2d05eeab9d766d51bc7c436ea1e45f9b49940e92",
        "b1_oracle": "B1.10",
        "b1_manifest_sha256": B1_10_MANIFEST,
        "checks": checks,
        "actual_git_blobs": actual_blobs,
        "transaction_source_provenance": evolution,
        "failed": failed,
        "holds": [
            "generic physical sub-day execution not yet qualified",
            "mandatory full-plus-two-half transaction route remains reference-only",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
