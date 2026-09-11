#!/usr/bin/env python3
"""Fail-closed validator for F-DOC05 bounded RB1 execution/restart traceability."""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "a703747ce1991c5601b76a84f04969b602298268"
BASE_TREE = "01231d37614b37fbd9b0b14ab807dac1caf28228"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SOURCE_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FMQ27 = "33beccd7b38f5a3c29131025e1b06166026851e3"
FMQ29 = "5ea88d81a63e6c706c87e99ac360f91f08711fc1"
FMQ30 = "48ee2841d783ee023c29391a7ea1e5d7ee0d20e0"

REGISTRY = ROOT / "docs/scientific/registries/rb1-execution-restart-traceability.json"
DOC = ROOT / "docs/scientific/F-DOC05_RB1_EXECUTION_RESTART_TRACEABILITY.md"
STATUS = ROOT / "integration/f-doc/F-DOC05_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC05_INVARIANT_AUDIT.json"
CLOSEOUT = ROOT / "integration/f-doc/F-DOC05_CLOSEOUT.json"

CAPS = [
    "RB1-STANDALONE-N1",
    "RB1-MULTISWAP-SERIAL",
    "RB1-MULTISWAP-PARALLEL-V1",
    "RB1-RESTART-SERIAL",
    "RB1-RESTART-PARALLEL",
]
ALLOWED = (
    "docs/scientific/F-DOC05_",
    "docs/scientific/registries/rb1-execution-restart-traceability.json",
    "integration/f-doc/F-DOC05_",
    "tools/docs/validate_fdoc05_rb1_execution_restart_traceability.py",
    ".github/workflows/fdoc05-rb1-execution-restart-traceability.yml",
)
SOURCE_PINS = {
    "src/runtime/mod_fmr_runtime_core.f90": "adc2b7514cc062c0cde4e71582ba8ed7776a7335",
    "src/runtime/mod_fmr_serialized_multiswap_runtime.f90": "f06a2eef7b47880e449cf9b201342d7bd1e197e1",
    "src/runtime/mod_fmr_parallel_physical_scheduler.f90": "544a1ca16fdeebdfce7f89d1ddf1825fa32fa654",
    "src/runtime/mod_fmr_parallel_worker_pool.f90": "0e700797cbaed4aaab7f04db0054f72faddcfc15",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "2a190d206200ad201c37c9a82d3e32e651d37a37",
    "src/runtime/mod_fmr_committed_restart.f90": "19ea410e0ed48e65b5d73887a8e1dba59c7c4f37",
    "src/runtime/mod_fmr_restart_state_contract.f90": "f1359f97d02408d8b700b0c93fe961a6ba46742c",
    "src/runtime/mod_fmr_deterministic_runtime.f90": "6f567600e42bc4e37e0e175ef4a3edc97a945592",
}


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC05_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC05_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def blob(commit: str, path: str) -> str:
    return sh("git", "rev-parse", f"{commit}:{path}")


# Exact upstream and documentation-only delta.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC04_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC04_BASE_ANCESTRY")
base_status = git_json(BASE, "integration/f-doc/F-DOC04_STATUS.json")
require(base_status["decision"] == "QUALIFIED_BOUNDED_RB1_REFERENCE_TEMPORAL_TRACEABILITY_WITH_EXPLICIT_GAPS", "FDOC04_DECISION")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
require(bool(changed), "BOUNDED_DELTA_NONEMPTY")
for path in changed:
    marker = "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper()
    require(any(path.startswith(prefix) for prefix in ALLOWED), marker)
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Frozen RB1 source identity and exact runtime/restart mappings.
require(sh("git", "rev-parse", f"{SOURCE}^{{tree}}") == SOURCE_TREE, "RB1_SOURCE_TREE")
for path, expected in SOURCE_PINS.items():
    require(blob(SOURCE, path) == expected, "SOURCE_BLOB_" + path.split("/")[-1].replace(".", "_").upper())

