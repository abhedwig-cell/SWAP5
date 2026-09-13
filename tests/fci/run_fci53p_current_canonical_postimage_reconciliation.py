#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

POSTIMAGE = "ccfaed51beeff8f3bc7de9ee2feef538af724bc9"
PREIMAGE = "9770a659d5a93d9abe1341815b57c0fb2fea15ec"
ADMISSION_HEAD = "da401b186a3b7f8a1f93881fa61ad45137561f99"
COMPOSITION = "e0e8462c0d09034dcbdadb99ec16670667d37715"
OWNER = "cfa4e9dcd9a283d85ade316651d34cac93958a4a"
FVQ61 = "e83fe9a4955275935903730c4484c77fb0b117ff"
FVQ60 = "773b1dec23957f2d86648b82ab76f8daede2cbbc"
GOV = "09ef05c60c5e45af218980001c8ad8ec30da2e9e"
SERVICE = "src/runtime/mod_groundwater_exchange_service_contract.f90"
COUPLING = "src/runtime/mod_groundwater_coupling_contract.f90"
SERVICE_BLOB = "f0fc25592624360802713a9487813d119e7dc4e9"
COUPLING_BLOB = "fc598d14eabafcb025bb55621f7b00d6d1816f10"
CANONICAL_WORKFLOW = ".github/workflows/fci-canonical.yml"
ADMITTED_DELTA = [
    ".github/workflows/fci53-gc18r-current-canonical-admission.yml",
    "integration/f-ci/F-CI53_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI53_PRE_REGISTRATION.json",
    "integration/f-ci/F-CI53_STATUS.json",
    SERVICE,
    "tests/fci/run_fci53_gc18r_current_canonical_admission.sh",
]
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci53p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI53P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI53P_EVIDENCE.json",
    "integration/f-ci/F-CI53P_PRE_REGISTRATION.json",
    "integration/f-ci/F-CI53P_STATUS.json",
    "tests/fci/run_fci53p_current_canonical_postimage_reconciliation.py",
}


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def git(*args: str) -> str:
    return run("git", *args).stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI53P_FAIL: {message}")


def fetch_live_authorities() -> None:
    refs = [
        "integration/f-ci-canonical",
        "work/f-gc18r-r1-prepared-transaction-remediation",
        "qualification/f-vq61-gc18r-r1-transactional-groundwater-exchange-independent-requalification",
        "qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification",
        "qualification/f-ci53-gc18r-transactional-groundwater-exchange-current-canonical-admission",
        "regie/f-rg01-post-rb1-program-rebaseline",
    ]
    specs = [f"+refs/heads/{r}:refs/remotes/origin/{r}" for r in refs]
    run("git", "fetch", "--no-tags", "origin", *specs)
    expected = {
        "integration/f-ci-canonical": POSTIMAGE,
        "work/f-gc18r-r1-prepared-transaction-remediation": OWNER,
        "qualification/f-vq61-gc18r-r1-transactional-groundwater-exchange-independent-requalification": FVQ61,
        "qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification": FVQ60,
        "qualification/f-ci53-gc18r-transactional-groundwater-exchange-current-canonical-admission": ADMISSION_HEAD,
        "regie/f-rg01-post-rb1-program-rebaseline": GOV,
    }
    for ref, sha in expected.items():
        actual = git("rev-parse", f"refs/remotes/origin/{ref}")
        require(actual == sha, f"live authority moved: {ref}: expected {sha}, got {actual}")
    print("FCI53P_LIVE_AUTHORITY_RACE_GUARDS=PASS")


