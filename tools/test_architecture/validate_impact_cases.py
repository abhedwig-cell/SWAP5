#!/usr/bin/env python3
"""Replay the F-TA02 historical impact-selection corpus."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

from select_impact import ROOT, select

CASES = ROOT / "test-architecture" / "impact-validation-cases.json"


def main() -> None:
    corpus = json.loads(CASES.read_text(encoding="utf-8"))
    passed = 0
    for case in corpus["cases"]:
        commit = case["historical_commit"]
        parent = subprocess.check_output(["git", "rev-parse", f"{commit}^"], cwd=ROOT, text=True).strip()
        observed = subprocess.check_output(
            ["git", "diff", "--name-only", "--no-renames", parent, commit], cwd=ROOT, text=True
        ).splitlines()
        assert observed == case["changed_paths"], f"{case['case_id']}: historical path drift"
        result = select(observed, case["semantic_declarations"])
        assert not result["blockers"], f"{case['case_id']}: {result['blockers']}"
        assert set(case["required_cost_classes"]) <= set(result["required_cost_classes"]), case["case_id"]
        assert all(any(token in test_id for test_id in result["selected_test_ids"]) for token in case["required_test_id_tokens"]), case["case_id"]
        passed += 1
    unknown = select(["src/new_unowned_component.f90"], {key: False for key in (
        "physics_change", "numerical_policy_change", "transaction_semantics_change",
        "state_layout_change", "precision_policy_change",
    )})
    assert unknown["decision"] == "BLOCKED"
    assert "UNMAPPED_CHANGED_PATH" in unknown["blockers"]
    undeclared = select(["src/kernel/mod_kernel_transactions.f90"], {})
    assert undeclared["decision"] == "BLOCKED"
    assert "SEMANTIC_DECLARATION_INCOMPLETE" in undeclared["blockers"]
    print(f"FTA02_IMPACT_CORPUS_PASS cases={passed} negative_fail_closed=2")


if __name__ == "__main__":
    main()
