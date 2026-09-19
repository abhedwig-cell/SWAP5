#!/usr/bin/env python3
from __future__ import annotations
import json, os, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE="781c829943c9e5880e5ab83281112e66f439ecf2"
TREE="9ca065553765e38eec4d4ceb611ec80d866dbae3"
SRC_TREE="573df94cbb1c3f1cb38498e0003f11b8f7e3bcf1"
REF_TREE="684f1e2889b6992e5aedc88f52bb45f4558bb3e4"

def git(*args):
    return subprocess.check_output(["git",*args],cwd=ROOT,text=True).strip()

meta=json.loads((ROOT/"release/pub-gc-gmd/PUB_GC_GMD_UNVERSIONED_CANDIDATE.json").read_text())
delta=json.loads((ROOT/"release/pub-gc-gmd/PUB_GC_GMD_RB1_TO_CANDIDATE_DELTA.json").read_text())

assert meta["status"]=="TECHNICAL_CANDIDATE_FROZEN_R1_L1_NOT_AUTHORIZED"
assert meta["final_release_authority"] is False
assert meta["publication_release_identifier"] is None
assert meta["software_license_authority"] is None
assert meta["archive_doi_or_pid"] is None
assert git("rev-parse",f"{SOURCE}^{{tree}}")==TREE
assert git("rev-parse",f"{SOURCE}:src")==SRC_TREE
assert git("rev-parse",f"{SOURCE}:reference")==REF_TREE
assert delta["predecessor"]["release_id"]=="SWAP5-RB1-v1"
assert delta["unversioned_publication_candidate"]["scientific_source_commit"]==SOURCE
assert delta["src"]["added_count"]==127
assert delta["src"]["modified_count"]==23
assert delta["src"]["deleted_count"]==0
assert delta["reference"]["added_count"]==3
assert delta["reference"]["modified_count"]==7
assert delta["reference"]["deleted_count"]==0

for path,blob in meta["critical_publication_blobs"].items():
    assert git("rev-parse",f"{SOURCE}:{path}")==blob,(path,blob)

candidate_head=os.environ.get("PUB_GC_CANDIDATE_HEAD") or git("rev-parse","HEAD")
git("cat-file","-e",candidate_head+"^{commit}")
changed=git("diff","--name-only",SOURCE+".."+candidate_head).splitlines()
allowed_prefixes=("release/pub-gc-gmd/",)
allowed_exact={".github/workflows/pub-gc-gmd-unversioned-candidate.yml",
               "docs/publication/PUB_GC_GMD_GOVERNANCE_DECISION_REQUEST.md"}
bad=[p for p in changed if not p.startswith(allowed_prefixes) and p not in allowed_exact]
assert not bad,bad

paths=git("ls-tree","-r","--name-only",SOURCE).splitlines()
assert not any(p.lower().endswith("swap_4.3.1.zip") for p in paths)

e7=json.loads((ROOT/"docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json").read_text())
assert e7["status"]=="CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT"
assert e7["coupled_execution"]["modflow_e7_windows_executed"]==0

print("PUB_GC_GMD_CANDIDATE_SOURCE_TREE=PASS")
print("PUB_GC_GMD_CANDIDATE_RB1_DELTA=PASS")
print("PUB_GC_GMD_CANDIDATE_CRITICAL_BLOBS=PASS")
print("PUB_GC_GMD_CANDIDATE_METADATA_HEAD="+candidate_head)
print("PUB_GC_GMD_CANDIDATE_METADATA_ONLY_DESCENDANT=PASS")
print("PUB_GC_GMD_CANDIDATE_EXTERNAL_ASSET_NOT_REDISTRIBUTED=PASS")
print("PUB_GC_GMD_CANDIDATE_R1_L1_FAIL_CLOSED=PASS")
print("PUB_GC_GMD_UNVERSIONED_CANDIDATE_GATE=PASS")
