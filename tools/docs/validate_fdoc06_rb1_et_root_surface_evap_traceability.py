#!/usr/bin/env python3
"""Fail-closed validator for F-DOC06 bounded RB1 ET/root/surface-evaporation traceability."""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "919f228d8aedc1029b5080bb019fbe61d2e1d7c6"
BASE_TREE = "61eb70ab21771f894f19425e2e2396e0ccef08e8"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SOURCE_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
SRC_TREE = "8ceeb70a64012631ebba295f5c045ea908b0681f"
REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FMQ30 = "48ee2841d783ee023c29391a7ea1e5d7ee0d20e0"

REGISTRY = ROOT / "docs/scientific/registries/rb1-et-root-surface-evap-traceability.json"
DOC = ROOT / "docs/scientific/F-DOC06_RB1_ET_ROOT_SURFACE_EVAP_TRACEABILITY.md"
STATUS = ROOT / "integration/f-doc/F-DOC06_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC06_INVARIANT_AUDIT.json"
CLOSEOUT = ROOT / "integration/f-doc/F-DOC06_CLOSEOUT.json"

CAPS = [
    "RB1-ET-ROOT-SERIAL",
    "RB1-ROOT-PARALLEL",
    "RB1-SURFACE-EVAP-RESTRICTED",
]
ALLOWED = (
    "docs/scientific/F-DOC06_",
    "docs/scientific/registries/rb1-et-root-surface-evap-traceability.json",
    "integration/f-doc/F-DOC06_",
    "tools/docs/validate_fdoc06_rb1_et_root_surface_evap_traceability.py",
    ".github/workflows/fdoc06-rb1-et-root-surface-evap-traceability.yml",
)
SOURCE_PINS = {
    "src/process/mod_reference_et_demand_process.f90": "f5e88ec5089fd3b57ac111065fab2aa32dde0fae",
    "src/runtime/mod_fmr_reference_et_demand_binding.f90": "8c679f911c9a82c498258224d83f5fce3cb09163",
    "src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90": "11ef6182414af4fbe67eebec3d6f14742df04aca",
    "src/runtime/mod_fmr_reference_et_root_uptake_composition.f90": "8ed7610144700f58d0b89482925471fcb2ff7d69",
    "src/crop/mod_crop_root_uptake_input_contract.f90": "cc5594f6c7a91ac2ff37af611d40c740b7f25521",
    "src/process/mod_root_water_uptake_process.f90": "e6134587cf3c0164bbe09f2f4c87aef6886aaeb3",
    "src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90": "9105126c219cbd06fadfa7757ba95d7b7bd0499b",
    "src/runtime/mod_fmr_root_uptake_process_binding.f90": "2fc348f18e8561096fa34dd3c11c64b359583f11",
    "src/runtime/mod_fmr_serialized_multiswap_runtime.f90": "f06a2eef7b47880e449cf9b201342d7bd1e197e1",
    "src/runtime/mod_fmr_parallel_root_uptake_pool.f90": "c78c13997642617376b8d118122c86c60ca77189",
    "src/solver/mod_b110_root_sink_provider.f90": "ef2d2fd883d116c314b98e8f0f14330150b4778a",
    "src/process/mod_restricted_surface_evaporation.f90": "a213af4deec2fe854d79120899827852a57237d1",
    "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90": "bc40bc6b121f56071d2b811195759f86130defeb",
    "src/solver/mod_surface_evaporation_capacity_contract.f90": "551513f77caeb9c54e8c8b1cdc326be0e9d01982",
    "src/solver/mod_b110_surface_evaporation_capacity_provider.f90": "8909cdf342527a2b0266c8d9a5fc918f98556ea2",
}


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC06_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC06_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def blob(commit: str, path: str) -> str:
    return sh("git", "rev-parse", f"{commit}:{path}")