serial_src = sh("git", "show", f"{SOURCE}:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")
parallel_src = sh("git", "show", f"{SOURCE}:src/runtime/mod_fmr_parallel_worker_pool.f90")
restart_src = sh("git", "show", f"{SOURCE}:src/runtime/mod_fmr_committed_restart.f90")
require("public :: fmr_run_serialized_physical_multiswap" in serial_src, "SERIAL_SHARED_ENTRYPOINT")
require("public :: fmr_run_parallel_physical_multiswap" in parallel_src, "PARALLEL_ENTRYPOINT")
require("if (worker_count == 1) then" in parallel_src and "fmr_run_serialized_physical_multiswap" in parallel_src, "PARALLEL_ONE_DELEGATES_SERIAL")
require("worker_count /= 2 .and. worker_count /= 4" in parallel_src, "PARALLEL_MULTIWORKER_BOUND_2_4")
require("allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))" in parallel_src, "WORKER_OWNED_CONTEXT_ALLOCATION")
for token in ("fmr_committed_restart_record_t", "fmr_committed_restart_bundle_t", "fmr_export_committed_restart", "fmr_restore_committed_restart"):
    require(token in restart_src, "RESTART_CONTRACT_" + token.upper())
for excluded in ("solver/Newton/Jacobian scratch", "worker warm starts"):
    require(excluded in restart_src, "RESTART_EXCLUDES_" + excluded.replace("/", "_").replace(" ", "_").upper())

# Exact independent qualification evidence.
require(blob(FMQ27, "integration/f-mq/F-MQ27_QUALIFICATION_MATRIX.json") == "efee0213881dff04d2111e4eccb879d50247324c", "FMQ27_MATRIX_BLOB")
require(blob(FMQ27, "integration/f-mq/F-MQ27_STATUS.json") == "8368b2095b4996a63ed2bd1992b70cbf7c3318b0", "FMQ27_STATUS_BLOB")
m27 = git_json(FMQ27, "integration/f-mq/F-MQ27_QUALIFICATION_MATRIX.json")
s27 = git_json(FMQ27, "integration/f-mq/F-MQ27_STATUS.json")
require(m27["positive_matrix"]["column_counts"] == [1, 2, 7, 8, 17, 31, 32], "FMQ27_COUNTS_INCLUDE_N1")
require(m27["positive_matrix"]["generic_time_window"]["calendar_boundary_required"] is False, "FMQ27_GENERIC_TIME")
require("hard mass residual <= 1e-12" in m27["positive_matrix"]["checks_each_count"], "FMQ27_HARD_MASS")
require(m27["atomicity"].startswith("Every negative restore must leave all fresh target states uninitialized"), "FMQ27_ATOMIC_NEGATIVE_RESTORE")
require(s27["QUALIFIED"] is True and s27["decision"] == "QUALIFIED_RESTRICTED_SERIALIZED_MULTISWAP_COMMITTED_BOUNDARY_PROCESS_RESTART", "FMQ27_QUALIFIED")

require(blob(FMQ29, "integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json") == "d080220c26f390eb08d6f32a64af685ec1c50746", "FMQ29_MATRIX_BLOB")
require(blob(FMQ29, "integration/f-mq/F-MQ29_STATUS.json") == "b39f4475f111018f0a95d05c37e10f28b793ebe2", "FMQ29_STATUS_BLOB")
m29 = git_json(FMQ29, "integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json")
s29 = git_json(FMQ29, "integration/f-mq/F-MQ29_STATUS.json")
require(m29["continuation_workers"] == [2, 4], "FMQ29_CONTINUATION_2_4")
require(m29["cross_worker_routes"] == ["2_to_4", "4_to_2"], "FMQ29_CROSS_WORKER_RESTART")
require(m29["hard_mass_gate_cm"] == 1e-12, "FMQ29_HARD_MASS")
for gate in ("malformed physical state atomic rejection", "late-record provenance atomic rejection", "wrong state family rejection", "non-fresh target rejection", "duplicate/unknown column rejection", "template/layout/parameter mismatch rejection"):
    require(gate in m29["required_negative_gates"], "FMQ29_NEGATIVE_" + gate[:18].replace("/", "_").replace(" ", "_").upper())
