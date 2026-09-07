#!/usr/bin/env python3
"""F-CI02 fail-closed gate for the canonical B1.10 integration root.

This gate changes no production physics. It verifies that F-CI starts from the
exact repository/main commit and corrected-reference identity admitted for B1.10,
and then delegates reconstruction/admission to the existing VQ B1.10 gate when
available.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = REPO_ROOT / "integration" / "f-ci" / "canonical-source-manifest.json"
SNAPSHOT = REPO_ROOT / "reference" / "swap-4.3.1" / "snapshots" / "B1.10.yml"
EXPECTED_MAIN = "fafeebdece209abcc320b24a3c8c2757800b2e0e"
EXPECTED_B1_ADMISSION = "5a25526e77a4e1ba3b8f2755cb1e59ca0700ee96"
EXPECTED_MEMBER_COUNT = 63
EXPECTED_SOURCE_BYTES = 1863575
EXPECTED_MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"


def _git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def assess(repo: Path, run_vq_gate: bool) -> dict[str, object]:
    result: dict[str, object] = {"work_unit": "F-CI02", "checks": {}, "pass": False}
    checks: dict[str, bool] = result["checks"]  # type: ignore[assignment]

    manifest_path = repo / MANIFEST.relative_to(REPO_ROOT)
    snapshot_path = repo / SNAPSHOT.relative_to(REPO_ROOT)
    checks["manifest_exists"] = manifest_path.is_file()
    checks["b1_10_snapshot_exists"] = snapshot_path.is_file()
    if not all(checks.values()):
        return result

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    root = manifest.get("root", {})
    oracle = manifest.get("legacy_oracle", {})
    tx = manifest.get("transactional_lineage", {})

    checks["main_root_pinned"] = root.get("main_commit") == EXPECTED_MAIN
    checks["b1_10_admission_pinned"] = oracle.get("admission_commit") == EXPECTED_B1_ADMISSION
    checks["b1_10_snapshot_pinned"] = oracle.get("snapshot") == "B1.10"
    checks["member_count_pinned"] = oracle.get("source_member_count") == EXPECTED_MEMBER_COUNT
    checks["source_bytes_pinned"] = oracle.get("source_bytes") == EXPECTED_SOURCE_BYTES
    checks["source_manifest_pinned"] = oracle.get("source_manifest_sha256") == EXPECTED_MANIFEST_SHA256
    checks["a23_not_direct_merge"] = tx.get("direct_merge_allowed") is False
    checks["a23_merge_base_is_b1_6"] = tx.get("merge_base_with_b1_10") == "2d05eeab9d766d51bc7c436ea1e45f9b49940e92"

    try:
        root_is_ancestor = subprocess.run(
            ["git", "-C", str(repo), "merge-base", "--is-ancestor", EXPECTED_MAIN, "HEAD"],
            check=False,
        ).returncode == 0
    except OSError:
        root_is_ancestor = False
    checks["current_head_descends_from_pinned_main_root"] = root_is_ancestor

    if run_vq_gate:
        gate = repo / "tools" / "vq" / "b1_10_admission_gate.py"
        checks["vq_b1_10_gate_exists"] = gate.is_file()
        if gate.is_file():
            completed = subprocess.run([sys.executable, str(gate)], cwd=repo, check=False)
            checks["vq_b1_10_gate_pass"] = completed.returncode == 0
        else:
            checks["vq_b1_10_gate_pass"] = False

    result["pass"] = all(checks.values())
    if not result["pass"]:
        result["failed_checks"] = [name for name, ok in checks.items() if not ok]
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--skip-vq-gate", action="store_true")
    args = parser.parse_args()
    result = assess(args.repo_root.resolve(), run_vq_gate=not args.skip_vq_gate)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
