#!/usr/bin/env python3
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]

EXPECTED = {
    # F-KT05 transaction/kernel spine
    "src/kernel/mod_kernel_transactions.f90": "e8605e73a191e863374a26b096e0d597cb70cadd",
    "src/transaction/mod_transaction_reference.f90": "4a573316b77252b56bcb429fd519aa57123e9a06",
    "src/runtime/mod_canonical_contracts.f90": "55cd8a9dc529bb2d057845f212b7efff6c80c553",
    "src/runtime/mod_canonical_interval_runtime.f90": "f0bfb2c1359c39b4708350b756aa2211fb982be4",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "2a190d206200ad201c37c9a82d3e32e651d37a37",
    # F-SI05 focused production seam
    "src/solver/mod_soil_water_solver_contract.f90": "57b51997d28807fbe2da1b2e5bf654fc4167adb9",
    "src/solver/mod_reference_richards_workspace.f90": "93285b2ca24669494c93c00403e3783fca6758e9",
    "src/adapter/mod_reference_richards_legacy_binding.f90": "e02882bd45f67b42ede118de14a6b5b8b16fdb80",
    "src/legacy/b1_10_port/headcalc.f90": "e22251c8f562839857cdb7a609a8148d1f2d58f8",
    # Corrected legacy oracle
    "reference/swap-4.3.1/snapshots/B1.10.yml": "8d768f00d47224a663941f79bb2d35eacc66d16b",
    "tools/vq/cases/b1-10-reference-pin.json": "2422c3ec518afb1d9b7fbd55e869a806842161c9",
    # Exact F-SI05 focused test closure imported into F-MR02
    "tests/fsi/run_fsi05_gate.sh": "78fd05cf8c36899fb9fdd970d318fec009bdc827",
    "tests/fsi/test_fsi05_production_headcalc.F90": "8e617d8c6b2fdad2d8ac94455c533c87179f0f18",
    "tests/fsi/fsi04_real_headcalc_stubs.f90": "23c00e4a188e88bc36ef95cbe4faaacdd6aad639",
    "tests/fsi/fsi03_legacy_binding_stubs.f90": "2da0d9d715d0de1096c3debdc3afae4e6fc3fc97",
    "tests/fsi/test_fsi03_reference_binding.f90": "fbeefb6c84624d87a7c77ef59f7558b92a81e4e2",
    "tests/fsi/test_fsi02_solver_contract.f90": "e1ab326daeeddff486954da899586d440c53dd28",
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


for rel, expected in EXPECTED.items():
    path = ROOT / rel
    if not path.is_file():
        raise SystemExit(f"F-MR02_PROVENANCE FAIL missing {rel}")
    actual = git_blob_sha(path.read_bytes())
    if actual != expected:
        raise SystemExit(
            f"F-MR02_PROVENANCE FAIL {rel}: expected {expected}, got {actual}"
        )
print("F-MR02_EXACT_BLOB_PROVENANCE PASS")

shared = json.loads((ROOT / "integration/f-mr/F-MR02_SHARED_POSTIMAGE.json").read_text())
deps = json.loads((ROOT / "integration/f-mr/F-MR02_DEPENDENCIES.json").read_text())

assert shared["routing_invariants"]["multiswap_runtime_entry"] == \
    "F-MR -> F-KT kernel_executor_t%advance_interval"
assert shared["routing_invariants"]["f_mr_direct_headcalc_call_allowed"] is False
assert shared["routing_invariants"]["f_mr_direct_f_si_internal_array_access_allowed"] is False
assert shared["routing_invariants"]["fsi_workspace_persistent_per_column"] is False
assert shared["routing_invariants"]["fsi_workspace_owner"] == "worker_or_job"
assert shared["routing_invariants"]["committed_state_owner"] == "F-KT transaction/kernel layer"

admission = shared["admission_after_source_composition"]
assert admission["parallel_reference_backend"] == "NOT_ADMITTED"
assert admission["physical_multiswap_reference_backend"] == "NOT_ADMITTED"
assert admission["serialized_reference_backend"] == "NOT_YET_QUALIFIED_IN_SHARED_POSTIMAGE"
assert deps["composition_policy"]["parallel_reference_admission_allowed"] is False
assert deps["composition_policy"]["physical_multiswap_admission_allowed"] is False
assert deps["composition_policy"]["physics_change_allowed"] is False
assert deps["composition_policy"]["numerical_policy_change_allowed"] is False
assert deps["composition_policy"]["f_kt_transaction_semantics_change_allowed"] is False
print("F-MR02_ADMISSION_AND_OWNERSHIP_CONTRACT PASS")

# MultiSWAP runtime must remain routed through F-KT and must not reach into the
# reference Richards/HeadCalc implementation directly.
violations = []
for path in sorted((ROOT / "src/runtime").glob("mod_fmr*.f90")):
    text = path.read_text().lower()
    for pattern, label in [
        (r"\bcall\s+headcalc\s*\(", "direct HeadCalc call"),
        (r"\buse\s+mod_reference_richards_workspace\b", "reference workspace import"),
        (r"\buse\s+mod_reference_richards_legacy_binding\b", "legacy binding import"),
    ]:
        if re.search(pattern, text, re.I):
            violations.append(f"{path.relative_to(ROOT)}: {label}")
if violations:
    raise SystemExit("F-MR02_RUNTIME_BOUNDARY FAIL " + "; ".join(violations))

checkpoint = (ROOT / "src/runtime/mod_fmr_checkpoint_orchestrator.f90").read_text().lower()
if "use mod_kernel_transactions" not in checkpoint or "%advance_interval" not in checkpoint:
    raise SystemExit("F-MR02_RUNTIME_BOUNDARY FAIL F-MR checkpoint orchestrator is not routed through F-KT")
print("F-MR02_RUNTIME_TO_FKT_BOUNDARY PASS")

# Production HeadCalc may expose the workspace only as an optional seam; the
# legacy one-argument SoilWater caller must remain intact.
headcalc = (ROOT / "src/legacy/b1_10_port/headcalc.f90").read_text().lower()
soilwater = (ROOT / "src/legacy/b1_10_port/soilwater.f90").read_text().lower()
adapter = (ROOT / "src/adapter/mod_reference_richards_legacy_binding.f90").read_text().lower()
if "subroutine headcalc(worker, fsi_workspace)" not in headcalc:
    raise SystemExit("F-MR02_FSI_SEAM FAIL explicit workspace signature missing")
if "optional :: fsi_workspace" not in headcalc:
    raise SystemExit("F-MR02_FSI_SEAM FAIL workspace is not optional")
if "call headcalc(worker)" not in soilwater:
    raise SystemExit("F-MR02_FSI_SEAM FAIL legacy compatibility caller missing")
if "call headcalc(ws%legacy_worker, ws%richards)" not in adapter:
    raise SystemExit("F-MR02_FSI_SEAM FAIL adapter does not pass worker/job workspace")
print("F-MR02_FSI05_SEAM_CONTRACT PASS")

print("F-MR02_SHARED_POSTIMAGE_STATIC_GATE PASS")
