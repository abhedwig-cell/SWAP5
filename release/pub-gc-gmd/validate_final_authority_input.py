#!/usr/bin/env python3
from __future__ import annotations
import json
from datetime import date
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/"release/pub-gc-gmd/PUB_GC_GMD_FINAL_AUTHORITY_INPUT.json"
C=ROOT/"release/pub-gc-gmd/PUB_GC_GMD_UNVERSIONED_CANDIDATE.json"
L=ROOT/"docs/publication/PUB_GC_GMD_LICENSE_EXTERNAL_EVIDENCE.json"

a=json.loads(P.read_text(encoding="utf-8"))
c=json.loads(C.read_text(encoding="utf-8"))
l=json.loads(L.read_text(encoding="utf-8"))

EXPECTED_COMMIT="781c829943c9e5880e5ab83281112e66f439ecf2"
EXPECTED_TREE="9ca065553765e38eec4d4ceb611ec80d866dbae3"
EXPECTED_SRC="573df94cbb1c3f1cb38498e0003f11b8f7e3bcf1"
EXPECTED_REF="684f1e2889b6992e5aedc88f52bb45f4558bb3e4"
EXTERNAL_SHA="2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"

b=a["candidate_binding"]
assert b["scientific_source_commit"]==EXPECTED_COMMIT
assert b["scientific_source_tree"]==EXPECTED_TREE
assert b["src_tree"]==EXPECTED_SRC
assert b["reference_tree"]==EXPECTED_REF
assert b["predecessor_release"]=="SWAP5-RB1-v1"
assert c["scientific_source_authority"]["tree"]==EXPECTED_TREE
assert c["publication_release_identifier"] is None
assert l["status"]=="UPSTREAM_SW4_GPLV2_CONFIRMED_SWAP5_DECLARATION_AUTHORITY_REQUIRED"
assert a["external_reference_asset"]["sha256"]==EXTERNAL_SHA
assert a["external_reference_asset"]["redistributed_in_publication_archive"] is False

state=a["state"]
assert state in {"AWAITING_R1_L1_AUTHORITY","AUTHORIZED_FOR_PUBLIC_ARCHIVE"}

if state=="AWAITING_R1_L1_AUTHORITY":
    assert a["R1"]["publication_release_identifier"] is None
    assert a["L1"]["software_license_expression"] is None
    assert a["L1"]["publication_archive_redistribution_statement"] is None
    assert a["L1"]["public_archive_redistribution_authorized"] is None
    assert a["A3"]["persistent_archive_doi_or_pid"] is None
    print("PUB_GC_GMD_AUTHORITY_TEMPLATE_CANDIDATE_BINDING=PASS")
    print("PUB_GC_GMD_AUTHORITY_TEMPLATE_FAIL_CLOSED=PASS")
    print("PUB_GC_GMD_AUTHORITY_STATE=AWAITING_R1_L1_AUTHORITY")
else:
    r1=a["R1"]; l1=a["L1"]; ext=a["external_reference_asset"]
    required_r1=["publication_release_identifier","authority_name_or_role","governing_record","effective_date"]
    required_l1=["software_license_expression","publication_archive_redistribution_statement",
                 "authority_name_or_role","governing_record","effective_date"]
    assert all(isinstance(r1[k],str) and r1[k].strip() for k in required_r1)
    assert all(isinstance(l1[k],str) and l1[k].strip() for k in required_l1)
    assert r1["publication_release_identifier"]!="SWAP5-RB1-v1"
    assert l1["public_archive_redistribution_authorized"] is True
    assert isinstance(ext["reviewer_access_statement"],str) and ext["reviewer_access_statement"].strip()
    assert isinstance(ext["reviewer_access_authority"],str) and ext["reviewer_access_authority"].strip()
    # DOI remains null until the external archive action has actually completed.
    assert a["A3"]["persistent_archive_doi_or_pid"] is None
    print("PUB_GC_GMD_R1_AUTHORITY=PASS")
    print("PUB_GC_GMD_L1_AUTHORITY=PASS")
    print("PUB_GC_GMD_EXTERNAL_REFERENCE_ACCESS_WORDING=PASS")
    print("PUB_GC_GMD_AUTHORITY_STATE=AUTHORIZED_FOR_PUBLIC_ARCHIVE")
    print("PUB_GC_GMD_NEXT_ACTION=CREATE_PERSISTENT_ARCHIVE_AND_BIND_A3")
