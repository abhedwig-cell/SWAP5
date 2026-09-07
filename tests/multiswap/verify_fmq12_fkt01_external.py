import argparse
import json
from pathlib import Path

EXPECTED_HEAD = "62f27672bbb74066ece202de8898597e655aed3d"
EXPECTED_QUAL_EVIDENCE = "e350d84e975e9f6ab4475658566f623b0e46f9ac"
EXPECTED_RUN = 34117279573


def load(path):
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", required=True)
    parser.add_argument("--qualification", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()

    status = load(args.status)
    qualification = load(args.qualification)
    contract = load(args.contract)
    source = Path(args.source).read_text(encoding="utf-8")

    require(status["work_unit"] == "F-KT01", "unexpected F-KT work unit")
    require(status["qualified"] is True, "F-KT01 is not qualified")
    require(status["qualification_evidence_commit"] == EXPECTED_QUAL_EVIDENCE, "qualification evidence commit mismatch")
    require(status["qualification_workflow_run"] == EXPECTED_RUN, "workflow run mismatch")
    require(status["reference_execution_admitted"] is False, "real reference execution must remain fail-closed")

    require(qualification["qualification_status"] == "QUALIFIED", "qualification status mismatch")
    require(qualification["workflow"]["conclusion"] == "success", "F-KT workflow not successful")
    acceptance = qualification["acceptance"]
    for key in (
        "single_canonical_kernel_transaction_api",
        "rejected_trials_never_mutate_committed_state",
        "same_committed_state_retry_and_replay_reproducible",
        "generic_t0_t1_preserved",
        "numerical_configuration_separate_from_physics",
        "worker_scratch_excluded_from_persistent_column_state",
        "unrounded_transaction_mass_accounting_preserved",
        "missing_reference_policy_evidence_fails_closed",
    ):
        require(acceptance[key] == "PASS", f"F-KT01 acceptance missing: {key}")

    require(contract["canonical_api"]["production_execution_entrypoint"] == "kernel_executor_t%advance_interval", "canonical entrypoint mismatch")
    tx = contract["transaction_semantics"]
    require(tx["rejected_trial_mutates_committed"] is False, "rejected trial mutation contract violated")
    require(tx["incomplete_interval_creates_candidate"] is False, "incomplete interval candidate contract violated")
    require(tx["commit_is_explicit"] is True, "explicit commit contract missing")
    require(tx["rollback_discards_candidate_only"] is True, "rollback contract missing")
    require(tx["same_committed_state_replay_required"] is True, "replay contract missing")
    require(contract["mass_semantics"]["fabricate_incomplete_interval_mass"] is False, "mass fabrication must remain forbidden")

    required_source_fragments = (
        "class(transaction_state_t), allocatable, intent(in) :: committed_state",
        "procedure, public :: advance_interval => kernel_advance_interval",
        "procedure, public :: commit_candidate => kernel_commit_candidate",
        "procedure, public :: rollback_candidate => kernel_rollback_candidate",
        "if (runtime_result%completed) then",
        "call move_alloc(working, candidate_state%state)",
        "call move_alloc(candidate_state%state, committed_state)",
    )
    for fragment in required_source_fragments:
        require(fragment in source, f"missing source-bound kernel contract fragment: {fragment}")

    print(f"F-MQ12_EXTERNAL_FKT01_GATE PASS head={EXPECTED_HEAD}")


if __name__ == "__main__":
    main()
