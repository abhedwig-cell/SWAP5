#!/usr/bin/env python3
"""Fail-closed admission gate for the SWAP5/B2 reference adapter target.

Verification infrastructure only. This module does not execute SWAP5 physics.
It determines whether an integrated, exactly pinned B2 reference-mode entrypoint
exists with the minimum contracts required before VQ may perform B1 -> B2 runs.

VQ-1d1 binds the candidate and stored gate evidence to the current corrected-
reference manifest. VQ-1d2 requires a machine-readable reference-seam contract
for any candidate that claims to be READY. VQ-1d3 binds that seam to an
executable canonical result contract before numerical comparison is admitted.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import yaml

try:
    from tools.vq.b2_seam_contract import assess_contract
except ModuleNotFoundError:  # direct script execution from tools/vq
    from b2_seam_contract import assess_contract

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATE = REPO_ROOT / "tools" / "vq" / "cases" / "b2-reference-candidate.json"
DEFAULT_EVIDENCE = REPO_ROOT / "tools" / "vq" / "cases" / "b2-reference-gate-2026-09-06.json"
B1_MANIFEST = Path("reference/swap-4.3.1/b1-manifest.yml")
QUALIFIED_B1_STATUS = "QUALIFIED_NUMERICAL_BEHAVIOURAL"

REQUIRED_CAPABILITIES = (
    "callable_reference_entrypoint",
    "generic_interval_t0_t1",
    "committed_state_input",
    "forcing_input",
    "numerical_config_separate",
    "canonical_result_output",
    "unrounded_mass_accounting",
    "transaction_diagnostics",
)

READY = "READY_FOR_VQ_B1_TO_B2"
BLOCKED = "BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT"


def _valid_sha(value: object, length: int = 40) -> bool:
    return isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None


def _declared_path(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def load_current_b1(repo_root: Path) -> dict[str, str]:
    manifest_path = repo_root / B1_MANIFEST
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    b1 = data["b1"]
    source_tree = b1["source_tree"]
    current = {
        "snapshot": str(b1["snapshot"]),
        "qualification": str(b1["oracle_status"]),
        "reconstructed_manifest_sha256": str(source_tree["member_manifest_sha256"]),
    }
    if not _valid_sha(current["reconstructed_manifest_sha256"], length=64):
        raise ValueError("current B1 source manifest SHA-256 is invalid")
    return current


def assess_candidate(repo_root: Path, candidate_path: Path = DEFAULT_CANDIDATE) -> dict[str, Any]:
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    b1 = candidate.get("b1_oracle", {})
    b2 = candidate.get("b2", {})
    integration = b2.get("integration", {})
    capabilities = b2.get("capabilities", {})

    result: dict[str, Any] = {
        "candidate": str(candidate_path),
        "observation_baseline": candidate.get("observation_baseline"),
        "b1_snapshot": b1.get("snapshot"),
        "b1_qualification": b1.get("qualification"),
        "b1_reconstructed_manifest_sha256": b1.get("reconstructed_manifest_sha256"),
        "b2_commit": b2.get("commit"),
        "candidate_status": b2.get("status"),
        "admissible_adapter_target": False,
        "checks": {},
        "missing_capabilities": [],
    }
    checks = result["checks"]

    try:
        current_b1 = load_current_b1(repo_root)
    except (FileNotFoundError, KeyError, TypeError, ValueError, yaml.YAMLError) as exc:
        result["current_b1"] = None
        checks["b1_manifest_loaded"] = False
        result["failure"] = "current_b1_manifest_unavailable"
        result["detail"] = str(exc)
        return result

    result["current_b1"] = current_b1
    checks["b1_manifest_loaded"] = True
    checks["b1_oracle_qualified"] = current_b1["qualification"] == QUALIFIED_B1_STATUS
    checks["b1_snapshot_matches_manifest"] = b1.get("snapshot") == current_b1["snapshot"]
    checks["b1_qualification_matches_manifest"] = (
        b1.get("qualification") == current_b1["qualification"]
    )
    checks["b1_source_manifest_matches_manifest"] = (
        b1.get("reconstructed_manifest_sha256")
        == current_b1["reconstructed_manifest_sha256"]
    )

    checks["observation_baseline_exact"] = _valid_sha(candidate.get("observation_baseline"))
    checks["exact_b2_commit"] = _valid_sha(b2.get("commit"))
    checks["observation_matches_b2_commit"] = (
        checks["observation_baseline_exact"]
        and checks["exact_b2_commit"]
        and candidate.get("observation_baseline") == b2.get("commit")
    )
    checks["ready_status"] = b2.get("status") == READY

    entrypoint = integration.get("entrypoint_path")
    result_contract = integration.get("result_contract_path")
    seam_contract = integration.get("seam_contract_path")
    checks["entrypoint_declared"] = _declared_path(entrypoint)
    checks["result_contract_declared"] = _declared_path(result_contract)
    checks["seam_contract_declared"] = _declared_path(seam_contract)
    checks["reference_policy_explicit"] = integration.get("reference_policy") == "reference"

    checks["entrypoint_exists"] = bool(
        checks["entrypoint_declared"] and (repo_root / str(entrypoint)).is_file()
    )
    checks["result_contract_exists"] = bool(
        checks["result_contract_declared"] and (repo_root / str(result_contract)).is_file()
    )
    checks["seam_contract_exists"] = bool(
        checks["seam_contract_declared"] and (repo_root / str(seam_contract)).is_file()
    )

    seam_result: dict[str, Any] | None = None
    if checks["seam_contract_exists"]:
        seam_result = assess_contract(repo_root, repo_root / str(seam_contract))
    result["seam_contract"] = seam_result
    checks["seam_contract_valid"] = bool(
        seam_result is not None and seam_result.get("admissible_reference_seam") is True
    )
    checks["seam_contract_matches_candidate"] = bool(
        seam_result is not None
        and seam_result.get("implementation_commit") == b2.get("commit")
        and seam_result.get("entrypoint_path") == entrypoint
        and seam_result.get("result_contract_path") == result_contract
        and seam_result.get("reference_policy") == integration.get("reference_policy")
    )

    missing = [name for name in REQUIRED_CAPABILITIES if capabilities.get(name) is not True]
    result["missing_capabilities"] = missing
    checks["required_capabilities"] = not missing

    result["admissible_adapter_target"] = all(checks.values())
    if not result["admissible_adapter_target"]:
        b1_consistency_checks = (
            "b1_manifest_loaded",
            "b1_oracle_qualified",
            "b1_snapshot_matches_manifest",
            "b1_qualification_matches_manifest",
            "b1_source_manifest_matches_manifest",
        )
        if not all(checks.get(name, False) for name in b1_consistency_checks):
            result["failure"] = "b1_oracle_not_current_or_not_qualified"
        elif not checks["observation_baseline_exact"] or not checks["exact_b2_commit"]:
            result["failure"] = "invalid_or_missing_b2_commit"
        elif not checks["observation_matches_b2_commit"]:
            result["failure"] = "b2_observation_commit_mismatch"
        elif not checks["ready_status"]:
            result["failure"] = "b2_reference_entrypoint_not_ready"
        elif not checks["entrypoint_exists"]:
            result["failure"] = "integrated_entrypoint_missing"
        elif not checks["result_contract_exists"]:
            result["failure"] = "result_contract_missing"
        elif not checks["seam_contract_exists"]:
            result["failure"] = "reference_seam_contract_missing"
        elif not checks["seam_contract_valid"]:
            result["failure"] = "reference_seam_contract_invalid"
        elif not checks["seam_contract_matches_candidate"]:
            result["failure"] = "reference_seam_contract_candidate_mismatch"
        elif missing:
            result["failure"] = "required_b2_capability_missing"
        else:
            result["failure"] = "b2_adapter_admission_failed"
    return result


def evidence_projection(candidate: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    """Return the fail-closed fields that must stay synchronized in stored evidence."""
    return {
        "schema_version": 1,
        "workstream": "VQ",
        "slice": "VQ-1d3",
        "observation_baseline": candidate.get("observation_baseline"),
        "candidate_status": result.get("candidate_status"),
        "b1_snapshot": result.get("b1_snapshot"),
        "b1_qualification": result.get("b1_qualification"),
        "b1_reconstructed_manifest_sha256": result.get("b1_reconstructed_manifest_sha256"),
        "b2_commit": result.get("b2_commit"),
        "admissible_adapter_target": result.get("admissible_adapter_target"),
        "failure": result.get("failure"),
        "checks": result.get("checks"),
        "missing_capabilities": result.get("missing_capabilities"),
    }


def check_stored_evidence(
    candidate_path: Path,
    result: dict[str, Any],
    evidence_path: Path,
) -> dict[str, Any]:
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    stored = json.loads(evidence_path.read_text(encoding="utf-8"))
    expected = evidence_projection(candidate, result)
    mismatches = {
        key: {"expected": expected.get(key), "stored": stored.get(key)}
        for key in expected
        if stored.get(key) != expected.get(key)
    }
    return {
        "consistent": not mismatches,
        "mismatches": mismatches,
        "expected_projection": expected,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Assess whether an integrated B2 reference adapter target is admissible."
    )
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument(
        "--allow-expected-blocked",
        action="store_true",
        help=(
            "Return success for the declared BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT state "
            "only when the candidate is internally consistent and, when supplied, "
            "stored evidence matches the current gate result."
        ),
    )
    args = parser.parse_args()

    result = assess_candidate(args.repo_root, args.candidate)
    evidence_check: dict[str, Any] | None = None
    if args.evidence is not None:
        evidence_check = check_stored_evidence(args.candidate, result, args.evidence)
        result["stored_evidence"] = {
            "path": str(args.evidence),
            **evidence_check,
        }

    print(json.dumps(result, indent=2, sort_keys=True))

    if evidence_check is not None and not evidence_check["consistent"]:
        return 3
    if result["admissible_adapter_target"]:
        return 0
    if (
        args.allow_expected_blocked
        and result.get("candidate_status") == BLOCKED
        and result.get("failure") == "b2_reference_entrypoint_not_ready"
    ):
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
