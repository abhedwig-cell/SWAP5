#!/usr/bin/env python3
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = "c7379b6b5b5f529ff96de3087379712bd665276a"
FGC13 = "0c776f7c3d910c6727ec5659ae6437ca993fb20d"
ADAPTER = "src/runtime/mod_coupling_application_accuracy_adapter.f90"
CONTRACT = "src/runtime/mod_coupling_application_accuracy_contract.f90"
TEST = "tests/fgc/test_fgc14_external_accuracy_adapter.f90"


def run(*args, cwd=ROOT, capture=False):
    result = subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)
    return result.stdout.strip() if capture else ""


def require(condition, message):
    if not condition:
        raise SystemExit("FGC14_GATE_FAIL: " + message)


def git_text(*args):
    return run("git", *args, capture=True)


def compile_case(opt, out):
    common = ["-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow"]
    units = [
        ("src/transaction/mod_transaction_reference.f90", "transaction.o", False),
        ("src/runtime/mod_canonical_contracts.f90", "contracts.o", False),
        (CONTRACT, "contract.o", True),
        (ADAPTER, "adapter.o", True),
        (TEST, "test.o", True),
    ]
    for source, obj, strict in units:
        cmd = ["gfortran", *common]
        if strict:
            cmd.append("-Werror")
        cmd += [opt, "-J", str(out), "-I", str(out), "-c", source, "-o", str(out / obj)]
        run(*cmd)
    exe = out / "fgc14"
    run("gfortran", opt, *(str(out / obj) for _, obj, _ in units), "-o", str(exe))
    return subprocess.run([str(exe)], cwd=ROOT, check=True, text=True, capture_output=True).stdout


run("git", "merge-base", "--is-ancestor", CANONICAL, "HEAD")
run("git", "merge-base", "--is-ancestor", FGC13, "HEAD")
require(git_text("rev-parse", "HEAD:integration/f-gc/F-GC13_CLOSEOUT.json") == "a6852bc3ff4a6c22097543510a49ea7164326648", "F-GC13 closeout drifted")
require(git_text("rev-parse", f"HEAD:{CONTRACT}") == "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc", "canonical contract drifted")
print("FGC14_UPSTREAM_AUTHORITY_LOCK=PASS")

changed = git_text("diff", "--name-only", f"{CANONICAL}..HEAD", "--", "src")
require(changed == ADAPTER, "source allowlist violated: " + changed)
print("FGC14_SOURCE_ALLOWLIST=PASS")

adapter_text = (ROOT / ADAPTER).read_text(encoding="utf-8").lower()
contract_text = (ROOT / CONTRACT).read_text(encoding="utf-8").lower()
for forbidden in ("json", "yaml", "filepath", "filename"):
    require(forbidden not in adapter_text, "format/path coupling: " + forbidden)
for forbidden in ("use mod_kernel", "use mod_transaction", "use mod_soil_water", "use mod_reference_richards"):
    require(forbidden not in adapter_text, "forbidden dependency: " + forbidden)
for required in (
    "fgc13_packet_validated = .false.",
    "application_source_digest_content_verified = .false.",
    "temporal_source_digest_content_verified = .false.",
    "contract = coupling_application_accuracy_contract_t()",
    "candidate%application_requirement_valid()",
    "candidate%temporal_allocation_valid()",
    "candidate%temporal_budget_ready()",
):
    require(required in adapter_text, "missing fail-closed binding: " + required)
require("ieee_is_finite(self%h_app_cm)" in contract_text, "finite H_app guard missing")
require("ieee_is_finite(self%a_temporal)" in contract_text, "finite A_temporal guard missing")
print("FGC14_TYPED_FAIL_CLOSED_BOUNDARY=PASS")
print("FGC14_NONFINITE_GUARD_INHERITANCE=PASS")

with tempfile.TemporaryDirectory(prefix="swap5-fgc14-") as temp:
    base = Path(temp)
    o0 = base / "o0"
    o2 = base / "o2"
    o0.mkdir()
    o2.mkdir()
    out0 = compile_case("-O0", o0)
    out2 = compile_case("-O2", o2)
    require(out0 == out2, "O0/O2 output drift")
    print(out2, end="")

print("FGC14_O0_O2_IDENTITY=PASS")
print("FGC14_MASS_CONSERVATION_RELAXED=NO")
print("FGC14_PRODUCTION_COUPLING_ADMISSION=NO")
print("FGC14_EXTERNAL_ACCURACY_RUNTIME_ADAPTER_GATE=PASS")
