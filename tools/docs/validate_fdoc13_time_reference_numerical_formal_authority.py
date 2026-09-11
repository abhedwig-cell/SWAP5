#!/usr/bin/env python3
import json
import pathlib
import subprocess

BASE = "e34caabe225986db3c60551f4168869f3e4cc2a2"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
FDOC08 = "8e5863510004ec11ab377b5bc9d3bd5df6d69777"
FVQ34_CLOSEOUT = "df9b1123ba33ece022ce6649e70dcb538e44837f"
DECISION = "QUALIFIED_RB1_TIME_REFERENCE_RESTRICTED_T0_T7_NUMERICAL_FORMAL_AUTHORITY_WITH_EXPLICIT_APPLICATION_ACCURACY_NONCLAIM"

REG = pathlib.Path("docs/scientific/registries/rb1-time-reference-numerical-formal-authority.json")
DOC = pathlib.Path("docs/scientific/F-DOC13_RB1_TIME_REFERENCE_NUMERICAL_FORMAL_AUTHORITY.md")
STATUS = pathlib.Path("integration/f-doc/F-DOC13_STATUS.json")
AUDIT = pathlib.Path("integration/f-doc/F-DOC13_INVARIANT_AUDIT.json")
CLOSEOUT = pathlib.Path("integration/f-doc/F-DOC13_CLOSEOUT.json")

ALLOWED_PATHS = {
    ".github/workflows/fdoc13-rb1-time-reference-numerical-formal-authority.yml",
    "docs/scientific/F-DOC13_RB1_TIME_REFERENCE_NUMERICAL_FORMAL_AUTHORITY.md",
    "docs/scientific/registries/rb1-time-reference-numerical-formal-authority.json",
    "integration/f-doc/F-DOC13_STATUS.json",
    "integration/f-doc/F-DOC13_INVARIANT_AUDIT.json",
    "integration/f-doc/F-DOC13_CLOSEOUT.json",
    "tools/docs/validate_fdoc13_time_reference_numerical_formal_authority.py",
}

UPSTREAM_BLOBS = [
    (FVQ34_CLOSEOUT, "integration/f-si/F-SI24_GATE_A_LINEAR_DEFECT_BOUND_DERIVATION.json", "c674633b4de8779af3b58998ab028dc7591bac8f"),
    (FVQ34_CLOSEOUT, "integration/f-si/F-SI24_STATUS.json", "32b83b7bdd3bc9ffeb051a2efcece8375d63f1f8"),
    (FVQ34_CLOSEOUT, "integration/f-vq/F-VQ30_CLOSEOUT.json", "6663bcc1149f07962bb9921840958d6d7de628a4"),
    (FVQ34_CLOSEOUT, "integration/f-si/F-SI25_CLOSEOUT.json", "5bbb3613fe53ab68ec083e979dc7b062c117349c"),
    (FVQ34_CLOSEOUT, "integration/f-si/F-SI26_CLOSEOUT.json", "a07afb736ef3dd4a4fd937c9b04f83bcf77e70c0"),
    (FVQ34_CLOSEOUT, "integration/f-vq/F-VQ34_CLOSEOUT.json", "2bf2c2e790abac2ee4dc3cd6ee51c5e579859270"),
    (FVQ34_CLOSEOUT, "integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json", "4f3f7c8883397ed96d3af2f6585f25698c58e7b4"),
    (FDOC08, "docs/scientific/registries/rb1-time-reference-t11-traceability.json", "1dc7983a3a89546093fcf0f46ee6007401b26d35"),
]


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def load(path):
    return json.loads(path.read_text())


reg = load(REG)
status = load(STATUS)
audit = load(AUDIT)
closeout = load(CLOSEOUT)
assert DOC.exists()

