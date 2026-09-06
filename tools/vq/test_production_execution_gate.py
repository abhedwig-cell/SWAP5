from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.vq.production_execution_gate import (
    BLOCKED_NO_BINDING,
    READY,
    assess_candidate,
    check_stored_evidence,
    evidence_projection,
)
from tools.vq.tx_time_harness import CASE_IDS


class ProductionExecutionGateTests(unittest.TestCase):
    def write_adapter_candidate(self, root: Path) -> None:
        path = root / "tools/vq/cases"
        path.mkdir(parents=True, exist_ok=True)
        (path / "adapter.json").write_text("{}\n", encoding="utf-8")

    def candidate(self, ready: bool = True) -> dict:
        return {
            "schema_version": 1,
            "workstream": "VQ",
            "slice": "VQ-1e3",
            "status": READY if ready else BLOCKED_NO_BINDING,
            "production_adapter_candidate_path": "tools/vq/cases/adapter.json",
            "adapter_loader": {
                "module_path": "tools/vq/production_adapter_impl.py" if ready else None,
                "factory_symbol": "create_adapter" if ready else None,
                "adapter_protocol": "VQ-QualificationAdapter-v1",
            },
            "suite": {
                "protocol": "VQ-TX-TIME-SUITE-v1",
                "required_case_ids": list(CASE_IDS),
            },
            "pre_execution_claims": {
                "production_execution_claimed": False,
                "b2_physics_status": "NOT_EVALUATED",
                "production_mass_tolerance_qualified": False,
            },
            "decision": {},
        }

    def write_candidate(self, root: Path, data: dict) -> Path:
        path = root / "candidate.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def create_loader(self, root: Path) -> None:
        path = root / "tools/vq"
        path.mkdir(parents=True, exist_ok=True)
        (path / "production_adapter_impl.py").write_text(
            "def create_adapter():\n    raise RuntimeError('not executed by admission test')\n",
            encoding="utf-8",
        )

    @staticmethod
    def ready_adapter_result() -> dict:
        return {
            "ready_for_production_tx_time": True,
            "b1_snapshot": "B1.test",
            "b2_commit": "a" * 40,
        }

    @staticmethod
    def blocked_adapter_result() -> dict:
        return {
            "ready_for_production_tx_time": False,
            "b1_snapshot": "B1.test",
            "b2_commit": "a" * 40,
            "failure": "b2_reference_target_not_admitted",
        }

    def test_blocked_prior_binding_fails_before_loader(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            data = self.candidate(ready=False)
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.blocked_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["production_execution_admissible"])
            self.assertEqual(result["failure"], "production_adapter_binding_not_admitted")
            self.assertFalse(result["production_physics_executed"])
            self.assertEqual(result["b2_physics_status"], "NOT_EVALUATED")

    def test_missing_loader_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, self.candidate()))
            self.assertEqual(result["failure"], "production_adapter_loader_missing")

    def test_missing_factory_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            data = self.candidate()
            data["adapter_loader"]["factory_symbol"] = None
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertEqual(result["failure"], "production_adapter_factory_missing")

    def test_protocol_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            data = self.candidate()
            data["adapter_loader"]["adapter_protocol"] = "other"
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertEqual(result["failure"], "production_adapter_protocol_mismatch")

    def test_incomplete_suite_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            data = self.candidate()
            data["suite"]["required_case_ids"] = list(CASE_IDS[:-1])
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertEqual(result["failure"], "production_tx_time_suite_mismatch")

    def test_duplicate_suite_case_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            data = self.candidate()
            data["suite"]["required_case_ids"][-1] = data["suite"]["required_case_ids"][0]
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertEqual(result["failure"], "production_tx_time_suite_mismatch")

    def test_premature_physics_claim_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            data = self.candidate()
            data["pre_execution_claims"]["production_execution_claimed"] = True
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            self.assertEqual(result["failure"], "premature_production_execution_claim")

    def test_complete_fixture_passes_admission_without_execution(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            self.create_loader(root)
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.ready_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, self.candidate()))
            self.assertTrue(result["production_execution_admissible"])
            self.assertFalse(result["production_physics_executed"])
            self.assertEqual(result["b2_physics_status"], "NOT_EVALUATED")

    def test_stored_evidence_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.write_adapter_candidate(root)
            data = self.candidate(ready=False)
            with patch(
                "tools.vq.production_execution_gate.assess_adapter_candidate",
                return_value=self.blocked_adapter_result(),
            ):
                result = assess_candidate(root, self.write_candidate(root, data))
            stored = evidence_projection(result)
            stored["b1_snapshot"] = "stale"
            evidence = root / "evidence.json"
            evidence.write_text(json.dumps(stored), encoding="utf-8")
            check = check_stored_evidence(result, evidence)
            self.assertFalse(check["consistent"])
            self.assertIn("b1_snapshot", check["mismatches"])


if __name__ == "__main__":
    unittest.main()
