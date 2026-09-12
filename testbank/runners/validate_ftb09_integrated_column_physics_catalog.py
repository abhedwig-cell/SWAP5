#!/usr/bin/env python3
"""Validate the F-TB09 integrated-column qualification catalog.

This validator qualifies the catalog contract and support-only change boundary.
It deliberately does not claim that catalogued physics cases have executed or passed.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

EXPECTED_WORKUNIT = "F-TB09"
EXPECTED_TARGET = "QUALIFIED_INTEGRATED_COLUMN_PHYSICS_TESTBANK_CATALOG_ESTABLISHED"
ALLOWED_PROFILES = {"FAST", "CANONICAL", "RELEASE", "DEEP"}
ORACLE_ORDER = {
    "O1_MATHEMATICAL_EXACT": 1,
    "O2_MANUFACTURED_SOLUTION": 2,
    "O3_INDEPENDENT_NUMERICAL_REFERENCE": 3,
    "O4_QUALIFIED_FULL_RICHARDS_REFERENCE": 4,
    "O5_LEGACY_SWAP431_SOURCE_BOUND": 5,
    "O6_PROPERTY_INVARIANT": 6,
    "O7_CROSS_SOLVER_CONSISTENCY": 7,
}
CASE_ID = re.compile(r"^SWAP5-TB09-[A-Z0-9-]+-\d{3}-v\d+$")
ALLOWED_CHANGED_PATHS = (
    ".github/workflows/ftb09-integrated-column-physics-catalog.yml",
    "docs/testbank/F-TB09_",
    "testbank/manifests/F-TB09_",
    "testbank/runners/validate_ftb09_",
    "integration/f-tb/F-TB09_",
    "integration/f-tb/RUNLOG_F-TB09.md",
)
REQUIRED_CASE_KEYS = {"stable_id","title","physics_scope","coverage","oracle","water_balance","tolerance_provenance","execution_profiles","expected_diagnostics","theory_equation_refs","architecture_invariants","owner_evidence_reused","execution_state","qualification_state","risk_selection_rationale"}


def fail(msg: str) -> None:
    raise AssertionError(msg)


def git(root: pathlib.Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def changed_path_allowed(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_CHANGED_PATHS)


def validate_support_only(root: pathlib.Path, base: str) -> list[str]:
    subprocess.check_call(["git", "-C", str(root), "merge-base", "--is-ancestor", base, "HEAD"])
    changed = [p for p in git(root, "diff", "--name-only", f"{base}..HEAD").splitlines() if p]
    forbidden = [p for p in changed if not changed_path_allowed(p)]
    if forbidden:
        fail("Production/non-TB09 paths changed: " + ", ".join(forbidden))
    if not changed:
        fail("No F-TB09 support changes found.")
    return changed


def validate_manifest(doc: dict) -> None:
    if doc.get("workunit") != EXPECTED_WORKUNIT: fail("Wrong workunit.")
    if doc.get("exit_target") != EXPECTED_TARGET: fail("Wrong or missing exit target.")
    if doc.get("qualification_claim") != "CATALOG_AND_ORACLE_CONTRACT_ONLY": fail("TB09 must not overclaim executed physics qualification.")
    if doc.get("catalog_status") != "QUALIFIED_CATALOG_CONTRACT_WHEN_EXACT_HEAD_CI_GREEN": fail("Catalog status must remain conditional on exact-head CI.")

    chain = doc.get("authority_chain", [])
    expected = [f"F-TB{i:02d}" for i in range(1, 9)]
    actual = [x.get("workunit") for x in chain]
    if actual != expected: fail(f"Authority chain must be exactly F-TB01..F-TB08, got {actual!r}")
    for auth in chain:
        if not re.fullmatch(r"[0-9a-f]{40}", auth.get("commit", "")): fail(f"Unpinned authority commit: {auth}")
        if auth.get("ci_status") != "success" or not auth.get("exact_head_ci_run"): fail(f"Authority lacks successful exact-head CI: {auth['workunit']}")

    oracle_policy = doc["oracle_policy"]
    if oracle_policy.get("hierarchy") != list(ORACLE_ORDER): fail("F-TB01 oracle hierarchy changed or reordered.")
    if oracle_policy.get("tb09_uses_legacy_o5"): fail("TB09 currently has no scientifically justified O5 legacy case.")
    if oracle_policy.get("corrected_golden_baseline_constructed"): fail("TB09 may not construct a corrected golden baseline.")

    mass = doc["mass_contract"]
    if not mass.get("required_for_all_water_bearing_cases"): fail("Hard water mass gate is required.")
    if mass.get("soft_mass_tolerance_allowed"): fail("Soft mass tolerance tradeoff is forbidden.")

    dimensions = doc.get("coverage_dimensions", [])
    if len(dimensions) != 11 or len(set(dimensions)) != len(dimensions): fail("Coverage dimensions must contain the 11 unique TB09 physics dimensions.")

    cases = doc.get("cases", [])
    if not cases: fail("No integrated cases catalogued.")
    ids = [c.get("stable_id") for c in cases]
    if len(ids) != len(set(ids)): fail("Duplicate stable case IDs.")

    for case in cases:
        missing = REQUIRED_CASE_KEYS - set(case)
        if missing: fail(f"{case.get('stable_id')}: missing metadata {sorted(missing)}")
        cid = case["stable_id"]
        if not CASE_ID.fullmatch(cid): fail(f"Invalid stable ID: {cid}")
        if set(case["coverage"]) != set(dimensions): fail(f"{cid}: coverage keys differ from catalog dimensions.")
        active = [d for d, flag in case["coverage"].items() if flag == "P"]
        if not active: fail(f"{cid}: no active physics dimensions.")
        if len(active) > doc["pairwise_risk_policy"]["max_primary_interaction_dimensions_per_case"]: fail(f"{cid}: violates bounded interaction size without an admitted exception.")
        if any(flag not in {"P", "-"} for flag in case["coverage"].values()): fail(f"{cid}: coverage flags must be P or -.")

        primary = case["oracle"].get("primary_class")
        if primary not in ORACLE_ORDER: fail(f"{cid}: unknown primary oracle {primary!r}.")
        if primary == "O5_LEGACY_SWAP431_SOURCE_BOUND": fail(f"{cid}: O5 requires separate scientific justification/provenance and is not admitted in this catalog.")

        wb = case["water_balance"]
        if not wb.get("required"): fail(f"{cid}: water balance must be explicit and required.")
        if wb.get("soft_tolerance_tradeoff_allowed"): fail(f"{cid}: mass conservation cannot be traded for a soft tolerance.")
        for field in ("equation_id","equation","active_storage","inputs","outputs","closure_rule","transaction_rule"):
            if field not in wb or wb[field] in (None, "", []): fail(f"{cid}: incomplete water-balance metadata: {field}")
        if not any(d == "hard_mass_residual" or d.startswith("hard_mass_residual") for d in case["expected_diagnostics"]): fail(f"{cid}: expected diagnostics lack hard mass residual.")
        if not case["tolerance_provenance"]: fail(f"{cid}: missing tolerance provenance.")
        profiles = set(case["execution_profiles"])
        if not profiles or not profiles <= ALLOWED_PROFILES: fail(f"{cid}: invalid execution profiles {profiles}.")
        if not case["theory_equation_refs"]: fail(f"{cid}: missing theory/equation references.")
        inv = case["architecture_invariants"]
        if 13 not in inv or 30 not in inv: fail(f"{cid}: invariants 13 and 30 are mandatory.")
        if any(not isinstance(i, int) or i < 1 or i > 30 for i in inv): fail(f"{cid}: invalid architecture invariant ID.")
        if case["qualification_state"] != "CATALOGED_NOT_PHYSICS_QUALIFIED": fail(f"{cid}: TB09 may not claim executed physics qualification.")

    for dim in dimensions:
        if not any(c["coverage"][dim] == "P" for c in cases): fail(f"No case covers dimension: {dim}")
    for left, right in doc["pairwise_risk_policy"]["mandatory_pairs"]:
        if not any(c["coverage"][left] == "P" and c["coverage"][right] == "P" for c in cases): fail(f"Mandatory risk pair not covered: {left} x {right}")

    restart_cases = [c for c in cases if c.get("restart_interaction")]
    if not restart_cases: fail("No restart-mid-interaction case.")
    for c in restart_cases:
        if "F-TB04" not in " ".join(c["owner_evidence_reused"]): fail(f"{c['stable_id']}: restart interaction must reuse F-TB04 authority.")
    if not any(c["oracle"].get("primary_class") == "O4_QUALIFIED_FULL_RICHARDS_REFERENCE" for c in cases): fail("No bounded Full Richards reference-oriented integrated case.")

    if doc.get("production_source_changed") is not False: fail("Manifest must explicitly state production_source_changed=false.")
    if doc.get("source_defects_fixed") is not False: fail("TB09 must not repair source defects.")
    if doc.get("integrated_physics_results_qualified") is not False: fail("Catalog establishment is not executed physics qualification.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    root = pathlib.Path(args.repo_root).resolve()
    manifest_path = (root / args.manifest).resolve()
    if root not in manifest_path.parents: fail("Manifest must live inside repository.")
    doc = json.loads(manifest_path.read_text(encoding="utf-8"))
    validate_manifest(doc)
    changed = validate_support_only(root, args.base)
    print("F-TB09 catalog contract: PASS")
    print(f"cases={len(doc['cases'])}")
    print("changed_paths=" + ",".join(changed))
    print(EXPECTED_TARGET)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as exc:
        print(f"F-TB09 catalog contract: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
