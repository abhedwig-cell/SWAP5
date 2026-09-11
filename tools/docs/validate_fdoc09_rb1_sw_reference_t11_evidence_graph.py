#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "8e5863510004ec11ab377b5bc9d3bd5df6d69777"
BASE_TREE = "baad1220494f5f42a25c112736d6157b3c2030da"
CANONICAL = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
REGISTRY = Path("docs/scientific/registries/rb1-sw-reference-t11-evidence-graph.json")
DOC = Path("docs/scientific/F-DOC09_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH.md")
AUDIT = Path("integration/f-doc/F-DOC09_INVARIANT_AUDIT.json")
STATUS = Path("integration/f-doc/F-DOC09_STATUS.json")
CLOSEOUT = Path("integration/f-doc/F-DOC09_CLOSEOUT.json")
EVIDENCE = Path("_fdoc09_sw_reference_t11_evidence.json")

ALLOWED = {
    ".github/workflows/fdoc09-rb1-sw-reference-t11-evidence-graph.yml",
    "docs/scientific/F-DOC09_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH.md",
    "docs/scientific/registries/rb1-sw-reference-t11-evidence-graph.json",
    "integration/f-doc/F-DOC09_INVARIANT_AUDIT.json",
    "integration/f-doc/F-DOC09_STATUS.json",
    "integration/f-doc/F-DOC09_CLOSEOUT.json",
    "tools/docs/validate_fdoc09_rb1_sw_reference_t11_evidence_graph.py",
}

