#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "integration" / "f-ci" / "F-CI17_BASELINE_REGISTRY.json"
FCI16_SNAPSHOT = ROOT / "integration" / "f-ci" / "F-CI16_EXIT_GATES.json"
CANONICAL = "integration/f-ci-canonical"
EXPECTED_HISTORICAL = {
    "integration/a23bk-transactional-rebase": "763f276a96ee1722a465bacd3a710172a5f38107",
    "integration/f-ci06-temp": "db3a918815b0fdc22bdd612e1ceab7b092cd1600",
    "integration/f-ci06-working": "db3a918815b0fdc22bdd612e1ceab7b092cd1600",
    "integration/f-ci08-safety-checkpoint": "b2c0664816f8b34ecf9e337790767cc575c330ee",
    "integration/f-ci08-working": "b2c0664816f8b34ecf9e337790767cc575c330ee",
    "integration/f-ci-canonical-copy": "db3a918815b0fdc22bdd612e1ceab7b092cd1600",
}
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    raise SystemExit(f"FCI17_GATE_FAIL: {message}")


def main() -> None:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or data.get("work_unit") != "F-CI17":
        fail("registry identity")
    if data.get("canonical_branch") != CANONICAL:
        fail("canonical branch")
    if data.get("production_source_changed") is not False:
        fail("production source mutation")
    parent = data.get("registry_parent_head")
    if not isinstance(parent, str) or SHA40.fullmatch(parent) is None:
        fail("registry parent head")

    policy = data.get("policy", {})
    required_policy = {
        "sole_active_development_baseline": CANONICAL,
        "new_production_work_must_start_from_canonical": True,
        "historical_branches_may_remain_for_provenance": True,
        "historical_branches_allow_new_production_work": False,
        "branch_presence_does_not_imply_active_baseline": True,
        "canonical_copy_is_not_a_fallback_baseline": True,
    }
    if policy != required_policy:
        fail("canonical baseline policy")

    branches = data.get("audited_branches", {})
    expected_names = {CANONICAL, *EXPECTED_HISTORICAL.keys()}
    if set(branches) != expected_names:
        fail("audited branch set")

    active = [name for name, rec in branches.items() if rec.get("status") == "ACTIVE_CANONICAL"]
    if active != [CANONICAL]:
        fail("exactly one active canonical baseline")
    canonical = branches[CANONICAL]
    if canonical.get("allows_new_production_work") is not True or canonical.get("successor") is not None:
        fail("canonical permissions")
    if canonical.get("observed_head_before_registry") != parent:
        fail("canonical parent pin")

    for name, expected_sha in EXPECTED_HISTORICAL.items():
        rec = branches[name]
        if rec.get("status") != "SUPERSEDED_HISTORICAL_ONLY":
            fail(f"{name} not superseded")
        if rec.get("observed_head") != expected_sha:
            fail(f"{name} head pin")
        if rec.get("successor") != CANONICAL:
            fail(f"{name} successor")
        if rec.get("allows_new_production_work") is not False:
            fail(f"{name} still allows production work")
        if not rec.get("retained_for"):
            fail(f"{name} retention rationale")

    if branches["integration/f-ci-canonical-copy"].get("explicit_note") is None:
        fail("canonical-copy ambiguity not resolved")

    old = json.loads(FCI16_SNAPSHOT.read_text(encoding="utf-8"))
    if old.get("work_unit") != "F-CI16" or old.get("gates", {}).get("CI-G10", {}).get("status") != "BLOCKED":
        fail("immutable F-CI16 assessment snapshot")

    print("FCI17_CANONICAL_BASELINE_REGISTRY PASS")


if __name__ == "__main__":
    main()
