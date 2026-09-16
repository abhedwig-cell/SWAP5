#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OLD_CANONICAL = "c7379b6b5b5f529ff96de3087379712bd665276a"
PROMOTED = "c65471e544b5fa25ab13f944b9db13bd47fba8fa"
PROMOTED_TREE = "46f56a4f22c64fc4a1ae68668182098a8153df8b"
FCI46 = "f87c1ec05293f43f60e87c6436a0f6cf5e2041df"
FGC14 = "6d91bedc305504cc2fa08b196e6a9903c48c9461"
MODULE = "src/runtime/mod_coupling_application_accuracy_adapter.f90"
MODULE_BLOB = "9212d600e89c85287e9280832c7e0a94befb642e"
CONTRACT = "src/runtime/mod_coupling_application_accuracy_contract.f90"
CONTRACT_BLOB = "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
STATUS_BLOB = "3c49657ad84294c4c48e080dba3726bdd3f1734a"
AUDIT_BLOB = "0aa0654c1057e20c3be1ed82ed6e0a106c71ba66"
DONOR_TEST = "tests/fgc/test_fgc14_external_accuracy_adapter.f90"


def run(*args, cwd=ROOT, capture=False):
    r = subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)
    return r.stdout.strip() if capture else ""


def require(condition, message):
    if not condition:
        raise SystemExit("FCI46P_GATE_FAIL " + message)


def git_text(*args):
    return run("git", *args, capture=True)


for sha in (OLD_CANONICAL, PROMOTED, FCI46, FGC14):
    try:
        run("git", "cat-file", "-e", f"{sha}^{{commit}}")
    except subprocess.CalledProcessError:
        run("git", "fetch", "--no-tags", "origin", sha)
run("git", "fetch", "--no-tags", "origin", "integration/f-ci-canonical")
require(git_text("rev-parse", "origin/integration/f-ci-canonical") == PROMOTED, "canonical moved during reconciliation")
require(git_text("rev-parse", f"{PROMOTED}^{{tree}}") == PROMOTED_TREE, "promoted tree drift")
require(git_text("rev-parse", f"{PROMOTED}:reference") == git_text("rev-parse", f"{OLD_CANONICAL}:reference"), "reference tree drift")
print("FCI46P_CURRENT_CANONICAL_PIN=PASS")

parents = git_text("rev-list", "--parents", "-n1", PROMOTED).split()
require(parents == [PROMOTED, OLD_CANONICAL, FCI46], "promotion is not exact declared two-parent merge: " + repr(parents))
print("FCI46P_TRUE_TWO_PARENT_PROMOTION=PASS")

delta = [x for x in git_text("diff", "--name-only", OLD_CANONICAL, PROMOTED, "--", "src").splitlines() if x]
require(delta == [MODULE], "unexpected promoted src delta: " + repr(delta))
require(git_text("rev-parse", f"{PROMOTED}:{MODULE}") == MODULE_BLOB, "promoted module blob drift")
require(git_text("rev-parse", f"HEAD:{MODULE}") == MODULE_BLOB, "reconciliation changed module blob")
run("git", "diff", "--quiet", PROMOTED, "HEAD", "--", "src")
run("git", "diff", "--quiet", PROMOTED, "HEAD", "--", "reference")
print("FCI46P_EXACT_ONE_BLOB_PROMOTED_SOURCE_SCOPE=PASS")
print("FCI46P_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS")

require(git_text("rev-parse", f"{PROMOTED}:integration/f-ci/F-CI46_STATUS.json") == STATUS_BLOB, "F-CI46 status drift")
require(git_text("rev-parse", f"{PROMOTED}:integration/f-ci/F-CI46_ARCHITECTURE_AUDIT.json") == AUDIT_BLOB, "F-CI46 audit drift")
status = json.loads(git_text("show", f"{PROMOTED}:integration/f-ci/F-CI46_STATUS.json"))
require(status["decision"] == "QUALIFIED_FGC14_EXTERNAL_ACCURACY_RUNTIME_ADAPTER_FOR_CURRENT_CANONICAL_ADMISSION", "F-CI46 decision missing")
require(status["state"]["numeric_application_policy_added"] is False, "numeric policy hold drift")
require(status["state"]["production_coupling_admitted"] is False, "production coupling hold drift")
print("FCI46P_FCI46_AUTHORITY_PRESERVED=PASS")

