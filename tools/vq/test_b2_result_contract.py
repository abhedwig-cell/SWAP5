from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.b2_result_contract import assess_contract

COMMIT = "a" * 40


def valid_result_contract(commit: str = COMMIT) -> dict:
    return {
        "schema_version": 1,
        "contract_id": "SWAP5-B2-reference-result-v1",
        "implementation": {
            "commit": commit,
            "canonical_record_schema": "tools/vq/contracts/b2-reference-result-record.schema.json",
        },
        "interval": {
            "t0_explicit": True,
            "t1_explicit": True,
            "generic_t0_t1": True,
            "calendar_boundary_required": False,
            "returned_interval_matches_request": True,
        },
        "endpoint_state": {
            "explicit": True,
            "committed_only": True,
            "rejected_trial_endpoint_can_replace_committed": False,
            "stable_variable_ids": True,
        },
        "result_values": {
            "stable_result_ids": True,
            "units_explicit": True,
            "unrounded": True,
            "rejected_trials_excluded": True,
            "retry_totals_exactly_once": True,
        },
        "mass_accounting": {
            "record_schema": "tools/vq/contracts/mass-accounting-record.schema.json",
            "start_end_storage_unrounded": True,
            "signed_external_terms_unrounded": True,
            "residual_recomputed_by_vq": True,
            "reported_residual_diagnostic_only": True,
            "rounded_acceptance_allowed": False,
            "identity": "delta_storage_minus_net_external",
        },
        "transaction": {
            "required_fields": [
                "accepted",
                "accepted_trial_id",
                "trial_count",
                "retry_count",
                "commit_count",
                "rollback_count",
            ],
            "exactly_one_commit_for_accepted": True,
            "rejected_trials_excluded_from_committed_totals": True,
            "retry_history_diagnostic_only": True,
        },
        "diagnostics": {
            "required_fields": [
                "accepted",
                "execution_class",
                "retry_count",
                "solver_iterations",
                "solver_cost",
                "fallback_used",
                "balance_residual",
            ],
            "defines_physical_result": False,
        },
        "provenance": {
            "required_fields": [
                "implementation_commit",
                "numerical_policy",
                "result_contract_version",
                "case_id",
            ],
            "implementation_commit_bound_to_result": True,
            "numerical_policy_bound_to_result": True,
            "result_contract_version": "v1",
        },
        "execution_class_semantics": {
            "same_physical_result_schema": True,
            "same_mass_identity": True,
            "policy_changes_physics": False,
        },
    }


class B2ResultContractTests(unittest.TestCase):
    def prepare_root(self, root: Path) -> None:
        contracts = root / "tools" / "vq" / "contracts"
        contracts.mkdir(parents=True, exist_ok=True)
        (contracts / "b2-reference-result-record.schema.json").write_text("{}\n", encoding="utf-8")
        (contracts / "mass-accounting-record.schema.json").write_text("{}\n", encoding="utf-8")

    def write_contract(self, root: Path, data: dict) -> Path:
        path = root / "result-contract.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_valid_contract_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            result = assess_contract(root, self.write_contract(root, valid_result_contract()))
            self.assertTrue(result["admissible_result_contract"])

    def test_missing_canonical_record_schema_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            (root / "tools/vq/contracts/b2-reference-result-record.schema.json").unlink()
            result = assess_contract(root, self.write_contract(root, valid_result_contract()))
            self.assertFalse(result["admissible_result_contract"])
            self.assertIn("canonical_record_schema_exists", result["failed_checks"])

    def test_rounded_mass_acceptance_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            data = valid_result_contract()
            data["mass_accounting"]["rounded_acceptance_allowed"] = True
            result = assess_contract(root, self.write_contract(root, data))
            self.assertFalse(result["admissible_result_contract"])
            self.assertIn("rounded_mass_acceptance_forbidden", result["failed_checks"])

    def test_rejected_trial_contribution_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            data = valid_result_contract()
            data["transaction"]["rejected_trials_excluded_from_committed_totals"] = False
            result = assess_contract(root, self.write_contract(root, data))
            self.assertFalse(result["admissible_result_contract"])
            self.assertIn("rejected_trials_excluded_from_committed_totals", result["failed_checks"])

    def test_missing_solver_iterations_diagnostic_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            data = valid_result_contract()
            data["diagnostics"]["required_fields"].remove("solver_iterations")
            result = assess_contract(root, self.write_contract(root, data))
            self.assertFalse(result["admissible_result_contract"])
            self.assertIn("diagnostics_fields", result["failed_checks"])

    def test_execution_policy_may_not_change_physics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            data = valid_result_contract()
            data["execution_class_semantics"]["policy_changes_physics"] = True
            result = assess_contract(root, self.write_contract(root, data))
            self.assertFalse(result["admissible_result_contract"])
            self.assertIn("execution_policy_does_not_change_physics", result["failed_checks"])


if __name__ == "__main__":
    unittest.main()