# Exact upstream and documentation-only delta.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC05_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC05_BASE_ANCESTRY")
base_status = git_json(BASE, "integration/f-doc/F-DOC05_STATUS.json")
require(base_status["decision"] == "QUALIFIED_BOUNDED_RB1_EXECUTION_RESTART_TRACEABILITY_WITH_EXPLICIT_GAPS", "FDOC05_DECISION")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
require(bool(changed), "BOUNDED_DELTA_NONEMPTY")
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED), "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Frozen RB1 source identity and exact implementation pins.
require(sh("git", "rev-parse", f"{SOURCE}^{{tree}}") == SOURCE_TREE, "RB1_SOURCE_TREE")
require(sh("git", "rev-parse", f"{SOURCE}:src") == SRC_TREE, "RB1_SRC_TREE")
require(sh("git", "rev-parse", f"{SOURCE}:reference") == REFERENCE_TREE, "RB1_REFERENCE_TREE")
for path, expected in SOURCE_PINS.items():
    require(blob(SOURCE, path) == expected, "SOURCE_BLOB_" + path.split("/")[-1].replace(".", "_").upper())

# ET authority must retain its historical scope boundary rather than being promoted into root qualification.
require(blob(SOURCE, "integration/f-ci/F-CI27_STATUS.json") == "f8059ea8d8aaad4451ab64c46d398bd77aa1cd9e", "FCI27_STATUS_BLOB")
fci27 = git_json(SOURCE, "integration/f-ci/F-CI27_STATUS.json")
require(fci27["decision"] == "QUALIFIED_CLOSED_FMR23_RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_CANONICAL_ADMISSION", "FCI27_DECISION")
require(fci27["qualified_scope"]["generic_contained_interval_binding"] is True, "FCI27_GENERIC_TIME")
require(fci27["qualified_scope"]["root_uptake_binding"] is False, "FCI27_ROOT_NOT_YET_BOUND")
require(fci27["qualified_scope"]["ptra_ownership_reconciled"] is False, "FCI27_PTRA_NOT_YET_RECONCILED")

# Serialized root-attribution scientific lineage.
require(blob(SOURCE, "integration/f-ci/F-CI34_STATUS.json") == "b21b6bd58e45a8734b24517f24bfec5a7640c4b8", "FCI34_STATUS_BLOB")
fci34 = git_json(SOURCE, "integration/f-ci/F-CI34_STATUS.json")
require(fci34["candidate"]["owner_closeout"] == "c84894c335b699f0dcf2c46019be0ce7a97f2910", "FCI34_OWNER_CLOSEOUT")
require(fci34["independent_qualification"]["work_unit"] == "F-VQ50", "FCI34_FVQ50_BINDING")
require(fci34["independent_qualification"]["closeout"] == "55ccc132b0405cf4ee13336f08730aa94b24ad19", "FCI34_FVQ50_CLOSEOUT")
require(fci34["independent_qualification"]["decision"] == "QUALIFIED_REMEDIATED_EXACT_RUNTIME_FORCING_BOUND_ROOT_UPTAKE_ATTRIBUTION_WITHIN_FROZEN_SERIALIZED_SCOPE", "FCI34_FVQ50_DECISION")
for gate in (
    "f_vq50_forcing_provenance_oracle",
    "f_vq21_real_headcalc_root_sink_oracle",
    "o0_o2_scientific_identity",
    "attribution_not_derived_from_generic_mass_total",
    "active_zero_attribution_available",
    "root_inactive_attribution_unavailable",
    "noncommitted_attribution_unavailable",
    "no_second_mass_booking",
    "hard_mass_balance",
    "exact_forcing_handle_association",
):
    require(fci34["scientific_gates"][gate] == "PASS", "FCI34_GATE_" + gate.upper())
require("parallel root-attribution publication" in fci34["scope"]["nonclaims"], "FCI34_NO_PARALLEL_ATTRIBUTION_CLAIM")
require("time-varying qrot within accepted substeps" in fci34["scope"]["nonclaims"], "FCI34_NO_TIMEVARYING_QROT_CLAIM")

