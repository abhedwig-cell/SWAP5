from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.production_adapter_binding import assess_binding

COMMIT = "a" * 40


def valid_binding() -> dict:
    return {
        "schema_version": 1,
        "contract_id": "SWAP5-VQ-production-adapter-binding-v1",
        "implementation": {"commit": COMMIT, "production_target": True},
        "adapter": {
            "path": "tools/vq/adapters/reference_bridge.py",
            "factory_symbol": "build_qualification_adapter",
            "qualification_adapter_protocol": "VQ-QualificationAdapter-v1",
            "synthetic_fixture": False,
        },
        "b2_binding": {
            "entrypoint_path": "src/reference_driver.f90",
            "seam_contract_path": "src/reference_seam.json",
            "result_contract_path": "src/reference_result.contract.json",
            "reference_policy": "reference",
        },
        "semantics": {
            "generic_interval_forwarded_exactly": True,
            "committed_state_forwarded_as_physical_start": True,
            "forcing_replayed_exactly_on_retry": True,
            "numerical_warm_start_separate": True,
            "accepted_result_normalized_to_vq_record": True,
            "transaction_trace_exposed": True,
            "rejected_trials_excluded_from_committed_totals": True,
            "commit_exactly_once": True,
        },
        "non_interference": {
            "changes_physics": False,
            "changes_numerical_policy": False,
            "changes_forcing": False,
            "changes_interval": False,
            "changes_mass_terms": False,
            "introduces_kernel_file_io": False,
            "introduces_hidden_calendar_boundary": False,
        },
    }


class ProductionAdapterBindingTests(unittest.TestCase):
    def prepare(self, root: Path, binding: dict, create_files: bool = True) -> Path:
        if create_files:
            (root / "tools/vq/adapters").mkdir(parents=True, exist_ok=True)
            (root / "tools/vq/adapters/reference_bridge.py").write_text("# fixture\n", encoding="utf-8")
            (root / "src").mkdir(parents=True, exist_ok=True)
            for name in ("reference_driver.f90", "reference_seam.json", "reference_result.contract.json"):
                (root / "src" / name).write_text("{}\n", encoding="utf-8")
        path = root / "binding.json"
        path.write_text(json.dumps(binding), encoding="utf-8")
        return path

    def test_valid_production_binding_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_binding(root, self.prepare(root, valid_binding()))
            self.assertTrue(result["admissible_production_adapter_binding"])

    def test_synthetic_fixture_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binding = valid_binding()
            binding["adapter"]["synthetic_fixture"] = True
            result = assess_binding(root, self.prepare(root, binding))
            self.assertFalse(result["admissible_production_adapter_binding"])
            self.assertIn("not_synthetic_fixture", result["failed_checks"])

    def test_missing_adapter_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_binding(root, self.prepare(root, valid_binding(), create_files=False))
            self.assertFalse(result["admissible_production_adapter_binding"])
            self.assertIn("adapter_path_exists", result["failed_checks"])

    def test_protocol_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binding = valid_binding()
            binding["adapter"]["qualification_adapter_protocol"] = "other"
            result = assess_binding(root, self.prepare(root, binding))
            self.assertFalse(result["admissible_production_adapter_binding"])
            self.assertIn("qualification_adapter_protocol", result["failed_checks"])

    def test_physics_interference_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binding = valid_binding()
            binding["non_interference"]["changes_physics"] = True
            result = assess_binding(root, self.prepare(root, binding))
            self.assertFalse(result["admissible_production_adapter_binding"])
            self.assertIn("non_interference_changes_physics", result["failed_checks"])

    def test_missing_transaction_semantic_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binding = valid_binding()
            binding["semantics"]["commit_exactly_once"] = False
            result = assess_binding(root, self.prepare(root, binding))
            self.assertFalse(result["admissible_production_adapter_binding"])
            self.assertIn("semantics_commit_exactly_once", result["failed_checks"])


if __name__ == "__main__":
    unittest.main()
