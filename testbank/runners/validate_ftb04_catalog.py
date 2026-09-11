#!/usr/bin/env python3
import csv, json, re, subprocess
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
CAT=ROOT/"testbank/manifests/F-TB04_CASE_CATALOG.tsv"
CONTRACT=ROOT/"integration/f-tb/F-TB04_WORK_UNIT_CONTRACT.json"
CANONICAL="0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
FTB03="65d5e5202446212390dbdd84b06e6b2a80e7121c"
REQ={3,4,5,6,7,8,9,13,16,23,24,26,27,29,30}
VALID_PROFILES={"FAST","CANONICAL","RELEASE","DEEP"}
VALID_DET={"BIT_IDENTITY_REQUIRED","NUMERICAL_EQUIVALENCE_REQUIRED"}
ID=re.compile(r"^SWAP5-TB-(TXN|RST|DET|MSW)-[A-Z0-9]+-\d{4}-v1$")
EXPECTED_DOMAINS=Counter({"TRANSACTION":10,"RESTART":9,"DETERMINISM":6,"MULTISWAP":10})
EXPECTED_PROFILES={"FAST":9,"CANONICAL":18,"RELEASE":34,"DEEP":35}
TOLS={
 "EXACT":(0.0,"exact"),
 "MASS1E-12_INHERITED":(1.0e-12,"inherited"),
 "SEMANTIC_MASS1E-12_INHERITED":(1.0e-12,"inherited"),
}

def fail(s): raise SystemExit("FTB04_CATALOG_FAIL:"+s)
def git(*a): return subprocess.check_output(["git",*a],cwd=ROOT,text=True).strip()

contract=json.loads(CONTRACT.read_text())
if contract["authorities"]["current_canonical"]!=CANONICAL or contract["authorities"]["F-TB03"]!=FTB03:
    fail("authority drift")
for k in ("production_source_changes","new_physics","new_solver","scientific_tolerance_relaxation","RB1_reopened","historical_RB1_evidence_rewritten"):
    if contract["hard_scope"].get(k) is not False: fail("hard scope "+k)

with CAT.open(newline="",encoding="utf-8") as f:
    rows=list(csv.DictReader(f,delimiter="\t"))
if len(rows)!=35: fail("case count")
if len({r["case_id"] for r in rows})!=35: fail("duplicate id")
if Counter(r["domain"] for r in rows)!=EXPECTED_DOMAINS: fail("domain counts")
covered=set(); det=set()
for r in rows:
    if not ID.match(r["case_id"]): fail("unstable id "+r["case_id"])
    if any(not r[k] for k in ("title","purpose","invariants","oracle","fixture","tolerance","determinism","profiles","cost","lineage")):
        fail("empty required field "+r["case_id"])
    try: inv={int(x) for x in r["invariants"].split(",")}
    except ValueError: fail("invalid invariant "+r["case_id"])
    covered|=inv
    if r["determinism"] not in VALID_DET: fail("determinism "+r["case_id"])
    det.add(r["determinism"])
    p=set(r["profiles"].split(","))
    if not p or not p<=VALID_PROFILES: fail("profile "+r["case_id"])
    if r["cost"]=="LARGE" and "FAST" in p: fail("large case in FAST "+r["case_id"])
    if r["tolerance"] not in TOLS: fail("tolerance binding "+r["case_id"])
    value,provenance=TOLS[r["tolerance"]]
    if value!=0.0 and provenance!="inherited": fail("unqualified tolerance "+r["case_id"])
    if "@" not in r["lineage"] and not r["lineage"].startswith("tests/fci/run_fci21_"):
        fail("unversioned lineage "+r["case_id"])
if not REQ<=covered: fail("invariant mapping")
if det!=VALID_DET: fail("determinism classes")
pc={p:sum(p in r["profiles"].split(",") for r in rows) for p in VALID_PROFILES}
if pc!=EXPECTED_PROFILES: fail("profile counts "+repr(pc))
required={
"SWAP5-TB-TXN-STALE-0010-v1","SWAP5-TB-RST-SCHEMA-0014-v1","SWAP5-TB-RST-LAYOUT-0015-v1",
"SWAP5-TB-RST-TEMPLATE-0016-v1","SWAP5-TB-RST-PARAM-0017-v1","SWAP5-TB-RST-CORRUPT-0018-v1",
"SWAP5-TB-MSW-HETPARAM-0030-v1","SWAP5-TB-MSW-SCRATCH-0033-v1","SWAP5-TB-MSW-OPTIONAL-0035-v1"}
if not required<={r["case_id"] for r in rows}: fail("mandatory cases")

# Executable immutability conditions.
if git("rev-parse",CANONICAL+":src")!=git("rev-parse","HEAD:src"): fail("production source drift")
if git("rev-parse",FTB03+":testbank/rb1")!=git("rev-parse","HEAD:testbank/rb1"): fail("RB1 drift")
locks={
"testbank/manifests/F-TB01_CASE_REGISTRY.json":"4b4fcaa20e09a915428e459922d7b6b2a6a381b7",
"testbank/manifests/F-TB02_HYDRAULIC_CASE_REGISTRY.json":"f5cc721b98bd8167fd14b6218193526807f9c3b6",
"testbank/manifests/F-TB03_RB1_RELEASE_BANK.json":"afa0275b3d20856eb1e310e90186e5ee8e8f0a66"}
for path,blob in locks.items():
    if git("rev-parse","HEAD:"+path)!=blob: fail("prior authority drift "+path)

print("FTB04_CATALOG_SCHEMA=PASS")
print("FTB04_STABLE_CASE_IDS=PASS COUNT=35")
print("FTB04_DOMAIN_COUNTS=PASS TXN=10 RST=9 DET=6 MSW=10")
print("FTB04_PROFILE_COUNTS=PASS FAST=9 CANONICAL=18 RELEASE=34 DEEP=35")
print("FTB04_INVARIANT_MAPPING=PASS "+",".join(map(str,sorted(REQ))))
print("FTB04_DETERMINISM_CLASSES=PASS BIT_IDENTITY_REQUIRED,NUMERICAL_EQUIVALENCE_REQUIRED")
print("FTB04_TOLERANCE_PROVENANCE=PASS NO_NEW_NONZERO_TOLERANCE")
print("FTB04_CURRENT_CANONICAL_SRC_IMMUTABLE=PASS")
print("FTB04_RB1_ARCHIVE_IMMUTABLE=PASS")
print("FTB04_PRIOR_TESTBANK_AUTHORITIES_IMMUTABLE=PASS")