# Parallel-root independent matrix.
require(blob(FMQ30, "integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json") == "40b45112f0e14accbcc08c015b988f39bf376eb7", "FMQ30_MATRIX_BLOB")
require(blob(FMQ30, "integration/f-mq/F-MQ30_STATUS.json") == "3fafdbad7f923023b550d264ba5edb398c1903f3", "FMQ30_STATUS_BLOB")
m30 = git_json(FMQ30, "integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json")
s30 = git_json(FMQ30, "integration/f-mq/F-MQ30_STATUS.json")
require(m30["workers"] == [2, 4], "FMQ30_WORKERS_2_4")
require(m30["hard_mass_gate_cm"] == 1e-12, "FMQ30_HARD_MASS")
require("actual transpiration is attribution only and does not create a second mass booking" in m30["positive_oracles"], "FMQ30_NO_DUPLICATE_TRANSPIRATION_BOOKING")
require("worker_count=1 rejects this explicit parallel-root capability without silent serialized fallback" in m30["negative_oracles"], "FMQ30_WORKER1_FAIL_CLOSED")
require("performance speedup" in m30["nonclaims"], "FMQ30_NO_SPEEDUP_CLAIM")
require("root-active committed-boundary restart" in m30["nonclaims"], "FMQ30_NO_ROOT_RESTART_CLAIM")
require(s30["state"]["independently_qualified"] is True, "FMQ30_INDEPENDENTLY_QUALIFIED")

# Restricted surface-evaporation final postimage and preservation evidence.
require(blob(SOURCE, "integration/f-ci/F-CI41P_STATUS.json") == "f5a359c7d3f80ede80c15eadc44afb155aaab845", "FCI41P_STATUS_BLOB")
fci41p = git_json(SOURCE, "integration/f-ci/F-CI41P_STATUS.json")
require(fci41p["phase"] == "FINAL_CLOSEOUT_COMPLETE", "FCI41P_FINAL_CLOSEOUT")
require(fci41p["decision"] == "QUALIFIED_CURRENT_CANONICAL_SURFACE_EVAPORATION_RUNTIME_POSTIMAGE_GOVERNANCE_RECONCILIATION", "FCI41P_DECISION")
require(fci41p["independent_scientific_authority"]["head"] == "0cdbc193976c73bef208a82547b3c9ea81c4102c", "FCI41P_FVQ56_HEAD")
require(fci41p["independent_scientific_authority"]["decision"] == "QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE", "FCI41P_FVQ56_DECISION")
require(fci41p["state"]["final_closeout_complete"] is True, "FCI41P_STATE_FINAL")
require("NO_THROUGHPUT_OR_SCALING_CHANGE" in fci41p["performance_scope"], "FCI41P_NO_THROUGHPUT_SCALING_CHANGE")
require("CALL_LOCAL_COPY_ALLOCATION_DEBT_REMAINS_DEFERRED" in fci41p["performance_scope"], "FCI41P_ALLOCATION_DEBT_DEFERRED")

fpe_path = "tests/fpe/run_fpe11_surface_evaporation_allocation_qualification.sh"
require(blob(SOURCE, fpe_path) == "f3068802d4428e6941bef6e76a65d78c2e3d264d", "FPE11_RUNNER_BLOB")
fpe11 = sh("git", "show", f"{SOURCE}:{fpe_path}")
for marker in (
    "FPE11_FCI41P_OBSERVABLE_IDENTITY=PASS",
    "FPE11_O0_O2_IDENTITY=PASS",
    "FPE11_COMMITTED_STATE_IMMUTABILITY=PASS",
    "FPE11_ABA_DETERMINISM=PASS",
    "FPE11_NO_AUTHORITATIVE_MASS_BOOKING=PASS",
    "FPE11_FUNCTIONAL_QUALIFICATION=PASS",
    "FPE11_THROUGHPUT_SCALING_CLAIM=NOT_YET_MADE",
):
    require(marker in fpe11, "FPE11_MARKER_" + marker.split("=")[0].replace("FPE11_", ""))

