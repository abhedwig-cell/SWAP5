#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "2a4a8738496329001a3c3af9b5e50a9f31d0c44f"
BASE_TREE = "c034335e459a742ab35c0120420e1b18e3f27b9b"
REGISTRY = Path("docs/scientific/registries/rb1-post-t11-aggregate-traceability-reconciliation.json")
DOC = Path("docs/scientific/F-DOC10_RB1_POST_T11_AGGREGATE_RECONCILIATION.md")
AUDIT = Path("integration/f-doc/F-DOC10_INVARIANT_AUDIT.json")
STATUS = Path("integration/f-doc/F-DOC10_STATUS.json")
CLOSEOUT = Path("integration/f-doc/F-DOC10_CLOSEOUT.json")
EVIDENCE = Path("_fdoc10_aggregate_evidence.json")

ALLOWED = {
    ".github/workflows/fdoc10-rb1-post-t11-aggregate-reconciliation.yml",
    "docs/scientific/F-DOC10_RB1_POST_T11_AGGREGATE_RECONCILIATION.md",
    "docs/scientific/registries/rb1-post-t11-aggregate-traceability-reconciliation.json",
    "integration/f-doc/F-DOC10_INVARIANT_AUDIT.json",
    "integration/f-doc/F-DOC10_STATUS.json",
    "integration/f-doc/F-DOC10_CLOSEOUT.json",
    "tools/docs/validate_fdoc10_rb1_post_t11_aggregate_reconciliation.py",
}

BLOB_LOCKS = [
    ("492b984bca282d6ec11dcaa727227b34c0ff3a84", "docs/scientific/registries/rb1-aggregate-traceability-reconciliation.json", "2ff4bb671ebafdaa92efc24c511f3466ac897724"),
    ("8e5863510004ec11ab377b5bc9d3bd5df6d69777", "integration/f-doc/F-DOC08_STATUS.json", "8184a7a3ddbbe5e28d31899278f9daae6852a633"),
    ("8e5863510004ec11ab377b5bc9d3bd5df6d69777", "integration/f-doc/F-DOC08_CLOSEOUT.json", "e862d10ef84b34c4f3ba1abe89abe5f7d401b5d0"),
    ("2a4a8738496329001a3c3af9b5e50a9f31d0c44f", "integration/f-doc/F-DOC09_STATUS.json", "7a166383d86e575700daba650bec66f0b53b144e"),
    ("2a4a8738496329001a3c3af9b5e50a9f31d0c44f", "integration/f-doc/F-DOC09_CLOSEOUT.json", "c04c3df5eb51d81335c4fe85aac5f42621aba5c2"),
]


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def require(condition, message):
    if not condition:
        raise SystemExit(f"FDOC10_FAIL {message}")


def load_json(path):
    with path.open() as f:
        return json.load(f)


