#!/usr/bin/env python3
"""F-VQ06 admission gate for qualified F-CI18 scope/ownership evidence.

The gate admits only the F-CI18 scope/ownership qualification. It must keep final
F-CI gate promotion, downstream release and downstream physics/reference claims
fail-closed until their separate evidence exists.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FCI17_BASIS = "e17b43e3dda7d178c4c81035308308448823e38d"
FCI18_SOURCE = "a0fdf73b67aa57456d8cbe6700ce707d672981cd"
FCI18_QUALIFICATION = "2989ff626bef3206119213be7776ed4a11059db6"
FCI18_QUAL_RUN = 34112588499
FCI18_QUAL_JOB = 101712814659
FCI18_PR_FAILURE_RUN = 34112593384
FCI18_PR_FAILURE_JOB = 101712984493
PR_MERGE = "bebb886fd215d89234d52b08a95503e45ad972f8"
EXPECTED_CLAIMS = {f"FVQ06-C{i:02d}" for i in range(1, 10)}


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
    q = data.get("qualification_handoff", {})
    failures = data.get("superseded_or_non_authoritative_failure_observations", [])
    by_run = {x.get("workflow_run"): x for x in failures}
    pr = by_run.get(FCI18_PR_FAILURE_RUN, {})
    ctx = data.get("ci_context_evidence", {})
    current = data.get("current_exit_state", {})
    boundary = data.get("fci18_scope_ownership_boundary", {})
    return {
        "source_postimage_exact": q.get("fci18_source_postimage") == FCI18_SOURCE,
        "qualification_commit_exact": q.get("fci18_qualification_commit") == FCI18_QUALIFICATION,
        "canonical_push_exact": q.get("canonical_push_workflow") == FCI18_QUAL_RUN and q.get("fci18_job") == FCI18_QUAL_JOB and q.get("workflow_result") == "SUCCESS",
        "full_chain_pass": q.get("full_dependency_chain") == "PASS_FCI03_THROUGH_FCI18",
        "scope_qualified_by_fci": q.get("scope_ownership_qualified_by_fci") is True,
        "gate_promotion_pending": q.get("gate_promotion") == "PENDING_SEPARATE_COMMIT" and q.get("final_exit_handoff_qualified") is False,
        "pr_failure_exact": pr.get("fci18_job") == FCI18_PR_FAILURE_JOB and pr.get("result") == "FAIL" and pr.get("authoritative_for_fci18_qualification") is False,
        "pr_failure_class_exact": pr.get("failure_class") == "PR_SYNTHETIC_MERGE_DIFF_CONTEXT",
        "valid_event_push": ctx.get("valid_qualification_event") == "push" and ctx.get("valid_qualification_head") == FCI18_SOURCE,
        "pr_merge_recorded": ctx.get("pr_failure_checkout_commit") == PR_MERGE,
        "head_parent_diff_recorded": ctx.get("gate_uses_head_parent_diff") is True and ctx.get("gate_diff_expression") == "git diff --name-only HEAD^ HEAD",
        "candidate_no_production_delta_recorded": ctx.get("source_bound_fci18_candidate_has_production_or_reference_delta") is False,
        "fci17_exit_still_authoritative": current.get("work_unit") == "F-CI17" and current.get("downstream_release_allowed") is False and current.get("must_remain_authoritative_until_fci18_gate_promotion") is True,
        "boundary_not_promotion": boundary.get("proposal_and_qualified_scope_do_not_equal_gate_promotion") is True,
        "mass_non_delegable": boundary.get("hard_mass_remains_non_delegable") is True,
        "transaction_non_delegable": boundary.get("transaction_correctness_remains_non_delegable") is True,
        "provenance_non_delegable": boundary.get("provenance_remains_non_delegable") is True,
        "fvq_numeric_downstream": boundary.get("independent_fvq_numeric_profile_qualification_remains_downstream") is True,
        "fvq_release_downstream": boundary.get("independent_fvq_release_qualification_remains_downstream") is True,
        "scope_ready_not_yet_admitted": data.get("scope_ownership_admission") == "READY_FOR_FVQ06_QUALIFICATION" and data.get("fci18_scope_ownership_admitted_by_fvq06") is False,
        "final_exit_blocked": data.get("final_exit_handoff_admission") == "BLOCKED_FCI18_GATE_PROMOTION_PENDING" and data.get("fci18_final_exit_handoff_qualified") is False,
        "no_fvq_release": data.get("downstream_release_admitted_by_fvq06") is False,
        "reference_execution_blocked": data.get("production_reference_execution_admitted") is False,
        "numeric_profile_blocked": data.get("production_temporal_profile_qualified") is False,
    }


def validate_matrix(data: dict) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    return {
        "claim_set_exact": set(claims) == EXPECTED_CLAIMS,
        "final_promotion_not_claimed": claims.get("FVQ06-C06", {}).get("claim_qualified") is False,
        "scope_not_capability_evidence": claims.get("FVQ06-C07", {}).get("claim_qualified") is False,
        "downstream_release_not_promoted": claims.get("FVQ06-C08", {}).get("claim_qualified") is False,
        "fvq05_blocks_not_lifted": claims.get("FVQ06-C09", {}).get("claim_qualified") is False,
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

    source_paths = changed(FCI17_BASIS, FCI18_SOURCE)
    fvq_paths = changed(FCI18_QUALIFICATION)

    sections: dict[str, dict[str, bool]] = {}
    sections["readiness"] = validate_readiness(readiness)
    sections["matrix"] = validate_matrix(matrix)
    sections["qualified_fci18"] = {
        "qualification_commit_is_ancestor": is_ancestor(FCI18_QUALIFICATION),
        "source_is_ancestor": is_ancestor(FCI18_SOURCE),
        "no_src_source_delta": not any(p.startswith("src/") for p in source_paths),
        "no_reference_source_delta": not any(p.startswith("reference/swap-4.3.1/") for p in source_paths),
        "status_qualified_scope": fci18_status.get("status") == "QUALIFIED_EXIT_SCOPE_OWNERSHIP_GATE_PROMOTION_PENDING",
        "qualified_postimage_exact": fci18_status.get("qualified_postimage") == FCI18_SOURCE,
        "focused_gate_pass": fci18_status.get("qualification", {}).get("focused_scope_gate") == "PASS",
        "canonical_ci_exact": fci18_status.get("qualification", {}).get("canonical_ci") == f"PASS_RUN_{FCI18_QUAL_RUN}_JOB_{FCI18_QUAL_JOB}",
        "full_chain_exact": fci18_status.get("qualification", {}).get("full_dependency_chain") == "PASS_FCI03_THROUGH_FCI18",
        "gate_promotion_pending": fci18_status.get("gate_promotion") == "PENDING_SEPARATE_COMMIT",
        "no_production_change": fci18_status.get("production_source_changed") is False,
    }
    sections["ci_context"] = {
        "workflow_has_push": "push:" in fci_workflow,
        "workflow_has_pull_request": "pull_request:" in fci_workflow,
        "gate_uses_head_parent_diff": '"HEAD^", "HEAD"' in fci18_gate,
        "qualification_records_push_run": str(FCI18_QUAL_RUN) in fci18_qualification and str(FCI18_QUAL_JOB) in fci18_qualification,
        "qualification_precedes_promotion": "This qualification evidence precedes gate promotion." in fci18_qualification,
    }
    non_del = proposal.get("non_delegable", [])
    sections["scope_boundary"] = {
        "proposal_all_gates": proposal.get("proposed_exit", {}).get("all_required_gates") == "QUALIFIED",
        "proposal_release_true": proposal.get("proposed_exit", {}).get("downstream_release_allowed") is True,
        "holds_do_not_mean_admission": proposal.get("downstream_holds_do_not_mean_admission") is True,
        "mass_non_delegable": any("mass" in s.lower() for s in non_del),
        "transaction_non_delegable": any("transaction" in s.lower() for s in non_del),
        "provenance_non_delegable": any("provenance" in s.lower() for s in non_del),
        "g05_fvq_numeric_owner": "F-VQ" in proposal.get("decisions", {}).get("CI-G05", {}).get("owner", ""),
        "g08_fvq_release_owner": "F-VQ" in proposal.get("decisions", {}).get("CI-G08", {}).get("owner", ""),
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
        "no_src_changes_since_fci18_qualification": not any(p.startswith("src/") for p in fvq_paths),
        "qualification_paths_only_since_fci18_qualification": all(
            p.startswith(("integration/f-vq/", "tools/vq/", "docs/verification/"))
            or p == ".github/workflows/vq-reference.yml"
            for p in fvq_paths
        ),
    }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ06",
        "oracle": "B1.10",
        "fci18_source_postimage": FCI18_SOURCE,
        "fci18_qualification_commit": FCI18_QUALIFICATION,
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "FCI18_SCOPE_OWNERSHIP_HANDOFF_ONLY",
        "fci18_scope_ownership_qualifiable": not failed,
        "fci18_final_exit_handoff_qualified": False,
        "final_exit_handoff_admission": "BLOCKED_FCI18_GATE_PROMOTION_PENDING",
        "downstream_release_admitted": False,
        "production_source_changed_by_fvq06": any(p.startswith("src/") for p in fvq_paths),
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_temporal_profile_qualified": False,
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