# Registry boundedness and tier semantics.
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
require(registry["schema_version"] == "1.0" and registry["work_unit"] == "F-DOC06", "REGISTRY_IDENTITY")
require(registry["base_authority"]["fdoc05"] == BASE, "REGISTRY_FDOC05_BASE")
require(registry["base_authority"]["rb1_scientific_source"] == SOURCE, "REGISTRY_SOURCE")
require(registry["scope"]["bounded_capabilities"] == CAPS, "EXACT_THREE_CAPABILITIES")
require([c["capability_id"] for c in registry["capabilities"]] == CAPS, "CAPABILITY_ORDER")
require(len(registry["source_pins"]) == len(SOURCE_PINS), "SOURCE_PIN_COUNT")
for item in registry["source_pins"]:
    require(SOURCE_PINS[item["path"]] == item["blob"], "REGISTRY_PIN_" + item["path"].split("/")[-1].replace(".", "_").upper())
for cap in registry["capabilities"]:
    marker = cap["capability_id"].replace("-", "_")
    require(cap["release_gate"] == "PASS", "REGISTRY_RELEASE_PASS_" + marker)
    require(cap["resolved_tiers"] == ["T8", "T9", "T10", "T13", "T14"], "REGISTRY_BOUNDED_RESOLUTION_" + marker)
    require(cap["T11"]["status"] == "SCOPED_QUALIFICATION_EVIDENCE_BOUND_NOT_COMPLETE_GRAPH", "REGISTRY_T11_SCOPED_" + marker)
    require(cap["open_tiers"] == ["T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T12"], "REGISTRY_OPEN_TIERS_" + marker)
nonclaims = "\n".join(registry["global_nonclaims"])
for phrase in (
    "does not claim FULLY_TRACED",
    "does not invent or backfill a controlled T1",
    "does not claim T12 application validation",
    "does not claim Status A readiness",
    "does not change the frozen 15-capability RB1 denominator",
    "does not reopen immutable RB1",
    "does not make a performance speedup, throughput or scaling claim",
    "does not reopen call-local surface-evaporation copy/allocation performance work",
):
    require(phrase in nonclaims, "REGISTRY_NONCLAIM_" + phrase[:28].replace(" ", "_").replace("-", "_").upper())

