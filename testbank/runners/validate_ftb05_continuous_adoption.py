#!/usr/bin/env python3
import csv, json, subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "integration/f-tb/F-TB05_WORK_UNIT_CONTRACT.json"
CATALOG = ROOT / "testbank/manifests/F-TB04_CASE_CATALOG.tsv"
CANONICAL = "d201904a85f3b595e028242978e52c02f5122a09"
CANONICAL_SRC = "d6f4816be543044b090d11294808b5be986b2ee8"
CANONICAL_REF = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
FTB04 = "85280c6c436a73c211b70996f9a22f4ad6b04f9c"
EXPECTED_DOMAINS = Counter({"TRANSACTION":10,"RESTART":9,"DETERMINISM":6,"MULTISWAP":10})
EXPECTED_PROFILES = {"FAST":9,"CANONICAL":18,"RELEASE":34,"DEEP":35}


def fail(msg):
    raise SystemExit("FTB05_ADOPTION_FAIL:" + msg)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

contract = json.loads(CONTRACT.read_text())
auth = contract["authorities"]
if auth["current_canonical"] != CANONICAL or auth["F-TB04_closeout"] != FTB04:
    fail("authority drift")
if auth["current_canonical_src_tree"] != CANONICAL_SRC or auth["current_canonical_reference_tree"] != CANONICAL_REF:
    fail("tree authority drift")
for key in ("production_source_changes","reference_changes","new_physics","new_solver","scientific_tolerance_relaxation","F-TB04_case_catalog_rewrite","RB1_reopened"):
    if contract["hard_scope"].get(key) is not False:
        fail("hard scope " + key)

if git("rev-parse", CANONICAL + ":src") != CANONICAL_SRC or git("rev-parse", "HEAD:src") != CANONICAL_SRC:
    fail("current canonical source mismatch")
if git("rev-parse", CANONICAL + ":reference") != CANONICAL_REF or git("rev-parse", "HEAD:reference") != CANONICAL_REF:
    fail("current canonical reference mismatch")

# F-TB04 remains historical authority. F-TB05 may add its own files, but may
# not rewrite the permanent F-TB04 bank or closeout evidence it adopts.
immutable_paths = [
    "testbank/manifests/F-TB04_CASE_CATALOG.tsv",
    "testbank/runners/validate_ftb04_catalog.py",
    "testbank/runners/run_ftb04_current_canonical_replays.sh",
    "testbank/runners/run_ftb04_qualification.sh",
    "integration/f-tb/F-TB04_WORK_UNIT_CONTRACT.json",
    "integration/f-tb/F-TB04_QUALIFICATION_STATUS.json",
    "integration/f-tb/F-TB04_INVARIANT_AUDIT.json",
    "docs/testbank/F-TB04_TRANSACTION_RESTART_DETERMINISM_MULTISWAP_CASE_CATALOG.md",
]
for path in immutable_paths:
    if git("rev-parse", "HEAD:" + path) != git("rev-parse", FTB04 + ":" + path):
        fail("F-TB04 historical artifact drift " + path)

with CATALOG.open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))
if len(rows) != 35:
    fail("catalog case count")
if Counter(r["domain"] for r in rows) != EXPECTED_DOMAINS:
    fail("catalog domain counts")
profile_counts = {p: sum(p in r["profiles"].split(",") for r in rows) for p in EXPECTED_PROFILES}
if profile_counts != EXPECTED_PROFILES:
    fail("catalog profile counts")

# New F-CI43 soil-temperature source is present in the later canonical, but
# F-TB05 makes no restart/MultiSWAP persistence claim for that capability.
for path in ("src/process/mod_soil_temperature_contract.f90", "src/process/mod_restricted_soil_temperature.f90"):
    try:
        git("rev-parse", "HEAD:" + path)
    except subprocess.CalledProcessError:
        fail("expected F-CI43 canonical source missing " + path)

print("FTB05_CURRENT_CANONICAL_AUTHORITY=PASS:" + CANONICAL)
print("FTB05_CURRENT_CANONICAL_SOURCE_TREE=PASS:" + CANONICAL_SRC)
print("FTB05_CURRENT_CANONICAL_REFERENCE_TREE=PASS:" + CANONICAL_REF)
print("FTB05_FTB04_HISTORICAL_AUTHORITY_IMMUTABLE=PASS:" + FTB04)
print("FTB05_FTB04_CASE_CATALOG_BYTE_IDENTITY=PASS:COUNT=35")
print("FTB05_SOIL_TEMPERATURE_NONCLAIM_BOUNDARY=PASS")
