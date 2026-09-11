#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "492b984bca282d6ec11dcaa727227b34c0ff3a84"
BASE_TREE = "51e9b59f7ffe6c1a66d9fdf59b63ae78e91e8136"
REGISTRY = Path("docs/scientific/registries/rb1-time-reference-t11-traceability.json")
DOC = Path("docs/scientific/F-DOC08_RB1_TIME_REFERENCE_T11_TRACEABILITY.md")
AUDIT = Path("integration/f-doc/F-DOC08_INVARIANT_AUDIT.json")
STATUS = Path("integration/f-doc/F-DOC08_STATUS.json")
CLOSEOUT = Path("integration/f-doc/F-DOC08_CLOSEOUT.json")
EVIDENCE = Path("_fdoc08_t11_evidence.json")

ALLOWED = {
    ".github/workflows/fdoc08-rb1-time-reference-t11-traceability.yml",
    "docs/scientific/F-DOC08_RB1_TIME_REFERENCE_T11_TRACEABILITY.md",
    "docs/scientific/registries/rb1-time-reference-t11-traceability.json",
    "integration/f-doc/F-DOC08_INVARIANT_AUDIT.json",
    "integration/f-doc/F-DOC08_STATUS.json",
    "integration/f-doc/F-DOC08_CLOSEOUT.json",
    "tools/docs/validate_fdoc08_rb1_time_reference_t11_traceability.py",
}

BLOB_LOCKS = [
    ("a703747ce1991c5601b76a84f04969b602298268", "docs/scientific/registries/rb1-reference-temporal-traceability.json", "de9690e061ef6f28cc3a786ab474644ffbec3990"),
    ("df9b1123ba33ece022ce6649e70dcb538e44837f", "integration/f-vq/F-VQ34_CLOSEOUT.json", "2bf2c2e790abac2ee4dc3cd6ee51c5e579859270"),
    ("df9b1123ba33ece022ce6649e70dcb538e44837f", "integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json", "4f3f7c8883397ed96d3af2f6585f25698c58e7b4"),
    ("df9b1123ba33ece022ce6649e70dcb538e44837f", "tests/fvq/run_fvq34_remediated_head_budget_certificate.sh", "d72403e00ad1a1a9cb69fac89cc680e3dc847262"),
    ("697755068253cfb5a2f838c63894e1609a85ff51", "integration/f-ci/F-CI21_CLOSEOUT.json", "57f670c02a58cd21fc442a076c7a2ad06087254a"),
    ("697755068253cfb5a2f838c63894e1609a85ff51", "integration/f-ci/F-CI21_VQ34_REMEDIATED_CERTIFICATE_REPLAY_EVIDENCE.json", "578fbfdd2a2b137a4119335beb648af0e90d283c"),
    ("aeb74560d801c4ac7314df7b8845fcc5daf8bba6", "tests/frb01/run_frb01_temporal_authority.sh", "4e3a789f649a5b427a3fe0d89d01f09dc7277cfe"),
]


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def require(condition, message):
    if not condition:
        raise SystemExit(f"FDOC08_FAIL {message}")


def load_json(path):
    with path.open() as f:
        return json.load(f)


