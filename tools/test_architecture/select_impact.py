#!/usr/bin/env python3
"""Conservative, advisory F-TA test-impact selector.

The selector never grants qualification and never treats an unmatched production
path as safe. It consumes changed paths plus explicit semantic declarations.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "test-architecture" / "test-impact-map.json"
REGISTER = ROOT / "test-architecture" / "test-register.json"

SEMANTIC_KEYS = (
    "physics_change", "numerical_policy_change", "transaction_semantics_change",
    "state_layout_change", "precision_policy_change",
)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def matches(path: str, expression: str) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in expression.split("|"))


def changed_paths(base: str, head: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", f"{base}..{head}"],
        cwd=ROOT, text=True,
    )
    return sorted(filter(None, output.splitlines()))


def select(paths: list[str], declarations: dict) -> dict:
    impact = load(MAP)
    tests = load(REGISTER)["tests"]
    selected: set[str] = set()
    matched_rules: list[dict] = []
    unmatched: list[str] = []
    layers = {"FAST"}

    for path in paths:
        rules = [rule for rule in impact["rules"] if matches(path, rule["source_surface"])]
        if not rules:
            unmatched.append(path)
            continue
        for rule in rules:
            matched_rules.append({"path": path, "component": rule["component"], "dependency_type": rule["dependency_type"]})
            layers.update(rule["required_layers"])
            for test in tests:
                direct = any(fnmatch.fnmatchcase(test["test_id"], pattern) for pattern in rule["direct_test_selectors"])
                dependent = test["component"] in rule["dependent_components"]
                if direct or dependent:
                    selected.add(test["test_id"])

    production = any(path.startswith(("src/", "reference/")) for path in paths)
    undeclared = [key for key in SEMANTIC_KEYS if declarations.get(key) not in {True, False}]
    semantic_change = any(declarations.get(key) is True for key in SEMANTIC_KEYS)
    qualification = any(path.startswith("reference/") for path in paths) or declarations.get("physics_change") is True
    broad = semantic_change or any(item["dependency_type"] in {"STATE_MUTATING", "PHYSICS", "NUMERICAL_POLICY"} for item in matched_rules)
    if broad:
        layers.add("BROAD")
    if qualification:
        layers.add("QUALIFICATION")

    blockers = []
    if unmatched:
        blockers.append("UNMAPPED_CHANGED_PATH")
    if production and undeclared:
        blockers.append("SEMANTIC_DECLARATION_INCOMPLETE")
    if production and not selected:
        blockers.append("NO_TESTS_SELECTED_FOR_PRODUCTION_CHANGE")

    return {
        "selector_version": 1,
        "authority": "ADVISORY_FAIL_CLOSED",
        "changed_paths": paths,
        "semantic_declarations": {key: declarations.get(key, "NOT_ASSESSED") for key in SEMANTIC_KEYS},
        "matched_rules": matched_rules,
        "selected_test_ids": sorted(selected),
        "required_cost_classes": [item for item in ("FAST", "FOCUSED", "BROAD", "QUALIFICATION") if item in layers],
        "unmatched_paths": unmatched,
        "blockers": blockers,
        "decision": "BLOCKED" if blockers else "SELECTION_PROPOSED_NOT_QUALIFICATION",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--case", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.case:
        case = load(args.case)
        paths = case["changed_paths"]
        declarations = case["semantic_declarations"]
    else:
        if not args.base or not args.head:
            parser.error("provide --case or both --base and --head")
        paths = changed_paths(args.base, args.head)
        declarations = {}
    result = select(paths, declarations)
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