def verify_source_admission() -> None:
    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI53 merge parents: {parents}")
    print("FCI53P_TRUE_TWO_PARENT_FCI53_SOURCE_MERGE=PASS")

    anc = run("git", "merge-base", "--is-ancestor", COMPOSITION, ADMISSION_HEAD, check=False)
    require(anc.returncode == 0, "F-CI53 production composition is not an ancestor of qualified admission head")

    actual_delta = sorted(filter(None, git("diff", "--name-only", f"{PREIMAGE}..{POSTIMAGE}").splitlines()))
    require(actual_delta == sorted(ADMITTED_DELTA), f"F-CI53 admitted delta drift: {actual_delta}")
    production = [p for p in actual_delta if p.startswith("src/")]
    require(production == [SERVICE], f"unexpected F-CI53 production scope: {production}")
    print("FCI53P_EXACT_SIX_FILE_FCI53_ADMISSION_DELTA=PASS")

    require(git("rev-parse", f"{POSTIMAGE}:{SERVICE}") == SERVICE_BLOB, "admitted service blob drift")
    require(git("rev-parse", f"HEAD:{SERVICE}") == SERVICE_BLOB, "F-CI53P service blob drift")
    require(git("rev-parse", f"{OWNER}:{SERVICE}") == SERVICE_BLOB, "owner service blob drift")
    require(git("rev-parse", f"{POSTIMAGE}:{COUPLING}") == COUPLING_BLOB, "admitted coupling blob drift")
    require(git("rev-parse", f"HEAD:{COUPLING}") == COUPLING_BLOB, "F-CI53P coupling blob drift")
    print("FCI53P_QUALIFIED_GROUNDWATER_BLOBS_PRESERVED=PASS")


def verify_governance_only_delta() -> None:
    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed == ALLOWED_BRANCH_DELTA, f"unexpected F-CI53P branch delta: {sorted(changed ^ ALLOWED_BRANCH_DELTA)}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed by F-CI53P")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed by F-CI53P")
    require(git("rev-parse", f"HEAD:{CANONICAL_WORKFLOW}") == git("rev-parse", f"{POSTIMAGE}:{CANONICAL_WORKFLOW}"), "fci-canonical workflow changed by F-CI53P")
    print("FCI53P_GOVERNANCE_TEST_ONLY_DELTA=PASS")
    print("FCI53P_MOVING_PRESERVATION_WORKFLOW_UNCHANGED=PASS")


def verify_authority_semantics() -> None:
    owner = json.loads(git("show", f"{OWNER}:integration/f-gc/F-GC18R_R1_STATUS.json"))
    vq61 = json.loads(git("show", f"{FVQ61}:integration/f-vq/F-VQ61_STATUS.json"))
    vq60 = json.loads(git("show", f"{FVQ60}:integration/f-vq/F-VQ60_STATUS.json"))
    require(owner.get("decision") == "OWNER_QUALIFIED_FVQ60_B1_B2_REMEDIATION_NOT_CANONICALLY_ADMITTED", "owner decision drift")
    require(vq61.get("decision") == "INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION", "F-VQ61 decision drift")
    require(vq61.get("independently_qualified_for_canonical_admission") is True, "F-VQ61 positive authority missing")
    require(vq61.get("canonical_admission") is False, "F-VQ61 historical authority rewritten into canonical admission")
    require(vq60.get("decision") == "BLOCKED_REMEDIATION_REQUIRED_BEFORE_CANONICAL_ADMISSION", "F-VQ60 blocked decision drift")
    require(vq60.get("independently_qualified_for_canonical_admission") is False, "F-VQ60 historical blocked authority rewritten")
    print("FCI53P_OWNER_FVQ61_AND_FROZEN_FVQ60_SEMANTICS=PASS")


