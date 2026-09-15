#!/usr/bin/env python3
"""F-VQ07 gate for the final qualified F-CI development-baseline exit handoff."""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ06_FINAL = "f7d68248a22d0912fe91e2277ac51f64293e449c"
FCI18_SCOPE = "a0fdf73b67aa57456d8cbe6700ce707d672981cd"
FCI18_SCOPE_EVIDENCE = "2989ff626bef3206119213be7776ed4a11059db6"
FCI18_PROMOTION = "1eceed967b12396b8bbc832f897376378463adce"
FCI18_CLOSEOUT = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
FCI18_PROMOTION_RUN = 34114164800
FCI18_PROMOTION_JOB = 101717589931
FCI18_CLOSEOUT_RUN = 34114481363
FCI18_CLOSEOUT_JOB = 101718655619
EXPECTED_GATES = {f"CI-G{i:02d}" for i in range(1, 11)}
EXPECTED_CLAIMS = {f"FVQ07-C{i:02d}" for i in range(1, 11)}
CANONICAL_OVERLAY = [
    "integration/f-ci/F-CI18_EXIT_GATES.json",
    "integration/f-ci/F-CI18_QUALIFICATION.md",
    "integration/f-ci/F-CI18_STATUS.json",
    "integration/f-ci/F-CI_EXIT_GATES.json",
]

def load_json(rel): return json.loads((ROOT / rel).read_text(encoding="utf-8"))
def read(rel): return (ROOT / rel).read_text(encoding="utf-8")
def git(*args): return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
def is_ancestor(commit): return subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0
def changed(base, head="HEAD"):
    out = git("diff", "--name-only", base, head)
    return [p for p in out.splitlines() if p]
def show(commit, rel): return git("show", f"{commit}:{rel}")

def validate_exit_snapshot(data):
    gates = data.get("gates", {})
    return {
        "work_unit_fci18": data.get("work_unit") == "F-CI18",
        "oracle_b1_10": data.get("b1_oracle") == "B1.10",
        "release_true": data.get("downstream_release_allowed") is True,
        "summary_ten_qualified": data.get("assessment_summary", {}).get("qualified") == 10,
        "gate_set_exact": set(gates) == EXPECTED_GATES,
        "all_required": all(g.get("required") is True for g in gates.values()) and len(gates) == 10,
        "all_qualified": all(g.get("status") == "QUALIFIED" for g in gates.values()) and len(gates) == 10,
        "all_allow_release": all(g.get("allows_downstream_release") is True for g in gates.values()) and len(gates) == 10,
        "all_blockers_empty": all(g.get("blockers") == [] for g in gates.values()) and len(gates) == 10,
    }

def validate_readiness(data):
    b = data.get("basis", {}); ex = data.get("fci_exit_state", {}); r = data.get("source_bound_replays", {}); nd = data.get("non_delegable", {}); cap = data.get("downstream_capability_boundaries", {})
    return {
        "fvq06_exact": b.get("fvq06_final_head") == FVQ06_FINAL,
        "scope_exact": b.get("fci18_scope_postimage") == FCI18_SCOPE and b.get("fci18_scope_qualification_evidence_commit") == FCI18_SCOPE_EVIDENCE,
        "promotion_exact": b.get("fci18_gate_promotion_head") == FCI18_PROMOTION and b.get("fci18_gate_promotion_push_run") == FCI18_PROMOTION_RUN and b.get("fci18_gate_promotion_job") == FCI18_PROMOTION_JOB,
        "closeout_exact": b.get("fci18_canonical_closeout_head") == FCI18_CLOSEOUT and b.get("fci18_closeout_push_run") == FCI18_CLOSEOUT_RUN and b.get("fci18_closeout_job") == FCI18_CLOSEOUT_JOB,
        "exit_status_qualified": ex.get("status") == "QUALIFIED_EXIT" and ex.get("gate_promotion") == "QUALIFIED" and ex.get("all_required_gates") == "QUALIFIED",
        "exit_release_true": ex.get("downstream_release_allowed") is True and ex.get("required_gate_count") == 10 and ex.get("remaining_fci_blockers") == [],
        "promotion_replay_exact": r.get("promotion") == f"PASS_RUN_{FCI18_PROMOTION_RUN}_JOB_{FCI18_PROMOTION_JOB}",
        "closeout_replay_exact": r.get("closeout") == f"PASS_RUN_{FCI18_CLOSEOUT_RUN}_JOB_{FCI18_CLOSEOUT_JOB}" and r.get("closeout_full_dependency_chain") == "PASS_FCI03_THROUGH_FCI18",
        "non_delegable_all_true": all(nd.get(k) is True for k in ["provenance_integrity","transaction_correctness_and_rollback_isolation","hard_mass_conservation_for_every_admitted_path","fail_closed_unqualified_reference_or_optional_process_capability","single_canonical_development_baseline"]),
        "reference_still_blocked": cap.get("production_reference_execution_admitted") is False,
        "temporal_still_blocked": cap.get("production_temporal_profile_qualified") is False and cap.get("real_b1_10_temporal_acceptance_qualified") is False,
        "optional_still_blocked": cap.get("optional_process_scope_qualified") is False,
        "parallel_still_blocked": cap.get("parallel_backend_qualified") is False,
        "overall_release_still_blocked": cap.get("overall_swap5_release_qualified") is False,
    }

