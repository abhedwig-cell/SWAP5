#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRAPH = ROOT / "integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json"
PRE = ROOT / "integration/audits/PPA_WU05_PREREGISTRATION.json"
STATUS = ROOT / "integration/audits/PPA_WU05_STATUS.json"
DOC = ROOT / "docs/audits/PPA_WU05_ADVANCED_WATER_PROCESS_TRIAGE.md"

graph = json.loads(GRAPH.read_text())
pre = json.loads(PRE.read_text())
status = json.loads(STATUS.read_text())
doc = DOC.read_text()

assert graph["schema"] == "swap5.ppa_wu05.advanced_water_dependency_graph.v1"
assert pre["workunit"] == "PPA-WU05"
assert status["work_unit"] == "PPA-WU05"

assert graph["reference"]["snapshot"] == "B1.11"
assert graph["reference"]["member_manifest_sha256"] == "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
assert pre["source_authority"]["macropore"]["corrected_b1_sha256"] == "f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f"
assert pre["source_authority"]["oxygenstress"]["corrected_b1_sha256"] == "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"

policy = graph["authority_policy"]
unsupported = set(policy["removed_unsupported_historical_evidence"])
assert {"S12o", "A23au", "S12r"}.issubset(unsupported)

macro = graph["families"]["macropore"]
assert macro["physical_state_evidence"]["status"] == "SOURCE_TRACE_REQUIRED"
assert "committed_history_fields" not in macro["physical_state_evidence"]
assert macro["scratch_evidence"]["status"] == "SOURCE_TRACE_REQUIRED"

frost = graph["families"]["frost_hydraulic_modifier"]
assert frost["persistent_state"] == "UNRESOLVED_SOURCE_TRACE_REQUIRED"
assert frost["recomputable_fields"] == []

oxygen = graph["families"]["advanced_root_stress"]["subfamilies"]["oxygen"]
assert "not yet source-bound" in oxygen["current_source_trace"].lower()
assert "does not assume separability" in oxygen["composition_target"].lower()

first = graph["ranked_targets"][0]
assert first["id"] == "PPA-WU05-A"
assert first["target"] == "Macropore source/state/mass/transaction authority"
assert "No macropore production equations" in first["scope"]
assert first["implementation_admission"] == "REVIEW_AUTHORITY_ONLY_NO_PRODUCTION_MACROPORE_CLAIM"

ids = [x["id"] for x in graph["ranked_targets"]]
assert len(ids) == len(set(ids))
assert ids[:3] == ["PPA-WU05-A", "PPA-WU05-C", "PPA-WU05-B"]

assert status["production_source_mutation"] is False
assert status["reference_mutation"] is False
assert status["first_target"]["id"] == "PPA-WU05-A"
assert status["first_target"]["type"] == "REVIEW_ONLY_PREREQUISITE"
assert status["first_target"]["production_admission"] == "NONE"

for phrase in [
    "Macropore source/state/mass/transaction authority",
    "repository-authority correction",
    "Current sensible-temperature production is not frost production",
    "existing root-water-uptake owner remains the only admitted root-water mass sink",
]:
    assert phrase.lower() in doc.lower(), phrase

# This review must never mutate production or corrected-reference source.
subprocess.run(["git", "fetch", "-q", "origin", "integration/f-ci-canonical"], cwd=ROOT, check=True)
changed = subprocess.check_output(
    ["git", "diff", "--name-only", "origin/integration/f-ci-canonical...HEAD"],
    cwd=ROOT,
    text=True,
).splitlines()
for path in changed:
    assert not path.startswith("src/"), f"production source mutation: {path}"
    assert not path.startswith("reference/"), f"reference mutation: {path}"

# PPA-WU05 is already a frozen parent authority. On later child or governance
# work, this validator owns only its scientific contract plus the absolute
# prohibition on src/reference mutation above. It must not claim an allowlist
# over unrelated governance/evidence files in the same pull request.
print("PPA_WU05_CROSS_GOVERNANCE_DELTA_NOT_OWNED=PASS")
print("PPA_WU05_B1_11_AUTHORITY=PASS")
print("PPA_WU05_UNSUPPORTED_HISTORY_NOT_DECISION_AUTHORITY=PASS")
print("PPA_WU05_MACROPORE_STATE_TRACE_HELD=PASS")
print("PPA_WU05_FROST_STATE_TRACE_HELD=PASS")
print("PPA_WU05_OXYGEN_STATE_TRACE_HELD=PASS")
print("PPA_WU05_FIRST_TARGET_MACROPORE_REVIEW_ONLY=PASS")
print("PPA_WU05_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS")
print("PPA-WU05 ADVANCED WATER PROCESS TRIAGE REVIEW PASS")
