from __future__ import annotations

from typing import Any, Callable, Mapping

from reference_candidate_gate import assess


class FixtureAdmissionBlocked(ValueError):
    pass


def _require_reference_record_binding(
    candidate: Mapping[str, Any], record: Mapping[str, Any]
) -> None:
    source = record.get("source")
    if not isinstance(source, Mapping):
        raise FixtureAdmissionBlocked("reference record source must be an object")

    identity = candidate["source_identity"]
    if source.get("kind") != "reference_run":
        raise FixtureAdmissionBlocked("reference record must originate from a reference run")
    if source.get("extraction_mode") != "reference_run_checkpoint":
        raise FixtureAdmissionBlocked("reference record must use checkpoint extraction mode")
    if source.get("commit") != identity["source_commit"]:
        raise FixtureAdmissionBlocked("reference record commit does not match admitted source")
    if source.get("reference_snapshot") != identity["snapshot"]:
        raise FixtureAdmissionBlocked("reference record snapshot does not match admitted source")

    artifacts = source.get("source_artifacts")
    if not isinstance(artifacts, Mapping):
        raise FixtureAdmissionBlocked("reference record source artifacts are required")
    if artifacts.get("source_tree_manifest") != identity["source_tree_manifest_sha256"]:
        raise FixtureAdmissionBlocked(
            "reference record source-tree manifest does not match admitted source"
        )


def admit_reference_record(
    candidate: Mapping[str, Any],
    record: Mapping[str, Any],
    *,
    builder: Callable[[Mapping[str, Any]], dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Build an F-MQ03 fixture only after source readiness and binding pass.

    The candidate gate is intentionally evaluated before importing/calling the
    fixture builder. A blocked physical candidate therefore cannot accidentally
    become an admitted fixture merely because a structurally valid record was
    supplied by a test or caller.
    """
    status = assess(candidate)
    if not status["admission_allowed"]:
        missing = ",".join(status["missing"])
        raise FixtureAdmissionBlocked(
            f"reference candidate is not admitted: {status['status']} missing={missing}"
        )

    _require_reference_record_binding(candidate, record)

    if builder is None:
        from event_fixture import build_fixture_from_reference_record

        builder = build_fixture_from_reference_record
    return builder(record)
