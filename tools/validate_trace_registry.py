#!/usr/bin/env python3
"""Fail-closed integrity checks for the prospective TRACE research registry."""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACE = ROOT / "integration" / "trace"
CASES = TRACE / "cases"

ID_RE = re.compile(r"^TRACE-(SWAP|ANIMO)-[0-9]{4}$")
MODELS = {"SWAP", "ANIMO"}
STATUSES = {"CANDIDATE", "CONFIRMED", "EXCLUDED", "CLOSED", "UNRESOLVED"}
CASE_REQUIRED = {
    "trace_id", "model", "status", "discovery", "eligibility",
    "scientific_element", "representations", "conflict", "detection",
    "scientific_consequence", "regression_counterfactual",
    "resolution", "reproducibility",
}

CANDIDATE_HEADER = [
    "trace_id","model","status","first_observed_date","registered_date","observer",
    "discovering_work_unit","inspection_trigger","planned_or_opportunistic",
    "scientific_element_id","pre_resolution_ref",
    "substantive_discrepancy_known_before_registration",
    "disposition_known_before_registration","prospective_eligible",
    "initial_conflict_statement","evidence_freeze_location",
    "eligibility_decision_date","notes",
]
ELEMENT_HEADER = [
    "scientific_element_id","model","subsystem","element_type","element_description",
    "inspection_start_date","inspection_end_date","inspection_trigger",
    "planned_or_opportunistic","repository_start_ref","repository_end_ref",
    "candidate_trace_ids","confirmed_trace_ids","no_discrepancy_observed","notes",
]
EXCLUSION_HEADER = [
    "trace_id","model","candidate_registered_date","exclusion_date",
    "exclusion_reason","scientific_relevance_assessed","relation_sources_assessed",
    "recoverable_pre_resolution_evidence","notes",
]
HISTORICAL_HEADER = [
    "pilot_id","model","original_identifier_or_work_unit",
    "known_before_protocol_freeze","reason_historical","possible_trace_use","notes",
]

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def read_csv(name: str, expected_header: list[str]) -> list[dict[str, str]]:
    path = TRACE / name
    if not path.is_file():
        fail(f"missing required file: {path.relative_to(ROOT)}")
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != expected_header:
            fail(f"{name}: header mismatch: {reader.fieldnames!r}")
        return list(reader)


def parse_bool(value: str, where: str, *, allow_blank: bool = False) -> bool | None:
    normalized = (value or "").strip().lower()
    if allow_blank and not normalized:
        return None
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    fail(f"{where}: expected true/false, got {value!r}")
    return None


def split_ids(value: str) -> list[str]:
    return [x.strip() for x in (value or "").split(";") if x.strip()]