head = git("rev-parse", "HEAD")
require(git("rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "F-DOC09 base tree drift")
require(git("merge-base", BASE, "HEAD") == BASE, "branch is not descended from exact F-DOC09 final head")
changed = [x for x in git("diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
unexpected = sorted(set(changed) - ALLOWED)
require(not unexpected, f"unbounded changed paths: {unexpected}")
require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{BASE}:src"), "production src tree changed")
require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{BASE}:reference"), "reference tree changed")
print("FDOC10_ZERO_PRODUCTION_SOURCE_DELTA=PASS")
print("FDOC10_ZERO_REFERENCE_DELTA=PASS")

for commit, path, expected in BLOB_LOCKS:
    actual = git("rev-parse", f"{commit}:{path}")
    require(actual == expected, f"authority blob drift {commit}:{path}: {actual} != {expected}")
print("FDOC10_EXACT_UPSTREAM_BLOBS=PASS")

r = load_json(REGISTRY)
require(r["work_unit"] == "F-DOC10", "registry work unit")
require(r["base_authority"]["commit"] == BASE, "base authority")
pop = r["population_authority"]
require(pop["work_unit"] == "F-DOC07", "population authority work unit")
require(pop["commit"] == "492b984bca282d6ec11dcaa727227b34c0ff3a84", "F-DOC07 population authority")
require(pop["registry_blob"] == "2ff4bb671ebafdaa92efc24c511f3466ac897724", "F-DOC07 registry blob")
require(pop["required_denominator"] == 15, "required denominator")
require(pop["covered_exactly_once"] == 15, "covered exactly once")
require(pop["duplicate_assignments"] == 0, "duplicate assignments")
require(pop["unassigned_required_capabilities"] == 0, "unassigned capabilities")

rem = {x["work_unit"]: x for x in r["post_population_remediations"]}
require(set(rem) == {"F-DOC08", "F-DOC09"}, "remediation set")
require(rem["F-DOC08"]["head"] == "8e5863510004ec11ab377b5bc9d3bd5df6d69777", "F-DOC08 head")
require(rem["F-DOC08"]["final_exact_head_run"] == 34642744759, "F-DOC08 exact-head run")
require(rem["F-DOC08"]["decision"] == "QUALIFIED_BOUNDED_RB1_TIME_REFERENCE_T11_RELATION_TO_TEST_GRAPH", "F-DOC08 decision")
require(rem["F-DOC09"]["head"] == "2a4a8738496329001a3c3af9b5e50a9f31d0c44f", "F-DOC09 head")
require(rem["F-DOC09"]["final_exact_head_run"] == 34643460050, "F-DOC09 exact-head run")
require(rem["F-DOC09"]["decision"] == "QUALIFIED_BOUNDED_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH_WITH_EXPLICIT_RESIDUAL_GAPS", "F-DOC09 decision")
print("FDOC10_REMEDIATION_AUTHORITIES=PASS")

cov = r["aggregate_coverage_after_remediation"]
require(cov["required_denominator"] == 15 and cov["covered_exactly_once"] == 15, "coverage denominator")
require(cov["duplicate_assignments"] == 0 and cov["unassigned_required_capabilities"] == 0, "coverage uniqueness")
require(cov["population_coverage_changed_by_fdoc08_or_fdoc09"] is False, "population coverage must not change")
require(cov["traceability_maturity_claim"] == "IMPROVED_BOUNDED_TRACEABILITY_WITH_EXPLICIT_RESIDUAL_GAPS_NOT_FULLY_TRACED", "maturity claim")

deltas = r["maturity_deltas"]
require(deltas["RB1-TIME-REFERENCE"]["whole_capability_fully_traced"] is False, "TIME capability must remain not fully traced")
require(deltas["RB1-SW-REFERENCE"]["whole_capability_fully_traced"] is False, "SW reference must remain not fully traced")
require(deltas["other_13_required_capabilities"]["maturity_changed_by_fdoc08_or_fdoc09"] is False, "other 13 maturity must be unchanged")

gaps = {x["id"]: x for x in r["aggregate_gap_state"]}
expected_gaps = {
    "GAP-CONTROLLED-THEORY-FORMAL",
    "GAP-T11-COMPLETE-GRAPHS",
    "GAP-T12-APPLICATION-VALIDATION",
    "GAP-WR-QA-2024-CONTROLLED-COPY",
    "GAP-APPLICATION-TEMPORAL-H-BUDGET",
    "GAP-SURFACE-EVAP-PERFORMANCE",
}
require(set(gaps) == expected_gaps, "aggregate gap set")
require(gaps["GAP-CONTROLLED-THEORY-FORMAL"]["state"] == "OPEN", "controlled theory gap")
require(gaps["GAP-T11-COMPLETE-GRAPHS"]["state"] == "OPEN_NARROWED", "T11 gap must be open narrowed")
require(gaps["GAP-T12-APPLICATION-VALIDATION"]["state"] == "OPEN", "T12 gap")
require(gaps["GAP-WR-QA-2024-CONTROLLED-COPY"]["state"] == "OPEN_EXTERNAL_AUTHORITY_DEPENDENCY", "WR-QA gap")
require(gaps["GAP-APPLICATION-TEMPORAL-H-BUDGET"]["state"] == "OPEN_EXTERNAL_POLICY_DEPENDENCY", "H_budget gap")
require(gaps["GAP-SURFACE-EVAP-PERFORMANCE"]["state"] == "OPEN_SEPARATE_PERFORMANCE_WORK", "surface evap performance gap")

sa = r["status_a_boundary"]
require(sa["ready_for_status_a_review"] is False, "Status A readiness")
require(sa["status_a_compliant"] is False, "Status A compliance")
require(sa["status_aa_compliant"] is False, "Status AA compliance")
require(sa["external_audit_performed"] is False, "external audit")
require(sa["formal_2024_reconciliation"] == "PENDING_CONTROLLED_COPY", "WR-QA reconciliation")
print("FDOC10_AGGREGATE_GAP_STATE=PASS")
print("FDOC10_NO_STATUS_A_PROMOTION=PASS")

nonclaims = "\n".join(r["hard_nonclaims"])
for required in [
    "does not promote any capability to FULLY_TRACED",
    "does not turn F-DOC08 bounded temporal T11 completion into a universal application-accuracy claim or H_budget",
    "does not turn F-DOC09 bounded reference evidence inventory into a complete Full Richards theory",
    "does not establish Status A readiness/compliance",
    "does not alter production source",
    "Surface-evaporation throughput/scaling",
]:
    require(required in nonclaims, f"missing hard nonclaim: {required}")

text = DOC.read_text()
for token in [
    "15 required RB1 capabilities",
    "F-DOC08 and F-DOC09 therefore change **maturity**, not **population coverage**",
    "OPEN_NARROWED",
    "No Status A readiness or compliance claim follows",
    "Mass conservation remains hard and unchanged",
    "QUALIFIED_RB1_POST_T11_AGGREGATE_TRACEABILITY_RECONCILIATION_WITH_RESIDUAL_GAPS",
]:
    require(token in text, f"documentation sentinel missing: {token}")

if AUDIT.exists():
    audit = load_json(AUDIT)
    require(audit["work_unit"] == "F-DOC10", "audit work unit")
    require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "audit overall")
    require(audit["mass_conservation"] == "HARD_UNCHANGED", "mass audit")
    require(len(audit["invariants"]) == 30, "30 invariants required")
    require([x["id"] for x in audit["invariants"]] == list(range(1, 31)), "invariant ids")
    require(all(x["status"] == "PASS" for x in audit["invariants"]), "all invariants must PASS")
    print("FDOC10_INVARIANT_AUDIT_30_OF_30=PASS")

if STATUS.exists():
    s = load_json(STATUS)
    require(s["work_unit"] == "F-DOC10", "status work unit")
    require(s["decision"] == "QUALIFIED_RB1_POST_T11_AGGREGATE_TRACEABILITY_RECONCILIATION_WITH_RESIDUAL_GAPS", "status decision")
    require(s["scope"]["required_denominator"] == 15, "status denominator")
    require(s["scope"]["fully_traced_claimed"] is False, "status fully traced")
    require(s["scope"]["ready_for_status_a_review"] is False, "status Status A readiness")

if CLOSEOUT.exists():
    c = load_json(CLOSEOUT)
    require(c["work_unit"] == "F-DOC10", "closeout work unit")
    require(c["decision"] == "QUALIFIED_RB1_POST_T11_AGGREGATE_TRACEABILITY_RECONCILIATION_WITH_RESIDUAL_GAPS", "closeout decision")
    require(c["finality_rule"].startswith("Final only when"), "closeout finality rule")

out = {
    "work_unit": "F-DOC10",
    "head": head,
    "base": BASE,
    "changed_paths": changed,
    "changed_path_count": len(changed),
    "src_tree_unchanged": True,
    "reference_tree_unchanged": True,
    "required_denominator": 15,
    "covered_exactly_once": 15,
    "post_population_remediations": ["F-DOC08", "F-DOC09"],
    "t11_gap_state": "OPEN_NARROWED",
    "fully_traced_promotions": 0,
    "ready_for_status_a_review": False,
    "mass_conservation": "HARD_UNCHANGED",
    "status_present": STATUS.exists(),
    "closeout_present": CLOSEOUT.exists(),
}
EVIDENCE.write_text(json.dumps(out, indent=2) + "\n")
print("FDOC10_VALIDATION=PASS")
