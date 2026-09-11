#!/usr/bin/env python3
"""Fail-closed validator for the F-TB01 proof-of-concept registry.

F-TB01 validates testbank architecture and registry mechanics. It does not
re-execute or reinterpret scientific conclusions owned by registered workunits.
"""

from __future__ import annotations
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "testbank/manifests/F-TB01_CASE_REGISTRY.json"
REGISTRY_SCHEMA = ROOT / "testbank/schema/F-TB01_CASE_REGISTRY.schema.json"
REPORT_SCHEMA = ROOT / "testbank/schema/F-TB01_REPORT.schema.json"
STATUS = ROOT / "integration/f-tb/F-TB01_STATUS.json"
AUDIT = ROOT / "integration/f-tb/F-TB01_INVARIANT_AUDIT.json"

FROZEN_COMMIT = "3c5f5bd3686e1632058b906be21abd73883e30ef"
FROZEN_TREE = "6baaf40271497db831698c5a01de355b5d296dbe"
EXIT_TARGET = "SWAP5_TESTBANK_ARCHITECTURE_AND_CASE_REGISTRY_READY_FOR_INCREMENTAL_IMPLEMENTATION"
SHA40 = re.compile(r"^[0-9a-f]{40}$")
CASE_ID = re.compile(r"^SWAP5-TB-[A-Z0-9_-]+-[0-9]{3,5}-v([1-9][0-9]*)$")
LEVELS = {f"TB-L{i}" for i in range(13)}
PROFILES = {"FAST", "CANONICAL", "RELEASE", "DEEP"}
CATEGORIES = {"PRIMITIVE","HYDRAULICS","PROCESS","SOLVER","TRANSACTION","RESTART",
              "INTEGRATED","LEGACY_REFERENCE","COUPLING","MULTISWAP","PERFORMANCE",
              "ROBUSTNESS","RELEASE"}
ARTIFACT_KINDS = {"SOURCE_TEST","QUALIFICATION_EVIDENCE","GOVERNANCE_REPLAY"}
PURPOSES = {"HISTORICAL_QUALIFICATION","MOVING_CURRENT_PRESERVATION",
            "BROAD_RELEASE_REGRESSION","OWNER_VERIFICATION","CHARACTERIZATION"}
MATURITY = {"CHARACTERIZATION","OWNER_TESTED","INDEPENDENTLY_QUALIFIED",
            "CANONICAL_PRESERVATION","RELEASE_MANDATORY"}
ORACLES = {"O1_MATHEMATICAL_EXACT","O2_MANUFACTURED_SOLUTION",
           "O3_INDEPENDENT_NUMERICAL_REFERENCE","O4_QUALIFIED_FULL_RICHARDS_REFERENCE",
           "O5_LEGACY_SWAP431_SOURCE_BOUND","O6_PROPERTY_INVARIANT",
           "O7_CROSS_SOLVER_CONSISTENCY"}
MASS_GATES = {"REQUIRED","NOT_WATER_BEARING","INHERITED_EXACT_AUTHORITY"}
COST = {"TINY","SMALL","MEDIUM","LARGE","EXTERNAL_LONG_RUNNING"}
TOL_MODES = {"EXACT_OR_HARD_ONLY","INHERITED_PINNED_AUTHORITY","GOVERNED_BINDINGS"}
TOL_CLASSES = {"FP_IDENTITY","NUMERICAL_SOLVER","SCIENTIFIC_COMPARISON","APPLICATION","COUPLING"}
REQUIRED_CASE_KEYS = {
    "case_id","version","title","layer","category","artifact_kind","physics","solver",
    "parameters","forcing","initial_state","interval","oracle","tolerance_policy",
    "provenance","source_authority","test_matrix_authority","evidence_authority",
    "governance_authority","admission_purpose","maturity","compiler_requirements",
    "cost_class","profiles","requiredness","invariants","negative_paths","mass_gate",
    "current_preservation_eligible","lineage","notes"
}

def load(p):
    with p.open("r", encoding="utf-8") as h:
        return json.load(h)

def fail(msg):
    raise SystemExit(f"F-TB01 VALIDATION FAIL: {msg}")

def exact_keys(obj, keys, label):
    if not isinstance(obj, dict) or set(obj) != set(keys):
        fail(f"{label}: keys mismatch")

registry = load(REGISTRY)
schema = load(REGISTRY_SCHEMA)
report_schema = load(REPORT_SCHEMA)
status = load(STATUS)
audit = load(AUDIT)

if schema.get("properties",{}).get("schema_version",{}).get("const") != "1.1": fail("registry schema version contract drift")
if registry.get("schema_version") != "1.1": fail("registry schema version must be 1.1")
if report_schema.get("properties",{}).get("schema_version",{}).get("const") != "swap5.testbank.report.v1.1": fail("report schema version contract drift")
src = registry.get("source_authority",{})
if src != {"repository":"abhedwig-cell/SWAP5","ref":"integration/f-ci-canonical","commit":FROZEN_COMMIT,"tree":FROZEN_TREE}: fail("frozen source authority drift")
if status.get("exit_target") != EXIT_TARGET: fail("exit target drift")
for key in ("production_source_changed","existing_test_changed","qualified_reference_changed","physics_changed","solver_policy_changed","runtime_semantics_changed","io_adapter_changed"):
    if status.get("scope_holds",{}).get(key) is not False: fail(f"scope hold is not explicitly false: {key}")