def validate_json_file(path: Path) -> dict | None:
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception as exc:
        fail(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        return None
    if not isinstance(data, dict):
        fail(f"{path.relative_to(ROOT)}: top level must be an object")
        return None
    return data


candidates = read_csv("TRACE_CANDIDATE_REGISTER.csv", CANDIDATE_HEADER)
elements = read_csv("TRACE_SCIENTIFIC_ELEMENT_REGISTER.csv", ELEMENT_HEADER)
exclusions = read_csv("TRACE_EXCLUSION_LOG.csv", EXCLUSION_HEADER)
historical = read_csv("TRACE_HISTORICAL_PILOT_REGISTER.csv", HISTORICAL_HEADER)

candidate_by_id: dict[str, dict[str, str]] = {}
for rownum, row in enumerate(candidates, start=2):
    where = f"TRACE_CANDIDATE_REGISTER.csv:{rownum}"
    trace_id = row["trace_id"].strip()
    model = row["model"].strip()
    status = row["status"].strip()

    if not ID_RE.fullmatch(trace_id):
        fail(f"{where}: invalid trace_id {trace_id!r}")
    if trace_id in candidate_by_id:
        fail(f"{where}: duplicate trace_id {trace_id}")
    candidate_by_id[trace_id] = row

    if model not in MODELS:
        fail(f"{where}: invalid model {model!r}")
    match = ID_RE.fullmatch(trace_id)
    if match and model in MODELS and match.group(1) != model:
        fail(f"{where}: trace_id prefix does not match model")
    if status not in STATUSES:
        fail(f"{where}: invalid status {status!r}")

    for field in ("first_observed_date","registered_date","observer",
                  "scientific_element_id","initial_conflict_statement"):
        if not row[field].strip():
            fail(f"{where}: required field {field} is blank")

    known = parse_bool(
        row["substantive_discrepancy_known_before_registration"],
        f"{where}:substantive_discrepancy_known_before_registration",
    )
    disposition_known = parse_bool(
        row["disposition_known_before_registration"],
        f"{where}:disposition_known_before_registration",
    )
    prospective = parse_bool(
        row["prospective_eligible"], f"{where}:prospective_eligible"
    )

    if prospective is True:
        if known is not False or disposition_known is not False:
            fail(f"{where}: prospective case cannot have pre-known discrepancy/disposition")
        if not row["pre_resolution_ref"].strip():
            fail(f"{where}: prospective case requires pre_resolution_ref")
        if not row["evidence_freeze_location"].strip():
            fail(f"{where}: prospective case requires evidence_freeze_location")

    if status in {"CONFIRMED", "CLOSED", "UNRESOLVED"}:
        case_path = CASES / f"{trace_id}.json"
        if not case_path.is_file():
            fail(f"{where}: {status} case missing {case_path.relative_to(ROOT)}")
        else:
            data = validate_json_file(case_path)
            if data is not None:
                missing = sorted(CASE_REQUIRED - set(data))
                if missing:
                    fail(f"{case_path.relative_to(ROOT)}: missing top-level fields {missing}")
                if data.get("trace_id") != trace_id:
                    fail(f"{case_path.relative_to(ROOT)}: trace_id mismatch")
                if data.get("model") != model:
                    fail(f"{case_path.relative_to(ROOT)}: model mismatch")
                eligibility = data.get("eligibility")
                if isinstance(eligibility, dict):
                    if prospective is not None and eligibility.get("prospective_eligible") != prospective:
                        fail(f"{case_path.relative_to(ROOT)}: eligibility disagrees with register")

element_ids: set[str] = set()
for rownum, row in enumerate(elements, start=2):
    where = f"TRACE_SCIENTIFIC_ELEMENT_REGISTER.csv:{rownum}"
    element_id = row["scientific_element_id"].strip()
    if not element_id:
        fail(f"{where}: scientific_element_id is blank")
    if element_id in element_ids:
        fail(f"{where}: duplicate scientific_element_id {element_id}")
    element_ids.add(element_id)
    if row["model"].strip() not in MODELS:
        fail(f"{where}: invalid model {row['model']!r}")
    parse_bool(row["no_discrepancy_observed"], f"{where}:no_discrepancy_observed", allow_blank=True)
    for trace_id in split_ids(row["candidate_trace_ids"]) + split_ids(row["confirmed_trace_ids"]):
        if trace_id not in candidate_by_id:
            fail(f"{where}: references unknown candidate {trace_id}")

for trace_id, row in candidate_by_id.items():
    element_id = row["scientific_element_id"].strip()
    if element_id and element_id not in element_ids:
        fail(f"candidate {trace_id}: scientific element {element_id} not registered")

excluded_ids: set[str] = set()
for rownum, row in enumerate(exclusions, start=2):
    where = f"TRACE_EXCLUSION_LOG.csv:{rownum}"
    trace_id = row["trace_id"].strip()
    if trace_id in excluded_ids:
        fail(f"{where}: duplicate exclusion for {trace_id}")
    excluded_ids.add(trace_id)
    if trace_id not in candidate_by_id:
        fail(f"{where}: exclusion references unknown candidate {trace_id}")
    elif candidate_by_id[trace_id]["status"].strip() != "EXCLUDED":
        fail(f"{where}: candidate {trace_id} is not marked EXCLUDED")
    if not row["exclusion_reason"].strip():
        fail(f"{where}: exclusion_reason is blank")

for trace_id, row in candidate_by_id.items():
    if row["status"].strip() == "EXCLUDED" and trace_id not in excluded_ids:
        fail(f"candidate {trace_id}: EXCLUDED but absent from exclusion log")

pilot_ids: set[str] = set()
for rownum, row in enumerate(historical, start=2):
    where = f"TRACE_HISTORICAL_PILOT_REGISTER.csv:{rownum}"
    pilot_id = row["pilot_id"].strip()
    if not pilot_id:
        fail(f"{where}: pilot_id is blank")
    if pilot_id in pilot_ids:
        fail(f"{where}: duplicate pilot_id {pilot_id}")
    pilot_ids.add(pilot_id)
    if row["model"].strip() not in MODELS:
        fail(f"{where}: invalid model {row['model']!r}")
    known = parse_bool(
        row["known_before_protocol_freeze"],
        f"{where}:known_before_protocol_freeze",
    )
    if known is not True:
        fail(f"{where}: historical/pilot row must be known_before_protocol_freeze=true")

for name in ("TRACE_CASE_SCHEMA.json", "TRACE_CASE_TEMPLATE.json", "TRACE_EVIDENCE_MANIFEST_TEMPLATE.json"):
    path = TRACE / name
    if not path.is_file():
        fail(f"missing required file: {path.relative_to(ROOT)}")
    else:
        validate_json_file(path)

if CASES.is_dir():
    for path in sorted(CASES.glob("TRACE-*.json")):
        trace_id = path.stem
        if trace_id not in candidate_by_id:
            fail(f"{path.relative_to(ROOT)}: case file has no candidate-register row")

if errors:
    print("TRACE registry integrity: FAIL", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    raise SystemExit(1)

print(
    "TRACE registry integrity: PASS "
    f"({len(candidates)} candidates, {len(elements)} scientific elements, "
    f"{len(exclusions)} exclusions, {len(historical)} historical/pilot rows)"
)