def verify_metadata() -> None:
    prereg = json.loads(Path("integration/f-ci/F-CI53P_PRE_REGISTRATION.json").read_text())
    require(prereg.get("restart_authority") == POSTIMAGE, "pre-registration restart authority drift")
    scope = prereg.get("scope", {})
    require(scope.get("governance_only_reconciliation") is True, "pre-registration governance-only scope missing")
    require(scope.get("fci_canonical_workflow_change_required") is False, "pre-registration incorrectly requires moving-preservation mutation")
    require(scope.get("production_source_change_allowed") is False, "pre-registration permits production mutation")
    require(scope.get("reference_change_allowed") is False, "pre-registration permits reference mutation")

    evidence = json.loads(Path("integration/f-ci/F-CI53P_EVIDENCE.json").read_text())
    require(evidence.get("source_admission_postimage") == POSTIMAGE, "evidence source postimage drift")
    require(evidence.get("prepromotion_canonical") == PREIMAGE, "evidence prepromotion canonical drift")
    require(evidence.get("fci53_qualified_admission_head") == ADMISSION_HEAD, "evidence admission head drift")
    require(evidence.get("production_composition") == COMPOSITION, "evidence composition drift")
    require(evidence.get("owner_authority") == OWNER, "evidence owner authority drift")
    require(evidence.get("f_vq61_authority") == FVQ61, "evidence F-VQ61 authority drift")
    require(evidence.get("f_vq60_frozen_blocked_authority") == FVQ60, "evidence F-VQ60 authority drift")
    post = evidence.get("fci53_postpromotion_broad_canonical", {})
    require(post.get("run") == 34691652502 and post.get("head") == POSTIMAGE and post.get("conclusion") == "success", "postpromotion broad-run evidence drift")
    require(post.get("current_restricted_canonical_preservation_job") == 103548028821, "current-preservation job evidence drift")
    require(post.get("current_restricted_canonical_preservation_conclusion") == "success", "current-preservation evidence is not green")
    classification = evidence.get("reconciliation_classification", {})
    require(classification.get("moving_preservation_reconciliation_required") is False, "evidence incorrectly requests moving-preservation repair")
    require(classification.get("fci_canonical_workflow_change_required") is False, "evidence incorrectly requests canonical-workflow mutation")
    require(classification.get("classification") == "POSTIMAGE_ALREADY_GREEN_RECONCILIATION_AND_CLOSEOUT_ONLY", "reconciliation classification drift")
    require(not any(classification.get(k) for k in ("production_regression", "scientific_regression", "transaction_regression", "mass_regression", "reference_regression")), "evidence reports a regression")

    audit = json.loads(Path("integration/f-ci/F-CI53P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall drift")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED_WITH_EXACTLY_ONCE_PUBLICATION_GUARD_PRESERVED", "mass audit drift")
    for key in ("production_source_changed", "reference_changed", "canonical_workflow_changed", "scientific_tolerances_changed", "solver_functionality_changed", "new_physics_added", "moving_preservation_weakened", "historical_frozen_authority_rewritten", "RB1_reopened"):
        require(audit.get(key) is False, f"architecture audit reports forbidden change: {key}")
    invariants = audit.get("invariants", [])
    require([x.get("id") for x in invariants] == list(range(1, 31)), "architecture invariant IDs drift")
    require(all(x.get("status") == "PASS" for x in invariants), "architecture invariant failure")

    status = json.loads(Path("integration/f-ci/F-CI53P_STATUS.json").read_text())
    require(status.get("restart_authority") == POSTIMAGE, "status restart authority drift")
    require(status.get("fci53_qualified_admission_head") == ADMISSION_HEAD, "status admission head drift")
    require(status.get("fci53_source_postimage") == POSTIMAGE, "status source postimage drift")
    state = status.get("state", {})
    for key in ("production_source_changed_by_fci53p", "reference_changed_by_fci53p", "canonical_workflow_changed_by_fci53p", "scientific_tolerance_changed", "solver_functionality_changed", "mass_conservation_relaxed", "moving_preservation_disabled_or_weakened", "moving_preservation_change_required", "historical_frozen_authority_rewritten", "RB1_reopened"):
        require(state.get(key) is False, f"status reports forbidden change: {key}")
    require(state.get("all_30_architecture_invariants_reconciled") is True, "status does not reconcile all 30 invariants")
    phase = status.get("phase")
    decision = status.get("decision")
    if phase == "CANDIDATE_MATERIALIZED":
        require(decision == "PENDING_EXACT_HEAD_QUALIFICATION", "candidate decision drift")
        require(state.get("canonical_reconciliation_promoted") is False, "candidate prematurely claims promotion")
        require(state.get("final_closeout_complete") is False, "candidate prematurely claims closeout")
    elif phase == "QUALIFIED_PREPROMOTION_EXACT_STATUS_HEAD_RERUN_REQUIRED":
        require(decision == "QUALIFIED_FCI53P_POSTIMAGE_RECONCILIATION_FOR_PROMOTION_PENDING_EXACT_STATUS_HEAD_RERUN", "qualified decision drift")
        first = status.get("first_green_postimage_reconciliation", {})
        require(first.get("conclusion") == "success" and isinstance(first.get("run"), int) and isinstance(first.get("job"), int), "first-green qualification not pinned")
        for key in ("fci53_true_two_parent_source_merge_verified", "exact_transactional_service_blob_verified", "exact_typed_groundwater_contract_blob_verified", "owner_and_independent_authorities_rechecked", "frozen_f_vq60_history_preserved"):
            require(state.get(key) is True, f"qualified status missing verified state: {key}")
        require(state.get("canonical_reconciliation_promoted") is False, "qualified status prematurely claims promotion")
    else:
        require(False, f"unsupported prepromotion status phase: {phase}")
    print("FCI53P_METADATA_AND_30_INVARIANT_AUDIT=PASS")


def compile_and_run(test_source: str, stem: str, build: Path) -> tuple[str, str]:
    outputs: list[str] = []
    for opt in ("O0", "O2"):
        outdir = build / f"{stem}-{opt}"
        outdir.mkdir(parents=True, exist_ok=True)
        testfile = outdir / f"{stem}.f90"
        testfile.write_text(test_source)
        exe = outdir / "test"
        cp = run(
            "gfortran", f"-{opt}", "-std=f2008", "-Wall", "-Wextra", "-fcheck=all",
            "-ffpe-trap=invalid,zero,overflow", f"-J{outdir}", f"-I{outdir}", COUPLING, SERVICE,
            str(testfile), "-o", str(exe)
        )
        _ = cp
        result = run(str(exe)).stdout
        outputs.append(result)
    require(outputs[0] == outputs[1], f"{stem} O0/O2 output differs")
    return outputs[0], outputs[1]


def replay_exact_admitted_runtime() -> None:
    owner_test = git("show", f"{OWNER}:tests/fgc/test_fgc18r_prepared_commit.f90") + "\n"
    vq_test = git("show", f"{FVQ61}:tests/fvq/test_fvq61_gc18r_r1_independent.f90") + "\n"
    with tempfile.TemporaryDirectory(prefix="fci53p-") as tmp:
        build = Path(tmp)
        owner_out, _ = compile_and_run(owner_test, "owner", build)
        vq_out, _ = compile_and_run(vq_test, "vq61", build)
    require("FGC18R_COPIED_COMMIT_REPLAY_REJECTED=PASS" in owner_out, "owner copied-commit replay marker missing")
    require("FGC18R_BACKEND_TOKEN_REUSE_GENERATION_GUARDED=PASS" in owner_out, "owner generation guard marker missing")
    require("FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED=PASS" in owner_out, "owner revision boundary marker missing")
    require("FVQ61_BACKEND_TOKEN_REUSE_GENERATION_GUARDED=PASS" in vq_out, "independent generation guard marker missing")
    require("FVQ61_REVISION_EXHAUSTION_FAILS_BEFORE_BACKEND=PASS" in vq_out, "independent revision exhaustion marker missing")
    require("FVQ61_INDEPENDENT_NEGATIVE_PATH_AUDIT=PASS_BLOCKERS_CLOSED" in vq_out, "independent negative-path marker missing")
    print("FCI53P_EXACT_ADMITTED_RUNTIME_OWNER_AND_FVQ61_O0_O2=PASS")


def verify_static_contract() -> None:
    service = Path(SERVICE).read_text()
    low = service.lower()
    for forbidden in ("modflow", ".swp", "midnight", "86400"):
        require(forbidden not in low, f"hidden dependency introduced: {forbidden}")
    for required in ("safe_revision_successor", "GW_EXCHANGE_REVISION_EXHAUSTED", "GW_EXCHANGE_STALE_PREPARED", "free_reservation_slot", "reservation_generation", "subroutine consume_prepared_slot", "subroutine release_prepared_slot"):
        require(required in service, f"transaction guard missing: {required}")
    coupling = Path(COUPLING).read_text()
    require("self%t1 <= self%t0" in coupling, "generic coupling time validation missing")
    require("q_groundwater_m_per_s = -q_swap_m_per_s" in coupling, "groundwater sign contract missing")
    require("flux_residual_m_per_s = state%q_swap_m_per_s + state%q_groundwater_m_per_s" in coupling, "mass residual contract missing")
    print("FCI53P_TRANSACTION_MASS_TIME_STATIC_CONTRACT=PASS")


def main() -> None:
    fetch_live_authorities()
    verify_source_admission()
    verify_governance_only_delta()
    verify_authority_semantics()
    verify_metadata()
    verify_static_contract()
    replay_exact_admitted_runtime()
    print("FCI53P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI53P_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI53P_MOVING_PRESERVATION_REPAIR_REQUIRED=NO")
    print("FCI53P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
