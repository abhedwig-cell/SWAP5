#!/usr/bin/env python3
import json
import pathlib
import subprocess

BASE = "df438f8d0eaa4117e3e6df13a7061985fe233a16"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
FDOC03 = "0c25d97bd180378a916fbb14a1e45768af9ec63a"
FDOC05 = "919f228d8aedc1029b5080bb019fbe61d2e1d7c6"
DECISION = "QUALIFIED_RB1_RUNTIME_ARCHITECTURE_T0_T7_APPLICABILITY_AND_STATE_TRANSITION_AUTHORITY_WITH_ZERO_SCIENTIFIC_PROMOTION"
REG = pathlib.Path("docs/scientific/registries/rb1-runtime-architecture-tier-applicability.json")
OLD_CORE = pathlib.Path("docs/scientific/registries/rb1-core-capability-traceability.json")
STATUS = pathlib.Path("integration/f-doc/F-DOC12_STATUS.json")
AUDIT = pathlib.Path("integration/f-doc/F-DOC12_INVARIANT_AUDIT.json")
CLOSEOUT = pathlib.Path("integration/f-doc/F-DOC12_CLOSEOUT.json")
DOC = pathlib.Path("docs/scientific/F-DOC12_RB1_RUNTIME_ARCHITECTURE_TIER_APPLICABILITY.md")

EXPECTED = {
    "RB1-CORE-INTERVAL", "RB1-CORE-DATA", "RB1-CORE-TRANSACTION", "RB1-CORE-DIAGNOSTICS",
    "RB1-STANDALONE-N1", "RB1-MULTISWAP-SERIAL", "RB1-MULTISWAP-PARALLEL-V1",
    "RB1-RESTART-SERIAL", "RB1-RESTART-PARALLEL"
}
CARRIED = {"RB1-CORE-INTERVAL", "RB1-CORE-DATA", "RB1-CORE-TRANSACTION", "RB1-CORE-DIAGNOSTICS"}
MATERIALISED = EXPECTED - CARRIED
ALLOWED_PATHS = {
    ".github/workflows/fdoc12-rb1-runtime-architecture-tier-applicability.yml",
    "docs/scientific/F-DOC12_RB1_RUNTIME_ARCHITECTURE_TIER_APPLICABILITY.md",
    "docs/scientific/registries/rb1-runtime-architecture-tier-applicability.json",
    "integration/f-doc/F-DOC12_STATUS.json",
    "integration/f-doc/F-DOC12_INVARIANT_AUDIT.json",
    "integration/f-doc/F-DOC12_CLOSEOUT.json",
    "tools/docs/validate_fdoc12_runtime_architecture_tier_applicability.py",
}

def run(*args):
    return subprocess.check_output(args, text=True).strip()

def load(path):
    return json.loads(path.read_text())

reg = load(REG)
old = load(OLD_CORE)
status = load(STATUS)
audit = load(AUDIT)
closeout = load(CLOSEOUT)
assert DOC.exists()

assert reg["work_unit"] == "F-DOC12"
assert reg["base_authority"]["fdoc11"] == BASE
assert reg["base_authority"]["fdoc03"] == FDOC03
assert reg["base_authority"]["fdoc05"] == FDOC05
assert reg["base_authority"]["canonical_scientific_source"] == SOURCE
assert reg["scope"]["family"] == "RUNTIME_ARCHITECTURE"
assert reg["scope"]["capability_count"] == 9
assert reg["scope"]["tier_scope"] == [f"T{i}" for i in range(8)]

caps = {c["capability_id"]: c for c in reg["capabilities"]}
assert set(caps) == EXPECTED
assert len(reg["capabilities"]) == 9
for cid, cap in caps.items():
    for i in range(8):
        t = cap[f"T{i}"]
        assert t["status"] in {"RESOLVED", "NOT_APPLICABLE"}, (cid, i, t)
        if t["status"] == "NOT_APPLICABLE":
            assert t.get("rationale"), (cid, i)

oldcaps = {c["capability_id"]: c for c in old["capabilities"]}
for cid in CARRIED:
    assert caps[cid]["disposition"] == "CARRIED_FORWARD_FROM_FDOC03"
    for i in range(8):
        assert caps[cid][f"T{i}"]["status"] == oldcaps[cid]["tiers"][f"T{i}"]["status"], (cid, i)

