#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

BASE = "ef34a9f5a01d78ff9c2628315b484c5a8ff4f717"
REGISTRY = pathlib.Path("docs/scientific/registries/rb1-controlled-theory-formal-gap-decomposition.json")
DOC = pathlib.Path("docs/scientific/F-DOC11_RB1_CONTROLLED_THEORY_FORMAL_GAP_DECOMPOSITION.md")
AUDIT = pathlib.Path("integration/f-doc/F-DOC11_INVARIANT_AUDIT.json")
STATUS = pathlib.Path("integration/f-doc/F-DOC11_STATUS.json")
CLOSEOUT = pathlib.Path("integration/f-doc/F-DOC11_CLOSEOUT.json")

EXPECTED = {
    "RB1-CORE-INTERVAL",
    "RB1-CORE-DATA",
    "RB1-CORE-TRANSACTION",
    "RB1-CORE-MASS",
    "RB1-CORE-DIAGNOSTICS",
    "RB1-SW-REFERENCE",
    "RB1-TIME-REFERENCE",
    "RB1-STANDALONE-N1",
    "RB1-MULTISWAP-SERIAL",
    "RB1-MULTISWAP-PARALLEL-V1",
    "RB1-ET-ROOT-SERIAL",
    "RB1-ROOT-PARALLEL",
    "RB1-SURFACE-EVAP-RESTRICTED",
    "RB1-RESTART-SERIAL",
    "RB1-RESTART-PARALLEL",
}

ALLOWED_PREFIXES = (
    ".github/workflows/fdoc11-rb1-controlled-theory-formal-gap-decomposition.yml",
    "docs/scientific/F-DOC11_RB1_CONTROLLED_THEORY_FORMAL_GAP_DECOMPOSITION.md",
    "docs/scientific/registries/rb1-controlled-theory-formal-gap-decomposition.json",
    "integration/f-doc/F-DOC11_",
    "tools/docs/validate_fdoc11_controlled_theory_formal_gap_decomposition.py",
)


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def emit(name, ok, detail=None):
    print(f"FDOC11_{name}={'PASS' if ok else 'FAIL'}" + (f" {detail}" if detail else ""))
    if not ok:
        raise AssertionError(name)


def main():
    reg = json.loads(REGISTRY.read_text())
    emit("BASE_AUTHORITY", reg["base_authority"]["fdoc10"] == BASE)
    emit("EXACT_TIER_SCOPE", reg["tier_scope"] == [f"T{i}" for i in range(8)])

    caps = reg["capabilities"]
    ids = [x["capability_id"] for x in caps]
    emit("DENOMINATOR_15", len(ids) == 15)
    emit("CAPABILITIES_EXACT_ONCE", set(ids) == EXPECTED and len(ids) == len(set(ids)))
    emit("NO_T0_T7_RESOLUTION", all(x.get("resolved_by_fdoc11") == [] for x in caps))

    summary = reg["decomposition_summary"]
    emit("FAMILY_COUNTS", summary == {
        "required_denominator": 15,
        "covered_exactly_once": 15,
        "physical_science": 3,
        "numerical_method": 1,
        "runtime_architecture": 9,
        "hybrid": 2,
        "resolved_t0_t7_by_fdoc11": 0,
        "fully_traced_promotions": 0,
        "status_a_readiness_promotions": 0,
    })

    policy = reg["decomposition_policy"]
    emit("NO_FULLY_TRACED_PROMOTION", policy["fully_traced_promotions"] == 0)
    emit("NO_STATUS_A_PROMOTION", not policy["status_a_ready_claimed"] and not policy["status_a_compliant_claimed"] and not policy["status_aa_compliant_claimed"])

    text = DOC.read_text()
    emit("DOC_ZERO_RESOLUTION_EXPLICIT", "resolveert bewust 0 T0–T7 tiers" in text or "resolves **zero** T0–T7 tiers" in text)
    emit("NO_UNIVERSAL_H_BUDGET", "does not" in text and "universal `H_budget`" in text)
    emit("SURFACE_EVAP_PERF_SEPARATE", "surface-evaporation performance remain distinct gaps" in text or "surface-evaporation MultiSWAP compatibility" in text)

    changed = run("git", "diff", "--name-only", f"{BASE}...HEAD").splitlines()
    bad = [p for p in changed if not any(p == pref or p.startswith(pref) for pref in ALLOWED_PREFIXES)]
    emit("BOUNDED_CHANGED_PATHS", not bad, ",".join(bad) if bad else None)
    emit("ZERO_PRODUCTION_DELTA", not any(p.startswith("src/") for p in changed))
    emit("ZERO_REFERENCE_DELTA", not any(p.startswith("reference/") for p in changed))

    if AUDIT.exists():
        audit = json.loads(AUDIT.read_text())
        emit("INVARIANTS_30_OF_30_PASS", audit["summary"]["total"] == 30 and audit["summary"]["pass"] == 30 and audit["summary"]["fail"] == 0)
        emit("HARD_MASS_UNCHANGED", audit["summary"]["mass_conservation"] == "HARD_UNCHANGED")

    if STATUS.exists():
        status = json.loads(STATUS.read_text())
        emit("STATUS_NO_MATURITY_PROMOTION", status["scope"]["resolved_t0_t7_by_fdoc11"] == 0 and status["scope"]["fully_traced_promotions"] == 0)
        emit("STATUS_NO_STATUS_A_CLAIM", not status["scope"]["ready_for_status_a_review"])

    if CLOSEOUT.exists():
        closeout = json.loads(CLOSEOUT.read_text())
        emit("CLOSEOUT_DECISION", closeout["decision"] == "QUALIFIED_RB1_CONTROLLED_THEORY_FORMAL_GAP_DECOMPOSITION_WITH_ZERO_TIER_PROMOTION")

    evidence = {
        "work_unit": "F-DOC11",
        "head": run("git", "rev-parse", "HEAD"),
        "base": BASE,
        "changed_paths": changed,
        "required_denominator": 15,
        "covered_exactly_once": 15,
        "resolved_t0_t7_by_fdoc11": 0,
        "fully_traced_promotions": 0,
        "status_a_readiness_promotions": 0,
        "production_delta": "NONE",
        "reference_delta": "NONE",
        "decision_if_workflow_green": "QUALIFIED_RB1_CONTROLLED_THEORY_FORMAL_GAP_DECOMPOSITION_WITH_ZERO_TIER_PROMOTION",
    }
    pathlib.Path("_fdoc11_controlled_theory_formal_gap_decomposition_evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("FDOC11_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_RB1_CONTROLLED_THEORY_FORMAL_GAP_DECOMPOSITION_WITH_ZERO_TIER_PROMOTION")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FDOC11_VALIDATION_ERROR={type(exc).__name__}:{exc}", file=sys.stderr)
        raise