require(s29["independently_qualified"] is True and s29["decision"] == "QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION", "FMQ29_QUALIFIED")

require(blob(FMQ30, "integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json") == "40b45112f0e14accbcc08c015b988f39bf376eb7", "FMQ30_MATRIX_BLOB")
require(blob(FMQ30, "integration/f-mq/F-MQ30_STATUS.json") == "3fafdbad7f923023b550d264ba5edb398c1903f3", "FMQ30_STATUS_BLOB")
m30 = git_json(FMQ30, "integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json")
s30 = git_json(FMQ30, "integration/f-mq/F-MQ30_STATUS.json")
require(m30["workers"] == [2, 4], "FMQ30_WORKERS_2_4")
require(m30["hard_mass_gate_cm"] == 1e-12, "FMQ30_HARD_MASS")
require("worker_count=1 rejects this explicit parallel-root capability without silent serialized fallback" in m30["negative_oracles"], "FMQ30_ROOT_ENTRYPOINT_WORKER1_REJECTS")
require("performance speedup" in m30["nonclaims"], "FMQ30_NO_PERFORMANCE_SPEEDUP")
require(s30["state"]["independently_qualified"] is True, "FMQ30_QUALIFIED")

# Registry semantics.
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
require(registry["schema_version"] == "1.0" and registry["work_unit"] == "F-DOC05", "REGISTRY_IDENTITY")
require(registry["base_authority"]["fdoc04"] == BASE, "REGISTRY_FDOC04_BASE")
require(registry["base_authority"]["rb1_scientific_source"] == SOURCE, "REGISTRY_SOURCE")
require(registry["base_authority"]["rb1_qualification"] == FRB01 and registry["base_authority"]["rb1_release"] == FRB02, "REGISTRY_RB1_AUTHORITIES")
require(registry["scope"]["bounded_capabilities"] == CAPS, "EXACT_FIVE_CAPABILITIES")
require([c["capability_id"] for c in registry["capabilities"]] == CAPS, "CAPABILITY_ORDER")
require(len(registry["source_pins"]) == len(SOURCE_PINS), "SOURCE_PIN_COUNT")
for item in registry["source_pins"]:
    require(SOURCE_PINS[item["path"]] == item["blob"], "REGISTRY_PIN_" + item["path"].split("/")[-1].replace(".", "_").upper())

for cap in registry["capabilities"]:
    require(cap["release_gate"] == "PASS", "REGISTRY_RELEASE_PASS_" + cap["capability_id"].replace("-", "_"))
    require(cap["resolved_tiers"] == ["T8", "T9", "T10", "T13", "T14"], "REGISTRY_BOUNDED_RESOLUTION_" + cap["capability_id"].replace("-", "_"))
    require(cap["T11"]["status"] == "SCOPED_QUALIFICATION_EVIDENCE_BOUND_NOT_COMPLETE_GRAPH", "REGISTRY_T11_SCOPED_" + cap["capability_id"].replace("-", "_"))
    require(cap["open_tiers"] == ["T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T12"], "REGISTRY_OPEN_TIERS_" + cap["capability_id"].replace("-", "_"))

nonclaims = "\n".join(registry["global_nonclaims"])
for phrase in ("does not claim FULLY_TRACED", "does not invent a physical or scientific T1 authority", "does not claim T12 application validation", "does not claim Status A readiness", "does not change the frozen 15-capability RB1 denominator", "does not reopen immutable RB1", "does not qualify root-process science"):
    require(phrase in nonclaims, "REGISTRY_NONCLAIM_" + phrase[:24].replace(" ", "_").replace("-", "_").upper())