assert reg["work_unit"] == "F-DOC13"
assert reg["capability"]["capability_id"] == "RB1-TIME-REFERENCE"
assert reg["capability"]["family"] == "NUMERICAL_METHOD"
assert reg["capability"]["tier_scope"] == [f"T{i}" for i in range(8)]
assert reg["base_authority"]["fdoc12"] == BASE
assert reg["base_authority"]["canonical_scientific_source"] == SOURCE

# Every T0-T7 tier must be explicitly disposed, with no silent gap.
tiers = reg["tier_dispositions"]
assert set(tiers) == {f"T{i}" for i in range(8)}
assert tiers["T0"]["status"] == "NOT_APPLICABLE"
assert tiers["T0"].get("rationale")
for i in range(1, 8):
    assert tiers[f"T{i}"]["status"] == "RESOLVED_RESTRICTED", (i, tiers[f"T{i}"])

# Hard claim boundaries: exact-linear theorem may be documented; nonlinear theorem may not be invented.
formal = reg["formal_scope_boundary"]
assert formal["exact_linear_true_error_bound"] is True
assert formal["general_nonlinear_true_error_bound"] is False
assert formal["nonlinear_finite_comparator_transfer"] is True
assert formal["numeric_H_budget_selected"] is False
assert formal["universal_H_budget"] is False
assert formal["universal_temporal_tolerance"] is False
assert formal["groundwater_head_accuracy_budget"] is False
assert formal["shorter_dt_monotonicity"] is False
assert formal["arbitrary_no_history_bootstrap"] is False
assert formal["arbitrary_restart_event_topology_continuation"] is False
assert formal["hard_mass_precedence"] is True
assert formal["calendar_boundary_dependency"] is False

# T5 must remain explicitly restricted to the F-SI24 exact-linear basis.
t5 = tiers["T5"]
assert "constant SPD M" in t5["meaning"]
assert "constant SPSD A" in t5["meaning"]
assert "does not elevate" in t5["meaning"]
assert "general nonlinear true-error upper bound" in t5["meaning"]

# Normalization must retain explicit, un-defaulted budget semantics.
fsi26 = reg["authority_chain"]["F_SI26"]
assert fsi26["formula"] == "C_h=B_inf/H_budget"
assert fsi26["default_H_budget"] is None
assert reg["authority_chain"]["F_SI24"]["nonlinear_boundary"] == "NO_GENERAL_NONLINEAR_BOUND"
assert reg["authority_chain"]["F_VQ30"]["nonlinear_boundary"] == "FINITE_COMPARATOR_CONSISTENT_NOT_TRUE_GENERAL_NONLINEAR_ERROR_BOUND"

# Exact canonical source pins.
for pin in reg["canonical_source_pins"]:
    actual = run("git", "rev-parse", f"{SOURCE}:{pin['path']}")
    assert actual == pin["blob"], (pin["path"], actual, pin["blob"])

# Exact upstream documentation/scientific evidence pins.
for commit, path, expected in UPSTREAM_BLOBS:
    actual = run("git", "rev-parse", f"{commit}:{path}")
    assert actual == expected, (commit, path, actual, expected)

