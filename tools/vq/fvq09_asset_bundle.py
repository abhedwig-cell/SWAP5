#!/usr/bin/env python3
"""F-VQ09 fail-closed external asset byte-manifest utilities.

Candidate directory manifests are deliberately not self-admitting. Real execution
requires independently persisted admitted manifest hashes in the F-VQ09 bundle
contract.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONTRACT = ROOT / "integration/f-vq/F-VQ09_ASSET_BUNDLE_CONTRACT.json"


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def directory_manifest(root: Path) -> dict[str, Any]:
    root = root.resolve()
    if not root.is_dir():
        raise ValueError(f"directory_not_found:{root}")
    entries: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*"), key=lambda p: p.relative_to(root).as_posix()):
        rel = path.relative_to(root).as_posix()
        if "\n" in rel or "\r" in rel:
            raise ValueError("newline_in_relative_path")
        if path.is_symlink():
            raise ValueError(f"symlink_not_allowed:{rel}")
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError(f"non_regular_file_not_allowed:{rel}")
        entries.append({
            "path": rel,
            "size_bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        })
    if not entries:
        raise ValueError("empty_directory_not_allowed")
    manifest_text = "".join(
        f"{entry['sha256']}  {entry['size_bytes']}  {entry['path']}\n" for entry in entries
    )
    manifest_bytes = manifest_text.encode("utf-8")
    return {
        "root": str(root),
        "file_count": len(entries),
        "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "entries": entries,
    }


def validate_b0(path: Path, spec: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "path": str(path),
        "expected_name": spec.get("name"),
        "expected_size_bytes": spec.get("size_bytes"),
        "expected_sha256": spec.get("sha256"),
        "exact_identity": False,
    }
    if not path.is_file():
        result["status"] = "FAIL_MISSING"
        return result
    result["observed_size_bytes"] = path.stat().st_size
    result["observed_sha256"] = sha256_file(path)
    result["exact_identity"] = (
        result["observed_size_bytes"] == spec.get("size_bytes")
        and result["observed_sha256"] == spec.get("sha256")
    )
    result["status"] = "PASS_EXACT" if result["exact_identity"] else "FAIL_IDENTITY_MISMATCH"
    return result


def validate_external_directory(root: Path, spec: dict[str, Any], label: str) -> dict[str, Any]:
    result: dict[str, Any] = {"label": label, "path": str(root), "admitted": False}
    try:
        candidate = directory_manifest(root)
    except Exception as exc:
        result.update({"status": "FAIL_DIRECTORY_CONTRACT", "failure": str(exc)})
        return result
    result["candidate_manifest_sha256"] = candidate["manifest_sha256"]
    result["candidate_file_count"] = candidate["file_count"]
    anchors = spec.get("required_anchor_files", [])
    entry_paths = {entry["path"] for entry in candidate["entries"]}
    missing = [anchor for anchor in anchors if anchor not in entry_paths]
    result["missing_anchor_files"] = missing
    if missing:
        result["status"] = "FAIL_MISSING_ANCHOR"
        return result
    expected_hash = spec.get("admitted_manifest_sha256")
    expected_count = spec.get("admitted_file_count")
    if expected_hash is None or expected_count is None:
        result["status"] = "BLOCKED_NOT_INDEPENDENTLY_ADMITTED"
        return result
    hash_ok = candidate["manifest_sha256"] == expected_hash
    count_ok = candidate["file_count"] == expected_count
    result["manifest_matches"] = hash_ok
    result["file_count_matches"] = count_ok
    result["admitted"] = bool(hash_ok and count_ok)
    result["status"] = "PASS_ADMITTED" if result["admitted"] else "FAIL_ADMITTED_IDENTITY_MISMATCH"
    return result


def load_contract(path: Path = DEFAULT_CONTRACT) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_bundle(b0: Path, ttutil: Path, case: Path, contract_path: Path = DEFAULT_CONTRACT) -> dict[str, Any]:
    contract = load_contract(contract_path)
    chain = contract["source_chain"]
    result = {
        "work_unit": "F-VQ09",
        "contract": str(contract_path),
        "b0": validate_b0(b0, chain["b0_distribution"]),
        "ttutil": validate_external_directory(ttutil, contract["ttutil"], "TTUTIL"),
        "hupsel_case": validate_external_directory(case, contract["hupsel_case"], "HUPSEL_CASE"),
    }
    result["bundle_admitted"] = bool(
        result["b0"].get("exact_identity")
        and result["ttutil"].get("admitted")
        and result["hupsel_case"].get("admitted")
    )
    if result["bundle_admitted"]:
        result["status"] = "PASS_ADMITTED_BUNDLE"
    elif not result["b0"].get("exact_identity"):
        result["status"] = "FAIL_B0_IDENTITY"
    else:
        result["status"] = "BLOCKED_EXTERNAL_ASSET_ADMISSION"
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    capture = sub.add_parser("capture-dir")
    capture.add_argument("path", type=Path)
    validate = sub.add_parser("validate-bundle")
    validate.add_argument("--b0", required=True, type=Path)
    validate.add_argument("--ttutil", required=True, type=Path)
    validate.add_argument("--case", required=True, type=Path)
    validate.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    args = parser.parse_args()

    try:
        if args.command == "capture-dir":
            result = directory_manifest(args.path)
            result["candidate_manifest_is_admission"] = False
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        result = validate_bundle(args.b0, args.ttutil, args.case, args.contract)
        print(json.dumps(result, indent=2, sort_keys=True))
        if result["bundle_admitted"]:
            return 0
        return 2 if result["status"] == "FAIL_B0_IDENTITY" else 3
    except Exception as exc:
        print(json.dumps({"work_unit": "F-VQ09", "status": "FAIL_CONTRACT", "failure": str(exc)}, indent=2))
        return 2


if __name__ == "__main__":
    sys.exit(main())
