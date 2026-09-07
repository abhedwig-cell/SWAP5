#!/usr/bin/env python3
"""F-VQ06 fail-closed admission gate for the unqualified F-CI18 handoff candidate."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FCI17_BASIS = "e17b43e3dda7d178c4c81035308308448823e38d"
FCI18_FIRST = "9d35702452808ff849ae285bca5c4377ea2b87b4"
FCI18_CANDIDATE = "a0fdf73b67aa57456d8cbe6700ce707d672981cd"
FCI18_RUN_FIRST = 34112080253
FCI18_RUN_REPLAY = 34112593384
FCI18_JOB_REPLAY = 101712984493
EXPECTED_CLAIMS = {f"FVQ06-C{i:02d}" for i in range(1, 9)}


def load_json(rel: str) -> dict:
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def is_ancestor(commit: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0


def changed(base: str, head: str = "HEAD") -> list[str]:
    out = git("diff", "--name-only", base, head)
    return [p for p in out.splitlines() if p]


def validate_readiness(data: dict) -> dict[str, bool]:
    observed = data.get("observed_ci", [])
    by_head = {item.get("head"): item for item in observed}
    first = by_head.get(FCI18_FIRST, {})
    replay = by_head.get(FCI18_CANDIDATE, {})
    ctx = data.get("context_failure_evidence", {})
    current = data.get("current_exit_state", {})
    review = data.get("fci18_candidate_scope_review", {})
    return {
        "candidate_head_exact": data.get("candidate", {}).get("fci18_replayability_head") == FCI18_CANDIDATE,
        "candidate_status_pending": data.get("candidate", {}).get("status_record") == "PERSISTED_EXIT_SCOPE_CANDIDATE_CI_PENDING",
        "first_run_failed": first.get("workflow_run") == FCI18_RUN_FIRST and first.get("result") == "FAIL" and first.get("fci18_qualified") is False,
        "replay_run_failed": replay.get("workflow_run") == FCI18_RUN_REPLAY and replay.get("fci18_job") == FCI18_JOB_REPLAY and replay.get("result") == "FAIL" and replay.get("fci18_qualified") is False,
        "failure_class_exact": first.get("failure_class") == "PR_SYNTHETIC_MERGE_DIFF_CONTEXT" and replay.get("failure_class") == "PR_SYNTHETIC_MERGE_DIFF_CONTEXT",
        "pr_merge_checkout_recorded": ctx.get("workflow_has_pull_request_trigger") is True and ctx.get("checkout_uses_default_pr_merge_ref") is True and ctx.get("observed_checkout_commit") == "bebb886fd215d89234d52b08a95503e45ad972f8",
        "head_parent_diff_recorded": ctx.get("gate_uses_head_parent_diff") is True and ctx.get("gate_diff_expression") == "git diff --name-only HEAD^ HEAD",
        "actual_candidate_no_production_delta_recorded": ctx.get("actual_fci18_candidate_commit_has_production_or_reference_delta") is False,
        "fci17_exit_still_authoritative": current.get("work_unit") == "F-CI17" and current.get("downstream_release_allowed") is False and current.get("must_remain_authoritative_until_fci18_qualified_promotion") is True,
        "proposal_not_qualification": review.get("proposal_is_not_qualification") is True,
        "mass_non_delegable": review.get("hard_mass_remains_non_delegable") is True,
        "transaction_non_delegable": review.get("transaction_correctness_remains_non_delegable") is True,
        "provenance_non_delegable": review.get("provenance_remains_non_delegable") is True,
        "handoff_blocked": data.get("handoff_admission") == "BLOCKED_FCI18_NOT_QUALIFIED" and data.get("fci18_handoff_qualified") is False,
        "no_fvq_release": data.get("downstream_release_admitted_by_fvq06") is False,
        "reference_execution_blocked": data.get("production_reference_execution_admitted") is False,
        "numeric_profile_blocked": data.get("production_temporal_profile_qualified") is False,
    }


def validate_matrix(data: dict) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    return {
        "claim_set_exact": set(claims) == EXPECTED_CLAIMS,
        "fci18_handoff_not_promoted": claims.get("FVQ06-C04", {}).get("claim_qualified") is False,
        "proposal_not_physics_evidence": claims.get("FVQ06-C07", {}).get("claim_qualified") is False,
        "downstream_release_not_promoted": claims.get("FVQ06-C08", {}).get("claim_qualified") is False,
    }


def main() -> int:
    readiness = load_json("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")
    matrix = load_json("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json")
    fci18_status = load_json("integration/f-ci/F-CI18_STATUS.json")
    current_exit = load_json("integration/f-ci/F-CI_EXIT_GATES.json")
    proposal = load_json("integration/f-ci/F-CI18_EXIT_SCOPE_OWNERSHIP.json")
    fvq05 = load_json("integration/f-vq/evidence/F-VQ05_QUALIFICATION.json")
    fci18_gate = read("tools/fci/fci18_exit_scope_ownership_gate.py")
    fci_workflow = read(".github/workflows/fci-canonical.yml")
    fci18_qualification = read("integration/f-ci/F-CI18_QUALIFICATION.md")

    candidate_paths = changed(FCI17_BASIS, FCI18_CANDIDATE)
    overlay_paths = changed(FCI18_CANDIDATE)

    sections: dict[str, dict[str, bool]] = {}
    sections["readiness"] = validate_readiness(readiness)
    sections["matrix"] = validate_matrix(matrix)
    sections["source_bound_candidate"] = {
        "candidate_is_ancestor": is_ancestor(FCI18_CANDIDATE),
        "no_src_candidate_delta": not any(p.startswith("src/") for p in candidate_paths),
        "no_reference_candidate_delta": not any(p.startswith("reference/swap-4.3.1/") for p in candidate_paths),
        "fci18_status_pending": fci18_status.get("status") == "PERSISTED_EXIT_SCOPE_CANDIDATE_CI_PENDING",
        "focused_gate_pending": fci18_status.get("qualification", {}).get("focused_scope_gate") == "PENDING",
        "canonical_ci_pending": fci18_status.get("qualification", {}).get("canonical_ci") == "PENDING",
        "status_says_no_production_change": fci18_status.get("production_source_changed") is False,
        "status_says_current_exit_not_changed": fci18_status.get("current_exit_gate_file_changed") is False,
    }
    sections["ci_context_diagnosis"] = {
        "workflow_has_pull_request": "pull_request:" in fci_workflow,
        "fci18_job_default_checkout": "fci18-exit-scope-ownership:" in fci_workflow and "uses: actions/checkout@v4" in fci_workflow,
        "gate_uses_head_parent_diff": '"HEAD^", "HEAD"' in fci18_gate,
        "qualification_text_not_promotion": "This is not yet a gate promotion." in fci18_qualification,
    }
    non_del = proposal.get("non_delegable", [])
    sections["proposal_boundary"] = {
        "proposal_all_gates_only_proposed": proposal.get("proposed_exit", {}).get("all_required_gates") == "QUALIFIED",
        "proposal_release_only_proposed": proposal.get("proposed_exit", {}).get("downstream_release_allowed") is True,
        "holds_do_not_mean_admission": proposal.get("downstream_holds_do_not_mean_admission") is True,
        "mass_non_delegable": any("mass" in s.lower() for s in non_del),
        "transaction_non_delegable": any("transaction" in s.lower() for s in non_del),
        "provenance_non_delegable": any("provenance" in s.lower() for s in non_del),
        "g05_keeps_fvq_numeric_ownership": "F-VQ" in proposal.get("decisions", {}).get("CI-G05", {}).get("owner", ""),
        "g08_keeps_fvq_release_qualification": "F-VQ" in proposal.get("decisions", {}).get("CI-G08", {}).get("owner", ""),
        "g09_no_mass_relaxation": "No fallback" in json.dumps(proposal.get("decisions", {}).get("CI-G09", {})),
    }
    sections["authoritative_exit"] = {
        "current_exit_is_fci17": current_exit.get("work_unit") == "F-CI17",
        "current_exit_release_false": current_exit.get("downstream_release_allowed") is False,
        "g02_still_blocked": current_exit.get("gates", {}).get("CI-G02", {}).get("status") == "BLOCKED",
        "g05_still_blocked": current_exit.get("gates", {}).get("CI-G05", {}).get("status") == "BLOCKED",
    }
    sections["fvq05_continuity"] = {
        "temporal_profile_still_unqualified": fvq05.get("production_temporal_profile_qualified") is False,
        "real_temporal_acceptance_still_unqualified": fvq05.get("real_b1_10_temporal_acceptance_qualified") is False,
        "reference_execution_still_blocked": fvq05.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
    }
    sections["change_scope"] = {
        "no_src_changes_since_candidate": not any(p.startswith("src/") for p in overlay_paths),
        "qualification_paths_only_since_candidate": all(
            p.startswith(("integration/f-vq/", "tools/vq/", "docs/verification/"))
            or p == ".github/workflows/vq-reference.yml"
            for p in overlay_paths
        ),
    }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ06",
        "oracle": "B1.10",
        "fci18_candidate": FCI18_CANDIDATE,
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "FCI18_HANDOFF_READINESS_AND_BLOCKING_ONLY",
        "fci18_handoff_qualified": False,
        "handoff_admission": "BLOCKED_FCI18_NOT_QUALIFIED",
        "downstream_release_admitted": False,
        "production_source_changed_by_fvq06": any(p.startswith("src/") for p in overlay_paths),
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