# Bounded documentation/governance-only delta.
assert run("git", "merge-base", BASE, "HEAD") == BASE
changed = set(filter(None, run("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines()))
assert changed <= ALLOWED_PATHS, sorted(changed - ALLOWED_PATHS)
assert not any(p.startswith("src/") for p in changed)
assert not any(p.startswith("reference/") for p in changed)
assert not any(p.startswith("tests/") for p in changed)

result = reg["result"]
assert result["numerical_method_capabilities_in_fdoc11_denominator"] == 1
assert result["time_reference_t0_t7_explicit_dispositions"] == 8
assert result["time_reference_t0_t7_unresolved_after_fdoc13"] == 0
assert result["fully_traced_promotions"] == 0
assert result["status_a_readiness_promotions"] == 0
assert result["rb1_science_reopened"] is False
assert result["rb1_release_reopened"] is False

assert status["decision"] == DECISION
assert status["scope"]["capability"] == "RB1-TIME-REFERENCE"
assert status["scope"]["unresolved_t0_t7_after_fdoc13"] == 0
assert status["scope"]["general_nonlinear_true_error_bound"] is False
assert status["scope"]["numeric_H_budget_selected"] is False
assert status["scope"]["universal_H_budget"] is False
assert status["scope"]["groundwater_head_accuracy_budget"] is False
assert status["scope"]["fully_traced_promotions"] == 0
assert status["scope"]["status_a_readiness_promotions"] == 0
assert status["scope"]["status_a_compliant"] is False
assert status["scope"]["status_aa_compliant"] is False
for key in ("production_delta", "reference_delta", "physics_delta", "solver_delta", "scientific_tolerance_delta", "mass_criterion_delta", "temporal_acceptance_delta", "performance_delta"):
    assert status["scope_holds"][key] == "NONE", (key, status["scope_holds"][key])
assert status["scope_holds"]["universal_H_budget_claimed"] is False
assert status["scope_holds"]["universal_groundwater_head_accuracy_claimed"] is False
assert status["scope_holds"]["general_nonlinear_true_error_bound_claimed"] is False

assert audit["total"] == 30 and audit["pass"] == 30 and audit["fail"] == 0
assert audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA"
assert audit["mass_conservation"] == "HARD_UNCHANGED"
assert len(audit["invariants"]) == 30
assert {x["id"] for x in audit["invariants"]} == set(range(1, 31))
assert all(x["status"] == "PASS" for x in audit["invariants"])
assert audit["scope_holds"]["numeric_H_budget_selected"] is False
assert audit["scope_holds"]["universal_groundwater_head_budget_claimed"] is False
assert audit["scope_holds"]["general_nonlinear_true_error_bound_claimed"] is False

assert closeout["decision"] == DECISION
assert closeout["result"]["unresolved_T0_T7_within_time_reference"] == 0
assert closeout["result"]["exact_linear_theorem_preserved"] is True
assert closeout["result"]["general_nonlinear_true_error_bound_created"] is False
assert closeout["result"]["numeric_H_budget_selected"] is False
assert closeout["result"]["fully_traced_promotions"] == 0
assert closeout["result"]["status_a_readiness_promotions"] == 0

print("FDOC13_TIME_REFERENCE_CAPABILITY_EXACT=PASS")
print("FDOC13_T0_T7_ALL_EXPLICIT=PASS")
print("FDOC13_EXACT_LINEAR_SCOPE_PRESERVED=PASS")
print("FDOC13_NO_GENERAL_NONLINEAR_BOUND=PASS")
print("FDOC13_NO_NUMERIC_OR_UNIVERSAL_H_BUDGET=PASS")
print("FDOC13_HARD_MASS_PRECEDENCE_PRESERVED=PASS")
print("FDOC13_SOURCE_PINS_EXACT=PASS")
print("FDOC13_UPSTREAM_EVIDENCE_PINS_EXACT=PASS")
print("FDOC13_BOUNDED_CHANGED_PATHS=PASS")
print("FDOC13_ZERO_PRODUCTION_REFERENCE_DELTA=PASS")
print("FDOC13_NO_FULLY_TRACED_OR_STATUS_A_PROMOTION=PASS")
print("FDOC13_INVARIANTS_30_OF_30_PASS=PASS")
print("FDOC13_HARD_MASS_UNCHANGED=PASS")
print(f"FDOC13_DECISION_IF_WORKFLOW_GREEN={DECISION}")

pathlib.Path("_fdoc13_time_reference_evidence.json").write_text(json.dumps({
    "head": run("git", "rev-parse", "HEAD"),
    "base": BASE,
    "source": SOURCE,
    "capability": "RB1-TIME-REFERENCE",
    "tier_dispositions": {k: v["status"] for k, v in tiers.items()},
    "formal_scope_boundary": formal,
    "changed_paths": sorted(changed),
    "decision_if_green": DECISION,
}, indent=2) + "\n")
