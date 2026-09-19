#!/usr/bin/env python3
"""Validate PUB-GC E7 preservation against the current canonical application envelope."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path: str) -> bytes:
    return (ROOT / path).read_bytes()

def load(path: str):
    return json.loads(read(path).decode("utf-8"))

def git_blob_sha(path: str) -> str:
    data = read(path)
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

rec = load("docs/publication/PUB_GC_E7_CURRENT_CANONICAL_RECONCILIATION_20260919.json")
e7 = load("docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json")
wu02 = load("integration/audits/PPA_WU02_STATUS.json")
wu03 = load("integration/audits/PPA_WU03_STATUS.json")
wu04 = load("integration/audits/PPA_WU04_STATUS.json")
wu05 = load("integration/audits/PPA_WU05_STATUS.json")
wu05a = load("integration/audits/PPA_WU05A_STATUS.json")
low02 = load("integration/audits/PPA_LOW02_TIME_STATUS.json")
wu05c = load("integration/audits/PPA_WU05C_STATUS.json")
src_path = "src/runtime/mod_fmr_production_application_bootstrap.f90"
src = read(src_path).decode("utf-8")

assert e7["status"] == "CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT"
assert e7["outcome"] == "REALISTIC_COMPONENT_DOMAIN_LIMIT"
assert git_blob_sha("docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json") == rec["e7"]["result_blob"]

assert git_blob_sha(src_path) == rec["current_production_boundary"]["bootstrap_blob"]
assert "groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5" in src
assert "prescribed_qbot_profile = prescribed_qbot_profile .and. config%tiles(i)%parameters%bottom_mode == 2" in src
assert "standalone_profile = standalone_profile .and. config%tiles(i)%parameters%bottom_mode == 7" in src
assert "tile%parameters%drainage_response_active .or. tile%parameters%root_extraction_active" in src

assert git_blob_sha("integration/audits/PPA_WU02_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU02"]["status_blob"]
assert wu02["status"] == "CANONICAL_ADMITTED_CLOSED"
assert "bottom_mode=2" in wu02["admission"]["scope"]
assert "PPA-WU01/F-GC mode5 groundwater" in wu02["first_slice"]["preserved_application_authority"]
assert "mixed bottom-mode production profiles" in wu02["admission"]["nonclaims"]

assert git_blob_sha("integration/audits/PPA_WU03_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU03"]["status_blob"]
assert wu03["state"] == "CANONICAL_ADMITTED_CLOSED"
assert "mixed PPA-WU01 bottom_mode=5/7 ownership" in wu03["explicit_nonclaims"]
assert "new physics or tolerance changes" in wu03["explicit_nonclaims"]

assert git_blob_sha("integration/audits/PPA_WU04_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU04"]["status_blob"]
assert wu04["scope"]["production_source_mutation"] is False
assert wu04["production_admission"] == "NONE_REVIEW_ONLY"

assert git_blob_sha("integration/audits/PPA_WU05_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05"]["status_blob"]
assert wu05["production_source_mutation"] is False
assert wu05["first_target"]["production_admission"] == "NONE"

assert git_blob_sha("integration/audits/PPA_WU05A_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05A"]["status_blob"]
assert wu05a["production_source_mutation"] is False
assert wu05a["production_admission"] == "NONE_REVIEW_ONLY"

assert git_blob_sha("integration/audits/PPA_LOW02_TIME_STATUS.json") == rec["later_canonical_workunits"]["PPA_LOW02_TIME"]["status_blob"]
assert low02["status"] == "CANONICAL_ADMITTED_CLOSED"
assert low02["admission"]["state"] == "CANONICAL_ADMITTED"
assert "new groundwater-coupling semantics" in low02["explicit_nonclaims"]
assert "mixed bottom-mode production profiles" in low02["explicit_nonclaims"]
assert rec["later_canonical_workunits"]["PPA_LOW02_TIME"]["groundwater_semantics_change"] is False

assert git_blob_sha("integration/audits/PPA_WU05C_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05C"]["status_blob"]
assert wu05c["status"] == "CANONICAL_ADMITTED_REVIEW_AUTHORITY_CLOSED"
assert wu05c["scope"]["production_source_mutation"] is False
assert wu05c["production_admission"] == "NONE_REVIEW_ONLY"

assert rec["canonical_head_at_reconcile"] == "67dcbd5252ec6aab465329c55e427f535ce47f02"
assert rec["verdict"] == "E7_CURRENT_CANONICAL_PRESERVED"

print("PUB_GC_E7_CURRENT_RESULT_CLOSED=PASS")
print("PUB_GC_E7_CURRENT_BOOTSTRAP_BLOB=PASS")
print("PUB_GC_E7_CURRENT_MODE5_GROUNDWATER_PROFILE=PASS")
print("PUB_GC_E7_CURRENT_ACTIVE_DRAINAGE_ROOT_GUARD=PASS")
print("PUB_GC_E7_PPA_WU02_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU03_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU04_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_WU05_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_WU05A_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_LOW02_TIME_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU05C_REVIEW_ONLY=PASS")
print("PUB_GC_E7_CURRENT_CANONICAL_PRESERVED=PASS")
