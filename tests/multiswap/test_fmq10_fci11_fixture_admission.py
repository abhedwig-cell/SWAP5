from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from fixture_admission_bridge import FixtureAdmissionBlocked, admit_reference_record
from reference_candidate_gate import REQUIRED, assess

CANDIDATE_PATH = HERE / "reference_candidates" / "b1_10_fci11_candidate.json"

SOURCE_HEAD = "4e8894fc741d7abd711367f712e7aad29d1361eb"
EVIDENCE_COMMIT = "b18150cb4f5313f01fc1c775917c617b421c9ba0"
MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
FVQ01_HEAD = "4bf00d23fc35944df30cc17fc5dd4544e813c29d"

EXPECTED_EVIDENCE_BLOBS = {
    "integration/f-ci/F-CI11_STATUS.json": "18d38b9e94584e3b5757f17c83d69e37eb42c78f",
    "integration/f-ci/F-CI11_QUALIFICATION.md": "42dd72ded40bca6f2beaad8dcccc27a356fec014",
    "integration/f-ci/evidence/F-CI11_LOCAL_GENERIC_INTERVAL_GATE.json": "e75ec40baa689ea0a2ee3d64dfdfa8dfeb646ab6",
    "integration/f-ci/evidence/F-CI10_LOCAL_HUPSEL_MASS_CANDIDATE.json": "cdc8fb5bcee6aa527c0df1fc6b816f4522b263c8",
    "integration/f-vq/F-VQ01_STATUS.json": "67306722f2cfc0c4544a4a47066fc6cfeb428ba9",
}


class TestFMQ10FCI11FixtureAdmission(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.candidate = json.loads(CANDIDATE_PATH.read_text(encoding="utf-8"))

    def test_candidate_is_valid_but_fail_closed(self) -> None:
        result = assess(self.candidate)
        self.assertFalse(result["admission_allowed"])
        self.assertEqual(result["status"], "BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING")
        self.assertEqual(set(result["missing"]), REQUIRED)

    def test_exact_fci11_source_and_qualification_pins(self) -> None:
        identity = self.candidate["source_identity"]
        self.assertEqual(identity["source_commit"], SOURCE_HEAD)
        self.assertEqual(identity["source_tree_manifest_sha256"], MANIFEST_SHA256)
        self.assertEqual(identity["qualification_evidence_commit"], EVIDENCE_COMMIT)
        self.assertEqual(identity["canonical_workflow_run"], 34100440481)
        self.assertEqual(self.candidate["repository_evidence"]["f_vq01_head_inspected"], FVQ01_HEAD)

    def test_fci11_progress_is_visible_without_fixture_promotion(self) -> None:
        progress = self.candidate["capability_progress"]
        for key in (
            "generic_interval_seam",
            "non_midnight_and_cross_day_qualified",
            "worker_local_unrounded_trial_mass",
            "hard_mass_bound_qualified_for_exercised_profile",
        ):
            self.assertTrue(progress[key], key)
        for key in (
            "committed_state_serialized_as_reference_record",
            "forcing_slice_serialized_as_reference_record",
            "numerical_config_serialized_as_reference_record",
            "endpoint_state_serialized_as_reference_record",
            "fmq03_complete_mass_record_serialized",
            "reference_run_extractor_and_output_hash_present",
            "execute_reference_interval_real_b1_10_admitted",
        ):
            self.assertFalse(progress[key], key)

    def test_evidence_inventory_is_exactly_pinned(self) -> None:
        observed = {
            item["path"]: item["git_blob_sha1"]
            for item in self.candidate["evidence_inventory"]
        }
        self.assertEqual(observed, EXPECTED_EVIDENCE_BLOBS)
        self.assertTrue(all(not item["provides_event_checkpoint"] for item in self.candidate["evidence_inventory"]))
        self.assertTrue(all(not item["provides_unrounded_mass"] for item in self.candidate["evidence_inventory"]))

    def test_no_canonical_reference_checkpoint_artifact_is_claimed(self) -> None:
        evidence = self.candidate["repository_evidence"]
        self.assertFalse(evidence["event_checkpoint_artifact_found"])
        self.assertFalse(evidence["raw_fci11_run_matrix_canonical_git"])
        self.assertFalse(evidence["execute_reference_interval_real_b1_10_admitted"])

    def test_admission_bridge_blocks_before_fixture_builder(self) -> None:
        calls: list[str] = []

        def builder(_record):
            calls.append("called")
            return {"should": "not happen"}

        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(self.candidate, {}, builder=builder)
        self.assertEqual(calls, [])

    def test_forbidden_substitutes_protect_physical_oracle(self) -> None:
        forbidden = "\n".join(self.candidate["forbidden_substitutes"]).lower()
        self.assertIn("committed state", forbidden)
        self.assertIn("total_in/total_out/residual", forbidden)
        self.assertIn("workflow run id", forbidden)
        self.assertIn("forcing", forbidden)
        self.assertIn("non-admitted execute_reference_interval", forbidden)


if __name__ == "__main__":
    unittest.main(verbosity=2)
