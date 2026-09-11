#!/usr/bin/env python3
"""Fail-closed F-TB03 validator.

F-TB03 permanently adopts bounded RB1 release fragments into the SWAP5
release-qualification bank. It does not requalify science, retune tolerances,
or turn an immutable historical release into moving-current authority.
"""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "549531e2e233cccab1416dba04edb266653a5da5"
FTB01 = "1d039292d5768496c4550a8e1b35a92c6f836504"
FTB01_TREE = "217ad406db38b564a8b03e6c34c26b9123b58c6c"
FTB02_TREE = "13b1f3be0771f05bfa4ba21bca9d820df1e3b5f6"
SCI = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SCI_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
SRC_TREE = "8ceeb70a64012631ebba295f5c045ea908b0681f"
REF_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
QUAL = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
QUAL_TREE = "71a5b96f550b21567685884b5405b43820f865bf"
META = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
META_TREE = "9fd636cb35503d59654495186c9b4ec33287f344"
META_CLOSEOUT_BLOB = "e20dd5744c5717397339af5d14935b41e4ff90c7"
FMQ29 = "5ea88d81a63e6c706c87e99ac360f91f08711fc1"
FMQ29_MATRIX_BLOB = "d080220c26f390eb08d6f32a64af685ec1c50746"
FMQ30 = "48ee2841d783ee023c29391a7ea1e5d7ee0d20e0"
FMQ30_MATRIX_BLOB = "40b45112f0e14accbcc08c015b988f39bf376eb7"
FPE11_BLOB = "f3068802d4428e6941bef6e76a65d78c2e3d264d"
CROSSWALK_BLOB = "e47deeb03e58825deab3331ab4b5f293a65dec71"
AUDIT_BLOB = "ea9ac771a47e9d165af0e3a5ab445b23578b9160"
MANIFEST = ROOT / "testbank/manifests/F-TB03_RB1_RELEASE_BANK.json"
SCHEMA = ROOT / "testbank/schema/F-TB01_CASE_REGISTRY.schema.json"
CASE_ID = re.compile(r"^SWAP5-TB-[A-Z0-9_-]+-[0-9]{3,5}-v[1-9][0-9]*$")

EXPECTED = {
    "SWAP5-TB-RELEASE-PARALLEL-RESTART-0001-v1": {
        "predecessor": "FRB01-RELEASE-PARALLEL-RESTART-0001-v1",
        "maturity": "INDEPENDENTLY_QUALIFIED",
        "tolerance": "INHERITED_PINNED_AUTHORITY",
        "mass": "REQUIRED",
    },
    "SWAP5-TB-RELEASE-PARALLEL-ROOT-0001-v1": {
        "predecessor": "FRB01-RELEASE-PARALLEL-ROOT-0001-v1",
        "maturity": "INDEPENDENTLY_QUALIFIED",
        "tolerance": "INHERITED_PINNED_AUTHORITY",
        "mass": "REQUIRED",
    },
    "SWAP5-TB-RELEASE-SURFACE-EVAP-0001-v1": {
        "predecessor": "FRB01-RELEASE-SURFACE-EVAP-0001-v1",
        "maturity": "INDEPENDENTLY_QUALIFIED",
        "tolerance": "INHERITED_PINNED_AUTHORITY",
        "mass": "INHERITED_EXACT_AUTHORITY",
    },
    "SWAP5-TB-RELEASE-ARCHITECTURE-0001-v1": {
        "predecessor": "FRB01-RELEASE-ARCHITECTURE-0001-v1",
        "maturity": "RELEASE_MANDATORY",
        "tolerance": "EXACT_OR_HARD_ONLY",
        "mass": "NOT_WATER_BEARING",
    },
}

ALLOWED_PREFIXES = (
    ".github/workflows/ftb03-",
    "docs/testbank/F-TB03",
    "integration/f-tb/F-TB03",
    "testbank/manifests/F-TB03",
    "testbank/runners/validate_ftb03_",
)


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def need_commit(sha: str) -> None:
    try:
        subprocess.check_call(["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        subprocess.check_call(["git", "fetch", "--no-tags", "origin", sha], cwd=ROOT,
                              stdout=subprocess.DEVNULL)


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FTB03_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FTB03_{marker}=PASS")


def json_at(commit: str, path: str):
    return json.loads(sh("git", "show", f"{commit}:{path}"))


for commit in (BASE, FTB01, SCI, QUAL, META, FMQ29, FMQ30):
    need_commit(commit)

manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
head = sh("git", "rev-parse", "HEAD")
head_tree = sh("git", "rev-parse", "HEAD^{tree}")

require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FTB02_BASE_ANCESTRY")
require(sh("git", "rev-parse", f"{FTB01}^{{tree}}") == FTB01_TREE, "FTB01_ARCHITECTURE_TREE")
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == FTB02_TREE, "FTB02_AUTHORITY_TREE")
require(sh("git", "rev-parse", f"{SCI}^{{tree}}") == SCI_TREE, "RB1_SCIENTIFIC_TREE")
require(sh("git", "rev-parse", f"{SCI}:src") == SRC_TREE, "RB1_SCIENTIFIC_SRC_TREE")
require(sh("git", "rev-parse", f"{SCI}:reference") == REF_TREE, "RB1_SCIENTIFIC_REFERENCE_TREE")
require(sh("git", "rev-parse", f"{QUAL}^{{tree}}") == QUAL_TREE, "RB1_QUALIFICATION_TREE")
require(sh("git", "rev-parse", f"{META}^{{tree}}") == META_TREE, "RB1_METADATA_TREE")
require(sh("git", "rev-parse", f"{META}:release/f-rb02/F-RB02_CLOSEOUT.json") == META_CLOSEOUT_BLOB,
        "RB1_METADATA_CLOSEOUT_BLOB")