# Frozen RB1 denominator and bounded capability gates.
rb1 = git_json(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json")
require(rb1["required_denominator"] == 15 and rb1["summary"]["required_integrated_pass"] == 15, "RB1_DENOMINATOR_15_PASS")
rb1_caps = {c["capability_id"]: c for c in rb1["capabilities"]}
for cap in CAPS:
    require(rb1_caps[cap]["integrated_release_gate"] == "PASS", "RB1_PASS_" + cap.replace("-", "_"))
require("2 and 4 workers only" in rb1_caps["RB1-MULTISWAP-PARALLEL-V1"]["limitations"], "RB1_PARALLEL_BOUND_2_4")
require("no universal speedup claim" in rb1_caps["RB1-MULTISWAP-PARALLEL-V1"]["limitations"], "RB1_NO_UNIVERSAL_SPEEDUP")
require("committed-boundary only" in rb1_caps["RB1-RESTART-PARALLEL"]["limitations"], "RB1_RESTART_COMMITTED_BOUNDARY")
require("no mid-transaction restart" in rb1_caps["RB1-RESTART-PARALLEL"]["limitations"], "RB1_NO_MID_TRANSACTION_RESTART")

# Human-facing documentation, status and invariant audit.
doc = DOC.read_text(encoding="utf-8")
for phrase in ("same serialized runtime", "2 and 4 workers", "committed-boundary", "worker/Newton/Jacobian", "T12 remains open", "does not claim Status A", "root-process science remains outside F-DOC05"):
    require(phrase in doc, "DOC_CONTAINS_" + phrase[:20].replace("/", "_").replace(" ", "_").replace("-", "_").upper())

status = json.loads(STATUS.read_text(encoding="utf-8"))
require(status["work_unit"] == "F-DOC05" and status["base"] == BASE, "STATUS_IDENTITY")
require(status["capabilities"] == CAPS, "STATUS_CAPABILITIES")
for key in ("production_delta", "reference_delta", "physics_delta", "solver_delta", "acceptance_threshold_delta", "performance_delta"):
    require(status["scope_holds"][key] == "NONE", "STATUS_" + key.upper() + "_NONE")
require(status["traceability_boundary"]["fully_traced_claimed"] is False, "STATUS_NOT_FULLY_TRACED")
require(status["traceability_boundary"]["status_a_ready_claimed"] is False, "STATUS_NO_STATUS_A_READY")
require(status["traceability_boundary"]["t12_application_validation_claimed"] is False, "STATUS_NO_T12_VALIDATION")

closeout = json.loads(CLOSEOUT.read_text(encoding="utf-8"))
require(closeout["work_unit"] == "F-DOC05" and closeout["base_authority"]["fdoc04"] == BASE, "CLOSEOUT_IDENTITY")
require(closeout["bounded_capabilities"] == CAPS, "CLOSEOUT_CAPABILITIES")

audit = json.loads(AUDIT.read_text(encoding="utf-8"))
require(audit["total"] == 30 and audit["pass"] == 30 and audit["fail"] == 0, "INVARIANT_COUNTS")
require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_OVERALL")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "MASS_HARD_UNCHANGED")
items = audit["items"]
require(len(items) == 30 and [x["id"] for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["status"] == "PASS" for x in items), "ALL_INVARIANTS_PASS")

print("FDOC05_VALIDATION=PASS")
print("FDOC05_PRODUCTION_DELTA=NONE")
print("FDOC05_REFERENCE_DELTA=NONE")
print("FDOC05_CAPABILITY_COUNT=5")
print("FDOC05_FULLY_TRACED_CLAIM=FALSE")
print("FDOC05_STATUS_A_READY_CLAIM=FALSE")
print("FDOC05_T12_APPLICATION_VALIDATION_CLAIM=FALSE")
print("FDOC05_MASS_CONSERVATION=HARD_UNCHANGED")
