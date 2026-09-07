from __future__ import annotations

from dataclasses import asdict, dataclass
from hashlib import sha256
import json
import re
from pathlib import Path
from typing import Any, Mapping

_SHA40 = re.compile(r"^[0-9a-f]{40}$")
_SHA64 = re.compile(r"^[0-9a-f]{64}$")
QUALIFIED_ORACLE_STATUS = "QUALIFIED_NUMERICAL_BEHAVIOURAL"


class ReferenceSourceError(ValueError):
    pass


@dataclass(frozen=True)
class ReferenceSourceIdentity:
    repository: str
    snapshot: str
    integration_commit: str
    snapshot_path: str
    snapshot_git_blob_sha1: str
    source_manifest_sha256: str
    oracle_status: str
    pin_path: str
    pin_git_blob_sha1: str | None = None

    def canonical_payload(self) -> dict[str, Any]:
        return asdict(self)

    def canonical_hash(self) -> str:
        encoded = json.dumps(
            self.canonical_payload(), sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        return sha256(encoded).hexdigest()


def _require_sha(value: object, bits: int, name: str) -> str:
    text = str(value)
    matcher = _SHA40 if bits == 160 else _SHA64
    if matcher.fullmatch(text) is None:
        raise ReferenceSourceError(f"{name} must be a lowercase {bits}-bit hex digest")
    return text


def adapt_vq_reference_pin(
    pin: Mapping[str, Any],
    *,
    repository: str,
    pin_path: str,
    pin_git_blob_sha1: str | None = None,
    expected_snapshot: str | None = None,
) -> ReferenceSourceIdentity:
    """Translate a qualified VQ pin into the narrower F-MQ source identity.

    This deliberately does not reimplement the VQ admission gate. F-MQ consumes
    the VQ result fail-closed and records exactly which VQ identity it consumed.
    """
    if pin.get("schema_version") != 1:
        raise ReferenceSourceError("unsupported VQ reference-pin schema")
    if pin.get("workstream") != "VQ":
        raise ReferenceSourceError("reference pin must originate from VQ")

    snapshot = str(pin.get("snapshot", ""))
    if not snapshot:
        raise ReferenceSourceError("snapshot is required")
    if expected_snapshot is not None and snapshot != expected_snapshot:
        raise ReferenceSourceError(
            f"snapshot mismatch: expected {expected_snapshot}, got {snapshot}"
        )

    integration_commit = _require_sha(pin.get("integration_commit"), 160, "integration_commit")
    snapshot_path = str(pin.get("snapshot_path", ""))
    expected_suffix = f"/{snapshot}.yml"
    if not snapshot_path.endswith(expected_suffix):
        raise ReferenceSourceError("snapshot_path is not bound to the declared snapshot")

    snapshot_blob = _require_sha(
        pin.get("snapshot_git_blob_sha1"), 160, "snapshot_git_blob_sha1"
    )
    source_manifest = _require_sha(
        pin.get("source_tree", {}).get("member_manifest_sha256"),
        256,
        "source_tree.member_manifest_sha256",
    )
    oracle_status = str(
        pin.get("qualification", {}).get(
            "b1_10_oracle_status",
            pin.get("qualification", {}).get("oracle_status", ""),
        )
    )
    if oracle_status != QUALIFIED_ORACLE_STATUS:
        raise ReferenceSourceError(
            f"oracle is not qualified: {oracle_status or '<missing>'}"
        )

    for key, value in pin.get("qualification", {}).items():
        if isinstance(value, bool) and not value:
            raise ReferenceSourceError(f"VQ qualification flag {key} is false")
        if isinstance(value, str) and key.endswith("_gate") and value != "PASS":
            raise ReferenceSourceError(f"VQ qualification gate {key} is not PASS")

    if not repository or "/" not in repository:
        raise ReferenceSourceError("repository must be owner/name")
    if not pin_path.endswith(".json"):
        raise ReferenceSourceError("pin_path must identify a JSON reference pin")
    if pin_git_blob_sha1 is not None:
        _require_sha(pin_git_blob_sha1, 160, "pin_git_blob_sha1")

    return ReferenceSourceIdentity(
        repository=repository,
        snapshot=snapshot,
        integration_commit=integration_commit,
        snapshot_path=snapshot_path,
        snapshot_git_blob_sha1=snapshot_blob,
        source_manifest_sha256=source_manifest,
        oracle_status=oracle_status,
        pin_path=pin_path,
        pin_git_blob_sha1=pin_git_blob_sha1,
    )


def load_and_adapt_vq_reference_pin(
    path: Path,
    *,
    repository: str,
    expected_snapshot: str | None = None,
    pin_git_blob_sha1: str | None = None,
) -> ReferenceSourceIdentity:
    pin = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(pin, dict):
        raise ReferenceSourceError("reference pin must be a JSON object")
    return adapt_vq_reference_pin(
        pin,
        repository=repository,
        pin_path=path.as_posix(),
        pin_git_blob_sha1=pin_git_blob_sha1,
        expected_snapshot=expected_snapshot,
    )


def fixture_reference_identity(identity: ReferenceSourceIdentity) -> dict[str, Any]:
    """Return the exact provenance fragment to embed in an F-MQ fixture."""
    return {
        "repository": identity.repository,
        "source_commit": identity.integration_commit,
        "qualified_snapshot": identity.snapshot,
        "snapshot_path": identity.snapshot_path,
        "snapshot_git_blob_sha1": identity.snapshot_git_blob_sha1,
        "source_tree_manifest_sha256": identity.source_manifest_sha256,
        "vq_reference_pin": identity.pin_path,
        "vq_reference_pin_git_blob_sha1": identity.pin_git_blob_sha1,
        "vq_oracle_status": identity.oracle_status,
        "source_identity_sha256": identity.canonical_hash(),
    }