head = git("rev-parse", "HEAD")
require(git("rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "F-DOC07 base tree drift")
require(git("merge-base", BASE, "HEAD") == BASE, "branch is not descended exactly from F-DOC07 base")

changed = [x for x in git("diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
unexpected = sorted(set(changed) - ALLOWED)
require(not unexpected, f"unbounded changed paths: {unexpected}")
require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{BASE}:src"), "production src tree changed")
require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{BASE}:reference"), "reference tree changed")
print("FDOC08_ZERO_PRODUCTION_SOURCE_DELTA=PASS")
print("FDOC08_ZERO_REFERENCE_DELTA=PASS")

for commit, path, expected in BLOB_LOCKS:
    actual = git("rev-parse", f"{commit}:{path}")
    require(actual == expected, f"authority blob drift {commit}:{path}: {actual} != {expected}")
require(git("cat-file", "-t", "d81ef430ebaa601469a165dfc5b9866b813b71aa") == "commit", "F-CI40 commit missing")
print("FDOC08_EXACT_AUTHORITY_BLOBS=PASS")

r = load_json(REGISTRY)
require(r["work_unit"] == "F-DOC08", "registry work unit")
require(r["base_authority"]["commit"] == BASE and r["base_authority"]["tree"] == BASE_TREE, "base authority lock")
require(r["capability"] == "RB1-TIME-REFERENCE", "wrong capability")
require(r["traceability_level"] == "T11_BOUNDED_TEMPORAL_ACCEPTANCE_SEMANTICS", "wrong traceability level")

a = r["authorities"]
require(a["F_VQ34"]["tested_head"] == "31e3f85ae83fe8bab9554da5467de0598446c0bd", "F-VQ34 tested head")
require(a["F_VQ34"]["workflow_run"] == 34364081068, "F-VQ34 workflow run")
require(a["F_CI21"]["materialized_production_source_commit"] == "a0331164a8dfc2642becdbe96cab969eabead392", "F-CI21 materialized source")
require(a["F_CI40"]["current_temporal_dependency_authority_commit"] == "d81ef430ebaa601469a165dfc5b9866b813b71aa", "F-CI40 lock")
require(a["F_RB01"]["commit"] == "aeb74560d801c4ac7314df7b8845fcc5daf8bba6", "F-RB01 lock")

rels = {x["id"]: x for x in r["relation_nodes"]}
tests = {x["id"]: x for x in r["test_nodes"]}
require(set(rels) == {f"R{i:02d}" for i in range(1, 9)}, "relation node set")
require(set(tests) == {f"T{i:02d}" for i in range(1, 9)}, "test node set")
require(rels["R01"]["relation"] == "C_h = B_inf / H_budget", "formula drift")
require("finite and > 0" in rels["R02"]["relation"], "budget validity drift")
require("C_h <= 1" in rels["R04"]["relation"], "acceptance boundary drift")
require("mass rejection precedes" in rels["R06"]["relation"], "mass precedence drift")

mapped = set()
for edge in r["edges"]:
    require(edge["relation"] in rels, f"unknown relation edge {edge}")
    require(edge["tests"], f"empty test edge {edge['relation']}")
    for tid in edge["tests"]:
        require(tid in tests, f"unknown test node {tid}")
    mapped.add(edge["relation"])
require(mapped == set(rels), "not every bounded relation has a test edge")
require(r["coverage"]["bounded_relation_nodes"] == 8, "bounded relation count")
require(r["coverage"]["nodes_with_test_edges"] == 8, "mapped relation count")
require(r["coverage"]["unmapped_bounded_relation_nodes"] == 0, "unmapped relation nodes")
require(r["coverage"]["t11_bounded_temporal_acceptance_graph_complete"] is True, "bounded T11 not complete")
require(r["coverage"]["t11_universal_application_accuracy_graph_complete"] is False, "universal application T11 must remain open")

require(tests["T01"]["cases"] == [1, 2, 10, 11, 12], "accept/reject case mapping")
require(tests["T02"]["cases"] == [3, 4, 7, 8, 9], "invalid budget case mapping")
require(tests["T03"]["case"] == 5, "no-history case mapping")
require(tests["T04"]["case"] == 6, "bounded retry case mapping")
require(r["negative_evidence"]["F_VQ33_remains_failed"] is True, "F-VQ33 failure not preserved")
require(r["negative_evidence"]["F_VQ33_used_as_positive_evidence"] is False, "F-VQ33 illegally positive")

nonclaims = "\n".join(r["hard_nonclaims"])
for required in [
    "No numeric H_budget",
    "No universal temporal tolerance",
    "No shorter-dt monotonicity claim",
    "No production source",
    "does not establish Status A or Status AA",
    "does not close T12",
    "does not close the controlled WR-QA-2024",
]:
    require(required in nonclaims, f"missing hard nonclaim: {required}")
print("FDOC08_BOUNDED_T11_GRAPH=PASS")
print("FDOC08_NO_UNIVERSAL_H_BUDGET_CLAIM=PASS")
print("FDOC08_FVQ33_NEGATIVE_EVIDENCE_LOCK=PASS")

text = DOC.read_text()
for token in [
    "C_h = B_inf / H_budget",
    "C_h <= 1",
    "F-VQ33 remains failed",
    "No value or selection rule for `H_budget` is introduced",
    "Mass conservation remains hard and unchanged",
]:
    require(token in text, f"documentation sentinel missing: {token}")

if AUDIT.exists():
    audit = load_json(AUDIT)
    require(audit["work_unit"] == "F-DOC08", "audit work unit")
    require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "invariant audit overall")
    inv = audit["invariants"]
    require(len(inv) == 30, "invariant audit must contain 30 entries")
    require([x["id"] for x in inv] == list(range(1, 31)), "invariant ids must be 1..30")
    require(all(x["status"] == "PASS" for x in inv), "all invariants must PASS")
    require(audit["mass_conservation"] == "HARD_UNCHANGED", "mass conservation audit")
    print("FDOC08_INVARIANT_AUDIT_30_OF_30=PASS")

if STATUS.exists():
    s = load_json(STATUS)
    require(s["work_unit"] == "F-DOC08", "status work unit")
    require(s["decision"] == "QUALIFIED_BOUNDED_RB1_TIME_REFERENCE_T11_RELATION_TO_TEST_GRAPH", "status decision")
    require(s["scope"]["bounded_t11_graph_complete"] is True, "status bounded T11")
    require(s["scope"]["universal_application_accuracy_t11_complete"] is False, "status universal T11")
    require(s["work_state"]["scientific_scope_reopened"] is False, "scientific scope reopened")

if CLOSEOUT.exists():
    c = load_json(CLOSEOUT)
    require(c["work_unit"] == "F-DOC08", "closeout work unit")
    require(c["decision"] == "QUALIFIED_BOUNDED_RB1_TIME_REFERENCE_T11_RELATION_TO_TEST_GRAPH", "closeout decision")
    require(c["finality_rule"].startswith("Final only when"), "closeout finality rule")

out = {
    "work_unit": "F-DOC08",
    "head": head,
    "base": BASE,
    "changed_paths": changed,
    "changed_path_count": len(changed),
    "src_tree_unchanged": True,
    "reference_tree_unchanged": True,
    "exact_authority_blobs": "PASS",
    "bounded_relation_nodes": 8,
    "mapped_relation_nodes": 8,
    "bounded_t11_graph_complete": True,
    "universal_application_accuracy_t11_complete": False,
    "F_VQ33_remains_negative": True,
    "mass_conservation": "HARD_UNCHANGED",
    "status_present": STATUS.exists(),
    "closeout_present": CLOSEOUT.exists(),
}
EVIDENCE.write_text(json.dumps(out, indent=2) + "\n")
print("FDOC08_VALIDATION=PASS")
