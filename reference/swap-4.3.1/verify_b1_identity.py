#!/usr/bin/env python3
"""Fail-closed identity gate for the current corrected SWAP 4.3.1 reference.

This gate does not compile or run Fortran. It verifies that the current B1
snapshot is internally and cryptographically anchored to:

* the canonical B0 source archive/member manifest identity;
* the exact stored patch bytes;
* the canonical B0 target-member hashes;
* the ordered patch list in b1-manifest.yml;
* the recorded qualification/helper artifacts.

It is intended to catch exactly the provenance failures found in B1.2-B1.5.
The gate deliberately does not claim to recompute every corrected-target hash
because the byte-exact expanded B0 source tree is not stored in Git.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "reference" / "swap-4.3.1"
MANIFEST = REFERENCE / "b1-manifest.yml"
B0_MEMBER_MANIFEST = REFERENCE / "b0" / "file-manifest.sha256"
HEX64 = re.compile(r"^[0-9a-f]{64}$")


class GateFailure(RuntimeError):
    pass


def fail(message: str) -> None:
    raise GateFailure(message)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        fail(f"required YAML file missing: {path.relative_to(ROOT)}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        fail(f"YAML root is not a mapping: {path.relative_to(ROOT)}")
    return data


def parse_b0_member_manifest(path: Path) -> dict[str, tuple[str, int]]:
    members: dict[str, tuple[str, int]] = {}
    if not path.is_file():
        fail(f"canonical B0 member manifest missing: {path.relative_to(ROOT)}")
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(maxsplit=2)
        if len(parts) != 3:
            fail(f"invalid B0 member manifest line {lineno}: {raw!r}")
        digest, size_text, member = parts
        if not HEX64.fullmatch(digest):
            fail(f"invalid B0 member SHA on line {lineno}: {digest}")
        try:
            size = int(size_text)
        except ValueError as exc:
            raise GateFailure(f"invalid B0 member size on line {lineno}: {size_text}") from exc
        if member in members:
            fail(f"duplicate B0 member entry: {member}")
        members[member] = (digest, size)
    if not members:
        fail("canonical B0 member manifest is empty")
    return members


def require_hex64(label: str, value: Any) -> str:
    if not isinstance(value, str) or not HEX64.fullmatch(value):
        fail(f"{label} is not a lowercase SHA-256: {value!r}")
    return value


def compare_patch_lists(manifest_patches: list[dict[str, Any]], snapshot_patches: list[dict[str, Any]]) -> None:
    manifest_ids = [p.get("id") for p in manifest_patches]
    snapshot_ids = [p.get("id") for p in snapshot_patches]
    if manifest_ids != snapshot_ids:
        fail(f"manifest/snapshot patch order mismatch: {manifest_ids} != {snapshot_ids}")
    if len(set(snapshot_ids)) != len(snapshot_ids):
        fail(f"duplicate patch IDs in snapshot: {snapshot_ids}")
    for m, s in zip(manifest_patches, snapshot_patches):
        for key in ("id", "patch_path", "patch_sha256"):
            if m.get(key) != s.get(key):
                fail(f"manifest/snapshot mismatch for {m.get('id')} field {key}: {m.get(key)!r} != {s.get(key)!r}")


def helper_hashes(path: Path) -> tuple[str | None, str | None]:
    """Extract B0/B1 SHA constants from a byte-verifier when present."""
    text = path.read_text(encoding="utf-8")
    b0 = None
    b1 = None
    for name, digest in re.findall(r"\b(B0_SHA256|B1_SHA256)\s*=\s*[\"']([0-9a-f]{64})[\"']", text):
        if name == "B0_SHA256":
            b0 = digest
        elif name == "B1_SHA256":
            b1 = digest
    return b0, b1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expect-snapshot", default=None, help="fail unless this snapshot is current")
    parser.add_argument("--json", action="store_true", help="emit machine-readable summary")
    args = parser.parse_args()

    manifest = load_yaml(MANIFEST)
    b1 = manifest.get("b1")
    if not isinstance(b1, dict):
        fail("b1-manifest.yml has no b1 mapping")

    snapshot_id = b1.get("snapshot")
    if not isinstance(snapshot_id, str) or not snapshot_id:
        fail("current B1 snapshot ID missing")
    if args.expect_snapshot and snapshot_id != args.expect_snapshot:
        fail(f"expected current snapshot {args.expect_snapshot}, found {snapshot_id}")

    snapshot_rel = b1.get("snapshot_definition")
    if not isinstance(snapshot_rel, str) or not snapshot_rel:
        fail("current snapshot_definition missing")
    snapshot_path = ROOT / snapshot_rel
    snapshot = load_yaml(snapshot_path)
    if snapshot.get("snapshot") != snapshot_id:
        fail(f"snapshot file identifies {snapshot.get('snapshot')!r}, manifest identifies {snapshot_id!r}")

    manifest_b0 = manifest.get("b0")
    snapshot_b0 = snapshot.get("b0")
    if not isinstance(manifest_b0, dict) or not isinstance(snapshot_b0, dict):
        fail("B0 identity mapping missing from manifest or snapshot")
    for key in ("source_archive_sha256", "expanded_member_manifest_sha256"):
        m = require_hex64(f"manifest b0.{key}", manifest_b0.get(key))
        s = require_hex64(f"snapshot b0.{key}", snapshot_b0.get(key))
        if m != s:
            fail(f"B0 identity mismatch for {key}: manifest={m}, snapshot={s}")

    declared_member_manifest_sha = require_hex64(
        "b0.expanded_member_manifest_sha256", manifest_b0.get("expanded_member_manifest_sha256")
    )
    actual_member_manifest_sha = sha256_file(B0_MEMBER_MANIFEST)
    if actual_member_manifest_sha != declared_member_manifest_sha:
        fail(
            "canonical B0 member-manifest SHA mismatch: "
            f"declared={declared_member_manifest_sha}, actual={actual_member_manifest_sha}"
        )
    canonical_members = parse_b0_member_manifest(B0_MEMBER_MANIFEST)

    manifest_patches = b1.get("patches")
    snapshot_patches = snapshot.get("patches")
    if not isinstance(manifest_patches, list) or not isinstance(snapshot_patches, list):
        fail("manifest or snapshot patch list missing")
    if not manifest_patches:
        fail("current corrected-reference patch list is empty")
    compare_patch_lists(manifest_patches, snapshot_patches)

    evidence: list[dict[str, Any]] = []
    for patch in snapshot_patches:
        patch_id = patch.get("id")
        if not isinstance(patch_id, str) or not re.fullmatch(r"SWAP-[0-9]{3}", patch_id):
            fail(f"invalid patch ID: {patch_id!r}")

        patch_rel = patch.get("patch_path")
        if not isinstance(patch_rel, str):
            fail(f"{patch_id}: patch_path missing")
        expected_prefix = f"reference/swap-4.3.1/patches/{patch_id}/"
        if not patch_rel.startswith(expected_prefix):
            fail(f"{patch_id}: patch_path escapes own dossier: {patch_rel}")
        patch_path = ROOT / patch_rel
        if not patch_path.is_file():
            fail(f"{patch_id}: stored patch missing: {patch_rel}")

        declared_patch_sha = require_hex64(f"{patch_id}.patch_sha256", patch.get("patch_sha256"))
        actual_patch_sha = sha256_file(patch_path)
        if actual_patch_sha != declared_patch_sha:
            fail(f"{patch_id}: stored patch SHA mismatch: declared={declared_patch_sha}, actual={actual_patch_sha}")

        target = patch.get("target")
        if not isinstance(target, str) or target not in canonical_members:
            fail(f"{patch_id}: target missing from canonical B0 member manifest: {target!r}")
        canonical_b0_sha, canonical_b0_size = canonical_members[target]
        declared_b0_sha = require_hex64(f"{patch_id}.b0_target_sha256", patch.get("b0_target_sha256"))
        if declared_b0_sha != canonical_b0_sha:
            fail(
                f"{patch_id}: B0 preimage identity is not canonical for {target}: "
                f"declared={declared_b0_sha}, canonical={canonical_b0_sha}"
            )

        corrected_sha = require_hex64(
            f"{patch_id}.corrected_target_sha256", patch.get("corrected_target_sha256")
        )

        manifest_entry = next(p for p in manifest_patches if p.get("id") == patch_id)
        qualification_rel = patch.get("qualification") or manifest_entry.get("qualification")
        if not isinstance(qualification_rel, str) or not (ROOT / qualification_rel).is_file():
            fail(f"{patch_id}: qualification evidence path missing or invalid: {qualification_rel!r}")

        dossier = patch_path.parent
        helper_candidates: list[Path] = []
        explicit_helper = patch.get("canonical_verifier") or manifest_entry.get("canonical_b0_verifier")
        if explicit_helper:
            helper_candidates.append(ROOT / str(explicit_helper))
        default_helper = dossier / "apply_and_verify.py"
        if default_helper.is_file():
            helper_candidates.append(default_helper)

        existing_helpers: list[str] = []
        helper_b0_matches = False
        helper_b1_checked = False
        for helper in dict.fromkeys(helper_candidates):
            if not helper.is_file():
                fail(f"{patch_id}: declared verifier missing: {helper.relative_to(ROOT)}")
            existing_helpers.append(str(helper.relative_to(ROOT)))
            helper_b0, helper_b1 = helper_hashes(helper)
            if helper_b0 is not None:
                if helper_b0 != canonical_b0_sha:
                    fail(
                        f"{patch_id}: verifier {helper.relative_to(ROOT)} pins non-canonical B0 SHA "
                        f"{helper_b0} (canonical {canonical_b0_sha})"
                    )
                helper_b0_matches = True
            if helper_b1 is not None:
                helper_b1_checked = True
                if helper_b1 != corrected_sha:
                    fail(
                        f"{patch_id}: verifier {helper.relative_to(ROOT)} corrected SHA mismatch "
                        f"{helper_b1} != {corrected_sha}"
                    )

        if not existing_helpers:
            fail(f"{patch_id}: no byte-verification helper found")
        if not helper_b0_matches:
            fail(f"{patch_id}: verifier set does not pin the canonical B0 target SHA")

        evidence.append(
            {
                "id": patch_id,
                "patch_sha256": actual_patch_sha,
                "target": target,
                "b0_target_sha256": canonical_b0_sha,
                "b0_target_bytes": canonical_b0_size,
                "corrected_target_sha256_declared": corrected_sha,
                "corrected_target_sha_checked_by_helper": helper_b1_checked,
                "qualification": qualification_rel,
                "verifiers": existing_helpers,
            }
        )

    fingerprint_payload = {
        "snapshot": snapshot_id,
        "snapshot_definition_sha256": sha256_file(snapshot_path),
        "b0_source_archive_sha256": manifest_b0["source_archive_sha256"],
        "b0_member_manifest_sha256": actual_member_manifest_sha,
        "patches": evidence,
    }
    fingerprint = hashlib.sha256(
        json.dumps(fingerprint_payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()

    result = {
        "status": "PASS",
        "scope": "artifact-and-canonical-B0-preimage-identity",
        "snapshot": snapshot_id,
        "oracle_status_before_gate": b1.get("oracle_status"),
        "identity_fingerprint_sha256": fingerprint,
        "patch_count": len(evidence),
        "corrected_target_recomputation": "NOT_PERFORMED_WITHOUT_BYTE_EXACT_B0_SOURCE_TREE",
        "evidence": evidence,
    }
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"B1_IDENTITY_GATE=PASS snapshot={snapshot_id} patches={len(evidence)}")
        print(f"B1_IDENTITY_FINGERPRINT_SHA256={fingerprint}")
        for item in evidence:
            print(
                f"  {item['id']}: patch={item['patch_sha256']} "
                f"b0={item['b0_target_sha256']} corrected_declared={item['corrected_target_sha256_declared']}"
            )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except GateFailure as exc:
        print(f"B1_IDENTITY_GATE=FAIL: {exc}")
        raise SystemExit(1)