items = audit.get("items",[])
if audit.get("overall") != "30_OF_30_NO_ADVERSE_DELTA" or len(items) != 30: fail("architecture invariant audit incomplete")
if {x.get("id") for x in items} != set(range(1,31)) or any(x.get("result") != "PASS" for x in items): fail("architecture invariant audit must be exactly 1..30 PASS")
if audit.get("mass_conservation") != "HARD_UNCHANGED": fail("hard mass-conservation audit drift")

cases = registry.get("cases")
if not isinstance(cases,list) or not (5 <= len(cases) <= 10): fail("proof-of-concept registry must contain 5..10 cases")
seen=set(); layers=set(); resolved=0
for c in cases:
    if set(c) != REQUIRED_CASE_KEYS: fail(f"{c.get('case_id','<unknown>')}: rich case metadata incomplete")
    cid=c["case_id"]; m=CASE_ID.fullmatch(cid)
    if not m or int(m.group(1)) != c["version"]: fail(f"{cid}: stable ID suffix must equal numeric version")
    if cid in seen: fail(f"duplicate case id: {cid}")
    seen.add(cid)
    if c["layer"] not in LEVELS: fail(f"{cid}: invalid layer")
    layers.add(c["layer"])
    if c["category"] not in CATEGORIES: fail(f"{cid}: invalid category")
    if c["artifact_kind"] not in ARTIFACT_KINDS: fail(f"{cid}: invalid artifact kind")
    if c["admission_purpose"] not in PURPOSES: fail(f"{cid}: invalid admission purpose")
    if c["maturity"] not in MATURITY: fail(f"{cid}: invalid maturity")
    if c["cost_class"] not in COST: fail(f"{cid}: invalid cost class")
    if not isinstance(c["physics"],list) or not c["physics"] or any(not isinstance(x,str) or not x.strip() for x in c["physics"]): fail(f"{cid}: physics must be explicit")
    if not isinstance(c["solver"],str) or not c["solver"].strip(): fail(f"{cid}: solver must be explicit")
    for key in ("parameters","forcing","initial_state"):
        exact_keys(c[key], {"identity","authority_ref"}, f"{cid}:{key}")
        if not all(isinstance(c[key][x],str) and c[key][x].strip() for x in ("identity","authority_ref")): fail(f"{cid}:{key}: empty identity binding")
    exact_keys(c["interval"], {"t0","t1","time_basis","calendar_required"}, f"{cid}:interval")
    if not isinstance(c["interval"]["calendar_required"],bool): fail(f"{cid}: calendar_required must be boolean")
    if not all(isinstance(c["interval"][x],str) and c["interval"][x].strip() for x in ("t0","t1","time_basis")): fail(f"{cid}: interval identity incomplete")
    exact_keys(c["oracle"], {"class","id","version","authority_ref"}, f"{cid}:oracle")
    if c["oracle"]["class"] not in ORACLES or not isinstance(c["oracle"]["version"],int) or c["oracle"]["version"] < 1: fail(f"{cid}: invalid oracle binding")
    if not c["oracle"]["id"] or not c["oracle"]["authority_ref"]: fail(f"{cid}: empty oracle authority")
    exact_keys(c["tolerance_policy"], {"mode","bindings","inheritance_authority"}, f"{cid}:tolerance")
    tp=c["tolerance_policy"]; mode=tp["mode"]
    if mode not in TOL_MODES or not isinstance(tp["bindings"],list): fail(f"{cid}: invalid tolerance mode")
    if mode == "GOVERNED_BINDINGS":
        if not tp["bindings"] or tp["inheritance_authority"] is not None: fail(f"{cid}: governed tolerances require bindings and no inherited authority")
        for b in tp["bindings"]:
            keys={"id","version","class","quantity","unit","meaning","scope","rationale","provenance","owner","evidence"}; exact_keys(b,keys,f"{cid}:tolerance binding")
            if b["class"] not in TOL_CLASSES or not isinstance(b["version"],int) or b["version"] < 1: fail(f"{cid}: invalid governed tolerance")
            if any(not isinstance(b[k],str) or not b[k].strip() for k in keys-{"version"}): fail(f"{cid}: governed tolerance metadata incomplete")
    elif mode == "INHERITED_PINNED_AUTHORITY":
        if tp["bindings"] or not isinstance(tp["inheritance_authority"],str) or not tp["inheritance_authority"].strip(): fail(f"{cid}: inherited tolerance requires named pinned authority and no fabricated local bindings")
        if c["maturity"] == "RELEASE_MANDATORY": fail(f"{cid}: inherited tolerance binding cannot itself promote a case to RELEASE_MANDATORY")
    else:
        if tp["bindings"] or tp["inheritance_authority"] is not None: fail(f"{cid}: exact/hard-only tolerance mode cannot carry soft tolerance bindings")
    exact_keys(c["provenance"], {"primary_path","registration_basis"}, f"{cid}:provenance")
    sa=c["source_authority"]; exact_keys(sa, {"repository","ref","commit","tree","path"}, f"{cid}:source authority")
    if sa["repository"] != "abhedwig-cell/SWAP5" or sa["ref"] != "integration/f-ci-canonical" or sa["commit"] != FROZEN_COMMIT or sa["tree"] != FROZEN_TREE: fail(f"{cid}: source authority is not exact F-TB01 frozen authority")
    if sa["path"] != c["provenance"]["primary_path"]: fail(f"{cid}: provenance path/source path mismatch")
    rel=pathlib.PurePosixPath(sa["path"])
    if rel.is_absolute() or ".." in rel.parts: fail(f"{cid}: unsafe primary path")
    if not ROOT.joinpath(*rel.parts).is_file(): fail(f"{cid}: registered primary asset does not exist: {sa['path']}")
    resolved += 1
    for key in ("test_matrix_authority","evidence_authority","governance_authority"):
        exact_keys(c[key], {"kind","reference","requalified_by_ftb01"}, f"{cid}:{key}")
        if not isinstance(c[key]["requalified_by_ftb01"],bool) or not c[key]["kind"] or not c[key]["reference"]: fail(f"{cid}:{key}: incomplete authority binding")
    exact_keys(c["compiler_requirements"], {"requirement","platform_scope"}, f"{cid}:compiler")
    if not c["compiler_requirements"]["requirement"] or not c["compiler_requirements"]["platform_scope"]: fail(f"{cid}: compiler requirements incomplete")
    p=c["profiles"]
    if not isinstance(p,list) or not p or len(p)!=len(set(p)) or not set(p)<=PROFILES: fail(f"{cid}: invalid profiles")
    exact_keys(c["requiredness"], {"mandatory_profiles","optional_profiles"}, f"{cid}:requiredness")
    mand=set(c["requiredness"]["mandatory_profiles"]); opt=set(c["requiredness"]["optional_profiles"])
    if mand & opt or mand|opt != set(p): fail(f"{cid}: mandatory/optional profile classification incomplete")
    inv=c["invariants"]
    if not isinstance(inv,list) or not inv or len(inv)!=len(set(inv)) or any(not isinstance(i,int) or i<1 or i>30 for i in inv): fail(f"{cid}: invalid invariant bindings")
    if not isinstance(c["negative_paths"],list) or len(c["negative_paths"]) != len(set(c["negative_paths"])): fail(f"{cid}: invalid negative paths")
    if c["mass_gate"] not in MASS_GATES: fail(f"{cid}: invalid mass gate")
    if not isinstance(c["current_preservation_eligible"],bool): fail(f"{cid}: preservation eligibility must be boolean")
    exact_keys(c["lineage"], {"predecessor","evidence_disposition"}, f"{cid}:lineage")
    if c["lineage"]["predecessor"] is not None and not isinstance(c["lineage"]["predecessor"],str): fail(f"{cid}: invalid predecessor")
    if not isinstance(c["lineage"]["evidence_disposition"],str) or not c["lineage"]["evidence_disposition"].strip(): fail(f"{cid}: missing evidence disposition")