for cid in MATERIALISED:
    assert caps[cid]["disposition"] == "MATERIALISED_BY_FDOC12"
    for i in (0, 1, 4, 5, 7):
        assert caps[cid][f"T{i}"]["status"] == "NOT_APPLICABLE", (cid, i)
    for i in (2, 3, 6):
        assert caps[cid][f"T{i}"]["status"] == "RESOLVED", (cid, i)

assert reg["summary"] == {
    "runtime_capabilities": 9,
    "carried_from_fdoc03": 4,
    "materialised_by_fdoc12": 5,
    "t0_t7_unresolved_after_fdoc12": 0,
    "fully_traced_promotions": 0,
    "status_a_readiness_promotions": 0,
}

for pin in reg["source_pins"]:
    actual = run("git", "rev-parse", f"{SOURCE}:{pin['path']}")
    assert actual == pin["blob"], (pin["path"], actual, pin["blob"])

assert run("git", "merge-base", BASE, "HEAD") == BASE
changed = set(filter(None, run("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines()))
assert changed <= ALLOWED_PATHS, sorted(changed - ALLOWED_PATHS)
assert not any(p.startswith("src/") for p in changed)
assert not any(p.startswith("reference/") for p in changed)

assert status["decision"] == DECISION
assert status["scope"]["capabilities"] == 9
assert status["scope"]["t0_t7_unresolved_after_fdoc12"] == 0
assert status["scope"]["fully_traced_promotions"] == 0
assert status["scope"]["status_a_readiness_promotions"] == 0
assert status["scope"]["status_a_compliant"] is False
assert status["scope"]["status_aa_compliant"] is False
assert status["scope"]["scientific_authority_invented"] is False
assert status["scope_holds"]["production_delta"] == "NONE"
assert status["scope_holds"]["reference_delta"] == "NONE"
assert status["scope_holds"]["physics_delta"] == "NONE"
assert status["scope_holds"]["solver_delta"] == "NONE"
assert status["scope_holds"]["mass_criterion_delta"] == "NONE"
assert status["scope_holds"]["temporal_acceptance_delta"] == "NONE"
assert status["scope_holds"]["performance_delta"] == "NONE"
assert status["scope_holds"]["universal_H_budget_claimed"] is False
assert status["scope_holds"]["surface_evaporation_throughput_scaling_claimed"] is False

assert audit["total"] == 30 and audit["pass"] == 30 and audit["fail"] == 0
assert audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA"
assert audit["mass_conservation"] == "HARD_UNCHANGED"
assert len(audit["invariants"]) == 30
assert {x["id"] for x in audit["invariants"]} == set(range(1,31))
assert all(x["status"] == "PASS" for x in audit["invariants"])
assert closeout["decision"] == DECISION
assert closeout["result"]["unresolved_T0_T7_within_runtime_family"] == 0
assert closeout["result"]["fully_traced_promotions"] == 0
assert closeout["result"]["status_a_readiness_promotions"] == 0
assert closeout["result"]["scientific_theory_created"] is False

print("FDOC12_CAPABILITIES_9_EXACT=PASS")
print("FDOC12_T0_T7_ALL_DISPOSED=PASS")
print("FDOC12_FDOC03_CARRY_FORWARD_EXACT=PASS")
print("FDOC12_FIVE_RUNTIME_SEMANTICS_MATERIALISED=PASS")
print("FDOC12_SOURCE_PINS_EXACT=PASS")
print("FDOC12_BOUNDED_CHANGED_PATHS=PASS")
print("FDOC12_ZERO_PRODUCTION_DELTA=PASS")
print("FDOC12_ZERO_REFERENCE_DELTA=PASS")
print("FDOC12_NO_FULLY_TRACED_PROMOTION=PASS")
print("FDOC12_NO_STATUS_A_PROMOTION=PASS")
print("FDOC12_INVARIANTS_30_OF_30_PASS=PASS")
print("FDOC12_HARD_MASS_UNCHANGED=PASS")
print(f"FDOC12_DECISION_IF_WORKFLOW_GREEN={DECISION}")

pathlib.Path("_fdoc12_runtime_architecture_evidence.json").write_text(json.dumps({
    "head": run("git", "rev-parse", "HEAD"),
    "base": BASE,
    "source": SOURCE,
    "capabilities": sorted(EXPECTED),
    "changed_paths": sorted(changed),
    "decision_if_green": DECISION,
}, indent=2) + "\n")