def validate_matrix(data, qualified):
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    target_flags = [claims.get(f"FVQ07-C{i:02d}", {}).get("claim_qualified") for i in range(1, 6)]
    blocked_flags = [claims.get(f"FVQ07-C{i:02d}", {}).get("claim_qualified") for i in range(6, 11)]
    return {
        "claim_set_exact": set(claims) == EXPECTED_CLAIMS,
        "target_flags_match_status": all(x is qualified for x in target_flags),
        "blocked_claims_false": all(x is False for x in blocked_flags),
        "blocked_claims_have_blockers": all(bool(claims.get(f"FVQ07-C{i:02d}", {}).get("blocker")) for i in range(6, 11)),
    }

def main():
    readiness = load_json("integration/f-vq/F-VQ07_EXIT_HANDOFF_READINESS.json")
    matrix = load_json("integration/f-vq/F-VQ07_ADMISSION_MATRIX.json")
    status = load_json("integration/f-vq/F-VQ07_STATUS.json")
    fci_status = load_json("integration/f-ci/F-CI18_STATUS.json")
    current_exit = load_json("integration/f-ci/F-CI_EXIT_GATES.json")
    immutable_exit = load_json("integration/f-ci/F-CI18_EXIT_GATES.json")
    qualification_md = read("integration/f-ci/F-CI18_QUALIFICATION.md")
    fvq06 = load_json("integration/f-vq/evidence/F-VQ06_QUALIFICATION.json")
    qualified = status.get("qualified") is True

    sections = {}
    sections["readiness"] = validate_readiness(readiness)
    sections["current_exit"] = validate_exit_snapshot(current_exit)
    sections["immutable_exit"] = validate_exit_snapshot(immutable_exit)
    sections["matrix"] = validate_matrix(matrix, qualified)
    sections["ancestry"] = {
        "fvq06_is_ancestor": is_ancestor(FVQ06_FINAL),
        "scope_is_ancestor": is_ancestor(FCI18_SCOPE),
        "scope_evidence_is_ancestor": is_ancestor(FCI18_SCOPE_EVIDENCE),
        "promotion_is_ancestor": is_ancestor(FCI18_PROMOTION),
        "closeout_is_ancestor": is_ancestor(FCI18_CLOSEOUT),
    }
    sections["fci18_status"] = {
        "status_qualified_exit": fci_status.get("status") == "QUALIFIED_EXIT",
        "promotion_qualified": fci_status.get("gate_promotion") == "QUALIFIED",
        "all_required_qualified": fci_status.get("all_required_gates") == "QUALIFIED",
        "release_true": fci_status.get("downstream_release_allowed") is True,
        "no_fci_blockers": fci_status.get("remaining_fci_blockers") == [],
        "exit_head_exact": fci_status.get("canonical_development_baseline_exit_head") == FCI18_PROMOTION,
        "promotion_replay_exact": fci_status.get("qualification", {}).get("gate_promotion_replay") == f"PASS_RUN_{FCI18_PROMOTION_RUN}_JOB_{FCI18_PROMOTION_JOB}",
    }
    sections["qualification_text"] = {
        "status_qualified_exit": "Status: `QUALIFIED_EXIT`." in qualification_md,
        "promotion_run_recorded": str(FCI18_PROMOTION_RUN) in qualification_md and str(FCI18_PROMOTION_JOB) in qualification_md,
        "downstream_boundary_recorded": "does not itself mark F-KT, F-SI or any other downstream workstream as released" in qualification_md,
    }
    sections["overlay_identity"] = {rel.replace("/", "_"): read(rel).rstrip("\n") == show(FCI18_CLOSEOUT, rel).rstrip("\n") for rel in CANONICAL_OVERLAY}
    fci18_delta = changed(FCI18_SCOPE_EVIDENCE, FCI18_CLOSEOUT)
    fvq_delta = changed(FCI18_CLOSEOUT)
    sections["change_scope"] = {
        "fci18_no_src_delta": not any(p.startswith("src/") for p in fci18_delta),
        "fci18_no_reference_delta": not any(p.startswith("reference/swap-4.3.1/") for p in fci18_delta),
        "fvq07_no_src_delta": not any(p.startswith("src/") for p in fvq_delta),
        "fvq07_no_reference_delta": not any(p.startswith("reference/swap-4.3.1/") for p in fvq_delta),
        "fvq07_qualification_paths_only": all(p.startswith(("integration/f-vq/", "tools/vq/", "docs/verification/")) or p == ".github/workflows/vq-reference.yml" for p in fvq_delta),
    }
    sections["fvq06_continuity"] = {
        "decision_exact": fvq06.get("decision") == "QUALIFIED_FCI18_SCOPE_OWNERSHIP_HANDOFF_ONLY",
        "production_source_unchanged": fvq06.get("production_source_changed_by_fvq06") is False,
        "prior_reference_nonclaim": any("execute_reference_interval" in x for x in fvq06.get("explicit_non_claims", [])),
        "prior_temporal_nonclaim": any("temporal-limit profile" in x for x in fvq06.get("explicit_non_claims", [])),
    }
    sections["status_boundary"] = {
        "status_work_unit": status.get("work_unit") == "F-VQ07",
        "production_source_false": status.get("production_source_changed_by_fvq07") is False,
        "reference_blocked": status.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "temporal_false": status.get("production_temporal_profile_qualified") is False,
        "optional_false": status.get("optional_process_scope_qualified") is False,
        "parallel_false": status.get("parallel_backend_qualified") is False,
        "overall_release_false": status.get("overall_swap5_release_qualified") is False,
    }

    evidence_ok = True
    evidence_checks = {}
    evidence_path = ROOT / "integration/f-vq/evidence/F-VQ07_QUALIFICATION.json"
    if qualified:
        if not evidence_path.exists():
            evidence_ok = False; evidence_checks["evidence_exists"] = False
        else:
            evidence = load_json("integration/f-vq/evidence/F-VQ07_QUALIFICATION.json")
            tested = evidence.get("tested_postimage")
            evidence_checks = {
                "evidence_exists": True,
                "decision_exact": evidence.get("decision") == "QUALIFIED_FINAL_FCI_DEVELOPMENT_BASELINE_HANDOFF_ONLY",
                "tested_matches_status": bool(tested) and tested == status.get("tested_postimage"),
                "tested_is_ancestor": bool(tested) and is_ancestor(tested),
                "run_success": evidence.get("qualification_run", {}).get("conclusion") == "success",
                "no_production_change": evidence.get("production_source_changed_by_fvq07") is False,
                "reference_still_blocked": evidence.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
                "overall_release_false": evidence.get("overall_swap5_release_qualified") is False,
            }
            evidence_ok = all(evidence_checks.values())
        sections["qualification_evidence"] = evidence_checks

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    if qualified and not evidence_ok and not any(x.startswith("qualification_evidence.") for x in failed): failed.append("qualification_evidence.invalid")
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ07",
        "oracle": "B1.10",
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "FINAL_FCI_DEVELOPMENT_BASELINE_HANDOFF_ONLY",
        "fci_final_exit_handoff_qualifiable": not failed,
        "fci_final_exit_handoff_qualified": qualified and not failed,
        "canonical_development_baseline_admitted_for_downstream_qualification": qualified and not failed,
        "production_source_changed_by_fvq07": any(p.startswith("src/") for p in fvq_delta),
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_temporal_profile_qualified": False,
        "optional_process_scope_qualified": False,
        "parallel_backend_qualified": False,
        "overall_swap5_release_qualified": False,
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1

if __name__ == "__main__": sys.exit(main())