BLOB_LOCKS = [
    ("a703747ce1991c5601b76a84f04969b602298268", "docs/scientific/registries/rb1-reference-temporal-traceability.json", "de9690e061ef6f28cc3a786ab474644ffbec3990"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI13_QUALIFICATION.json", "f9a1dda7819f6b769e8b7cd9ac0319af436e0499"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI14_QUALIFICATION.json", "a54aa26e6cfac710648f876a619da7f84ab3d0d5"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI15_QUALIFICATION.json", "9dd06140d624c18d1a282bf10a30c737f61ab1ea"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI16_QUALIFICATION.json", "7ee1b26a7ccdf6c4ae0d2b6c95a44a984e80fc57"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI18_STATUS.json", "ba36fc155c769beea5d2829211b88feb3c628323"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI18_REFERENCE_TRIDAG_EVIDENCE.json", "bf433c7adff71ce9d10463d53a55a92fe4599655"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI19_STATUS.json", "14f6458d87c518f38206de68a91305c0d37b0408"),
    ("d3a1bc8eef243b6109af8871398c06e1840fb367", "integration/f-si/F-SI19_QUALIFICATION_EVIDENCE.json", "b60be218fffc2255087b7bbb636745d99d6c8df9"),
    ("aeb74560d801c4ac7314df7b8845fcc5daf8bba6", "tests/frb01/run_frb01_release_qualification.sh", "fce077b67d9dfed4e8889894615dab37c97ebb0f"),
]


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def require(condition, message):
    if not condition:
        raise SystemExit(f"FDOC09_FAIL {message}")


def load_json(path):
    with path.open() as f:
        return json.load(f)


head = git("rev-parse", "HEAD")
require(git("rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "F-DOC08 base tree drift")
require(git("merge-base", BASE, "HEAD") == BASE, "branch is not descended from exact F-DOC08 final head")

changed = [x for x in git("diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
unexpected = sorted(set(changed) - ALLOWED)
require(not unexpected, f"unbounded changed paths: {unexpected}")
require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{BASE}:src"), "production src tree changed")
require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{BASE}:reference"), "reference tree changed")
print("FDOC09_ZERO_PRODUCTION_SOURCE_DELTA=PASS")
print("FDOC09_ZERO_REFERENCE_DELTA=PASS")

for commit, path, expected in BLOB_LOCKS:
    actual = git("rev-parse", f"{commit}:{path}")
    require(actual == expected, f"authority blob drift {commit}:{path}: {actual} != {expected}")
print("FDOC09_EXACT_AUTHORITY_BLOBS=PASS")

r = load_json(REGISTRY)
require(r["work_unit"] == "F-DOC09", "registry work unit")
require(r["capability"] == "RB1-SW-REFERENCE", "wrong capability")
require(r["base_authority"]["commit"] == BASE, "wrong base authority")
require(r["governance"]["theory_reconstruction_from_code_permitted"] is False, "theory reconstruction must be prohibited")
require(r["governance"]["release_pass_may_replace_missing_equation_test_edges"] is False, "release PASS cannot replace missing T11 edges")
require(r["governance"]["complete_full_richards_equation_to_test_graph_claimed"] is False, "whole-route T11 completion illegally claimed")
require(r["governance"]["fully_traced_claimed"] is False, "FULLY_TRACED illegally claimed")
require(r["governance"]["status_a_ready_claimed"] is False, "Status A readiness illegally claimed")

scope = r["release_scope"]
require(scope["solver"] == "Full Richards REFERENCE route", "wrong solver scope")
require(scope["swkimpl"] == 0 and scope["swsophy"] == 0, "wrong frozen option scope")
require(scope["macropore_active"] is False, "active macropore outside scope")
require(scope["rossfast_excluded"] is True, "RossFast exclusion missing")
require(scope["source_authority"] == CANONICAL, "canonical source authority drift")
require(scope["qualification_authority"] == "aeb74560d801c4ac7314df7b8845fcc5daf8bba6", "F-RB01 drift")
require(scope["release_authority"] == "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0", "F-RB02 drift")

for path, expected_blob in r["source_pins"].items():
    actual_blob = git("rev-parse", f"{CANONICAL}:{path}")
    require(actual_blob == expected_blob, f"canonical source pin drift {path}: {actual_blob} != {expected_blob}")
print("FDOC09_CANONICAL_SOURCE_PINS=PASS")

a = r["authorities"]
require(a["F_SI13"]["record_blob"] == "f9a1dda7819f6b769e8b7cd9ac0319af436e0499", "F-SI13 lock")
require(a["F_SI14"]["record_blob"] == "a54aa26e6cfac710648f876a619da7f84ab3d0d5", "F-SI14 lock")
require(a["F_SI15"]["record_blob"] == "9dd06140d624c18d1a282bf10a30c737f61ab1ea", "F-SI15 lock")
require(a["F_SI16"]["record_blob"] == "7ee1b26a7ccdf6c4ae0d2b6c95a44a984e80fc57", "F-SI16 lock")
require(a["F_SI18"]["classification"] == "DIAGNOSTIC_TEST_ARCHITECTURE_SUPPORT_ONLY", "F-SI18 must stay diagnostic")
require(a["F_SI19"]["qualification_run"] == 34258568803, "F-SI19 run lock")
require(a["F_RB01"]["workflow_run"] == 34570204719, "F-RB01 run lock")

rels = {x["id"]: x for x in r["verification_relations"]}
require(set(rels) == {f"R{i:02d}" for i in range(1, 9)}, "verification relation node set")
require(sum(x["classification"] == "QUALIFIED_SCOPED_VERIFICATION" for x in rels.values()) == 5, "scoped verification count")
require(sum(x["classification"] == "QUALIFIED_CROSS_CUTTING_VERIFICATION" for x in rels.values()) == 2, "cross-cutting verification count")
require(rels["R08"]["classification"] == "RELEASE_PRESERVATION_VERIFICATION_NOT_EQUATION_AUTHORITY", "release preservation classification")
require("F_RB01" in rels["R08"]["evidence"], "R08 release evidence")

support = r["diagnostic_support"]
require(len(support) == 1 and support[0]["id"] == "D01", "diagnostic support node")
require(support[0]["authority"] == "F_SI18", "F-SI18 diagnostic authority")
require(support[0]["positive_scientific_admission"] is False, "F-SI18 cannot become positive scientific admission")

gaps = {x["id"]: x for x in r["residual_gap_nodes"]}
require(set(gaps) == {f"G{i:02d}" for i in range(1, 6)}, "residual gap node set")
require(gaps["G01"]["tier"] == "T1", "T1 gap must remain explicit")
require("T11" == gaps["G04"]["tier"], "whole-route T11 gap missing")

cov = r["coverage"]
require(cov["bounded_verification_relation_nodes"] == 8, "bounded relation count")
require(cov["qualified_scoped_relation_nodes"] == 7, "qualified scoped+cross-cutting relation count")
require(cov["release_preservation_relation_nodes"] == 1, "release relation count")
require(cov["diagnostic_support_nodes"] == 1, "diagnostic node count")
require(cov["residual_gap_nodes"] == 5, "gap count")
require(cov["bounded_reference_route_evidence_inventory_complete"] is True, "bounded inventory must be complete")
require(cov["complete_full_richards_equation_to_test_graph"] is False, "whole-route equation-to-test graph must remain incomplete")
require(cov["T1_complete"] is False, "T1 must remain incomplete")
require(cov["T3_T8_complete"] is False, "T3-T8 must remain incomplete")
require(cov["T11_complete_for_entire_reference_route"] is False, "T11 entire route must remain incomplete")
require(cov["fully_traced"] is False, "FULLY_TRACED must remain false")
require(cov["ready_for_status_a_review"] is False, "Status A readiness must remain false")
print("FDOC09_BOUNDED_EVIDENCE_GRAPH=PASS")
print("FDOC09_RESIDUAL_T1_T11_GAPS_LOCKED=PASS")
print("FDOC09_FSI18_DIAGNOSTIC_ONLY=PASS")

nonclaims = "\n".join(r["hard_nonclaims"])
for required in [
    "does not create or infer a missing Full Richards T1 theory authority",
    "does not claim a complete equation-to-test graph",
    "does not promote F-SI18 diagnostic fixture evidence",
    "does not establish Status A readiness",
    "does not alter RB1 production source",
    "Surface-evaporation throughput/scaling",
]:
    require(required in nonclaims, f"missing hard nonclaim: {required}")

text = DOC.read_text()
for token in [
    "the complete Full Richards **equation-to-test graph is not complete**",
    "does **not** make it `READY_FOR_STATUS_A_REVIEW`",
    "head_gradient(NN+1) = (h(NN) - hbot) / disnod(NN+1) + 1",
    "Mass conservation remains hard and unchanged",
    "QUALIFIED_BOUNDED_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH_WITH_EXPLICIT_RESIDUAL_GAPS",
]:
    require(token in text, f"documentation sentinel missing: {token}")

if AUDIT.exists():
    audit = load_json(AUDIT)
    require(audit["work_unit"] == "F-DOC09", "audit work unit")
    require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "invariant audit overall")
    require(audit["mass_conservation"] == "HARD_UNCHANGED", "mass conservation audit")
    inv = audit["invariants"]
    require(len(inv) == 30, "invariant audit must contain 30 entries")
    require([x["id"] for x in inv] == list(range(1, 31)), "invariant ids must be 1..30")
    require(all(x["status"] == "PASS" for x in inv), "all invariants must PASS")
    print("FDOC09_INVARIANT_AUDIT_30_OF_30=PASS")

if STATUS.exists():
    s = load_json(STATUS)
    require(s["work_unit"] == "F-DOC09", "status work unit")
    require(s["decision"] == "QUALIFIED_BOUNDED_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH_WITH_EXPLICIT_RESIDUAL_GAPS", "status decision")
    require(s["scope"]["bounded_evidence_inventory_complete"] is True, "status bounded inventory")
    require(s["scope"]["complete_full_richards_equation_to_test_graph"] is False, "status whole-route T11")
    require(s["scope"]["fully_traced"] is False, "status fully traced")
    require(s["work_state"]["scientific_scope_reopened"] is False, "scientific scope reopened")

if CLOSEOUT.exists():
    c = load_json(CLOSEOUT)
    require(c["work_unit"] == "F-DOC09", "closeout work unit")
    require(c["decision"] == "QUALIFIED_BOUNDED_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH_WITH_EXPLICIT_RESIDUAL_GAPS", "closeout decision")
    require(c["finality_rule"].startswith("Final only when"), "closeout finality rule")

out = {
    "work_unit": "F-DOC09",
    "head": head,
    "base": BASE,
    "changed_paths": changed,
    "changed_path_count": len(changed),
    "src_tree_unchanged": True,
    "reference_tree_unchanged": True,
    "exact_authority_blobs": "PASS",
    "canonical_source_pins": "PASS",
    "verification_relation_nodes": 8,
    "diagnostic_support_nodes": 1,
    "residual_gap_nodes": 5,
    "bounded_evidence_inventory_complete": True,
    "complete_full_richards_equation_to_test_graph": False,
    "fully_traced": False,
    "ready_for_status_a_review": False,
    "mass_conservation": "HARD_UNCHANGED",
    "status_present": STATUS.exists(),
    "closeout_present": CLOSEOUT.exists(),
}
EVIDENCE.write_text(json.dumps(out, indent=2) + "\n")
print("FDOC09_VALIDATION=PASS")
