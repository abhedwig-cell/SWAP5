from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.vq.b2_reference_gate import (
    BLOCKED,
    QUALIFIED_B1_STATUS,
    READY,
    REQUIRED_CAPABILITIES,
    assess_candidate,
    check_stored_evidence,
    evidence_projection,
)
from tools.vq.test_b2_result_contract import valid_result_contract
from tools.vq.test_b2_seam_contract import valid_contract

CURRENT_SNAPSHOT = "B1.8"
CURRENT_MANIFEST_SHA256 = "b" * 64
OBSERVATION_COMMIT = "a" * 40


def base_candidate() -> dict:
    return {
        "schema_version": 1,
        "observation_baseline": OBSERVATION_COMMIT,
        "b1_oracle": {
            "snapshot": CURRENT_SNAPSHOT,
            "qualification": QUALIFIED_B1_STATUS,
            "reconstructed_manifest_sha256": CURRENT_MANIFEST_SHA256,
        },
        "b2": {
            "status": READY,
            "commit": OBSERVATION_COMMIT,
            "integration": {
                "entrypoint_path": "src/reference_driver.f90",
                "result_contract_path": "src/reference_result.contract.json",
                "seam_contract_path": "src/reference_seam.json",
                "reference_policy": "reference",
            },
            "capabilities": {name: True for name in REQUIRED_CAPABILITIES},
        },
    }


class B2ReferenceGateTests(unittest.TestCase):
    def write_manifest(
        self,
        root: Path,
        snapshot: str = CURRENT_SNAPSHOT,
        status: str = QUALIFIED_B1_STATUS,
        source_manifest: str = CURRENT_MANIFEST_SHA256,
    ) -> None:
        path = root / "reference" / "swap-4.3.1"
        path.mkdir(parents=True, exist_ok=True)
        (path / "b1-manifest.yml").write_text(
            yaml.safe_dump(
                {
                    "b1": {
                        "snapshot": snapshot,
                        "oracle_status": status,
                        "source_tree": {"member_manifest_sha256": source_manifest},
                    }
                }
            ),
            encoding="utf-8",
        )

    def write_candidate(self, root: Path, data: dict) -> Path:
        path = root / "candidate.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def create_integrated_files(
        self,
        root: Path,
        seam: dict | None = None,
        result_contract: dict | None = None,
    ) -> None:
        (root / "src").mkdir()
        (root / "src/reference_driver.f90").write_text("! fixture\n", encoding="utf-8")
        (root / "src/reference_result.contract.json").write_text(
            json.dumps(valid_result_contract() if result_contract is None else result_contract),
            encoding="utf-8",
        )
        (root / "src/reference_seam.json").write_text(
            json.dumps(valid_contract() if seam is None else seam),
            encoding="utf-8",
        )
        contracts = root / "tools" / "vq" / "contracts"
        contracts.mkdir(parents=True, exist_ok=True)
        (contracts / "b2-reference-result-record.schema.json").write_text("{}\n", encoding="utf-8")
        (contracts / "mass-accounting-record.schema.json").write_text("{}\n", encoding="utf-8")

    def prepared_root(self, root: Path) -> None:
        self.write_manifest(root)

    def blocked_candidate(self) -> dict:
        data = base_candidate()
        data["b2"]["status"] = BLOCKED
        data["b2"]["integration"] = {
            "entrypoint_path": None,
            "result_contract_path": None,
            "seam_contract_path": None,
            "reference_policy": None,
        }
        data["b2"]["capabilities"] = {name: False for name in REQUIRED_CAPABILITIES}
        return data

    def test_blocked_candidate_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            result = assess_candidate(root, self.write_candidate(root, self.blocked_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "b2_reference_entrypoint_not_ready")

    def test_stale_b1_snapshot_fails_against_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            data = base_candidate()
            data["b1_oracle"]["snapshot"] = "B1.7"
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "b1_oracle_not_current_or_not_qualified")
            self.assertFalse(result["checks"]["b1_snapshot_matches_manifest"])

    def test_stale_b1_source_manifest_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            data = base_candidate()
            data["b1_oracle"]["reconstructed_manifest_sha256"] = "c" * 64
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "b1_oracle_not_current_or_not_qualified")
            self.assertFalse(result["checks"]["b1_source_manifest_matches_manifest"])

    def test_observation_commit_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            data = base_candidate()
            data["observation_baseline"] = "d" * 40
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "b2_observation_commit_mismatch")

    def test_ready_candidate_without_entrypoint_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "integrated_entrypoint_missing")

    def test_ready_candidate_without_seam_contract_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            self.create_integrated_files(root)
            (root / "src/reference_seam.json").unlink()
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "reference_seam_contract_missing")

    def test_seam_contract_commit_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            other_commit = "d" * 40
            seam = valid_contract()
            seam["implementation"]["commit"] = other_commit
            self.create_integrated_files(
                root,
                seam=seam,
                result_contract=valid_result_contract(other_commit),
            )
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "reference_seam_contract_candidate_mismatch")

    def test_invalid_seam_contract_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            seam = valid_contract()
            seam["transaction"]["rejected_trial_mutates_committed_state"] = True
            self.create_integrated_files(root, seam=seam)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "reference_seam_contract_invalid")

    def test_invalid_result_contract_fails_admission_through_seam(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            result_contract = valid_result_contract()
            result_contract["transaction"]["rejected_trials_excluded_from_committed_totals"] = False
            self.create_integrated_files(root, result_contract=result_contract)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertEqual(result["failure"], "reference_seam_contract_invalid")

    def test_missing_capability_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            self.create_integrated_files(root)
            data = base_candidate()
            data["b2"]["capabilities"]["unrounded_mass_accounting"] = False
            result = assess_candidate(root, self.write_candidate(root, data))
            self.assertFalse(result["admissible_adapter_target"])
            self.assertIn("unrounded_mass_accounting", result["missing_capabilities"])

    def test_complete_integrated_candidate_passes_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            self.create_integrated_files(root)
            result = assess_candidate(root, self.write_candidate(root, base_candidate()))
            self.assertTrue(result["admissible_adapter_target"])
            self.assertNotIn("failure", result)

    def test_stored_evidence_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.prepared_root(root)
            data = self.blocked_candidate()
            candidate_path = self.write_candidate(root, data)
            result = assess_candidate(root, candidate_path)
            stored = evidence_projection(data, result)
            stored["b1_snapshot"] = "B1.7"
            evidence_path = root / "evidence.json"
            evidence_path.write_text(json.dumps(stored), encoding="utf-8")
            check = check_stored_evidence(candidate_path, result, evidence_path)
            self.assertFalse(check["consistent"])
            self.assertIn("b1_snapshot", check["mismatches"])


if __name__ == "__main__":
    unittest.main()
