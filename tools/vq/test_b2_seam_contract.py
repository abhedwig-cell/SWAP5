from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.b2_seam_contract import assess_contract

COMMIT = "a" * 40


def valid_contract() -> dict:
    return {
        "schema_version": 1,
        "contract_id": "SWAP5-B2-reference-seam-v1",
        "implementation": {
            "commit": COMMIT,
            "integrated": True,
            "entrypoint_path": "src/reference_driver.f90",
            "entrypoint_symbol": "swap_reference_interval",
            "result_contract_path": "src/reference_result.schema.json",
        },
        "policy": {
            "reference_policy_id": "reference",
            "full_accuracy": True,
            "changes_physics": False,
        },
        "inputs": {
            "parameters": {"explicit": True, "file_path_required": False},
            "committed_state": {"explicit": True, "file_path_required": False},
            "forcing": {"explicit": True, "file_path_required": False},
            "numerical_config": {"explicit": True, "file_path_required": False},
            "interval": {"generic_t0_t1": True, "calendar_boundary_required": False},
        },
        "transaction": {
            "checkpoint_trial_commit_rollback": True,
            "rejected_trial_mutates_committed_state": False,
            "trial_endpoint_returned_explicitly": True,
        },
        "outputs": {
            "endpoint_state": True,
            "canonical_results": True,
            "unrounded_mass_accounting": True,
            "transaction_diagnostics": True,
        },
        "mass_accounting": {
            "hard_acceptance": True,
            "identity": "delta_storage_minus_net_external",
            "rounded_acceptance_allowed": False,
        },
        "diagnostics": {
            "required_fields": [
                "accepted",
                "execution_class",
                "retry_count",
                "solver_cost",
                "balance_residual",
            ]
        },
        "forbidden_dependencies": {
            "kernel_file_io": False,
            "kernel_path_dependency": False,
            "kernel_modflow_tile_fraction": False,
            "hidden_calendar_day_assumption": False,
        },
    }


class B2SeamContractTests(unittest.TestCase):
    def prepare(self, root: Path, contract: dict, create_files: bool = True) -> Path:
        if create_files:
            (root / "src").mkdir(parents=True, exist_ok=True)
            (root / "src/reference_driver.f90").write_text("! fixture\n", encoding="utf-8")
            (root / "src/reference_result.schema.json").write_text("{}\n", encoding="utf-8")
        path = root / "seam.json"
        path.write_text(json.dumps(contract), encoding="utf-8")
        return path

    def test_valid_reference_seam_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_contract(root, self.prepare(root, valid_contract()))
            self.assertTrue(result["admissible_reference_seam"])

    def test_missing_integrated_entrypoint_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_contract(root, self.prepare(root, valid_contract(), create_files=False))
            self.assertFalse(result["admissible_reference_seam"])
            self.assertIn("entrypoint_exists", result["failed_checks"])

    def test_file_path_dependency_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract = valid_contract()
            contract["inputs"]["forcing"]["file_path_required"] = True
            result = assess_contract(root, self.prepare(root, contract))
            self.assertFalse(result["admissible_reference_seam"])
            self.assertIn("input_forcing_file_path_not_required", result["failed_checks"])

    def test_rejected_trial_mutation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract = valid_contract()
            contract["transaction"]["rejected_trial_mutates_committed_state"] = True
            result = assess_contract(root, self.prepare(root, contract))
            self.assertFalse(result["admissible_reference_seam"])
            self.assertIn("rejected_trial_preserves_committed_state", result["failed_checks"])

    def test_rounded_mass_acceptance_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract = valid_contract()
            contract["mass_accounting"]["rounded_acceptance_allowed"] = True
            result = assess_contract(root, self.prepare(root, contract))
            self.assertFalse(result["admissible_reference_seam"])
            self.assertIn("mass_rounding_forbidden", result["failed_checks"])

    def test_missing_transaction_diagnostic_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract = valid_contract()
            contract["diagnostics"]["required_fields"].remove("retry_count")
            result = assess_contract(root, self.prepare(root, contract))
            self.assertFalse(result["admissible_reference_seam"])
            self.assertIn("diagnostics_required_fields", result["failed_checks"])


if __name__ == "__main__":
    unittest.main()