require(git_text("rev-parse", f"{PROMOTED}:{CONTRACT}") == CONTRACT_BLOB, "application contract drift")
contract = (ROOT / CONTRACT).read_text(encoding="utf-8").lower()
adapter = (ROOT / MODULE).read_text(encoding="utf-8").lower()
require("ieee_is_finite(self%h_app_cm)" in contract, "finite H_app guard missing")
require("ieee_is_finite(self%a_temporal)" in contract, "finite A_temporal guard missing")
for required in (
    "fgc13_packet_validated = .false.",
    "application_source_digest_content_verified = .false.",
    "temporal_source_digest_content_verified = .false.",
    "contract = coupling_application_accuracy_contract_t()",
    "candidate%application_requirement_valid()",
    "candidate%temporal_allocation_valid()",
    "candidate%temporal_budget_ready()",
):
    require(required in adapter, "postimage fail-closed binding missing " + required)
print("FCI46P_FAIL_CLOSED_BINDING_PRESERVED=PASS")
print("FCI46P_NONFINITE_GUARD_INHERITANCE_PRESERVED=PASS")

allowed_exact = {
    "tests/fci/run_fci46p_current_canonical_postimage_reconciliation.py",
    ".github/workflows/fci46p-current-canonical-postimage-reconciliation.yml",
}
branch_delta = [x for x in git_text("diff", "--name-only", PROMOTED, "HEAD").splitlines() if x]
for path in branch_delta:
    require(path in allowed_exact or (path.startswith("integration/f-ci/F-CI46P_") and path.endswith(".json")), "unexpected reconciliation delta: " + path)
print("FCI46P_RECONCILIATION_SCOPE=PASS")
run("git", "diff", "--check", PROMOTED, "--", "tests/fci", "integration/f-ci", ".github/workflows")
print("FCI46P_DIFF_CHECK=PASS")

common = ["-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow"]
with tempfile.TemporaryDirectory(prefix="swap5-fci46p-") as td:
    root = Path(td)
    donor_test = root / "donor_test.f90"
    donor_test.write_text(git_text("show", f"{FGC14}:{DONOR_TEST}") + "\n", encoding="utf-8")

    def replay(opt, name):
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
        exe = out / "fci46p.exe"
        run("gfortran", opt, *(str(out / obj) for _, obj, _ in units), "-o", str(exe))
        first = subprocess.run([str(exe)], cwd=ROOT, check=True, text=True, capture_output=True).stdout
        second = subprocess.run([str(exe)], cwd=ROOT, check=True, text=True, capture_output=True).stdout
        require(first == second, f"repeated-run nondeterminism {opt}")
        return first

    o0 = replay("-O0", "o0")
    o2 = replay("-O2", "o2")
    require(o0 == o2, "O0/O2 output drift")
    print(o0, end="")

print("FCI46P_EXACT_FGC14_EXECUTABLE_REPLAY=PASS")
print("FCI46P_REPEATED_RUN_DETERMINISM_O0_O2=PASS")
print("FCI46P_NUMERIC_H_APP=NOT_SET")
print("FCI46P_NUMERIC_A_TEMPORAL=NOT_SET")
print("FCI46P_EXTERNAL_SOURCE_BYTES_VERIFIED_BY_ADAPTER=NO")
print("FCI46P_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE")
print("FCI46P_MASS_CONSERVATION_RELAXED=NO")
print("FCI46P_POSTIMAGE_RECONCILIATION_GATE=PASS")
