#!/usr/bin/env python3
"""F-TB11 structural/provenance gate for the frozen current-canonical preservation set."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "testbank/manifests/F-TB11_CURRENT_CANONICAL_100_PERCENT_CAPABILITY_PRESERVATION.json"
REQUIRED_LAYERS = {
    "constitutive", "process", "solver", "kernel/transaction", "persistence/restart",
    "integrated column", "legacy/reference", "coupling", "MultiSWAP", "performance",
    "robustness", "release qualification",
}
ALLOWED_HEAD_DELTA_PREFIXES = (
    "testbank/",
    "docs/testbank/F-TB11_",
    ".github/workflows/f-tb11-current-canonical-permanent-preservation.yml",
)
ALLOWED_HEADCALC_CALL_PATHS = {
    "src/adapter/mod_reference_richards_legacy_binding.f90",
    "src/adapter/mod_b110_production_soil_water_task2.f90",
}


def fail(msg: str) -> None:
    raise SystemExit(f"FTB11_VALIDATION_FAIL {msg}")


def git(*args: str, check: bool = True) -> str:
    cp = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True)
    if check and cp.returncode != 0:
        fail(f"git {' '.join(args)} rc={cp.returncode}: {cp.stderr.strip()}")
    return cp.stdout.strip()


def marker(test_id: str, detail: str = "PASS") -> None:
    print(f"{test_id}={detail}")


def load_git_json(commit: str, path: str) -> dict:
    raw = git("show", f"{commit}:{path}")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        fail(f"invalid authority JSON {commit}:{path}: {exc}")


def assert_blob(commit: str, path: str, expected: str) -> None:
    actual = git("rev-parse", f"{commit}:{path}")
    if actual != expected:
        fail(f"blob drift {path}: expected={expected} actual={actual}")


def verify_canonical_run(run_id: int, expected_sha: str) -> None:
    url = f"https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/{run_id}"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "SWAP5-F-TB11"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = json.load(response)
    except Exception as exc:  # network/API failure must fail closed
        fail(f"cannot independently read canonical workflow run {run_id}: {exc}")
    if payload.get("head_sha") != expected_sha:
        fail(f"canonical run head drift: {payload.get('head_sha')} != {expected_sha}")
    if payload.get("status") != "completed" or payload.get("conclusion") != "success":
        fail(f"canonical run is not successful: status={payload.get('status')} conclusion={payload.get('conclusion')}")


def main() -> None:
    data = json.loads(MANIFEST.read_text())
    canon = data["current_canonical"]
    csha = canon["sha"]

    # Stable registry and layer coverage.
    tests = data["stable_tests"]
    ids = [item["id"] for item in tests]
    if len(ids) != len(set(ids)):
        fail("stable test IDs are not unique")
    if set(data["layer_coverage"]) != REQUIRED_LAYERS:
        fail(f"layer coverage mismatch: {set(data['layer_coverage']) ^ REQUIRED_LAYERS}")
    known = set(ids)
    for layer, refs in data["layer_coverage"].items():
        if not refs or not set(refs) <= known:
            fail(f"invalid layer registry for {layer}: {refs}")
    if data["horizontal_hard_gate"] != {"mass_conservation": "FTB11-MASS-001", "waivable": False}:
        fail("mass conservation is not the non-waivable horizontal gate")
    if data["drainage"]["adopted_as_100_percent_capability"]:
        fail("unqualified drainage was credited")

    # Live and immutable current-canonical binding.
    live = git("ls-remote", "origin", "refs/heads/integration/f-ci-canonical").split()[0]
    if live != csha:
        fail(f"stale canonical binding expected={csha} live={live}")
    expected_objects = {
        "^{tree}": canon["tree"],
        ":src": canon["src_tree"],
        ":reference": canon["reference_tree"],
        ":tests": canon["tests_tree"],
        ":.github/workflows/fci-canonical.yml": canon["canonical_workflow_blob"],
    }
    for suffix, expected in expected_objects.items():
        actual = git("rev-parse", csha + suffix)
        if actual != expected:
            fail(f"canonical object drift {suffix}: expected={expected} actual={actual}")
    verify_canonical_run(canon["qualification_run"], csha)

    # F-TB ownership: no src/reference delta and no unrelated branch changes.
    prod_delta = git("diff", "--name-only", f"{csha}..HEAD", "--", "src", "reference")
    if prod_delta:
        fail(f"production/reference changed by F-TB11: {prod_delta}")
    changed = [p for p in git("diff", "--name-only", f"{csha}..HEAD").splitlines() if p]
    bad = [p for p in changed if not p.startswith(ALLOWED_HEAD_DELTA_PREFIXES)]
    if bad:
        fail(f"ownership scope violation: {bad}")
    marker("FTB11-REL-001")

    # Exact authority SHA/tree/path/decision for every adopted 100% capability.
    for cap in data["adopted_capabilities"]:
        sha = cap["authority_sha"]
        actual_tree = git("rev-parse", f"{sha}^{{tree}}")
        if actual_tree != cap["authority_tree"]:
            fail(f"authority tree mismatch {cap['authority_work_unit']}: {actual_tree}")
        status = load_git_json(sha, cap["authority_path"])
        if status.get("decision") != cap["decision"]:
            fail(f"authority decision mismatch {cap['authority_work_unit']}: {status.get('decision')}")

    # Exact current-source locks for the highest-risk completion surfaces.
    kt = data["adopted_capabilities"][0]["provenance"]
    assert_blob(csha, kt["transaction_path"], kt["transaction_blob"])

    seam = data["adopted_capabilities"][4]["provenance"]
    assert_blob(csha, seam["adapter_path"], seam["adapter_blob"])
    assert_blob(csha, seam["soilwater_path"], seam["soilwater_blob"])
    adapter = git("show", f"{csha}:{seam['adapter_path']}")
    if "soil_water_solver_t" not in adapter:
        fail("mandatory soil_water_solver_t production seam disappeared")
    soilwater = git("show", f"{csha}:{seam['soilwater_path']}")
    for raw in soilwater.splitlines():
        code = raw.split("!", 1)[0]
        if re.search(r"\bcall\s+headcalc\b", code, flags=re.I):
            fail("MOD_SoilWater direct HeadCalc production bypass reappeared")

    grep = subprocess.run(
        ["git", "grep", "-n", "-i", "-E", r"call[[:space:]]+HeadCalc", csha, "--", "src"],
        cwd=ROOT, text=True, capture_output=True,
    )
    if grep.returncode not in (0, 1):
        fail(f"HeadCalc classification grep failed: {grep.stderr.strip()}")
    found_paths = set()
    for line in grep.stdout.splitlines():
        parts = line.split(":", 2)
        if len(parts) >= 2:
            found_paths.add(parts[1])
    unexpected = found_paths - ALLOWED_HEADCALC_CALL_PATHS
    if unexpected:
        fail(f"production HeadCalc calls outside admitted bindings: {sorted(unexpected)}")
    marker("FTB11-SEAM-001")

    et = data["adopted_capabilities"][5]["provenance"]
    et_blobs = {
        "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90": et["surface_materializer_blob"],
        "src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90": et["accepted_publication_blob"],
        "src/runtime/mod_fmr_accepted_commit_receipt.f90": et["accepted_commit_receipt_blob"],
        "src/process/mod_restricted_surface_evaporation.f90": et["restricted_surface_evaporation_blob"],
    }
    for path, blob in et_blobs.items():
        assert_blob(csha, path, blob)

    # Authority-backed permanent preservation IDs. Their scientific oracles are
    # not duplicated here; provenance and the exact green canonical postimage are.
    marker("FTB11-RST-001")
    marker("FTB11-MSW-001")
    marker("FTB11-FR-001")
    marker("FTB11-ET-001")
    print("FTB11_STRUCTURAL_PROVENANCE_GATE=PASS")


if __name__ == "__main__":
    main()
