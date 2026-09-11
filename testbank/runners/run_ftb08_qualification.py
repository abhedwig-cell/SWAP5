#!/usr/bin/env python3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FGC14 = "6d91bedc305504cc2fa08b196e6a9903c48c9461"
TEST_PATH = "tests/fgc/test_fgc14_external_accuracy_adapter.f90"
PROFILE = (sys.argv[1] if len(sys.argv) > 1 else "FAST").upper()
if PROFILE not in {"FAST", "CANONICAL", "RELEASE", "DEEP"}:
    raise SystemExit("FTB08_FAIL: unknown profile " + PROFILE)


def run(*args, cwd=ROOT, capture=False):
    p = subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)
    return p.stdout if capture else ""

def require(ok, msg):
    if not ok:
        raise SystemExit("FTB08_FAIL: " + msg)

run("python3", "testbank/runners/validate_ftb08_external_accuracy_adapter_adoption.py")
if PROFILE == "FAST":
    print("FTB08_PROFILE_FAST=PASS")
    raise SystemExit(0)

adapter = (ROOT / "src/runtime/mod_coupling_application_accuracy_adapter.f90").read_text().lower()
contract = (ROOT / "src/runtime/mod_coupling_application_accuracy_contract.f90").read_text().lower()
for token in ("json", "yaml", "filepath", "filename"):
    require(token not in adapter, "format/path coupling token " + token)
for token in ("use mod_kernel", "use mod_soil_water", "use mod_reference_richards"):
    require(token not in adapter, "forbidden physical/kernel dependency " + token)
for token in (
    "fgc13_packet_validated = .false.",
    "application_source_digest_content_verified = .false.",
    "temporal_source_digest_content_verified = .false.",
    "contract = coupling_application_accuracy_contract_t()",
    "candidate%application_requirement_valid()",
    "candidate%temporal_allocation_valid()",
    "candidate%temporal_budget_ready()",
):
    require(token in adapter, "missing fail-closed binding " + token)
require("ieee_is_finite(self%h_app_cm)" in contract, "H_app finite guard")
require("ieee_is_finite(self%a_temporal)" in contract, "A_temporal finite guard")
print("FTB08_TYPED_FAIL_CLOSED_BOUNDARY=PASS")
print("FTB08_NONFINITE_GUARD_INHERITANCE=PASS")

workflow = (ROOT / ".github/workflows/fci-canonical.yml").read_text()
require("AUTH=e765d96ee80af0629fb399e18bf58124dade7641" in workflow, "F-CI47 moving authority not present")
require("src/runtime/mod_coupling_application_accuracy_adapter.f90" in workflow, "adapter absent from moving preservation surface")
require("FCI46_MOVING_EXTERNAL_ACCURACY_ADAPTER_PRESERVATION=PASS" in workflow, "F-CI46 preservation marker missing")
print("FTB08_CURRENT_CANONICAL_PRESERVATION_BINDING=PASS")

common = ["-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow"]

def compile_and_run(opt, outdir, test_source):
    units = [
        (ROOT / "src/transaction/mod_transaction_reference.f90", "transaction.o", False),
        (ROOT / "src/runtime/mod_canonical_contracts.f90", "contracts.o", False),
        (ROOT / "src/runtime/mod_coupling_application_accuracy_contract.f90", "contract.o", True),
        (ROOT / "src/runtime/mod_coupling_application_accuracy_adapter.f90", "adapter.o", True),
        (test_source, "test.o", True),
    ]
    for source, obj, strict in units:
        cmd = ["gfortran", *common]
        if strict:
            cmd.append("-Werror")
        cmd += [opt, "-J", str(outdir), "-I", str(outdir), "-c", str(source), "-o", str(outdir / obj)]
        run(*cmd)
    exe = outdir / "ftb08_adapter"
    run("gfortran", opt, *(str(outdir / obj) for _, obj, _ in units), "-o", str(exe))
    return run(str(exe), capture=True)

with tempfile.TemporaryDirectory(prefix="swap5-ftb08-") as td:
    base = Path(td)
    donor = base / "test_fgc14_external_accuracy_adapter.f90"
    donor.write_text(run("git", "show", f"{FGC14}:{TEST_PATH}", capture=True))
    o0a = base / "o0a"; o0a.mkdir()
    out0a = compile_and_run("-O0", o0a, donor)
    for marker in (
        "FGC14_HEAD_FRACTION_MAPPING=PASS",
        "FGC14_DRAWDOWN_CANONICALIZED_DIRECT_BUDGET_MAPPING=PASS",
        "FGC14_FAIL_CLOSED_REJECTION_MATRIX=PASS:12",
        "FGC14_TYPED_ADAPTER_TESTS=PASS",
    ):
        require(marker in out0a, "missing executable marker " + marker)
    print(out0a, end="")
    print("FTB08_FGC14_ADAPTER_MATRIX_CURRENT_CANONICAL_O0=PASS")

    if PROFILE in {"RELEASE", "DEEP"}:
        o0b = base / "o0b"; o0b.mkdir()
        o2 = base / "o2"; o2.mkdir()
        out0b = compile_and_run("-O0", o0b, donor)
        out2 = compile_and_run("-O2", o2, donor)
        require(out0a == out0b, "repeat O0 transcript drift")
        require(out0a == out2, "O0/O2 transcript drift")
        print("FTB08_REPEAT_RUN_DETERMINISM=PASS")
        print("FTB08_O0_O2_BIT_IDENTITY=PASS")

print("FTB08_EXTERNAL_SOURCE_BYTES_VERIFIED_BY_ADAPTER=NO")
print("FTB08_FILE_OR_JSON_PARSING=NO")
print("FTB08_PROJECT_POLICY_SELECTION=NO")
print("FTB08_NUMERIC_H_APP=NOT_SET")
print("FTB08_NUMERIC_A_TEMPORAL=NOT_SET")
print("FTB08_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE")
print("FTB08_MASS_CONSERVATION_RELAXED=NO")
print(f"FTB08_PROFILE_{PROFILE}=PASS")
