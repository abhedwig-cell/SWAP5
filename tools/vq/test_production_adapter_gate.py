from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.vq.b2_reference_gate import QUALIFIED_B1_STATUS, READY as B2_READY, REQUIRED_CAPABILITIES
from tools.vq.production_adapter_gate import (
    BLOCKED_NO_B2,
    BLOCKED_NO_BINDING,
    READY,
    assess_candidate,
    check_stored_evidence,
    evidence_projection,
)
from tools.vq.test_b2_result_contract import valid_result_contract
from tools.vq.test_b2_seam_contract import valid_contract
from tools.vq.test_production_adapter_binding import COMMIT, valid_binding

B1_SNAPSHOT = "B1.test"
B1_MANIFEST = "b" * 64


class ProductionAdapterGateTests(unittest.TestCase):
    def prepare_root(self, root: Path, b2_ready: bool = True) -> Path:
        manifest_dir = root / "reference/swap-4.3.1"
        manifest_dir.mkdir(parents=True, exist_ok=True)
        (manifest_dir / "b1-manifest.yml").write_text(
            yaml.safe_dump(
                {
                    "b1": {
                        "snapshot": B1_SNAPSHOT,
                        "oracle_status": QUALIFIED_B1_STATUS,
                        "source_tree": {"member_manifest_sha256": B1_MANIFEST},
                    }
                }
            ),
            encoding="utf-8",
        )

        b2 = {
            "schema_version": 1,
            "observation_baseline": COMMIT,
            "b1_oracle": {
                "snapshot": B1_SNAPSHOT,
                "qualification": QUALIFIED_B1_STATUS,
                "reconstructed_manifest_sha256": B1_MANIFEST,
            },
            "b2": {
                "status": B2_READY if b2_ready else "BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT",
                "commit": COMMIT,
                "integration": {
                    "entrypoint_path": "src/reference_driver.f90" if b2_ready else None,
                    "result_contract_path": "src/reference_result.contract.json" if b2_ready else None,
                    "seam_contract_path": "src/reference_seam.json" if b2_ready else None,
                    "reference_policy": "reference" if b2_ready else None,
                },
                "capabilities": {
                    name: b2_ready for name in REQUIRED_CAPABILITIES
                },
            },
        }
        b2_path = root / "b2.json"
        b2_path.write_text(json.dumps(b2), encoding="utf-8")

        if b2_ready:
            (root / "src").mkdir(parents=True, exist_ok=True)
            (root / "src/reference_driver.f90").write_text("! fixture\n", encoding="utf-8")
            (root / "src/reference_result.contract.json").write_text(
                json.dumps(valid_result_contract()), encoding="utf-8"
            )
            (root / "src/reference_seam.json").write_text(
                json.dumps(valid_contract()), encoding="utf-8"
            )
            contracts = root / "tools/vq/contracts"
            contracts.mkdir(parents=True, exist_ok=True)
            (contracts / "b2-reference-result-record.schema.json").write_text("{}\n", encoding="utf-8")
            (contracts / "mass-accounting-record.schema.json").write_text("{}\n", encoding="utf-8")
        return b2_path

    def prepare_binding(self, root: Path, binding: dict | None = None) -> Path:
        data = valid_binding() if binding is None else binding
        (root / "tools/vq/adapters").mkdir(parents=True, exist_ok=True)
        (root / "tools/vq/adapters/reference_bridge.py").write_text("# fixture\n", encoding="utf-8")
        path = root / "binding.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def write_candidate(self, root: Path, status: str, binding_path: str | None) -> Path:
        path = root / "production-candidate.json"
        path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "workstream": "VQ",
                    "slice": "VQ-1e2",
                    "status": status,
                    "b2_candidate_path": "b2.json",
                    "binding_contract_path": binding_path,
                }
            ),
            encoding="utf-8",
        )
        return path

    def test_blocked_b2_target_fails_before_binding(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root, b2_ready=False)
            candidate = self.write_candidate(root, BLOCKED_NO_B2, None)
            result = assess_candidate(root, candidate)
            self.assertFalse(result["ready_for_production_tx_time"])
            self.assertEqual(result["failure"], "b2_reference_target_not_admitted")

    def test_admitted_b2_with_blocked_binding_status_stays_blocked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            candidate = self.write_candidate(root, BLOCKED_NO_BINDING, None)
            result = assess_candidate(root, candidate)
            self.assertTrue(result["b2_admissible_target"])
            self.assertEqual(result["failure"], "production_adapter_binding_not_ready")

    def test_ready_status_without_binding_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            candidate = self.write_candidate(root, READY, "missing.json")
            result = assess_candidate(root, candidate)
            self.assertEqual(result["failure"], "production_adapter_binding_missing")

    def test_synthetic_binding_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            binding = valid_binding()
            binding["adapter"]["synthetic_fixture"] = True
            self.prepare_binding(root, binding)
            candidate = self.write_candidate(root, READY, "binding.json")
            result = assess_candidate(root, candidate)
            self.assertEqual(result["failure"], "production_adapter_binding_invalid")

    def test_binding_commit_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            binding = valid_binding()
            binding["implementation"]["commit"] = "d" * 40
            self.prepare_binding(root, binding)
            candidate = self.write_candidate(root, READY, "binding.json")
            result = assess_candidate(root, candidate)
            self.assertEqual(result["failure"], "production_adapter_binding_candidate_mismatch")
            self.assertFalse(result["checks"]["binding_commit_matches_b2"])

    def test_binding_entrypoint_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            binding = valid_binding()
            binding["b2_binding"]["entrypoint_path"] = "src/other_driver.f90"
            (root / "src/other_driver.f90").write_text("! fixture\n", encoding="utf-8")
            self.prepare_binding(root, binding)
            candidate = self.write_candidate(root, READY, "binding.json")
            result = assess_candidate(root, candidate)
            self.assertEqual(result["failure"], "production_adapter_binding_candidate_mismatch")
            self.assertFalse(result["checks"]["binding_entrypoint_matches_b2"])

    def test_complete_production_binding_is_ready(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root)
            self.prepare_binding(root)
            candidate = self.write_candidate(root, READY, "binding.json")
            result = assess_candidate(root, candidate)
            self.assertTrue(result["ready_for_production_tx_time"])
            self.assertTrue(result["production_adapter_binding_admissible"])

    def test_stored_evidence_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepare_root(root, b2_ready=False)
            candidate = self.write_candidate(root, BLOCKED_NO_B2, None)
            result = assess_candidate(root, candidate)
            stored = evidence_projection(result)
            stored["candidate_status"] = "wrong"
            evidence = root / "evidence.json"
            evidence.write_text(json.dumps(stored), encoding="utf-8")
            check = check_stored_evidence(result, evidence)
            self.assertFalse(check["consistent"])
            self.assertIn("candidate_status", check["mismatches"])


if __name__ == "__main__":
    unittest.main()