# Frozen RB1 denominator and exact release limitations.
require(blob(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json") == "e20e0b2cae1cfde91c8736ad632059b4fe480d88", "RB1_MATRIX_BLOB")
rb1 = git_json(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json")
require(rb1["required_denominator"] == 15 and rb1["summary"]["required_integrated_pass"] == 15, "RB1_DENOMINATOR_15_PASS")
rb1_caps = {c["capability_id"]: c for c in rb1["capabilities"]}
for cap in CAPS:
    require(rb1_caps[cap]["integrated_release_gate"] == "PASS", "RB1_PASS_" + cap.replace("-", "_"))
require("restricted drought-only precomputed QROT scope" in rb1_caps["RB1-ET-ROOT-SERIAL"]["limitations"], "RB1_ET_ROOT_QROT_BOUND")
require("2/4 workers" in rb1_caps["RB1-ROOT-PARALLEL"]["limitations"], "RB1_ROOT_PARALLEL_2_4")
require("no root-active restart claim" in rb1_caps["RB1-ROOT-PARALLEL"]["limitations"], "RB1_ROOT_NO_RESTART")
require("SWINTER=0" in rb1_caps["RB1-SURFACE-EVAP-RESTRICTED"]["limitations"], "RB1_SURFACE_SWINTER0")
require("SWREDU=0" in rb1_caps["RB1-SURFACE-EVAP-RESTRICTED"]["limitations"], "RB1_SURFACE_SWREDU0")
require(any("throughput/scaling is separate" in x for x in rb1_caps["RB1-SURFACE-EVAP-RESTRICTED"]["limitations"]), "RB1_SURFACE_THROUGHPUT_SEPARATE")

# Human-facing documentation and governance state.
doc = DOC.read_text(encoding="utf-8")
for phrase in (
    "root uptake was not yet bound",
    "2 and 4 workers",
    "1e-12 cm",
    "SWINTER=0",
    "SWREDU=0",
    "FPE11_THROUGHPUT_SCALING_CLAIM=NOT_YET_MADE",
    "call-local copy/allocation",
    "T12 also remains open",
    "does not claim Status A readiness",
):
    require(phrase in doc, "DOC_CONTAINS_" + phrase[:22].replace("/", "_").replace(" ", "_").replace("-", "_").replace("=", "_").upper())

status = json.loads(STATUS.read_text(encoding="utf-8"))
require(status["work_unit"] == "F-DOC06" and status["base"] == BASE, "STATUS_IDENTITY")
require(status["capabilities"] == CAPS, "STATUS_CAPABILITIES")
require(status["decision"] == "QUALIFIED_BOUNDED_RB1_ET_ROOT_SURFACE_EVAP_TRACEABILITY_WITH_EXPLICIT_GAPS", "STATUS_DECISION")
for key in ("production_delta", "reference_delta", "physics_delta", "solver_delta", "acceptance_threshold_delta", "performance_delta"):
    require(status["scope_holds"][key] == "NONE", "STATUS_" + key.upper() + "_NONE")
require(status["traceability_boundary"]["fully_traced_claimed"] is False, "STATUS_NOT_FULLY_TRACED")
require(status["traceability_boundary"]["status_a_ready_claimed"] is False, "STATUS_NO_STATUS_A_READY")
require(status["traceability_boundary"]["t12_application_validation_claimed"] is False, "STATUS_NO_T12_VALIDATION")
require(status["traceability_boundary"]["surface_evaporation_throughput_scaling_claimed"] is False, "STATUS_NO_SURFACE_THROUGHPUT_CLAIM")
require(status["traceability_boundary"]["surface_evaporation_performance_debt_reopened"] is False, "STATUS_PERFORMANCE_DEBT_NOT_REOPENED")

closeout = json.loads(CLOSEOUT.read_text(encoding="utf-8"))
require(closeout["work_unit"] == "F-DOC06" and closeout["base_authority"]["fdoc05"] == BASE, "CLOSEOUT_IDENTITY")
require(closeout["bounded_capabilities"] == CAPS, "CLOSEOUT_CAPABILITIES")
require(closeout["decision"] == status["decision"], "CLOSEOUT_DECISION")
require(closeout["closeout_state"] in ("PENDING_EXACT_HEAD_CI", "FINAL_EXACT_HEAD_CI_GREEN"), "CLOSEOUT_STATE_ALLOWED")

# Explicit 30-invariant audit.
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
require(audit["total"] == 30 and audit["pass"] == 30 and audit["fail"] == 0, "INVARIANT_COUNTS")
require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_OVERALL")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "MASS_HARD_UNCHANGED")
require(len(audit["items"]) == 30 and [x["id"] for x in audit["items"]] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["status"] == "PASS" for x in audit["items"]), "ALL_INVARIANTS_PASS")
require(audit["scope_holds"]["surface_evaporation_throughput_scaling_claimed"] is False, "AUDIT_NO_SURFACE_THROUGHPUT_CLAIM")

print("FDOC06_VALIDATION=PASS")
print("FDOC06_PRODUCTION_DELTA=NONE")
print("FDOC06_REFERENCE_DELTA=NONE")
print("FDOC06_CAPABILITY_COUNT=3")
print("FDOC06_FULLY_TRACED_CLAIM=FALSE")
print("FDOC06_STATUS_A_READY_CLAIM=FALSE")
print("FDOC06_T12_APPLICATION_VALIDATION_CLAIM=FALSE")
print("FDOC06_SURFACE_EVAP_THROUGHPUT_SCALING_CLAIM=FALSE")
print("FDOC06_MASS_CONSERVATION=HARD_UNCHANGED")