if len(layers) < 5: fail("proof-of-concept must span at least five layers")
if not any(c["mass_gate"]=="REQUIRED" for c in cases): fail("prototype has no hard water-mass case")
if not any(c["negative_paths"] for c in cases): fail("prototype has no negative-path mapping")
if not any(c["admission_purpose"]=="BROAD_RELEASE_REGRESSION" for c in cases): fail("prototype has no broad release regression")
if not any(c["tolerance_policy"]["mode"]=="INHERITED_PINNED_AUTHORITY" for c in cases): fail("prototype does not demonstrate inherited pinned tolerance semantics")

print(f"F-TB01_REGISTRY_CASES={len(seen)}")
print(f"F-TB01_REGISTRY_LAYERS={len(layers)}")
print(f"F-TB01_REGISTERED_PRIMARY_ASSETS_RESOLVED={resolved}/{len(seen)}")
print("F-TB01_REQUIRED_CASE_METADATA=PASS")
print("F-TB01_AUTHORITY_SEPARATION=PASS")
print("F-TB01_TOLERANCE_BINDING_SEMANTICS=PASS")
print("F-TB01_CASE_REGISTRY_SCHEMA_CONTRACT=PASS")
print("F-TB01_REPORT_SCHEMA_JSON=PASS")
print("F-TB01_INVARIANT_AUDIT=30/30_PASS")
print("F-TB01_HARD_MASS_POLICY=PASS")
print("F-TB01_GATE=PASS")
