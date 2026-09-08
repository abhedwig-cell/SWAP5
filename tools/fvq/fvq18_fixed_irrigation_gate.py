#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess

QUALIFIED_SOURCE = "61df2b26c569fe59231f22ba0b28e21e009d3892"
QUALIFIED_TREE = "dc053278de45df5eff427689ef244159cf8d8d3e"
CLOSEOUT = "55efeb4090a669d179a8d93f73e0799e6c7623c5"
CLOSEOUT_TREE = "746d40e6beb25e92986f523d80669966d861b7cb"
IRRIGATION_PATH = "src/process/mod_irrigation_process.f90"
IRRIGATION_BLOB = "af8dc3b3e16d261af573c9b626704638d5ee70c9"
LEGACY_SHA256 = "65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def blob_at(commit: str, path: str) -> str:
    line = git("ls-tree", commit, "--", path)
    parts = line.split()
    assert len(parts) >= 3, f"missing {path} at {commit}"
    return parts[2]


assert git("rev-parse", f"{QUALIFIED_SOURCE}^{{tree}}") == QUALIFIED_TREE
assert git("rev-parse", f"{CLOSEOUT}^{{tree}}") == CLOSEOUT_TREE
assert blob_at(QUALIFIED_SOURCE, IRRIGATION_PATH) == IRRIGATION_BLOB
assert blob_at(CLOSEOUT, IRRIGATION_PATH) == IRRIGATION_BLOB
assert git("hash-object", IRRIGATION_PATH) == IRRIGATION_BLOB

post_source = git("diff", "--name-only", f"{QUALIFIED_SOURCE}..{CLOSEOUT}", "--", "src", "reference")
assert post_source == "", f"F-PM03 evidence closeout changed production source: {post_source!r}"
qualification_source = git("diff", "--name-only", f"{CLOSEOUT}..HEAD", "--", "src", "reference")
assert qualification_source == "", f"F-VQ18 modified source/reference: {qualification_source!r}"

contract = json.loads(Path("integration/f-vq/F-VQ18_CONTRACT.json").read_text())
assert contract["qualified_source_commit"] == QUALIFIED_SOURCE
assert contract["qualified_source_tree"] == QUALIFIED_TREE
assert contract["candidate_closeout_commit"] == CLOSEOUT
assert contract["candidate_closeout_tree"] == CLOSEOUT_TREE
assert contract["candidate_process_blob"] == IRRIGATION_BLOB
assert contract["source_modification_permitted"] is False

oracle = json.loads(Path("integration/f-pm/F-PM03_B110_FIXED_EVENT_ORACLE.json").read_text())
assert oracle["source"]["sha256"] == LEGACY_SHA256
rules = oracle["runtime_equations_and_rules"]
required_rule_fragments = {
    "event_match": "abs(irdate(nirri)-t1900) < 1e-3",
    "surface_rate": "gird=irrate(nirri)",
    "surface_concentration": "cirr=irconc(nirri)",
    "ssdi_rate": "qssdi(nod_ssdi(1):nod_ssdi(2))=irrate(nirri)",
    "duration": "dt_irr_event=irdepth(nirri)/irrate(nirri)",
    "cursor": "nirri increments by one",
}
for key, fragment in required_rule_fragments.items():
    assert fragment in rules[key], f"oracle rule drift for {key}: {rules[key]}"
translation = oracle["translation_rules"]
assert "divided by the number of SSDI nodes" in translation["ssdi_depth_distribution"]
assert "irrate is not divided" in translation["ssdi_rate_distribution"]
assert "node_count * per_node_rate * duration equals original total irrigation depth" == translation["ssdi_total_water_identity"]

# Exact F-MR06 production blobs needed by the independent snow preservation check.
expected_blobs = {
    "src/process/mod_snow_process.f90": "54702d71b4c84dce2842813549bd14c57301a383",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "202ab846cbd30d149d0d450249b3d517e333994f",
    "src/runtime/mod_fmr_serialized_multiswap_runtime.f90": "1bb0c6d4683db2729d48de31babcea72bc1a6caf",
    "src/kernel/mod_kernel_transactions.f90": "9f7c16e71cfb93b57f796ba759bae73824318a2f",
    "src/transaction/mod_transaction_reference.f90": "b1878606ae6cb2b04a7b4b15e3e537deacf4477f",
    "src/runtime/mod_canonical_contracts.f90": "0c2b15fc45011c580384cf6a618e7b378fdccf0a",
    "src/runtime/mod_canonical_interval_runtime.f90": "f2cae79d533343db818c11e0b61b605ac5f6739d",
}
for path, expected in expected_blobs.items():
    actual = git("hash-object", path)
    assert actual == expected, f"F-MR06 source drift {path}: {actual} != {expected}"

runner = Path("tests/fvq/run_fvq18_fixed_irrigation_gate.sh").read_text().lower()
assert "run_fpm03_fixed_event_gate.sh" not in runner, "F-VQ18 must not call the F-PM03 engineering gate"

print("FVQ18_SOURCE_PROVENANCE_LOCK PASS")
print("FVQ18_LEGACY_ORACLE_LOCK PASS")
print("FVQ18_NO_SOURCE_MODIFICATION PASS")
print("FVQ18_FMR06_SOURCE_PRESERVATION PASS")
