#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "c7379b6b5b5f529ff96de3087379712bd665276a"
BASE_TREE = "6a3b51a3d51782c06bd388f77ea3421a289c7ac5"
COMPOSITION = "fb6339e665b016e2b4fc9ab03c972b3cd7b7bd34"
COMPOSITION_TREE = "1c7b9e24385e5a27b24ad850a75aaff6d58b0c5c"
FGC14 = "6d91bedc305504cc2fa08b196e6a9903c48c9461"
FGC14_CLOSEOUT_BLOB = "202dd875b44e1865c6d96da981b690137e451a38"
MODULE = "src/runtime/mod_coupling_application_accuracy_adapter.f90"
MODULE_BLOB = "9212d600e89c85287e9280832c7e0a94befb642e"
CONTRACT = "src/runtime/mod_coupling_application_accuracy_contract.f90"
CONTRACT_BLOB = "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
DONOR_TEST = "tests/fgc/test_fgc14_external_accuracy_adapter.f90"
AUDIT = "integration/f-ci/F-CI46_ARCHITECTURE_AUDIT.json"


def run(*args, cwd=ROOT, capture=False):
    r = subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)
    return r.stdout.strip() if capture else ""


def require(condition, message):
    if not condition:
        raise SystemExit("FCI46_GATE_FAIL " + message)


def git_text(*args):
    return run("git", *args, capture=True)


def need_commit(sha):
    try:
        run("git", "cat-file", "-e", f"{sha}^{{commit}}")
    except subprocess.CalledProcessError:
        run("git", "fetch", "--no-tags", "origin", sha)
        run("git", "cat-file", "-e", f"{sha}^{{commit}}")


for sha in (BASE, COMPOSITION, FGC14):
    need_commit(sha)
