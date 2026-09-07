from __future__ import annotations
import json
import re
from pathlib import Path
from typing import Any, Mapping

SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED = {
    "reference_run_id",
    "committed_state_at_t0",
    "short_interval_forcing",
    "numerical_reference_config",
    "expected_endpoint_state",
    "unrounded_internal_mass_accounting",
    "extractor_identity_and_output_hash",
}


class CandidateGateError(ValueError):
    pass


def assess(candidate: Mapping[str, Any]) -> dict[str, Any]:
    if candidate.get("schema_version") != "mq-reference-candidate-v1":
        raise CandidateGateError("unsupported candidate schema")
    source = candidate.get("source_identity", {})
    if source.get("snapshot") != "B1.10":
        raise CandidateGateError("current F-MQ04b candidate must remain B1.10")
    if SHA40.fullmatch(str(source.get("source_commit", ""))) is None:
        raise CandidateGateError("source commit must be exact")
    if SHA64.fullmatch(str(source.get("source_tree_manifest_sha256", ""))) is None:
        raise CandidateGateError("source manifest must be SHA-256")
    required = set(candidate.get("required_for_admission", []))
    if required != REQUIRED:
        raise CandidateGateError("admission requirement set changed")
    missing = set(candidate.get("missing", []))
    admission = candidate.get("admission_allowed")
    if admission is False:
        if not missing:
            raise CandidateGateError("blocked candidate must name missing evidence")
        if candidate.get("status") != "BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING":
            raise CandidateGateError("blocked candidate status mismatch")
    elif admission is True:
        if missing:
            raise CandidateGateError("admitted candidate cannot have missing evidence")
        if candidate.get("status") != "READY_FOR_FIXTURE_BUILD":
            raise CandidateGateError("ready candidate status mismatch")
    else:
        raise CandidateGateError("admission_allowed must be boolean")
    evidence = candidate.get("evidence_inventory")
    if not isinstance(evidence, list) or not evidence:
        raise CandidateGateError("evidence inventory required")
    if any(item.get("provides_event_checkpoint") for item in evidence) and "committed_state_at_t0" in missing:
        raise CandidateGateError("checkpoint evidence/missing declaration inconsistent")
    repo = candidate.get("repository_evidence", {})
    if repo.get("event_checkpoint_artifact_found") is False and "committed_state_at_t0" not in missing:
        raise CandidateGateError("repository says no checkpoint but candidate does not mark it missing")
    return {
        "candidate_id": candidate.get("candidate_id"),
        "status": candidate.get("status"),
        "admission_allowed": admission,
        "missing": sorted(missing),
    }


def load_and_assess(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise CandidateGateError("candidate must be JSON object")
    return assess(data)
