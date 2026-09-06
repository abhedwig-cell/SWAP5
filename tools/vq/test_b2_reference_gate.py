from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.b2_reference_gate import READY, REQUIRED_CAPABILITIES, assess_candidate


def base_candidate() -> dict:
    return {
        "schema_version": 1,
        "b1_oracle": {
            "snapshot": "B1.5p1",
            "qualification": "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        },
        "b2": {
            "status": READY,
            "commit": "a" * 40,
            "integration": {
                "entrypoint_path": "src/reference_driver.f90",
                "result_contract_path": "src/reference_result.schema.json",
                "reference_policy": "reference",
            },
            "capabilities": {name: True for name in REQUIRED_CAPABILITIES},
        },
    }


class B2ReferenceGateTests(unittest.TestCase):
    def write_candidate(self, root: Path, data: dict) -> Path:
        path = root / "candidate.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def create_integrated_files(self, root: Path) -> None:
        (root / "src").mkdir()
        (root / "src/reference_driver.f90").write_text("! fixture\n", encoding="utf-8")
        (root / "src/reference_result.schema.json").write_text("{}\n", encoding="utf-8")

    def test_blocked_candidate_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = base_candidate()
            data["b2"]["status"] = "BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT"
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "b2_reference_entrypoint_not_ready")

    def test_ready_candidate_without_entrypoint_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "integrated_entrypoint_missing")

    def test_missing_capability_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.create_integrated_files(root)
            data = base_candidate()
            data["b2"]["capabilities"]["unrounded_mass_accounting"] = False
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertIn("unrounded_mass_accounting", result["missing_capabilities"])

    def test_complete_integrated_candidate_passes_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.create_integrated_files(root)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertTrue(result["admissible_adapter_target"])
            self.assertNotIn("failure", result)


if __name__ == "__main__":
    unittest.main()