run("git", "fetch", "--no-tags", "origin", "integration/f-ci-canonical")
canonical_head = git_text("rev-parse", "origin/integration/f-ci-canonical")
require(canonical_head == BASE, f"canonical race expected {BASE} got {canonical_head}")
require(git_text("rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "base tree drift")
print("FCI46_PREPROMOTION_CANONICAL_RACE_GUARD=PASS")

require(git_text("rev-parse", f"{COMPOSITION}^") == BASE, "composition is not direct child of canonical base")
require(git_text("rev-parse", f"{COMPOSITION}^{{tree}}") == COMPOSITION_TREE, "composition tree drift")
require(git_text("rev-parse", f"{COMPOSITION}:{MODULE}") == MODULE_BLOB, "composition module blob drift")
require(git_text("rev-parse", f"HEAD:{MODULE}") == MODULE_BLOB, "qualification governance changed admitted module")
run("git", "diff", "--quiet", COMPOSITION, "HEAD", "--", "src")
delta = [x for x in git_text("diff", "--name-only", BASE, COMPOSITION, "--", "src").splitlines() if x]
require(delta == [MODULE], "unexpected production delta: " + repr(delta))
run("git", "diff", "--quiet", BASE, COMPOSITION, "--", "reference")
print("FCI46_EXACT_ONE_BLOB_PRODUCTION_SCOPE=PASS")
print("FCI46_REFERENCE_IMMUTABLE=PASS")

require(git_text("rev-parse", f"{FGC14}:{MODULE}") == MODULE_BLOB, "F-GC14 donor module drift")
require(git_text("rev-parse", f"{FGC14}:integration/f-gc/F-GC14_CLOSEOUT.json") == FGC14_CLOSEOUT_BLOB, "F-GC14 closeout drift")
closeout = json.loads(git_text("show", f"{FGC14}:integration/f-gc/F-GC14_CLOSEOUT.json"))
require(closeout["decision"] == "QUALIFIED_TYPED_EXTERNAL_ACCURACY_RUNTIME_CONTRACT_ADAPTER_BOUNDARY_NO_CANONICAL_OR_PRODUCTION_ADMISSION", "F-GC14 decision mismatch")
require(closeout["canonical_admission"] is False, "F-GC14 canonical hold missing")
require(closeout["production_coupling_admission"] is False, "F-GC14 production coupling hold missing")
require(closeout["numeric_project_policy_qualified"] is False, "F-GC14 numeric policy hold missing")
require(closeout["mass_conservation_relaxed"] is False, "F-GC14 mass hold missing")
require(closeout["external_source_bytes_verified_by_adapter"] is False, "F-GC14 source-verification boundary drift")
print("FCI46_FGC14_AUTHORITY_PINNED=PASS")

require(git_text("rev-parse", f"HEAD:{CONTRACT}") == CONTRACT_BLOB, "canonical application contract drift")
adapter = (ROOT / MODULE).read_text(encoding="utf-8").lower()
contract = (ROOT / CONTRACT).read_text(encoding="utf-8").lower()
for forbidden in ("use mod_kernel", "use mod_transaction", "use mod_soil_water", "use mod_reference_richards"):
    require(forbidden not in adapter, "forbidden adapter dependency " + forbidden)
for required in (
    "fgc13_packet_validated = .false.",
    "application_source_digest_content_verified = .false.",
    "temporal_source_digest_content_verified = .false.",
    "contract = coupling_application_accuracy_contract_t()",
    "candidate%application_requirement_valid()",
    "candidate%temporal_allocation_valid()",
    "candidate%temporal_budget_ready()",
):
    require(required in adapter, "missing fail-closed binding " + required)
require("ieee_is_finite(self%h_app_cm)" in contract, "canonical H_app finite guard missing")
require("ieee_is_finite(self%a_temporal)" in contract, "canonical A_temporal finite guard missing")
print("FCI46_TYPED_FAIL_CLOSED_CONTRACT_BINDING=PASS")
print("FCI46_NONFINITE_GUARD_INHERITANCE=PASS")

with (ROOT / AUDIT).open(encoding="utf-8") as handle:
    audit = json.load(handle)
ids = [entry["id"] for entry in audit["invariants"]]
require(ids == list(range(1, 31)), "architecture audit does not cover invariants 1..30 exactly")
require(all(entry["result"] in {"PASS", "PASS_WITH_SCOPE", "PASS_STRUCTURAL", "NO_ADVERSE_DELTA"} for entry in audit["invariants"]), "architecture audit contains non-passing result")
print("FCI46_ARCHITECTURE_INVARIANTS_30_OF_30=PASS")

run("git", "diff", "--check", BASE, "--", "src", "tests/fci", "integration/f-ci", ".github/workflows")
print("FCI46_DIFF_CHECK=PASS")

common = ["-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow"]
with tempfile.TemporaryDirectory(prefix="swap5-fci46-") as td:
    root = Path(td)
    donor_test = root / "donor_test.f90"
    donor_test.write_text(git_text("show", f"{FGC14}:{DONOR_TEST}") + "\n", encoding="utf-8")

    def build_and_run(opt, name):
        out = root / name
        out.mkdir()
        units = [
            ("src/transaction/mod_transaction_reference.f90", "transaction.o", False),
            ("src/runtime/mod_canonical_contracts.f90", "contracts.o", False),
            (CONTRACT, "contract.o", True),
            (MODULE, "adapter.o", True),
            (str(donor_test), "test.o", True),
        ]
        for source, obj, strict in units:
            cmd = ["gfortran", *common]
            if strict:
                cmd.append("-Werror")
            cmd += [opt, "-J", str(out), "-I", str(out), "-c", source, "-o", str(out / obj)]
            run(*cmd)
        exe = out / "fci46.exe"
        run("gfortran", opt, *(str(out / obj) for _, obj, _ in units), "-o", str(exe))
        first = subprocess.run([str(exe)], cwd=ROOT, check=True, text=True, capture_output=True).stdout
        second = subprocess.run([str(exe)], cwd=ROOT, check=True, text=True, capture_output=True).stdout
        require(first == second, f"repeated-run nondeterminism {opt}")
        return first

    o0 = build_and_run("-O0", "o0")
    o2 = build_and_run("-O2", "o2")
    require(o0 == o2, "O0/O2 output drift")
    print(o0, end="")

print("FCI46_EXACT_FGC14_EXECUTABLE_REPLAY=PASS")
print("FCI46_REPEATED_RUN_DETERMINISM_O0_O2=PASS")
print("FCI46_NUMERIC_H_APP=NOT_SET")
print("FCI46_NUMERIC_A_TEMPORAL=NOT_SET")
print("FCI46_EXTERNAL_SOURCE_BYTES_VERIFIED_BY_ADAPTER=NO")
print("FCI46_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE")
print("FCI46_MASS_CONSERVATION_RELAXED=NO")
print("FCI46_CANONICAL_ADMISSION_GATE=PASS")