require(sh("git", "rev-parse", f"{META}:release/f-rb01/RB1_TESTBANK_CROSSWALK.json") == CROSSWALK_BLOB,
        "RB1_TESTBANK_CROSSWALK_BLOB")
require(sh("git", "rev-parse", f"{QUAL}:release/f-rb01/RB1_ARCHITECTURE_INVARIANT_AUDIT.json") == AUDIT_BLOB,
        "RB1_ARCHITECTURE_AUDIT_BLOB")
require(sh("git", "rev-parse", f"{FMQ29}:integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json") == FMQ29_MATRIX_BLOB,
        "FMQ29_MATRIX_BLOB")
require(sh("git", "rev-parse", f"{FMQ30}:integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json") == FMQ30_MATRIX_BLOB,
        "FMQ30_MATRIX_BLOB")
require(sh("git", "rev-parse", f"{SCI}:tests/fpe/run_fpe11_surface_evaporation_allocation_qualification.sh") == FPE11_BLOB,
        "FPE11_RUNNER_BLOB")

# F-TB03 must be governance/testbank-only relative to its exact F-TB02 base.
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED_PREFIXES),
            "GOVERNANCE_ONLY_" + path.replace("/", "_").replace(".", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

require(manifest.get("schema_version") == "1.0", "MANIFEST_SCHEMA")
require(manifest.get("work_unit") == "F-TB03", "WORK_UNIT")
require(manifest.get("registry_id") == "F-TB03-RB1_RELEASE_BANK_FRAGMENT", "REGISTRY_ID")
require(manifest.get("architecture_authority", {}).get("commit") == FTB01, "MANIFEST_FTB01_AUTHORITY")
require(manifest.get("upstream_catalog_authority", {}).get("commit") == BASE, "MANIFEST_FTB02_AUTHORITY")
rb = manifest.get("rb1_authorities", {})
require(rb.get("scientific_source", {}).get("commit") == SCI, "MANIFEST_RB1_SCIENTIFIC_AUTHORITY")
require(rb.get("qualification", {}).get("commit") == QUAL, "MANIFEST_RB1_QUALIFICATION_AUTHORITY")
require(rb.get("release_metadata", {}).get("commit") == META, "MANIFEST_RB1_METADATA_AUTHORITY")
policy = manifest.get("adoption_policy", {})
for key in ("scientific_requalification_performed", "historical_oracles_reinterpreted", "tolerances_changed",
            "production_source_changed", "reference_changed", "central_ftb01_poc_registry_rewritten",
            "moving_current_preservation_claim"):
    require(policy.get(key) is False, "POLICY_FALSE_" + key.upper())
require(policy.get("future_canonical_rebinding_requires_separate_qualification") is True,
        "FUTURE_REBINDING_SEPARATE_QUALIFICATION")

# Crosswalk must still expose exactly the four bounded fragments as pending adoption.
crosswalk = json_at(META, "release/f-rb01/RB1_TESTBANK_CROSSWALK.json")
pending = {
    x["rb1_fragment_id"]: x["relationship"]
    for x in crosswalk["crosswalk"] if x.get("rb1_fragment_id")
}
require(set(pending) == {v["predecessor"] for v in EXPECTED.values()}, "EXACT_FOUR_PRECURSOR_FRAGMENTS")
require(set(pending.values()) == {"BOUNDED_RELEASE_FRAGMENT_PENDING_FTB_ADOPTION"}, "PRECURSOR_DISPOSITION")

# Use the F-TB01 schema itself as the structural contract, without inheriting
# the F-TB01 POC validator's intentionally older frozen source authority.
case_schema = schema["properties"]["cases"]["items"]
required_keys = set(case_schema["required"])
cases = manifest.get("cases")
require(isinstance(cases, list) and len(cases) == 4, "EXACT_FOUR_RELEASE_CASES")
require({c.get("case_id") for c in cases} == set(EXPECTED), "STABLE_RELEASE_CASE_IDS")
for c in cases:
    cid = c["case_id"]
    exp = EXPECTED[cid]
    require(set(c) == required_keys, "RICH_METADATA_" + cid)
    require(CASE_ID.fullmatch(cid) is not None and c["version"] == 1, "CASE_ID_VERSION_" + cid)
    require(c["layer"] == "TB-L12" and c["category"] == "RELEASE", "L12_RELEASE_" + cid)
    require(c["artifact_kind"] in {"QUALIFICATION_EVIDENCE", "GOVERNANCE_REPLAY"}, "ARTIFACT_KIND_" + cid)
    require(c["admission_purpose"] == "BROAD_RELEASE_REGRESSION", "PURPOSE_" + cid)
    require(c["maturity"] == exp["maturity"], "MATURITY_" + cid)
    require(c["profiles"] == ["RELEASE"], "PROFILE_" + cid)
    require(c["requiredness"] == {"mandatory_profiles": ["RELEASE"], "optional_profiles": []}, "REQUIREDNESS_" + cid)
    require(c["current_preservation_eligible"] is False, "IMMUTABLE_NOT_MOVING_CURRENT_" + cid)
    require(c["lineage"]["predecessor"] == exp["predecessor"], "PREDECESSOR_" + cid)
    require(c["mass_gate"] == exp["mass"], "MASS_GATE_" + cid)
    tp = c["tolerance_policy"]
    require(tp["mode"] == exp["tolerance"], "TOLERANCE_MODE_" + cid)
    require(tp["bindings"] == [], "NO_NEW_TOLERANCE_BINDINGS_" + cid)
    if tp["mode"] == "INHERITED_PINNED_AUTHORITY":
        require(isinstance(tp["inheritance_authority"], str) and tp["inheritance_authority"],
                "PINNED_TOLERANCE_AUTHORITY_" + cid)
        require(c["maturity"] != "RELEASE_MANDATORY", "NO_PINNED_TOLERANCE_PROMOTION_" + cid)
    else:
        require(tp["inheritance_authority"] is None, "HARD_ONLY_NO_SOFT_AUTHORITY_" + cid)
    require(isinstance(c["negative_paths"], list) and c["negative_paths"], "NEGATIVE_PATHS_" + cid)
    require(isinstance(c["invariants"], list) and c["invariants"], "INVARIANTS_" + cid)
    sa = c["source_authority"]
    need_commit(sa["commit"])
    require(sh("git", "rev-parse", f"{sa['commit']}^{{tree}}") == sa["tree"], "SOURCE_TREE_" + cid)
    require(sh("git", "cat-file", "-t", f"{sa['commit']}:{sa['path']}") == "blob", "SOURCE_PATH_" + cid)
    require(sa["path"] == c["provenance"]["primary_path"], "PROVENANCE_PATH_" + cid)
    for authority_key in ("test_matrix_authority", "evidence_authority", "governance_authority"):
        require(c[authority_key].get("requalified_by_ftb01") is False,
                "NO_FTB01_REQUALIFICATION_" + authority_key.upper() + "_" + cid)

arch = next(c for c in cases if c["case_id"] == "SWAP5-TB-RELEASE-ARCHITECTURE-0001-v1")
require(arch["invariants"] == list(range(1, 31)), "ARCHITECTURE_ALL_30")

fmq29 = json_at(FMQ29, "integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json")
fmq30 = json_at(FMQ30, "integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json")
require(fmq29["hard_mass_gate_cm"] == 1e-12 and set(fmq29["continuation_workers"]) == {2, 4}, "FMQ29_PINNED_HARD_GATES")
require(fmq30["hard_mass_gate_cm"] == 1e-12 and set(fmq30["workers"]) == {2, 4}, "FMQ30_PINNED_HARD_GATES")

closeout = json_at(META, "release/f-rb02/F-RB02_CLOSEOUT.json")
require(closeout["decision"] == "QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_RELEASE_AUTHORITY_ESTABLISHED",
        "RB1_RELEASE_AUTHORITY_DECISION")
require(closeout["immutability"]["scientific_authority_reopened"] is False, "RB1_SCIENCE_REMAINS_CLOSED")

nonclaims = "\n".join(manifest.get("nonclaims", [])).lower()
require("status a or status aa" in nonclaims, "NO_STATUS_A_AA_CLAIM")
require("rossfast" in nonclaims, "NO_ROSSFAST_CLAIM")
require("throughput/scaling" in nonclaims, "SURFACE_EVAP_THROUGHPUT_NONCLAIM")

report = {
    "schema": "swap5.ftb03_exact_head_evidence.v1",
    "head_sha": head,
    "head_tree": head_tree,
    "base_ftb02": BASE,
    "rb1_scientific_source": SCI,
    "rb1_qualification_authority": QUAL,
    "rb1_release_metadata_authority": META,
    "registered_release_cases": sorted(EXPECTED),
    "changed_paths_since_ftb02": changed,
    "scientific_requalification_performed": False,
    "zero_production_delta": True,
    "zero_reference_delta": True,
    "moving_current_preservation_claim": False,
}
(ROOT / "_ftb03_release_bank_evidence.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"FTB03_EXACT_HEAD_SHA={head}")
print(f"FTB03_EXACT_HEAD_TREE={head_tree}")
print("FTB03_REGISTERED_RELEASE_CASES=4")
print("FTB03_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_RB1_RELEASE_BANK_FRAGMENT_PERMANENTLY_ADOPTED")
