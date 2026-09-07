#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASELINE = ROOT / "integration/f-si/F-SI01_BASELINE.json"
CONTRACT = ROOT / "integration/f-si/F-SI01_SOLVER_INTERFACE_CONTRACT.json"

ALLOWED_CLASSES = {
    "immutable/shared parameter",
    "committed physical state",
    "worker scratch",
    "reconstructible intermediate",
    "legacy compatibility state",
    "unresolved",
}
REQUIRED_TESTS = {f"FSI01-T{i:02d}" for i in range(1, 12)}
REQUIRED_INVARIANTS = {"1", "3", "4", "5", "6", "13", "14", "16", "20", "21", "22", "23", "24", "25", "26", "27"}


def fail(message: str) -> None:
    print(f"F-SI01_SOURCE_BOUNDARY_GATE FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def git_blob_sha(path: pathlib.Path) -> str:
    data = path.read_bytes()
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def read_json(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        fail(f"cannot read {path.relative_to(ROOT)}: {exc}")


def source_texts() -> dict[pathlib.Path, str]:
    result = {}
    for path in ROOT.glob("src/**/*.f90"):
        result[path] = path.read_text(errors="strict").lower()
    return result


def scan_files(texts: dict[pathlib.Path, str], pattern: str) -> set[str]:
    rx = re.compile(pattern, flags=re.IGNORECASE | re.MULTILINE)
    return {
        str(path.relative_to(ROOT)).replace("\\", "/")
        for path, text in texts.items()
        if rx.search(text)
    }


baseline = read_json(BASELINE)
contract = read_json(CONTRACT)

if baseline.get("work_unit") != "F-SI01":
    fail("baseline work_unit is not F-SI01")
if baseline["source_binding"]["fci18_canonical_closeout_head"] != "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab":
    fail("wrong canonical closeout binding")
if baseline["source_binding"]["qualified_production_source_head"] != "da5026d8b87ad2f3c7912360891839a120ecccb6":
    fail("wrong qualified production-source binding")
if baseline["source_binding"]["production_source_modified_by_fsi01"]:
    fail("F-SI01 must not claim a production source modification")

try:
    subprocess.run(
        ["git", "merge-base", "--is-ancestor", baseline["source_binding"]["fci18_canonical_closeout_head"], "HEAD"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
except (subprocess.CalledProcessError, FileNotFoundError) as exc:
    fail(f"current checkout is not descendant of the pinned canonical closeout head: {exc}")

for item in baseline["source_binding"]["pinned_current_files"]:
    path = ROOT / item["path"]
    if not path.is_file():
        fail(f"missing pinned file {item['path']}")
    observed = git_blob_sha(path)
    if observed != item["blob"]:
        fail(f"pinned file changed unexpectedly: {item['path']} {observed} != {item['blob']}")

for item in baseline["ownership_inventory"]:
    if item.get("classification") not in ALLOWED_CLASSES:
        fail(f"invalid ownership classification {item.get('id')}: {item.get('classification')}")
if not any(item["classification"] == "unresolved" for item in baseline["ownership_inventory"]):
    fail("inventory hides all unresolved ownership questions")

if set(baseline["invariant_assessment"]) != REQUIRED_INVARIANTS:
    fail("invariant assessment does not cover the exact required F-SI01 invariant set")

if {item["id"] for item in baseline["test_matrix"]} != REQUIRED_TESTS:
    fail("test matrix does not contain the exact F-SI01 T01..T11 set")

for evidence in baseline["historical_evidence"]:
    if evidence["provenance"].startswith("handoff-asserted historical"):
        if evidence["exact_git_provenance"] == "unresolved" and evidence["production_source_eligible"]:
            fail(f"unresolved historical evidence marked production-source eligible: {evidence['name']}")

if contract.get("solve_signature") != "solve(request, workspace) -> result":
    fail("common solver signature changed")
if contract["implemented_in_fsi01"]:
    fail("F-SI01 contract incorrectly claims production interface implementation")
if contract["request"]["base_physical_state"]["mutability"] != "read_only":
    fail("base physical state must be read-only at solver boundary")
if contract["workspace"]["persistent_per_logical_column"]:
    fail("worker workspace must not be persistent per logical column")
for forbidden in ("committed physical state", "commit flag", "rollback authority"):
    if forbidden not in contract["workspace"]["must_not_contain"]:
        fail(f"workspace does not forbid {forbidden}")
for key in (
    "solver_may_mutate_committed_input",
    "solver_may_commit",
    "solver_may_rollback",
    "solver_may_define_t0_t1_semantics",
    "solver_may_select_external_numerical_policy",
):
    if contract["transaction_boundary"][key]:
        fail(f"transaction boundary grants forbidden solver authority: {key}")
if not contract["result"]["mass_accounting"]["hard_conservation_required"]:
    fail("hard mass conservation not required")
if "dh_bottom_dq_bottom" not in contract["result"]["interface_sensitivity"]["reserved_fields"]:
    fail("bottom interface sensitivity shape not reserved")

texts = source_texts()
expected_headcalc_callers = {"src/legacy/b1_10_port/soilwater.f90"}
observed_headcalc_callers = scan_files(texts, r"\bcall\s+headcalc\s*\(")
if observed_headcalc_callers != expected_headcalc_callers:
    fail(f"unexpected direct HeadCalc caller set: {sorted(observed_headcalc_callers)}")

expected_ctx_users = {"src/legacy/b1_10_port/headcalc.f90"}
observed_ctx_users = scan_files(texts, r"ctx\s*%\s*headcalc")
if observed_ctx_users != expected_ctx_users:
    fail(f"unexpected ctx%headcalc user set: {sorted(observed_ctx_users)}")

expected_legacy_worker = {"src/legacy/b1_10_port/headcalc.f90"}
observed_legacy_worker = scan_files(texts, r"\blegacy_worker\b")
if observed_legacy_worker != expected_legacy_worker:
    fail(f"unexpected legacy_worker reference set: {sorted(observed_legacy_worker)}")

headcalc = texts[ROOT / "src/legacy/b1_10_port/headcalc.f90"]
for token in (
    "save :: legacy_worker",
    "call rootextraction",
    "call boundtop",
    "call macropore",
    "pondrunoff",
    "ctx%headcalc%dkdh",
):
    if token not in headcalc:
        fail(f"expected current isolation seam missing from headcalc: {token}")

worker = texts[ROOT / "src/runtime/mod_a23bu_worker_execution_context.f90"]
for token in (
    "dfdhl", "dfdhm", "dfdhu", "difh", "residual", "sink", "source", "dkdh",
    "hold", "qv", "hgrad", "flnonconv1", "flnonconv2", "flunsatok",
):
    if token not in worker:
        fail(f"worker scratch contract missing {token}")

print("F-SI01_SOURCE_BOUNDARY_GATE PASS")
print(f"pinned_files={len(baseline['source_binding']['pinned_current_files'])}")
print(f"ownership_items={len(baseline['ownership_inventory'])}")
print(f"historical_evidence_records={len(baseline['historical_evidence'])}")
print(f"specified_tests={len(baseline['test_matrix'])}")
print(f"headcalc_callers={','.join(sorted(observed_headcalc_callers))}")
